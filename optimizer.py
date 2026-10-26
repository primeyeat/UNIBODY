"""
Schedule Optimizer & ICS Parser for CAU Kiel LMS Bot.
Calculates conflict-free tutorial groups and ranks them based on customizable weights:
- Compactness / Minimizing gaps (Freistunden)
- Preferred time window (e.g., 10:00 - 16:00)
- Keeping free days completely free
- Maximum daily workload penalty
"""

import re
import uuid
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional, Tuple, Any


DAYS_MAP = {
    "mo": 0, "montag": 0, "monday": 0, "mon": 0,
    "di": 1, "dienstag": 1, "tuesday": 1, "tue": 1,
    "mi": 2, "mittwoch": 2, "wednesday": 2, "wed": 2,
    "do": 3, "donnerstag": 3, "thursday": 3, "thu": 3,
    "fr": 4, "freitag": 4, "friday": 4, "fri": 4,
    "sa": 5, "samstag": 5, "saturday": 5, "sat": 5,
    "so": 6, "sonntag": 6, "sunday": 6, "sun": 6,
}

DAY_NAMES_DE = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
DAY_SHORT_DE = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]


def time_to_minutes(t_str: str) -> int:
    """Converts 'HH:MM' to minutes since 00:00."""
    parts = t_str.strip().split(":")
    h = int(parts[0])
    m = int(parts[1]) if len(parts) > 1 else 0
    return h * 60 + m


def minutes_to_time(mins: int) -> str:
    """Converts minutes since 00:00 to 'HH:MM'."""
    h = (mins // 60) % 24
    m = mins % 60
    return f"{h:02d}:{m:02d}"


def parse_german_timeslot(text: str) -> Optional[Dict[str, Any]]:
    """
    Extracts day of week, start_time, and end_time from typical CAU / OpenOlat / Moodle group names or descriptions.
    Examples:
      - 'Gruppe 1: Di 10:15 - 11:45 (CAP2)'
      - 'Übungsgruppe A - Mittwoch, 14:00-16:00 Uhr'
      - 'Do. 08:30 bis 10:00'
      - 'Mo 12-14 c.t.'
    """
    if not text:
        return None

    # Pattern 1: Day + HH:MM - HH:MM (or bis)
    pattern_full = re.compile(
        r"\b(Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag|Mo|Di|Mi|Do|Fr|Sa|So)\.?,?\s*"
        r"(\d{1,2})[:\.](\d{2})\s*(?:Uhr)?\s*(?:-|–|—|bis|to)\s*(\d{1,2})[:\.](\d{2})",
        re.IGNORECASE
    )
    match = pattern_full.search(text)
    if match:
        day_raw = match.group(1).lower()
        day_idx = DAYS_MAP.get(day_raw, 0)
        sh, sm = int(match.group(2)), int(match.group(3))
        eh, em = int(match.group(4)), int(match.group(5))
        return {
            "day": day_idx,
            "day_name": DAY_NAMES_DE[day_idx],
            "start_time": f"{sh:02d}:{sm:02d}",
            "end_time": f"{eh:02d}:{em:02d}",
        }

    # Pattern 2: Day + HH - HH (c.t. / s.t.) e.g. "Mo 10-12 c.t." or "Di 14 - 16 Uhr"
    pattern_short = re.compile(
        r"\b(Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag|Mo|Di|Mi|Do|Fr|Sa|So)\.?,?\s*"
        r"(\d{1,2})\s*(?:-|–|—|bis)\s*(\d{1,2})\s*(?:Uhr)?\s*(c\.?\s*t\.?|s\.?\s*t\.?)?",
        re.IGNORECASE
    )
    match_short = pattern_short.search(text)
    if match_short:
        day_raw = match_short.group(1).lower()
        day_idx = DAYS_MAP.get(day_raw, 0)
        sh = int(match_short.group(2))
        eh = int(match_short.group(3))
        ct_flag = (match_short.group(4) or "").lower()
        # At CAU Kiel, standard "10-12" without s.t. is typically c.t. (10:15 - 11:45)
        is_st = "s" in ct_flag
        sm = 0 if is_st else 15
        em = 0 if is_st else 45
        if not is_st and eh > sh:
            eh = eh - 1
        return {
            "day": day_idx,
            "day_name": DAY_NAMES_DE[day_idx],
            "start_time": f"{sh:02d}:{sm:02d}",
            "end_time": f"{eh:02d}:{em:02d}",
        }

    return None


def parse_ics_content(ics_text: str) -> List[Dict[str, Any]]:
    """
    Parses a UnivIS or standard .ics calendar file and deduplicates recurring weekly events
    into clean weekly schedule blocks so the user can review/toggle/delete UnivIS junk entries!
    """
    events = []
    # Unfold RFC 5545 multi-line fields
    unfolded = re.sub(r"\r?\n[ \t]", "", ics_text)
    raw_blocks = unfolded.split("BEGIN:VEVENT")

    seen_signatures = set()

    for block in raw_blocks[1:]:
        end_idx = block.find("END:VEVENT")
        if end_idx != -1:
            block = block[:end_idx]

        summary_match = re.search(r"^SUMMARY(?:;[^:]*)?:(.*)$", block, re.MULTILINE)
        location_match = re.search(r"^LOCATION(?:;[^:]*)?:(.*)$", block, re.MULTILINE)
        dtstart_match = re.search(r"^DTSTART(?:;[^:]*)?:(\d{8}T\d{6}Z?)", block, re.MULTILINE)
        dtend_match = re.search(r"^DTEND(?:;[^:]*)?:(\d{8}T\d{6}Z?)", block, re.MULTILINE)
        rrule_match = re.search(r"^RRULE(?:;[^:]*)?:(.*)$", block, re.MULTILINE)

        if not dtstart_match or not dtend_match:
            continue

        title = summary_match.group(1).strip() if summary_match else "Unbenannter Termin"
        title = title.replace("\\,", ",").replace("\\;", ";")
        location = location_match.group(1).strip() if location_match else ""
        location = location.replace("\\,", ",").replace("\\;", ";")

        dt_start_str = dtstart_match.group(1)
        dt_end_str = dtend_match.group(1)

        # Parse YYYYMMDDTHHMMSS
        try:
            year = int(dt_start_str[0:4])
            month = int(dt_start_str[4:6])
            day_num = int(dt_start_str[6:8])
            sh = int(dt_start_str[9:11])
            sm = int(dt_start_str[11:13])

            eh = int(dt_end_str[9:11])
            em = int(dt_end_str[11:13])

            # If UTC ('Z'), adjust +1 or +2 hours for Europe/Berlin roughly if needed,
            # though UnivIS exports local Europe/Berlin timestamps without Z.
            if dt_start_str.endswith("Z"):
                sh = (sh + 2) % 24
                eh = (eh + 2) % 24

            import datetime
            dt_obj = datetime.date(year, month, day_num)
            weekday = dt_obj.weekday()  # 0 = Monday .. 6 = Sunday
            if weekday > 5:
                continue  # Ignore Sundays

            start_time = f"{sh:02d}:{sm:02d}"
            end_time = f"{eh:02d}:{em:02d}"

            # Detect potential UnivIS clutter (e.g., exam dates, single appointments, or parallel exercise placeholders)
            is_recurring = bool(rrule_match and "WEEKLY" in rrule_match.group(1).upper())
            is_suspicious_exercise = bool(re.search(r"\b(Übung|ÜG|Tutorium|Praktikum|Klausur|Prüfung)\b", title, re.IGNORECASE))

            sig = (weekday, start_time, end_time, title.lower())
            if sig in seen_signatures:
                continue
            seen_signatures.add(sig)

            events.append({
                "id": f"ics-{uuid.uuid4().hex[:8]}",
                "title": title,
                "day": weekday,
                "day_name": DAY_NAMES_DE[weekday],
                "start_time": start_time,
                "end_time": end_time,
                "room": location,
                "type": "exercise" if is_suspicious_exercise else "lecture",
                "is_recurring": is_recurring,
                "univis_warning": (
                    "Wahrscheinliche Parallel-Übung / Platzhalter aus UnivIS"
                    if is_suspicious_exercise
                    else ("Einzeltermin (nicht wöchentlich)" if not is_recurring else None)
                ),
                "enabled": not is_suspicious_exercise  # Auto-uncheck suspicious UnivIS parallel exercises during import preview!
            })
        except Exception:
            continue

    # Sort by day, then start_time
    events.sort(key=lambda e: (e["day"], e["start_time"]))
    return events


def evaluate_group_candidate(
    candidate: Dict[str, Any],
    fixed_schedule: List[Dict[str, Any]],
    preferences: Dict[str, Any],
    course_id: Optional[str] = None,
    enrolled_group_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Scores a candidate tutorial group against the student's active schedule and preferences.
    Returns detailed breakdown:
      - score (0..100, or -1000 if hard conflict / full)
      - status ('optimal' | 'good' | 'suboptimal' | 'conflict' | 'full')
      - conflict_with (list of overlapping events)
      - reasons (list of human-readable pros & cons in German)
      - metrics (gap_minutes, day_load_minutes, keeps_free_days, etc.)
    """
    day = candidate.get("day", 0)
    start_str = candidate.get("start_time", "10:15")
    end_str = candidate.get("end_time", "11:45")
    c_start = time_to_minutes(start_str)
    c_end = time_to_minutes(end_str)
    duration = max(0, c_end - c_start)

    spots_free = candidate.get("spots_free")
    spots_total = candidate.get("spots_total")
    is_full = (spots_free is not None and spots_free <= 0 and not candidate.get("waitlist_available", False))

    # Preferences with defaults
    w_gaps = float(preferences.get("weight_compact", 80)) / 100.0        # 0.0 - 1.0
    w_free_days = float(preferences.get("weight_free_days", 75)) / 100.0  # 0.0 - 1.0
    w_time_pref = float(preferences.get("weight_time_window", 65)) / 100.0  # 0.0 - 1.0
    w_campus = float(preferences.get("weight_campus_buffer", 50)) / 100.0  # 0.0 - 1.0

    pref_earliest = time_to_minutes(preferences.get("earliest_time", "09:30"))
    pref_latest = time_to_minutes(preferences.get("latest_time", "16:30"))
    preferred_free_days = set(preferences.get("preferred_free_days", [4]))  # Default Friday (4)
    min_break_mins = int(preferences.get("min_break_minutes", 15))  # c.t. buffer

    # Active schedule events (exclude an already-enrolled exercise of the SAME course so it doesn't conflict with itself!)
    cid_lower = (course_id or "").lower()
    active_events = [
        e for e in fixed_schedule
        if e.get("enabled", True)
        and not (
            cid_lower
            and (
                str(e.get("id", "")).lower() == f"enrolled-{cid_lower}"
                or (e.get("type") == "enrolled_exercise" and str(e.get("course_id", "")).lower() == cid_lower)
            )
        )
    ]
    same_day_events = [e for e in active_events if int(e.get("day", -1)) == day]

    conflicts = []
    tight_transitions = []

    for ev in same_day_events:
        e_start = time_to_minutes(ev["start_time"])
        e_end = time_to_minutes(ev["end_time"])

        # Hard overlap check (allowing exact boundary touch e.g. 10:00 and 10:00)
        if c_start < e_end and c_end > e_start:
            conflicts.append({
                "title": ev.get("title", "Termin"),
                "start_time": ev["start_time"],
                "end_time": ev["end_time"],
                "room": ev.get("room", "")
            })
        else:
            # Check transition buffer if rooms are far apart
            gap_before = c_start - e_end if c_start >= e_end else None
            gap_after = e_start - c_end if e_start >= c_end else None
            if (gap_before is not None and gap_before < min_break_mins) or (
                gap_after is not None and gap_after < min_break_mins
            ):
                tight_transitions.append(ev.get("title", "Termin"))

    reasons = []
    score = 100.0

    if conflicts:
        conflict_names = ", ".join(f"{c['title']} ({c['start_time']}–{c['end_time']})" for c in conflicts)
        reasons.append(f"❌ Zeitkonflikt mit: {conflict_names}")
        return {
            **candidate,
            "score": -500.0,
            "display_score": 0,
            "status": "conflict",
            "is_conflict": True,
            "is_full": is_full,
            "conflicts": conflicts,
            "reasons": reasons,
            "gap_minutes": None,
        }

    # 1. Check Free Day impact
    was_free_day = len(same_day_events) == 0
    if was_free_day:
        if day in preferred_free_days:
            penalty = 35.0 * w_free_days
            score -= penalty
            reasons.append(f"⚠️ Belegt deinen Wunsch-Freitag/Freitag ({DAY_NAMES_DE[day]}) (-{round(penalty)} Pkt.)")
        else:
            penalty = 22.0 * w_free_days
            score -= penalty
            reasons.append(f"⚠️ Macht einen bisher komplett freien Tag ({DAY_NAMES_DE[day]}) zunichte (-{round(penalty)} Pkt.)")
    else:
        # Calculate gap (Freistunden) to nearest existing block on the same day
        gaps = []
        for ev in same_day_events:
            e_start = time_to_minutes(ev["start_time"])
            e_end = time_to_minutes(ev["end_time"])
            if c_start >= e_end:
                gaps.append(c_start - e_end)
            elif e_start >= c_end:
                gaps.append(e_start - c_end)

        nearest_gap = min(gaps) if gaps else 0

        # Also compute total span of day vs active minutes on that day
        all_day_intervals = [(time_to_minutes(e["start_time"]), time_to_minutes(e["end_time"])) for e in same_day_events]
        all_day_intervals.append((c_start, c_end))
        all_day_intervals.sort(key=lambda x: x[0])

        total_idle_gap = 0
        for i in range(len(all_day_intervals) - 1):
            gap_between = max(0, all_day_intervals[i + 1][0] - all_day_intervals[i][1])
            # Subtract normal 15-30 min c.t. walking break
            if gap_between > 30:
                total_idle_gap += (gap_between - 15)

        if nearest_gap <= 30:
            bonus = 8.0 * w_gaps
            score += bonus
            reasons.append(f"✅ Nahtloser Anschluss ({nearest_gap} Min. Pause) am {DAY_NAMES_DE[day]}")
        elif nearest_gap <= 60:
            penalty = 8.0 * w_gaps
            score -= penalty
            reasons.append(f"ℹ️ Kurze Pause ({nearest_gap} Min.) zum nächsten Kurs")
        else:
            # Penalize large gaps (e.g., 2h = 120m -> ~24 pts penalty)
            penalty = min(45.0, (nearest_gap - 30) * 0.25 * w_gaps)
            score -= penalty
            hours_str = f"{nearest_gap // 60}h {nearest_gap % 60}m" if nearest_gap >= 60 else f"{nearest_gap} Min."
            reasons.append(f"⚠️ Erzeugt {hours_str} Freistunde am {DAY_NAMES_DE[day]} (-{round(penalty)} Pkt.)")

    # 2. Preferred Time Window check
    if c_start < pref_earliest:
        diff_early = pref_earliest - c_start
        penalty = min(35.0, (diff_early / 15.0) * 6.0 * w_time_pref)
        score -= penalty
        reasons.append(f"🌅 Vor deiner Wunschzeit ({start_str} < {minutes_to_time(pref_earliest)}) (-{round(penalty)} Pkt.)")
    elif c_end > pref_latest:
        diff_late = c_end - pref_latest
        penalty = min(35.0, (diff_late / 15.0) * 6.0 * w_time_pref)
        score -= penalty
        reasons.append(f"🌙 Endet nach deiner Wunschzeit ({end_str} > {minutes_to_time(pref_latest)}) (-{round(penalty)} Pkt.)")
    else:
        reasons.append(f"✅ Liegt perfekt im Wunsch-Zeitfenster ({start_str}–{end_str})")

    # 3. Tight campus transition check
    if tight_transitions and w_campus > 0:
        penalty = 10.0 * w_campus
        score -= penalty
        reasons.append(f"🏃 Knapper Raumwechsel (< {min_break_mins} Min.) zu {', '.join(tight_transitions)}")

    # 4. Daily total load check (avoid 8+ hour marathon days)
    existing_day_minutes = sum(
        max(0, time_to_minutes(e["end_time"]) - time_to_minutes(e["start_time"]))
        for e in same_day_events
    )
    new_day_minutes = existing_day_minutes + duration
    if new_day_minutes > 360:  # > 6 hours of pure lectures on one day
        overload_penalty = min(20.0, ((new_day_minutes - 360) / 60.0) * 8.0)
        score -= overload_penalty
        reasons.append(f"📚 Langer Uni-Tag ({round(new_day_minutes / 60, 1)} Std. Gesamtzeit am {DAY_SHORT_DE[day]})")

    # 5. Capacity / Availability check
    if is_full:
        score -= 40.0
        reasons.append("⚠️ Aktuell voll belegt (nur Warteliste / Nachrücken möglich)")
    elif spots_free is not None and spots_total is not None and spots_total > 0:
        taken = max(0, spots_total - spots_free)
        if taken == 0:
            reasons.append(f"🟢 Alle {spots_total} Plätze verfügbar (0/{spots_total} belegt)")
        elif spots_free <= 3:
            reasons.append(f"⚠️ Nur noch {spots_free} Restplätze ({taken}/{spots_total} belegt) – Schnell sein!")
        else:
            reasons.append(f"🟢 {spots_free} freie Plätze ({taken}/{spots_total} belegt)")

    display_score = max(1, min(100, round(score)))
    if is_full:
        status = "full"
    elif display_score >= 82:
        status = "optimal"
    elif display_score >= 60:
        status = "good"
    else:
        status = "suboptimal"

    return {
        **candidate,
        "score": round(score, 2),
        "display_score": display_score,
        "status": status,
        "is_conflict": False,
        "is_full": is_full,
        "conflicts": [],
        "reasons": reasons,
    }


def rank_course_groups(
    groups: List[Dict[str, Any]],
    fixed_schedule: List[Dict[str, Any]],
    preferences: Dict[str, Any],
    pinned_group_id: Optional[str] = None,
    course_id: Optional[str] = None,
    enrolled_group_id: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """
    Evaluates all tutorial groups of a course and returns them sorted from best (Rank 1) to worst.
    If pinned_group_id is provided (when the user clicks a group in the timetable or list),
    that group is promoted to Rank #1 (Wunsch #1).
    If enrolled_group_id is provided (when the user already booked a group manually or via sync),
    that group is marked with `is_enrolled = True` so the user sees both their current group and if a better one exists!
    """
    evaluated = [
        evaluate_group_candidate(
            g,
            fixed_schedule,
            preferences,
            course_id=course_id,
            enrolled_group_id=enrolled_group_id,
        )
        for g in groups
    ]

    for item in evaluated:
        is_pinned = bool(pinned_group_id and item.get("group_id") == pinned_group_id)
        is_enrolled = bool(enrolled_group_id and item.get("group_id") == enrolled_group_id)
        item["is_pinned"] = is_pinned
        item["is_enrolled"] = is_enrolled
        if is_enrolled:
            item["reasons"] = ["✅ BEREITS GEBUCHT: Du bist aktuell in dieser Übungsgruppe eingeschrieben!"] + item.get("reasons", [])
        if is_pinned:
            item["reasons"] = ["📌 Manuell als Wunsch #1 priorisiert (Kalender-/Listen-Auswahl)"] + item.get("reasons", [])

    # Sort: pinned group first (if not a hard conflict), then non-conflicts, then non-full, then highest score
    evaluated.sort(
        key=lambda x: (
            0 if (x.get("is_pinned") and not x["is_conflict"]) else 1,
            0 if not x["is_conflict"] else 1,
            0 if not x["is_full"] else 1,
            -x["score"]
        )
    )

    rank_counter = 1
    for item in evaluated:
        if not item["is_conflict"]:
            item["rank"] = rank_counter
            rank_counter += 1
        else:
            item["rank"] = None

    return evaluated

