# CAU Kiel · LMS Kurs-Sniper & Stundenplan-Optimizer (WiSe 26/27)

Automatisierte Kurs- & Übungsgruppen-Einschreibung mit Echtzeit-Stundenplan-Optimierung für **Wirtschaftsinformatik (B.Sc.)** an der **Christian-Albrechts-Universität zu Kiel (CAU)** (`lms.uni-kiel.de` / OpenOlat & Moodle).

## Features

- 🛡️ **Strikte Kurs-ID- & Modulcode-Verifikation:** Prüft exakte Modulcodes (`infEWInf-01a`, `infEInf-01a`, `Inf-Math-A`, `BWL-EinfBWL`, `Inf-InfRecht`), UnivIS-Kennnummern oder OpenOlat-Repository-IDs und blockiert ungenaue Namens-Treffer, damit niemals ein falscher Kurs gewählt wird.
- 🧮 **Echtzeit-Stundenplan-Optimizer:** Berechnet die bestmögliche Übungsgruppe anhand einstellbarer Gewichtungen:
  - Minimale Freistunden / kompakte Uni-Tage (inkl. 15 Min. c.t. Pause)
  - Komplette Freihaltung von Wunsch-Tagen
  - Einhaltung deines Wunsch-Zeitfensters (z. B. `09:30` – `16:30`)
  - Campus-Raumwechsel-Puffer
- 🧹 **UnivIS `.ics` Smart-Import & Geistertermin-Filter:** Erkennt beim Import von CAU UnivIS-Kalenderdateien automatisch die typischen Parallel-Übungs-Platzhalter und wählt sie vorab ab.
- ⚡ **Dual-Mode Einschreibung:**
  - **First-Come-First-Served Sniper:** Feuert sofort oder per Countdown auf Platz #1 und springt in Millisekunden automatisch auf Platz #2 (Fallback), falls Platz #1 voll ist.
  - **Verteilungsverfahren (Prioritäten 1–3):** Überträgt automatisch das berechnete Top-3-Ranking.
- 🌐 **CAU Shibboleth SSO Integration:** Startet ein sichtbares Chrome-Fenster mit persistentem Profil für den sicheren Login mit `stu...`-Kennung & 2FA.

## Schnellstart

```bash
python3 server.py
```

Danach im Browser öffnen:
**[http://127.0.0.1:8765](http://127.0.0.1:8765)**
