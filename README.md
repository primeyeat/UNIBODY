<p align="center">
  <img src="static/unibody-logo.png" width="135" alt="UNIBODY Logo" />
</p>

<h1 align="center">🫧 UNIBODY</h1>
<p align="center">
  <strong>CAU Kiel Dual-Platform Kurs-Sniper &amp; Echtzeit-Stundenplan-Optimizer (WiSe 2026/27)</strong><br/>
  Automatische Kurswahl, Kollisionsschutz &amp; 1-Klick Auto-Login für <code>lms.uni-kiel.de</code> (OpenOlat) und <code>elearn.informatik.uni-kiel.de</code> (Informatik-Moodle)
</p>

---

## 🌍 Warum UNIBODY?

Als Wirtschaftsinformatiker/in an der **CAU Kiel** sind deine Kurse und Übungsgruppen auf **zwei völlig verschiedene Plattformen** verteilt:
1. **🏛️ `lms.uni-kiel.de` (CAU OpenOlat)** – hier liegen u. a. *Einführung in die Wirtschaftsinformatik* (`infEWInf-01a`), *Mathematik für die Informatik A* (`Inf-Math-A`), *Einführung in die BWL* (`BWL-EinfBWL`) und *Informatikrecht* (`Inf-InfRecht`).
2. **💻 `elearn.informatik.uni-kiel.de` (Informatik Moodle)** – hier liegen die Übungsgruppen für *Einführung in die Informatik* (`infEInf-02a` / `infEInf-01a`, Moodle-Kurs `id=470`) sowie weitere Informatik-Module.

**UNIBODY** verbindet beide Systeme zu einer einzigen Oberfläche im **Frutiger Aero Design** (inklusive *Deep Ocean Aurora Dark Mode*):
- Du hinterlegst deine CAU-Kennung (`stu...`) und dein Passwort **ein einziges Mal**.
- **UNIBODY erkennt bei jedem Kurs vollautomatisch, auf welcher der beiden Seiten er gelistet ist**, loggt dich im Browser auf beiden Plattformen automatisch ein und sichert dir sekundengenau deine Wunsch-Übungsgruppe!

---

## 🚀 Komplette Schritt-für-Schritt-Anleitung (Auch für absolute Einsteiger!)

Du brauchst **keine Programmierkenntnisse** und musst **keine extra Pakete (`pip`)** installieren. UNIBODY nutzt ausschließlich Funktionen, die in Python bereits standardmäßig eingebaut sind.

### Was du auf deinem Computer brauchst:
1. **Google Chrome** (als Browser für den automatischen CAU-Login)
2. **Python 3**
   - *Auf dem Mac:* Ist oft schon vorinstalliert (falls nicht, fragt dich dein Mac beim ersten Befehl automatisch, ob er es mit einem Klick installieren soll, oder lade es auf [python.org/downloads](https://www.python.org/downloads/) herunter).
   - *Auf Windows:* Lade Python kostenlos auf [python.org/downloads](https://www.python.org/downloads/) herunter. **Wichtig bei Windows:** Setze ganz unten im Installationsfenster unbedingt das Häkchen bei **„Add python.exe to PATH“**!

---

### 🍏 Anleitung für Mac (macOS)

#### Schritt 1: UNIBODY herunterladen
Du hast zwei Möglichkeiten (wähle einfach die, die dir leichter fällt):

- **Variante A – Ohne Git (Einfach per Mausklick als ZIP):**
  1. Klicke ganz oben rechts auf dieser GitHub-Seite auf den grünen Button **`<> Code`**.
  2. Klicke im Menü auf **`Download ZIP`**.
  3. Öffne deinen `Downloads`-Ordner und mache einen Doppelklick auf `UNIBODY-main.zip`, sodass der Ordner **`UNIBODY-main`** entpackt wird.

- **Variante B – Über das Terminal (mit Git):**
  1. Drücke gleichzeitig **`Cmd ⌘` + `Leertaste`** (Spotlight-Suche), tippe **`Terminal`** ein und drücke **`Enter`**.
  2. Kopiere diesen Befehl hinein und drücke **`Enter`**:
     ```bash
     git clone https://github.com/primeyeat/UNIBODY.git
     ```

#### Schritt 2: UNIBODY starten
1. Öffne die App **Terminal** (falls noch nicht offen: `Cmd ⌘` + `Leertaste` $\rightarrow$ `Terminal` $\rightarrow$ `Enter`).
2. **Profi-Trick für Einsteiger:**
   - Tippe im Terminal `cd ` ein (wichtig: mit einem **Leerzeichen** hinter dem `cd`!) – drücke noch **nicht** Enter.
   - Ziehe jetzt einfach deinen heruntergeladenen **`UNIBODY`**-Ordner (bzw. `UNIBODY-main`) mit der Maus aus dem Finder direkt in das Terminal-Fenster! Das Terminal setzt den Pfad automatisch ein.
   - Drücke jetzt **`Enter`**.
3. Starte nun den UNIBODY-Server mit diesem Befehl und drücke **`Enter`**:
   ```bash
   python3 server.py
   ```
4. Im Terminal steht jetzt:
   `CAU Kiel LMS Sniper & Schedule Optimizer running on http://127.0.0.1:8765`
   *(Lass dieses Terminal-Fenster einfach im Hintergrund offen, solange du UNIBODY benutzt!)*

#### Schritt 3: UNIBODY im Browser öffnen
Öffne deinen normalen Webbrowser (Safari, Chrome, Arc, Firefox etc.) und klicke auf diesen Link (oder gib ihn oben in die Adresszeile ein):

👉 **[http://127.0.0.1:8765](http://127.0.0.1:8765)**

---

### 🪟 Anleitung für Windows

1. **Herunterladen:** Klicke oben auf dieser GitHub-Seite auf den grünen Button **`<> Code`** $\rightarrow$ **`Download ZIP`** und entpacke den ZIP-Ordner (z. B. auf deinen Desktop).
2. **Ordner im Terminal öffnen:**
   - Öffne den entpackten Ordner `UNIBODY-main` im Windows-Explorer.
   - Klicke oben in die Adresszeile des Ordners, tippe **`cmd`** ein und drücke **`Enter`**. Es öffnet sich ein schwarzes Fenster direkt im richtigen Ordner.
3. **Server starten:** Tippe folgenden Befehl ein und drücke **`Enter`**:
   ```bat
   python server.py
   ```
4. **Website öffnen:** Öffne deinen Browser und gehe auf:
   👉 **[http://127.0.0.1:8765](http://127.0.0.1:8765)**

---

## 🎮 Wie bediene ich UNIBODY auf der Website? (In 4 einfachen Schritten)

Sobald du **[http://127.0.0.1:8765](http://127.0.0.1:8765)** geöffnet hast, funktioniert alles bequem per Mausklick:

### 1️⃣ CAU-Account einmalig hinterlegen (Oben links: „🫧 UNIBODY TRESOR“)
- Trage deine **CAU-Kennung** (z. B. `stu123456`) und dein **Passwort** ein.
- Klicke auf den grünen Button **`🚀 Speichern & beide Plattformen im Browser einloggen`**.
- **Was passiert jetzt?**
  - Dein Passwort wird sicher lokal im **macOS Schlüsselbund (Keychain)** gespeichert (es verlässt niemals deinen Computer!).
  - Es öffnet sich ein Google-Chrome-Fenster, das automatisch sowohl **`lms.uni-kiel.de` (OpenOlat)** als auch **`elearn.informatik.uni-kiel.de` (Informatik-Moodle)** öffnet, deine Login-Daten von selbst einträgt und dich auf beiden Seiten anmeldet!

### 2️⃣ Kurs auswählen (Per Klick im Kalender oder über Schritt 1)
- **Schnellster Weg:** Klicke rechts im **Wochen-Stundenplan** einfach direkt auf einen der **blauen Vorlesungs-Blöcke** (z. B. auf *Einführung in die Informatik* am Montag oder *Einführung in die Wirtschaftsinformatik* am Donnerstag).
- **Alternativ:** Klicke links in **Schritt 1** auf einen der Kurs-Buttons (`infEWInf-01a`, `infEInf-02a`, `Inf-Math-A`, `BWL-EinfBWL`, `Inf-InfRecht`) oder tippe irgendeine **6-stellige UnivIS-Kennung** ein – UNIBODY lädt die echten Termine live von `univis.uni-kiel.de`!
- Im grünen Banner siehst du sofort, wohin **UNIBODY** den Kurs routet (`🫧 UNIBODY -> lms.uni-kiel.de` oder `🫧 UNIBODY -> elearn.informatik.uni-kiel.de`).

### 3️⃣ Deine Wunsch-Übungsgruppe priorisieren
- Im Wochen-Stundenplan werden dir alle möglichen Übungsgruppen des ausgewählten Kurses als **gestrichelte Blöcke** angezeigt:
  - 🟩 **Grün (#1):** Deine aktuell beste Empfehlung / dein Wunsch #1
  - 🟧 **Orange (#2 / #3):** Gute Alternativen ohne Zeitkonflikt
  - 🟥 **Rot:** Blockiert, weil du zu dieser Zeit schon eine andere Vorlesung hast!
- **Per Klick priorisieren:** Gefällt dir eine bestimmte orangefarbene Übung im Stundenplan am besten? **Klicke einfach im Kalender auf den gestrichelten Kasten!** Er färbt sich sofort **grün** und wird in **Schritt 3** automatisch als dein **📌 Wunsch #1** ganz nach oben gesetzt.

### 4️⃣ Einschreiben / Sniper abfeuern (Schritt 3)
- Klicke in **Schritt 3** auf:
  - **`⚡ Jetzt sofort einschreiben (Bestplatz sichern)`** – um dich direkt in deinen Wunsch #1 einzutragen.
  - **`⏱️ 5s Countdown-Sniper starten`** – für den Ernstfall, wenn die Anmeldung zu einer vollen Stunde freigeschaltet wird.
- **Automatischer Fallback-Schutz:** Sollte dein Wunsch #1 in derselben Millisekunde voll werden, bricht UNIBODY nicht ab, sondern bucht in **12 Millisekunden automatisch deinen Platz #2**!

---

## 📊 Überblick der vorinstallierten CAU Wirtschaftsinformatik-Kurse (WiSe 26/27)

| Modulcode | Veranstaltung | UnivIS-Kennung (VL / ÜB) | UNIBODY Ziel-Plattform |
| :--- | :--- | :--- | :--- |
| **`infEWInf-01a`** | Einführung in die Wirtschaftsinformatik (Prof. Cordes) | `080038` / `080042` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |
| **`infEInf-02a`** | Einführung in die Informatik (Prof. Mühling / Dr. Esquivel) | `080058` / `080056` | 💻 `elearn.informatik.uni-kiel.de` (Moodle `#470`) |
| **`Inf-Math-A`** | Mathematik für die Informatik A (Dr. Langfeld) | `060107` / `060098`–`060397` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |
| **`BWL-EinfBWL`** | Einführung in die Betriebswirtschaftslehre (Prof. Walter) | `030225` / `030189`–`030315` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |
| **`Inf-InfRecht`** | Informatikrecht (Dr. Lindhorst) | `080103` | 🏛️ `lms.uni-kiel.de` (OpenOlat) |

*(Jederzeit erweiterbar über den Button **`+ Eigenen LMS-Kurs anlegen`** oder **`✏️ Echte Gruppen aus LMS einfügen / anpassen`**!)*

---

## ❓ Häufige Fragen (FAQ für Einsteiger)

- **Wie schalte ich zwischen Light Mode und Dark Mode um?**
  Oben rechts im Header findest du den Button **`🌙 Dark Mode`** bzw. **`☀️ Daylight Mode`**, der zwischen hellem *Frutiger Aero Daylight* und dunklem *Deep Ocean Aurora Glass* wechselt.
- **Sind meine CAU-Login-Daten sicher?**
  Ja, zu 100 %. Deine Zugangsdaten werden im **macOS Schlüsselbund (Keychain)** bzw. lokal im Ordner `data/` gespeichert. Der gesamte Ordner `data/` ist über `.gitignore` gesperrt und wird niemals ins Internet oder zu GitHub hochgeladen.
- **Wie beende ich UNIBODY wieder?**
  Klicke in das geöffnete Terminal-Fenster und drücke **`Ctrl + C`** (bzw. **`Strg + C`**) oder schließe einfach das Terminal-Fenster.
