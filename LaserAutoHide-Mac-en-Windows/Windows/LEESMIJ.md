# Laser Auto Hide Windows helper v0.3.3

## Correctie voor terugkerende laser / zichtbare pijl

v0.3.3 herstelt de regressie uit v0.3.2. De eerder werkende tweestaps-verbergactie
is teruggezet. De stabiele identificatie en automatische pijlstand blijven behouden.
Dit voorkomt niet gegarandeerd een kort zichtbare pijl tussen de twee API-aanroepen;
eerst moet bevestigd worden dat de laser verborgen blijft en bij beweging terugkomt.

Deze versie gebruikt de volgende pointerbediening:
- Schakelt de laser uit en zet vervolgens PointerType=3 (verborgen). Alleen
  PointerType=3 bleek bij jouw PowerPoint de laser niet te verbergen.
- Schrijft nooit meer PointerType=1 (pijl altijd zichtbaar).
- Bij beweging: PointerType=4 (automatische pijl) en vervolgens de laser aan.
- Een blijvend True teruggelezen laserflag start tijdens verbergen geen nieuwe cyclus.
- Verlies van voorgrondfocus toont de verborgen laser niet automatisch.
- Een opnieuw aangemaakt COM-View-object start geen nieuwe sessie: de presentatie
  en het show-indexnummer bepalen nu een stabiele sleutel. Alleen een hash van
  die sleutel wordt in de diagnose getoond; geen presentatiepad of -naam.

## Gebruiken

1. Sluit de vorige helper volledig. Laat de plug-in uit tijdens deze test.
2. Pak de ZIP uit en open Start.cmd.
3. Schakel in, start de diavoorstelling, kies de laser met Ctrl+L.
4. Blijf in PowerPoint en houd de muis minstens 15 seconden stil. De laser moet na
   de ingestelde 4 seconden verdwijnen en verborgen blijven.
5. Beweeg: de laser moet terugkomen. Na opnieuw 4 seconden stilstand verdwijnt hij.

Na handmatig uitschakelen of afsluiten van de helper wordt een door de helper
verborgen laser zo mogelijk ook hersteld. Wisselen naar een andere app pauzeert de
bewaking. De helper moet blijven draaien; hij wacht automatisch op volgende shows.
Beweging op beide schermen telt als beweging. Een bewust gekozen pen of pijl wordt
niet overgenomen. Gebruik niet meerdere PowerPoint-processen tegelijkertijd.

Bij uitschakelen/herstellen gaat de pijlstand naar Automatisch. Tijdens verbergen
wordt intern Altijd verbergen gebruikt: dat is nodig voor de verborgen pointer.

## Diagnose

Bij afwijkend gedrag: klik Diagnose kopieren en plak de volledige tekst.
Nieuw: de eigen verborgen-status en de laatste pointeractie met tijdstip.
Zo is zichtbaar of de helper zelf opnieuw toont of PowerPoint dat doet.
De Windows-focus wordt via het POWERPNT-proces gecontroleerd; de ontbrekende
SlideShowWindow.HWND uit de eerdere foutmelding wordt niet gebruikt.

## Teststatus

PowerShell-syntax en vensterselectie getest. De echte Update-Laser-functie is met
nagebootste PowerPoint-eigenschappen getest op: 20 seconden stilstand (exact één
verbergactie), laserflag blijft True terwijl verborgen, tonen bij beweging,
automatische pijlstand, volgende verbergcyclus, handmatige pen en stabiele sleutel
bij opnieuw aangemaakt View-object. Die tests slagen.

Niet hier getest: visuele werking in Windows PowerPoint. De testobjecten bewijzen
niet hoe jouw PowerPoint-versie de pointerinstellingen daadwerkelijk weergeeft.
