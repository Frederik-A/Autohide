import Cocoa
import ApplicationServices

// macOS prototype. PowerPoint's AppleScript dictionary is resolved on the user's Mac.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var statusItem: NSStatusItem!
    let status = NSTextField(wrappingLabelWithString: "Uitgeschakeld.")
    let seconds = NSTextField(string: "4")
    let button = NSButton(title: "Inschakelen", target: nil, action: nil)
    var timer: Timer?
    var monitor: Any?
    var enabled = false
    var started = false
    var hidden = false
    var last = ProcessInfo.processInfo.systemUptime
    var point = NSEvent.mouseLocation
    var checkAt = 0.0
    var delay = 4.0
    var scriptError = ""
    var manualPointer = false
    var lastPowerPointPID: pid_t?

    var powerpoint: NSRunningApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == "com.microsoft.Powerpoint" else { return nil }
        return app
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Stop Laser Auto Hide", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 490, height: 255),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Laser Auto Hide – Mac v0.2"
        window.isReleasedWhenClosed = false
        let label = NSTextField(labelWithString: "Verbergen na (1–60 seconden):")
        label.frame = NSRect(x: 20, y: 205, width: 300, height: 25)
        seconds.frame = NSRect(x: 350, y: 205, width: 110, height: 25)
        button.frame = NSRect(x: 20, y: 155, width: 190, height: 35)
        button.target = self; button.action = #selector(toggle)
        status.frame = NSRect(x: 20, y: 20, width: 450, height: 125)
        for view in [label, seconds, button, status] { window.contentView?.addSubview(view) }
        let saved = UserDefaults.standard.double(forKey: "delay")
        if saved >= 1 && saved <= 60 { seconds.stringValue = String(saved); delay = saved }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Laser ○"
        let tray = NSMenu()
        let settings = NSMenuItem(title: "Instellingen", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self; tray.addItem(settings)
        let stopItem = NSMenuItem(title: "Uitschakelen", action: #selector(stop), keyEquivalent: "")
        stopItem.target = self; tray.addItem(stopItem)
        tray.addItem(.separator())
        tray.addItem(withTitle: "Afsluiten", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem.menu = tray
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.enabled, self.powerpoint != nil else { return }
            if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == 0x4C4148 { return }
            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
            // End-show keys suspend this session; the master switch stays on.
            if event.keyCode == 53 || key == "-" ||
                (event.modifierFlags.contains(.command) && [".", "q", "w"].contains(key)) {
                self.manualPointer = false
                self.waitForShow("Ingeschakeld — wacht op de volgende diavoorstelling.", retryAfter: 1)
            } else if event.modifierFlags.contains(.command) && ["a", "p", "i"].contains(key) {
                self.manualPointer = true
                self.waitForShow("Ingeschakeld — handmatige aanwijzer. Kies ⌘L om te hervatten.")
            } else if event.modifierFlags.contains(.command) && key == "l" {
                self.manualPointer = false
                self.waitForShow("Ingeschakeld — laser hervatten.", retryAfter: 0.3)
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
        window.center(); openSettings()
        if UserDefaults.standard.bool(forKey: "enabled") {
            enabled = true
            button.title = "Uitschakelen"
            statusItem.button?.title = "Laser ●"
            status.stringValue = "Ingeschakeld — wacht op een PowerPoint-diavoorstelling."
        }
    }

    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc func toggle() {
        if enabled { stop(); return }
        guard let value = Double(seconds.stringValue.replacingOccurrences(of: ",", with: ".")),
              value.isFinite, (1...60).contains(value) else {
            status.stringValue = "Vul een getal tussen 1 en 60 in."; return
        }
        guard AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) else {
            status.stringValue = "Geef LaserAutoHide toegang bij Systeeminstellingen → Privacy en beveiliging → Toegankelijkheid. Sluit en heropen de app daarna."
            return
        }
        delay = value; UserDefaults.standard.set(value, forKey: "delay")
        enabled = true; started = false; hidden = false
        manualPointer = false
        UserDefaults.standard.set(true, forKey: "enabled")
        button.title = "Uitschakelen"; statusItem.button?.title = "Laser ●"
        status.stringValue = "Ga naar je lopende PowerPoint-diavoorstelling. De laser wordt daar ingeschakeld. Sta de vraag om PowerPoint te bedienen toe."
        checkAt = 0
    }

    // Fail closed: never post presentation shortcuts unless PowerPoint itself
    // reports an active show. Unsupported dictionaries surface their exact error.
    func hasShow() -> Bool {
        scriptError = ""
        guard powerpoint != nil else { return false }
        let source = """
        with timeout of 2 seconds
            tell application id "com.microsoft.Powerpoint"
                return count of slide show windows
            end tell
        end timeout
        """
        guard let script = NSAppleScript(source: source) else {
            scriptError = "AppleScript kon niet worden aangemaakt."; return false
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error = error {
            scriptError = error.description; return false
        }
        return result.int32Value == 1
    }

    // HID keycodes are selected from the active keyboard layout for AZERTY too.
    func keyCode(for character: String) -> CGKeyCode? {
        guard let input = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let dataPointer = TISGetInputSourceProperty(input, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(dataPointer).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        for code in 0..<128 {
            var dead: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let result = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDown), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 4, &length, &chars)
            if result == noErr && String(utf16CodeUnits: chars, count: length).lowercased() == character {
                return CGKeyCode(code)
            }
        }
        return nil
    }

    @discardableResult func send(_ character: String) -> Bool {
        guard hasShow(), let app = powerpoint, AXIsProcessTrusted(),
              let code = keyCode(for: character),
              let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else { return false }
        down.flags = .maskCommand; up.flags = .maskCommand
        down.setIntegerValueField(.eventSourceUserData, value: 0x4C4148)
        up.setIntegerValueField(.eventSourceUserData, value: 0x4C4148)
        down.postToPid(app.processIdentifier); up.postToPid(app.processIdentifier)
        return true
    }

    func disable(_ message: String) {
        enabled = false; started = false; hidden = false
        manualPointer = false
        UserDefaults.standard.set(false, forKey: "enabled")
        button.title = "Inschakelen"; statusItem.button?.title = "Laser ○"
        status.stringValue = message
    }

    @objc func stop() {
        if hidden && powerpoint != nil { _ = send("l") }
        disable("Uitgeschakeld. Zo nodig toont ⌘L in de diavoorstelling de laser opnieuw.")
    }

    // Reset only the current show, never the user's persistent enable setting.
    func waitForShow(_ message: String, retryAfter: Double = 0.5) {
        started = false; hidden = false
        checkAt = ProcessInfo.processInfo.systemUptime + retryAfter
        last = ProcessInfo.processInfo.systemUptime
        point = NSEvent.mouseLocation
        status.stringValue = message
    }

    func tick() {
        guard enabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard let front = powerpoint else {
            if started { waitForShow("Ingeschakeld — wacht tot PowerPoint weer op de voorgrond staat.") }
            return
        }
        if lastPowerPointPID != front.processIdentifier {
            lastPowerPointPID = front.processIdentifier
            manualPointer = false
            waitForShow("Ingeschakeld — PowerPoint gevonden; wacht op diavoorstelling.", retryAfter: 0)
        }
        if !started && now < checkAt { return }
        guard AXIsProcessTrusted() else {
            waitForShow("Ingeschakeld — geef de app toegang tot Toegankelijkheid.", retryAfter: 3)
            return
        }
        if now >= checkAt {
            guard hasShow() else {
                if !scriptError.isEmpty {
                    waitForShow("Ingeschakeld — PowerPoint-controle mislukt; nieuwe poging volgt: " + scriptError, retryAfter: 5)
                } else {
                    manualPointer = false
                    waitForShow("Ingeschakeld — wacht op precies één actieve PowerPoint-diavoorstelling.", retryAfter: 0.5)
                }
                return
            }
            checkAt = now + 0.5
        }
        if manualPointer { return }
        if !started {
            guard send("l") else { waitForShow("Ingeschakeld — laser starten mislukt; nieuwe poging volgt: " + scriptError, retryAfter: 3); return }
            started = true; hidden = false; last = now; point = NSEvent.mouseLocation
            status.stringValue = "Laser actief. Verbergen na \(delay) seconden."
            return
        }
        let newPoint = NSEvent.mouseLocation
        let moved = newPoint != point
        point = newPoint
        if moved {
            last = now
            if hidden {
                guard send("l") else { waitForShow("Ingeschakeld — laser tonen mislukt; nieuwe poging volgt: " + scriptError, retryAfter: 3); return }
                hidden = false; status.stringValue = "Laser actief."
            }
        } else if !hidden && now - last >= delay {
            guard send("i") else { waitForShow("Ingeschakeld — laser verbergen mislukt; nieuwe poging volgt: " + scriptError, retryAfter: 3); return }
            hidden = true; status.stringValue = "Laser verborgen. Beweeg de muis om te tonen."
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        // Quitting the helper preserves the preference for the next launch.
        if hidden && powerpoint != nil { _ = send("l") }
        if let monitor = monitor { NSEvent.removeMonitor(monitor) }
    }
}

import Carbon
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
