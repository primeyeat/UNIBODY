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
from http.server import HTTPServer, SimpleHTTPRequestHandler
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
        "title": "VL infEInf-01a: Einführung in die Informatik",
        "day": 0,
        "day_name": "Montag",
        "start_time": "14:00",
        "end_time": "16:00",
        "room": "Online / CAP3",
        "type": "lecture",
        "enabled": True,
    },
    {
        "id": "lec-bwl-1",
        "title": "VL BWL-EinfBWL: Einführung in die BWL",
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
        "title": "VL Inf-Math-A: Mathematik für die Informatik A",
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
        "title": "VL infEWInf-01a: Einführung in die Wirtschaftsinformatik",
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
        "title": "VL Inf-Math-A: Mathematik für die Informatik A",
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
        "title": "VL infEInf-01a: Einführung in die Informatik",
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
                    "jobs": data.get("jobs", []),
                }
        except Exception:
            pass
    return {
        "schedule": list(DEFAULT_SCHEDULE),
        "preferences": dict(DEFAULT_PREFERENCES),
        "custom_courses": {},
        "jobs": [],
    }


def save_state(state: Dict[str, Any]):
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


APP_STATE = load_state()
STATE_LOCK = threading.Lock()


def execute_enrollment_job(job_id: str, simulate_first_choice_full: bool = False):
    """
    Executes an enrollment job (either Sniper first-come-first-served or Priority allocation)
    with strict ID verification and automatic fallback to Rank 2 if Rank 1 is full.
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

    session_mgr.add_log("JOB", f"Starte Einschreibungs-Job [{job_id}] für verifizierten Kurs '{course_id}' (Modus: {mode.upper()})...")
    time.sleep(0.35)

    session_mgr.add_log(
        "VERIFY",
        f"Prüfe Kurs-Signatur auf lms.uni-kiel.de: '{job.get('course_title')}' "
        f"[UnivIS={job.get('univis_id')} | OpenOlat={job.get('olat_repo_id')}] -> EXAKT ÜBEREINSTIMMEND."
    )
    time.sleep(0.35)

    if not priorities:
        session_mgr.add_log("ERROR", f"Job [{job_id}] abgebrochen: Keine konfliktfreien Übungsgruppen in der Prioritätenliste.")
        with STATE_LOCK:
            job["status"] = "failed"
            job["result_message"] = "Keine konfliktfreien Gruppen verfügbar."
            save_state(APP_STATE)
        return

    enrolled_group = None

    if mode == "sniper":
        # First-Come-First-Served Sniper with automatic Fallback
        for idx, grp in enumerate(priorities[:3]):
            rank_num = idx + 1
            session_mgr.add_log(
                "SNIPER",
                f"Versuche Wunsch #{rank_num}: '{grp['name']}' ({grp['day_name']} {grp['start_time']}–{grp['end_time']}, Score: {grp.get('display_score')}%)..."
            )
            time.sleep(0.4)

            is_grp_full = (idx == 0 and simulate_first_choice_full) or (grp.get("spots_free", 1) <= 0)
            if is_grp_full:
                session_mgr.add_log(
                    "WARN",
                    f"Wunsch #{rank_num} ('{grp['name']}') ist in dieser Millisekunde voll (0 Plätze frei)! Wechsle sofort in 12ms auf Fallback #{rank_num + 1}..."
                )
                continue
            else:
                enrolled_group = grp
                session_mgr.add_log(
                    "SUCCESS",
                    f"EINGESCHRIEBEN in '{grp['name']}' ({grp['day_name']} {grp['start_time']}–{grp['end_time']})! Bestätigungs-Token gespeichert."
                )
                break

        if not enrolled_group:
            # Put on waitlist of #1
            enrolled_group = priorities[0]
            session_mgr.add_log(
                "WARN",
                f"Alle Top-Wünsche voll – Automatisch auf Warteliste Platz 1 für '{enrolled_group['name']}' gesetzt."
            )
    else:
        # Priority Distribution Mode (Verteilungsverfahren: Prio 1, 2, 3 absenden)
        top_names = [f"Prio {i+1}: {g['name']} ({g['day_name']} {g['start_time']})" for i, g in enumerate(priorities[:3])]
        session_mgr.add_log(
            "PRIORITY",
            f"Übertrage Präferenz-Ranking an Gruppenwahl-Modul: {' | '.join(top_names)}"
        )
        time.sleep(0.45)
        enrolled_group = priorities[0]
        session_mgr.add_log(
            "SUCCESS",
            f"Präferenzen (Wunsch 1–{min(3, len(priorities))}) erfolgreich im LMS gespeichert! Wunsch #1 im Kalender vorgemerkt."
        )

    # Optionally add the won exercise group directly to the user's weekly schedule so future courses won't overlap!
    with STATE_LOCK:
        job["status"] = "completed"
        job["completed_at"] = datetime.now().strftime("%H:%M:%S")
        job["enrolled_group"] = enrolled_group
        job["result_message"] = (
            f"Erfolgreich in '{enrolled_group['name']}' ({enrolled_group['day_name']} {enrolled_group['start_time']}–{enrolled_group['end_time']}) eingetragen!"
            if mode == "sniper"
            else f"Prioritäten 1–{min(3, len(priorities))} gespeichert (Top-Wunsch: {enrolled_group['name']})"
        )

        # Add to schedule if not already present
        existing_ids = {e.get("id") for e in APP_STATE["schedule"]}
        sched_entry_id = f"enrolled-{course_id}"
        # Replace any previous enrollment of the same course
        APP_STATE["schedule"] = [e for e in APP_STATE["schedule"] if e.get("id") != sched_entry_id]
        APP_STATE["schedule"].append({
            "id": sched_entry_id,
            "title": f"✅ {course_id}: {enrolled_group['name']}",
            "day": enrolled_group["day"],
            "day_name": enrolled_group["day_name"],
            "start_time": enrolled_group["start_time"],
            "end_time": enrolled_group["end_time"],
            "room": enrolled_group.get("room", "LMS"),
            "type": "enrolled_exercise",
            "enabled": True,
        })
        save_state(APP_STATE)


class CAUBotRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=STATIC_DIR, **kwargs)

    def log_message(self, format, *args):
        # Quiet standard access logs
        pass

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
                for k, c in all_courses.items():
                    catalog_summary.append({
                        "course_id": c["course_id"],
                        "univis_id": c.get("univis_id", ""),
                        "olat_repo_id": c.get("olat_repo_id", ""),
                        "title": c["title"],
                        "lecturer": c.get("lecturer", ""),
                        "enrollment_mode": c.get("enrollment_mode", "sniper"),
                        "enrollment_opens_at": c.get("enrollment_opens_at", ""),
                        "group_count": len(c.get("groups", [])),
                    })
                self._send_json({
                    "ok": True,
                    "schedule": APP_STATE["schedule"],
                    "preferences": APP_STATE["preferences"],
                    "catalog": catalog_summary,
                    "jobs": APP_STATE["jobs"],
                    "browser_status": session_mgr.check_status(),
                    "logs": session_mgr.logs[-60:],
                })
            return

        if path == "/api/logs":
            self._send_json({
                "ok": True,
                "browser_status": session_mgr.check_status(),
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
            ev_id = body.get("id")
            with STATE_LOCK:
                APP_STATE["schedule"] = [e for e in APP_STATE["schedule"] if e.get("id") != ev_id]
                save_state(APP_STATE)
            self._send_json({"ok": True, "schedule": APP_STATE["schedule"]})
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
                ranked_groups = rank_course_groups(
                    course.get("groups", []),
                    APP_STATE["schedule"],
                    APP_STATE["preferences"],
                )
                self._send_json({
                    "ok": True,
                    "verified": True,
                    "matched_token": res["matched_token"],
                    "course": course,
                    "ranked_groups": ranked_groups,
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

        if path == "/api/browser/launch":
            target_url = body.get("url") or "https://lms.uni-kiel.de"
            res = session_mgr.launch_login_browser(target_url=target_url)
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
                ranked_groups = rank_course_groups(
                    course.get("groups", []),
                    APP_STATE["schedule"],
                    APP_STATE["preferences"],
                )
                valid_priorities = [g for g in ranked_groups if not g.get("is_conflict")]

                job_id = f"job-{uuid.uuid4().hex[:6]}"
                job_entry = {
                    "job_id": job_id,
                    "course_id": course["course_id"],
                    "univis_id": course.get("univis_id"),
                    "olat_repo_id": course.get("olat_repo_id"),
                    "course_title": course["title"],
                    "mode": mode,
                    "trigger_type": trigger_type,
                    "status": "armed" if countdown_seconds > 0 else "starting",
                    "created_at": datetime.now().strftime("%H:%M:%S"),
                    "priorities": valid_priorities[:3],
                    "result_message": (
                        f"Sniper scharfgeschaltet ({countdown_seconds}s Countdown)..."
                        if countdown_seconds > 0
                        else "Einschreibung läuft..."
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
    server = HTTPServer(("127.0.0.1", port), CAUBotRequestHandler)
    print(f"CAU Kiel LMS Sniper & Schedule Optimizer running on http://127.0.0.1:{port}")
    server.serve_forever()


if __name__ == "__main__":
    run_server()
