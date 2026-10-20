# 🫧 UNIBODY · CAU Kiel Dual-Platform Kurs-Sniper & Stundenplan-Optimizer (WiSe 26/27)

**UNIBODY** ist die automatische Kurs- & Übungsgruppen-Einschreibung mit Echtzeit-Stundenplan-Optimierung für **Wirtschaftsinformatik (B.Sc.)** an der **Christian-Albrechts-Universität zu Kiel (CAU)** – gebaut im **Frutiger Aero** Design (inkl. *Deep Ocean Aurora Dark Mode*).

## Warum UNIBODY?
Als Wirtschaftsinformatiker an der CAU Kiel sind die Kurse über zwei getrennte Systeme verteilt:
1. **`lms.uni-kiel.de` (CAU OpenOlat)** – z. B. für *Einführung in die Wirtschaftsinformatik* (`infEWInf-01a`), *Mathematik für die Informatik A* (`Inf-Math-A`), *Einführung in die BWL* (`BWL-EinfBWL`) und *Informatikrecht* (`Inf-InfRecht`).
2. **`elearn.informatik.uni-kiel.de` (Informatik Moodle)** – z. B. für *Einführung in die Informatik* (`infEInf-02a` / `infEInf-01a`, Moodle Kurs-ID `470`).

**UNIBODY** vereint beide Welten: Du gibst deine `stu`-Kennung & dein Passwort **ein einziges Mal** im Tresor (macOS Schlüsselbund) ein, und **UNIBODY erkennt bei jedem Kurs vollautomatisch, auf welcher der beiden Plattformen er gelistet ist**, loggt dich auf beiden Seiten automatisch ein und steuert den richtigen Tab an!

## Features

- 🫧 **UNIBODY Auto-Router (`lms.uni-kiel.de` & `elearn.informatik.uni-kiel.de`):** Erkennt anhand von Modulcode, UnivIS-Kennung oder Live-XML automatisch das Ziel-System und wechselt selbstständig zwischen OpenOlat und Informatik-Moodle.
- 🔐 **macOS Keychain Account-Tresor & 1-Klick Auto-Login:** Speichert deine CAU `stu`-Zugangsdaten sicher im macOS Schlüsselbund und füllt Login-Masken in Chrome via CDP & eigener Chrome-Extension vollautomatisch aus.
- 🛡️ **Exakte CAU UnivIS (2026w) & Live-XML Verifikation:** Alle echten 6-stelligen UnivIS-Nummern (`080038`, `080042`, `080058`, `080056`, `060107`, `060098`, `030225`, `080103`) sowie Live-Abfragen gegen `univis.uni-kiel.de`.
- 🗓️ **Interaktiver Frutiger Aero Stundenplan:**
  - **Klick auf blauen Vorlesungs-Block** = Kurs sofort in Schritt 1 auswählen.
  - **Klick auf gestrichelten Übungs-Block** = Übungsgruppe sofort als **Wunsch #1** in Schritt 3 priorisieren.
- 🧹 **UnivIS `.ics` Smart-Import & Geistertermin-Filter:** Filtert Parallel-Übungs-Ballast aus UnivIS-Exporten automatisch heraus.

## Schnellstart

```bash
python3 server.py
```

Danach im Browser öffnen:
**[http://127.0.0.1:8765](http://127.0.0.1:8765)**
