$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Native {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
'@
$script:ppt = $null
$script:view = $null
$script:hidden = $false
$script:enabled = $false
$script:watch = [Diagnostics.Stopwatch]::StartNew()
$script:last = 0.0
$script:point = [Windows.Forms.Cursor]::Position
$script:viewKey = 0
$script:retryAt = 0.0
$script:report = 'Nog geen verbinding.'
$script:wasLaser = $false
$script:lastAction = 'Nog geen pointeractie.'
$form = New-Object Windows.Forms.Form
$form.Text = 'Laser Auto Hide - Windows helper v0.3.3'
$form.ClientSize = New-Object Drawing.Size(670,440)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$label = New-Object Windows.Forms.Label
$label.Text = 'Verberg de laser na (seconden):'
$label.SetBounds(20,20,290,25)
$delay = New-Object Windows.Forms.NumericUpDown
$delay.Minimum = 1; $delay.Maximum = 60; $delay.Value = 4
$delay.SetBounds(325,18,110,28)
$toggle = New-Object Windows.Forms.Button
$toggle.Text = 'Inschakelen'
$toggle.SetBounds(20,60,180,35)
$status = New-Object Windows.Forms.Label
$status.Text = 'Uitgeschakeld.'
$status.SetBounds(20,110,630,70)
$diagnostics = New-Object Windows.Forms.TextBox
$diagnostics.Multiline = $true
$diagnostics.ReadOnly = $true
$diagnostics.ScrollBars = 'Vertical'
$diagnostics.SetBounds(20,190,630,180)
$copy = New-Object Windows.Forms.Button
$copy.Text = 'Diagnose kopieren'
$copy.SetBounds(20,385,180,32)
$copy.Add_Click({
    $header = 'LaserAutoHide Windows helper 0.3.3' + [Environment]::NewLine +
        'PowerShell: ' + $PSVersionTable.PSVersion + '; proces 64-bit: ' + [Environment]::Is64BitProcess + [Environment]::NewLine
    [Windows.Forms.Clipboard]::SetText($header + $script:report + [Environment]::NewLine + $status.Text)
})
$form.Controls.AddRange(@($label,$delay,$toggle,$status,$diagnostics,$copy))

function Select-Show($candidates, $previousKey, $ownHidden) {
    # Presenter View may expose a different window from the audience view.
    # Never demand exactly one item; select the window reporting a laser.
    if ($ownHidden) {
        foreach ($candidate in $candidates) {
            if ($candidate.Key -eq $previousKey) { return $candidate }
        }
    }
    foreach ($candidate in $candidates) {
        if ($candidate.Laser -and $candidate.Key -eq $previousKey) { return $candidate }
    }
    foreach ($candidate in $candidates) {
        if ($candidate.Laser) { return $candidate }
    }
    foreach ($candidate in $candidates) {
        if ($candidate.Key -eq $previousKey) { return $candidate }
    }
    foreach ($candidate in $candidates) { return $candidate }
    return $null
}
function Get-ViewKey($window, $index) {
    # View can be re-created internally when pointer mode changes. Use a stable
    # presentation identifier instead; never put file names in diagnostics.
    $text = [string]$window.Presentation.FullName + '|' + [string]$index
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))) }
    finally { $hash.Dispose() }
}
function Set-SelectedView($selected) {
    # Always initialize a missing view, even if its key equals the sentinel.
    if ($null -eq $script:view -or $script:viewKey -ne $selected.Key) {
        Restore-Pointer
        $script:view = $selected.View
        $script:viewKey = $selected.Key
        $script:wasLaser = $false
        $script:last = $script:watch.Elapsed.TotalSeconds
    }
}
function Restore-Pointer {
    if ($script:hidden -and $null -ne $script:view) {
        try {
            # Only undo our own hidden state; preserve a manually chosen pen/arrow.
            if ([int]$script:view.PointerType -notin @(1,2,4,5)) {
                $script:view.PointerType = 4
                $script:view.LaserPointerEnabled = $true
                $script:lastAction = 'Tonen: ' + $script:watch.Elapsed.TotalSeconds.ToString('F2') + ' s'
            }
        } catch { }
    }
    $script:hidden = $false
}
function Update-Laser($now, $moved, $seconds) {
    if ($moved) { $script:last = $now }
    if ($script:hidden) {
        # A getter may keep reporting LaserPointerEnabled=True even though the
        # pointer is hidden. Do not use that flag to re-arm the idle cycle.
        if ([int]$script:view.PointerType -in @(1,2,4,5)) {
            $script:hidden = $false
            $script:wasLaser = $false
            $script:last = $now
        } elseif ($moved) {
            Restore-Pointer
            $script:wasLaser = $true
        }
        return
    }
    if (-not $script:view.LaserPointerEnabled) {
        $script:wasLaser = $false
        $script:last = $now
        return
    }
    if (-not $script:wasLaser) { $script:last = $now }
    $script:wasLaser = $true
    if (($now - $script:last) -ge $seconds) {
        # Laser visibility and arrow visibility are separate in this host.
        # Keep the previously working two-step hide; do not re-arm while hidden.
        try {
            $script:view.LaserPointerEnabled = $false
            $script:view.PointerType = 3
            $script:hidden = $true
            $script:lastAction = 'Verbergen (laser uit + pointer verborgen): ' + [string]$now + ' s'
        } catch {
            $failure = $_
            try { $script:view.PointerType = 4; $script:view.LaserPointerEnabled = $true } catch {}
            $script:hidden = $false
            throw $failure
        }
    }
}
$toggle.Add_Click({
    $script:enabled = -not $script:enabled
    if ($script:enabled) {
        $toggle.Text = 'Uitschakelen'
        $script:last = $script:watch.Elapsed.TotalSeconds
        $status.Text = 'Start de diavoorstelling en kies de laserpointer (Ctrl+L).'
    } else {
        Restore-Pointer
        $toggle.Text = 'Inschakelen'
        $status.Text = 'Uitgeschakeld.'
    }
})
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 50
$timer.Add_Tick({
    if (-not $script:enabled) { return }
    if ($script:watch.Elapsed.TotalSeconds -lt $script:retryAt) { return }
    try {
        if ($null -eq $script:ppt) {
            $script:ppt = [Runtime.InteropServices.Marshal]::GetActiveObject('PowerPoint.Application')
        }
        $count = [int]$script:ppt.SlideShowWindows.Count
        [uint32]$frontPid = 0
        [void][Native]::GetWindowThreadProcessId([Native]::GetForegroundWindow(), [ref]$frontPid)
        $lines = @('PowerPoint-versie: ' + $script:ppt.Version)
        $lines += 'Open presentaties: ' + $script:ppt.Presentations.Count
        $lines += 'SlideShowWindows.Count: ' + $count
        $lines += 'Verborgen door helper: ' + $script:hidden
        $lines += 'Laatste pointeractie: ' + $script:lastAction
        $lines += 'Voorgrond-proces-ID: ' + $frontPid
        # ROT can point to another PowerPoint instance: pause if ambiguous.
        $processes = @(Get-Process POWERPNT -ErrorAction SilentlyContinue)
        $lines += 'PowerPoint-processen: ' + $processes.Count
        if ($processes.Count -gt 1) {
            $script:last = $script:watch.Elapsed.TotalSeconds
            $script:wasLaser = $false
            $script:report = $lines -join [Environment]::NewLine
            $diagnostics.Text = $script:report
            $status.Text = 'Meerdere PowerPoint-processen. Sluit overige instanties en probeer opnieuw.'
            return
        }
        $candidates = @()
        for ($i = 1; $i -le $count; $i++) {
            try {
                $window = $script:ppt.SlideShowWindows.Item($i)
                $view = $window.View
                $laser = [bool]$view.LaserPointerEnabled
                $key = Get-ViewKey $window $i
                $lines += "Venster ${i}: view-ID=$key; laser=$laser; pointer=$($view.PointerType); state=$($view.State)"
                $candidates += [pscustomobject]@{ Window=$window; View=$view; Key=$key; Laser=$laser }
            } catch {
                $lines += "Venster ${i}: leesfout: $($_.Exception.Message)"
            }
        }
        $selected = Select-Show $candidates $script:viewKey $script:hidden
        if ($null -ne $selected) { $lines += 'Geselecteerd view-ID: ' + $selected.Key }
        $script:report = $lines -join [Environment]::NewLine
        if ($diagnostics.Text -ne $script:report) { $diagnostics.Text = $script:report }
        if ($null -eq $selected) {
            Restore-Pointer
            $script:view = $null; $script:viewKey = 0
            $script:wasLaser = $false
            if ($count -eq 0) {
                $status.Text = 'PowerPoint meldt 0 diavoorstellingen. Start de show. Loopt die al? Kopieer de diagnose.'
                # Reconnect instead of holding on indefinitely to an idle instance.
                $script:ppt = $null
            } else {
                $status.Text = 'PowerPoint meldt vensters, maar ze konden niet worden uitgelezen. Kopieer de diagnose.'
            }
            $script:retryAt = $script:watch.Elapsed.TotalSeconds + 1
            return
        }
        Set-SelectedView $selected
        # SlideShowWindow.HWND may be absent/null. Never use it for focus or identity.
        $frontName = ''
        try { $frontName = [Diagnostics.Process]::GetProcessById([int]$frontPid).ProcessName } catch {}
        $now = $script:watch.Elapsed.TotalSeconds
        $point = [Windows.Forms.Cursor]::Position
        if ($frontName -ine 'POWERPNT') {
            $script:last = $now; $script:point = $point
            $script:wasLaser = $false
            $status.Text = 'Gepauzeerd: PowerPoint staat niet op de voorgrond.'
            return
        }
        $moved = $point.X -ne $script:point.X -or $point.Y -ne $script:point.Y
        $script:point = $point
        if ($moved) { $script:last = $now }
        Update-Laser $now $moved ([double]$delay.Value)
        if (-not $script:hidden -and -not $script:view.LaserPointerEnabled) {
            $status.Text = 'Kies Laserpointer in PowerPoint (Ctrl+L). Pen en pijl blijven vrij.'
            return
        }
        if ($script:hidden) { $status.Text = 'Laser verborgen - beweeg de muis om te tonen.' }
        else { $status.Text = 'Laser actief - wordt automatisch verborgen na ' + $delay.Value + ' s.' }
    } catch {
        $script:ppt = $null
        $script:wasLaser = $false
        $script:retryAt = $script:watch.Elapsed.TotalSeconds + 1
        $status.Text = 'Wacht op PowerPoint / verbindingsfout: ' + $_.Exception.Message
        $script:report += [Environment]::NewLine + $status.Text
        $diagnostics.Text = $script:report
    }
})
$form.Add_FormClosing({ $timer.Stop(); Restore-Pointer })
$timer.Start()
[void]$form.ShowDialog()
$timer.Dispose(); $form.Dispose()
