"""
CAU Kiel LMS Course Sniper & Schedule Optimizer Server.
Zero-dependency Python HTTP + JSON API server with persistent state.
"""

import os
import json
import uuid
import time
import threading
from datetime import datetime
from typing import Dict, List, Any, Optional
from http.server import HTTPServer, ThreadingHTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

from optimizer import (
    parse_ics_content,
    parse_german_timeslot,
    rank_course_groups,
    DAY_NAMES_DE,
)
from lms_bot import (
    BUILTIN_CAU_COURSES,
    CAUBrowserSessionManager,
    lookup_course_by_identifier,
    parse_groups_from_raw_text,
    enrich_course_with_unibody,
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
STATIC_DIR = os.path.join(BASE_DIR, "static")
CHROME_PROFILE_DIR = os.path.join(DATA_DIR, "chrome_cau_profile")
STATE_FILE = os.path.join(DATA_DIR, "state.json")

os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(STATIC_DIR, exist_ok=True)

session_mgr = CAUBrowserSessionManager(profile_dir=CHROME_PROFILE_DIR)


DEFAULT_SCHEDULE = [
    {
        "id": "lec-einf-1",
        "course_id": "infEInf-02a",
        "univis_id": "080058",
        "title": "VL infEInf-02a/01a [#080058]: Einführung in die Informatik",
        "day": 0,
        "day_name": "Montag",
        "start_time": "14:00",
        "end_time": "16:00",
        "room": "Online-Veranstaltung",
        "type": "lecture",
        "enabled": True,
    },
    {
        "id": "lec-bwl-1",
        "course_id": "BWL-EinfBWL",
        "univis_id": "030225",
        "title": "VL BWL-EinfBWL [#030225]: Einführung in die BWL",
        "day": 1,
        "day_name": "Dienstag",
        "start_time": "12:15",
        "end_time": "13:45",
        "room": "CAP3 - Hörsaal 2",
        "type": "lecture",
        "enabled": True,
    },
    {
        "id": "lec-matha-1",
        "course_id": "Inf-Math-A",
        "univis_id": "060107",
        "title": "VL Inf-Math-A [#060107]: Mathematik für die Informatik A",
        "day": 2,
        "day_name": "Mittwoch",
        "start_time": "08:15",
        "end_time": "09:45",
        "room": "CAP3 - Hörsaal 2",
        "type": "lecture",
        "enabled": True,
    },
    {
        "id": "lec-ewinf-1",
        "course_id": "infEWInf-01a",
        "univis_id": "080038",
        "title": "VL infEWInf-01a [#080038]: Einführung in die Wirtschaftsinformatik",
        "day": 3,
        "day_name": "Donnerstag",
        "start_time": "10:15",
        "end_time": "11:45",
        "room": "LMS6 - R.11 / CAP2",
        "type": "lecture",
        "enabled": True,
    },
    {
        "id": "lec-matha-2",
        "course_id": "Inf-Math-A",
        "univis_id": "060107",
        "title": "VL Inf-Math-A [#060107]: Mathematik für die Informatik A",
        "day": 4,
        "day_name": "Freitag",
        "start_time": "10:15",
        "end_time": "11:45",
        "room": "OS75 - Hörsaal 1",
        "type": "lecture",
        "enabled": True,
    },
    {
        "id": "lec-einf-2",
        "course_id": "infEInf-02a",
        "univis_id": "080058",
        "title": "VL infEInf-02a/01a [#080058]: Einführung in die Informatik",
        "day": 4,
        "day_name": "Freitag",
        "start_time": "12:00",
        "end_time": "14:00",
        "room": "OHP5 - Chemie II",
        "type": "lecture",
        "enabled": True,
    },
]

DEFAULT_PREFERENCES = {
    "weight_compact": 85,          # 0..100: Minimale Freistunden / kompakte Tage
    "weight_free_days": 80,        # 0..100: Freie Tage schützen
    "weight_time_window": 70,      # 0..100: Wunsch-Uhrzeiten einhalten
    "weight_campus_buffer": 50,    # 0..100: Raumwechsel-Puffer beachten
    "earliest_time": "09:30",      # Nicht vor 09:30 wenn vermeidbar
    "latest_time": "16:30",        # Nicht nach 16:30 wenn vermeidbar
    "preferred_free_days": [0],    # Montag Vormittag / freie Randtage bevorzugen
    "min_break_minutes": 15,       # 15 Min c.t. Pause
}

SAMPLE_UNIVIS_ICS = """BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//CAU Kiel//UnivIS Export Wirtschaftsinformatik B.Sc. WiSe 26/27//DE
BEGIN:VEVENT
SUMMARY:VL infEInf-01a: Einführung in die Informatik
DTSTART:20261019T140000
DTEND:20261019T160000
RRULE:FREQ=WEEKLY;BYDAY=MO
LOCATION:Online / CAP3
END:VEVENT
BEGIN:VEVENT
SUMMARY:Übung zu infEWInf-01a (Parallelgruppe Dummy aus UnivIS)
DTSTART:20261019T081500
DTEND:20261019T094500
RRULE:FREQ=WEEKLY;BYDAY=MO
LOCATION:LMS8 - R.EG.015
END:VEVENT
BEGIN:VEVENT
SUMMARY:VL BWL-EinfBWL: Einführung in die Betriebswirtschaftslehre
DTSTART:20261020T121500
DTEND:20261020T134500
RRULE:FREQ=WEEKLY;BYDAY=TU
LOCATION:CAP3 - Hörsaal 2
END:VEVENT
BEGIN:VEVENT
SUMMARY:Übung zu infEInf-01a (Alle Parallelgruppen Platzhalter UnivIS)
DTSTART:20261020T161500
DTEND:20261020T194500
RRULE:FREQ=WEEKLY;BYDAY=TU
LOCATION:WSP3
END:VEVENT
BEGIN:VEVENT
SUMMARY:VL Inf-Math-A: Mathematik für die Informatik A
DTSTART:20261021T081500
DTEND:20261021T094500
RRULE:FREQ=WEEKLY;BYDAY=WE
LOCATION:CAP3 - Hörsaal 2
END:VEVENT
BEGIN:VEVENT
SUMMARY:VL infEWInf-01a: Einführung in die Wirtschaftsinformatik
DTSTART:20261022T101500
DTEND:20261022T114500
RRULE:FREQ=WEEKLY;BYDAY=TH
LOCATION:LMS6 - R.11
END:VEVENT
BEGIN:VEVENT
SUMMARY:VL Inf-Math-A: Mathematik für die Informatik A (Fr)
DTSTART:20261023T101500
DTEND:20261023T114500
RRULE:FREQ=WEEKLY;BYDAY=FR
LOCATION:OS75 - Hörsaal 1
END:VEVENT
BEGIN:VEVENT
SUMMARY:VL infEInf-01a: Einführung in die Informatik (Fr)
DTSTART:20261023T120000
DTEND:20261023T140000
RRULE:FREQ=WEEKLY;BYDAY=FR
LOCATION:OHP5 - Chemie II
END:VEVENT
END:VCALENDAR"""


def load_state() -> Dict[str, Any]:
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return {
                    "schedule": data.get("schedule", DEFAULT_SCHEDULE),
                    "preferences": {**DEFAULT_PREFERENCES, **data.get("preferences", {})},
                    "custom_courses": data.get("custom_courses", {}),
                    "pinned_groups": data.get("pinned_groups", {}),
                    "enrolled_groups": data.get("enrolled_groups", {}),
                    "jobs": data.get("jobs", []),
                }
        except Exception:
            pass
    return {
        "schedule": list(DEFAULT_SCHEDULE),
        "preferences": dict(DEFAULT_PREFERENCES),
        "custom_courses": {},
        "pinned_groups": {},
        "enrolled_groups": {},
        "jobs": [],
    }


def save_state(state: Dict[str, Any]):
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


APP_STATE = load_state()
STATE_LOCK = threading.Lock()


def _apply_enrolled_group_to_state(course: Dict[str, Any], group_id: Optional[str]) -> Optional[Dict[str, Any]]:
    """
    Marks `group_id` as the user's already-booked exercise group for `course` (or clears it if None),
    and synchronizes the `enrolled-<course_id>` block in `APP_STATE["schedule"]` so all other courses
    automatically avoid overlapping with this booked exercise!
    """
    cid = course["course_id"]
    ckey = cid.lower()
    sched_entry_id = f"enrolled-{ckey}"
    if "enrolled_groups" not in APP_STATE:
        APP_STATE["enrolled_groups"] = {}

    # Remove any previous enrolled block for this course (case-insensitive)
    APP_STATE["schedule"] = [
        e for e in APP_STATE["schedule"]
        if str(e.get("id", "")).lower() != sched_entry_id
        and not (e.get("type") == "enrolled_exercise" and str(e.get("course_id", "")).lower() == ckey)
    ]

    if not group_id:
        APP_STATE["enrolled_groups"].pop(ckey, None)
        return None

    grp = next((g for g in course.get("groups", []) if g.get("group_id") == group_id), None)
    if not grp:
        return None

    APP_STATE["enrolled_groups"][ckey] = group_id
    APP_STATE["schedule"].append({
        "id": f"enrolled-{cid}",
        "course_id": cid,
        "group_id": group_id,
        "title": f"✅ {cid}: {grp['name']}",
        "day": grp["day"],
        "day_name": grp["day_name"],
        "start_time": grp["start_time"],
        "end_time": grp["end_time"],
        "room": grp.get("room", "LMS"),
        "type": "enrolled_exercise",
        "enabled": True,
    })
    return grp


def execute_enrollment_job(job_id: str, simulate_first_choice_full: bool = False):
    """
    Executes a real enrollment job (either Sniper first-come-first-served or Priority allocation)
    via Chrome DevTools Protocol automation with live DOM interaction, real-time capacity checks,
    and automatic fallback to Rank 2 if Rank 1 is full.
    """
    with STATE_LOCK:
        job = next((j for j in APP_STATE["jobs"] if j["job_id"] == job_id), None)
        if not job:
            return
        job["status"] = "running"
        save_state(APP_STATE)

    course_id = job["course_id"]
    mode = job.get("mode", "sniper")
    priorities = job.get("priorities", [])  # Ordered list of group dicts
    platform_host = job.get("platform_host") or "lms.uni-kiel.de"
    course_url = job.get("course_url") or f"https://{platform_host}/"

    if not priorities:
        session_mgr.add_log("ERROR", f"Job [{job_id}] abgebrochen: Keine konfliktfreien Übungsgruppen in der Prioritätenliste.")
        with STATE_LOCK:
            job["status"] = "failed"
            job["result_message"] = "Keine konfliktfreien Gruppen verfügbar."
            save_state(APP_STATE)
        return

    # Execute real CDP browser automation
    live_res = session_mgr.execute_live_enrollment_via_cdp(
        job,
        simulate_first_choice_full=simulate_first_choice_full,
    )

    with STATE_LOCK:
        if live_res.get("ok"):
            enrolled_group = live_res.get("enrolled_group") or priorities[0]
            job["status"] = "completed"
            job["completed_at"] = datetime.now().strftime("%H:%M:%S")
            job["enrolled_group"] = enrolled_group
            job["rank_won"] = live_res.get("rank_won", 1)
            job["confirmation_token"] = live_res.get("confirmation_token")
            job["is_waitlist"] = live_res.get("is_waitlist", False)
            job["result_message"] = live_res.get("message") or (
                f"[{platform_host}] Erfolgreich in '{enrolled_group['name']}' eingetragen!"
            )

            # Block won exercise group in the user's weekly schedule so future courses won't overlap!
            if "enrolled_groups" not in APP_STATE:
                APP_STATE["enrolled_groups"] = {}
            APP_STATE["enrolled_groups"][course_id.lower()] = enrolled_group.get("group_id")

            sched_entry_id = f"enrolled-{course_id.lower()}"
            APP_STATE["schedule"] = [
                e for e in APP_STATE["schedule"]
                if str(e.get("id", "")).lower() != sched_entry_id
                and not (e.get("type") == "enrolled_exercise" and str(e.get("course_id", "")).lower() == course_id.lower())
            ]
            APP_STATE["schedule"].append({
                "id": f"enrolled-{course_id}",
                "course_id": course_id,
                "group_id": enrolled_group.get("group_id"),
                "title": f"✅ {course_id}: {enrolled_group['name']}",
                "day": enrolled_group["day"],
                "day_name": enrolled_group["day_name"],
                "start_time": enrolled_group["start_time"],
                "end_time": enrolled_group["end_time"],
                "room": enrolled_group.get("room", "LMS"),
                "type": "enrolled_exercise",
                "enabled": True,
            })

        else:
            is_locked = bool(live_res.get("is_locked", False) or live_res.get("status") == "locked")
            job["status"] = "locked" if is_locked else "failed"
            job["is_locked"] = is_locked
            job["open_date"] = live_res.get("open_date")
            job["completed_at"] = datetime.now().strftime("%H:%M:%S")
            job["result_message"] = live_res.get("message") or (
                "Anmeldung noch nicht freigeschaltet." if is_locked else "Einschreibung fehlgeschlagen."
            )

        save_state(APP_STATE)

    # Automatically close Google Chrome as requested once the enrollment order is fulfilled or locked (outside of lock)
    if live_res.get("ok") or live_res.get("is_locked") or live_res.get("status") == "locked":
        time.sleep(1.0)
        session_mgr.close_browser()
        with STATE_LOCK:
            job["browser_closed"] = True
            save_state(APP_STATE)


class CAUBotRequestHandler(SimpleHTTPRequestHandler):
    timeout = 10

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=STATIC_DIR, **kwargs)

    def log_message(self, format, *args):
        print(f"[HTTP] {format % args}", flush=True)

    def _send_json(self, data: Any, status: int = 200):
        raw = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def _read_json_body(self) -> Dict[str, Any]:
        length = int(self.headers.get("Content-Length", 0))
        if length <= 0:
            return {}
        body = self.rfile.read(length).decode("utf-8")
        return json.loads(body) if body else {}

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/api/state":
            with STATE_LOCK:
                catalog_summary = []
                all_courses = {**BUILTIN_CAU_COURSES, **APP_STATE["custom_courses"]}
                enrolled_map = APP_STATE.get("enrolled_groups", {})
                for k, raw_c in all_courses.items():
                    c = enrich_course_with_unibody(raw_c)
                    ckey = c["course_id"].lower()
                    catalog_summary.append({
                        "course_id": c["course_id"],
                        "univis_id": c.get("univis_id", ""),
                        "olat_repo_id": c.get("olat_repo_id", ""),
                        "title": c["title"],
                        "lecturer": c.get("lecturer", ""),
                        "platform_id": c.get("platform_id", "openolat"),
                        "platform_host": c.get("platform_host", "lms.uni-kiel.de"),
                        "platform_short": c.get("platform_short", "lms.uni-kiel.de"),
                        "platform_badge": c.get("platform_badge", "🏛️ lms.uni-kiel.de"),
                        "url": c.get("url", "https://lms.uni-kiel.de"),
                        "enrollment_mode": c.get("enrollment_mode", "sniper"),
                        "enrollment_opens_at": c.get("enrollment_opens_at", ""),
                        "group_count": len(c.get("groups", [])),
                        "enrolled_group_id": enrolled_map.get(ckey),
                    })
                self._send_json({
                    "ok": True,
                    "schedule": APP_STATE["schedule"],
                    "preferences": APP_STATE["preferences"],
                    "enrolled_groups": enrolled_map,
                    "catalog": catalog_summary,
                    "jobs": APP_STATE["jobs"],
                    "credentials": session_mgr.load_credentials(include_secret=False),
                    "browser_status": session_mgr.check_status(),
                    "logs": session_mgr.logs[-60:],
                })
            return

        if path == "/api/logs":
            self._send_json({
                "ok": True,
                "browser_status": session_mgr.check_status(),
                "credentials": session_mgr.load_credentials(include_secret=False),
                "logs": session_mgr.logs[-80:],
                "jobs": APP_STATE["jobs"],
                "schedule": APP_STATE["schedule"],
            })
            return

        if path == "/api/sample-ics":
            self._send_json({
                "ok": True,
                "ics_text": SAMPLE_UNIVIS_ICS,
                "parsed_events": parse_ics_content(SAMPLE_UNIVIS_ICS),
            })
            return

        return super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        body = self._read_json_body()

        if path == "/api/schedule/update":
            with STATE_LOCK:
                if "schedule" in body:
                    APP_STATE["schedule"] = body["schedule"]
                save_state(APP_STATE)
            session_mgr.add_log("INFO", f"Stundenplan aktualisiert ({len(APP_STATE['schedule'])} Einträge).")
            self._send_json({"ok": True, "schedule": APP_STATE["schedule"]})
            return

        if path == "/api/schedule/add":
            ev = body.get("event", {})
            day_idx = int(ev.get("day", 0))
            new_ev = {
                "id": ev.get("id") or f"manual-{uuid.uuid4().hex[:8]}",
                "title": ev.get("title", "Veranstaltung").strip() or "Veranstaltung",
                "day": day_idx,
                "day_name": DAY_NAMES_DE[day_idx],
                "start_time": ev.get("start_time", "10:15"),
                "end_time": ev.get("end_time", "11:45"),
                "room": ev.get("room", ""),
                "type": ev.get("type", "lecture"),
                "enabled": True,
            }
            with STATE_LOCK:
                APP_STATE["schedule"].append(new_ev)
                save_state(APP_STATE)
            session_mgr.add_log("INFO", f"Termin hinzugefügt: {new_ev['title']} ({new_ev['day_name']} {new_ev['start_time']}–{new_ev['end_time']})")
            self._send_json({"ok": True, "schedule": APP_STATE["schedule"]})
            return

        if path == "/api/schedule/delete":
            ev_id = str(body.get("id") or "")
            with STATE_LOCK:
                for e in APP_STATE["schedule"]:
                    if e.get("id") == ev_id:
                        cid_del = (e.get("course_id") or "").lower()
                        if not cid_del and ev_id.lower().startswith("enrolled-"):
                            cid_del = ev_id[9:].lower()
                        if cid_del and "enrolled_groups" in APP_STATE:
                            APP_STATE["enrolled_groups"].pop(cid_del, None)
                APP_STATE["schedule"] = [e for e in APP_STATE["schedule"] if e.get("id") != ev_id]
                save_state(APP_STATE)
            self._send_json({
                "ok": True,
                "schedule": APP_STATE["schedule"],
                "enrolled_groups": APP_STATE.get("enrolled_groups", {}),
            })
            return

        if path == "/api/schedule/toggle":
            ev_id = body.get("id")
            with STATE_LOCK:
                for e in APP_STATE["schedule"]:
                    if e.get("id") == ev_id:
                        e["enabled"] = not e.get("enabled", True)
                save_state(APP_STATE)
            self._send_json({"ok": True, "schedule": APP_STATE["schedule"]})
            return

        if path == "/api/schedule/parse-ics":
            ics_text = body.get("ics_text", "")
            events = parse_ics_content(ics_text)
            session_mgr.add_log(
                "ICS",
                f"UnivIS .ics Datei analysiert: {len(events)} wöchentliche Serien erkannt "
                f"({sum(1 for e in events if e.get('univis_warning'))} verdächtige Parallel-Übungen automatisch abgewählt)."
            )
            self._send_json({"ok": True, "parsed_events": events})
            return

        if path == "/api/preferences/update":
            with STATE_LOCK:
                APP_STATE["preferences"].update(body.get("preferences", {}))
                save_state(APP_STATE)
            self._send_json({"ok": True, "preferences": APP_STATE["preferences"]})
            return

        if path == "/api/course/lookup":
            query_id = body.get("query_id", "")
            with STATE_LOCK:
                res = lookup_course_by_identifier(query_id, APP_STATE["custom_courses"], session_mgr)
                if not res.get("ok"):
                    self._send_json(res, status=200)
                    return

                course = res["course"]
                ckey = course["course_id"].lower()
                pinned_gid = APP_STATE.get("pinned_groups", {}).get(ckey)
                enrolled_gid = APP_STATE.get("enrolled_groups", {}).get(ckey)
                ranked_groups = rank_course_groups(
                    course.get("groups", []),
                    APP_STATE["schedule"],
                    APP_STATE["preferences"],
                    pinned_group_id=pinned_gid,
                    course_id=course["course_id"],
                    enrolled_group_id=enrolled_gid,
                )
                self._send_json({
                    "ok": True,
                    "verified": True,
                    "matched_token": res["matched_token"],
                    "course": course,
                    "pinned_group_id": pinned_gid,
                    "enrolled_group_id": enrolled_gid,
                    "ranked_groups": ranked_groups,
                })
            return

        if path == "/api/course/pin-group":
            course_id = (body.get("course_id") or "").strip()
            group_id = body.get("group_id")  # None to unpin
            with STATE_LOCK:
                res = lookup_course_by_identifier(course_id, APP_STATE["custom_courses"], session_mgr)
                if not res.get("ok"):
                    self._send_json(res, status=200)
                    return

                course = res["course"]
                ckey = course["course_id"].lower()
                if "pinned_groups" not in APP_STATE:
                    APP_STATE["pinned_groups"] = {}

                # Toggle off if clicking the already-pinned group, otherwise pin it
                if not group_id or APP_STATE["pinned_groups"].get(ckey) == group_id:
                    APP_STATE["pinned_groups"].pop(ckey, None)
                    pinned_gid = None
                    session_mgr.add_log("INFO", f"Manuelle Priorisierung für '{course['course_id']}' aufgehoben (Automatisches Score-Ranking aktiv).")
                else:
                    APP_STATE["pinned_groups"][ckey] = group_id
                    pinned_gid = group_id
                    grp_name = next((g["name"] for g in course.get("groups", []) if g.get("group_id") == group_id), group_id)
                    session_mgr.add_log("SNIPER", f"📌 Übungsgruppe manuell als WUNSCH #1 gesetzt: '{grp_name}'")

                enrolled_gid = APP_STATE.get("enrolled_groups", {}).get(ckey)
                save_state(APP_STATE)
                ranked_groups = rank_course_groups(
                    course.get("groups", []),
                    APP_STATE["schedule"],
                    APP_STATE["preferences"],
                    pinned_group_id=pinned_gid,
                    course_id=course["course_id"],
                    enrolled_group_id=enrolled_gid,
                )
                self._send_json({
                    "ok": True,
                    "course": course,
                    "pinned_group_id": pinned_gid,
                    "enrolled_group_id": enrolled_gid,
                    "ranked_groups": ranked_groups,
                })
            return

        if path == "/api/course/mark-enrolled":
            course_id = (body.get("course_id") or "").strip()
            group_id = body.get("group_id")  # None or same group_id to unmark
            with STATE_LOCK:
                res = lookup_course_by_identifier(course_id, APP_STATE["custom_courses"], session_mgr)
                if not res.get("ok"):
                    self._send_json(res, status=200)
                    return

                course = res["course"]
                ckey = course["course_id"].lower()
                if "enrolled_groups" not in APP_STATE:
                    APP_STATE["enrolled_groups"] = {}

                if not group_id or APP_STATE["enrolled_groups"].get(ckey) == group_id:
                    _apply_enrolled_group_to_state(course, None)
                    enrolled_gid = None
                    session_mgr.add_log("INFO", f"Gebuchte Übung für '{course['course_id']}' aus Stundenplan entfernt.")
                else:
                    grp_obj = _apply_enrolled_group_to_state(course, group_id)
                    enrolled_gid = group_id
                    gname = grp_obj["name"] if grp_obj else group_id
                    session_mgr.add_log(
                        "SUCCESS",
                        f"✅ Manuell gebuchte Übung übernommen für '{course['course_id']}': '{gname}' -> Im Wochenplan blockiert!"
                    )

                pinned_gid = APP_STATE.get("pinned_groups", {}).get(ckey)
                save_state(APP_STATE)
                ranked_groups = rank_course_groups(
                    course.get("groups", []),
                    APP_STATE["schedule"],
                    APP_STATE["preferences"],
                    pinned_group_id=pinned_gid,
                    course_id=course["course_id"],
                    enrolled_group_id=enrolled_gid,
                )
                self._send_json({
                    "ok": True,
                    "course": course,
                    "pinned_group_id": pinned_gid,
                    "enrolled_group_id": enrolled_gid,
                    "enrolled_groups": APP_STATE["enrolled_groups"],
                    "schedule": APP_STATE["schedule"],
                    "ranked_groups": ranked_groups,
                })
            return

        if path == "/api/course/sync-enrolled":
            with STATE_LOCK:
                all_courses = {**BUILTIN_CAU_COURSES, **APP_STATE["custom_courses"]}
                scan_res = session_mgr.scan_enrolled_groups_via_cdp(all_courses)
                for d in scan_res.get("detected", []):
                    c_res = lookup_course_by_identifier(d["course_id"], APP_STATE["custom_courses"], None)
                    if c_res.get("ok"):
                        _apply_enrolled_group_to_state(c_res["course"], d["group_id"])
                save_state(APP_STATE)
                self._send_json({
                    **scan_res,
                    "enrolled_groups": APP_STATE.get("enrolled_groups", {}),
                    "schedule": APP_STATE["schedule"],
                })
            return

        if path == "/api/course/create-custom":
            c = body.get("course", {})
            cid = (c.get("course_id") or "").strip()
            if not cid:
                self._send_json({"ok": False, "error": "Bitte eine eindeutige Kurs-ID / Modulnummer angeben."})
                return

            raw_groups = c.get("groups", [])
            parsed_groups = []
            for idx, g in enumerate(raw_groups):
                # Support either structured group or natural German string like "Gruppe 1: Di 14:15-15:45 (CAP3)"
                if isinstance(g, str):
                    slot = parse_german_timeslot(g)
                    if slot:
                        parsed_groups.append({
                            "group_id": f"{cid}-g{idx+1}",
                            "name": g.strip(),
                            "day": slot["day"],
                            "day_name": slot["day_name"],
                            "start_time": slot["start_time"],
                            "end_time": slot["end_time"],
                            "room": "LMS / CAU",
                            "tutor": "",
                            "spots_free": 10,
                            "spots_total": 25,
                            "waitlist_available": True,
                        })
                elif isinstance(g, dict):
                    day_idx = int(g.get("day", 0))
                    parsed_groups.append({
                        "group_id": g.get("group_id") or f"{cid}-g{idx+1}",
                        "name": g.get("name") or f"Übungsgruppe {idx+1}",
                        "day": day_idx,
                        "day_name": DAY_NAMES_DE[day_idx],
                        "start_time": g.get("start_time", "10:15"),
                        "end_time": g.get("end_time", "11:45"),
                        "room": g.get("room", "CAU Campus"),
                        "tutor": g.get("tutor", ""),
                        "spots_free": int(g.get("spots_free", 10)),
                        "spots_total": int(g.get("spots_total", 25)),
                        "waitlist_available": True,
                    })

            univis_id = (c.get("univis_id") or "").strip()
            olat_repo_id = (c.get("olat_repo_id") or "").strip()
            tokens = [t for t in [cid, univis_id, olat_repo_id] if t]

            new_course = {
                "course_id": cid,
                "univis_id": univis_id or "custom",
                "olat_repo_id": olat_repo_id or "custom",
                "title": c.get("title") or cid,
                "lecturer": c.get("lecturer") or "CAU Dozent/in",
                "semester": "WiSe 2026/27",
                "platform": c.get("platform") or "OpenOlat (lms.uni-kiel.de)",
                "enrollment_mode": c.get("enrollment_mode") or "sniper",
                "enrollment_opens_at": c.get("enrollment_opens_at") or "Sofort / Countdown",
                "url": c.get("url") or f"https://lms.uni-kiel.de/auth/RepositoryEntry/{olat_repo_id or '0'}",
                "verified_tokens": tokens,
                "groups": parsed_groups,
            }

            with STATE_LOCK:
                APP_STATE["custom_courses"][cid.lower()] = new_course
                save_state(APP_STATE)

            session_mgr.add_log("SUCCESS", f"Eigener CAU-Kurs '{new_course['title']}' (ID: {cid}) mit {len(parsed_groups)} Übungsgruppen gespeichert.")
            self._send_json({"ok": True, "course": new_course})
            return

        if path == "/api/course/update-groups":
            course_id = (body.get("course_id") or "").strip()
            raw_text = body.get("raw_text") or ""
            with STATE_LOCK:
                res = lookup_course_by_identifier(course_id, APP_STATE["custom_courses"], session_mgr)
                if not res.get("ok"):
                    self._send_json(res)
                    return

                course = dict(res["course"])
                new_groups = parse_groups_from_raw_text(raw_text, course["course_id"])
                if not new_groups:
                    self._send_json({
                        "ok": False,
                        "error": "Keine gültigen Zeitangaben (z. B. 'Di 16:15 - 17:45' oder 'Mi 14-16') im Text erkannt."
                    })
                    return

                course["groups"] = new_groups
                APP_STATE["custom_courses"][course["course_id"].lower()] = course
                save_state(APP_STATE)

            session_mgr.add_log(
                "SUCCESS",
                f"Übungsgruppen für '{course['course_id']}' live aktualisiert ({len(new_groups)} Gruppen übernommen)."
            )
            self._send_json({"ok": True, "course": course})
            return

        if path == "/api/credentials/save":
            username = (body.get("username") or "").strip()
            password = body.get("password")
            default_platform = body.get("default_platform") or "unibody"
            auto_fill = bool(body.get("auto_fill", True))
            auto_submit = bool(body.get("auto_submit", True))
            use_keychain = bool(body.get("use_keychain", True))
            launch_now = bool(body.get("launch_browser", False))

            if not username:
                self._send_json({"ok": False, "error": "Bitte gib deine CAU-Kennung (z. B. stu123456) ein."})
                return

            creds_meta = session_mgr.save_credentials(
                username=username,
                password=password,
                default_platform=default_platform,
                auto_fill=auto_fill,
                auto_submit=auto_submit,
                use_keychain=use_keychain,
            )

            if launch_now:
                session_mgr.launch_login_browser(target_url=default_platform, force_auto_login=True)
            else:
                # If browser is already open on a login page, immediately inject updated credentials
                session_mgr.inject_autofill_into_tabs(force_submit=auto_submit)

            self._send_json({
                "ok": True,
                "credentials": creds_meta,
                "browser_status": session_mgr.check_status(),
            })
            return

        if path == "/api/credentials/clear":
            creds_meta = session_mgr.clear_credentials()
            self._send_json({
                "ok": True,
                "credentials": creds_meta,
                "browser_status": session_mgr.check_status(),
            })
            return

        if path == "/api/browser/launch":
            target_url = body.get("url")
            force_auto_login = bool(body.get("force_auto_login", True))
            res = session_mgr.launch_login_browser(target_url=target_url, force_auto_login=force_auto_login)
            self._send_json(res)
            return

        if path == "/api/browser/close":
            res = session_mgr.close_browser()
            self._send_json(res)
            return

        if path == "/api/enroll/execute":
            course_id = body.get("course_id", "")
            mode = body.get("mode", "sniper")
            simulate_full = bool(body.get("simulate_first_choice_full", False))
            trigger_type = body.get("trigger_type", "immediate")  # 'immediate' or 'countdown'
            countdown_seconds = int(body.get("countdown_seconds", 0))

            with STATE_LOCK:
                res = lookup_course_by_identifier(course_id, APP_STATE["custom_courses"], session_mgr)
                if not res.get("ok"):
                    self._send_json(res)
                    return

                course = res["course"]
                ckey = course["course_id"].lower()
                pinned_gid = APP_STATE.get("pinned_groups", {}).get(ckey)
                enrolled_gid = APP_STATE.get("enrolled_groups", {}).get(ckey)
                ranked_groups = rank_course_groups(
                    course.get("groups", []),
                    APP_STATE["schedule"],
                    APP_STATE["preferences"],
                    pinned_group_id=pinned_gid,
                    course_id=course["course_id"],
                    enrolled_group_id=enrolled_gid,
                )
                valid_priorities = [g for g in ranked_groups if not g.get("is_conflict")]

                job_id = f"job-{uuid.uuid4().hex[:6]}"
                job_entry = {
                    "job_id": job_id,
                    "course_id": course["course_id"],
                    "univis_id": course.get("univis_id"),
                    "olat_repo_id": course.get("olat_repo_id"),
                    "platform_id": course.get("platform_id", "openolat"),
                    "platform_host": course.get("platform_host", "lms.uni-kiel.de"),
                    "course_url": course.get("url", "https://lms.uni-kiel.de"),
                    "course_title": course["title"],
                    "mode": mode,
                    "trigger_type": trigger_type,
                    "status": "armed" if countdown_seconds > 0 else "starting",
                    "created_at": datetime.now().strftime("%H:%M:%S"),
                    "priorities": valid_priorities[:3],
                    "result_message": (
                        f"Sniper scharfgeschaltet ({countdown_seconds}s Countdown) auf {course.get('platform_host', 'LMS')}..."
                        if countdown_seconds > 0
                        else f"UNIBODY Einschreibung läuft auf {course.get('platform_host', 'LMS')}..."
                    ),
                }
                APP_STATE["jobs"].insert(0, job_entry)
                save_state(APP_STATE)

            def _delayed_runner():
                if countdown_seconds > 0:
                    for rem in range(countdown_seconds, 0, -1):
                        session_mgr.add_log("SNIPER", f"⏱️ Countdown für '{course['course_id']}': T-{rem}s bis Freischaltung...")
                        time.sleep(1.0)
                execute_enrollment_job(job_id, simulate_first_choice_full=simulate_full)

            t = threading.Thread(target=_delayed_runner, daemon=True)
            t.start()

            self._send_json({"ok": True, "job": job_entry})
            return

        self._send_json({"ok": False, "error": f"Unknown endpoint {path}"}, status=404)


def run_server(port: int = 8765):
    try:
        # Bind to 0.0.0.0 to support 127.0.0.1, localhost, and all local interfaces
        server = ThreadingHTTPServer(("0.0.0.0", port), CAUBotRequestHandler)
    except Exception:
        server = ThreadingHTTPServer(("127.0.0.1", port), CAUBotRequestHandler)
    server.daemon_threads = True
    print(f"CAU Kiel LMS Sniper & Schedule Optimizer running on http://127.0.0.1:{port} and http://localhost:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    run_server()
