#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UNIBODY Reminders (reminders.py)
--------------------------------
Local reminders for assignment deadlines and enrollment openings.
Runs as a background thread of the local server and shows native macOS notifications.
Standard library only, nothing leaves the machine.
"""

import json
import os
import subprocess
import sys
import threading
from datetime import datetime, timedelta
from typing import Any, Callable, Dict, List, Optional, Set

# (lead time before the deadline, label) – most urgent first
DEADLINE_LEADS = [(timedelta(hours=2), "in 2 Stunden"), (timedelta(hours=24), "in 24 Stunden")]
ENROLLMENT_LEAD = timedelta(minutes=15)
ENROLLMENT_GRACE = timedelta(minutes=10)
MAX_SENT_KEYS = 500


def _parse_iso(value: Any) -> Optional[datetime]:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        parsed = datetime.fromisoformat(value.strip())
    except ValueError:
        return None
    return parsed.replace(tzinfo=None)


def collect_due_reminders(
    materials: Dict[str, Any],
    courses: List[Dict[str, Any]],
    enrolled_groups: Dict[str, str],
    now: datetime,
    sent: Set[str],
) -> List[Dict[str, str]]:
    """
    Returns the reminders that should fire right now: [{'key', 'title', 'message'}].
    `sent` holds the keys of reminders that were already shown; superseded keys are added to it
    (e.g. the 24-hour reminder once the 2-hour one fires).
    """
    due: List[Dict[str, str]] = []

    # 1. Assignment deadlines (open assignments only)
    for course_key, course in materials.items():
        if not isinstance(course, dict):
            continue
        course_name = course.get("course_id") or course_key
        for assignment in course.get("assignments", []):
            if assignment.get("status") == "submitted":
                continue
            deadline = _parse_iso(assignment.get("due_date"))
            if deadline is None or deadline <= now:
                continue
            fired = False
            for lead, label in DEADLINE_LEADS:
                key = f"due:{course_key}:{assignment.get('id')}:{assignment.get('due_date')}:{int(lead.total_seconds())}"
                if now < deadline - lead:
                    continue
                if fired:
                    sent.add(key)  # a more urgent reminder already covers this one
                    continue
                if key not in sent:
                    due.append({
                        "key": key,
                        "title": f"Abgabe {label}: {course_name}",
                        "message": f"{assignment.get('title', 'Aufgabe')} – fällig {deadline.strftime('%d.%m. um %H:%M Uhr')}",
                    })
                fired = True

    # 2. Enrollment openings (courses without a booked group)
    enrolled = {k.lower() for k, v in enrolled_groups.items() if v}
    for course in courses:
        course_id = str(course.get("course_id", ""))
        opens_at = _parse_iso(course.get("enrollment_opens_at"))
        if opens_at is None or not course.get("groups") or course_id.lower() in enrolled:
            continue
        open_key = f"enroll:{course_id}:{course.get('enrollment_opens_at')}:open"
        soon_key = f"enroll:{course_id}:{course.get('enrollment_opens_at')}:soon"
        if opens_at <= now < opens_at + ENROLLMENT_GRACE:
            sent.add(soon_key)
            if open_key not in sent:
                due.append({
                    "key": open_key,
                    "title": f"Einschreibung offen: {course_id}",
                    "message": f"Die Übungsgruppen für {course.get('title', course_id)} sind jetzt freigeschaltet.",
                })
        elif opens_at - ENROLLMENT_LEAD <= now < opens_at and soon_key not in sent:
            due.append({
                "key": soon_key,
                "title": f"Einschreibung in Kürze: {course_id}",
                "message": f"{course.get('title', course_id)} öffnet um {opens_at.strftime('%H:%M Uhr')}.",
            })

    return due


def show_notification(title: str, message: str) -> bool:
    """Shows a native macOS notification. Text is passed as arguments, never spliced into the script."""
    if sys.platform != "darwin":
        return False
    try:
        result = subprocess.run(
            [
                "osascript",
                "-e", "on run argv",
                "-e", 'display notification (item 2 of argv) with title "UNIBODY" subtitle (item 1 of argv) sound name "Glass"',
                "-e", "end run",
                title[:120],
                message[:240],
            ],
            capture_output=True,
            timeout=5,
        )
        return result.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


class ReminderWorker:
    """Checks once a minute for reminders that are due and shows each one exactly once."""

    def __init__(
        self,
        sent_file: str,
        snapshot: Callable[[], Dict[str, Any]],
        log: Callable[[str, str], None],
        interval_seconds: float = 60.0,
    ):
        self.sent_file = sent_file
        self.snapshot = snapshot
        self.log = log
        self.interval_seconds = interval_seconds
        self._stop = threading.Event()
        self._sent: List[str] = self._load_sent()

    def _load_sent(self) -> List[str]:
        try:
            with open(self.sent_file, "r", encoding="utf-8") as f:
                data = json.load(f)
            return [str(k) for k in data] if isinstance(data, list) else []
        except (OSError, ValueError):
            return []

    def _save_sent(self) -> None:
        self._sent = self._sent[-MAX_SENT_KEYS:]
        try:
            os.makedirs(os.path.dirname(self.sent_file), exist_ok=True)
            with open(self.sent_file, "w", encoding="utf-8") as f:
                json.dump(self._sent, f)
        except OSError:
            pass

    def check_once(self, now: Optional[datetime] = None) -> List[Dict[str, str]]:
        """Runs one check and returns the reminders that were fired."""
        state = self.snapshot()
        if not state.get("enabled", True):
            return []
        sent_set = set(self._sent)
        before = set(sent_set)
        due = collect_due_reminders(
            state.get("materials", {}),
            state.get("courses", []),
            state.get("enrolled_groups", {}),
            now or datetime.now(),
            sent_set,
        )
        for reminder in due:
            shown = show_notification(reminder["title"], reminder["message"])
            self.log("INFO" if shown else "WARN", f"🔔 {reminder['title']} · {reminder['message']}")
            sent_set.add(reminder["key"])
        new_keys = [k for k in sent_set if k not in before]
        if new_keys:
            self._sent.extend(new_keys)
            self._save_sent()
        return due

    def _loop(self) -> None:
        while not self._stop.wait(self.interval_seconds):
            try:
                self.check_once()
            except Exception as exc:  # the reminder thread must never die
                self.log("WARN", f"Erinnerungs-Prüfung fehlgeschlagen: {exc}")

    def start(self) -> None:
        threading.Thread(target=self._loop, daemon=True, name="unibody-reminders").start()

    def stop(self) -> None:
        self._stop.set()
