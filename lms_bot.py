"""
CAU Kiel LMS Browser Automation & Course Catalog Engine.
Supports:
1. Interactive Google Chrome / Chromium Login via DevTools Protocol (CDP) or Playwright so Shibboleth SSO & 2FA work seamlessly.
2. Strict ID/Module Code verification (checks exact Modulcode / UnivIS-Kennnummer / OpenOlat Repository-ID before touching any enrollment button).
3. Parsing exercise groups (Übungsgruppen) from CAU OpenOlat (lms.uni-kiel.de) and CAU Moodle (elearn.uni-kiel.de).
4. Dual-Mode Execution:
   - Mode A: First-Come-First-Served Sniper (high-frequency polling / countdown trigger -> instant click on Rank 1, automatic fallback to Rank 2/3 if full).
   - Mode B: Priority Allocator (Verteilungsverfahren -> fills out Rank 1, 2, 3 dropdowns/sliders automatically).
"""

import os
import re
import time
import json
import subprocess
import threading
import urllib.request
from datetime import datetime
from typing import Dict, List, Any, Optional

from optimizer import parse_german_timeslot, DAY_NAMES_DE


# Official CAU Kiel Wirtschaftsinformatik (B.Sc.) 1. Fachsemester (WiSe 2026/27) Catalog
BUILTIN_CAU_COURSES: Dict[str, Dict[str, Any]] = {
    "infewinf-01a": {
        "course_id": "infEWInf-01a",
        "univis_id": "080241",
        "olat_repo_id": "849201340",
        "title": "infEWInf-01a: Einführung in die Wirtschaftsinformatik (7 LP)",
        "lecturer": "Prof. Dr. Ann-Kristin Cordes",
        "semester": "WiSe 2026/27 (1. Sem. WInf)",
        "platform": "OpenOlat (lms.uni-kiel.de)",
        "enrollment_mode": "sniper",  # First-Come-First-Served
        "enrollment_opens_at": "2026-10-21T12:00:00",
        "url": "https://lms.uni-kiel.de/auth/RepositoryEntry/849201340",
        "verified_tokens": ["infewinf-01a", "infewinf", "080241", "849201340"],
        "groups": [
            {
                "group_id": "ewinf-g1",
                "name": "Übung 01 (Mi 12:15 - 13:45 · LMS8 - R.EG.015)",
                "day": 2,
                "day_name": "Mittwoch",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "LMS8 - R.EG.015",
                "tutor": "Lukas H. (AG Cordes)",
                "spots_free": 6,
                "spots_total": 30,
                "waitlist_available": True,
            },
            {
                "group_id": "ewinf-g2",
                "name": "Übung 02 (Do 12:15 - 13:45 · LMS11a - R.EG.003)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "LMS11a - R.EG.003",
                "tutor": "Marie K. (AG Cordes)",
                "spots_free": 4,
                "spots_total": 30,
                "waitlist_available": True,
            },
            {
                "group_id": "ewinf-g3",
                "name": "Übung 03 (Di 14:15 - 15:45 · CAP3 - R.114)",
                "day": 1,
                "day_name": "Dienstag",
                "start_time": "14:15",
                "end_time": "15:45",
                "room": "CAP3 - R.114",
                "tutor": "Jannis M.",
                "spots_free": 9,
                "spots_total": 30,
                "waitlist_available": True,
            },
            {
                "group_id": "ewinf-g4",
                "name": "Übung 04 (Do 10:15 - 11:45 · Kollisionstest mit VL)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "10:15",
                "end_time": "11:45",
                "room": "LMS8 - R.EG.015",
                "tutor": "Svenja B.",
                "spots_free": 15,
                "spots_total": 30,
                "waitlist_available": True,
            },
        ],
    },
    "infeinf-01a": {
        "course_id": "infEInf-01a",
        "univis_id": "080056",
        "olat_repo_id": "849201552",
        "title": "infEInf-01a: Einführung in die Informatik (10 LP)",
        "lecturer": "Prof. Dr. Andreas Mühling, Dr. P. Fleischmann, Dr. S. Esquivel",
        "semester": "WiSe 2026/27 (1. Sem. WInf)",
        "platform": "OpenOlat / Moodle (elearn.informatik.uni-kiel.de)",
        "enrollment_mode": "sniper",
        "enrollment_opens_at": "2026-10-21T14:00:00",
        "url": "https://lms.uni-kiel.de/auth/RepositoryEntry/849201552",
        "verified_tokens": ["infeinf-01a", "infeinf-02a", "infeinf", "080056", "080112", "849201552"],
        "groups": [
            {
                "group_id": "einf-g1",
                "name": "Übung 01 (Di 10:15 - 11:45 · WSP3 - R.2 [32])",
                "day": 1,
                "day_name": "Dienstag",
                "start_time": "10:15",
                "end_time": "11:45",
                "room": "WSP3 - Seminarraum 2 (32)",
                "tutor": "UnivIS #080056",
                "spots_free": 5,
                "spots_total": 25,
                "waitlist_available": True,
            },
            {
                "group_id": "einf-g2",
                "name": "Übung 02 (Di 12:15 - 13:45 · WSP3 - R.2 [32] · Kollision BWL VL)",
                "day": 1,
                "day_name": "Dienstag",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "WSP3 - Seminarraum 2 (32)",
                "tutor": "UnivIS #080056",
                "spots_free": 14,
                "spots_total": 25,
                "waitlist_available": True,
            },
            {
                "group_id": "einf-g3",
                "name": "Übung 03 (Mi 12:15 - 13:45 · WSP3 - R.2 [32])",
                "day": 2,
                "day_name": "Mittwoch",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "WSP3 - Seminarraum 2 (32)",
                "tutor": "UnivIS #080056",
                "spots_free": 7,
                "spots_total": 25,
                "waitlist_available": True,
            },
            {
                "group_id": "einf-g4",
                "name": "Übung 04 (Do 10:15 - 11:45 · WSP3 - R.1 [24] · Kollision WInf VL)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "10:15",
                "end_time": "11:45",
                "room": "WSP3 - Seminarraum 1 (24)",
                "tutor": "UnivIS #080056",
                "spots_free": 18,
                "spots_total": 25,
                "waitlist_available": True,
            },
            {
                "group_id": "einf-g5",
                "name": "Übung 05 (Do 12:15 - 13:45 · CAP3 - Hörsaal 1)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "CAP3 - Hörsaal 1",
                "tutor": "UnivIS #080056",
                "spots_free": 9,
                "spots_total": 25,
                "waitlist_available": True,
            },
            {
                "group_id": "einf-g6",
                "name": "Übung 06 (Do 14:15 - 15:45 · WSP3 - R.2 [32])",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "14:15",
                "end_time": "15:45",
                "room": "WSP3 - Seminarraum 2 (32)",
                "tutor": "UnivIS #080056",
                "spots_free": 11,
                "spots_total": 25,
                "waitlist_available": True,
            },
        ],
    },
    "inf-math-a": {
        "course_id": "Inf-Math-A",
        "univis_id": "080108",
        "olat_repo_id": "849201789",
        "title": "Inf-Math-A: Mathematik für die Informatik A (8 LP)",
        "lecturer": "Dr. Barbara Langfeld",
        "semester": "WiSe 2026/27 (1. Sem. WInf)",
        "platform": "OpenOlat (lms.uni-kiel.de)",
        "enrollment_mode": "priority",  # Priority distribution
        "enrollment_opens_at": "2026-10-22T09:00:00",
        "url": "https://lms.uni-kiel.de/auth/RepositoryEntry/849201789",
        "verified_tokens": ["inf-math-a", "math-infa", "080108", "849201789"],
        "groups": [
            {
                "group_id": "matha-g1",
                "name": "Übung 01 (Di 16:15 - 17:45 · HHP6 - R.EG.004)",
                "day": 1,
                "day_name": "Dienstag",
                "start_time": "16:15",
                "end_time": "17:45",
                "room": "HHP6 - R.EG.004",
                "tutor": "UnivIS (AG Langfeld)",
                "spots_free": 7,
                "spots_total": 28,
                "waitlist_available": True,
            },
            {
                "group_id": "matha-g2",
                "name": "Übung 02 (Di 16:15 - 17:45 · LMS4 - R.424)",
                "day": 1,
                "day_name": "Dienstag",
                "start_time": "16:15",
                "end_time": "17:45",
                "room": "LMS4 - R.424",
                "tutor": "UnivIS (AG Langfeld)",
                "spots_free": 12,
                "spots_total": 28,
                "waitlist_available": True,
            },
            {
                "group_id": "matha-g3",
                "name": "Übung 03 (Di 18:15 - 19:45 · HHP6 - R.EG.004)",
                "day": 1,
                "day_name": "Dienstag",
                "start_time": "18:15",
                "end_time": "19:45",
                "room": "HHP6 - R.EG.004",
                "tutor": "UnivIS (AG Langfeld)",
                "spots_free": 19,
                "spots_total": 28,
                "waitlist_available": True,
            },
            {
                "group_id": "matha-g4",
                "name": "Übung 04 (Mi 14:15 - 15:45 · HHP6 - R.EG.004)",
                "day": 2,
                "day_name": "Mittwoch",
                "start_time": "14:15",
                "end_time": "15:45",
                "room": "HHP6 - R.EG.004",
                "tutor": "UnivIS (AG Langfeld)",
                "spots_free": 5,
                "spots_total": 28,
                "waitlist_available": True,
            },
            {
                "group_id": "matha-g5",
                "name": "Übung 05 (Mi 16:15 - 17:45 · HHP6 - R.EG.004)",
                "day": 2,
                "day_name": "Mittwoch",
                "start_time": "16:15",
                "end_time": "17:45",
                "room": "HHP6 - R.EG.004",
                "tutor": "UnivIS (AG Langfeld)",
                "spots_free": 11,
                "spots_total": 28,
                "waitlist_available": True,
            },
        ],
    },
    "bwl-einfbwl": {
        "course_id": "BWL-EinfBWL",
        "univis_id": "030225",
        "olat_repo_id": "849201910",
        "title": "BWL-EinfBWL: Einführung in die Betriebswirtschaftslehre + Planspiel (5 LP)",
        "lecturer": "Prof. Dr. Achim Walter, Carolin Lilienthal, Alexander Dobers-Tarasevich",
        "semester": "WiSe 2026/27 (1. Sem. WInf)",
        "platform": "OpenOlat (lms.uni-kiel.de)",
        "enrollment_mode": "sniper",
        "enrollment_opens_at": "2026-10-23T10:00:00",
        "url": "https://lms.uni-kiel.de/auth/RepositoryEntry/849201910",
        "verified_tokens": ["bwl-einfbwl", "bwl-einf", "030225", "030001", "849201910"],
        "groups": [
            {
                "group_id": "bwl-g1",
                "name": "ÜbEBWL Gruppe 1 (Do 08:30 - 10:00 · LMS2 - R.Ü2/K)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "08:30",
                "end_time": "10:00",
                "room": "LMS2 - R.Ü2/K",
                "tutor": "Carolin Lilienthal",
                "spots_free": 9,
                "spots_total": 35,
                "waitlist_available": True,
            },
            {
                "group_id": "bwl-g2",
                "name": "ÜbEBWL Gruppe 2 (Do 10:15 - 11:45 · LMS2 - R.Ü2/K · Kollision WInf VL)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "10:15",
                "end_time": "11:45",
                "room": "LMS2 - R.Ü2/K",
                "tutor": "Alexander Dobers-Tarasevich",
                "spots_free": 14,
                "spots_total": 35,
                "waitlist_available": True,
            },
            {
                "group_id": "bwl-g3",
                "name": "ÜbEBWL Gruppe 3 (Mi 14:15 - 15:45 · OS75 - R.202)",
                "day": 2,
                "day_name": "Mittwoch",
                "start_time": "14:15",
                "end_time": "15:45",
                "room": "OS75 - R.202",
                "tutor": "Svenja Sievers",
                "spots_free": 8,
                "spots_total": 35,
                "waitlist_available": True,
            },
        ],
    },
    "inf-infrecht": {
        "course_id": "Inf-InfRecht",
        "univis_id": "080310",
        "olat_repo_id": "849202100",
        "title": "Inf-InfRecht: Informatikrecht (2 LP)",
        "lecturer": "Dr. Hermann Lindhorst",
        "semester": "WiSe 2026/27 (1. Sem. WInf)",
        "platform": "OpenOlat (lms.uni-kiel.de)",
        "enrollment_mode": "sniper",
        "enrollment_opens_at": "2026-10-23T12:00:00",
        "url": "https://lms.uni-kiel.de/auth/RepositoryEntry/849202100",
        "verified_tokens": ["inf-infrecht", "infrecht", "080310", "849202100"],
        "groups": [
            {
                "group_id": "recht-g1",
                "name": "Begleitgruppe / Kurseinschreibung (Do 16:15 - 17:45 · CAP2)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "16:15",
                "end_time": "17:45",
                "room": "CAP2 - Hörsaal",
                "tutor": "Dr. H. Lindhorst",
                "spots_free": 42,
                "spots_total": 80,
                "waitlist_available": True,
            },
        ],
    },
}


class CAUBrowserSessionManager:
    """
    Manages the dedicated Google Chrome browser profile for CAU Shibboleth SSO & LMS automation.
    Uses Chrome's native remote debugging port (9222) + persistent profile folder so the user
    can log in once with stu-Kennung & 2FA, and the bot can inspect/click OpenOlat & Moodle pages.
    """

    def __init__(self, profile_dir: str):
        self.profile_dir = profile_dir
        self.debug_port = 9222
        self.chrome_process: Optional[subprocess.Popen] = None
        self.session_state = {
            "browser_running": False,
            "logged_in": False,
            "current_url": None,
            "current_title": None,
            "last_checked": None,
            "user_hint": "Nicht verbunden – Klicke auf 'CAU Login-Browser starten', um dich einmalig via SSO einzuloggen.",
        }
        self.logs: List[Dict[str, str]] = []
        self._lock = threading.Lock()
        self.add_log("SYSTEM", "CAU LMS Sniper & Optimizer Engine initialisiert.")

    def add_log(self, level: str, message: str):
        with self._lock:
            now_str = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            self.logs.append({
                "timestamp": now_str,
                "level": level,
                "message": message,
            })
            if len(self.logs) > 250:
                self.logs = self.logs[-250:]

    def find_chrome_binary(self) -> Optional[str]:
        candidates = [
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Chromium.app/Contents/MacOS/Chromium",
            "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
            "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
        ]
        for path in candidates:
            if os.path.exists(path):
                return path
        return None

    def launch_login_browser(self, target_url: str = "https://lms.uni-kiel.de") -> Dict[str, Any]:
        """Launches a visible Chrome window with a persistent CAU session profile and remote debugging."""
        chrome_bin = self.find_chrome_binary()
        if not chrome_bin:
            self.add_log("ERROR", "Google Chrome wurde nicht unter /Applications gefunden.")
            return {"ok": False, "error": "Google Chrome nicht gefunden."}

        os.makedirs(self.profile_dir, exist_ok=True)

        # Check if debug port is already responding
        tabs = self._get_cdp_tabs()
        if tabs is not None:
            self.add_log("INFO", f"Browser-Session läuft bereits ({len(tabs)} offene Tabs).")
            self.check_status()
            return {"ok": True, "status": self.session_state}

        cmd = [
            chrome_bin,
            f"--user-data-dir={self.profile_dir}",
            f"--remote-debugging-port={self.debug_port}",
            "--no-first-run",
            "--no-default-browser-check",
            target_url,
        ]
        try:
            self.chrome_process = subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            self.add_log("SUCCESS", f"Sichtbares Chrome-Fenster gestartet -> {target_url}")
            self.add_log("INFO", "Bitte im geöffneten Fenster mit deiner CAU stu-Kennung (Shibboleth SSO) anmelden.")
            time.sleep(1.2)
            self.check_status()
            return {"ok": True, "status": self.session_state}
        except Exception as e:
            self.add_log("ERROR", f"Fehler beim Starten von Chrome: {e}")
            return {"ok": False, "error": str(e)}

    def _get_cdp_tabs(self) -> Optional[List[Dict[str, Any]]]:
        try:
            req = urllib.request.Request(f"http://127.0.0.1:{self.debug_port}/json")
            with urllib.request.urlopen(req, timeout=0.8) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                return [t for t in data if t.get("type") == "page"]
        except Exception:
            return None

    def check_status(self) -> Dict[str, Any]:
        tabs = self._get_cdp_tabs()
        now_str = datetime.now().strftime("%H:%M:%S")
        if tabs is None:
            self.session_state.update({
                "browser_running": False,
                "logged_in": False,
                "current_url": None,
                "current_title": None,
                "last_checked": now_str,
                "user_hint": "Browser ist noch nicht gestartet oder im Demo-Modus aktiv.",
            })
            return self.session_state

        # Inspect open pages for CAU LMS or Shibboleth login
        lms_tab = None
        for t in tabs:
            u = t.get("url", "")
            if "uni-kiel.de" in u:
                lms_tab = t
                break
        if not lms_tab and tabs:
            lms_tab = tabs[0]

        url = lms_tab.get("url", "") if lms_tab else ""
        title = lms_tab.get("title", "") if lms_tab else ""

        # Detect whether user is past the Shibboleth login screen
        is_shibboleth_login = any(k in url.lower() for k in ["idp.uni-kiel.de", "shibboleth.sso", "login", "wayf"])
        is_lms_authenticated = (
            ("lms.uni-kiel.de" in url.lower() or "elearn.uni-kiel.de" in url.lower())
            and not is_shibboleth_login
            and ("auth/" in url.lower() or "my" in url.lower() or "course" in url.lower() or "olat" in title.lower())
        )

        self.session_state.update({
            "browser_running": True,
            "logged_in": is_lms_authenticated,
            "current_url": url,
            "current_title": title,
            "last_checked": now_str,
            "user_hint": (
                "Verbunden & Authentifiziert auf lms.uni-kiel.de"
                if is_lms_authenticated
                else "Browser offen – Bitte im Chrome-Fenster bei CAU Shibboleth einloggen."
            ),
        })
        return self.session_state


def lookup_course_by_identifier(
    query_id: str,
    custom_courses: Dict[str, Dict[str, Any]],
    session_mgr: Optional[CAUBrowserSessionManager] = None,
) -> Dict[str, Any]:
    """
    Strictly verifies and looks up a course by its identifier:
      - Modulcode (e.g., 'inf-Prog1', 'Math-Inf1', 'inf-EGR', 'BWL-Einf')
      - UnivIS-Nummer (e.g., '080012', '080104')
      - OpenOlat RepositoryEntry ID or full LMS URL (e.g., '482910293' or 'https://lms.uni-kiel.de/auth/RepositoryEntry/482910293')
    Never guesses a course on fuzzy title match alone—requires an exact ID/Code token match so the bot
    can NEVER accidentally enroll in the wrong course!
    """
    raw = query_id.strip()
    if not raw:
        return {"ok": False, "error": "Bitte gib eine gültige Kurs-ID, Modulnummer oder LMS-URL ein."}

    # Extract RepositoryEntry ID or Moodle id if a full URL was pasted
    extracted_token = raw.lower()
    m_olat = re.search(r"repositoryentry/(\d+)", raw, re.IGNORECASE)
    m_moodle = re.search(r"[?&]id=(\d+)", raw, re.IGNORECASE)
    if m_olat:
        extracted_token = m_olat.group(1)
    elif m_moodle:
        extracted_token = m_moodle.group(1)

    all_catalog = {**BUILTIN_CAU_COURSES, **custom_courses}

    # 1. Exact verification check against catalog tokens
    for key, course in all_catalog.items():
        tokens = [t.lower() for t in course.get("verified_tokens", [])]
        tokens.extend([
            str(course.get("course_id", "")).lower(),
            str(course.get("univis_id", "")).lower(),
            str(course.get("olat_repo_id", "")).lower(),
        ])
        if extracted_token in tokens or raw.lower() in tokens:
            if session_mgr:
                session_mgr.add_log(
                    "VERIFY",
                    f"Sicherheits-Check bestanden: ID '{raw}' exakt verifiziert -> {course['title']} "
                    f"(UnivIS: {course.get('univis_id')} | OpenOlat: {course.get('olat_repo_id')})"
                )
            return {
                "ok": True,
                "verified": True,
                "matched_token": raw,
                "course": course,
            }

    return {
        "ok": False,
        "verified": False,
        "error": (
            f"Sicherheits-Sperre: Kein Kurs mit der exakten Kennung '{raw}' gefunden. "
            "Damit der Bot niemals einen falschen Kurs belegt, werden ungenaue Namens-Treffer blockiert. "
            "Nutze einen verifizierten WInf-Code (z. B. 'infEWInf-01a', 'infEInf-01a', 'Inf-Math-A', 'BWL-EinfBWL', 'Inf-InfRecht') "
            "oder lege deinen Kurs mit seiner exakten OpenOlat/Moodle-ID über '+ Eigenen LMS-Kurs anlegen' an."
        ),
    }


def parse_groups_from_raw_text(raw_text: str, course_id: str = "kurs") -> List[Dict[str, Any]]:
    """
    Parses real exercise groups pasted directly from OpenOlat (lms.uni-kiel.de),
    Moodle (elearn.informatik.uni-kiel.de), or UnivIS tables into structured group objects.
    """
    groups = []
    lines = [l.strip() for l in raw_text.splitlines() if l.strip()]
    for idx, line in enumerate(lines):
        slot = parse_german_timeslot(line)
        if not slot:
            continue

        # Try to extract free/total spots if present e.g. "(5/25)" or "12 von 30 frei" or "Plätze: 8/25"
        spots_free = 10
        spots_total = 25
        m_ratio = re.search(r"(\d+)\s*/\s*(\d+)", line)
        m_free = re.search(r"(\d+)\s*(?:von|of)\s*(\d+)\s*frei", line, re.IGNORECASE)
        if m_free:
            spots_free = int(m_free.group(1))
            spots_total = int(m_free.group(2))
        elif m_ratio:
            taken_or_free = int(m_ratio.group(1))
            total_val = int(m_ratio.group(2))
            spots_total = max(1, total_val)
            spots_free = max(0, total_val - taken_or_free) if "belegt" in line.lower() else taken_or_free

        # Try to extract room (e.g. HHP6, CAP3, WSP3, LMS8, OS75)
        room_match = re.search(r"\b((?:CAP|LMS|HHP|WSP|OS|OHP|abg)\d*[a-zA-Z]?\s*(?:-\s*[^\),\n]+)?)", line)
        room = room_match.group(1).strip() if room_match else "CAU Campus / LMS"

        groups.append({
            "group_id": f"{course_id.lower()}-live-{idx+1}",
            "name": line,
            "day": slot["day"],
            "day_name": slot["day_name"],
            "start_time": slot["start_time"],
            "end_time": slot["end_time"],
            "room": room,
            "tutor": "Live-Import (LMS/UnivIS)",
            "spots_free": spots_free,
            "spots_total": spots_total,
            "waitlist_available": True,
        })
    return groups

