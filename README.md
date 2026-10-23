<p align="center">
  <img src="static/unibody-logo.png" width="135" alt="UNIBODY Logo" />
</p>

<h1 align="center">🫧 UNIBODY</h1>
<p align="center">
  <strong>CAU Kiel Dual-Platform Kurs-Sniper &amp; Intelligenter Stundenplan-Optimizer (WiSe 2026/27)</strong><br/>
  Vollautomatisches Einschreiben, Live-UnivIS-Scraping, Kollisionsschutz &amp; 1-Klick Auto-Login für <code>lms.uni-kiel.de</code> (OpenOlat) und <code>elearn.informatik.uni-kiel.de</code> (Informatik-Moodle)
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.9+-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python 3.9+" />
  <img src="https://img.shields.io/badge/iOS-27.0+-000000?style=flat-square&logo=apple&logoColor=white" alt="iOS 27.0+" />
  <img src="https://img.shields.io/badge/SwiftUI-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="SwiftUI 6.0" />
  <img src="https://img.shields.io/badge/Themes-4%20Styles-ff71ce?style=flat-square" alt="4 Themes" />
  <img src="https://img.shields.io/badge/Plattformen-OpenOlat%20%7C%20Moodle-10b981?style=flat-square" alt="OpenOlat & Moodle" />
  <img src="https://img.shields.io/badge/Zero--Dependency-Stdlib%20Only-blueviolet?style=flat-square" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/Lizenz-MIT-orange?style=flat-square" alt="License" />
</p>

---

## 🌟 Was ist UNIBODY?

An der **Christian-Albrechts-Universität zu Kiel (CAU)** sind Lehrveranstaltungen und Übungsgruppen je nach Institut über **zwei getrennte Portale** verteilt:
1. **🏛️ `lms.uni-kiel.de` (CAU OpenOlat):** u. a. *Einführung in die Wirtschaftsinformatik* (`infEWInf-01a`), *Mathematik für die Informatik A* (`Inf-Math-A`), *Einführung in die BWL* (`BWL-EinfBWL`) und *Informatikrecht* (`Inf-InfRecht`).
2. **💻 `elearn.informatik.uni-kiel.de` (Informatik Moodle):** u. a. *Einführung in die Informatik* (`infEInf-02a` / `infEInf-01a`, Kurs `id=470`) und weitere Informatik-Module.

**UNIBODY** vereint beide Lernplattformen in einer einzigen, performanten Anwendung:
- 🔑 **1-Klick CAU Auto-Login:** Hinterlege deine CAU-Kennung (`stu...`) einmalig im sicheren Tresor. UNIBODY meldet dich auf beiden Plattformen automatisch per Shibboleth SSO an.
- 🎯 **Intelligentes Dual-Routing:** UNIBODY erkennt anhand der Modul-ID oder UnivIS-Nummer selbstständig, ob eine Veranstaltung in OpenOlat oder im Moodle liegt.
- ⚡ **First-Come-First-Served Sniper:** Beim Anmeldestart zählt jede Millisekunde. UNIBODY navigiert via Chrome DevTools Protocol (CDP) blitzschnell zu deiner Wunschgruppe, bestätigt den Platz und sichert dir deinen Favoriten vor dem Server-Crash.
- 🔄 **UNIBODY Deep-Sync:** Liest deine bereits fest gebuchten Übungen live aus OpenOlat und Moodle aus und trägt sie kollisionsfrei in deinen Stundenplan ein.
- 📅 **Echtes Semester-Management:** 8-Wochen-Vorschau (KW 42–49), Unterstützung für alternierende 14-tägige Vorlesungen (Woche A / Woche B) und sekundengenauer Echtzeit-Tagesstrahl.
- 📍 **Apple Maps Campus Resolver:** Punktgenaue Gebäude- und Hörsaal-Verortung für alle CAU-Räume (OS 75, CAP 3, Audimax, LMS 8 etc.) mit echten GPS-Koordinaten.

---

## 🎨 4 Wählbare Design-Themen (Light & Dark Mode)

In den Einstellungen (`⚙️ Einstellungen`) kannst du das Interface an deinen persönlichen Stil anpassen. Jedes Design verfügt über eine maßgeschneiderte **Light-** und **Dark-Mode**-Palette:

| Theme | Stil & Inspiration | Light Mode Palette | Dark Mode Palette |
| :--- | :--- | :--- | :--- |
| 🫧 **Frutiger Aero** *(Default)* | 2000er Windows 7 Aero Glass, Aqua & Eco-Tech | Sanftes Himmelblau, Milchglas, glänzende Gel-Buttons, Cyan- & Lime-Glow | **Deep Ocean Night:** Meeresblau-Schwarz (`#031529`), glühende Cyan-Ränder |
| 🍏 **Cupertino Minimal** | Modern Apple macOS Sonoma & iOS 18 | Edles Studio-Offwhite (`#f5f5f7`), ultra-feine Unschärfen, System-Blau | **Space Grey OLED:** Tiefschwarz (`#000000`), samtige Frosted Cards |
| 🌿 **Botanischer Garten** | Campus Nord / CAU Botanischer Garten | Beruhigendes Salbei- & Smaragdgrün (`#064e3b`), frische Frühlingsakzente | **Deep Jungle:** Tiefdunkles Waldgrün (`#03140c`), biolumineszenter Schimmer |
| 🌴 **Vaporwave Sunset** | Retro 80s/90s Synthwave & Neon Outrun | Zartes Pastell-Peach, Flieder & Flamingo-Pink | **Cyber Synthwave:** Mitternachtsviolett (`#0c021f`), leuchtendes Neon-Magenta & Cyan |

---

## 🚀 Schnellanleitung (In 3 Schritten startklar!)

UNIBODY benötigt **keine externen Pakete (`pip`)** oder Datenbanken. Alles läuft über die Standardbibliothek von Python!

### Voraussetzungen:
1. **Google Chrome** (wird für die Headless-/CDP-Automatisierung verwendet)
2. **Python 3.9 oder neuer** ([python.org/downloads](https://www.python.org/downloads/))

---

### 🍏 Installation & Start auf macOS

#### 1. Repository klonen
Öffne das **Terminal** (`Cmd ⌘` + `Leertaste` $\rightarrow$ `Terminal` $\rightarrow$ `Enter`):
```bash
git clone https://github.com/primeyeat/UNIBODY.git
cd UNIBODY
```

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
   - Klicke oben auf **`<> Code`** $\rightarrow$ **`Download ZIP`** und entpacke den Ordner (oder nutze `git clone https://github.com/primeyeat/UNIBODY.git`).
2. **Terminal im Ordner öffnen:**
   - Öffne den entpackten Ordner im Explorer, tippe in die Pfadzeile **`cmd`** ein und drücke `Enter`.
3. **Server starten:**
   ```bat
   python server.py
   ```
4. **Website aufrufen:**  
   👉 **[http://localhost:8765](http://localhost:8765)**

---

## 🎮 Funktionsübersicht & Bedienung

### 🍔 Navigation im Hamburger-Menü
Über den 3-Balken-Button oben links erreichst du die drei Kernbereiche:
1. **🎓 Stundenplan & Kurse (Landing Page):**  
   Schritt 1 (Kursauswahl via UnivIS-ID oder Chip) &rarr; Schritt 2 (Gruppen-Ranking, Deep-Sync & Live-Sniper) &rarr; Interaktiver Wochenplan.
2. **📅 Kalender (8-Wochen-Vorschau):**  
   Volle Semesterübersicht von KW 42 bis KW 49 mit automatischer Hervorhebung der aktuellen Woche und Umschaltung zwischen Woche A und Woche B.
3. **⚙️ Einstellungen:**  
   Theme-Auswahl (Aero, Cupertino, Botanical, Vaporwave), CAU Account Tresor, Optimierungs-Schieberegler und Telemetrie-Logs.

---

### ⚡ Live-Sniper (Schritt 1 bis 3)
1. **Kurs auswählen:** Wähle einen Kurs über die Schnell-Chips (z. B. `infEWInf-01a`, `infEInf-02a`) oder gib eine beliebige 6-stellige UnivIS-Kennung ein. UNIBODY zieht alle Daten live via UnivIS-XML-Schnittstelle.
2. **Priorität festlegen:** Das System ordnet die Übungsgruppen automatisch nach deinen Präferenzen (keine Kollisionen, Wunschzeiten, freie Tage). Mit einem Klick auf eine Gruppe kannst du deinen Favoriten als **📌 Wunsch #1** manuell fixieren.
3. **`⚡ Jetzt sofort einschreiben`:** UNIBODY startet die automatisierte Einschreibung via CDP und meldet das Ergebnis im Erfolgs-Popup mit Zeit, Raum und Bestätigungstoken.

---

### 🔄 UNIBODY Deep-Sync
Ein Klick auf den prominenten Button **`🔄 UNIBODY Deep-Sync (Gebuchte Übungen holen)`** scannt im Hintergrund OpenOlat und Moodle, gleicht deine aktuell belegten Übungsgruppen ab und trägt sie automatisch mit Raum und Uhrzeit in deinen Wochenplan ein.

---

### 📍 Apple Maps Campus Location Resolver
Jede Vorlesung und Übung im Kalender verfügt über einen Detail-Dialog mit Apple Maps Verlinkung. Durch den integrierten Resolver werden CAU-Raumkürzel in exakte Koordinaten aufgelöst:
- **OS 75:** Olshausenstraße 75, 24118 Kiel (`54.345406, 10.105659`, Hörsaal 1, 2 und Driftmann-Hörsaal)
- **CAP 2 / Audimax:** Christian-Albrechts-Platz 2
- **CAP 3:** Christian-Albrechts-Platz 3
- **LMS 8 / LMS 6:** Ludewig-Meyn-Straße (Informatik / Geozentrum)
- **HHP 6 / OHP 5 / WSP 3:** Heinrich-Hecht-Platz, Otto-Hahn-Platz, Wilhelm-Seelig-Platz

---

## 📚 Enthaltene Standardkurse (WiSe 2026/27)

| Modulcode | Veranstaltung | UnivIS-ID (VL / ÜB) | Ziel-Plattform |
| :--- | :--- | :--- | :--- |
| **`infEWInf-01a`** | Einführung in die Wirtschaftsinformatik (Prof. Cordes) | `080038` / `080042` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |
| **`infEInf-02a`** | Einführung in die Informatik (Prof. Mühling / Dr. Esquivel) | `080058` / `080056` | 💻 `elearn.informatik.uni-kiel.de` (Moodle `#470`) |
| **`Inf-Math-A`** | Mathematik für die Informatik A (Dr. Langfeld) | `060107` / `060098`–`060397` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |
| **`BWL-EinfBWL`** | Einführung in die Betriebswirtschaftslehre (Prof. Walter) | `030225` / `030189`–`030315` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |
| **`Inf-InfRecht`** | Informatikrecht (Dr. Lindhorst) | `080103` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |

*Über den Button **`+ Eigenen LMS-Kurs anlegen`** können beliebige weitere Vorlesungen und Übungen flexibel ergänzt werden!*

---

## 📱 Native iOS App (100 % Autonom & Standalone)

Unter [`ios/UNIBODY/UNIBODY.xcodeproj`](file:///Users/zer0/.gemini/antigravity/scratch/cau-lms-bot/ios/UNIBODY/UNIBODY.xcodeproj) liegt die native SwiftUI-App für iPhone und iPad:

- 🫧 **Frutiger Aero Liquid Glass Design:** Native iOS-Komponenten mit `.ultraThinMaterial`, Lichtreflexionen und haptischem Feedback.
- 📱 **Vollkommen unabhängig:** Läuft 100 % autonom auf dem iPhone – kein laufender Mac oder lokales WLAN-Setup nötig.
- 🔄 **On-Device Deep-Sync:** Eigener nativer WebKit-Crawler liest gebuchte Gruppen direkt auf dem Gerät aus OpenOlat und Moodle aus.
- 🔐 **Lokaler Keychain-Tresor:** Sichere Speicherung deiner Zugangsdaten direkt im geschützten iOS-Speicher.
- 📅 **Wochenplan & Alternierende Wochen:** Nahtlose Turnus-Erkennung (Woche A/B) auf dem Smartphone.

### iOS App mit Xcode bauen:
```bash
# Projekt in Xcode öffnen
open ios/UNIBODY/UNIBODY.xcodeproj

# Oder per CLI für den iOS Simulator kompilieren:
cd ios/UNIBODY
xcodebuild -scheme UNIBODY -destination "generic/platform=iOS Simulator" clean build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

---

## ❓ FAQ & Datenschutz

<details>
<summary><strong>Wo werden meine Zugangsdaten gespeichert?</strong></summary>
Deine CAU-Kennung und dein Passwort werden ausschließlich lokal auf deinem eigenen Rechner bzw. im sicheren iOS-Tresor gespeichert (im Ordner <code>data/</code>, der über <code>.gitignore</code> geschützt ist). Sie werden zu keinem Zeitpunkt an externe Server übertragen.
</details>

<details>
<summary><strong>Warum schließt sich Chrome nach der Einschreibung automatisch?</strong></summary>
Das ist ein bewusstes Sicherheits- und Ressourcen-Feature: Sobald der Sniper deinen Platz gebucht hat (oder festgestellt hat, dass die Übungsgruppe noch gesperrt ist), schließt UNIBODY Chrome sauber, um Arbeitsspeicher freizugeben.
</details>

<details>
<summary><strong>Wie wechsle ich zwischen Hell- und Dunkelmodus?</strong></summary>
Klicke einfach oben rechts auf <code>🌙 Dark Mode</code> bzw. <code>☀️ Daylight Mode</code> oder nutze den Umschalter in den Einstellungen.
</details>

---

## 📄 Lizenz & Haftungsausschluss

Dieses Projekt steht unter der **MIT-Lizenz**.  
*Hinweis:* UNIBODY ist ein unabhängiges Open-Source-Projekt von Studierenden für Studierende der Christian-Albrechts-Universität zu Kiel und steht in keiner offiziellen Verbindung zur CAU Kiel, OpenOlat oder Moodle.
