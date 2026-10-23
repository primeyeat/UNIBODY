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

let themeToggleClickTimestamps = [];
let claireHeartInterval = null;

function checkClaireEasterEgg() {
  const now = Date.now();
  themeToggleClickTimestamps.push(now);
  // Keep clicks within the last 3.5 seconds
  themeToggleClickTimestamps = themeToggleClickTimestamps.filter((t) => now - t <= 3500);

  // Trigger when rapidly toggled 7 times
  if (themeToggleClickTimestamps.length >= 7) {
    themeToggleClickTimestamps = [];
    showClaireEasterEggModal();
  }
}

function showClaireEasterEggModal() {
  const modal = document.getElementById("modalClaireEasterEgg");
  if (!modal) return;
  modal.classList.remove("hidden");

  playClaireChime();
  launchClaireHearts();
}

function launchClaireHearts() {
  const container = document.getElementById("claireHeartsContainer");
  if (!container) return;
  container.innerHTML = "";

  const symbols = ["💖", "💕", "🌸", "✨", "💗", "🌷", "🎀", "🤍"];

  function spawnHeart() {
    if (!container) return;
    const el = document.createElement("span");
    el.className = "claire-particle";
    el.textContent = symbols[Math.floor(Math.random() * symbols.length)];
    el.style.left = Math.random() * 85 + 5 + "%";
    el.style.fontSize = Math.random() * 1.2 + 1.0 + "rem";
    el.style.animationDuration = Math.random() * 1.5 + 2.0 + "s";
    container.appendChild(el);
    setTimeout(() => {
      el.remove();
    }, 3200);
  }

  // Initial burst of floating hearts
  for (let i = 0; i < 16; i++) {
    setTimeout(spawnHeart, i * 100);
  }

  if (claireHeartInterval) clearInterval(claireHeartInterval);
  claireHeartInterval = setInterval(spawnHeart, 300);
}

function playClaireChime() {
  try {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return;
    const ctx = new AudioContextClass();
    if (ctx.state === "suspended") {
      ctx.resume();
    }
    const now = ctx.currentTime;
    // Music box arpeggio: F5, A5, C6, E6, G6, C7
    const notes = [
      { freq: 698.46, delay: 0.0 },   // F5
      { freq: 880.00, delay: 0.12 },  // A5
      { freq: 1046.50, delay: 0.24 }, // C6
      { freq: 1318.51, delay: 0.36 }, // E6
      { freq: 1567.98, delay: 0.48 }, // G6
      { freq: 2093.00, delay: 0.60 }, // C7
    ];

    notes.forEach((n) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.setValueAtTime(n.freq, now + n.delay);

      gain.gain.setValueAtTime(0.001, now + n.delay);
      gain.gain.linearRampToValueAtTime(0.18, now + n.delay + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.001, now + n.delay + 0.85);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now + n.delay);
      osc.stop(now + n.delay + 0.85);
    });
  } catch (e) {
    console.debug("Claire chime audio could not play:", e);
  }
}

const THEME_NAMES = {
  aero: "🫧 Frutiger Aero",
  cupertino: "🍏 Cupertino Minimal",
  botanical: "🌿 Botanischer Garten",
  vaporwave: "🌴 Vaporwave Sunset",
};

function applyDesignTheme(themeKey) {
  const valid = THEME_NAMES[themeKey] ? themeKey : "aero";
  document.body.dataset.theme = valid;
  localStorage.setItem("cau_design_theme", valid);

  const selectEl = document.getElementById("selectThemeStyle");
  if (selectEl && selectEl.value !== valid) {
    selectEl.value = valid;
  }
  const badgeEl = document.getElementById("currentThemeBadge");
  if (badgeEl) {
    badgeEl.textContent = THEME_NAMES[valid] || "🫧 Frutiger Aero";
  }
}

function updateThemeToggleButtons(isDark) {
  const label = isDark ? "☀️ Daylight Mode" : "🌙 Dark Mode";
  const btnTop = document.getElementById("btnToggleDarkMode");
  if (btnTop) btnTop.textContent = label;
  const btnSettings = document.getElementById("btnToggleDarkModeInSettings");
  if (btnSettings) btnSettings.textContent = label;
}

function initThemeMode() {
  // 1. Dark / Daylight Mode
  const savedMode = localStorage.getItem("cau_dorfic_theme") || "light";
  const isDark = savedMode === "dark";
  if (isDark) {
    document.body.classList.add("dark-mode");
  }
  updateThemeToggleButtons(isDark);

  const toggleHandler = () => {
    const darkNow = document.body.classList.toggle("dark-mode");
    localStorage.setItem("cau_dorfic_theme", darkNow ? "dark" : "light");
    updateThemeToggleButtons(darkNow);
    checkClaireEasterEgg();
  };

  const btnTop = document.getElementById("btnToggleDarkMode");
  if (btnTop) btnTop.addEventListener("click", toggleHandler);

  const btnSettings = document.getElementById("btnToggleDarkModeInSettings");
  if (btnSettings) btnSettings.addEventListener("click", toggleHandler);

  // 2. Design-Theme (aero, cupertino, botanical, vaporwave)
  const savedDesign = localStorage.getItem("cau_design_theme") || "aero";
  applyDesignTheme(savedDesign);

  const selectEl = document.getElementById("selectThemeStyle");
  if (selectEl) {
    selectEl.addEventListener("change", (e) => {
      applyDesignTheme(e.target.value);
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
  renderFutureCalendar();
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
  const modeSel = document.getElementById("enrollModeSelect");
  if (modeSel) modeSel.value = "direct";

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
        force: false,
        launch_browser: true,
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

  if (appState.rankedGroups.length === 0) {
    if (enrolledBanner) enrolledBanner.classList.add("hidden");
    const isLectureOnly = (appState.currentCourse.enrollment_mode === "lecture_only") || (!appState.currentCourse.groups || appState.currentCourse.groups.length === 0);
    container.innerHTML = `
      <div style="padding:24px;text-align:center;background:var(--aero-glass-bg);border:1px solid var(--aero-glass-border);border-radius:var(--radius-lg);margin-top:8px;">
        <div style="font-size:2rem;margin-bottom:8px;">📚</div>
        <div style="font-size:1.05rem;font-weight:800;color:var(--aero-ink);margin-bottom:6px;">
          ${isLectureOnly ? "Reine Vorlesung (Keine Übungsgruppen)" : "Keine Übungsgruppen vorhanden"}
        </div>
        <div style="font-size:0.85rem;color:var(--aero-ink-muted);max-width:440px;margin:0 auto;line-height:1.45;">
          ${isLectureOnly ? "Dieses Modul (z. B. Informatikrecht) besteht ausschließlich aus einer Vorlesung. Eine gesonderte Übungs-Einschreibung ist nicht erforderlich – die Belegung ist frei." : "Zu diesem Modul wurden im UnivIS keine Übungsgruppen gefunden."}
        </div>
      </div>
    `;
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
                : `💡 <strong>Upgrade möglich:</strong> <strong>${rank1Grp ? rank1Grp.name : "Eine andere Gruppe"}</strong> hätte einen höheren Score (${rank1Grp ? rank1Grp.display_score : ""}% statt ${enrolledGrp.display_score}%). Du kannst dich per Klick direkt in die bessere Gruppe umtragen!`
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
        ${
          isEnrolled
            ? `<button type="button" class="btn-mark-enrolled" style="${enrollToggleBtnStyle}" title="Klicke hier, um dich aus dieser Übungsgruppe live im LMS auszutragen">
                ✕ Aus Gruppe austragen
               </button>`
            : `<div style="display:inline-flex; gap:6px; margin-top:6px; flex-wrap:wrap; justify-content:flex-end;">
                ${
                  !g.is_conflict
                    ? `<button type="button" class="btn-live-enroll-group" style="background:linear-gradient(135deg, #0ea5e9 0%, #2563eb 100%); color:#fff; border:none; font-weight:800; padding:4px 10px; border-radius:999px; font-size:0.71rem; cursor:pointer; display:inline-flex; align-items:center; gap:4px; box-shadow:0 2px 6px rgba(14,165,233,0.35);" title="Jetzt direkt im Browser einschreiben">
                        ⚡ Live einschreiben
                       </button>`
                    : ""
                }
                <button type="button" class="btn-mark-enrolled" style="${enrollToggleBtnStyle}" title="Bereits extern manuell belegt? Hier für deinen Wochenplan vormerken">
                  ☑️ Schon gebucht?
                </button>
               </div>`
        }
      </div>
    `;

    const liveEnrollBtn = card.querySelector(".btn-live-enroll-group");
    if (liveEnrollBtn) {
      liveEnrollBtn.addEventListener("click", async (e) => {
        e.stopPropagation();
        await pinGroupAsRank1(g.group_id);
        triggerEnrollment("immediate", 0);
      });
    }

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
  const now = new Date();
  const todayWeekday = (now.getDay() + 6) % 7; // 0=Mo, 1=Di, 2=Mi, 3=Do, 4=Fr, 5=Sa, 6=So
  for (let d = 0; d < 5; d++) {
    const isToday = (d === todayWeekday);
    const col = document.createElement("div");
    col.className = `tt-day-col ${freeSet.has(d) ? "free-day-highlight" : ""} ${isToday ? "tt-is-today-col" : ""}`;
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

      let turnusLabel = "🔄 Jede Woche";
      let turnusCls = "turnus-all";
      if (ev.week_type === "A") {
        turnusLabel = "🅰️ Woche A";
        turnusCls = "turnus-a";
      } else if (ev.week_type === "B") {
        turnusLabel = "🅱️ Woche B";
        turnusCls = "turnus-b";
      }

      el.innerHTML = `
        <div class="tt-ev-title">${isSelectedCourse ? "🎯 " : ""}${ev.title}</div>
        <div class="tt-ev-time">${ev.start_time}–${ev.end_time} ${ev.room ? `· ${ev.room}` : ""}</div>
        <div style="display:flex;align-items:center;gap:4px;margin-top:3px;">
          <button type="button" class="tt-turnus-pill ${turnusCls}" title="Klick = Turnus ändern (Jede Woche / Woche A / Woche B)">
            ${turnusLabel}
          </button>
        </div>
      `;

      el.querySelector(".tt-turnus-pill")?.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        openTurnusSelectModal(ev);
      });

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
        ? `Gruppe ist voll belegt (${total}/${total} Plätze belegt). Klick zum Priorisieren als Wunsch #1!`
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

  if (typeof updateTimetableTimeIndicator === "function") {
    updateTimetableTimeIndicator();
  }

  if (typeof renderFutureCalendar === "function") {
    renderFutureCalendar();
  }
}

/* ==========================================================================
   APPLE CALENDAR STYLE: 8-WEEKS FUTURE CALENDAR (ZUKUNFTSKALENDER)
   ========================================================================== */

const MONTH_NAMES_DE = [
  "Januar", "Februar", "März", "April", "Mai", "Juni",
  "Juli", "August", "September", "Oktober", "November", "Dezember"
];
const DAY_NAMES_FULL_DE = [
  "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"
];
const DAY_NAMES_SHORT_DE = ["MO", "DI", "MI", "DO", "FR"];

const FUTURE_CAL_START_HOUR = 6;
const FUTURE_CAL_END_HOUR = 22; // 06:00 to 22:00 (16 Stunden)
const FUTURE_CAL_PX_PER_HOUR = 60; // 60px pro Stunde = 1px pro Minute

const futureCalState = {
  currentWeekOffset: 0, // 0 to 7
  viewMode: "week",      // "week" or "agenda"
  baseMonday: new Date(2026, 9, 19), // 19. Oktober 2026 (Semesterstart KW 43)
  todayRef: new Date(2026, 9, 23)    // 23. Oktober 2026
};

function generate8WeeksData() {
  const weeks = [];
  const KW_START = 43;
  for (let i = 0; i < 8; i++) {
    const monday = new Date(futureCalState.baseMonday);
    monday.setDate(futureCalState.baseMonday.getDate() + i * 7);

    const friday = new Date(monday);
    friday.setDate(monday.getDate() + 4);

    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);

    const kw = KW_START + i;
    const weekType = (kw % 2 === 1) ? "A" : "B";

    const days = [];
    for (let d = 0; d < 5; d++) {
      const dDate = new Date(monday);
      dDate.setDate(monday.getDate() + d);
      const isToday = (
        dDate.getFullYear() === futureCalState.todayRef.getFullYear() &&
        dDate.getMonth() === futureCalState.todayRef.getMonth() &&
        dDate.getDate() === futureCalState.todayRef.getDate()
      );
      days.push({
        dayIndex: d,
        dayName: DAY_NAMES_FULL_DE[d],
        dayShort: DAY_NAMES_SHORT_DE[d],
        date: dDate,
        dayNum: dDate.getDate(),
        monthNum: dDate.getMonth() + 1,
        monthName: MONTH_NAMES_DE[dDate.getMonth()],
        year: dDate.getFullYear(),
        isToday: isToday
      });
    }

    const hasToday = days.some((d) => d.isToday);

    weeks.push({
      index: i,
      kw: kw,
      weekType: weekType,
      monday: monday,
      friday: friday,
      sunday: sunday,
      days: days,
      isCurrentWeek: i === 0,
      hasToday: hasToday
    });
  }
  return weeks;
}

function getCourseEventTheme(ev) {
  const title = (ev.title || "").toLowerCase();
  const cId = (ev.course_id || "").toLowerCase();
  if (ev.type === "enrolled_exercise") return "ev-theme-green";
  if (cId.includes("math") || title.includes("mathematik")) return "ev-theme-purple";
  if (cId.includes("einf") || title.includes("informatik")) {
    if (cId.includes("recht") || title.includes("recht")) return "ev-theme-teal";
    if (cId.includes("winf") || title.includes("wirtschaftsinformatik")) return "ev-theme-green";
    return "ev-theme-blue";
  }
  if (cId.includes("bwl") || title.includes("bwl")) return "ev-theme-orange";
  return "ev-theme-blue";
}

function isEventInWeek(ev, weekType) {
  if (ev.enabled === false) return false;
  if (!ev.week_type || ev.week_type === "all" || ev.week_type === "weekly") return true;
  return String(ev.week_type).toUpperCase() === String(weekType).toUpperCase();
}

function renderFutureCalendar() {
  const weeks = generate8WeeksData();
  const currentWeek = weeks[futureCalState.currentWeekOffset] || weeks[0];

  // 1. Update Month Title and Week Badge
  const titleEl = document.getElementById("futureCalMonthTitle");
  const badgeEl = document.getElementById("futureCalWeekBadge");
  if (titleEl) {
    const mStart = MONTH_NAMES_DE[currentWeek.monday.getMonth()];
    const mEnd = MONTH_NAMES_DE[currentWeek.friday.getMonth()];
    const yr = currentWeek.monday.getFullYear();
    titleEl.textContent = mStart === mEnd ? `${mStart} ${yr}` : `${mStart} – ${mEnd} ${yr}`;
  }
  if (badgeEl) {
    badgeEl.className = `aero-badge week-badge-${currentWeek.weekType.toLowerCase()}`;
    badgeEl.textContent = `KW ${currentWeek.kw} · Woche ${currentWeek.weekType}${currentWeek.isCurrentWeek ? " (Aktuell)" : ""}`;
  }

  // 2. Render 8-Week Quick Ribbon
  const ribbonEl = document.getElementById("futureCalRibbon");
  if (ribbonEl) {
    ribbonEl.innerHTML = "";
    weeks.forEach((w) => {
      const pill = document.createElement("button");
      pill.type = "button";
      pill.className = `ribbon-pill ${w.index === futureCalState.currentWeekOffset ? "active" : ""} ${w.hasToday ? "is-today-week" : ""}`;

      const m1 = String(w.monday.getDate()).padStart(2, "0") + "." + String(w.monday.getMonth() + 1).padStart(2, "0");
      const m2 = String(w.friday.getDate()).padStart(2, "0") + "." + String(w.friday.getMonth() + 1).padStart(2, "0");

      pill.innerHTML = `
        <span>KW ${w.kw}</span>
        <span style="opacity:0.75;font-weight:600;">${m1}–${m2}</span>
        <span class="ribbon-week-type">Woche ${w.weekType}</span>
      `;
      pill.addEventListener("click", () => {
        futureCalState.currentWeekOffset = w.index;
        renderFutureCalendar();
      });
      ribbonEl.appendChild(pill);
    });
  }

  // 3. Render View Toggle States
  const weekViewEl = document.getElementById("futureCalWeekContainer");
  const agendaViewEl = document.getElementById("futureCalAgendaContainer");
  const btnWeek = document.getElementById("btnViewWeek");
  const btnAgenda = document.getElementById("btnViewAgenda");

  if (futureCalState.viewMode === "agenda") {
    if (weekViewEl) weekViewEl.classList.add("hidden");
    if (agendaViewEl) agendaViewEl.classList.remove("hidden");
    btnWeek?.classList.remove("active");
    btnAgenda?.classList.add("active");
    renderFutureCalAgenda(weeks);
  } else {
    if (agendaViewEl) agendaViewEl.classList.add("hidden");
    if (weekViewEl) weekViewEl.classList.remove("hidden");
    btnWeek?.classList.add("active");
    btnAgenda?.classList.remove("active");
    renderFutureCalWeek(currentWeek);
  }
}

function renderFutureCalWeek(currentWeek) {
  const headersEl = document.getElementById("futureCalDayHeaders");
  const gutterEl = document.getElementById("futureCalTimeGutter");
  const colsContainer = document.getElementById("futureCalColumns");
  if (!headersEl || !gutterEl || !colsContainer) return;

  // Day Headers
  headersEl.innerHTML = "";
  const corner = document.createElement("div");
  corner.className = "future-cal-header-corner";
  corner.textContent = "Zeit";
  headersEl.appendChild(corner);

  currentWeek.days.forEach((d) => {
    const cell = document.createElement("div");
    cell.className = `future-cal-day-header-cell ${d.isToday ? "is-today" : ""}`;
    cell.innerHTML = `
      <div class="cal-day-name">${d.dayShort}</div>
      <div class="cal-day-bubble">${d.dayNum}</div>
    `;
    headersEl.appendChild(cell);
  });

  // Time Gutter (06:00 to 22:00)
  gutterEl.innerHTML = "";
  for (let hr = FUTURE_CAL_START_HOUR; hr <= FUTURE_CAL_END_HOUR; hr++) {
    const slot = document.createElement("div");
    slot.className = "future-cal-time-cell";
    slot.textContent = `${String(hr).padStart(2, "0")}:00`;
    gutterEl.appendChild(slot);
  }

  // 5 Day Columns
  colsContainer.innerHTML = "";
  const dayColEls = [];
  const totalGridHeight = (FUTURE_CAL_END_HOUR - FUTURE_CAL_START_HOUR) * FUTURE_CAL_PX_PER_HOUR;
  currentWeek.days.forEach((d) => {
    const col = document.createElement("div");
    col.className = `future-cal-col ${d.isToday ? "is-today-col" : ""}`;
    col.style.height = `${totalGridHeight}px`;
    col.dataset.dayIndex = d.dayIndex;
    colsContainer.appendChild(col);
    dayColEls.push(col);
  });

  // Filter events that happen in this week (respecting weekType A/B and enabled state)
  const activeEvents = appState.schedule.filter((ev) => isEventInWeek(ev, currentWeek.weekType));

  // Bucket events by day and time to avoid overlaps
  const buckets = {};
  activeEvents.forEach((ev) => {
    const dIdx = Number(ev.day);
    if (dIdx < 0 || dIdx > 4) return;
    const key = `${dIdx}-${ev.start_time}-${ev.end_time}`;
    if (!buckets[key]) buckets[key] = [];
    buckets[key].push(ev);
  });

  Object.values(buckets).forEach((bucket) => {
    bucket.sort((a, b) => String(a.id).localeCompare(String(b.id)));
    bucket.forEach((ev, idxInBucket) => {
      const dIdx = Number(ev.day);
      const targetCol = dayColEls[dIdx];
      if (!targetCol) return;

      const dayObj = currentWeek.days[dIdx];
      const startMins = timeToMinutes(ev.start_time);
      const endMins = timeToMinutes(ev.end_time);
      const topPx = ((startMins - FUTURE_CAL_START_HOUR * 60) / 60) * FUTURE_CAL_PX_PER_HOUR;
      const heightPx = Math.max(34, ((endMins - startMins) / 60) * FUTURE_CAL_PX_PER_HOUR);

      const card = document.createElement("div");
      const themeClass = getCourseEventTheme(ev);
      card.className = `cal-event-card ${themeClass}`;
      card.style.top = `${topPx}px`;
      card.style.height = `${heightPx}px`;

      if (bucket.length > 1) {
        const gapPct = 2;
        const totalGaps = (bucket.length - 1) * gapPct;
        const widthPct = (96 - totalGaps) / bucket.length;
        const leftPct = 2 + idxInBucket * (widthPct + gapPct);
        card.style.left = `${leftPct}%`;
        card.style.right = "auto";
        card.style.width = `${widthPct}%`;
      } else {
        card.style.left = "4px";
        card.style.right = "4px";
        card.style.width = "auto";
      }

      const isTurnus = Boolean(ev.week_type);
      const badgeText = isTurnus
        ? `Woche ${ev.week_type}`
        : (ev.type === "enrolled_exercise" ? "Übung" : "VL");

      card.innerHTML = `
        <div class="cal-ev-time">${ev.start_time} – ${ev.end_time}</div>
        <div class="cal-ev-title" title="${ev.title}">${ev.title}</div>
        <div class="cal-ev-room" title="${ev.room || 'Kein Raum'}">📍 ${ev.room || 'Online / Hörsaal'}</div>
        <span class="cal-ev-badge">${badgeText}</span>
      `;

      card.addEventListener("click", (e) => {
        e.stopPropagation();
        openEventDetailModal(ev, dayObj);
      });

      targetCol.appendChild(card);
    });
  });

  // Render / Update the live time indicator line on today's column (Apple Calendar style)
  updateFutureCalTimeIndicator();
}

/**
 * LIVE TIME INDICATOR UPDATER (Apple Calendar Style)
 * Calculates the exact pixel position based on the real computer clock (new Date()).
 * Moves down continuously as minutes and seconds tick by.
 */
function updateFutureCalTimeIndicator() {
  const container = document.getElementById("futureCalWeekContainer");
  if (!container || container.classList.contains("hidden")) return;

  const todayCol = container.querySelector(".future-cal-col.is-today-col");
  if (!todayCol) {
    const existing = container.querySelector(".future-cal-now-line");
    if (existing) existing.remove();
    return;
  }

  const now = new Date();
  const curHour = now.getHours();
  const curMins = now.getMinutes();
  const curSecs = now.getSeconds();

  const totalMins = curHour * 60 + curMins + curSecs / 60;
  const startMins = FUTURE_CAL_START_HOUR * 60; // 06:00 = 360 Min
  const totalGridHeight = (FUTURE_CAL_END_HOUR - FUTURE_CAL_START_HOUR) * FUTURE_CAL_PX_PER_HOUR;

  const topPx = ((totalMins - startMins) / 60) * FUTURE_CAL_PX_PER_HOUR;

  let line = todayCol.querySelector(".future-cal-now-line");

  // If outside visible hours (e.g. before 06:00 or after 22:00)
  if (topPx < 0 || topPx > totalGridHeight) {
    if (line) line.style.display = "none";
    return;
  }

  if (!line) {
    line = document.createElement("div");
    line.className = "future-cal-now-line";
    line.innerHTML = `
      <div class="future-cal-now-dot"></div>
      <div class="future-cal-now-time-tag"></div>
    `;
    todayCol.appendChild(line);
  }

  line.style.display = "block";
  line.style.top = `${topPx}px`;

  const timeStr = `${String(curHour).padStart(2, "0")}:${String(curMins).padStart(2, "0")}`;
  const tag = line.querySelector(".future-cal-now-time-tag");
  if (tag) tag.textContent = timeStr;
  line.title = `Aktuelle Uhrzeit: ${timeStr}:${String(curSecs).padStart(2, "0")} Uhr (Live synchronisiert)`;
}

/**
 * LIVE TIME INDICATOR FOR TIMETABLE (Stundenplan & Kurse)
 */
function updateTimetableTimeIndicator() {
  const container = document.getElementById("timetableContainer");
  if (!container) return;

  const todayCol = container.querySelector(".tt-day-col.tt-is-today-col");
  if (!todayCol) {
    const existing = container.querySelector(".tt-now-line");
    if (existing) existing.remove();
    return;
  }

  const now = new Date();
  const curHour = now.getHours();
  const curMins = now.getMinutes();
  const curSecs = now.getSeconds();

  const totalMins = curHour * 60 + curMins + curSecs / 60;
  const startMins = START_HOUR * 60; // 8 * 60 = 480
  const totalGridHeight = (END_HOUR - START_HOUR) * PX_PER_HOUR; // (19 - 8) * 44 = 484px

  const topPx = ((totalMins - startMins) / 60) * PX_PER_HOUR;

  let line = todayCol.querySelector(".tt-now-line");

  if (topPx < 0 || topPx > totalGridHeight) {
    if (line) line.style.display = "none";
    return;
  }

  if (!line) {
    line = document.createElement("div");
    line.className = "tt-now-line";
    line.innerHTML = `
      <div class="tt-now-dot"></div>
      <div class="tt-now-time-tag"></div>
    `;
    todayCol.appendChild(line);
  }

  line.style.display = "block";
  line.style.top = `${topPx}px`;

  const timeStr = `${String(curHour).padStart(2, "0")}:${String(curMins).padStart(2, "0")}`;
  const tag = line.querySelector(".tt-now-time-tag");
  if (tag) tag.textContent = timeStr;
  line.title = `Aktuelle Uhrzeit: ${timeStr} Uhr (Live synchronisiert)`;
}

/**
 * Smoothly scrolls calendar into view when user opens week view or clicks "Heute"
 */
function scrollFutureCalToCurrentTime(smooth = false) {
  setTimeout(() => {
    const line = document.querySelector(".future-cal-now-line");
    if (line && line.style.display !== "none") {
      line.scrollIntoView({ behavior: smooth ? "smooth" : "auto", block: "center" });
    }
  }, 100);
}

function renderFutureCalAgenda(weeks) {
  const container = document.getElementById("futureCalAgendaList");
  if (!container) return;
  container.innerHTML = "";

  weeks.forEach((w) => {
    const weekBlock = document.createElement("div");
    weekBlock.className = "agenda-week-block";

    const dStart = `${w.monday.getDate()}. ${MONTH_NAMES_DE[w.monday.getMonth()]}`;
    const dEnd = `${w.friday.getDate()}. ${MONTH_NAMES_DE[w.friday.getMonth()]} ${w.friday.getFullYear()}`;

    weekBlock.innerHTML = `
      <div class="agenda-week-header">
        <div class="agenda-week-title">
          <span>📅 KW ${w.kw} (${dStart} – ${dEnd})</span>
          <span class="aero-badge week-badge-${w.weekType.toLowerCase()}">Woche ${w.weekType}${w.isCurrentWeek ? " · Aktuell" : ""}</span>
        </div>
      </div>
      <div class="agenda-days-list" id="agendaWeekDays_${w.kw}"></div>
    `;

    const daysList = weekBlock.querySelector(`#agendaWeekDays_${w.kw}`);
    const activeEvents = appState.schedule.filter((ev) => isEventInWeek(ev, w.weekType));

    w.days.forEach((dayObj) => {
      const dayEvs = activeEvents
        .filter((ev) => Number(ev.day) === dayObj.dayIndex)
        .sort((a, b) => timeToMinutes(a.start_time) - timeToMinutes(b.start_time));

      if (dayEvs.length === 0) return;

      const dayGroup = document.createElement("div");
      dayGroup.className = "agenda-day-group";

      dayGroup.innerHTML = `
        <div class="agenda-day-date ${dayObj.isToday ? "is-today" : ""}">
          <div>${dayObj.dayName}</div>
          <div style="font-size:1.15rem;font-weight:900;">${dayObj.dayNum}. ${dayObj.monthName}</div>
          ${dayObj.isToday ? '<span class="aero-badge" style="background:#ff3b30;color:#fff;margin-top:4px;">HEUTE</span>' : ""}
        </div>
        <div class="agenda-events-col"></div>
      `;

      const evsCol = dayGroup.querySelector(".agenda-events-col");
      dayEvs.forEach((ev) => {
        const row = document.createElement("div");
        const theme = getCourseEventTheme(ev);
        row.className = `agenda-event-row ${theme}`;
        row.innerHTML = `
          <span class="agenda-time-pill">${ev.start_time} – ${ev.end_time}</span>
          <div class="agenda-info">
            <div class="agenda-title">${ev.title}</div>
            <div class="agenda-sub">
              <span>📍 ${ev.room || "Online / Hörsaal"}</span>
              ${ev.week_type ? `<span>· 🔄 Turnus: Woche ${ev.week_type}</span>` : ""}
            </div>
          </div>
          <span class="cal-ev-badge" style="margin-left:auto;">${ev.week_type ? `Woche ${ev.week_type}` : (ev.type === "enrolled_exercise" ? "Übung" : "VL")}</span>
        `;
        row.addEventListener("click", () => {
          openEventDetailModal(ev, dayObj);
        });
        evsCol.appendChild(row);
      });

      daysList.appendChild(dayGroup);
    });

    container.appendChild(weekBlock);
  });
}

/**
 * CAU KIEL CAMPUS LOCATION RESOLVER
 * Maps CAU Kiel building and room abbreviations (OS75, CAP3, LMS6, HHP6, OHP5, LMS2, LMS4, LMS8, WSP3, Audimax, etc.)
 * to their exact building names, street addresses, campus zones, and precise GPS coordinates.
 */
const CAU_CAMPUS_LOCATIONS = [
  {
    id: "OS75",
    regex: /\b(os\s*75|olshausenstr(?:a\u00dfe)?\.?\s*75)\b/i,
    code: "OS 75",
    name: "Hörsaalgebäude OS 75",
    address: "Olshausenstraße 75, 24118 Kiel",
    area: "Campus Nord (Bremerskamp)",
    lat: 54.345406,
    lon: 10.105659,
  },
  {
    id: "CAP3",
    regex: /\b(cap\s*3|christian-albrechts-platz\s*3|murmann)\b/i,
    code: "CAP 3",
    name: "Hörsaalgebäude CAP 3",
    address: "Christian-Albrechts-Platz 3, 24118 Kiel",
    area: "Campus Mitte (Hauptcampus)",
    lat: 54.338464,
    lon: 10.121958,
  },
  {
    id: "CAP2",
    regex: /\b(cap\s*2|audimax|frederik-paulsen|paulsen)\b/i,
    code: "CAP 2 (Audimax)",
    name: "Audimax (Auditorium Maximum)",
    address: "Christian-Albrechts-Platz 2, 24118 Kiel",
    area: "Campus Mitte (Hauptcampus)",
    lat: 54.338236,
    lon: 10.123757,
  },
  {
    id: "CAP4",
    regex: /\b(cap\s*4|christian-albrechts-platz\s*4)\b/i,
    code: "CAP 4",
    name: "Universitäts-Hochhaus CAP 4",
    address: "Christian-Albrechts-Platz 4, 24118 Kiel",
    area: "Campus Mitte",
    lat: 54.338920,
    lon: 10.121980,
  },
  {
    id: "LMS8",
    regex: /\b(lms\s*8|ludewig-meyn-str(?:a\u00dfe)?\.?\s*8|cip|informatik)\b/i,
    code: "LMS 8",
    name: "Institut für Informatik LMS 8",
    address: "Ludewig-Meyn-Straße 8, 24118 Kiel",
    area: "Campus West (Informatik)",
    lat: 54.337512,
    lon: 10.121552,
  },
  {
    id: "LMS6",
    regex: /\b(lms\s*6|ludewig-meyn-str(?:a\u00dfe)?\.?\s*6)\b/i,
    code: "LMS 6",
    name: "Geowissenschaften LMS 6",
    address: "Ludewig-Meyn-Straße 6, 24118 Kiel",
    area: "Campus West",
    lat: 54.337680,
    lon: 10.121570,
  },
  {
    id: "LMS4",
    regex: /\b(lms\s*4|ludewig-meyn-str(?:a\u00dfe)?\.?\s*4)\b/i,
    code: "LMS 4",
    name: "Mathematik & Informatik LMS 4",
    address: "Ludewig-Meyn-Straße 4, 24118 Kiel",
    area: "Campus West",
    lat: 54.337850,
    lon: 10.121600,
  },
  {
    id: "LMS2",
    regex: /\b(lms\s*2|ludewig-meyn-str(?:a\u00dfe)?\.?\s*2)\b/i,
    code: "LMS 2",
    name: "Geowissenschaften LMS 2",
    address: "Ludewig-Meyn-Straße 2, 24118 Kiel",
    area: "Campus West",
    lat: 54.337997,
    lon: 10.121653,
  },
  {
    id: "LMS11",
    regex: /\b(lms\s*11a?|ludewig-meyn-str(?:a\u00dfe)?\.?\s*11a?)\b/i,
    code: "LMS 11a",
    name: "Biologie- & Agrarwissenschaften LMS 11a",
    address: "Ludewig-Meyn-Straße 11a, 24118 Kiel",
    area: "Campus West",
    lat: 54.336900,
    lon: 10.122100,
  },
  {
    id: "HHP6",
    regex: /\b(hhp\s*6|heinrich-hecht(?:-platz)?(?:\s*6)?)\b/i,
    code: "HHP 6",
    name: "Mathematik-Institut & Physikzentrum (HHP 6)",
    address: "Heinrich-Hecht-Platz 6, 24118 Kiel",
    area: "Campus Nordost (Physik & Mathematik)",
    lat: 54.341271,
    lon: 10.124403,
  },
  {
    id: "OHP5",
    regex: /\b(ohp\s*5|otto-hahn(?:-platz)?(?:\s*5)?|chemie\s*ii)\b/i,
    code: "OHP 5",
    name: "Chemie II Institut (Otto-Hahn-Platz 5)",
    address: "Otto-Hahn-Platz 5, 24118 Kiel",
    area: "Campus Ost",
    lat: 54.339832,
    lon: 10.126442,
  },
  {
    id: "OH14",
    regex: /\b(oh\s*14|os\s*40|olshausenstr(?:a\u00dfe)?\.?\s*40|chemie\s*i)\b/i,
    code: "OS 40 / OH 14",
    name: "Chemiezentrum & Geozentrum",
    address: "Olshausenstraße 40, 24118 Kiel",
    area: "Campus Nordwest",
    lat: 54.339409,
    lon: 10.121270,
  },
  {
    id: "WSP3",
    regex: /\b(wsp\s*3|wilhelm-seelig(?:-platz)?(?:\s*3)?)\b/i,
    code: "WSP 3",
    name: "Seminarräume Wilhelm-Seelig-Platz 3",
    address: "Wilhelm-Seelig-Platz 3, 24118 Kiel",
    area: "Campus Nord (WiSo)",
    lat: 54.339550,
    lon: 10.123500,
  },
  {
    id: "WSP7",
    regex: /\b(wsp\s*7|wilhelm-seelig(?:-platz)?(?:\s*7)?|wiso)\b/i,
    code: "WSP 7",
    name: "Wirtschafts- & Sozialwissenschaften (WiSo)",
    address: "Wilhelm-Seelig-Platz 7, 24118 Kiel",
    area: "Campus Nord (WiSo-Hochhaus)",
    lat: 54.339718,
    lon: 10.123655,
  },
  {
    id: "MENSA1",
    regex: /\b(mensa\s*1|mensa\s*i|westring\s*385)\b/i,
    code: "Mensa I",
    name: "Mensa I & AStA",
    address: "Westring 385, 24118 Kiel",
    area: "Campus Mitte",
    lat: 54.337469,
    lon: 10.122759,
  },
  {
    id: "MENSA2",
    regex: /\b(mensa\s*2|mensa\s*ii|leibnizstr(?:a\u00dfe)?\.?\s*14)\b/i,
    code: "Mensa II",
    name: "Mensa II (Campus Nord)",
    address: "Leibnizstraße 14, 24118 Kiel",
    area: "Campus Nord",
    lat: 54.344400,
    lon: 10.118600,
  },
  {
    id: "UB",
    regex: /\b(universit\u00e4tsbibliothek|leibnizstr(?:a\u00dfe)?\.?\s*9)\b/i,
    code: "UB",
    name: "Universitätsbibliothek Kiel",
    address: "Leibnizstraße 9, 24118 Kiel",
    area: "Campus Mitte",
    lat: 54.339000,
    lon: 10.121000,
  },
  {
    id: "SPORT",
    regex: /\b(sportforum|olshausenstr(?:a\u00dfe)?\.?\s*7[04])\b/i,
    code: "Sportforum",
    name: "Universitäts-Sportforum",
    address: "Olshausenstraße 70-74, 24118 Kiel",
    area: "Campus Nord",
    lat: 54.344000,
    lon: 10.116000,
  }
];

function resolveCampusLocation(roomStr) {
  if (!roomStr || typeof roomStr !== "string") {
    return {
      isOnline: false,
      name: "Christian-Albrechts-Universität zu Kiel",
      address: "Christian-Albrechts-Platz 4, 24118 Kiel",
      area: "Campus Mitte",
      lat: 54.338700,
      lon: 10.122300,
      mapsUrl: "https://maps.apple.com/?ll=54.338700,10.122300&q=" + encodeURIComponent("Christian-Albrechts-Universität zu Kiel (Hauptcampus)") + "&z=18"
    };
  }

  const s = roomStr.trim();
  const isOnline = /online|zoom|bbb|bigbluebutton|moodle|virtuell/i.test(s);
  if (isOnline) {
    return {
      isOnline: true,
      name: "Virtuelle Online-Veranstaltung (Zoom / LMS)",
      address: "Online im Browser (Keine Anfahrt nötig)",
      area: "Digitale Lehre",
      lat: null,
      lon: null,
      mapsUrl: null
    };
  }

  // 1. Try matching the leading building code prefix first (e.g. "LMS6" in "LMS6 - R.11 / CAP2")
  const leadingPrefix = s.split(/[\s–\-\/]+/)[0] || "";
  if (leadingPrefix) {
    for (const loc of CAU_CAMPUS_LOCATIONS) {
      if (loc.regex.test(leadingPrefix)) {
        const pinLabel = `${s} · ${loc.name} (${loc.address})`;
        const mapsUrl = `https://maps.apple.com/?ll=${loc.lat},${loc.lon}&q=${encodeURIComponent(pinLabel)}&z=18`;
        return {
          isOnline: false,
          name: loc.name,
          address: loc.address,
          area: loc.area,
          lat: loc.lat,
          lon: loc.lon,
          mapsUrl: mapsUrl,
          code: loc.code
        };
      }
    }
  }

  // 2. Otherwise match anywhere in the room string
  for (const loc of CAU_CAMPUS_LOCATIONS) {
    if (loc.regex.test(s)) {
      const pinLabel = `${s} · ${loc.name} (${loc.address})`;
      const mapsUrl = `https://maps.apple.com/?ll=${loc.lat},${loc.lon}&q=${encodeURIComponent(pinLabel)}&z=18`;
      return {
        isOnline: false,
        name: loc.name,
        address: loc.address,
        area: loc.area,
        lat: loc.lat,
        lon: loc.lon,
        mapsUrl: mapsUrl,
        code: loc.code
      };
    }
  }

  // Fallback for general CAU Kiel campus
  const pinLabel = `${s} · Christian-Albrechts-Universität zu Kiel`;
  return {
    isOnline: false,
    name: "Christian-Albrechts-Universität zu Kiel",
    address: "Christian-Albrechts-Platz 4, 24118 Kiel",
    area: "Campus Mitte",
    lat: 54.338700,
    lon: 10.122300,
    mapsUrl: `https://maps.apple.com/?ll=54.338700,10.122300&q=${encodeURIComponent(pinLabel)}&z=18`
  };
}

function openEventDetailModal(ev, dayObj) {
  currentTurnusEditingEv = ev;
  const modal = document.getElementById("modalEventDetail");
  if (!modal) return;

  const badgeEl = document.getElementById("evDetailBadge");
  const titleEl = document.getElementById("evDetailTitle");
  const dateEl = document.getElementById("evDetailDate");
  const timeEl = document.getElementById("evDetailTime");
  const roomEl = document.getElementById("evDetailRoom");
  const bldEl = document.getElementById("evDetailBuilding");
  const turnusEl = document.getElementById("evDetailTurnus");
  const weekTypeEl = document.getElementById("evDetailWeekType");
  const courseIdEl = document.getElementById("evDetailCourseId");
  const univisEl = document.getElementById("evDetailUnivisId");
  const appleMapsBtn = document.getElementById("btnEvDetailAppleMaps");

  if (titleEl) titleEl.textContent = ev.title;
  if (badgeEl) {
    const isExercise = ev.type === "enrolled_exercise";
    badgeEl.textContent = isExercise ? "Übungsgruppe" : "Vorlesung";
    badgeEl.className = `aero-badge ${isExercise ? "badge-success" : "week-badge-a"}`;
  }
  if (dateEl && dayObj) {
    dateEl.textContent = `${dayObj.dayName}, ${dayObj.dayNum}. ${dayObj.monthName} ${dayObj.year}`;
  }
  if (timeEl) timeEl.textContent = `${ev.start_time} – ${ev.end_time} Uhr`;

  const campusLoc = resolveCampusLocation(ev.room);

  if (roomEl) roomEl.textContent = ev.room || "Kein Raum angegeben";
  if (bldEl) {
    if (campusLoc.isOnline) {
      bldEl.textContent = "💻 Virtuelle Online-Veranstaltung (Zoom / Moodle)";
    } else {
      bldEl.textContent = `${campusLoc.name} · ${campusLoc.address} (${campusLoc.area})`;
    }
  }

  if (appleMapsBtn) {
    if (campusLoc.isOnline || !campusLoc.mapsUrl) {
      appleMapsBtn.style.display = "none";
      appleMapsBtn.removeAttribute("href");
    } else {
      appleMapsBtn.style.display = "inline-flex";
      appleMapsBtn.href = campusLoc.mapsUrl;
      appleMapsBtn.target = "_blank";
      appleMapsBtn.rel = "noopener noreferrer";
      appleMapsBtn.title = `In Apple Maps öffnen: ${campusLoc.name} (${campusLoc.address})`;
      appleMapsBtn.onclick = null;
    }
  }

  if (turnusEl) {
    turnusEl.textContent = ev.week_type ? "14-tägig im Semester" : "Wöchentlich";
  }
  if (weekTypeEl) {
    weekTypeEl.textContent = ev.week_type ? `Findet nur in Woche ${ev.week_type} statt` : "Findet jede Woche statt";
  }

  if (courseIdEl) courseIdEl.textContent = ev.course_id || "Kurs-Termin";
  if (univisEl) {
    univisEl.textContent = ev.univis_id ? `UnivIS: #${ev.univis_id}` : "";
    univisEl.style.display = ev.univis_id ? "inline" : "none";
  }

  modal.classList.remove("hidden");
}

function initFutureCalEvents() {
  document.getElementById("btnCalPrevWeek")?.addEventListener("click", () => {
    futureCalState.currentWeekOffset = Math.max(0, futureCalState.currentWeekOffset - 1);
    renderFutureCalendar();
  });

  document.getElementById("btnCalToday")?.addEventListener("click", () => {
    futureCalState.currentWeekOffset = 0;
    renderFutureCalendar();
    scrollFutureCalToCurrentTime(true);
  });

  document.getElementById("btnCalNextWeek")?.addEventListener("click", () => {
    futureCalState.currentWeekOffset = Math.min(7, futureCalState.currentWeekOffset + 1);
    renderFutureCalendar();
  });

  document.getElementById("btnViewWeek")?.addEventListener("click", () => {
    futureCalState.viewMode = "week";
    renderFutureCalendar();
    scrollFutureCalToCurrentTime(false);
  });

  document.getElementById("btnViewAgenda")?.addEventListener("click", () => {
    futureCalState.viewMode = "agenda";
    renderFutureCalendar();
  });

  document.getElementById("btnJumpToTimetable")?.addEventListener("click", () => {
    switchAppPage("timetable");
  });

  document.getElementById("btnSwitchToFutureCal")?.addEventListener("click", () => {
    switchAppPage("calendar");
  });

  // Modal backdrop click closes detail modal
  const evDetailModal = document.getElementById("modalEventDetail");
  if (evDetailModal) {
    evDetailModal.addEventListener("click", (e) => {
      if (e.target === evDetailModal) {
        evDetailModal.classList.add("hidden");
      }
    });
  }

  // Live Clock-Sync Ticker for Red Time Indicator (Apple Calendar Style)
  if (!window._realtimeIndicatorsTimer) {
    window._realtimeIndicatorsTimer = setInterval(() => {
      updateFutureCalTimeIndicator();
      updateTimetableTimeIndicator();
    }, 5000); // Live-Sync alle 5 Sekunden
  }
  window.addEventListener("focus", () => {
    updateFutureCalTimeIndicator();
    updateTimetableTimeIndicator();
  });
}

/* ==========================================================================
   TURNUS MANAGER & TURNUS SELECTION LOGIC
   ========================================================================== */

let currentTurnusEditingEv = null;

async function setScheduleTurnus(evId, weekType) {
  const cleanWt = (weekType === "all" || !weekType || weekType === "null") ? null : String(weekType).toUpperCase();

  // 1. Optimistic instant update in memory
  let matchedTitle = "";
  appState.schedule = appState.schedule.map((e) => {
    if (String(e.id) === String(evId)) {
      matchedTitle = e.title || "Termin";
      return { ...e, week_type: cleanWt };
    }
    return e;
  });

  if (currentTurnusEditingEv && String(currentTurnusEditingEv.id) === String(evId)) {
    currentTurnusEditingEv.week_type = cleanWt;
    const turnusEl = document.getElementById("evDetailTurnus");
    const wtEl = document.getElementById("evDetailWeekType");
    if (turnusEl) turnusEl.textContent = cleanWt ? "14-tägig im Semester" : "Wöchentlich";
    if (wtEl) wtEl.textContent = cleanWt ? `Findet nur in Woche ${cleanWt} statt` : "Findet jede Woche statt";
  }

  // 2. Immediately re-render all views so the user sees the change INSTANTLY!
  renderTimetable();
  renderFutureCalendar();
  renderTurnusManagerList();

  // 3. Persist to backend: use /api/schedule/update first (works on all running server versions!)
  let res = await apiPost("/api/schedule/update", {
    schedule: appState.schedule
  });

  // Fallback to /api/schedule/set-turnus if update returned not ok
  if (!res || !res.ok) {
    res = await apiPost("/api/schedule/set-turnus", {
      id: evId,
      week_type: cleanWt
    });
  }

  if (res && res.ok && res.schedule) {
    appState.schedule = res.schedule;
    renderTimetable();
    renderFutureCalendar();
    renderTurnusManagerList();
  }

  return res;
}

function openTurnusSelectModal(ev) {
  currentTurnusEditingEv = ev;
  const modal = document.getElementById("modalTurnusSelect");
  if (!modal) return;

  const titleEl = document.getElementById("turnusSelectTitle");
  const badgeEl = document.getElementById("turnusSelectBadge");
  const subEl = document.getElementById("turnusSelectSub");

  if (titleEl) titleEl.textContent = ev.title;
  if (badgeEl) {
    badgeEl.textContent = ev.type === "enrolled_exercise" ? "Übungsgruppe" : "Vorlesung";
  }
  if (subEl) {
    const dayName = ev.day_name || DAY_NAMES[ev.day] || "Termin";
    subEl.textContent = `${dayName}, ${ev.start_time}–${ev.end_time} Uhr ${ev.room ? `(${ev.room})` : ""}`;
  }

  const currentWt = ev.week_type || "all";
  modal.querySelectorAll(".turnus-opt-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.turnus === currentWt);
  });

  modal.classList.remove("hidden");
}

function renderTurnusManagerList() {
  const listEl = document.getElementById("turnusManagerList");
  if (!listEl) return;
  listEl.innerHTML = "";

  if (!appState.schedule || appState.schedule.length === 0) {
    listEl.innerHTML = `<div class="empty-state">Keine Termine im Stundenplan vorhanden.</div>`;
    return;
  }

  const sorted = [...appState.schedule].sort((a, b) => {
    if (Number(a.day) !== Number(b.day)) return Number(a.day) - Number(b.day);
    return timeToMinutes(a.start_time) - timeToMinutes(b.start_time);
  });

  sorted.forEach((ev) => {
    const row = document.createElement("div");
    row.className = "turnus-manager-row";

    const currentWt = ev.week_type || "all";
    const dayStr = ev.day_name || (DAY_NAMES[ev.day] || "Termin");

    row.innerHTML = `
      <div class="turnus-row-info">
        <div class="turnus-row-title" title="${ev.title}">${ev.title}</div>
        <div class="turnus-row-sub">
          <span>📅 ${dayStr} ${ev.start_time}–${ev.end_time}</span>
          ${ev.room ? `<span>· 📍 ${ev.room}</span>` : ""}
        </div>
      </div>
      <div class="turnus-segmented-control">
        <button type="button" class="turnus-seg-btn ${currentWt === 'all' ? 'active' : ''}" data-wt="all">
          🔄 Jede Woche
        </button>
        <button type="button" class="turnus-seg-btn turnus-btn-a ${currentWt === 'A' ? 'active' : ''}" data-wt="A">
          🅰️ Woche A
        </button>
        <button type="button" class="turnus-seg-btn turnus-btn-b ${currentWt === 'B' ? 'active' : ''}" data-wt="B">
          🅱️ Woche B
        </button>
      </div>
    `;

    row.querySelectorAll(".turnus-seg-btn").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const wt = btn.dataset.wt;
        await setScheduleTurnus(ev.id, wt);
      });
    });

    listEl.appendChild(row);
  });
}

function initTurnusEvents() {
  // Bind all turnus option buttons using data-turnus attribute
  document.querySelectorAll(".turnus-opt-btn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      if (!currentTurnusEditingEv) return;
      const wt = btn.dataset.turnus;
      await setScheduleTurnus(currentTurnusEditingEv.id, wt);
      document.getElementById("modalTurnusSelect")?.classList.add("hidden");
    });
  });

  document.getElementById("btnOpenTurnusManagerModal")?.addEventListener("click", () => {
    renderTurnusManagerList();
    document.getElementById("modalTurnusManager")?.classList.remove("hidden");
  });

  document.getElementById("btnEvDetailChangeTurnus")?.addEventListener("click", () => {
    if (currentTurnusEditingEv) {
      openTurnusSelectModal(currentTurnusEditingEv);
    }
  });

  // Modal backdrop click closes
  ["modalTurnusSelect", "modalTurnusManager"].forEach((mId) => {
    const modalEl = document.getElementById(mId);
    if (modalEl) {
      modalEl.addEventListener("click", (e) => {
        if (e.target === modalEl) modalEl.classList.add("hidden");
      });
    }
  });
}

/* PAGE ROUTING (STUNDENPLAN & KURSE, KALENDER, EINSTELLUNGEN) */
function switchAppPage(pageName, updateHash = true) {
  const pageCalendar = document.getElementById("pageCalendar");
  const pageTimetable = document.getElementById("pageTimetable");
  const pageSettings = document.getElementById("pageSettings");
  if (!pageCalendar || !pageSettings || !pageTimetable) return;

  if (pageName === "settings") {
    pageCalendar.style.display = "none";
    pageTimetable.style.display = "none";
    pageSettings.style.display = "block";
    if (updateHash && window.location.hash !== "#settings") {
      window.location.hash = "settings";
    }
    window.scrollTo({ top: 0, behavior: "smooth" });
  } else if (pageName === "calendar") {
    pageTimetable.style.display = "none";
    pageSettings.style.display = "none";
    pageCalendar.style.display = "flex";
    if (updateHash && window.location.hash !== "#calendar") {
      window.location.hash = "calendar";
    }
    renderFutureCalendar();
    updateFutureCalTimeIndicator();
    scrollFutureCalToCurrentTime(false);
    window.scrollTo({ top: 0, behavior: "smooth" });
  } else {
    // Default: "timetable" (Stundenplan & Kurse)
    pageCalendar.style.display = "none";
    pageSettings.style.display = "none";
    pageTimetable.style.display = "grid";
    if (updateHash && window.location.hash && window.location.hash !== "#timetable") {
      window.location.hash = "timetable";
    }
    renderTimetable();
    updateTimetableTimeIndicator();
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
}

/* SLIDE-IN HAMBURGER MENU DRAWER */
function initDrawerMenu() {
  const hamburgerBtn = document.getElementById("btnHamburgerMenu");
  const logoBtn = document.getElementById("logoClickable");
  const titleBtn = document.getElementById("titleClickable");
  const backdrop = document.getElementById("drawerMenuBackdrop");
  const drawer = document.getElementById("drawerMenu");
  const closeBtn = document.getElementById("btnCloseDrawer");

  if (!drawer || !backdrop) return;

  function openDrawer() {
    backdrop.style.display = "block";
    drawer.style.display = "flex";
    void drawer.offsetWidth; // Reflow for transition
    backdrop.classList.add("open");
    drawer.classList.add("open");
    document.body.style.overflow = "hidden";
  }

  function closeDrawer() {
    backdrop.classList.remove("open");
    drawer.classList.remove("open");
    document.body.style.overflow = "";
    setTimeout(() => {
      if (!drawer.classList.contains("open")) {
        backdrop.style.display = "none";
        drawer.style.display = "none";
      }
    }, 360);
  }

  // Both hamburger button, logo, and title open the drawer
  if (hamburgerBtn) hamburgerBtn.addEventListener("click", openDrawer);
  if (logoBtn) {
    logoBtn.addEventListener("click", openDrawer);
    logoBtn.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        openDrawer();
      }
    });
  }
  if (titleBtn) {
    titleBtn.addEventListener("click", openDrawer);
    titleBtn.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        openDrawer();
      }
    });
  }

  if (closeBtn) closeBtn.addEventListener("click", closeDrawer);
  backdrop.addEventListener("click", closeDrawer);

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && drawer.classList.contains("open")) {
      closeDrawer();
    }
  });

  // Nav item handlers: Kalender (8-Wochen-Vorschau), Stundenplan & Kurse, Einstellungen
  document.getElementById("drawerBtnCalendar")?.addEventListener("click", () => {
    closeDrawer();
    switchAppPage("calendar");
  });

  document.getElementById("drawerBtnTimetable")?.addEventListener("click", () => {
    closeDrawer();
    switchAppPage("timetable");
  });

  document.getElementById("drawerBtnSettings")?.addEventListener("click", () => {
    closeDrawer();
    switchAppPage("settings");
  });

  // Settings page back buttons
  document.getElementById("btnBackToCalendar")?.addEventListener("click", () => {
    switchAppPage("timetable");
  });
  document.getElementById("btnBackToCalendarBottom")?.addEventListener("click", () => {
    switchAppPage("timetable");
  });

  // Hash-based routing (Default landing page: Stundenplan & Kurse)
  window.addEventListener("hashchange", () => {
    if (window.location.hash === "#settings") {
      switchAppPage("settings", false);
    } else if (window.location.hash === "#calendar") {
      switchAppPage("calendar", false);
    } else {
      switchAppPage("timetable", false);
    }
  });

  if (window.location.hash === "#settings") {
    switchAppPage("settings", false);
  } else if (window.location.hash === "#calendar") {
    switchAppPage("calendar", false);
  } else {
    switchAppPage("timetable", false);
  }
}

/* EVENT BINDINGS */
function bindUIEvents() {
  initDrawerMenu();
  initFutureCalEvents();
  initTurnusEvents();

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
  const btnLaunchBrowser = document.getElementById("btnLaunchBrowser");
  if (btnLaunchBrowser) {
    btnLaunchBrowser.addEventListener("click", async () => {
      const plat = document.getElementById("credPlatform")?.value || "unibody";
      const targetUrl = plat === "unibody" ? "unibody" : (appState.currentCourse ? appState.currentCourse.url : plat);
      const res = await apiPost("/api/browser/launch", {
        url: targetUrl,
        force_auto_login: true,
      });
      if (res.status) updateBrowserBadge(res.status);
      await pollTelemetry();
    });
  }

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
      switchAppPage("settings");
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

  // Execute Direct Live Enrollment
  const btnExecuteNow = document.getElementById("btnExecuteNow");
  if (btnExecuteNow) {
    btnExecuteNow.addEventListener("click", () => {
      triggerEnrollment();
    });
  }

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

  const btnEditCurrentGroups = document.getElementById("btnEditCurrentGroups");
  if (btnEditCurrentGroups) {
    btnEditCurrentGroups.addEventListener("click", () => {
      if (!appState.currentCourse) {
        alert("Bitte wähle zuerst oben in Schritt 1 einen Kurs aus!");
        return;
      }
      const titleEl = document.getElementById("editGroupsTitle");
      if (titleEl) titleEl.textContent = `✏️ Übungsgruppen für ${appState.currentCourse.course_id} anpassen / aus LMS einfügen`;
      const currentLines = (appState.currentCourse.groups || []).map((g) => `${g.name}`);
      const ta = document.getElementById("editGroupsTextarea");
      if (ta) ta.value = currentLines.join("\n");
      const m = document.getElementById("modalEditGroups");
      if (m) m.classList.remove("hidden");
    });
  }

  const formEditGroups = document.getElementById("formEditGroups");
  if (formEditGroups) {
    formEditGroups.addEventListener("submit", async (e) => {
      e.preventDefault();
      if (!appState.currentCourse) return;
      const ta = document.getElementById("editGroupsTextarea");
      const rawText = ta ? ta.value : "";
      const res = await apiPost("/api/course/update-groups", {
        course_id: appState.currentCourse.course_id,
        raw_text: rawText,
      });
      if (!res.ok) {
        alert(res.error || "Fehler beim Parsen der Gruppen.");
        return;
      }
      const m = document.getElementById("modalEditGroups");
      if (m) m.classList.add("hidden");
      await fetchInitialState();
      await verifyAndRankCourse(appState.currentCourse.course_id);
    });
  }

  document.querySelectorAll("[data-close]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const modalId = btn.dataset.close;
      const targetModal = document.getElementById(modalId);
      if (targetModal) targetModal.classList.add("hidden");
      if (modalId === "modalClaireEasterEgg" && claireHeartInterval) {
        clearInterval(claireHeartInterval);
        claireHeartInterval = null;
      }
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
    const wtVal = document.getElementById("evWeekType")?.value || "all";
    const ev = {
      title: document.getElementById("evTitle").value,
      day: Number(document.getElementById("evDay").value),
      start_time: document.getElementById("evStart").value,
      end_time: document.getElementById("evEnd").value,
      room: document.getElementById("evRoom").value,
      type: "lecture",
      week_type: wtVal === "all" ? null : wtVal,
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
        enrollment_mode: "sniper",
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

async function triggerEnrollment() {
  if (!appState.currentCourse) {
    alert("Bitte zuerst eine Kurs-ID in Schritt 1 verifizieren!");
    return;
  }
  const modeSel = document.getElementById("enrollModeSelect");
  const mode = modeSel ? modeSel.value : "sniper";
  const chkFallback = document.getElementById("chkSimulateFallback");
  const simulateFallback = chkFallback ? chkFallback.checked : false;

  const badge = document.getElementById("jobStatusBadge");
  if (badge) {
    badge.className = "status-pill";
    badge.textContent = "Einschreibung läuft...";
  }

  await apiPost("/api/enroll/execute", {
    course_id: appState.currentCourse.course_id,
    mode,
    simulate_first_choice_full: simulateFallback,
    trigger_type: "immediate",
    countdown_seconds: 0,
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
        if (badge) {
          badge.className = "status-pill completed";
          badge.textContent = `✓ ${latest.result_message}`;
        }
        appState.schedule = data.schedule || appState.schedule;
        renderTimetable();

        // Show enrollment success notification modal if not already notified
        const notifKey = `notified_job_${latest.job_id}`;
        if (!sessionStorage.getItem(notifKey)) {
          sessionStorage.setItem(notifKey, "1");
          showEnrollmentSuccessModal(latest);
        }
      } else if (latest.status === "locked") {
        if (badge) {
          badge.className = "status-pill";
          badge.style.background = "linear-gradient(180deg, #ffe082 0%, #ffb300 100%)";
          badge.style.color = "#5c2e00";
          badge.textContent = `⏳ ${latest.result_message}`;
        }

        // Show enrollment locked notification modal if not already notified
        const notifKey = `notified_job_${latest.job_id}`;
        if (!sessionStorage.getItem(notifKey)) {
          sessionStorage.setItem(notifKey, "1");
          showEnrollmentLockedModal(latest);
        }
      } else if (latest.status === "running" || latest.status === "armed") {
        if (badge) {
          badge.className = "status-pill";
          badge.style.background = "";
          badge.style.color = "";
          badge.textContent = `⚡ ${latest.result_message}`;
        }
      } else if (latest.status === "failed") {
        if (badge) {
          badge.className = "status-pill";
          badge.style.background = "linear-gradient(180deg, #ffcdd2 0%, #ef5350 100%)";
          badge.style.color = "#491212";
          badge.textContent = `❌ ${latest.result_message}`;
        }
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
  if (!badge || !text) return;
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
  if (!container) return;
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
