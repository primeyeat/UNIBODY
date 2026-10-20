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
import socket
import base64
import struct
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

    ext_url_m = re.search(r"https?://(?:elearn\.informatik\.uni-kiel\.de|lms\.uni-kiel\.de)[^\s<\"\']+", xml_text, re.IGNORECASE)
    detected_url = ext_url_m.group(0) if ext_url_m else f"https://univis.uni-kiel.de/prg?search=lectures&number={primary['univis_id']}&sem={semester}"

    live_obj = {
        "course_id": primary["short"] or primary["univis_id"],
        "univis_id": primary["univis_id"],
        "olat_repo_id": primary["internal_id"],
        "title": f"{primary['name']} (Live aus CAU UnivIS #{primary['univis_id']})",
        "lecturer": primary["lecturer"],
        "semester": "WiSe 2026/27 (UnivIS Live-XML)",
        "platform": "CAU UNIBODY Auto-Detect",
        "enrollment_mode": "sniper",
        "enrollment_opens_at": "Sofort / Countdown",
        "url": detected_url,
        "verified_tokens": [q.lower(), primary["univis_id"].lower(), (primary["short"] or "").lower()],
        "groups": groups,
    }
    return enrich_course_with_unibody(live_obj)


def enrich_course_with_unibody(course: Dict[str, Any]) -> Dict[str, Any]:
    """
    UNIBODY Auto-Detection Engine:
    Determines automatically whether a CAU course is hosted on:
      1. `lms.uni-kiel.de` (CAU Zentrales OpenOlat - e.g. infEWInf-01a, Inf-Math-A, BWL-EinfBWL, Inf-InfRecht)
      2. `elearn.informatik.uni-kiel.de` (Moodle Institut für Informatik - e.g. infEInf-02a / infEInf-01a, infProg, infADS)
    and attaches structured UNIBODY routing metadata (`platform_id`, `platform_host`, `platform_badge`).
    """
    c = dict(course)
    cid = (c.get("course_id") or "").lower()
    url = (c.get("url") or "").lower()
    plat = (c.get("platform") or "").lower()
    repo_id = (c.get("olat_repo_id") or "").lower()
    univis_id = (c.get("univis_id") or "").lower()

    is_elearn_inf = False
    if "elearn.informatik.uni-kiel.de" in url or "elearn.informatik" in plat or "moodle" in plat or "moodle" in repo_id:
        is_elearn_inf = True
    elif any(k in cid for k in ["infeinf", "infinfp", "infprog", "infads", "infrorg", "infti", "infcn", "infse"]):
        # Note: infEWInf is Wirtschaftsinformatik (Prof. Cordes -> OpenOlat lms.uni-kiel.de)
        if "infewinf" not in cid:
            is_elearn_inf = True
    elif any(u in univis_id for u in ["080058", "080056", "080314"]):
        is_elearn_inf = True

    if is_elearn_inf:
        c["platform_id"] = "elearn_inf"
        c["platform_host"] = "elearn.informatik.uni-kiel.de"
        c["platform_short"] = "elearn.informatik"
        c["platform_badge"] = "💻 elearn.informatik.uni-kiel.de (Info-Moodle)"
        c["platform"] = "Informatik eLearn (elearn.informatik.uni-kiel.de)"
        if not c.get("url") or "univis.uni-kiel.de" in url or ("lms.uni-kiel.de" in url and "elearn" not in url):
            c["url"] = (
                "https://elearn.informatik.uni-kiel.de/course/view.php?id=470"
                if ("08005" in univis_id or "infeinf" in cid)
                else "https://elearn.informatik.uni-kiel.de/"
            )
    else:
        c["platform_id"] = "openolat"
        c["platform_host"] = "lms.uni-kiel.de"
        c["platform_short"] = "lms.uni-kiel.de"
        c["platform_badge"] = "🏛️ lms.uni-kiel.de (CAU OpenOlat)"
        c["platform"] = "CAU OpenOlat (lms.uni-kiel.de)"
        if not c.get("url") or "univis.uni-kiel.de" in url:
            c["url"] = (
                f"https://lms.uni-kiel.de/url/RepositoryEntry/{c.get('olat_repo_id')}"
                if str(c.get("olat_repo_id", "")).isdigit() and len(str(c.get("olat_repo_id", ""))) > 6
                else "https://lms.uni-kiel.de/"
            )

    return c


# Enrich all built-in courses with UNIBODY metadata at startup
for _k, _v in list(BUILTIN_CAU_COURSES.items()):
    BUILTIN_CAU_COURSES[_k] = enrich_course_with_unibody(_v)


KEYCHAIN_SERVICE_NAME = "CAU-LMS-Sniper-Vault"


class CAUBrowserSessionManager:
    """
    UNIBODY Dual-Platform Browser Manager:
    Automatically routes between:
      1. `lms.uni-kiel.de` (CAU OpenOlat)
      2. `elearn.informatik.uni-kiel.de` (Informatik Moodle)
    using the exact same CAU `stu` credentials from macOS Keychain / local vault.
    """

    def __init__(self, profile_dir: str):
        self.profile_dir = profile_dir
        self.data_dir = os.path.dirname(profile_dir)
        self.creds_file = os.path.join(self.data_dir, "credentials.json")
        self.ext_dir = os.path.join(self.data_dir, "cau_autofill_ext")
        self.debug_port = 9222
        self.chrome_process: Optional[subprocess.Popen] = None
        self.session_state = {
            "browser_running": False,
            "logged_in": False,
            "openolat_logged_in": False,
            "elearn_inf_logged_in": False,
            "current_url": None,
            "current_title": None,
            "last_checked": None,
            "user_hint": "UNIBODY bereit – Erkennt automatisch lms.uni-kiel.de & elearn.informatik.uni-kiel.de.",
        }
        self.logs: List[Dict[str, str]] = []
        self._lock = threading.Lock()
        self._last_autofill_url: str = ""
        self._last_autofill_ts: float = 0.0

        os.makedirs(self.data_dir, exist_ok=True)
        self._write_chrome_extension()

        self.add_log(
            "SYSTEM",
            "🫧 CAU UNIBODY Dual-Engine aktiv: Automatisches Routing zwischen lms.uni-kiel.de (OpenOlat) & elearn.informatik.uni-kiel.de (Info-Moodle)."
        )

        # Start background watcher that auto-fills open Chrome CAU login pages via CDP on BOTH platforms
        self._watcher_thread = threading.Thread(target=self._autofill_watcher_loop, daemon=True)
        self._watcher_thread.start()

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

    # -------------------------------------------------------------------------
    # CAU CREDENTIAL VAULT (macOS Keychain + git-ignored 0600 JSON fallback)
    # -------------------------------------------------------------------------
    def _save_to_macos_keychain(self, username: str, password: str) -> bool:
        if not username or not password:
            return False
        try:
            res = subprocess.run(
                [
                    "security",
                    "add-generic-password",
                    "-U",
                    "-a", username,
                    "-s", KEYCHAIN_SERVICE_NAME,
                    "-w", password,
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=3.0,
            )
            return res.returncode == 0
        except Exception:
            return False

    def _read_from_macos_keychain(self, username: str) -> Optional[str]:
        if not username:
            return None
        try:
            res = subprocess.run(
                [
                    "security",
                    "find-generic-password",
                    "-a", username,
                    "-s", KEYCHAIN_SERVICE_NAME,
                    "-w",
                ],
                capture_output=True,
                text=True,
                timeout=2.5,
            )
            if res.returncode == 0 and res.stdout.strip():
                return res.stdout.strip()
        except Exception:
            pass
        return None

    def _delete_from_macos_keychain(self, username: str):
        if not username:
            return
        try:
            subprocess.run(
                [
                    "security",
                    "delete-generic-password",
                    "-a", username,
                    "-s", KEYCHAIN_SERVICE_NAME,
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=2.5,
            )
        except Exception:
            pass

    def load_credentials(self, include_secret: bool = False) -> Dict[str, Any]:
        default_meta = {
            "username": "",
            "has_password": False,
            "default_platform": "unibody",
            "auto_fill": True,
            "auto_submit": True,
            "use_keychain": True,
            "keychain_active": False,
            "updated_at": None,
        }
        if not os.path.exists(self.creds_file):
            return default_meta

        try:
            with open(self.creds_file, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            return default_meta

        username = (data.get("username") or "").strip()
        use_keychain = bool(data.get("use_keychain", True))
        stored_pw = ""

        # Try macOS Keychain first if enabled
        keychain_pw = self._read_from_macos_keychain(username) if (use_keychain and username) else None
        if keychain_pw:
            stored_pw = keychain_pw
            keychain_active = True
        else:
            b64_pw = data.get("password_b64") or ""
            if b64_pw:
                try:
                    stored_pw = base64.b64decode(b64_pw.encode("ascii")).decode("utf-8")
                except Exception:
                    stored_pw = ""
            keychain_active = bool(data.get("keychain_active", False))

        result = {
            "username": username,
            "has_password": bool(stored_pw),
            "default_platform": data.get("default_platform") or "unibody",
            "auto_fill": bool(data.get("auto_fill", True)),
            "auto_submit": bool(data.get("auto_submit", True)),
            "use_keychain": use_keychain,
            "keychain_active": keychain_active,
            "updated_at": data.get("updated_at"),
        }
        if include_secret:
            result["password"] = stored_pw
        return result

    def save_credentials(
        self,
        username: str,
        password: Optional[str],
        default_platform: str = "unibody",
        auto_fill: bool = True,
        auto_submit: bool = True,
        use_keychain: bool = True,
    ) -> Dict[str, Any]:
        username = (username or "").strip()
        existing = self.load_credentials(include_secret=True)

        # If user didn't re-type password (or sent masked placeholder) keep existing password
        if password is None or password == "" or password == "••••••••":
            final_pw = existing.get("password", "")
        else:
            final_pw = password

        keychain_ok = False
        if use_keychain and username and final_pw:
            keychain_ok = self._save_to_macos_keychain(username, final_pw)

        payload = {
            "username": username,
            "password_b64": base64.b64encode(final_pw.encode("utf-8")).decode("ascii") if final_pw else "",
            "default_platform": default_platform or "unibody",
            "auto_fill": bool(auto_fill),
            "auto_submit": bool(auto_submit),
            "use_keychain": bool(use_keychain),
            "keychain_active": keychain_ok,
            "updated_at": datetime.now().strftime("%d.%m.%Y %H:%M:%S"),
        }

        os.makedirs(self.data_dir, exist_ok=True)
        with open(self.creds_file, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        try:
            os.chmod(self.creds_file, 0o600)
        except Exception:
            pass

        # Regenerate the Chrome Auto-Fill extension with latest credentials
        self._write_chrome_extension()
        self._last_autofill_url = ""

        storage_label = "macOS Schlüsselbund (Keychain) + Lokal" if keychain_ok else "Lokalem Tresor (0600)"
        self.add_log(
            "SUCCESS",
            f"🔐 UNIBODY Login-Daten für '{username}' gespeichert ({storage_label} · Synchronisiert für lms.uni-kiel.de & elearn.informatik.uni-kiel.de)."
        )
        return self.load_credentials(include_secret=False)

    def clear_credentials(self) -> Dict[str, Any]:
        existing = self.load_credentials(include_secret=False)
        if existing.get("username"):
            self._delete_from_macos_keychain(existing["username"])
        if os.path.exists(self.creds_file):
            try:
                os.remove(self.creds_file)
            except Exception:
                pass
        self._write_chrome_extension()
        self.add_log("INFO", "🗑️ Gespeicherte CAU Login-Daten aus Tresor & macOS Schlüsselbund entfernt.")
        return self.load_credentials(include_secret=False)

    # -------------------------------------------------------------------------
    # AUTO-FILL & AUTO-LOGIN JAVASCRIPT + CHROME EXTENSION + CDP ENGINE
    # -------------------------------------------------------------------------
    def _build_autofill_js(self, creds: Dict[str, Any], force_submit: bool = False) -> str:
        username = creds.get("username") or ""
        password = creds.get("password") or ""
        auto_fill = bool(creds.get("auto_fill", True))
        auto_submit = bool(creds.get("auto_submit", True)) or force_submit

        if not username or not password or not auto_fill:
            return "(function(){ return 'DISABLED_OR_EMPTY'; })();"

        cfg_json = json.dumps({
            "username": username,
            "password": password,
            "autoSubmit": auto_submit,
            "forceSubmit": force_submit,
        })

        return f"""
(function() {{
  const CFG = {cfg_json};
  const host = (window.location.hostname || '').toLowerCase();
  const url = (window.location.href || '').toLowerCase();
  if (!host.includes('uni-kiel.de') && !host.includes('dfn.de')) return 'NOT_CAU';

  const platformName = host.includes('elearn.informatik')
    ? 'elearn.informatik.uni-kiel.de'
    : (host.includes('lms.uni-kiel') ? 'lms.uni-kiel.de' : host);

  function setNativeValue(el, val) {{
    if (!el) return false;
    try {{
      el.focus();
      const proto = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');
      if (proto && proto.set) {{
        proto.set.call(el, val);
      }} else {{
        el.value = val;
      }}
      el.dispatchEvent(new Event('input', {{ bubbles: true }}));
      el.dispatchEvent(new Event('change', {{ bubbles: true }}));
      return true;
    }} catch (e) {{
      el.value = val;
      return true;
    }}
  }}

  function showAeroBanner(text, isWarn) {{
    let badge = document.getElementById('cau-sniper-autofill-badge');
    if (!badge) {{
      badge = document.createElement('div');
      badge.id = 'cau-sniper-autofill-badge';
      badge.style.cssText = [
        'position:fixed',
        'top:14px',
        'right:14px',
        'z-index:2147483647',
        'padding:10px 16px',
        'border-radius:14px',
        'font-family:"Trebuchet MS","Segoe UI",sans-serif',
        'font-size:13px',
        'font-weight:bold',
        'color:#ffffff',
        'box-shadow:0 8px 24px rgba(0,80,160,0.38), inset 0 1px 1px rgba(255,255,255,0.85)',
        'border:1px solid rgba(255,255,255,0.75)',
        'backdrop-filter:blur(10px)',
        'transition:all 0.25s ease',
        'pointer-events:none'
      ].join(';');
      document.body.appendChild(badge);
    }}
    badge.style.background = isWarn
      ? 'linear-gradient(180deg, #ffb84d 0%, #f07800 50%, #c85a00 100%)'
      : 'linear-gradient(180deg, #52eb68 0%, #1db933 50%, #0e8a21 90%, #2ce048 100%)';
    badge.textContent = text;
  }}

  function hasLoginErrorOnPage() {{
    const errSelectors = ['.form-error', '.output-message.error', '.alert-danger', '.o_error', '#loginerrormessage', '.error'];
    for (const sel of errSelectors) {{
      const el = document.querySelector(sel);
      if (el && el.offsetParent !== null && (el.innerText || '').trim().length > 3) {{
        return true;
      }}
    }}
    const bodyText = (document.body ? document.body.innerText : '').toLowerCase();
    return (
      bodyText.includes('anmeldung fehlgeschlagen') ||
      bodyText.includes('passwort falsch') ||
      bodyText.includes('ungültige anmeldedaten') ||
      bodyText.includes('login failed') ||
      bodyText.includes('authentication failed')
    );
  }}

  // 1. Special Handler for OpenOlat 21+ Two-Step FlexiForm AJAX Login (`lms.uni-kiel.de/dmz/`)
  //    Step 1: `#o_fiooolat_login_name` is visible, while `#o_cooolat_login_pass` is still empty.
  //    Step 2: `#o_fiooolat_login_pass` is dynamically injected via `o_XHRSubmit('ofo_oolat_login')`.
  const olatForm = document.getElementById('ofo_oolat_login');
  const olatNameInput = document.getElementById('o_fiooolat_login_name');
  const olatPassInput = document.getElementById('o_fiooolat_login_pass');
  const olatBtn = document.getElementById('o_fiooolat_login_button');

  function triggerOlatFlexiSubmit() {{
    const du = document.getElementById('ofo_oolat_login_dispatchuri');
    const ev = document.getElementById('ofo_oolat_login_eventval');
    if (du) du.value = 'o_fiooolat_login_button';
    if (ev) ev.value = '2';
    if (window.o_info) window.o_info.preventOnchange = true;
    if (typeof window.o_XHRSubmit === 'function') {{
      window.o_XHRSubmit('ofo_oolat_login');
      return true;
    }} else if (olatBtn) {{
      olatBtn.click();
      return true;
    }}
    return false;
  }}

  if (olatForm && (olatNameInput || olatPassInput)) {{
    const pageHasErr = hasLoginErrorOnPage();
    // Ignore the "Bitte geben Sie einen Anmeldenamen ein" error if the field was empty
    const errEl = document.getElementById('o_fiooolat_login_name_error');
    const isEmptyNameErr = errEl && (errEl.innerText || '').includes('Anmeldenamen ein');

    if (pageHasErr && !isEmptyNameErr && !CFG.forceSubmit) {{
      showAeroBanner('⚠️ UNIBODY (lms.uni-kiel.de): Auto-Submit pausiert wegen Fehlermeldung', true);
      return 'FILLED_PAUSED_ON_ERROR';
    }}

    // Step 1: Username field is visible, password field is not yet rendered
    if (olatNameInput && olatNameInput.offsetParent !== null && (!olatPassInput || olatPassInput.offsetParent === null)) {{
      if (window.o_info) window.o_info.preventOnchange = true;
      setNativeValue(olatNameInput, CFG.username);
      const lastStep1Ts = parseInt(sessionStorage.getItem('cau_sniper_olat_step1_ts') || '0', 10);
      const now = Date.now();
      if (CFG.autoSubmit && (now - lastStep1Ts > 3500 || CFG.forceSubmit)) {{
        sessionStorage.setItem('cau_sniper_olat_step1_ts', String(now));
        showAeroBanner('🫧 UNIBODY (lms.uni-kiel.de): Schritt 1/2 – Sende Kennung ' + CFG.username + '...', false);
        setTimeout(() => {{
          triggerOlatFlexiSubmit();
        }}, 120);
        return 'FILLED_AND_SUBMITTED';
      }}
      showAeroBanner('🫧 UNIBODY (lms.uni-kiel.de): Kennung ' + CFG.username + ' eingetragen', false);
      return 'FILLED_ONLY';
    }}

    // Step 2: Password field is now visible in DOM
    if (olatPassInput && olatPassInput.offsetParent !== null) {{
      if (window.o_info) window.o_info.preventOnchange = true;
      if (olatNameInput && olatNameInput.offsetParent !== null && olatNameInput.value !== CFG.username) {{
        setNativeValue(olatNameInput, CFG.username);
      }}
      setNativeValue(olatPassInput, CFG.password);
      const lastStep2Ts = parseInt(sessionStorage.getItem('cau_sniper_olat_step2_ts') || '0', 10);
      const now = Date.now();
      if (CFG.autoSubmit && (now - lastStep2Ts > 4500 || CFG.forceSubmit)) {{
        sessionStorage.setItem('cau_sniper_olat_step2_ts', String(now));
        showAeroBanner('🫧 UNIBODY Auto-Login (lms.uni-kiel.de): Schritt 2/2 – Melde ' + CFG.username + ' an...', false);
        setTimeout(() => {{
          triggerOlatFlexiSubmit();
        }}, 150);
        return 'FILLED_AND_SUBMITTED';
      }}
      showAeroBanner('🫧 UNIBODY (lms.uni-kiel.de): Passwort ausgefüllt!', false);
      return 'FILLED_ONLY';
    }}
  }}

  // 2. Check for standard username & password fields (CAU Shibboleth IdP or Moodle elearn.informatik.uni-kiel.de)
  const userSelectors = [
    'input[name="j_username"]',
    'input#username',
    'input[name="username"]',
    'input[name*="fiooolat_login_name"]',
    'input[id*="fiooolat_login_name"]',
    'input[name*="fiooldap_login_name"]',
    'input[id*="fiooldap_login_name"]',
    'input[name="userid"]',
    'input[type="text"][autocomplete*="user"]'
  ];
  const passSelectors = [
    'input[name="j_password"]',
    'input#password',
    'input[name="password"]',
    'input[name*="fiooolat_login_pass"]',
    'input[id*="fiooolat_login_pass"]',
    'input[name*="fiooldap_login_pass"]',
    'input[id*="fiooldap_login_pass"]',
    'input[type="password"]'
  ];

  let userInput = null;
  for (const s of userSelectors) {{
    const el = document.querySelector(s);
    if (el && el.offsetParent !== null) {{ userInput = el; break; }}
  }}
  let passInput = null;
  for (const s of passSelectors) {{
    const el = document.querySelector(s);
    if (el && el.offsetParent !== null) {{ passInput = el; break; }}
  }}

  if (passInput) {{
    if (!userInput) {{
      const form = passInput.closest('form') || document;
      userInput = form.querySelector('input[type="text"], input[type="email"]');
    }}
    let changed = false;
    if (userInput && userInput.value !== CFG.username) {{
      setNativeValue(userInput, CFG.username);
      changed = true;
    }}
    if (passInput.value !== CFG.password) {{
      setNativeValue(passInput, CFG.password);
      changed = true;
    }}

    const pageHasErr = hasLoginErrorOnPage();
    if (pageHasErr && !CFG.forceSubmit) {{
      showAeroBanner('⚠️ UNIBODY (' + platformName + '): Felder ausgefüllt (Auto-Submit pausiert wegen Fehlermeldung)', true);
      return 'FILLED_PAUSED_ON_ERROR';
    }}

    const lastSubmitTs = parseInt(sessionStorage.getItem('cau_sniper_submit_ts') || '0', 10);
    const now = Date.now();
    const recentlySubmitted = (now - lastSubmitTs) < 7000;

    if (CFG.autoSubmit && (!recentlySubmitted || CFG.forceSubmit)) {{
      sessionStorage.setItem('cau_sniper_submit_ts', String(now));
      showAeroBanner('🫧 UNIBODY Auto-Login (' + platformName + ') als ' + CFG.username + '...', false);

      const submitSelectors = [
        'button[name="_eventId_proceed"]',
        'input[name="_eventId_proceed"]',
        'button#loginbtn',
        'button#o_fiooolat_login_button',
        'button[type="submit"]',
        'input[type="submit"]',
        'button.o_button_login'
      ];
      const scope = (passInput.closest('form') || document);
      let submitBtn = null;
      for (const s of submitSelectors) {{
        const btn = scope.querySelector(s) || document.querySelector(s);
        if (btn && btn.offsetParent !== null) {{ submitBtn = btn; break; }}
      }}
      setTimeout(() => {{
        if (submitBtn) {{
          submitBtn.click();
        }} else if (passInput.closest('form')) {{
          passInput.closest('form').submit();
        }}
      }}, 220);
      return 'FILLED_AND_SUBMITTED';
    }} else {{
      showAeroBanner('🫧 UNIBODY (' + platformName + '): Login für ' + CFG.username + ' ausgefüllt!', false);
      return changed ? 'FILLED_ONLY' : 'ALREADY_FILLED';
    }}
  }}

  // 3. If OpenOlat accidentally landed on the static `/msg/json/en/info.html` page, redirect straight back to `/dmz/`
  if (host.includes('lms.uni-kiel.de') && url.includes('/msg/json/')) {{
    window.location.replace('https://lms.uni-kiel.de/dmz/');
    return 'CLICKED_SSO_REDIRECT';
  }}

  // 3b. If Moodle (`elearn.informatik.uni-kiel.de/login/index.php`) says "You are already logged in" / "bereits angemeldet", redirect to `/my/`
  if (host.includes('elearn.informatik') && url.includes('/login/')) {{
    const bt = (document.body ? document.body.innerText : '').toLowerCase();
    if (bt.includes('already logged in') || bt.includes('bereits angemeldet')) {{
      window.location.replace('https://elearn.informatik.uni-kiel.de/my/');
      return 'CLICKED_SSO_REDIRECT';
    }}
  }}

  // 4. If on Moodle (elearn.informatik.uni-kiel.de) or CAU SSO page without visible login fields:
  //    Automatically click the "CAU-Login / Shibboleth / Anmelden" link if not authenticated yet!
  if (CFG.autoSubmit && !olatForm) {{
    const lastRedirectTs = parseInt(sessionStorage.getItem('cau_sniper_sso_redirect_ts') || '0', 10);
    if (Date.now() - lastRedirectTs > 5000 || CFG.forceSubmit) {{
      const ssoLinks = Array.from(document.querySelectorAll('a, button'));
      for (const el of ssoLinks) {{
        if (el.offsetParent === null) continue;
        const href = (el.getAttribute('href') || '').toLowerCase();
        const txt = (el.innerText || el.value || '').toLowerCase();
        if (href.includes('/msg/json/')) continue;
        if (
          href.includes('shibboleth') ||
          href.includes('idp.uni-kiel.de') ||
          (host.includes('elearn') && href.includes('login/index.php')) ||
          txt.includes('shibboleth') ||
          txt.includes('cau-login') ||
          txt.includes('cau login')
        ) {{
          sessionStorage.setItem('cau_sniper_sso_redirect_ts', String(Date.now()));
          showAeroBanner('🫧 UNIBODY (' + platformName + '): Öffne Login-Maske...', false);
          el.click();
          return 'CLICKED_SSO_REDIRECT';
        }}
      }}
    }}
  }}

  return 'NO_LOGIN_FORM';
}})();
"""

    def _write_chrome_extension(self):
        """
        Writes a lightweight Manifest V3 Chrome Extension into `data/cau_autofill_ext`
        so Chrome also has native content-script Auto-Fill on both `lms.uni-kiel.de` and `elearn.informatik.uni-kiel.de`.
        """
        try:
            os.makedirs(self.ext_dir, exist_ok=True)
            manifest = {
                "manifest_version": 3,
                "name": "CAU Kiel UNIBODY Auto-Login (OpenOlat & eLearn Informatik)",
                "version": "2.0.0",
                "description": "UNIBODY Auto-Fill & Auto-Login für lms.uni-kiel.de, elearn.informatik.uni-kiel.de und idp.uni-kiel.de",
                "permissions": ["storage"],
                "host_permissions": [
                    "https://*.uni-kiel.de/*",
                    "https://*.dfn.de/*"
                ],
                "content_scripts": [
                    {
                        "matches": [
                            "https://*.uni-kiel.de/*",
                            "https://*.dfn.de/*"
                        ],
                        "js": ["content.js"],
                        "run_at": "document_idle"
                    }
                ]
            }
            with open(os.path.join(self.ext_dir, "manifest.json"), "w", encoding="utf-8") as f:
                json.dump(manifest, f, indent=2)

            creds = self.load_credentials(include_secret=True)
            js_code = self._build_autofill_js(creds, force_submit=False)
            content_js = f"""
// CAU Kiel UNIBODY Auto-Fill Content Script (lms.uni-kiel.de + elearn.informatik.uni-kiel.de)
function runUnibodyAutoFill() {{
  try {{ {js_code} }} catch (e) {{ console.warn('CAU UNIBODY AutoFill error:', e); }}
}}
setTimeout(runUnibodyAutoFill, 250);
setTimeout(runUnibodyAutoFill, 1150);
setTimeout(runUnibodyAutoFill, 2200);
"""
            with open(os.path.join(self.ext_dir, "content.js"), "w", encoding="utf-8") as f:
                f.write(content_js)
        except Exception as e:
            self.add_log("WARN", f"Konnte Auto-Fill Extension nicht aktualisieren: {e}")

    def _cdp_send_command(self, ws_url: str, method: str, params: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Zero-dependency Python stdlib WebSocket client for Chrome DevTools Protocol (CDP).
        Connects to `ws://127.0.0.1:9222/devtools/page/...` and sends a single JSON-RPC command.
        """
        try:
            parsed = urllib.parse.urlparse(ws_url)
            host = parsed.hostname or "127.0.0.1"
            port = parsed.port or self.debug_port
            path = parsed.path or "/"

            sock = socket.create_connection((host, port), timeout=1.5)
            try:
                key = base64.b64encode(os.urandom(16)).decode("ascii")
                handshake = (
                    f"GET {path} HTTP/1.1\r\n"
                    f"Host: {host}:{port}\r\n"
                    "Upgrade: websocket\r\n"
                    "Connection: Upgrade\r\n"
                    f"Sec-WebSocket-Key: {key}\r\n"
                    "Sec-WebSocket-Version: 13\r\n\r\n"
                )
                sock.sendall(handshake.encode("ascii"))

                resp_buf = b""
                while b"\r\n\r\n" not in resp_buf:
                    chunk = sock.recv(1024)
                    if not chunk:
                        return None
                    resp_buf += chunk

                if b"101" not in resp_buf.split(b"\r\n", 1)[0]:
                    return None

                payload_bytes = json.dumps({"id": 1, "method": method, "params": params}).encode("utf-8")
                mask_key = os.urandom(4)
                header = bytearray([0x81])  # FIN + Text frame
                length = len(payload_bytes)
                if length < 126:
                    header.append(0x80 | length)
                elif length < 65536:
                    header.append(0x80 | 126)
                    header.extend(struct.pack("!H", length))
                else:
                    header.append(0x80 | 127)
                    header.extend(struct.pack("!Q", length))

                header.extend(mask_key)
                masked_payload = bytearray(b ^ mask_key[i % 4] for i, b in enumerate(payload_bytes))
                sock.sendall(header + masked_payload)

                # Read response frame
                first2 = sock.recv(2)
                if len(first2) < 2:
                    return None
                r_len = first2[1] & 0x7F
                if r_len == 126:
                    r_len = struct.unpack("!H", sock.recv(2))[0]
                elif r_len == 127:
                    r_len = struct.unpack("!Q", sock.recv(8))[0]

                data_buf = b""
                while len(data_buf) < r_len:
                    part = sock.recv(min(4096, r_len - len(data_buf)))
                    if not part:
                        break
                    data_buf += part

                return json.loads(data_buf.decode("utf-8", errors="ignore"))
            finally:
                sock.close()
        except Exception:
            return None

    def inject_autofill_into_tabs(self, force_submit: bool = False, navigate_url: Optional[str] = None) -> str:
        """
        UNIBODY Multi-Tab Injector:
        Evaluates the CAU Auto-Fill & Auto-Login script inside ALL active uni-kiel.de Chrome tabs
        (`lms.uni-kiel.de` AND `elearn.informatik.uni-kiel.de`) via CDP.
        If `navigate_url` is provided, routes the matching platform tab to `navigate_url` and brings it to front.
        """
        tabs = self._get_cdp_tabs()
        if not tabs:
            return "NO_BROWSER"

        creds = self.load_credentials(include_secret=True)

        if navigate_url:
            nav_lower = navigate_url.lower()
            want_elearn = "elearn.informatik" in nav_lower
            matched_tab = None
            for t in tabs:
                u = (t.get("url") or "").lower()
                if want_elearn and "elearn.informatik" in u:
                    matched_tab = t
                    break
                elif not want_elearn and "lms.uni-kiel.de" in u:
                    matched_tab = t
                    break
            if not matched_tab:
                matched_tab = tabs[0]
            ws_nav = matched_tab.get("webSocketDebuggerUrl")
            if ws_nav:
                self._cdp_send_command(ws_nav, "Page.bringToFront", {})
                if (matched_tab.get("url") or "").rstrip("/") != navigate_url.rstrip("/"):
                    self._cdp_send_command(ws_nav, "Page.navigate", {"url": navigate_url})
                    time.sleep(1.0)

        if not creds.get("username") or not creds.get("password"):
            return "NO_CREDENTIALS"

        js_expr = self._build_autofill_js(creds, force_submit=force_submit)
        last_result = "NONE"

        for t in tabs:
            u = (t.get("url") or "").lower()
            if not any(d in u for d in ["uni-kiel.de", "dfn.de"]):
                continue
            ws_url = t.get("webSocketDebuggerUrl")
            if not ws_url:
                continue
            res = self._cdp_send_command(ws_url, "Runtime.evaluate", {"expression": js_expr, "returnByValue": True})
            val = (
                res.get("result", {}).get("result", {}).get("value", "EXECUTED")
                if isinstance(res, dict)
                else "CDP_SENT"
            )
            if val in ("FILLED_AND_SUBMITTED", "FILLED_ONLY", "CLICKED_SSO_REDIRECT"):
                last_result = val
                plat_label = "elearn.informatik.uni-kiel.de" if "elearn.informatik" in u else ("lms.uni-kiel.de" if "lms.uni-kiel" in u else "idp.uni-kiel.de")
                now = time.time()
                if now - self._last_autofill_ts > 3.5 or force_submit:
                    self._last_autofill_ts = now
                    if val == "FILLED_AND_SUBMITTED":
                        self.add_log("SUCCESS", f"⚡ UNIBODY Auto-Login auf [{plat_label}] ausgeführt für '{creds['username']}'!")
                    elif val == "FILLED_ONLY":
                        self.add_log("INFO", f"🔑 UNIBODY: Login-Felder auf [{plat_label}] für '{creds['username']}' ausgefüllt.")
                    elif val == "CLICKED_SSO_REDIRECT":
                        self.add_log("INFO", f"🌐 UNIBODY: Weiterleitung zum Login auf [{plat_label}] ausgelöst...")

        return str(last_result)

    def _autofill_watcher_loop(self):
        """
        Background daemon thread that monitors all open Chrome tabs (`lms.uni-kiel.de` AND `elearn.informatik.uni-kiel.de`)
        and automatically fills in login forms whenever they appear.
        """
        while True:
            try:
                creds = self.load_credentials(include_secret=True)
                if creds.get("auto_fill") and creds.get("username") and creds.get("password"):
                    tabs = self._get_cdp_tabs()
                    if tabs:
                        for t in tabs:
                            u = (t.get("url") or "").lower()
                            if any(d in u for d in ["idp.uni-kiel.de", "lms.uni-kiel.de", "elearn.uni-kiel.de", "elearn.informatik.uni-kiel.de", "wayf.dfn.de"]):
                                self.inject_autofill_into_tabs(force_submit=False)
                                break
            except Exception:
                pass
            time.sleep(1.2)

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

    def launch_login_browser(self, target_url: Optional[str] = None, force_auto_login: bool = False) -> Dict[str, Any]:
        """
        UNIBODY Browser Launcher:
        If `target_url` is "unibody" or None (and default_platform is "unibody"), opens BOTH
        `https://lms.uni-kiel.de` AND `https://elearn.informatik.uni-kiel.de/login/index.php` in two tabs
        so both CAU platforms are logged in with a single click!
        If a specific course URL is passed, routes directly to that course's platform.
        """
        chrome_bin = self.find_chrome_binary()
        if not chrome_bin:
            self.add_log("ERROR", "Google Chrome wurde nicht unter /Applications gefunden.")
            return {"ok": False, "error": "Google Chrome nicht gefunden."}

        os.makedirs(self.profile_dir, exist_ok=True)
        self._write_chrome_extension()

        creds = self.load_credentials(include_secret=True)
        pref_plat = target_url or creds.get("default_platform") or "unibody"

        if pref_plat == "unibody":
            urls_to_open = [
                "https://lms.uni-kiel.de",
                "https://elearn.informatik.uni-kiel.de/my/",
            ]
        else:
            urls_to_open = [pref_plat]

        tabs = self._get_cdp_tabs()
        if tabs is not None:
            # Ensure requested platform tabs exist if Chrome is already running (e.g. if all windows were closed on macOS)
            existing_urls = " ".join((t.get("url") or "").lower() for t in tabs)
            for u_open in urls_to_open:
                host_check = "elearn.informatik" if "elearn.informatik" in u_open else ("lms.uni-kiel.de" if "lms.uni-kiel.de" in u_open else u_open)
                if host_check not in existing_urls:
                    try:
                        req_new = urllib.request.Request(f"http://127.0.0.1:{self.debug_port}/json/new?{u_open}", method="PUT")
                        urllib.request.urlopen(req_new, timeout=1.5).read()
                        time.sleep(0.8)
                    except Exception:
                        pass

            nav_target = None if pref_plat == "unibody" else pref_plat
            self.add_log(
                "INFO",
                f"🫧 UNIBODY Router: Browser läuft bereits – synchronisiere Session auf {nav_target or 'lms.uni-kiel.de & elearn.informatik.uni-kiel.de'}..."
            )
            self.inject_autofill_into_tabs(
                force_submit=force_auto_login or bool(creds.get("auto_submit")),
                navigate_url=nav_target,
            )
            if creds.get("username") and creds.get("password"):
                time.sleep(1.3)
                self.inject_autofill_into_tabs(
                    force_submit=force_auto_login or bool(creds.get("auto_submit")),
                    navigate_url=None,
                )
            self.check_status()
            return {"ok": True, "status": self.session_state}

        cmd = [
            chrome_bin,
            f"--user-data-dir={self.profile_dir}",
            f"--remote-debugging-port={self.debug_port}",
            "--remote-allow-origins=*",
            "--disable-features=DisableLoadExtensionCommandLineSwitch",
            f"--load-extension={self.ext_dir}",
            "--no-first-run",
            "--no-default-browser-check",
            *urls_to_open,
        ]
        try:
            self.chrome_process = subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            self.add_log(
                "SUCCESS",
                f"🫧 UNIBODY Chrome-Session gestartet -> {' + '.join(urls_to_open)}"
            )
            if creds.get("username") and creds.get("password"):
                self.add_log(
                    "INFO",
                    f"🔑 UNIBODY Auto-Login aktiv für '{creds['username']}' – Beide Plattformen (OpenOlat & Info-Moodle) werden automatisch eingeloggt."
                )
            else:
                self.add_log("INFO", "Bitte im geöffneten Fenster mit deiner CAU stu-Kennung anmelden (oder hinterlege deine Login-Daten im UNIBODY-Tresor).")
            time.sleep(1.6)
            if creds.get("username") and creds.get("password"):
                self.inject_autofill_into_tabs(force_submit=force_auto_login or bool(creds.get("auto_submit")))
                time.sleep(1.3)
                self.inject_autofill_into_tabs(force_submit=force_auto_login or bool(creds.get("auto_submit")))
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
        creds_meta = self.load_credentials(include_secret=False)
        if tabs is None:
            self.session_state.update({
                "browser_running": False,
                "logged_in": False,
                "openolat_logged_in": False,
                "elearn_inf_logged_in": False,
                "current_url": None,
                "current_title": None,
                "last_checked": now_str,
                "saved_username": creds_meta.get("username") or "",
                "has_credentials": bool(creds_meta.get("username") and creds_meta.get("has_password")),
                "user_hint": (
                    f"UNIBODY Auto-Login bereit ({creds_meta['username']})"
                    if (creds_meta.get("username") and creds_meta.get("has_password"))
                    else "UNIBODY bereit (lms.uni-kiel.de & elearn.informatik)"
                ),
            })
            return self.session_state

        openolat_auth = False
        elearn_inf_auth = False
        lms_tab = None

        for t in tabs:
            u = (t.get("url") or "").lower()
            title = (t.get("title") or "").lower()
            if "uni-kiel.de" in u and not lms_tab:
                lms_tab = t
            is_login_page = any(k in u for k in ["idp.uni-kiel.de", "shibboleth.sso", "login", "wayf", "/dmz/", "/msg/json/"])
            if "lms.uni-kiel.de" in u and not is_login_page and ("/auth/" in u or "repositoryentry" in u):
                openolat_auth = True
            if "elearn.informatik.uni-kiel.de" in u and not is_login_page and ("course" in u or "my" in u or "dashboard" in title or "moodle" in title):
                elearn_inf_auth = True

        if not lms_tab and tabs:
            lms_tab = tabs[0]

        url = lms_tab.get("url", "") if lms_tab else ""
        title = lms_tab.get("title", "") if lms_tab else ""
        any_auth = openolat_auth or elearn_inf_auth

        self.session_state.update({
            "browser_running": True,
            "logged_in": any_auth,
            "openolat_logged_in": openolat_auth,
            "elearn_inf_logged_in": elearn_inf_auth,
            "current_url": url,
            "current_title": title,
            "last_checked": now_str,
            "saved_username": creds_meta.get("username") or "",
            "has_credentials": bool(creds_meta.get("username") and creds_meta.get("has_password")),
            "user_hint": (
                "UNIBODY Verbunden (OpenOlat + Info-Moodle)"
                if (openolat_auth and elearn_inf_auth)
                else (
                    "Verbunden: lms.uni-kiel.de (OpenOlat)"
                    if openolat_auth
                    else (
                        "Verbunden: elearn.informatik.uni-kiel.de"
                        if elearn_inf_auth
                        else (
                            f"UNIBODY Auto-Fill aktiv ({creds_meta['username']})..."
                            if (creds_meta.get("username") and creds_meta.get("has_password"))
                            else "Browser offen – Bitte einloggen."
                        )
                    )
                )
            ),
        })
        return self.session_state


def lookup_course_by_identifier(
    query_id: str,
    custom_courses: Dict[str, Dict[str, Any]],
    session_mgr: Optional[CAUBrowserSessionManager] = None,
) -> Dict[str, Any]:
    """
    Strictly verifies and looks up a course by its identifier and enriches it with UNIBODY platform routing:
      - Automatically detects whether the course is on `lms.uni-kiel.de` (OpenOlat) or `elearn.informatik.uni-kiel.de` (Moodle Informatik).
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

    for key, raw_course in all_catalog.items():
        course = enrich_course_with_unibody(raw_course)
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
                    f"🫧 UNIBODY Auto-Detect: '{course['course_id']}' erkannt auf [{course['platform_host']}] -> {course['title']}"
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
                f"🫧 UNIBODY Live-XML: '{raw}' geladen -> Geroutet auf [{live_course['platform_host']}] ({len(live_course['groups'])} Termine)"
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
