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
  enrolledGroups: {},
  catalog: [],
  currentCourse: null,
  currentEnrolledGroupId: null,
  rankedGroups: [],
  highlightedGroupId: null,
  icsStagedEvents: [],
  credentials: {
    username: "",
    has_password: false,
    default_platform: "https://lms.uni-kiel.de",
    auto_fill: true,
    auto_submit: true,
    use_keychain: true,
  },
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
  initThemeMode();
  bindUIEvents();
  await fetchInitialState();
  await verifyAndRankCourse(document.getElementById("courseQueryInput").value);
  setInterval(pollTelemetry, 1800);
});

function initThemeMode() {
  const savedTheme = localStorage.getItem("cau_dorfic_theme") || "light";
  const btn = document.getElementById("btnToggleDarkMode");
  if (savedTheme === "dark") {
    document.body.classList.add("dark-mode");
    if (btn) btn.textContent = "☀️ Daylight Mode";
  }
  if (btn) {
    btn.addEventListener("click", () => {
      const isDark = document.body.classList.toggle("dark-mode");
      localStorage.setItem("cau_dorfic_theme", isDark ? "dark" : "light");
      btn.textContent = isDark ? "☀️ Daylight Mode" : "🌙 Dark Mode";
    });
  }
}

async function fetchInitialState() {
  const data = await apiGet("/api/state");
  if (!data.ok) return;
  appState.schedule = data.schedule || [];
  appState.preferences = data.preferences || appState.preferences;
  appState.enrolledGroups = data.enrolled_groups || {};
  appState.catalog = data.catalog || [];
  if (data.credentials) {
    appState.credentials = data.credentials;
    syncCredentialsUI(data.credentials, true);
  }

  syncPreferencesUI();
  renderCatalogChips();
  renderTimetable();
  renderLogs(data.logs || []);
  updateBrowserBadge(data.browser_status);

  // Mark existing completed and locked jobs as already acknowledged so no old popup shows on initial load
  if (data.jobs && Array.isArray(data.jobs)) {
    data.jobs.forEach((j) => {
      if ((j.status === "completed" || j.status === "locked") && j.job_id) {
        sessionStorage.setItem(`notified_job_${j.job_id}`, "1");
      }
    });
  }
}

function syncCredentialsUI(creds, isInitial = false) {
  if (!creds) return;
  const userEl = document.getElementById("credUsername");
  const passEl = document.getElementById("credPassword");
  const platEl = document.getElementById("credPlatform");
  const fillEl = document.getElementById("credAutoFill");
  const subEl = document.getElementById("credAutoSubmit");
  const keyEl = document.getElementById("credUseKeychain");
  const badgeEl = document.getElementById("vaultSavedBadge");
  const topBtn = document.getElementById("btnToggleAccountPanel");
  const formBody = document.getElementById("formCredentials");
  const collapseBtn = document.getElementById("btnCollapseVault");

  if (userEl && (isInitial || !document.activeElement || document.activeElement !== userEl)) {
    userEl.value = creds.username || "";
  }
  if (passEl && (isInitial || !document.activeElement || document.activeElement !== passEl)) {
    passEl.value = creds.has_password ? "••••••••" : "";
  }
  if (platEl && creds.default_platform) {
    platEl.value = creds.default_platform;
  }
  if (fillEl) fillEl.checked = creds.auto_fill !== false;
  if (subEl) subEl.checked = creds.auto_submit !== false;
  if (keyEl) keyEl.checked = creds.use_keychain !== false;

  const isSaved = Boolean(creds.username && creds.has_password);
  if (badgeEl) {
    if (isSaved) {
      badgeEl.className = "vault-badge saved";
      badgeEl.textContent = `🔒 Gespeichert: ${creds.username} (${creds.keychain_active ? "macOS Keychain" : "Tresor"} · Auto-Login aktiv)`;
    } else {
      badgeEl.className = "vault-badge unsaved";
      badgeEl.textContent = "Noch kein Account gespeichert";
    }
  }
  if (topBtn) {
    topBtn.textContent = isSaved
      ? `🔑 Auto-Login: ${creds.username}`
      : "🔑 CAU Account hinterlegen";
  }

  // On initial load, if credentials are already saved, collapse the form so it stays compact
  if (isInitial && isSaved && formBody && collapseBtn) {
    formBody.classList.add("collapsed");
    collapseBtn.textContent = "⚙️ Bearbeiten / Ausklappen";
  }
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
  container.innerHTML = `<span style="font-size:0.75rem;color:#0a4d82;font-weight:800;text-transform:uppercase;margin-right:4px;">🫧 UNIBODY Katalog:</span>`;
  appState.catalog.forEach((c) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "chip";
    if (appState.currentCourse && appState.currentCourse.course_id === c.course_id) {
      btn.classList.add("active");
    }
    const ckey = (c.course_id || "").toLowerCase();
    const hasEnrolled = Boolean((appState.enrolledGroups && appState.enrolledGroups[ckey]) || c.enrolled_group_id);
    const platIcon = c.platform_id === "elearn_inf" ? "💻 elearn.inf" : "🏛️ lms";
    const bookedDot = hasEnrolled ? " ✅" : "";
    btn.title = hasEnrolled
      ? `${c.course_id}: Du hast hier bereits eine Übungsgruppe gebucht (${c.platform_host || "lms.uni-kiel.de"})`
      : `UNIBODY routet diesen Kurs automatisch auf ${c.platform_host || "lms.uni-kiel.de"}`;
    btn.innerHTML = `<strong>${c.course_id}${bookedDot}</strong> <span style="opacity:0.85;font-size:0.68rem;">[${platIcon}]</span>`;
    btn.addEventListener("click", () => {
      document.getElementById("courseQueryInput").value = c.course_id;
      verifyAndRankCourse(c.course_id);
    });
    container.appendChild(btn);
  });
}

/* COURSE LOOKUP & STRICT ID VERIFICATION + UNIBODY ROUTING */
async function verifyAndRankCourse(queryId) {
  const banner = document.getElementById("verificationBanner");
  const res = await apiPost("/api/course/lookup", { query_id: queryId });

  if (!res.ok) {
    appState.currentCourse = null;
    appState.currentEnrolledGroupId = null;
    appState.rankedGroups = [];
    banner.className = "verification-banner error";
    banner.innerHTML = `<div>🛡️ <strong>${res.error}</strong></div>`;
    renderRankedGroups();
    renderTimetable();
    renderCatalogChips();
    return;
  }

  appState.currentCourse = res.course;
  appState.currentEnrolledGroupId = res.enrolled_group_id || null;
  if (appState.currentCourse && appState.currentCourse.course_id) {
    const ck = appState.currentCourse.course_id.toLowerCase();
    if (res.enrolled_group_id) appState.enrolledGroups[ck] = res.enrolled_group_id;
    else delete appState.enrolledGroups[ck];
  }
  appState.rankedGroups = res.ranked_groups || [];
  document.getElementById("enrollModeSelect").value = res.course.enrollment_mode || "sniper";

  const isElearnInf = res.course.platform_id === "elearn_inf";
  const unibodyPillStyle = isElearnInf
    ? "background:linear-gradient(180deg,#5eead4 0%,#0d9488 50%,#0f766e 100%);color:#ffffff;border:1px solid #115e59;"
    : "background:linear-gradient(180deg,#62d4ff 0%,#0088e8 50%,#0062b8 100%);color:#ffffff;border:1px solid #004b8f;";

  banner.className = "verification-banner verified";
  banner.innerHTML = `
    <div style="flex:1;">
      <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:4px;">
        <span>✅ <strong>Exakte Kurs-ID verifiziert:</strong> ${res.course.title}</span>
        <span class="step-pill" style="${unibodyPillStyle}">
          🫧 UNIBODY &rarr; ${res.course.platform_host || "lms.uni-kiel.de"}
        </span>
      </div>
      <span style="font-size:0.77rem;opacity:0.95;">
        Modulcode: <code>${res.course.course_id}</code> · UnivIS-Nr.: <code>${res.course.univis_id}</code> · Ziel-System: <strong>${res.course.platform_badge || res.course.platform}</strong> · Dozent/in: ${res.course.lecturer}
      </span>
    </div>
    <button type="button" id="btnRouteCourseBrowser" class="btn btn-xs btn-primary" title="Öffnet diesen Kurs automatisch auf der richtigen Plattform (${res.course.platform_host}) und loggt dich ein">
      🚀 Auf ${res.course.platform_short || res.course.platform_host} öffnen
    </button>
  `;

  const routeBtn = document.getElementById("btnRouteCourseBrowser");
  if (routeBtn) {
    routeBtn.addEventListener("click", async () => {
      const r = await apiPost("/api/browser/launch", {
        url: res.course.url,
        force_auto_login: true,
      });
      if (r.status) updateBrowserBadge(r.status);
      await pollTelemetry();
    });
  }

  renderCatalogChips();
  renderRankedGroups();
  renderTimetable();
}

/* MARK OR SYNC ALREADY ENROLLED GROUPS (SO UNIBODY KNOWS WHAT YOU ALREADY BOOKED) */
async function markGroupAsAlreadyEnrolled(groupId) {
  if (!appState.currentCourse) return;
  const isUnenroll = !groupId || appState.currentEnrolledGroupId === groupId;
  const previousGroup = appState.rankedGroups.find((g) => g.group_id === (appState.currentEnrolledGroupId || groupId)) || null;
  const currentCourseRef = { ...appState.currentCourse };

  if (isUnenroll) {
    const clearBtn = document.getElementById("btnClearEnrolledCurrent");
    const origClearHtml = clearBtn ? clearBtn.innerHTML : "";
    if (clearBtn) {
      clearBtn.disabled = true;
      clearBtn.innerHTML = "⏳ UNIBODY meldet im Browser ab...";
      clearBtn.style.opacity = "0.75";
      clearBtn.style.pointerEvents = "none";
    }
    const markBtns = document.querySelectorAll(".btn-mark-enrolled");
    markBtns.forEach((b) => {
      b.disabled = true;
      b.style.pointerEvents = "none";
    });

    try {
      const res = await apiPost("/api/course/unenroll", {
        course_id: appState.currentCourse.course_id,
      });

      if (res && res.ok && res.unenroll_verified) {
        appState.schedule = res.schedule || appState.schedule;
        appState.enrolledGroups = res.enrolled_groups || appState.enrolledGroups;
        appState.currentEnrolledGroupId = null;
        appState.rankedGroups = res.ranked_groups || [];
        renderCatalogChips();
        renderRankedGroups();
        renderTimetable();
        await pollTelemetry();

        // STRICT REQUIREMENT: Only show popup AFTER browser unenrollment is physically verified!
        showUnenrollmentSuccessModal(currentCourseRef, previousGroup);
      } else {
        const errorMsg = (res && res.message) || "Die Austragung im Browser konnte nicht bestätigt werden.";
        alert(
          `⚠️ UNIBODY Live-Austragung:\n\n${errorMsg}\n\nGoogle Chrome bleibt für dich geöffnet, damit du den Status auf ${currentCourseRef.platform_host || "dem LMS"} direkt prüfen kannst.`
        );
        await pollTelemetry();

        if (confirm("Möchtest du diesen Kurs trotzdem nur lokal aus deinem Wochenplan austragen (ohne LMS-Abmeldung)?")) {
          const fRes = await apiPost("/api/course/unenroll", {
            course_id: appState.currentCourse.course_id,
            force: true,
          });
          if (fRes && fRes.ok) {
            appState.schedule = fRes.schedule || appState.schedule;
            appState.enrolledGroups = fRes.enrolled_groups || appState.enrolledGroups;
            appState.currentEnrolledGroupId = null;
            appState.rankedGroups = fRes.ranked_groups || [];
            renderCatalogChips();
            renderRankedGroups();
            renderTimetable();
            await pollTelemetry();
          }
        }
      }
    } catch (err) {
      alert("⚠️ Netzwerkfehler beim Kommunizieren mit dem UNIBODY Backend.");
    } finally {
      if (clearBtn) {
        clearBtn.disabled = false;
        clearBtn.innerHTML = origClearHtml;
        clearBtn.style.opacity = "1";
        clearBtn.style.pointerEvents = "auto";
      }
      markBtns.forEach((b) => {
        b.disabled = false;
        b.style.pointerEvents = "auto";
      });
    }
    return;
  }

  // Enrollment (marking group as booked):
  const res = await apiPost("/api/course/mark-enrolled", {
    course_id: appState.currentCourse.course_id,
    group_id: groupId,
  });
  if (res.ok) {
    appState.schedule = res.schedule || appState.schedule;
    appState.enrolledGroups = res.enrolled_groups || appState.enrolledGroups;
    appState.currentEnrolledGroupId = res.enrolled_group_id || null;
    appState.rankedGroups = res.ranked_groups || [];
    renderCatalogChips();
    renderRankedGroups();
    renderTimetable();
    await pollTelemetry();
  }
}

async function syncEnrolledGroupsFromBrowser() {
  const btn = document.getElementById("btnSyncEnrolledGroups");
  if (btn) {
    btn.disabled = true;
    btn.textContent = "🔄 UNIBODY prüft OpenOlat & eLearn...";
  }
  try {
    const res = await apiPost("/api/course/sync-enrolled", {});
    if (res.schedule) appState.schedule = res.schedule;
    if (res.enrolled_groups) appState.enrolledGroups = res.enrolled_groups;
    if (appState.currentCourse) {
      await verifyAndRankCourse(appState.currentCourse.course_id);
    } else {
      renderCatalogChips();
      renderTimetable();
    }
    await pollTelemetry();
    if (btn) {
      const count = (res.detected || []).length;
      btn.textContent = count > 0
        ? `✅ ${count} gebuchte Übung(en) importiert!`
        : "ℹ️ Keine aktiven Übungen gefunden";
      setTimeout(() => {
        btn.textContent = "🔄 UNIBODY Deep-Sync (Gebuchte Übungen holen)";
        btn.disabled = false;
      }, 3500);
    }
  } catch (e) {
    if (btn) {
      btn.textContent = "🔄 UNIBODY Deep-Sync (Gebuchte Übungen holen)";
      btn.disabled = false;
    }
  }
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
    appState.currentEnrolledGroupId = res.enrolled_group_id || appState.currentEnrolledGroupId;
    renderRankedGroups();
    renderTimetable();
    const firstCard = document.querySelector("#rankedGroupsContainer .group-card.rank-1");
    if (firstCard) {
      firstCard.scrollIntoView({ behavior: "smooth", block: "nearest" });
      firstCard.style.boxShadow = "0 0 0 3px #1db933, 0 8px 25px rgba(29, 185, 51, 0.35)";
      setTimeout(() => {
        firstCard.style.boxShadow = "";
      }, 900);
    }
  }
}

function formatCapacityTag(g, course) {
  const total = Number(g.spots_total) || 40;
  const free = g.spots_free !== undefined && g.spots_free !== null ? Number(g.spots_free) : total;
  const taken = Math.max(0, total - free);

  // Check if group is full or ausgebucht
  if (g.is_full || free <= 0) {
    return `<span class="spots-pill spots-full" title="Gruppe ist voll belegt (${total}/${total}) · Keine freien Plätze">🔴 Ausgebucht (${total}/${total})</span>`;
  }

  // Check if course or group registration has not opened yet
  const openDateStr = g.enrollment_opens_at || (course ? course.enrollment_opens_at : null);
  let isOpenFuture = false;
  let dateLabel = "demnächst";
  if (openDateStr) {
    const d = new Date(openDateStr);
    if (!isNaN(d.getTime()) && d > new Date()) {
      isOpenFuture = true;
      dateLabel = `${String(d.getDate()).padStart(2, "0")}.${String(d.getMonth() + 1).padStart(2, "0")}.`;
    }
  }

  if (g.is_locked) {
    return `<span class="spots-pill spots-locked" title="Anmeldung durch Dozenten noch gesperrt (${total} Plätze vorbereitet)">🔒 Gesperrt (${total} Plätze)</span>`;
  }

  if (isOpenFuture && taken === 0) {
    return `<span class="spots-pill spots-locked" title="Einschreibung öffnet am ${openDateStr} · Alle ${total} Plätze verfügbar">🔒 Start: ${dateLabel} (${total} Plätze)</span>`;
  }

  if (taken > 0) {
    if (free <= 4) {
      return `<span class="spots-pill spots-few" title="${free} freie Restplätze (${taken}/${total} belegt)">⚠️ Nur noch ${free} frei (${taken}/${total})</span>`;
    }
    return `<span class="spots-pill spots-open" title="${free} freie Plätze (${taken}/${total} belegt)">🟢 ${free} frei (${taken}/${total} belegt)</span>`;
  }

  return `<span class="spots-pill spots-open" title="Alle ${total} Plätze frei verfügbar (0 belegt)">🟢 Alle ${total} Plätze frei (0/${total})</span>`;
}

function renderRankedGroups() {
  const container = document.getElementById("rankedGroupsContainer");
  const enrolledBanner = document.getElementById("currentCourseEnrolledBanner");
  container.innerHTML = "";

  if (!appState.currentCourse) {
    if (enrolledBanner) enrolledBanner.classList.add("hidden");
    container.innerHTML = `<div style="padding:18px;text-align:center;color:#525c68;font-size:0.85rem;">Bitte gib oben eine verifizierte Kurs-ID ein, um die optimalen Übungsgruppen zu berechnen.</div>`;
    return;
  }

  const enrolledGrp = appState.rankedGroups.find((g) => g.is_enrolled || g.group_id === appState.currentEnrolledGroupId);
  const rank1Grp = appState.rankedGroups.find((g) => g.rank === 1);

  if (enrolledBanner) {
    if (enrolledGrp) {
      const isAlreadyOptimal = rank1Grp && rank1Grp.group_id === enrolledGrp.group_id;
      enrolledBanner.classList.remove("hidden");
      enrolledBanner.innerHTML = `
        <div style="flex:1;">
          <div>
            ✅ <strong>Bereits gebuchte Übung in ${appState.currentCourse.course_id}:</strong>
            <span>${enrolledGrp.name} (${enrolledGrp.day_name}, ${enrolledGrp.start_time}–${enrolledGrp.end_time} Uhr · ${enrolledGrp.display_score}% Match)</span>
          </div>
          <div style="font-size:0.76rem;margin-top:3px;opacity:0.95;">
            ${
              isAlreadyOptimal
                ? "🎉 <strong>Perfekt!</strong> Deine bereits gebuchte Gruppe ist gleichzeitig Platz #1 im Optimizer. Der Termin ist fest im Wochenplan für alle anderen Kurse reserviert."
                : `💡 <strong>Upgrade möglich:</strong> <strong>${rank1Grp ? rank1Grp.name : "Eine andere Gruppe"}</strong> hätte einen höheren Score (${rank1Grp ? rank1Grp.display_score : ""}% statt ${enrolledGrp.display_score}%). Du kannst per Sniper automatisch auf die bessere Gruppe wechseln!`
            }
          </div>
        </div>
        <button type="button" id="btnClearEnrolledCurrent" class="btn" style="background:#dc2626; color:#fff; font-weight:700; border-radius:10px; padding:6px 14px; border:none; cursor:pointer; font-size:0.8rem; box-shadow:0 2px 8px rgba(220,38,38,0.4);" title="Aus diesem Kurs austragen und aus dem Stundenplan entfernen">
          ✕ Aus Kurs austragen
        </button>
      `;
      const clearBtn = document.getElementById("btnClearEnrolledCurrent");
      if (clearBtn) {
        clearBtn.addEventListener("click", () => {
          markGroupAsAlreadyEnrolled(null);
        });
      }
    } else {
      enrolledBanner.classList.add("hidden");
    }
  }

  appState.rankedGroups.forEach((g) => {
    const card = document.createElement("div");
    const isRank1 = g.rank === 1;
    const isPinned = Boolean(g.is_pinned);
    const isEnrolled = Boolean(g.is_enrolled || g.group_id === appState.currentEnrolledGroupId);
    card.className = `group-card ${isRank1 ? "rank-1" : ""} ${g.is_conflict ? "conflict" : ""} ${isEnrolled ? "already-enrolled-card" : ""}`;
    card.title = g.is_conflict
      ? "Zeitkonflikt mit deinem Stundenplan"
      : isPinned
      ? "Manuell als Wunsch #1 fixiert (Klicke erneut zum Aufheben)"
      : "Klicke hier oder im Kalender, um diese Übungsgruppe als Wunsch #1 zu priorisieren!";

    const rankText = g.is_conflict ? "KONFLIKT" : `#${g.rank}`;
    const reasonsHtml = (g.reasons || [])
      .map((r) => `<span class="reason-pill">${r}</span>`)
      .join("");

    const enrolledBadge = isEnrolled
      ? `<span style="background:linear-gradient(180deg,#42f5d4 0%,#00bfa5 50%,#008e7b 100%);color:#002b24;font-size:0.7rem;padding:2px 9px;border-radius:99px;margin-left:6px;font-weight:900;border:1px solid #00796b;box-shadow:0 2px 6px rgba(0,191,165,0.35);">✅ Aktuell gebucht (Im Kalender aktiv)</span>`
      : "";

    const pinBadge = isPinned
      ? `<span style="background:linear-gradient(180deg,#52eb68 0%,#1db933 50%,#0e8a21 100%);color:#ffffff;font-size:0.7rem;padding:2px 8px;border-radius:99px;margin-left:6px;font-weight:900;border:1px solid #0b6e1a;">📌 Manuell Priorisiert (Wunsch #1)</span>`
      : isRank1
      ? `<span style="color:#0f8a22;font-size:0.8rem;font-weight:900;margin-left:4px;">🏆 (Bester Platz)</span>`
      : `<span style="font-size:0.72rem;color:#35658a;margin-left:6px;">👆 Klick = als #1 priorisieren</span>`;

    const enrollToggleBtnStyle = isEnrolled
      ? "background:rgba(239,68,68,0.18);color:#fca5a5;border:1px solid #ef4444;font-weight:800;padding:4px 10px;border-radius:999px;font-size:0.71rem;cursor:pointer;margin-top:6px;display:inline-flex;align-items:center;gap:4px;"
      : "background:rgba(0,140,230,0.12);color:inherit;border:1px solid rgba(0,150,240,0.4);font-weight:700;padding:4px 10px;border-radius:999px;font-size:0.71rem;cursor:pointer;margin-top:6px;display:inline-flex;align-items:center;gap:4px;";

    card.innerHTML = `
      <div class="group-left">
        <div class="rank-badge">
          <span>${rankText}</span>
        </div>
        <div class="group-info">
          <h4>${g.name} ${enrolledBadge} ${pinBadge}</h4>
          <div class="group-meta">
            🗓️ <strong>${g.day_name}, ${g.start_time} – ${g.end_time} Uhr</strong> · 📍 ${g.room || "CAU"} ${g.tutor ? `· 👤 ${g.tutor}` : ""}
          </div>
          <div class="group-reasons">${reasonsHtml}</div>
        </div>
      </div>
      <div class="group-right">
        <div class="score-circle">${g.is_conflict ? "Blockiert" : `${g.display_score}% Match`}</div>
        <div class="spots-tag">${formatCapacityTag(g, appState.currentCourse)}</div>
        <button type="button" class="btn-mark-enrolled" style="${enrollToggleBtnStyle}" title="${isEnrolled ? 'Klicke hier, um dich aus dieser Übungsgruppe auszutragen' : 'Klicke hier, um diese Übungsgruppe als gebucht einzutragen'}">
          ${isEnrolled ? "✕ Aus Gruppe austragen" : "☑️ Schon manuell gebucht?"}
        </button>
      </div>
    `;

    const markBtn = card.querySelector(".btn-mark-enrolled");
    if (markBtn) {
      markBtn.addEventListener("click", (e) => {
        e.stopPropagation();
        markGroupAsAlreadyEnrolled(g.group_id);
      });
    }

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

  // 1. Place Fixed Lectures & Enrolled Exercises (with parallel-slot bucketing)
  const schedBuckets = {};
  appState.schedule.forEach((ev) => {
    const dayIdx = Number(ev.day);
    if (dayIdx < 0 || dayIdx > 4) return;

    // Determine associated course token (from ev.course_id, ev.univis_id, or extracted from title)
    let linkedCourseToken = ev.course_id || ev.univis_id || null;
    if (!linkedCourseToken && ev.title) {
      const mHash = ev.title.match(/#(\d{5,6})/);
      const mCode = ev.title.match(/\b(infEWInf-01a|infEInf-02a|infEInf-01a|Inf-Math-A|BWL-EinfBWL|Inf-InfRecht)\b/i);
      if (mCode) linkedCourseToken = mCode[1];
      else if (mHash) linkedCourseToken = mHash[1];
    }

    const isSelectedCourse = Boolean(
      appState.currentCourse &&
      linkedCourseToken &&
      (appState.currentCourse.course_id.toLowerCase() === linkedCourseToken.toLowerCase() ||
        String(appState.currentCourse.univis_id).includes(linkedCourseToken))
    );

    // If an enrolled exercise belongs to the currently active course, skip it here because
    // it will be seamlessly rendered and bucketed together with the course's candidate groups in Part 2!
    if (ev.type === "enrolled_exercise" && isSelectedCourse) return;

    const key = `${dayIdx}-${ev.start_time}-${ev.end_time}`;
    if (!schedBuckets[key]) schedBuckets[key] = [];
    schedBuckets[key].push({ ev, linkedCourseToken, isSelectedCourse });
  });

  Object.values(schedBuckets).forEach((bucket) => {
    bucket.sort((a, b) => String(a.ev.id).localeCompare(String(b.ev.id)));
    bucket.forEach(({ ev, linkedCourseToken, isSelectedCourse }, idxInBucket) => {
      const dayIdx = Number(ev.day);
      const startMins = timeToMinutes(ev.start_time);
      const endMins = timeToMinutes(ev.end_time);
      const topPx = ((startMins - START_HOUR * 60) / 60) * PX_PER_HOUR;
      const heightPx = Math.max(24, ((endMins - startMins) / 60) * PX_PER_HOUR);

      const el = document.createElement("div");
      const isEnabled = ev.enabled !== false;
      el.className = `tt-event ${ev.type || "lecture"} ${!isEnabled ? "disabled-event" : ""} ${isSelectedCourse ? "selected-lecture-block" : ""}`;
      el.style.top = `${topPx}px`;
      el.style.height = `${heightPx}px`;

      if (bucket.length > 1) {
        const gapPct = 1.5;
        const totalGaps = (bucket.length - 1) * gapPct;
        const widthPct = (96 - totalGaps) / bucket.length;
        const leftPct = 2 + idxInBucket * (widthPct + gapPct);
        el.style.left = `${leftPct}%`;
        el.style.right = "auto";
        el.style.width = `${widthPct}%`;
      } else {
        el.style.left = "4px";
        el.style.right = "4px";
        el.style.width = "auto";
      }

      if (isSelectedCourse) {
        el.style.boxShadow = "0 0 0 2.5px #f8fafc, 0 6px 18px rgba(59, 130, 246, 0.55)";
        el.style.zIndex = "18";
      }
      el.title = linkedCourseToken
        ? `👆 Klick = Diesen Kurs ('${linkedCourseToken}') sofort in Schritt 1 auswählen · Shift+Klick = Pausieren · Rechtsklick = Löschen`
        : "Shift+Klick zum Pausieren/Aktivieren · Rechtsklick zum Löschen";

      el.innerHTML = `
        <div class="tt-ev-title">${isSelectedCourse ? "🎯 " : ""}${ev.title}</div>
        <div class="tt-ev-time">${ev.start_time}–${ev.end_time} ${ev.room ? `· ${ev.room}` : ""}</div>
      `;

      el.addEventListener("click", async (e) => {
        e.stopPropagation();
        if (!e.shiftKey && linkedCourseToken) {
          const inputEl = document.getElementById("courseQueryInput");
          inputEl.value = linkedCourseToken;
          await verifyAndRankCourse(linkedCourseToken);
          inputEl.style.boxShadow = "0 0 0 3px #8b5cf6";
          setTimeout(() => {
            inputEl.style.boxShadow = "";
          }, 700);
          return;
        }

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
          if (res.enrolled_groups) appState.enrolledGroups = res.enrolled_groups;
          if (appState.currentCourse) {
            await verifyAndRankCourse(appState.currentCourse.course_id);
          } else {
            renderCatalogChips();
            renderTimetable();
          }
        }
      });

      dayCols[dayIdx].appendChild(el);
    });
  });

  // 2. Place Candidate Tutorial Overlays (All non-conflicting groups + enrolled group + hovered conflicts)
  // Group overlapping candidate slots on the same day/time so side-by-side parallel groups can both be clicked!
  const slotBuckets = {};
  appState.rankedGroups.forEach((g) => {
    const dayIdx = Number(g.day);
    if (dayIdx < 0 || dayIdx > 4) return;
    const isEnrolled = Boolean(g.is_enrolled || g.group_id === appState.currentEnrolledGroupId);
    const isHovered = appState.highlightedGroupId === g.group_id;
    if (g.is_conflict && !isHovered && !isEnrolled) return;

    const key = `${dayIdx}-${g.start_time}-${g.end_time}`;
    if (!slotBuckets[key]) slotBuckets[key] = [];
    slotBuckets[key].push(g);
  });

  function formatShortGroupName(fullName) {
    if (!fullName) return "";
    const mWeek = fullName.match(/\b(w1|w2|Woche\s*[AB]|Gr\.?\s*[AB]|14-tägig\s*Gr\.?\s*[AB])\b/i);
    let weekLabel = "";
    if (mWeek) {
      const raw = mWeek[1].toUpperCase();
      if (raw === "W1" || raw.includes("GR. A") || raw === "WOCHE A") weekLabel = " [Woche A]";
      else if (raw === "W2" || raw.includes("GR. B") || raw === "WOCHE B") weekLabel = " [Woche B]";
      else weekLabel = ` [${raw}]`;
    }
    const mGrp = fullName.match(/(?:gruppe|gr\.?|übung)\s*0*(\d+[a-zA-Z]?)/i);
    const grpNum = mGrp ? `Gr. ${mGrp[1]}` : "";
    return grpNum ? `${grpNum}${weekLabel}` : fullName;
  }

  Object.values(slotBuckets).forEach((bucket) => {
    // CRITICAL: Stable sort so enrolled group / Woche A is on the left and Woche B is on the right!
    bucket.sort((a, b) => {
      const aEnrolled = Boolean(a.is_enrolled || a.group_id === appState.currentEnrolledGroupId);
      const bEnrolled = Boolean(b.is_enrolled || b.group_id === appState.currentEnrolledGroupId);
      if (aEnrolled !== bEnrolled) return aEnrolled ? -1 : 1;
      return String(a.group_id || a.name).localeCompare(String(b.group_id || b.name));
    });

    bucket.forEach((g, idxInBucket) => {
      const dayIdx = Number(g.day);
      const isHovered = appState.highlightedGroupId === g.group_id;
      const isRank1 = g.rank === 1;
      const isEnrolled = Boolean(g.is_enrolled || g.group_id === appState.currentEnrolledGroupId);

      const startMins = timeToMinutes(g.start_time);
      const endMins = timeToMinutes(g.end_time);
      const topPx = ((startMins - START_HOUR * 60) / 60) * PX_PER_HOUR;
      const heightPx = Math.max(28, ((endMins - startMins) / 60) * PX_PER_HOUR);

      const el = document.createElement("div");
      const isFull = Boolean(g.is_full || (g.spots_free !== null && g.spots_free !== undefined && Number(g.spots_free) <= 0));
      let variant = "candidate-rank-alt";
      if (g.is_conflict) variant = "candidate-conflict";
      else if (isEnrolled) variant = "candidate-enrolled";
      else if (isFull) variant = "candidate-full";
      else if (isRank1) variant = "candidate-rank-1";

      el.className = `tt-event candidate-overlay ${variant}`;
      el.setAttribute("data-group-id", g.group_id);

      // If multiple groups of the same course share the exact same time slot, split width side-by-side with clear gap
      if (bucket.length > 1) {
        const gapPct = 1.5;
        const totalGaps = (bucket.length - 1) * gapPct;
        const widthPct = (96 - totalGaps) / bucket.length;
        const leftPct = 2 + idxInBucket * (widthPct + gapPct);
        el.style.left = `${leftPct}%`;
        el.style.right = "auto";
        el.style.width = `${widthPct}%`;
      } else {
        el.style.left = "4px";
        el.style.right = "4px";
        el.style.width = "auto";
      }

      el.style.top = `${topPx}px`;
      el.style.height = `${heightPx}px`;
      el.style.boxSizing = "border-box";
      el.style.cursor = g.is_conflict ? "not-allowed" : "pointer";

      if (isHovered) {
        el.style.transform = "translateY(-2px) scale(1.02)";
        el.style.zIndex = "45";
      }

      const total = Number(g.spots_total) || 40;
      const free = g.spots_free !== undefined && g.spots_free !== null ? Number(g.spots_free) : total;
      const taken = Math.max(0, total - free);
      const isLocked = Boolean(g.is_locked);

      let spotsInfo = "";
      if (isFull) {
        spotsInfo = `🔴 Ausgebucht (${total}/${total})`;
      } else if (isLocked) {
        spotsInfo = `🔒 Gesperrt (${total} Pl.)`;
      } else if (taken > 0) {
        spotsInfo = `🟢 ${free} frei (${taken}/${total})`;
      } else {
        spotsInfo = `🟢 ${total} frei`;
      }

      let badge = "";
      if (g.is_conflict) {
        badge = "❌ KONFLIKT";
      } else if (isEnrolled) {
        badge = "✅ BEREITS GEBUCHT";
      } else if (isFull) {
        badge = "🔴 AUSGEBUCHT";
      } else {
        const pinIcon = g.is_pinned ? "📌 " : (isRank1 ? "🏆 " : "⭐ ");
        badge = `${pinIcon}Wunsch #${g.rank}`;
      }

      let subAction = "";
      if (isEnrolled) {
        subAction = "✅ Deine Gruppe";
      } else if (isFull) {
        subAction = "🚫 Ausgebucht";
      } else if (isRank1) {
        subAction = "🏆 Wunsch #1";
      } else {
        subAction = "👆 Prio #1";
      }
      const subText = `${spotsInfo} · ${subAction}`;

      el.title = isEnrolled
        ? `✅ Deine aktuell gebuchte Übungsgruppe: ${g.name}. ${spotsInfo}. Klick zum Beibehalten oder Ändern.`
        : g.is_conflict
        ? "Zeitkonflikt mit deinem Stundenplan"
        : isFull
        ? `Gruppe ist voll belegt (${total}/${total} Plätze belegt). Klick zum Priorisieren als Wunsch #1 (für Sniper bei Nachrücker-Plätzen)!`
        : isRank1
        ? `Aktuell als Wunsch #1 (${g.name}) ausgewählt! (Klicke erneut zum Aufheben)`
        : `Klicke auf diesen Kasten, um '${g.name}' sofort als Wunsch #1 (Grün) für Schritt 3 auszuwählen!`;

      const displayName = bucket.length > 1 ? formatShortGroupName(g.name) : g.name;

      el.innerHTML = `
        <div class="tt-ev-title">${badge}: ${displayName}</div>
        <div class="tt-ev-time">${g.start_time}–${g.end_time} · ${subText}</div>
      `;

      if (!g.is_conflict) {
        el.addEventListener("click", (e) => {
          e.preventDefault();
          e.stopPropagation();
          pinGroupAsRank1(g.group_id);
        });
      }

      el.addEventListener("mouseenter", () => {
        appState.highlightedGroupId = g.group_id;
        el.style.zIndex = "45";
        el.style.transform = "translateY(-2px) scale(1.02)";
      });
      el.addEventListener("mouseleave", () => {
        appState.highlightedGroupId = null;
        if (!isHovered) {
          el.style.zIndex = isEnrolled ? "25" : (isRank1 ? "24" : "22");
          el.style.transform = "";
        }
      });

      dayCols[dayIdx].appendChild(el);
    });
  });
}

/* EVENT BINDINGS */
function bindUIEvents() {
  // Sync already enrolled groups from open browser tabs
  const syncEnrolledBtn = document.getElementById("btnSyncEnrolledGroups");
  if (syncEnrolledBtn) {
    syncEnrolledBtn.addEventListener("click", () => {
      syncEnrolledGroupsFromBrowser();
    });
  }

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

  // Launch CAU UNIBODY Chrome window (opens both lms.uni-kiel.de & elearn.informatik.uni-kiel.de or routes to selected course)
  document.getElementById("btnLaunchBrowser").addEventListener("click", async () => {
    const plat = document.getElementById("credPlatform")?.value || "unibody";
    const targetUrl = plat === "unibody" ? "unibody" : (appState.currentCourse ? appState.currentCourse.url : plat);
    const res = await apiPost("/api/browser/launch", {
      url: targetUrl,
      force_auto_login: true,
    });
    if (res.status) updateBrowserBadge(res.status);
    await pollTelemetry();
  });

  // CAU Account Vault handlers
  const formCreds = document.getElementById("formCredentials");
  const collapseBtn = document.getElementById("btnCollapseVault");
  const topAccountBtn = document.getElementById("btnToggleAccountPanel");
  const pwToggleBtn = document.getElementById("btnTogglePwVisibility");

  function toggleVaultCollapse(forceOpen = false) {
    if (!formCreds || !collapseBtn) return;
    if (forceOpen) {
      formCreds.classList.remove("collapsed");
    } else {
      formCreds.classList.toggle("collapsed");
    }
    const isCollapsed = formCreds.classList.contains("collapsed");
    collapseBtn.textContent = isCollapsed ? "⚙️ Bearbeiten / Ausklappen" : "🔽 Einklappen";
  }

  if (collapseBtn) {
    collapseBtn.addEventListener("click", () => toggleVaultCollapse(false));
  }
  if (topAccountBtn) {
    topAccountBtn.addEventListener("click", () => {
      toggleVaultCollapse(true);
      const card = document.getElementById("accountVaultCard");
      if (card) card.scrollIntoView({ behavior: "smooth", block: "start" });
      document.getElementById("credUsername")?.focus();
    });
  }
  if (pwToggleBtn) {
    pwToggleBtn.addEventListener("click", () => {
      const pwInput = document.getElementById("credPassword");
      if (!pwInput) return;
      pwInput.type = pwInput.type === "password" ? "text" : "password";
      pwToggleBtn.textContent = pwInput.type === "password" ? "👁️" : "🙈";
    });
  }

  async function saveAccountCredentials(launchBrowserNow = false) {
    const username = document.getElementById("credUsername").value.trim();
    const password = document.getElementById("credPassword").value;
    const default_platform = document.getElementById("credPlatform").value;
    const auto_fill = document.getElementById("credAutoFill").checked;
    const auto_submit = document.getElementById("credAutoSubmit").checked;
    const use_keychain = document.getElementById("credUseKeychain").checked;

    if (!username) {
      alert("Bitte gib deine CAU-Kennung (z. B. stu123456) ein!");
      return;
    }

    const res = await apiPost("/api/credentials/save", {
      username,
      password,
      default_platform,
      auto_fill,
      auto_submit,
      use_keychain,
      launch_browser: launchBrowserNow,
    });

    if (!res.ok) {
      alert(res.error || "Fehler beim Speichern der Login-Daten.");
      return;
    }

    appState.credentials = res.credentials;
    syncCredentialsUI(res.credentials, false);
    if (res.browser_status) updateBrowserBadge(res.browser_status);
    await pollTelemetry();
  }

  if (formCreds) {
    formCreds.addEventListener("submit", async (e) => {
      e.preventDefault();
      await saveAccountCredentials(false);
    });
  }

  const btnSaveAndLogin = document.getElementById("btnSaveAndAutoLogin");
  if (btnSaveAndLogin) {
    btnSaveAndLogin.addEventListener("click", async () => {
      await saveAccountCredentials(true);
    });
  }

  const btnClearCreds = document.getElementById("btnClearCreds");
  if (btnClearCreds) {
    btnClearCreds.addEventListener("click", async () => {
      const res = await apiPost("/api/credentials/clear", {});
      if (res.ok) {
        appState.credentials = res.credentials;
        syncCredentialsUI(res.credentials, false);
        document.getElementById("credPassword").value = "";
        if (res.browser_status) updateBrowserBadge(res.browser_status);
        await pollTelemetry();
      }
    });
  }

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

  // Enrollment success modal: "Im Wochenplan ansehen" button
  const btnNotifShowSchedule = document.getElementById("btnNotifShowSchedule");
  if (btnNotifShowSchedule) {
    btnNotifShowSchedule.addEventListener("click", () => {
      document.getElementById("modalEnrollmentSuccess").classList.add("hidden");
      const schedCard = document.querySelector(".calendar-card");
      if (schedCard) {
        schedCard.scrollIntoView({ behavior: "smooth", block: "start" });
        schedCard.style.boxShadow = "0 0 0 3px #10b981, 0 16px 40px rgba(16, 185, 129, 0.4)";
        schedCard.style.transition = "box-shadow 0.3s ease";
        setTimeout(() => {
          schedCard.style.boxShadow = "";
        }, 2400);
      }
    });
  }

  // Unenrollment success modal: "Wochenplan ansehen" button
  const btnNotifUnenrollSchedule = document.getElementById("btnNotifUnenrollSchedule");
  if (btnNotifUnenrollSchedule) {
    btnNotifUnenrollSchedule.addEventListener("click", () => {
      document.getElementById("modalUnenrollmentSuccess").classList.add("hidden");
      const schedCard = document.querySelector(".calendar-card");
      if (schedCard) {
        schedCard.scrollIntoView({ behavior: "smooth", block: "start" });
        schedCard.style.boxShadow = "0 0 0 3px #f59e0b, 0 16px 40px rgba(245, 158, 11, 0.4)";
        schedCard.style.transition = "box-shadow 0.3s ease";
        setTimeout(() => {
          schedCard.style.boxShadow = "";
        }, 2400);
      }
    });
  }

  // Enrollment locked modal: button handler
  const btnLockedArmCountdown = document.getElementById("btnLockedArmCountdown");
  if (btnLockedArmCountdown) {
    btnLockedArmCountdown.addEventListener("click", () => {
      document.getElementById("modalEnrollmentLocked").classList.add("hidden");
      const step3Card = document.querySelector(".left-panel");
      if (step3Card) {
        step3Card.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    });
  }

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

        // Show enrollment success notification modal if not already notified
        const notifKey = `notified_job_${latest.job_id}`;
        if (!sessionStorage.getItem(notifKey)) {
          sessionStorage.setItem(notifKey, "1");
          showEnrollmentSuccessModal(latest);
        }
      } else if (latest.status === "locked") {
        badge.className = "status-pill";
        badge.style.background = "linear-gradient(180deg, #ffe082 0%, #ffb300 100%)";
        badge.style.color = "#5c2e00";
        badge.textContent = `⏳ ${latest.result_message}`;

        // Show enrollment locked notification modal if not already notified
        const notifKey = `notified_job_${latest.job_id}`;
        if (!sessionStorage.getItem(notifKey)) {
          sessionStorage.setItem(notifKey, "1");
          showEnrollmentLockedModal(latest);
        }
      } else if (latest.status === "running" || latest.status === "armed") {
        badge.className = "status-pill";
        badge.style.background = "";
        badge.style.color = "";
        badge.textContent = `⚡ ${latest.result_message}`;
      } else if (latest.status === "failed") {
        badge.className = "status-pill";
        badge.style.background = "linear-gradient(180deg, #ffcdd2 0%, #ef5350 100%)";
        badge.style.color = "#491212";
        badge.textContent = `❌ ${latest.result_message}`;
      }
    }
  } catch (e) {
    // Ignore transient network errors
  }
}

function showEnrollmentLockedModal(job) {
  if (!job) return;
  const host = job.platform_host || (job.course_url ? new URL(job.course_url).host : "elearn.informatik.uni-kiel.de");

  // Platform pill
  const pillEl = document.getElementById("lockedPlatformPill");
  if (pillEl) {
    if (host.includes("elearn")) {
      pillEl.textContent = `⚡ Moodle (${host})`;
    } else {
      pillEl.textContent = `🏛️ OpenOlat (${host})`;
    }
  }

  // Course Title
  const courseObj = (appState.catalog || []).find(
    (c) => c.course_id.toLowerCase() === (job.course_id || "").toLowerCase()
  ) || appState.currentCourse;
  const titleEl = document.getElementById("lockedCourseTitle");
  if (titleEl) {
    const fullTitle = job.course_title || (courseObj ? courseObj.title : job.course_id);
    titleEl.textContent = `${fullTitle} (${job.course_id || ""})`;
  }

  // Lock Date Notice
  const dateEl = document.getElementById("lockedDateNotice");
  if (dateEl) {
    const dateText = job.open_date || "Freitag, 23. Oktober 2026, 14:00 Uhr";
    dateEl.innerHTML = `Freischaltung erst am: <strong>${dateText}</strong>`;
  }

  // Display Modal
  const modal = document.getElementById("modalEnrollmentLocked");
  if (modal) {
    modal.classList.remove("hidden");
  }

  // Play gentle attention chime
  playLockedNoticeChime();
}

function playLockedNoticeChime() {
  try {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return;
    const ctx = new AudioContextClass();
    if (ctx.state === "suspended") ctx.resume();
    const now = ctx.currentTime;

    // Note 1: F4 (349.23 Hz)
    const osc1 = ctx.createOscillator();
    const gain1 = ctx.createGain();
    osc1.type = "sine";
    osc1.frequency.setValueAtTime(349.23, now);
    gain1.gain.setValueAtTime(0, now);
    gain1.gain.linearRampToValueAtTime(0.20, now + 0.05);
    gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.50);
    osc1.connect(gain1);
    gain1.connect(ctx.destination);
    osc1.start(now);
    osc1.stop(now + 0.50);

    // Note 2: A4 (440.00 Hz)
    const osc2 = ctx.createOscillator();
    const gain2 = ctx.createGain();
    osc2.type = "sine";
    osc2.frequency.setValueAtTime(440.00, now + 0.15);
    gain2.gain.setValueAtTime(0, now + 0.15);
    gain2.gain.linearRampToValueAtTime(0.22, now + 0.20);
    gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.80);
    osc2.connect(gain2);
    gain2.connect(ctx.destination);
    osc2.start(now + 0.15);
    osc2.stop(now + 0.80);
  } catch (e) {
    console.debug("Web Audio chime could not play:", e);
  }
}

function showEnrollmentSuccessModal(job) {
  if (!job) return;
  const grp = job.enrolled_group || (job.priorities && job.priorities[0]) || {};
  const host = job.platform_host || (job.course_url ? new URL(job.course_url).host : "lms.uni-kiel.de");

  // Platform pill
  const pillEl = document.getElementById("notifPlatformPill");
  if (pillEl) {
    if (host.includes("elearn")) {
      pillEl.textContent = `⚡ Moodle / Elearn (${host})`;
    } else {
      pillEl.textContent = `🏛️ OpenOlat (${host})`;
    }
  }

  // Course Title
  const courseObj = (appState.catalog || []).find(
    (c) => c.course_id.toLowerCase() === (job.course_id || "").toLowerCase()
  ) || appState.currentCourse;
  const titleEl = document.getElementById("notifCourseTitle");
  if (titleEl) {
    const fullTitle = job.course_title || (courseObj ? courseObj.title : job.course_id);
    titleEl.textContent = fullTitle;
  }

  // Group Name & Rank
  const groupEl = document.getElementById("notifGroupName");
  if (groupEl) {
    const rankBadge = job.rank_won ? ` · 🥇 Wunsch-Rang #${job.rank_won}` : "";
    groupEl.textContent = `🎯 ${grp.name || "Übungsgruppe"}${rankBadge}`;
  }

  // Time & Day
  const timeEl = document.getElementById("notifTime");
  if (timeEl) {
    if (grp.day_name && grp.start_time) {
      timeEl.textContent = `${grp.day_name}, ${grp.start_time} – ${grp.end_time || ""} Uhr`;
    } else {
      timeEl.textContent = "Wöchentlicher Termin verbindlich gebucht";
    }
  }

  // Room
  const roomEl = document.getElementById("notifRoom");
  if (roomEl) {
    roomEl.textContent = grp.room || "Hörsaal / LMS";
  }

  // Platform Host
  const platEl = document.getElementById("notifPlatform");
  if (platEl) {
    platEl.textContent = host;
  }

  // Confirmation Token
  const tokenEl = document.getElementById("notifToken");
  if (tokenEl) {
    tokenEl.textContent = job.confirmation_token || `CONF-${(job.job_id || "OK").slice(-8).toUpperCase()}`;
  }

  // Display Modal
  const modal = document.getElementById("modalEnrollmentSuccess");
  if (modal) {
    modal.classList.remove("hidden");
  }

  // Play celebratory synthesized two-tone audio chime
  playSuccessChime();
}

function playSuccessChime() {
  try {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return;
    const ctx = new AudioContextClass();
    if (ctx.state === "suspended") {
      ctx.resume();
    }
    const now = ctx.currentTime;

    // Note 1: E5 (659.25 Hz)
    const osc1 = ctx.createOscillator();
    const gain1 = ctx.createGain();
    osc1.type = "sine";
    osc1.frequency.setValueAtTime(659.25, now);
    gain1.gain.setValueAtTime(0, now);
    gain1.gain.linearRampToValueAtTime(0.24, now + 0.04);
    gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.45);
    osc1.connect(gain1);
    gain1.connect(ctx.destination);
    osc1.start(now);
    osc1.stop(now + 0.45);

    // Note 2: B5 (987.77 Hz) slightly delayed
    const osc2 = ctx.createOscillator();
    const gain2 = ctx.createGain();
    osc2.type = "sine";
    osc2.frequency.setValueAtTime(987.77, now + 0.16);
    gain2.gain.setValueAtTime(0, now + 0.16);
    gain2.gain.linearRampToValueAtTime(0.28, now + 0.20);
    gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.85);
    osc2.connect(gain2);
    gain2.connect(ctx.destination);
    osc2.start(now + 0.16);
    osc2.stop(now + 0.85);
  } catch (e) {
    console.debug("Web Audio chime could not play:", e);
  }
}

function showUnenrollmentSuccessModal(course, group) {
  if (!course && !group) return;
  const grp = group || {};
  const host = course ? (course.platform_host || "lms.uni-kiel.de") : "lms.uni-kiel.de";

  const pillEl = document.getElementById("notifUnenrollPlatformPill");
  if (pillEl) {
    if (host.includes("elearn")) {
      pillEl.textContent = `⚡ Moodle / Elearn (${host})`;
    } else {
      pillEl.textContent = `🏛️ OpenOlat (${host})`;
    }
  }

  const titleEl = document.getElementById("notifUnenrollCourseTitle");
  if (titleEl) {
    titleEl.textContent = course ? (course.title || course.course_id) : "Modul";
  }

  const groupEl = document.getElementById("notifUnenrollGroupName");
  if (groupEl) {
    groupEl.textContent = grp.name ? `🚪 ${grp.name}` : "Übungsgruppe abgemeldet";
  }

  const timeEl = document.getElementById("notifUnenrollTime");
  if (timeEl) {
    if (grp.day_name && grp.start_time) {
      timeEl.textContent = `${grp.day_name}, ${grp.start_time} – ${grp.end_time || ""} Uhr`;
    } else {
      timeEl.textContent = "Zeitslot im Wochenplan wieder freigegeben";
    }
  }

  const roomEl = document.getElementById("notifUnenrollRoom");
  if (roomEl) {
    roomEl.textContent = grp.room || "Hörsaal / LMS";
  }

  const platEl = document.getElementById("notifUnenrollPlatform");
  if (platEl) {
    platEl.textContent = host;
  }

  const modal = document.getElementById("modalUnenrollmentSuccess");
  if (modal) {
    modal.classList.remove("hidden");
  }

  playUnenrollChime();
}

function playUnenrollChime() {
  try {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return;
    const ctx = new AudioContextClass();
    if (ctx.state === "suspended") {
      ctx.resume();
    }
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(587.33, now); // D5
    osc.frequency.exponentialRampToValueAtTime(392.00, now + 0.18); // G4 gentle down-tone
    gain.gain.setValueAtTime(0.16, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.38);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.38);
  } catch (e) {
    console.debug("Web Audio chime could not play:", e);
  }
}

function updateBrowserBadge(status) {
  if (!status) return;
  const badge = document.getElementById("ssoBadge");
  const text = document.getElementById("ssoStatusText");
  if (status.logged_in) {
    badge.className = "sso-badge connected";
    text.textContent = status.saved_username
      ? `CAU SSO: Verbunden (${status.saved_username})`
      : "CAU SSO: Verbunden (lms.uni-kiel.de)";
  } else if (status.browser_running) {
    badge.className = "sso-badge";
    text.textContent = status.has_credentials
      ? `Auto-Fill aktiv (${status.saved_username})`
      : "Chrome offen: Bitte im Fenster einloggen";
  } else {
    badge.className = "sso-badge";
    text.textContent = status.has_credentials
      ? `SSO bereit (${status.saved_username} gespeichert)`
      : "Shibboleth SSO: Bereit";
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
