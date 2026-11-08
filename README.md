<p align="center">
  <img src="static/unibody-logo.png" width="135" alt="UNIBODY Logo" />
</p>

<h1 align="center">🫧 UNIBODY</h1>
<p align="center">
  <strong>Inoffizielles Studierenden-Tool · Dual-Platform Kurs-Sniper &amp; Stundenplan-Optimizer (WiSe 2026/27)</strong><br/>
  Unabhängiges Open-Source-Programm für Studierende (kompatibel mit <code>lms.uni-kiel.de</code> / OpenOlat &amp; <code>elearn.informatik.uni-kiel.de</code> / Moodle)
</p>

> [!IMPORTANT]
> **Rechtlicher Hinweis (Inoffizielles Projekt – Keine Affiliation):**  
> **UNIBODY** ist ein privates, unabhängiges und **inoffizielles Open-Source-Projekt von Studierenden für Studierende**. Es besteht **keinerlei offizielle Verbindung, Kooperation, Unterstützung oder Zugehörigkeit** zur Christian-Albrechts-Universität zu Kiel (CAU), zur OpenOlat-Plattform oder zu Moodle. Alle genannten Portale und Modulbezeichnungen dienen ausschließlich der Beschreibung der technischen Kompatibilität.

<p align="center">
  <img src="https://img.shields.io/badge/Status-Inoffizielles%20Studierenden--Tool-f59e0b?style=flat-square" alt="Unofficial Tool" />
  <img src="https://img.shields.io/badge/Python-3.9+-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python 3.9+" />
  <img src="https://img.shields.io/badge/iOS-27.0+-000000?style=flat-square&logo=apple&logoColor=white" alt="iOS 27.0+" />
  <img src="https://img.shields.io/badge/SwiftUI-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="SwiftUI 6.0" />
  <img src="https://img.shields.io/badge/Themes-5%20Styles-ff71ce?style=flat-square" alt="5 Themes" />
  <img src="https://img.shields.io/badge/Kompatibel%20mit-OpenOlat%20%7C%20Moodle-10b981?style=flat-square" alt="OpenOlat & Moodle" />
  <img src="https://img.shields.io/badge/Zero--Dependency-Stdlib%20Only-blueviolet?style=flat-square" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/Lizenz-MIT-orange?style=flat-square" alt="License" />
</p>

---

## 🌟 Was ist UNIBODY?

Viele Lehrveranstaltungen und Übungsgruppen sind je nach Fachbereich über **zwei getrennte Lernplattformen** verteilt:
1. **🏛️ OpenOlat (`lms.uni-kiel.de`):** u. a. *Einführung in die Wirtschaftsinformatik* (`infEWInf-01a`), *Mathematik für die Informatik A* (`Inf-Math-A`), *Einführung in die BWL* (`BWL-EinfBWL`) und *Informatikrecht* (`Inf-InfRecht`).
2. **💻 Informatik-Moodle (`elearn.informatik.uni-kiel.de`):** u. a. *Einführung in die Informatik* (`infEInf-02a` / `infEInf-01a`) sowie die PDF-Übungsblätter für `infEWInf-01a`.

**UNIBODY** ist ein **inoffizieller Studienassistent**, der beide Plattformen lokal auf deinem eigenen Gerät bündelt:
- 🔑 **1-Klick Auto-Login (Lokaler Tresor):** Hinterlege deine Studierenden-Kennung (`stu...`) einmalig lokal im macOS- bzw. iOS-Schlüsselbund (`Keychain`). UNIBODY füllt die Login-Masken auf beiden Plattformen automatisch aus.
- 🎯 **Intelligentes Dual-Routing:** Erkennt anhand der Modul-ID oder UnivIS-Nummer selbstständig, ob eine Veranstaltung in OpenOlat oder im Moodle liegt.
- ⚡ **First-Come-First-Served Sniper:** Navigiert beim Anmeldestart via Chrome DevTools Protocol (CDP) bzw. WebKit automatisch zu deiner Wunschgruppe, bestätigt den Platz und weicht bei vollen Gruppen auf deine Priorität #2/#3 aus.
- 🔄 **High-Speed Deep-Sync:** Liest deine bereits gebuchten Übungen live aus OpenOlat und Moodle aus und trägt sie kollisionsfrei in deinen Stundenplan ein.
- 📁 **Aufgaben & Materialien (Beta):** Zweigeteilte Finder-Ordnerstruktur (*Hausaufgaben/Übungsblätter* & *Vorlesungsfolien*) mit PDF-Vorschau und Fristen-Countdown.
- ✉️ **Inoffizieller Uni-Mail Client:** Lokaler IMAP-Client (`imap.mail.uni-kiel.de:993` SSL) mit HTML-Sanitisierung und ungelesen-Zähler.
- 📅 **Semester-Management:** 8-Wochen-Vorschau, Unterstützung für 14-tägige Vorlesungen (Woche A / Woche B) und Raum-Verortung via Apple Maps.

---

## 🎨 5 Wählbare Design-Themen (Light & Dark Mode)

In den Einstellungen (`⚙️ Einstellungen`) kannst du das Interface an deinen persönlichen Stil anpassen:

| Theme | Stil & Inspiration | Light Mode Palette | Dark Mode Palette |
| :--- | :--- | :--- | :--- |
| 🫧 **Frutiger Aero** *(Default)* | 2000er Windows 7 Aero Glass, Aqua & Eco-Tech | Sanftes Himmelblau, Milchglas, glänzende Gel-Buttons | **Deep Ocean Night:** Meeresblau-Schwarz (`#031529`), Cyan-Ränder |
| 🪨 **Matte Minimal** | Flat & Puristisch ohne Glanz-Effekte | Ruhiges Schiefer-Offwhite, klare Konturen | **Matte Graphite:** Tiefmattes Anthrazit ohne Spiegelungen |
| 🍏 **Cupertino Minimal** | Modern Apple macOS & iOS | Edles Studio-Offwhite (`#f5f5f7`), feine Unschärfen | **Space Grey OLED:** Tiefschwarz (`#000000`), Frosted Cards |
| 🌿 **Botanischer Garten** | Natur- & Smaragd-Stil | Beruhigendes Salbei- & Smaragdgrün (`#064e3b`) | **Deep Jungle:** Tiefdunkles Waldgrün (`#03140c`) |
| 🌴 **Vaporwave Sunset** | Retro 80s/90s Synthwave | Pastell-Peach, Flieder & Flamingo-Pink | **Cyber Synthwave:** Mitternachtsviolett (`#0c021f`) & Neon |

---

## 🚀 Schnellanleitung (In 3 Schritten startklar!)

UNIBODY benötigt **keine externen Pakete (`pip`)** oder Cloud-Datenbanken. Alles läuft lokal über die Standardbibliothek von Python!

### Voraussetzungen:
1. **Google Chrome** (wird für die lokale CDP-Browser-Automatisierung verwendet)
2. **Python 3.9 oder neuer** ([python.org/downloads](https://www.python.org/downloads/))

---

### 🍏 Installation & Start auf macOS

#### 1. Repository klonen
Öffne das **Terminal** (`Cmd ⌘` + `Leertaste` → `Terminal` → `Enter`):
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
UNIBODY (Inoffizielles Studierenden-Tool) running on http://127.0.0.1:8765 and http://localhost:8765
```

#### 3. Im Browser öffnen
Rufe die Web-Oberfläche in Safari, Chrome oder Firefox auf:  
👉 **[http://localhost:8765](http://localhost:8765)** *(oder [http://127.0.0.1:8765](http://127.0.0.1:8765))*

---

### 🪟 Installation & Start auf Windows

1. **Herunterladen:**
   - Klicke oben auf **`<> Code`** → **`Download ZIP`** und entpacke den Ordner (oder nutze `git clone https://github.com/primeyeat/UNIBODY.git`).
2. **Terminal im Ordner öffnen:**
   - Öffne den entpackten Ordner im Explorer, tippe in die Pfadzeile **`cmd`** ein und drücke `Enter`.
3. **Server starten:**
   ```bat
   python server.py
   ```
4. **Website aufrufen:**  
   👉 **[http://localhost:8765](http://localhost:8765)**

---

## 📱 Native iOS App (100 % Autonom & Standalone)

Unter [`ios/UNIBODY/UNIBODY.xcodeproj`](ios/UNIBODY/UNIBODY.xcodeproj) liegt die native SwiftUI-App für iPhone und iPad (Bundle-ID: `app.unibody.student`):

- 📱 **Vollkommen unabhängig:** Läuft 100 % autonom auf dem iPhone – kein laufender Mac nötig.
- 🔄 **On-Device Deep-Sync:** Eigener nativer WebKit-Crawler liest gebuchte Gruppen direkt auf dem Gerät aus OpenOlat und Moodle aus.
- 📁 **Materialien-Finder (Beta) & PDF-QuickLook:** Integrierte Vorschau für Übungsblätter (`Übung 1..20`, `bl01.pdf`, `bl02.pdf`, `pr01.pdf`) und Vorlesungsfolien.
- ✉️ **Inoffizieller Uni-Mail Tab:** Direkter Postfach-Überblick mit Sicherheits-Sanitisierung.
- 🔐 **Lokaler Keychain-Tresor:** Sichere Speicherung deiner Zugangsdaten direkt im geschützten Gerätespeicher.

### iOS App mit Xcode bauen:
```bash
# Projekt in Xcode öffnen
open ios/UNIBODY/UNIBODY.xcodeproj

# Oder per CLI für den iOS Simulator kompilieren:
xcodebuild -project ios/UNIBODY/UNIBODY.xcodeproj -scheme UNIBODY -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

---

## 🛡️ Sicherheit & Datenschutz

Alle Details zum aktuellen Netzwerk- und Code-Security-Audit sind in [`NETWORK_SECURITY_AUDIT.md`](NETWORK_SECURITY_AUDIT.md) dokumentiert:
- **Zero-Cloud:** Keine externen Server, kein Tracking, keine Weitergabe von Zugangsdaten.
- **Loopback-Only (`127.0.0.1`):** Der lokale Python-Server ist aus dem lokalen Netzwerk (z. B. Campus-WLAN) nicht erreichbar.
- **Keychain-Verschlüsselung:** Passwörter werden im macOS- bzw. iOS-Schlüsselbund abgelegt.

---

## 📄 Lizenz & Haftungsausschluss

Dieses Projekt steht unter der **MIT-Lizenz**.  
**Wichtiger Hinweis:** UNIBODY ist ein inoffizielles Freizeit- und Studierendenprojekt. Es wird **nicht** von der Christian-Albrechts-Universität zu Kiel (CAU) betrieben, geprüft oder unterstützt. Die Nutzung erfolgt auf eigene Verantwortung.
