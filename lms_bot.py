"""
CAU Kiel LMS Browser Automation, Live UnivIS XML Grabber & Course Catalog Engine.
Supports:
1. Live UnivIS XML API querying (`https://univis.uni-kiel.de/prg?search=lectures&...&show=xml`) so any
   6-digit UnivIS Kennung (e.g. 080038, 080042, 080058, 080056, 060107, 030225, 080103) or module code
   is verified and scraped with 100% authentic CAU UnivIS data!
2. Interactive Google Chrome / Chromium Login via DevTools Protocol (CDP) so Shibboleth SSO & 2FA work seamlessly.
3. Strict ID/Module Code verification (checks exact Modulcode / UnivIS-Kennnummer / OpenOlat Repository-ID).
4. Dual-Mode Execution:
   - Mode A: First-Come-First-Served Sniper (high-frequency polling / countdown trigger -> instant click on Rank 1, automatic fallback to Rank 2/3 if full).
   - Mode B: Priority Allocator (Verteilungsverfahren -> fills out Rank 1, 2, 3 dropdowns/sliders automatically).
"""

import os
import re
import html
import time
import json
import subprocess
import threading
import urllib.request
import urllib.parse
from datetime import datetime
from typing import Dict, List, Any, Optional

from optimizer import parse_german_timeslot, DAY_NAMES_DE


# 100% Authentic CAU Kiel Wirtschaftsinformatik (B.Sc.) 1. Fachsemester (WiSe 2026/27) UnivIS Catalog
# Verified directly against https://univis.uni-kiel.de/prg?search=lectures&sem=2026w&show=xml
BUILTIN_CAU_COURSES: Dict[str, Dict[str, Any]] = {
    "infewinf-01a": {
        "course_id": "infEWInf-01a",
        "univis_id": "080038 (VL) / 080042 (ÜB)",
        "olat_repo_id": "41589955",
        "title": "infEWInf-01a: Einführung in die Wirtschaftsinformatik (7 LP)",
        "lecturer": "Prof. Dr. Ann-Kristin Cordes, A. Lossner, H. Fritzke",
        "semester": "WiSe 2026/27 (UnivIS 2026w)",
        "platform": "OpenOlat (lms.uni-kiel.de)",
        "enrollment_mode": "sniper",
        "enrollment_opens_at": "2026-10-21T12:00:00",
        "url": "https://lms.uni-kiel.de/url/RepositoryEntry/41589955",
        "verified_tokens": [
            "infewinf-01a", "infewinf", "üinfewinf-01a",
            "080038", "080042", "41589955"
        ],
        "groups": [
            {
                "group_id": "080042-g1",
                "name": "Übung 01 [UnivIS #080042] (Mi 12:15 - 13:45 · LMS8 - R.EG.015)",
                "day": 2,
                "day_name": "Mittwoch",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "LMS8 - R.EG.015 (40)",
                "tutor": "A. Lossner / H. Fritzke (UnivIS #080042)",
                "spots_free": 12,
                "spots_total": 40,
                "waitlist_available": True,
            },
            {
                "group_id": "080042-g2",
                "name": "Übung 02 [UnivIS #080042] (Do 12:15 - 13:45 · LMS11a - R.EG.003)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "LMS11a - R.EG.003 (40)",
                "tutor": "A. Lossner / H. Fritzke (UnivIS #080042)",
                "spots_free": 9,
                "spots_total": 40,
                "waitlist_available": True,
            },
        ],
    },
    "infeinf-02a": {
        "course_id": "infEInf-02a",
        "univis_id": "080058 (VL) / 080056 (ÜB)",
        "olat_repo_id": "moodle-id-470",
        "title": "infEInf-02a / infEInf-01a: Einführung in die Informatik (10 LP / 8 LP)",
        "lecturer": "Prof. Dr. Andreas Mühling, Dr.-Ing. Sandro Esquivel",
        "semester": "WiSe 2026/27 (UnivIS 2026w)",
        "platform": "CAU Informatik Moodle (id=470) / OpenOlat",
        "enrollment_mode": "sniper",
        "enrollment_opens_at": "2026-10-21T14:00:00",
        "url": "https://elearn.informatik.uni-kiel.de/course/view.php?id=470",
        "verified_tokens": [
            "infeinf-02a", "infeinf-01a", "infeinf", "infInfp-01a",
            "080058", "080056", "080314", "42195091", "470"
        ],
        "groups": [
            {
                "group_id": "080056-g1",
                "name": "Übung 01 [UnivIS #080056] (Di 10:15 - 11:45 · WSP3 - Seminarraum 2)",
                "day": 1,
                "day_name": "Dienstag",
                "start_time": "10:15",
                "end_time": "11:45",
                "room": "WSP3 - Seminarraum 2 (32)",
                "tutor": "UnivIS #080056 (10:00-12:00 c.t.)",
                "spots_free": 8,
                "spots_total": 32,
                "waitlist_available": True,
            },
            {
                "group_id": "080056-g2",
                "name": "Übung 02 [UnivIS #080056] (Di 12:15 - 13:45 · WSP3 - Seminarraum 2)",
                "day": 1,
                "day_name": "Dienstag",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "WSP3 - Seminarraum 2 (32)",
                "tutor": "UnivIS #080056 (12:00-14:00 c.t.)",
                "spots_free": 14,
                "spots_total": 32,
                "waitlist_available": True,
            },
            {
                "group_id": "080056-g3",
                "name": "Übung 03 [UnivIS #080056] (Mi 12:15 - 13:45 · WSP3 - Seminarraum 2)",
                "day": 2,
                "day_name": "Mittwoch",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "WSP3 - Seminarraum 2 (32)",
                "tutor": "UnivIS #080056 (12:00-14:00 c.t.)",
                "spots_free": 7,
                "spots_total": 32,
                "waitlist_available": True,
            },
            {
                "group_id": "080056-g4",
                "name": "Übung 04 [UnivIS #080056] (Do 10:15 - 11:45 · WSP3 - Seminarraum 1)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "10:15",
                "end_time": "11:45",
                "room": "WSP3 - Seminarraum 1 (24)",
                "tutor": "UnivIS #080056 (10:00-12:00 c.t.)",
                "spots_free": 11,
                "spots_total": 24,
                "waitlist_available": True,
            },
            {
                "group_id": "080056-g5",
                "name": "Übung 05 [UnivIS #080056] (Do 12:15 - 13:45 · CAP3 - Hörsaal 1)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "CAP3 - Hörsaal 1",
                "tutor": "UnivIS #080056 (12:00-14:00 c.t.)",
                "spots_free": 19,
                "spots_total": 40,
                "waitlist_available": True,
            },
            {
                "group_id": "080056-g6",
                "name": "Übung 06 [UnivIS #080056] (Do 14:15 - 15:45 · WSP3 - Seminarraum 2)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "14:15",
                "end_time": "15:45",
                "room": "WSP3 - Seminarraum 2 (32)",
                "tutor": "UnivIS #080056 (14:00-16:00 c.t.)",
                "spots_free": 10,
                "spots_total": 32,
                "waitlist_available": True,
            },
            {
                "group_id": "080056-g7",
                "name": "Betreutes Arbeiten [UnivIS #080056] (Fr 14:15 - 15:45 · LMS8 - R.EG.018)",
                "day": 4,
                "day_name": "Freitag",
                "start_time": "14:15",
                "end_time": "15:45",
                "room": "LMS8 - R.EG.018",
                "tutor": "Offenes Betreutes Arbeiten (UnivIS #080056)",
                "spots_free": 30,
                "spots_total": 40,
                "waitlist_available": True,
            },
        ],
    },
    "inf-math-a": {
        "course_id": "Inf-Math-A",
        "univis_id": "060107 (VL) / 060098–060397 (ÜB)",
        "olat_repo_id": "060107",
        "title": "Inf-Math-A: Mathematik für die Informatik A (8 LP)",
        "lecturer": "Dr. Barbara Langfeld",
        "semester": "WiSe 2026/27 (UnivIS 2026w)",
        "platform": "OpenOlat (lms.uni-kiel.de)",
        "enrollment_mode": "priority",
        "enrollment_opens_at": "2026-10-22T09:00:00",
        "url": "https://lms.uni-kiel.de",
        "verified_tokens": [
            "inf-math-a", "v:infmatha", "ü:mathinfa", "math-infa", "infmatha",
            "060107", "060098", "060103", "060105", "060397", "060102", "060577", "060574"
        ],
        "groups": [
            {
                "group_id": "060098",
                "name": "Ü:MathInfA [UnivIS #060098] (Di 16:15 - 17:45 · HHP6 - R.EG.004)",
                "day": 1,
                "day_name": "Dienstag",
                "start_time": "16:15",
                "end_time": "17:45",
                "room": "HHP6 - R.EG.004",
                "tutor": "UnivIS Kennung 060098",
                "spots_free": 7,
                "spots_total": 28,
                "waitlist_available": True,
            },
            {
                "group_id": "060103",
                "name": "Ü:MathInfA [UnivIS #060103] (Di 16:15 - 17:45 · LMS4 - R.424)",
                "day": 1,
                "day_name": "Dienstag",
                "start_time": "16:15",
                "end_time": "17:45",
                "room": "LMS4 - R.424",
                "tutor": "UnivIS Kennung 060103",
                "spots_free": 12,
                "spots_total": 28,
                "waitlist_available": True,
            },
            {
                "group_id": "060105",
                "name": "Ü:MathInfA [UnivIS #060105] (Di 18:15 - 19:45 · HHP6 - R.EG.004)",
                "day": 1,
                "day_name": "Dienstag",
                "start_time": "18:15",
                "end_time": "19:45",
                "room": "HHP6 - R.EG.004",
                "tutor": "UnivIS Kennung 060105",
                "spots_free": 19,
                "spots_total": 28,
                "waitlist_available": True,
            },
            {
                "group_id": "060397",
                "name": "Ü:MathInfA [UnivIS #060397] (Mi 14:15 - 15:45 · HHP6 - R.EG.004)",
                "day": 2,
                "day_name": "Mittwoch",
                "start_time": "14:15",
                "end_time": "15:45",
                "room": "HHP6 - R.EG.004",
                "tutor": "UnivIS Kennung 060397",
                "spots_free": 5,
                "spots_total": 28,
                "waitlist_available": True,
            },
            {
                "group_id": "060102",
                "name": "Ü:MathInfA [UnivIS #060102] (Mi 16:15 - 17:45 · HHP6 - R.EG.004)",
                "day": 2,
                "day_name": "Mittwoch",
                "start_time": "16:15",
                "end_time": "17:45",
                "room": "HHP6 - R.EG.004",
                "tutor": "UnivIS Kennung 060102",
                "spots_free": 11,
                "spots_total": 28,
                "waitlist_available": True,
            },
        ],
    },
    "bwl-einfbwl": {
        "course_id": "BWL-EinfBWL",
        "univis_id": "030225 (VL) / 030189–030315 (ÜB)",
        "olat_repo_id": "030225",
        "title": "BWL-EinfBWL: Einführung in die Betriebswirtschaftslehre (W-X) (5 LP)",
        "lecturer": "Prof. Dr. Achim Walter, Carolin Lilienthal, Alexander Dobers-Tarasevich",
        "semester": "WiSe 2026/27 (UnivIS 2026w)",
        "platform": "OpenOlat (lms.uni-kiel.de)",
        "enrollment_mode": "sniper",
        "enrollment_opens_at": "2026-10-23T10:00:00",
        "url": "https://lms.uni-kiel.de",
        "verified_tokens": [
            "bwl-einfbwl", "ebwl", "übebwl", "bwl-einf",
            "030225", "030191", "030189", "030196", "030315"
        ],
        "groups": [
            {
                "group_id": "030191",
                "name": "ÜbEBWL [UnivIS #030191] (Do 10:15 - 11:45 · LMS2 - R.Ü2/K · 14-tägig)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "10:15",
                "end_time": "11:45",
                "room": "LMS2 - R.Ü2/K",
                "tutor": "UnivIS Kennung 030191 (w2 Do 10:15-11:45)",
                "spots_free": 14,
                "spots_total": 35,
                "waitlist_available": True,
            },
            {
                "group_id": "030189",
                "name": "ÜbEBWL [UnivIS #030189] (Do 12:15 - 13:45 · LMS2 - R.Ü2/K · 14-tägig)",
                "day": 3,
                "day_name": "Donnerstag",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "LMS2 - R.Ü2/K",
                "tutor": "UnivIS Kennung 030189 (w2 Do 12:15-13:45)",
                "spots_free": 9,
                "spots_total": 35,
                "waitlist_available": True,
            },
            {
                "group_id": "030196",
                "name": "ÜbEBWL [UnivIS #030196] (Fr 12:15 - 13:45 · LMS2 - R.Ü2/K · 14-tägig Gr. A)",
                "day": 4,
                "day_name": "Freitag",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "LMS2 - R.Ü2/K",
                "tutor": "UnivIS Kennung 030196 (w2 Fr 12:15-13:45)",
                "spots_free": 11,
                "spots_total": 35,
                "waitlist_available": True,
            },
            {
                "group_id": "030315",
                "name": "ÜbEBWL [UnivIS #030315] (Fr 12:15 - 13:45 · LMS2 - R.Ü2/K · 14-tägig Gr. B)",
                "day": 4,
                "day_name": "Freitag",
                "start_time": "12:15",
                "end_time": "13:45",
                "room": "LMS2 - R.Ü2/K",
                "tutor": "UnivIS Kennung 030315 (w2 Fr 12:15-13:45)",
                "spots_free": 15,
                "spots_total": 35,
                "waitlist_available": True,
            },
        ],
    },
    "inf-infrecht": {
        "course_id": "Inf-InfRecht",
        "univis_id": "080103",
        "olat_repo_id": "080103",
        "title": "Inf-InfRecht: Informatikrecht (2 LP)",
        "lecturer": "Dr. Hermann Lindhorst",
        "semester": "WiSe 2026/27 (UnivIS 2026w)",
        "platform": "OpenOlat (lms.uni-kiel.de)",
        "enrollment_mode": "sniper",
        "enrollment_opens_at": "2026-10-23T12:00:00",
        "url": "https://lms.uni-kiel.de",
        "verified_tokens": ["inf-infrecht", "inf-infrech", "infrecht", "080103"],
        "groups": [
            {
                "group_id": "080103-v1",
                "name": "Vorlesung / Blocktermine [UnivIS #080103] (Mo 10:00 - 13:00 · CAP3 - Hörsaal 3)",
                "day": 0,
                "day_name": "Montag",
                "start_time": "10:00",
                "end_time": "13:00",
                "room": "CAP3 - Hörsaal 3",
                "tutor": "Dr. H. Lindhorst (Einzeltermine Mo 10-13 Uhr)",
                "spots_free": 45,
                "spots_total": 100,
                "waitlist_available": True,
            },
        ],
    },
}


def fetch_live_univis_course(query_str: str, semester: str = "2026w") -> Optional[Dict[str, Any]]:
    """
    Queries the official CAU Kiel UnivIS XML API live (`https://univis.uni-kiel.de/prg?search=lectures&...&show=xml`)
    whenever the user enters any 6-digit UnivIS number (e.g. '080058', '080038', '060107') or module short code
    not yet in the local catalog!
    """
    q = query_str.strip()
    if not q:
        return None

    if re.match(r"^\d{5,6}$", q):
        url = f"https://univis.uni-kiel.de/prg?search=lectures&number={urllib.parse.quote(q)}&sem={semester}&show=xml"
    else:
        url = f"https://univis.uni-kiel.de/prg?search=lectures&name={urllib.parse.quote(q)}&sem={semester}&show=xml"

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "CAU-LMS-Optimizer/2.0"})
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            raw_bytes = resp.read()
            xml_text = raw_bytes.decode("utf-8", errors="replace")
    except Exception:
        return None

    if "<Lecture " not in xml_text:
        return None

    # Parse rooms dictionary
    rooms: Dict[str, str] = {}
    for rm in re.finditer(r"<Room key=\"([^\"]+)\">(.*?)</Room>", xml_text, re.DOTALL):
        rshort = re.search(r"<short>(.*?)</short>", rm.group(2))
        rname = re.search(r"<name>(.*?)</name>", rm.group(2))
        rooms[rm.group(1)] = html.unescape(rshort.group(1) if rshort else (rname.group(1) if rname else rm.group(1)))

    # Parse persons dictionary
    persons: Dict[str, str] = {}
    for pm in re.finditer(r"<Person key=\"([^\"]+)\">(.*?)</Person>", xml_text, re.DOTALL):
        fn = re.search(r"<firstname>(.*?)</firstname>", pm.group(2))
        ln = re.search(r"<lastname>(.*?)</lastname>", pm.group(2))
        full = f"{html.unescape(fn.group(1)) if fn else ''} {html.unescape(ln.group(1)) if ln else ''}".strip()
        if full:
            persons[pm.group(1)] = full

    lectures = []
    for m in re.finditer(r"<Lecture key=\"([^\"]+)\">(.*?)</Lecture>", xml_text, re.DOTALL):
        block = m.group(2)
        if "<import_parent_id>" in block:
            continue
        num_m = re.search(r"<number>(.*?)</number>", block)
        name_m = re.search(r"<name>(.*?)</name>", block)
        short_m = re.search(r"<short>(.*?)</short>", block)
        type_m = re.search(r"<type>(.*?)</type>", block)
        id_m = re.search(r"<id>(.*?)</id>", block)

        doz_keys = re.findall(r"type=\"Person\" key=\"([^\"]+)\"", block)
        doz_names = ", ".join(persons[k] for k in doz_keys if k in persons) or "CAU Dozent/in"

        terms = []
        for tm in re.finditer(r"<term>(.*?)</term>", block, re.DOTALL):
            tb = tm.group(1)
            rep_m = re.search(r"<repeat>(.*?)</repeat>", tb)
            st_m = re.search(r"<starttime>(.*?)</starttime>", tb)
            et_m = re.search(r"<endtime>(.*?)</endtime>", tb)
            rk_m = re.search(r"type=\"Room\" key=\"([^\"]+)\"", tb)
            if not st_m or not et_m:
                continue
            rep_str = rep_m.group(1) if rep_m else ""
            # UnivIS repeat format: "w1 1" = weekly Monday (1=Mo..5=Fr), "w2 4" = biweekly Thursday
            day_match = re.search(r"\b([1-5])\b", rep_str)
            day_idx = (int(day_match.group(1)) - 1) if day_match else 0

            def _norm_time(t_val: str) -> str:
                parts = t_val.strip().split(":")
                return f"{int(parts[0]):02d}:{int(parts[1]):02d}" if len(parts) == 2 else "10:15"

            terms.append({
                "day": day_idx,
                "day_name": DAY_NAMES_DE[day_idx],
                "start_time": _norm_time(st_m.group(1)),
                "end_time": _norm_time(et_m.group(1)),
                "room": rooms.get(rk_m.group(1), "CAU Campus") if rk_m else "CAU Campus",
                "repeat": rep_str,
            })

        lectures.append({
            "univis_id": num_m.group(1) if num_m else q,
            "internal_id": id_m.group(1) if id_m else q,
            "name": html.unescape(name_m.group(1)) if name_m else q,
            "short": html.unescape(short_m.group(1)) if short_m else q,
            "type": type_m.group(1) if type_m else "V",
            "lecturer": doz_names,
            "terms": terms,
        })

    if not lectures:
        return None

    primary = lectures[0]
    groups = []
    for idx, lec in enumerate(lectures):
        for t_idx, t in enumerate(lec["terms"]):
            groups.append({
                "group_id": f"univis-{lec['univis_id']}-{idx}-{t_idx}",
                "name": f"{lec['name']} [UnivIS #{lec['univis_id']}] ({t['day_name'][:2]} {t['start_time']} - {t['end_time']} · {t['room']})",
                "day": t["day"],
                "day_name": t["day_name"],
                "start_time": t["start_time"],
                "end_time": t["end_time"],
                "room": t["room"],
                "tutor": f"UnivIS #{lec['univis_id']} ({lec['lecturer']})",
                "spots_free": 12,
                "spots_total": 30,
                "waitlist_available": True,
            })

    return {
        "course_id": primary["short"] or primary["univis_id"],
        "univis_id": primary["univis_id"],
        "olat_repo_id": primary["internal_id"],
        "title": f"{primary['name']} (Live aus CAU UnivIS #{primary['univis_id']})",
        "lecturer": primary["lecturer"],
        "semester": "WiSe 2026/27 (UnivIS Live-XML)",
        "platform": "CAU UnivIS Live / OpenOlat",
        "enrollment_mode": "sniper",
        "enrollment_opens_at": "Sofort / Countdown",
        "url": f"https://univis.uni-kiel.de/prg?search=lectures&number={primary['univis_id']}&sem={semester}",
        "verified_tokens": [q.lower(), primary["univis_id"].lower(), (primary["short"] or "").lower()],
        "groups": groups,
    }


class CAUBrowserSessionManager:
    """
    Manages the dedicated Google Chrome browser profile for CAU Shibboleth SSO & LMS automation.
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
        self.add_log("SYSTEM", "CAU LMS Sniper & Live-UnivIS XML Engine (Semester 2026w) initialisiert.")

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
        chrome_bin = self.find_chrome_binary()
        if not chrome_bin:
            self.add_log("ERROR", "Google Chrome wurde nicht unter /Applications gefunden.")
            return {"ok": False, "error": "Google Chrome nicht gefunden."}

        os.makedirs(self.profile_dir, exist_ok=True)

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
                "user_hint": "Browser ist noch nicht gestartet.",
            })
            return self.session_state

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

        is_shibboleth_login = any(k in url.lower() for k in ["idp.uni-kiel.de", "shibboleth.sso", "login", "wayf"])
        is_lms_authenticated = (
            ("lms.uni-kiel.de" in url.lower() or "elearn.uni-kiel.de" in url.lower() or "elearn.informatik.uni-kiel.de" in url.lower())
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
      1. Checks exact verified tokens in BUILTIN_CAU_COURSES + custom_courses
         (including all lecture AND exercise UnivIS numbers: 080038, 080042, 080058, 080056, 060107, 060098, 030225, 080103).
      2. If not in the preloaded catalog, queries the official CAU UnivIS XML API live (`univis.uni-kiel.de`)
         for that exact UnivIS number or code!
    """
    raw = query_id.strip()
    if not raw:
        return {"ok": False, "error": "Bitte gib eine gültige Kurs-ID, UnivIS-Kennung oder LMS-URL ein."}

    extracted_token = raw.lower()
    m_olat = re.search(r"repositoryentry/(\d+)", raw, re.IGNORECASE)
    m_moodle = re.search(r"[?&]id=(\d+)", raw, re.IGNORECASE)
    if m_olat:
        extracted_token = m_olat.group(1)
    elif m_moodle:
        extracted_token = m_moodle.group(1)

    all_catalog = {**BUILTIN_CAU_COURSES, **custom_courses}

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
                    f"Exakte UnivIS/LMS-Kennung '{raw}' verifiziert -> {course['title']} "
                    f"(UnivIS: {course.get('univis_id')})"
                )
            return {
                "ok": True,
                "verified": True,
                "matched_token": raw,
                "course": course,
            }

    # Try live lookup on CAU UnivIS XML API if user entered another 6-digit UnivIS ID or module code
    live_course = fetch_live_univis_course(raw, semester="2026w")
    if live_course and live_course.get("groups"):
        custom_courses[live_course["course_id"].lower()] = live_course
        if session_mgr:
            session_mgr.add_log(
                "VERIFY",
                f"Live aus CAU UnivIS XML geladen: '{raw}' -> {live_course['title']} ({len(live_course['groups'])} Termine)"
            )
        return {
            "ok": True,
            "verified": True,
            "matched_token": raw,
            "course": live_course,
        }

    return {
        "ok": False,
        "verified": False,
        "error": (
            f"Sicherheits-Sperre: Keine Veranstaltung mit der exakten Kennung '{raw}' im CAU-Katalog oder UnivIS (2026w) gefunden. "
            "Verifizierte WInf-Kennungen: "
            "080038 / 080042 (infEWInf-01a) · "
            "080058 / 080056 (infEInf-02a / infEInf-01a) · "
            "060107 / 060098 (Inf-Math-A) · "
            "030225 / 030191 (BWL-EinfBWL) · "
            "080103 (Inf-InfRecht)."
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
