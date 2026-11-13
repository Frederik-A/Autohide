# Laser Auto Hide Mac v0.2 — ingeschakeld blijven

Deze versie behoudt de werkende laserbediening van v0.1, maar scheidt de aan/uit-
keuze van de huidige diavoorstelling. Je hoeft niet na iedere presentatie opnieuw
op Inschakelen te klikken.

## Bijwerken

1. Sluit de oude LaserAutoHide af via **Laser → Afsluiten**.
2. Pak de ZIP uit en open **Build.command** zoals bij de vorige versie.
3. Vervang de oude **LaserAutoHide.app** in Programma's door de nieuw gebouwde app.
4. Open de nieuwe app en klik eenmalig op **Inschakelen**.
5. Laat de helper draaien. Het instellingenvenster mag je sluiten.

De Apple Command Line Tools zijn nodig om te bouwen. Als Build.command niet start,
typ dan `bash ` in Terminal, sleep het bestand erachter en druk op Return.
Na het vervangen kan macOS opnieuw toegang vragen voor Toegankelijkheid en
Automatisering/PowerPoint. Geef die zo nodig opnieuw en heropen de helper.

## Nieuw gedrag

- Einde diavoorstelling / Escape: blijft ingeschakeld en wacht op de volgende show.
- Andere presentatie: hervat automatisch zodra die diavoorstelling actief wordt.
- Andere app: pauzeert; hervat wanneer PowerPoint weer vooraan staat.
- PowerPoint afsluiten: de helper blijft draaien en wacht. PowerPoint wordt niet
  automatisch geopend. Na het zelf heropenen en starten van een show hervat hij.
- Helper afsluiten en heropenen: onthoudt aan/uit en wachttijd.
- Alleen **Uitschakelen** zet de bewaarde aan/uit-keuze uit.
- Een tijdelijk mislukte PowerPoint-controle schakelt de helper niet permanent uit;
  hij toont de fout en probeert later opnieuw. Ontbrekende toestemming blijft een
  zichtbare blokkade totdat je die zelf verleent.

Bij een nieuwe show selecteert de ingeschakelde helper zelf de ingebouwde laser.
De standaard wachttijd blijft 4 seconden; instelbaar van 1 tot 60 seconden.
Om die te wijzigen: Uitschakelen, waarde aanpassen, Inschakelen.

Handmatig ⌘A (pijl), ⌘P (pen) of ⌘I (verbergen) pauzeert de laserbediening voor
de huidige show. ⌘L hervat. Bij het waargenomen einde van de show wordt die pauze
gewist. Contextmenu-aanwijzerkeuzes worden nog niet teruggelezen; schakel de helper
uit als je via dat menu een andere aanwijzer wilt gebruiken.

De helper moet draaien: na een Mac-herstart start deze versie niet automatisch
mee met macOS. Bij handmatig openen wordt de bewaarde aan/uit-keuze hersteld.
Een gewone PowerPoint-herstart vereist geen herstart of klik in de helper.

## Kort testen

1. Schakel in, start presentatie A, controleer verbergen en tonen.
2. Druk Escape. Open/start presentatie B zonder de helper te bedienen.
3. Sluit PowerPoint volledig en open het opnieuw. Start een show en test opnieuw.
4. Wissel even naar een andere app en terug naar de diavoorstelling.
5. Sluit en heropen de helper: Ingeschakeld moet onthouden zijn.
6. Klik Uitschakelen, heropen de helper: Uitgeschakeld moet ook onthouden zijn.

Deze update is op broncode-, plist- en bouwscriptsyntax gecontroleerd. Compilatie
en de nieuwe overgangen zijn hier niet op macOS/PowerPoint uitgevoerd. De eerdere
v0.1-laserbediening is door jou als werkend bevestigd. Bij een probleem: stuur de
statusmelding en beschrijf welke wissel of herstart eraan voorafging.

## Windows

De Windows PowerPoint-plug-in v0.2 heeft het normale hervatten al ingebouwd:
SlideShowBegin start de timer, SlideShowEnd stopt alleen de huidige timer; de
aan/uit-keuze blijft bewaard. De installatie registreert automatisch laden bij
een volgende PowerPoint-start. Geen Windows-update nodig voor dit gedrag.
De Windows-plug-in wacht wel tot je in PowerPoint zelf de laser kiest (Ctrl+L).
Deze conclusie is gebaseerd op broncodecontrole, niet op een Windows-praktijktest.
