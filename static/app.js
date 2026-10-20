/**
 * CAU Kiel LMS Kurs-Sniper & Stundenplan-Optimizer
 * Interactive Client Logic (Timetable rendering, Strict ID Verification, UnivIS ICS Cleaner, Sniper execution)
 */

const DAY_NAMES = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"];
const START_HOUR = 8;
const END_HOUR = 19; // 08:00 to 19:00 (11 hours)
const PX_PER_HOUR = 44;

let appState = {
  schedule: [],
  preferences: {
    weight_compact: 85,
    weight_free_days: 80,
    weight_time_window: 70,
    weight_campus_buffer: 50,
    earliest_time: "09:30",
    latest_time: "16:30",
    preferred_free_days: [4],
  },
  catalog: [],
  currentCourse: null,
  rankedGroups: [],
  highlightedGroupId: null,
  icsStagedEvents: [],
};

function timeToMinutes(tStr) {
  const [h, m] = (tStr || "08:00").split(":").map(Number);
  return h * 60 + (m || 0);
}

async function apiGet(path) {
  const res = await fetch(path);
  return res.json();
}

async function apiPost(path, payload) {
  const res = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return res.json();
}

/* INITIALIZATION */
document.addEventListener("DOMContentLoaded", async () => {
  bindUIEvents();
  await fetchInitialState();
  await verifyAndRankCourse(document.getElementById("courseQueryInput").value);
  setInterval(pollTelemetry, 1800);
});

async function fetchInitialState() {
  const data = await apiGet("/api/state");
  if (!data.ok) return;
  appState.schedule = data.schedule || [];
  appState.preferences = data.preferences || appState.preferences;
  appState.catalog = data.catalog || [];

  syncPreferencesUI();
  renderCatalogChips();
  renderTimetable();
  renderLogs(data.logs || []);
  updateBrowserBadge(data.browser_status);
}

function syncPreferencesUI() {
  const p = appState.preferences;
  document.getElementById("sliderCompact").value = p.weight_compact ?? 85;
  document.getElementById("valCompact").textContent = `${p.weight_compact ?? 85}%`;

  document.getElementById("sliderFreeDays").value = p.weight_free_days ?? 80;
  document.getElementById("valFreeDays").textContent = `${p.weight_free_days ?? 80}%`;

  document.getElementById("sliderTimeWindow").value = p.weight_time_window ?? 70;
  document.getElementById("valTimeWindow").textContent = `${p.weight_time_window ?? 70}%`;

  document.getElementById("sliderCampus").value = p.weight_campus_buffer ?? 50;
  document.getElementById("valCampus").textContent = `${p.weight_campus_buffer ?? 50}%`;

  document.getElementById("prefEarliest").value = p.earliest_time || "09:30";
  document.getElementById("prefLatest").value = p.latest_time || "16:30";

  const freeSet = new Set(p.preferred_free_days || [4]);
  document.querySelectorAll("#freeDayToggles .day-btn").forEach((btn) => {
    const d = Number(btn.dataset.day);
    btn.classList.toggle("active", freeSet.has(d));
  });
}

function renderCatalogChips() {
  const container = document.getElementById("catalogChips");
  container.innerHTML = `<span style="font-size:0.75rem;color:#94a3b8;margin-right:4px;">Verifizierte CAU-Kurse:</span>`;
  appState.catalog.forEach((c) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "chip";
    if (appState.currentCourse && appState.currentCourse.course_id === c.course_id) {
      btn.classList.add("active");
    }
    btn.innerHTML = `<strong>${c.course_id}</strong> <span style="opacity:0.75">(UnivIS ${c.univis_id})</span>`;
    btn.addEventListener("click", () => {
      document.getElementById("courseQueryInput").value = c.course_id;
      verifyAndRankCourse(c.course_id);
    });
    container.appendChild(btn);
  });
}

/* COURSE LOOKUP & STRICT ID VERIFICATION */
async function verifyAndRankCourse(queryId) {
  const banner = document.getElementById("verificationBanner");
  const res = await apiPost("/api/course/lookup", { query_id: queryId });

  if (!res.ok) {
    appState.currentCourse = null;
    appState.rankedGroups = [];
    banner.className = "verification-banner error";
    banner.innerHTML = `<div>🛡️ <strong>${res.error}</strong></div>`;
    renderRankedGroups();
    renderTimetable();
    renderCatalogChips();
    return;
  }

  appState.currentCourse = res.course;
  appState.rankedGroups = res.ranked_groups || [];
  document.getElementById("enrollModeSelect").value = res.course.enrollment_mode || "sniper";

  banner.className = "verification-banner verified";
  banner.innerHTML = `
    <div>
      ✅ <strong>Exakte Kurs-ID verifiziert:</strong> ${res.course.title}<br/>
      <span style="font-size:0.77rem;opacity:0.9;">
        Modulcode: <code>${res.course.course_id}</code> · UnivIS-Nr.: <code>${res.course.univis_id}</code> · OpenOlat-ID: <code>${res.course.olat_repo_id}</code> · Dozent/in: ${res.course.lecturer}
      </span>
    </div>
    <span class="step-pill" style="background:rgba(16,185,129,0.25);color:#6ee7b7;">ID SICHER</span>
  `;

  renderCatalogChips();
  renderRankedGroups();
  renderTimetable();
}

/* RENDER RANKED EXERCISE GROUPS */
async function pinGroupAsRank1(groupId) {
  if (!appState.currentCourse) return;
  const res = await apiPost("/api/course/pin-group", {
    course_id: appState.currentCourse.course_id,
    group_id: groupId,
  });
  if (res.ok) {
    appState.rankedGroups = res.ranked_groups || [];
    appState.pinnedGroupId = res.pinned_group_id || null;
    renderRankedGroups();
    renderTimetable();
    // Smoothly highlight the newly promoted Rank #1 card in Step 3
    const firstCard = document.querySelector("#rankedGroupsContainer .group-card.rank-1");
    if (firstCard) {
      firstCard.scrollIntoView({ behavior: "smooth", block: "nearest" });
      firstCard.style.boxShadow = "0 0 0 3px #10b981, 0 8px 25px rgba(16, 185, 129, 0.4)";
      setTimeout(() => {
        firstCard.style.boxShadow = "";
      }, 900);
    }
  }
}

function renderRankedGroups() {
  const container = document.getElementById("rankedGroupsContainer");
  container.innerHTML = "";

  if (!appState.currentCourse) {
    container.innerHTML = `<div style="padding:18px;text-align:center;color:#94a3b8;font-size:0.85rem;">Bitte gib oben eine verifizierte Kurs-ID ein, um die optimalen Übungsgruppen zu berechnen.</div>`;
    return;
  }

  appState.rankedGroups.forEach((g) => {
    const card = document.createElement("div");
    const isRank1 = g.rank === 1;
    const isPinned = Boolean(g.is_pinned);
    card.className = `group-card ${isRank1 ? "rank-1" : ""} ${g.is_conflict ? "conflict" : ""}`;
    card.title = g.is_conflict
      ? "Zeitkonflikt mit deinem Stundenplan"
      : isPinned
      ? "Manuell als Wunsch #1 fixiert (Klicke erneut zum Aufheben)"
      : "Klicke hier oder im Kalender, um diese Übungsgruppe als Wunsch #1 zu priorisieren!";

    const rankText = g.is_conflict ? "KONFLIKT" : `#${g.rank}`;
    const reasonsHtml = (g.reasons || [])
      .map((r) => `<span class="reason-pill">${r}</span>`)
      .join("");

    const pinBadge = isPinned
      ? `<span style="background:#10b981;color:#052e16;font-size:0.7rem;padding:2px 7px;border-radius:99px;margin-left:6px;font-weight:800;">📌 Manuell Priorisiert (Wunsch #1)</span>`
      : isRank1
      ? `<span style="color:#34d399;font-size:0.8rem;margin-left:4px;">🏆 (Bester Platz)</span>`
      : `<span style="font-size:0.72rem;color:#94a3b8;margin-left:6px;opacity:0.85;">👆 Klick = als #1 priorisieren</span>`;

    card.innerHTML = `
      <div class="group-left">
        <div class="rank-badge">
          <span>${rankText}</span>
        </div>
        <div class="group-info">
          <h4>${g.name} ${pinBadge}</h4>
          <div class="group-meta">
            🗓️ <strong>${g.day_name}, ${g.start_time} – ${g.end_time} Uhr</strong> · 📍 ${g.room || "CAU"} ${g.tutor ? `· 👤 ${g.tutor}` : ""}
          </div>
          <div class="group-reasons">${reasonsHtml}</div>
        </div>
      </div>
      <div class="group-right">
        <div class="score-circle">${g.is_conflict ? "Blockiert" : `${g.display_score}% Match`}</div>
        <div class="spots-tag">${g.spots_free} / ${g.spots_total} Plätze frei</div>
      </div>
    `;

    if (!g.is_conflict) {
      card.addEventListener("click", () => {
        pinGroupAsRank1(g.group_id);
      });
    }

    card.addEventListener("mouseenter", () => {
      appState.highlightedGroupId = g.group_id;
      renderTimetable();
    });
    card.addEventListener("mouseleave", () => {
      appState.highlightedGroupId = null;
      renderTimetable();
    });

    container.appendChild(card);
  });
}

/* RENDER WEEKLY TIMETABLE WITH CANDIDATE OVERLAYS */
function renderTimetable() {
  const grid = document.getElementById("timetableGrid");
  grid.innerHTML = "";

  // Header Row
  const corner = document.createElement("div");
  corner.className = "tt-header";
  corner.textContent = "Zeit";
  grid.appendChild(corner);

  const freeSet = new Set(appState.preferences.preferred_free_days || []);
  DAY_NAMES.forEach((dName, idx) => {
    const h = document.createElement("div");
    h.className = "tt-header";
    h.innerHTML = `${dName} ${freeSet.has(idx) ? '<span title="Wunsch-Frei" style="font-size:0.7rem;color:#34d399;">★ Frei</span>' : ""}`;
    grid.appendChild(h);
  });

  // Left Time Column
  const timeCol = document.createElement("div");
  timeCol.className = "tt-time-col";
  for (let hr = START_HOUR; hr < END_HOUR; hr++) {
    const slot = document.createElement("div");
    slot.className = "tt-time-slot";
    slot.textContent = `${String(hr).padStart(2, "0")}:00`;
    timeCol.appendChild(slot);
  }
  grid.appendChild(timeCol);

  // 5 Day Columns (Mo - Fr)
  const dayCols = [];
  for (let d = 0; d < 5; d++) {
    const col = document.createElement("div");
    col.className = `tt-day-col ${freeSet.has(d) ? "free-day-highlight" : ""}`;
    grid.appendChild(col);
    dayCols.push(col);
  }

  // 1. Place Fixed Lectures & Already Enrolled Exercises
  appState.schedule.forEach((ev) => {
    const dayIdx = Number(ev.day);
    if (dayIdx < 0 || dayIdx > 4) return;

    const startMins = timeToMinutes(ev.start_time);
    const endMins = timeToMinutes(ev.end_time);
    const topPx = ((startMins - START_HOUR * 60) / 60) * PX_PER_HOUR;
    const heightPx = Math.max(24, ((endMins - startMins) / 60) * PX_PER_HOUR);

    const el = document.createElement("div");
    const isEnabled = ev.enabled !== false;
    el.className = `tt-event ${ev.type || "lecture"} ${!isEnabled ? "disabled-event" : ""}`;
    el.style.top = `${topPx}px`;
    el.style.height = `${heightPx}px`;
    el.title = "Klicke zum Pausieren/Aktivieren · Rechtsklick zum Löschen";

    el.innerHTML = `
      <div class="tt-ev-title">${ev.title}</div>
      <div class="tt-ev-time">${ev.start_time}–${ev.end_time} ${ev.room ? `· ${ev.room}` : ""}</div>
    `;

    el.addEventListener("click", async (e) => {
      e.stopPropagation();
      const res = await apiPost("/api/schedule/toggle", { id: ev.id });
      if (res.ok) {
        appState.schedule = res.schedule;
        if (appState.currentCourse) {
          await verifyAndRankCourse(appState.currentCourse.course_id);
        } else {
          renderTimetable();
        }
      }
    });

    el.addEventListener("contextmenu", async (e) => {
      e.preventDefault();
      const res = await apiPost("/api/schedule/delete", { id: ev.id });
      if (res.ok) {
        appState.schedule = res.schedule;
        if (appState.currentCourse) {
          await verifyAndRankCourse(appState.currentCourse.course_id);
        } else {
          renderTimetable();
        }
      }
    });

    dayCols[dayIdx].appendChild(el);
  });

  // 2. Place Candidate Tutorial Overlays (All non-conflicting groups + hovered conflicts)
  // Group overlapping candidate slots on the same day/time so side-by-side parallel groups can both be clicked!
  const slotBuckets = {};
  appState.rankedGroups.forEach((g) => {
    const dayIdx = Number(g.day);
    if (dayIdx < 0 || dayIdx > 4) return;
    const isHovered = appState.highlightedGroupId === g.group_id;
    if (g.is_conflict && !isHovered) return;

    const key = `${dayIdx}-${g.start_time}-${g.end_time}`;
    if (!slotBuckets[key]) slotBuckets[key] = [];
    slotBuckets[key].push(g);
  });

  Object.values(slotBuckets).forEach((bucket) => {
    bucket.forEach((g, idxInBucket) => {
      const dayIdx = Number(g.day);
      const isHovered = appState.highlightedGroupId === g.group_id;
      const isRank1 = g.rank === 1;

      const startMins = timeToMinutes(g.start_time);
      const endMins = timeToMinutes(g.end_time);
      const topPx = ((startMins - START_HOUR * 60) / 60) * PX_PER_HOUR;
      const heightPx = Math.max(28, ((endMins - startMins) / 60) * PX_PER_HOUR);

      const el = document.createElement("div");
      let variant = "candidate-rank-alt";
      if (g.is_conflict) variant = "candidate-conflict";
      else if (isRank1) variant = "candidate-rank-1";

      el.className = `tt-event candidate-overlay ${variant}`;
      // If multiple groups of the same course share the exact same time slot, split width side-by-side
      if (bucket.length > 1) {
        const widthPct = 96 / bucket.length;
        const leftPct = 2 + idxInBucket * widthPct;
        el.style.left = `${leftPct}%`;
        el.style.right = "auto";
        el.style.width = `${widthPct - 1}%`;
      }

      if (isHovered) {
        el.style.transform = "scale(1.03)";
        el.style.zIndex = "35";
      }
      el.style.top = `${topPx}px`;
      el.style.height = `${heightPx}px`;
      el.title = g.is_conflict
        ? "Zeitkonflikt"
        : isRank1
        ? "Aktuell als Wunsch #1 ausgewählt! (Erneut klicken für Automatik)"
        : `Klicke auf diesen Kasten, um '${g.name}' sofort als Wunsch #1 (Grün) für Schritt 3 auszuwählen!`;

      const pinIcon = g.is_pinned ? "📌 " : "⭐ ";
      const badge = g.is_conflict
        ? "❌ KONFLIKT"
        : `${pinIcon}Wunsch #${g.rank} (${g.display_score}%)`;
      el.innerHTML = `
        <div class="tt-ev-title">${badge}: ${g.name}</div>
        <div class="tt-ev-time">${g.start_time}–${g.end_time} · 👆 Klick = Prio #1</div>
      `;

      if (!g.is_conflict) {
        el.addEventListener("click", (e) => {
          e.stopPropagation();
          pinGroupAsRank1(g.group_id);
        });
      }

      el.addEventListener("mouseenter", () => {
        appState.highlightedGroupId = g.group_id;
      });
      el.addEventListener("mouseleave", () => {
        appState.highlightedGroupId = null;
      });

      dayCols[dayIdx].appendChild(el);
    });
  });
}

/* EVENT BINDINGS */
function bindUIEvents() {
  // Course lookup
  document.getElementById("btnVerifyCourse").addEventListener("click", () => {
    const q = document.getElementById("courseQueryInput").value;
    verifyAndRankCourse(q);
  });
  document.getElementById("courseQueryInput").addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      verifyAndRankCourse(e.target.value);
    }
  });

  // Preference sliders -> live recalculation
  const sliderMap = [
    ["sliderCompact", "valCompact", "weight_compact"],
    ["sliderFreeDays", "valFreeDays", "weight_free_days"],
    ["sliderTimeWindow", "valTimeWindow", "weight_time_window"],
    ["sliderCampus", "valCampus", "weight_campus_buffer"],
  ];

  sliderMap.forEach(([sliderId, valId, prefKey]) => {
    const el = document.getElementById(sliderId);
    el.addEventListener("input", async () => {
      const v = Number(el.value);
      document.getElementById(valId).textContent = `${v}%`;
      appState.preferences[prefKey] = v;
      await savePreferencesAndRecalc();
    });
  });

  document.getElementById("prefEarliest").addEventListener("change", async (e) => {
    appState.preferences.earliest_time = e.target.value;
    await savePreferencesAndRecalc();
  });

  document.getElementById("prefLatest").addEventListener("change", async (e) => {
    appState.preferences.latest_time = e.target.value;
    await savePreferencesAndRecalc();
  });

  document.querySelectorAll("#freeDayToggles .day-btn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      btn.classList.toggle("active");
      const activeDays = [];
      document.querySelectorAll("#freeDayToggles .day-btn.active").forEach((b) => {
        activeDays.push(Number(b.dataset.day));
      });
      appState.preferences.preferred_free_days = activeDays;
      await savePreferencesAndRecalc();
    });
  });

  // Launch CAU Shibboleth SSO Chrome window
  document.getElementById("btnLaunchBrowser").addEventListener("click", async () => {
    const targetUrl = appState.currentCourse ? appState.currentCourse.url : "https://lms.uni-kiel.de";
    const res = await apiPost("/api/browser/launch", { url: targetUrl });
    if (res.status) updateBrowserBadge(res.status);
    await pollTelemetry();
  });

  // Execute Immediate Sniper / Priority Enrollment
  document.getElementById("btnExecuteNow").addEventListener("click", () => {
    triggerEnrollment("immediate", 0);
  });

  // Execute 5s Countdown Sniper
  document.getElementById("btnArmCountdown").addEventListener("click", () => {
    triggerEnrollment("countdown", 5);
  });

  // Modals open/close
  document.getElementById("btnOpenAddEventModal").addEventListener("click", () => {
    document.getElementById("modalAddEvent").classList.remove("hidden");
  });
  document.getElementById("btnOpenIcsModal").addEventListener("click", () => {
    document.getElementById("modalIcsImport").classList.remove("hidden");
  });
  document.getElementById("btnOpenCustomCourseModal").addEventListener("click", () => {
    document.getElementById("modalCustomCourse").classList.remove("hidden");
  });

  document.getElementById("btnEditCurrentGroups").addEventListener("click", () => {
    if (!appState.currentCourse) {
      alert("Bitte wähle zuerst oben in Schritt 1 einen Kurs aus!");
      return;
    }
    document.getElementById("editGroupsTitle").textContent = `✏️ Übungsgruppen für ${appState.currentCourse.course_id} anpassen / aus LMS einfügen`;
    const currentLines = (appState.currentCourse.groups || []).map(
      (g) => `${g.name}`
    );
    document.getElementById("editGroupsTextarea").value = currentLines.join("\n");
    document.getElementById("modalEditGroups").classList.remove("hidden");
  });

  document.getElementById("formEditGroups").addEventListener("submit", async (e) => {
    e.preventDefault();
    if (!appState.currentCourse) return;
    const rawText = document.getElementById("editGroupsTextarea").value;
    const res = await apiPost("/api/course/update-groups", {
      course_id: appState.currentCourse.course_id,
      raw_text: rawText,
    });
    if (!res.ok) {
      alert(res.error || "Fehler beim Parsen der Gruppen.");
      return;
    }
    document.getElementById("modalEditGroups").classList.add("hidden");
    await fetchInitialState();
    await verifyAndRankCourse(appState.currentCourse.course_id);
  });

  document.querySelectorAll("[data-close]").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.getElementById(btn.dataset.close).classList.add("hidden");
    });
  });

  // Add Manual Schedule Event
  document.getElementById("formAddEvent").addEventListener("submit", async (e) => {
    e.preventDefault();
    const ev = {
      title: document.getElementById("evTitle").value,
      day: Number(document.getElementById("evDay").value),
      start_time: document.getElementById("evStart").value,
      end_time: document.getElementById("evEnd").value,
      room: document.getElementById("evRoom").value,
      type: "lecture",
    };
    const res = await apiPost("/api/schedule/add", { event: ev });
    if (res.ok) {
      appState.schedule = res.schedule;
      document.getElementById("modalAddEvent").classList.add("hidden");
      document.getElementById("formAddEvent").reset();
      if (appState.currentCourse) {
        await verifyAndRankCourse(appState.currentCourse.course_id);
      } else {
        renderTimetable();
      }
    }
  });

  // UnivIS ICS Smart Cleaner
  document.getElementById("btnLoadDemoIcs").addEventListener("click", async () => {
    const res = await apiGet("/api/sample-ics");
    if (res.ok) {
      appState.icsStagedEvents = res.parsed_events || [];
      renderIcsPreviewList();
    }
  });

  document.getElementById("icsFileInput").addEventListener("change", async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const text = await file.text();
    const res = await apiPost("/api/schedule/parse-ics", { ics_text: text });
    if (res.ok) {
      appState.icsStagedEvents = res.parsed_events || [];
      renderIcsPreviewList();
    }
  });

  document.getElementById("btnApplyIcsSelection").addEventListener("click", async () => {
    const selected = appState.icsStagedEvents.filter((ev) => ev.enabled);
    const res = await apiPost("/api/schedule/update", { schedule: selected });
    if (res.ok) {
      appState.schedule = res.schedule;
      document.getElementById("modalIcsImport").classList.add("hidden");
      if (appState.currentCourse) {
        await verifyAndRankCourse(appState.currentCourse.course_id);
      } else {
        renderTimetable();
      }
    }
  });

  // Create Custom Course Form
  document.getElementById("formCustomCourse").addEventListener("submit", async (e) => {
    e.preventDefault();
    const lines = document
      .getElementById("custGroupsText")
      .value.split("\n")
      .map((l) => l.trim())
      .filter(Boolean);

    const payload = {
      course: {
        course_id: document.getElementById("custCourseId").value.trim(),
        univis_id: document.getElementById("custUnivisId").value.trim(),
        olat_repo_id: document.getElementById("custOlatId").value.trim(),
        title: document.getElementById("custTitle").value.trim(),
        enrollment_mode: document.getElementById("custMode").value,
        groups: lines,
      },
    };

    const res = await apiPost("/api/course/create-custom", payload);
    if (res.ok) {
      document.getElementById("modalCustomCourse").classList.add("hidden");
      await fetchInitialState();
      document.getElementById("courseQueryInput").value = res.course.course_id;
      await verifyAndRankCourse(res.course.course_id);
    }
  });
}

function renderIcsPreviewList() {
  const container = document.getElementById("icsPreviewContainer");
  const applyBtn = document.getElementById("btnApplyIcsSelection");
  container.innerHTML = "";

  if (!appState.icsStagedEvents.length) {
    container.innerHTML = `<div class="empty-hint">Keine gültigen Termine in der .ics Datei gefunden.</div>`;
    applyBtn.disabled = true;
    return;
  }

  applyBtn.disabled = false;
  appState.icsStagedEvents.forEach((ev, idx) => {
    const row = document.createElement("div");
    row.className = `ics-item ${ev.univis_warning ? "suspicious" : ""}`;
    row.innerHTML = `
      <label class="checkbox-label" style="flex:1;">
        <input type="checkbox" data-ics-idx="${idx}" ${ev.enabled ? "checked" : ""} />
        <div>
          <strong>${ev.title}</strong>
          <div style="font-size:0.75rem;color:#94a3b8;">
            ${ev.day_name}, ${ev.start_time} – ${ev.end_time} Uhr ${ev.room ? `· ${ev.room}` : ""}
          </div>
        </div>
      </label>
      ${ev.univis_warning ? `<span class="ics-warn-badge">🧹 ${ev.univis_warning}</span>` : `<span style="font-size:0.72rem;color:#34d399;">✓ Feste Vorlesung</span>`}
    `;

    row.querySelector("input").addEventListener("change", (e) => {
      appState.icsStagedEvents[idx].enabled = e.target.checked;
    });
    container.appendChild(row);
  });
}

async function savePreferencesAndRecalc() {
  await apiPost("/api/preferences/update", { preferences: appState.preferences });
  if (appState.currentCourse) {
    await verifyAndRankCourse(appState.currentCourse.course_id);
  } else {
    renderTimetable();
  }
}

async function triggerEnrollment(triggerType, countdownSeconds) {
  if (!appState.currentCourse) {
    alert("Bitte zuerst eine Kurs-ID in Schritt 1 verifizieren!");
    return;
  }
  const mode = document.getElementById("enrollModeSelect").value;
  const simulateFallback = document.getElementById("chkSimulateFallback").checked;

  const badge = document.getElementById("jobStatusBadge");
  badge.className = "status-pill";
  badge.textContent = countdownSeconds > 0 ? `Sniper Countdown (${countdownSeconds}s)...` : "Einschreibung läuft...";

  await apiPost("/api/enroll/execute", {
    course_id: appState.currentCourse.course_id,
    mode,
    simulate_first_choice_full: simulateFallback,
    trigger_type: triggerType,
    countdown_seconds: countdownSeconds,
  });

  setTimeout(pollTelemetry, 300);
}

async function pollTelemetry() {
  try {
    const data = await apiGet("/api/logs");
    if (!data.ok) return;
    renderLogs(data.logs || []);
    updateBrowserBadge(data.browser_status);

    // Check if schedule changed (e.g. a sniper job completed and added the won exercise group)
    if (data.schedule && data.schedule.length !== appState.schedule.length) {
      appState.schedule = data.schedule;
      renderTimetable();
    }

    if (data.jobs && data.jobs.length > 0) {
      const latest = data.jobs[0];
      const badge = document.getElementById("jobStatusBadge");
      if (latest.status === "completed") {
        badge.className = "status-pill completed";
        badge.textContent = `✓ ${latest.result_message}`;
        appState.schedule = data.schedule || appState.schedule;
        renderTimetable();
      } else if (latest.status === "running" || latest.status === "armed") {
        badge.className = "status-pill";
        badge.textContent = `⚡ ${latest.result_message}`;
      }
    }
  } catch (e) {
    // Ignore transient network errors
  }
}

function updateBrowserBadge(status) {
  if (!status) return;
  const badge = document.getElementById("ssoBadge");
  const text = document.getElementById("ssoStatusText");
  if (status.logged_in) {
    badge.className = "sso-badge connected";
    text.textContent = "CAU SSO: Verbunden (lms.uni-kiel.de)";
  } else if (status.browser_running) {
    badge.className = "sso-badge";
    text.textContent = "Chrome offen: Bitte im Fenster einloggen";
  } else {
    badge.className = "sso-badge";
    text.textContent = "Shibboleth SSO: Bereit";
  }
}

function renderLogs(logs) {
  const container = document.getElementById("terminalLogs");
  const wasAtBottom = container.scrollHeight - container.scrollTop <= container.clientHeight + 30;
  container.innerHTML = logs
    .map(
      (l) => `
      <div class="log-line">
        <span class="log-time">[${l.timestamp}]</span>
        <span class="log-lvl ${l.level}">${l.level}</span>
        <span class="log-msg">${l.message}</span>
      </div>`
    )
    .join("");
  if (wasAtBottom) {
    container.scrollTop = container.scrollHeight;
  }
}
