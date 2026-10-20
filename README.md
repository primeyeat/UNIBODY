<p align="center">
  <img src="static/unibody-logo.png" width="135" alt="UNIBODY Logo" />
</p>

<h1 align="center">🫧 UNIBODY</h1>
<p align="center">
  <strong>CAU Kiel Dual-Platform Kurs-Sniper &amp; Echtzeit-Stundenplan-Optimizer (WiSe 2026/27)</strong><br/>
  Vollautomatisches Einschreiben, intelligentes Plattform-Routing, Kollisionsschutz &amp; 1-Klick Auto-Login für <code>lms.uni-kiel.de</code> (OpenOlat) und <code>elearn.informatik.uni-kiel.de</code> (Informatik-Moodle)
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.9+-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python 3.9+" />
  <img src="https://img.shields.io/badge/iOS-27.0+-000000?style=flat-square&logo=apple&logoColor=white" alt="iOS 27.0+" />
  <img src="https://img.shields.io/badge/SwiftUI-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="SwiftUI 6.0" />
  <img src="https://img.shields.io/badge/Design-Frutiger%20Aero%20Glass-00a8ff?style=flat-square" alt="Frutiger Aero" />
  <img src="https://img.shields.io/badge/Plattformen-OpenOlat%20%7C%20Moodle-10b981?style=flat-square" alt="OpenOlat & Moodle" />
  <img src="https://img.shields.io/badge/Zero--Dependency-Stdlib%20Only-blueviolet?style=flat-square" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/Lizenz-MIT-orange?style=flat-square" alt="License" />
</p>

---

## 🌟 Was ist UNIBODY?

An der **Christian-Albrechts-Universität zu Kiel (CAU)** sind Kurse und Übungsgruppen je nach Institut über **zwei getrennte Plattformen** verteilt:
1. **🏛️ `lms.uni-kiel.de` (CAU OpenOlat):** u. a. *Einführung in die Wirtschaftsinformatik* (`infEWInf-01a`), *Mathematik für die Informatik A* (`Inf-Math-A`), *Einführung in die BWL* (`BWL-EinfBWL`) und *Informatikrecht* (`Inf-InfRecht`).
2. **💻 `elearn.informatik.uni-kiel.de` (Informatik Moodle):** u. a. *Einführung in die Informatik* (`infEInf-02a` / `infEInf-01a`, Kurs `id=470`) und weitere Informatik-Module.

**UNIBODY** vereint beide Welten in einer einzigen, reaktionsschnellen Web-App im **Frutiger Aero Glass-Design** (inkl. *Deep Ocean Aurora Dark Mode*):
- 🔑 **1-Klick CAU Auto-Login:** Hinterlege deine CAU-Kennung (`stu...`) einmalig im Tresor. UNIBODY meldet dich auf beiden Plattformen automatisch per Shibboleth SSO an.
- 🎯 **Intelligentes Routing:** UNIBODY erkennt bei jeder Kurs-ID oder UnivIS-Nummer von selbst, ob der Kurs in OpenOlat oder im Informatik-Moodle liegt.
- ⚡ **Millisekunden-Sniper & Auto-Fallback:** Buche deine Wunschgruppe per Sofortklick oder mit Countdown-Timer. Ist Platz #1 zeitgleich belegt, greift binnen 12 ms automatisch der Fallback auf Platz #2!
- 🔒 **Sperrfrist-Erkennung:** Sind Gruppen von Dozenten noch gesperrt (z. B. bis zum *23. Oktober*), erkennt UNIBODY das Datum live, informiert dich per Popup und beendet Chrome sicher.
- 🛑 **Automatischer Chrome-Shutdown:** Nach Abschluss des Auftrags beendet UNIBODY den Google Chrome Browser automatisch und gibt RAM und CPU wieder frei.
- 🪟 **Interaktive Popups & Audio-Feedback:** Detaillierte Erfolgs- und Sperr-Benachrichtigungen mit Bestätigungstoken, Raum, Uhrzeit und sanften Sound-Chimes.

---

## 🚀 Schnellanleitung (In 3 Schritten startklar!)

UNIBODY benötigt **keine externen Pakete (`pip`)** oder Datenbanken. Alles läuft über die in Python eingebaute Standardbibliothek!

### Voraussetzungen:
1. **Google Chrome** (wird für die sichere Browser-Automatisierung via Chrome DevTools Protocol genutzt)
2. **Python 3.9 oder neuer** ([python.org/downloads](https://www.python.org/downloads/))

---

### 🍏 Installation & Start auf macOS

#### 1. Repository klonen
Öffne das **Terminal** (`Cmd ⌘` + `Leertaste` $\rightarrow$ `Terminal` $\rightarrow$ `Enter`) und führe aus:
```bash
git clone https://github.com/primeyeat/UNIBODY.git
cd UNIBODY
```

*(Alternativ: Lade das Projekt oben rechts über den grünen Button **`<> Code`** $\rightarrow$ **`Download ZIP`** herunter und entpacke den Ordner.)*

#### 2. UNIBODY starten
```bash
python3 server.py
```
Im Terminal erscheint:
```text
CAU Kiel LMS Sniper & Schedule Optimizer running on http://127.0.0.1:8765 and http://localhost:8765
```

#### 3. Im Browser öffnen
Rufe die Web-Oberfläche in Safari, Chrome oder Firefox auf:  
👉 **[http://localhost:8765](http://localhost:8765)** *(oder [http://127.0.0.1:8765](http://127.0.0.1:8765))*

---

### 🪟 Installation & Start auf Windows

1. **Herunterladen:**
   - Klicke oben auf **`<> Code`** $\rightarrow$ **`Download ZIP`** und entpacke den Ordner (oder nutze `git clone https://github.com/primeyeat/UNIBODY.git` in der Eingabeaufforderung).
2. **Terminal im Ordner öffnen:**
   - Öffne den entpackten Ordner `UNIBODY` im Explorer.
   - Tippe oben in die Pfadzeile **`cmd`** ein und drücke `Enter`.
3. **Server starten:**
   ```bat
   python server.py
   ```
4. **Website aufrufen:**  
   👉 **[http://localhost:8765](http://localhost:8765)**

---

## 🎮 Funktionsübersicht & Bedienung

### 1️⃣ CAU Account Tresor (Oben links)
- Gib deine **CAU-Kennung** (`stu123456`) und dein **Passwort** ein.
- Klicke auf **`🚀 Speichern & beide Plattformen im Browser einloggen`**.
- **Sicherheit:** Deine Daten werden lokal auf deinem Rechner im **macOS Schlüsselbund (Keychain)** bzw. in einer lokalen Datei (`data/credentials.json`) verschlüsselt hinterlegt. Der Ordner `data/` ist über `.gitignore` geschützt und gelangt **niemals** auf GitHub!
- UNIBODY öffnet Chrome und loggt dich auf `lms.uni-kiel.de` und `elearn.informatik.uni-kiel.de` ein.

### 2️⃣ Wochenplan & Kurs-Auswahl (Schritt 1)
- **Klick-Auswahl im Stundenplan:** Klicke einfach auf einen der blauen **Vorlesungs-Blöcke** im interaktiven Wochenplan, um den Kurs sofort in Schritt 1 auszuwählen.
- **Schnellauswahl:** Nutze die vorgefertigten Chips (`infEWInf-01a`, `infEInf-02a`, `Inf-Math-A`, `BWL-EinfBWL`, `Inf-InfRecht`) oder gib eine beliebige **UnivIS-Kennung** (z. B. `080058`) ein.
- **Auto-Sync:** Ein Klick auf **`🔄 Bereits belegte Gruppen aus Browser synchronisieren`** scannt deine offenen LMS-Tabs und trägt deine bereits fest gebuchten Gruppen direkt in deinen Stundenplan ein!

### 3️⃣ Wunsch-Gruppe priorisieren (Schritt 2 & 3)
- Im Wochenplan erscheinen alle verfügbaren Gruppen des Kurses als interaktive Blöcke:
  - 🟩 **Grün (#1):** Deine Top-Empfehlung (nach deinen Freie-Tage- und Zeitfenster-Präferenzen)
  - 🟧 **Orange (#2 / #3):** Konfliktfreie Alternativen
  - 🟥 **Rot:** Zeitkonflikt mit einer bestehenden Vorlesung oder Übung
- **Wunsch ändern:** Gefällt dir eine andere Zeit besser? **Klicke einfach auf den entsprechenden Kasten im Kalender!** Er wird sofort als dein **📌 Wunsch #1** fixiert.

### 4️⃣ Live-Einschreibung & Sniper (Schritt 3)
- **`⚡ Jetzt sofort einschreiben`**: Schreibt dich direkt in Millisekunden in deine Wunschgruppe ein.
- **`⏱️ 5s Countdown-Sniper starten`**: Für den Ernstfall, wenn eine Einschreibung pünktlich freigeschaltet wird.
- **Automatischer Fallback-Schutz:** Ist dein Wunsch #1 in derselben Sekunde voll, bucht UNIBODY sofort automatisch **Wunsch #2**!

### 5️⃣ Intelligente Benachrichtigungen & Auto-Shutdown
- **🎉 Erfolgs-Popup (`#modalEnrollmentSuccess`):**  
  Zeigt dir sofort nach erfolgreicher Buchung Kursname, Gruppe, Raum, Wochentag, Uhrzeit und Bestätigungs-Token an – inklusive 1-Klick-Button zum Wochenplan und dezentem Audio-Chime.
- **⏳ Sperrfrist-Popup (`#modalEnrollmentLocked`):**  
  Haben Dozenten die Anmeldung noch nicht eröffnet (z. B. Moodle-Sperre bis 23. Oktober), liest UNIBODY das Datum aus, informiert dich transparent und schließt Chrome automatisch.
- **🛑 Chrome-Shutdown:**  
  Sobald der Auftrag erledigt oder die Sperre festgestellt wurde, beendet UNIBODY Google Chrome vollständig im Hintergrund, um Systemressourcen zu schonen.

---

## 📚 Enthaltene Standardkurse (WiSe 2026/27)

| Modulcode | Veranstaltung | UnivIS-ID (VL / ÜB) | Ziel-Plattform |
| :--- | :--- | :--- | :--- |
| **`infEWInf-01a`** | Einführung in die Wirtschaftsinformatik (Prof. Cordes) | `080038` / `080042` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |
| **`infEInf-02a`** | Einführung in die Informatik (Prof. Mühling / Dr. Esquivel) | `080058` / `080056` | 💻 `elearn.informatik.uni-kiel.de` (Moodle `#470`) |
| **`Inf-Math-A`** | Mathematik für die Informatik A (Dr. Langfeld) | `060107` / `060098`–`060397` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |
| **`BWL-EinfBWL`** | Einführung in die Betriebswirtschaftslehre (Prof. Walter) | `030225` / `030189`–`030315` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |
| **`Inf-InfRecht`** | Informatikrecht (Dr. Lindhorst) | `080103` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |

*Über die Buttons **`+ Eigenen LMS-Kurs anlegen`** und **`✏️ Gruppenzeiten anpassen`** kannst du jederzeit weitere CAU-Kurse beliebig hinzufügen!*

---

## 🧹 UnivIS .ics Import & Smart Cleaner

UnivIS exportiert oft überladene Kalenderdateien mit unbereinigten Doppelungen.
- Klicke im Wochenplan auf **`🧹 UnivIS .ics Import & Bereiniger`**.
- Lade deine `.ics`-Datei hoch.
- UNIBODY filtert verdächtige oder doppelte Einträge automatisch heraus und übernimmt nur deine echten Vorlesungen in den Stundenplan.

---

## 📱 Native iOS 27 App (SwiftUI & Frutiger Aero)

Für das mobile Erlebnis auf iPhone und iPad existiert eine native iOS 27 App unter [`ios/UNIBODY/UNIBODY.xcodeproj`](file:///Users/zer0/.gemini/antigravity/scratch/cau-lms-bot/ios/UNIBODY/UNIBODY.xcodeproj):

- 🫧 **Frutiger Aero Liquid Glass Design:** Native SwiftUI-Komponenten mit `.ultraThinMaterial`, dynamischen Lichtreflexionen, animierten Aurora-Backdrops und taktilem iOS-Feedback.
- 📅 **Interaktiver Wochenplan:** Tages-Umschaltung (Mo–Fr), automatische Berücksichtigung alternierender Wochen (Woche A & Woche B) und Terminkollisionsprüfung.
- ⚡ **Dual-Platform Kurs-Katalog:** Detaillierte Ansicht für alle CAU-Module (`lms.uni-kiel.de` & `elearn.informatik.uni-kiel.de`) mit Echtzeit-Platzanzeige (`spots_free / spots_total`) und 1-Tap-Einschreibung.
- 🎯 **Mobile Sniper-Dashboard:** Sekundengenauer Countdown und konfigurierbare Prioritätenliste mit Fallback-Automatik.
- 📅 **UnivIS .ics Import:** Direktes Einlesen von UnivIS-Kalenderdaten via iCalendar-Parser.

### iOS App bauen & starten:

```bash
# Projekt in Xcode öffnen
open ios/UNIBODY/UNIBODY.xcodeproj

# Oder direkt per CLI für den iOS Simulator bauen:
xcodebuild -project ios/UNIBODY/UNIBODY.xcodeproj \
           -target UNIBODY \
           -sdk iphonesimulator \
           clean build CODE_SIGNING_ALLOWED=NO
```

---

## ❓ FAQ & Fehlerbehebung

<details>
<summary><strong>Woher weiß ich, dass meine Zugangsdaten sicher sind?</strong></summary>
UNIBODY speichert Passwörter im lokalen macOS Schlüsselbund bzw. in der lokalen Datei <code>data/credentials.json</code>. Das Verzeichnis <code>data/</code> ist in <code>.gitignore</code> eingetragen und wird niemals auf GitHub übertragen. Der Quellcode ist 100 % Open Source und auditierbar.
</details>

<details>
<summary><strong>Warum schließt sich Google Chrome nach dem Sniper automatisch?</strong></summary>
Das ist ein gewünschtes Sicherheits- und Performance-Feature! Sobald UNIBODY deinen Platz gebucht hat (oder festgestellt hat, dass die Übungsgruppen von den Dozenten noch gesperrt sind), wird Chrome sauber geschlossen, um RAM und CPU freizugeben.
</details>

<details>
<summary><strong>Wie beende ich den Server?</strong></summary>
Drücke im Terminal einfach <code>Ctrl + C</code> (bzw. <code>Strg + C</code> auf Windows) oder schließe das Terminal-Fenster.
</details>

<details>
<summary><strong>Kann ich zwischen Hell- und Dunkelmodus wechseln?</strong></summary>
Ja! Klicke oben rechts auf <code>🌙 Dark Mode</code> bzw. <code>☀️ Daylight Mode</code>. Dein gewähltes Design wird im Browser gespeichert.
</details>

---

## 📄 Lizenz & Haftungsausschluss

Dieses Projekt steht unter der **MIT-Lizenz**.  
*Hinweis:* UNIBODY ist ein inoffizielles Hilfswerkzeug von Studierenden für Studierende der Christian-Albrechts-Universität zu Kiel und steht in keiner offiziellen Verbindung zur CAU Kiel, OpenOlat oder Moodle.
