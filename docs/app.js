const installCommand = "curl -fsSL https://raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh | bash";
const copyButtons = document.querySelectorAll("[data-copy-install]");
const copyState = document.querySelector("[data-copy-state]");

async function copyInstallCommand() {
  try {
    await navigator.clipboard.writeText(installCommand);
    if (copyState) copyState.textContent = "copied";
    copyButtons.forEach((button) => {
      button.textContent = "Copied install command";
    });
    window.setTimeout(() => {
      if (copyState) copyState.textContent = "ready";
      copyButtons.forEach((button) => {
        button.textContent = "Copy install command";
      });
    }, 1800);
  } catch {
    if (copyState) copyState.textContent = "select";
  }
}

copyButtons.forEach((button) => {
  button.addEventListener("click", copyInstallCommand);
});

const commandCopyButtons = Array.from(document.querySelectorAll("[data-copy-command]"));

async function copyCommand(button) {
  const command = button.dataset.copyCommand || "";
  if (!command) return;
  const original = button.textContent;
  try {
    await navigator.clipboard.writeText(command);
    button.textContent = "Copied";
  } catch {
    button.textContent = "Select";
  }
  window.setTimeout(() => {
    button.textContent = original || "Copy";
  }, 1500);
}

commandCopyButtons.forEach((button) => {
  button.addEventListener("click", () => copyCommand(button));
});

async function shareProof(button) {
  const url = button.dataset.shareUrl || "";
  const text = button.dataset.shareText || url;
  if (!url && !text) return;
  const original = button.textContent;
  try {
    if (navigator.share && url) {
      await navigator.share({ title: "TokenBar builder proof", text, url });
      button.textContent = "Shared";
    } else {
      await navigator.clipboard.writeText(text);
      button.textContent = "Copied";
    }
  } catch {
    button.textContent = "Select";
  }
  window.setTimeout(() => {
    button.textContent = original || "Share";
  }, 1600);
}

function bindShareProofButtons(scope = document) {
  scope.querySelectorAll("[data-share-proof]").forEach((button) => {
    if (button.dataset.shareBound === "1") return;
    button.dataset.shareBound = "1";
    button.addEventListener("click", () => shareProof(button));
  });
}

bindShareProofButtons();

function submissionForProfile(profile = {}) {
  const raw = profile.hackathonSubmission || profile.submittedProject || {};
  const title = raw.projectTitle || raw.title || profile.projectTitle || profile.submittedProjectTitle || "";
  const event = raw.event || profile.event || profile.hackathonEvent || "";
  const track = raw.track || profile.track || profile.hackathonTrack || "";
  const repoUrl = raw.repoUrl || profile.repoUrl || profile.githubUrl || "";
  const demoUrl = raw.demoUrl || profile.demoUrl || profile.liveUrl || "";
  const tagline = raw.tagline || profile.projectTagline || profile.tagline || "";
  if (!title && !event && !track && !repoUrl && !demoUrl && !tagline) return null;
  return { title, event, track, repoUrl, demoUrl, tagline };
}

function renderSubmissionLinks(submission) {
  if (!submission) return "";
  const links = [
    submission.repoUrl ? `<a href="${escapeHtml(submission.repoUrl)}" rel="noopener noreferrer">Repo</a>` : "",
    submission.demoUrl ? `<a href="${escapeHtml(submission.demoUrl)}" rel="noopener noreferrer">Demo</a>` : "",
  ].filter(Boolean);
  return `<nav>${links.join("")}<em>No raw repo upload</em></nav>`;
}

function renderTokenSubmissionSummary(submission) {
  if (!submission) return "";
  const title = submission.title || "Submitted project";
  const meta = [submission.event, submission.track].filter(Boolean).join(" · ");
  return `<div class="token-submission-summary" aria-label="Submitted project attached to token">
      <span>Submitted project</span>
      <strong>${escapeHtml(title)}</strong>
      ${submission.tagline ? `<p>${escapeHtml(submission.tagline)}</p>` : ""}
      ${meta ? `<small>${escapeHtml(meta)}</small>` : ""}
      ${renderSubmissionLinks(submission)}
    </div>`;
}

function renderTokenProofPassport(profile = {}, token = "") {
  const privacy = profile.privacy || {};
  const usage = profile.usage || {};
  const leaderboard = profile.leaderboard || {};
  const story = profile.builderStory || profile.sessionAnalysis || {};
  const visibility = profile.publicVisibility || privacy.shareMode || profile?.shareControls?.visibility || "public";
  const totalTokens = leaderboard.tokenCount || usage.totalTokens || usage.last30 || profile.totalTokens || profile.tokenCount || 0;
  const sessionCount = usage.sessionCount || usage.sessionsIndexed || profile.sessionCount || profile.sessionsAnalyzed || 0;
  const projectRange = leaderboard.projectRange || usage.projectCount || profile.projectCount || "local";
  const nextFrontier = story.nextFrontier || profile.nextFrontier || profile?.nextActionPlan?.nextFrontier || "keep the next proof surface tighter than the last run";
  const proof = formatScore(profile.proofScore || profile.score || profile.specificityScore);
  const loop = formatScore(profile.loopMaturity || profile.loopScore || profile.proofScore);
  const specificity = formatScore(profile.specificityScore || profile.score || profile.proofScore);
  const shareModeLabel = String(visibility).replace(/^\w/, (char) => char.toUpperCase());
  const rawSafe = privacy.rawTranscriptsIncluded === false ? "raw transcripts excluded" : "raw transcript boundary needs review";
  const sourceSafe = privacy.sourceCodeIncluded === false ? "source code excluded" : "source boundary needs review";
  return `<section class="token-proof-passport" aria-label="TokenBar proof passport">
      <div class="token-passport-head">
        <span>60-second proof passport</span>
        <strong>${escapeHtml(profile.title || profile.primaryArchetype || "Builder Identity")}</strong>
        <p>${escapeHtml(profile.subtitle || story.summary || profile.bio || "A reloadable proof card built from safe local aggregate evidence.")}</p>
      </div>
      <div class="token-passport-scores" aria-label="Proof scores">
        <span><b>${proof}</b><small>Proof</small></span>
        <span><b>${loop}</b><small>Loop</small></span>
        <span><b>${specificity}</b><small>Specificity</small></span>
      </div>
      <div class="token-passport-evidence" aria-label="Safe evidence summary">
        <span><b>${escapeHtml(formatTokenCount(totalTokens))}</b><small>aggregate tokens</small></span>
        <span><b>${escapeHtml(sessionCount || "local")}</b><small>sessions</small></span>
        <span><b>${escapeHtml(projectRange)}</b><small>project range</small></span>
        <span><b>${escapeHtml(shareModeLabel)}</b><small>share mode</small></span>
      </div>
      <div class="token-passport-boundary">
        <span>${escapeHtml(rawSafe)}</span>
        <span>${escapeHtml(sourceSafe)}</span>
        <span>token ${escapeHtml(token)}</span>
      </div>
      <p class="token-passport-frontier"><b>Next frontier:</b> ${escapeHtml(nextFrontier)}</p>
    </section>`;
}

function bindTiltSurface(surface, options = {}) {
  if (!surface) return;
  const max = options.max || 8;
  const setStyle = options.setStyle || ((node, x, y) => {
    const centerOffset = node.classList.contains("hero-shot") ? "translateX(-50%) " : "";
    node.style.transform = `${centerOffset}rotateX(${y.toFixed(2)}deg) rotateY(${x.toFixed(2)}deg) rotate(1.2deg) translateY(-6px)`;
  });
  surface.addEventListener("pointermove", (event) => {
    const rect = surface.getBoundingClientRect();
    const x = ((event.clientX - rect.left) / rect.width - 0.5) * max;
    const y = ((event.clientY - rect.top) / rect.height - 0.5) * -max;
    surface.classList.add("is-tilting");
    setStyle(surface, x, y);
  });
  surface.addEventListener("pointerleave", () => {
    surface.classList.remove("is-tilting");
    surface.style.removeProperty("transform");
    surface.style.removeProperty("--scanner-x");
    surface.style.removeProperty("--scanner-y");
  });
}

bindTiltSurface(document.querySelector("[data-product-rig]"), { max: 10 });
bindTiltSurface(document.querySelector("[data-scanner-rig]"), {
  max: 7,
  setStyle: (node, x, y) => {
    node.style.setProperty("--scanner-x", `${y.toFixed(2)}deg`);
    node.style.setProperty("--scanner-y", `${x.toFixed(2)}deg`);
  },
});

const qd = document.querySelector(".qd");
const moods = ["0 0 0 0", "0 2px 0 0", "0 -2px 0 0"];
let moodIndex = 0;

window.setInterval(() => {
  if (!qd || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  moodIndex = (moodIndex + 1) % moods.length;
  qd.style.filter = `drop-shadow(${moods[moodIndex]} rgba(22, 136, 245, 0.18))`;
}, 2600);

const controlRows = Array.from(document.querySelectorAll("[data-control-row]"));
const controlLabel = document.querySelector("[data-control-label]");
const controlValue = document.querySelector("[data-control-value]");
const promptText = document.querySelector(".prompt-bar strong");
let controlIndex = 0;
let promptIndex = 0;

function activateControl(index) {
  if (!controlRows.length) return;
  controlRows.forEach((row, rowIndex) => {
    row.classList.toggle("is-active", rowIndex === index);
  });

  const active = controlRows[index];
  if (controlLabel) controlLabel.textContent = active.dataset.label || "Control";
  if (controlValue) controlValue.textContent = active.dataset.value || "";
}

window.setInterval(() => {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  controlIndex = (controlIndex + 1) % controlRows.length;
  activateControl(controlIndex);
}, 2200);

const promptExamples = [
  "will I run out before reset?",
  "why did May 18 spike?",
  "config budget 20B",
  "forecast next week by cost",
  "what source is missing for GPU pressure?",
];

window.setInterval(() => {
  if (!promptText || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  promptIndex = (promptIndex + 1) % promptExamples.length;
  promptText.textContent = promptExamples[promptIndex];
}, 2400);

const identitySlides = Array.from(document.querySelectorAll("[data-identity-slide]"));
const identityTabs = Array.from(document.querySelectorAll("[data-identity-tab]"));
const identityPrev = document.querySelector("[data-slide-prev]");
const identityNext = document.querySelector("[data-slide-next]");
let identityIndex = 0;
let identityTimer = null;

function showIdentitySlide(index) {
  if (!identitySlides.length) return;
  identityIndex = (index + identitySlides.length) % identitySlides.length;
  identitySlides.forEach((slide, slideIndex) => {
    slide.classList.toggle("is-active", slideIndex === identityIndex);
  });
  identityTabs.forEach((tab) => {
    tab.classList.toggle("is-active", Number(tab.dataset.identityTab) === identityIndex);
  });
}

function restartIdentityTimer() {
  if (!identitySlides.length || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  window.clearInterval(identityTimer);
  identityTimer = window.setInterval(() => {
    showIdentitySlide(identityIndex + 1);
  }, 5200);
}

identityTabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    showIdentitySlide(Number(tab.dataset.identityTab) || 0);
    restartIdentityTimer();
  });
});

identityPrev?.addEventListener("click", () => {
  showIdentitySlide(identityIndex - 1);
  restartIdentityTimer();
});

identityNext?.addEventListener("click", () => {
  showIdentitySlide(identityIndex + 1);
  restartIdentityTimer();
});

restartIdentityTimer();

const personaCards = Array.from(document.querySelectorAll("[data-persona-card]"));
const creatureStatus = document.querySelector("[data-creature-status]");
let personaIndex = 0;
let personaTimer = null;

function featurePersona(index) {
  if (!personaCards.length) return;
  personaIndex = (index + personaCards.length) % personaCards.length;
  personaCards.forEach((card, cardIndex) => {
    card.classList.toggle("is-featured", cardIndex === personaIndex);
  });
  if (creatureStatus) {
    creatureStatus.textContent = personaCards[personaIndex].dataset.personaStatus || "";
  }
}

function restartPersonaTimer() {
  if (!personaCards.length || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  window.clearInterval(personaTimer);
  personaTimer = window.setInterval(() => {
    const creatureSlideActive = document.querySelector(".identity-slide.is-active .creature-theater");
    if (!creatureSlideActive) return;
    featurePersona(personaIndex + 1);
  }, 2300);
}

personaCards.forEach((card, index) => {
  card.addEventListener("pointerenter", () => {
    featurePersona(index);
    restartPersonaTimer();
  });
  card.addEventListener("click", () => {
    featurePersona(index);
    restartPersonaTimer();
  });
  card.addEventListener("pointermove", (event) => {
    const rect = card.getBoundingClientRect();
    const x = ((event.clientX - rect.left) / rect.width - 0.5) * 10;
    const y = ((event.clientY - rect.top) / rect.height - 0.5) * -10;
    card.style.setProperty("--tilt-x", `${y.toFixed(2)}deg`);
    card.style.setProperty("--tilt-y", `${x.toFixed(2)}deg`);
  });
  card.addEventListener("pointerleave", () => {
    card.style.removeProperty("--tilt-x");
    card.style.removeProperty("--tilt-y");
  });
});

restartPersonaTimer();

const statsCount = document.querySelector("[data-stats-count]");
const statsSpecificity = document.querySelector("[data-stats-specificity]");
const statsLoop = document.querySelector("[data-stats-loop]");
const statsCoverage = document.querySelector("[data-stats-coverage]");
const statsArchetypes = document.querySelector("[data-stats-archetypes]");
const statsNpcs = document.querySelector("[data-stats-npcs]");
const statsBuckets = document.querySelector("[data-stats-buckets]");
const statsRarestBuckets = document.querySelector("[data-stats-rarest-buckets]");
const statsSessionSignals = document.querySelector("[data-stats-session-signals]");
const statsSpecificityBands = document.querySelector("[data-stats-specificity-bands]");
const statsProviderCoverage = document.querySelector("[data-stats-provider-coverage]");
const statsTopProfiles = document.querySelector("[data-stats-top-profiles]");
const statsTopLoopProfiles = document.querySelector("[data-stats-top-loop-profiles]");
const socialFeed = document.querySelector("[data-social-feed]");
const hackathonRoster = document.querySelector("[data-hackathon-roster]");
const shareContractPanel = document.querySelector("[data-share-contract]");
const actionLoopRankings = document.querySelector("[data-action-loop-rankings]");
const rankingLeaderboards = document.querySelector("[data-ranking-leaderboards]");
const scoreboardRegion = document.querySelector("[data-scoreboard-region]");
const scoreboardList = document.querySelector("[data-scoreboard-list]");
const regionTabs = Array.from(document.querySelectorAll("[data-region-tab]"));
const regionList = document.querySelector("[data-region-list]");
const identityThemeButtons = Array.from(document.querySelectorAll("[data-identity-pick]"));
const proofReceiptForms = Array.from(document.querySelectorAll("[data-proof-receipt-form]"));
const submissionUpdateForms = Array.from(document.querySelectorAll("[data-submission-update]"));
let regionalLeaderboards = {};

const identityThemeMap = {
  blueprint: ["blueprint", "captain", "architect", "commander"],
  cartographer: ["cartographer", "mapper", "navigator", "launch"],
  ronin: ["ronin", "prompt", "operator", "precision"],
  alchemist: ["alchemist", "signal", "synthesizer", "oracle"],
};

function identityThemeFor(value) {
  const text = String(value || "").toLowerCase();
  const match = Object.entries(identityThemeMap).find(([, keys]) => keys.some((key) => text.includes(key)));
  return match ? match[0] : "blueprint";
}

function setIdentityTheme(theme) {
  const nextTheme = identityThemeMap[theme] ? theme : "blueprint";
  document.body.dataset.identity = nextTheme;
  identityThemeButtons.forEach((button) => {
    button.classList.toggle("is-active", button.dataset.identityPick === nextTheme);
  });
}

function bindIdentityThemes(root = document) {
  root.querySelectorAll("[data-identity-theme]").forEach((node) => {
    node.addEventListener("pointerenter", () => setIdentityTheme(node.dataset.identityTheme));
    node.addEventListener("focus", () => setIdentityTheme(node.dataset.identityTheme));
  });
}

identityThemeButtons.forEach((button) => {
  button.addEventListener("click", () => setIdentityTheme(button.dataset.identityPick));
});

bindIdentityThemes();

function formatTokenCount(value) {
  const number = Number(value || 0);
  if (!number) return "local";
  if (number >= 1_000_000_000) return `${(number / 1_000_000_000).toFixed(1)}B`;
  if (number >= 1_000_000) return `${Math.round(number / 1_000_000)}M`;
  return number.toLocaleString();
}

function escapeHtml(value) {
  return String(value || "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[char]);
}

function formatScore(value) {
  const score = Number(value || 0);
  return Math.max(0, Math.min(100, score)).toFixed(0);
}

function profileHrefForToken(token) {
  return token ? `/api/profiles?token=${encodeURIComponent(token)}` : "";
}

function proofHref(profile) {
  return profile?.proofCardUrl || profile?.profileUrl || profileHrefForToken(profile?.token);
}

function surfaceFromBundle(profile, key) {
  const surfaces = Array.isArray(profile?.surfaceBundle?.surfaces) ? profile.surfaceBundle.surfaces : [];
  return surfaces.find((surface) => surface?.key === key) || {};
}

function renderProofLinks(profile) {
  const links = [
    ["Open proof", surfaceFromBundle(profile, "proofCard").url || profile.proofCardUrl || proofHref(profile)],
    ["Profile", surfaceFromBundle(profile, "publicProfile").url || profile.profileUrl],
    ["Rankings", surfaceFromBundle(profile, "rankings").url || profile.rankingsUrl || "/rankings"],
  ].filter(([, href]) => href);
  return links.map(([label, href]) => `<a class="profile-card-link" href="${escapeHtml(href)}">${escapeHtml(label)}</a>`).join("");
}

function renderStatsRows(target, values, percentages = {}) {
  if (!target) return;
  const entries = Object.entries(values || {}).slice(0, 6);
  if (!entries.length) {
    target.innerHTML = "<p>No public opt-in profiles yet.</p>";
    return;
  }
  const max = Math.max(...entries.map(([, count]) => Number(count) || 0), 1);
  target.innerHTML = entries
    .map(([name, count]) => {
      const safeName = escapeHtml(name);
      const safeCount = Number(count) || 0;
      const percent = Number(percentages[name] || 0);
      const width = Math.max(6, Math.round((safeCount / max) * 100));
      return `<div class="stats-row"><span>${safeName}</span><strong>${safeCount} · ${percent.toFixed(1)}%</strong><i><b style="width:${width}%"></b></i></div>`;
    })
    .join("");
}

function renderSignalRows(target, values) {
  if (!target) return;
  const labels = {
    planningSignal: "Planning",
    redirectionSignal: "Redirection",
    urgencySignal: "Urgency",
    visualSignal: "Visual/product",
    monetizationSignal: "Monetization",
    privacySignal: "Privacy",
    identitySignal: "Identity/report",
    commandPromptRatio: "Command style",
    shortPromptRatio: "Short prompts",
  };
  const entries = Object.entries(values || {}).slice(0, 8);
  if (!entries.length) {
    target.innerHTML = "<p>No public session signal averages yet.</p>";
    return;
  }
  target.innerHTML = entries
    .map(([name, value]) => {
      const label = labels[name] || name;
      const percent = Math.max(0, Math.min(100, Number(value) || 0));
      return `<div class="stats-row"><span>${label}</span><strong>${percent.toFixed(1)}%</strong><i><b style="width:${Math.max(6, percent)}%"></b></i></div>`;
    })
    .join("");
}

function renderTopProfiles(target, profiles, options = {}) {
  if (!target) return;
  const entries = Array.isArray(profiles) ? profiles.slice(0, 6) : [];
  if (!entries.length) {
    target.innerHTML = "<p>No public profile rankings yet.</p>";
    return;
  }
  const scoreKey = options.scoreKey || "specificityScore";
  const suffix = options.suffix || "/100";
  target.innerHTML = entries
    .map((profile) => {
      const safeTitle = escapeHtml(profile.nickname || profile.title || profile.bucket || profile.token || "Untitled profile");
      const score = Number(profile[scoreKey]) || 0;
      const theme = identityThemeFor(`${profile.primaryArchetype || ""} ${profile.npcClass || ""} ${profile.bucket || ""}`);
      const href = proofHref(profile) || "#";
      const archetype = escapeHtml(profile.primaryArchetype || profile.npcClass || "Builder");
      const context = `${formatTokenCount(profile.tokenCount)} tokens · ${Number(profile.sessionCount || profile.sessions || 0).toFixed(0)} sessions`;
      const submission = submissionForProfile(profile);
      const projectLine = submission
        ? `<small class="ranking-project-line">${escapeHtml(submission.title || "Submitted project")} · ${escapeHtml(submission.event || submission.track || "safe submission")}</small>`
        : "";
      const breakdown = profile.rankingBreakdown || {};
      const breakdownRows = ["proof", "loop", "specificity", "range", "tokens"]
        .filter((key) => breakdown[key] !== undefined && breakdown[key] !== null)
        .map((key) => `<span><b>${escapeHtml(key)}</b><em>${formatScore(breakdown[key])}</em></span>`)
        .join("");
      const breakdownNote = breakdownRows
        ? `<div class="ranking-breakdown" aria-label="Ranking score breakdown">${breakdownRows}<small>${escapeHtml(breakdown.note || "Token volume is capped at 6% of the composite ranking score.")}</small></div>`
        : "";
      return `<a class="ranking-proof-card" data-identity-theme="${theme}" href="${escapeHtml(href)}">
        <span>${safeTitle}<small>${archetype} · ${escapeHtml(context)}</small>${projectLine}</span>
        <strong>${formatScore(score)}${suffix}</strong>
        <i><b style="width:${Math.max(6, Math.min(100, score))}%"></b></i>
        ${breakdownNote}
      </a>`;
    })
    .join("");
  bindIdentityThemes(target);
}

function renderBucketRanking(target, buckets) {
  if (!target) return;
  const entries = Array.isArray(buckets) ? buckets.slice(0, 6) : [];
  if (!entries.length) {
    target.innerHTML = "<p>No bucket rankings yet.</p>";
    return;
  }
  target.innerHTML = entries
    .map((item) => {
      const safeBucket = escapeHtml(item.bucket || "unknown-bucket");
      const count = Number(item.count) || 0;
      const share = Number(item.sharePercent) || 0;
      const width = Math.max(6, Math.min(100, share || 6));
      return `<div class="stats-row"><span>${safeBucket}</span><strong>${count} · ${share.toFixed(1)}%</strong><i><b style="width:${width}%"></b></i></div>`;
    })
    .join("");
}

function renderSocialFeed(profiles) {
  if (!socialFeed || !Array.isArray(profiles) || !profiles.length) return;
  socialFeed.innerHTML = profiles.slice(0, 8).map((profile, index) => {
    const nickname = escapeHtml(profile.nickname || profile.title || "builder");
    const region = escapeHtml(profile.region || "Global");
    const archetype = escapeHtml(profile.primaryArchetype || profile.title || "Builder");
    const npc = escapeHtml(profile.npcClass || profile.bucket || "public profile");
    const bio = escapeHtml(profile.bio || `Shipped a public ${archetype} proof card from local TokenBar analysis.`);
    const token = escapeHtml(profile.token || "");
    const score = formatScore(profile.proofScore || profile.score || profile.specificityScore);
    const loopScore = formatScore(profile.loopMaturity || profile.loopScore || profile.proofScore || profile.specificityScore);
    const specificity = formatScore(profile.specificityScore || profile.score || profile.proofScore);
    const nextFrontier = profile.nextFrontier ? `<small class="feed-frontier">${escapeHtml(profile.nextFrontier)}</small>` : "";
    const proofFacts = Array.isArray(profile.proofFacts) ? profile.proofFacts.slice(0, 3) : [];
    const feedStory = profile.feedStory || {};
    const safeEvidenceReceipt = profile.safeEvidenceReceipt || {};
    const builderSignals = profile.builderSignalInbox || profile.socialLearningSignals || safeEvidenceReceipt.builderSignalInbox || {};
    const nextActionPlan = profile.nextActionPlan || {};
    const rankBadges = Array.isArray(profile.rankBadges) ? profile.rankBadges.slice(0, 4) : [];
    const proved = Array.isArray(profile.whatProved) ? profile.whatProved.slice(0, 3) : [];
    const shippedWork = Array.isArray(profile.shippedWork) ? profile.shippedWork.slice(0, 3) : [];
    const remaining = Array.isArray(profile.whatRemainsUncertain) ? profile.whatRemainsUncertain.slice(0, 2) : [];
    const privacy = profile.privacy || {};
    const rawSafe = privacy.rawTranscriptsIncluded === false ? "No raw transcripts" : "Transcript boundary unclear";
    const codeSafe = privacy.sourceCodeIncluded === false ? "No source code" : "Source boundary unclear";
    const artifact = escapeHtml(privacy.uploadedArtifact || "generated proof artifact only");
    const publicProfileSurface = surfaceFromBundle(profile, "publicProfile");
    const proofSurface = surfaceFromBundle(profile, "proofCard");
    const socialSurface = surfaceFromBundle(profile, "socialFeed");
    const rankingsSurface = surfaceFromBundle(profile, "rankings");
    const profileLinks = profile.profileLinks || profile.ownerProfile?.links || {};
    const submission = submissionForProfile(profile);
    const profileLinksHtml = Object.entries(profileLinks)
      .filter(([, href]) => typeof href === "string" && href.trim())
      .slice(0, 4)
      .map(([label, href]) => `<a href="${escapeHtml(href)}" rel="noopener noreferrer">${escapeHtml(label)}</a>`)
      .join("");
    const submissionCard = submission
      ? `<div class="feed-submission-card" aria-label="Submitted project">
          <span>Submitted project</span>
          <strong>${escapeHtml(submission.title || "Untitled project")}</strong>
          ${submission.tagline ? `<p>${escapeHtml(submission.tagline)}</p>` : ""}
          <small>${escapeHtml([submission.event, submission.track].filter(Boolean).join(" · ") || "Independent build")}</small>
          ${renderSubmissionLinks(submission)}
        </div>`
      : "";
    const shareUrl = profile.shareUrl || publicProfileSurface.url || proofSurface.url || proofHref(profile) || socialSurface.url || rankingsSurface.url || "/social";
    const shareCopy = profile?.surfaceBundle?.shareCopy || profile.shareCopy || `I published my TokenBar builder proof: ${nickname} (${archetype}). ${shareUrl}`;
    const proofReceipt = proved.length
      ? `<ul class="feed-evidence">${proved.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>`
      : "";
    const rankBadgeHtml = rankBadges.length
      ? `<div class="feed-rank-badges" aria-label="Public rank context">${rankBadges.map((badge) => {
        const label = escapeHtml(badge.label || "Rank");
        const rank = Number(badge.rank) || 0;
        const total = Number(badge.total) || 0;
        const score = formatScore(badge.score);
        return `<span><b>${label}</b><strong>#${rank}</strong><small>${total ? `of ${total}` : "public board"} · ${score}</small></span>`;
      }).join("")}</div>`
      : "";
    const storyCard = feedStory.whatShipped || feedStory.whyItMatters || feedStory.tradeoff || feedStory.nextFrontier
      ? `<div class="feed-story-card" aria-label="Builder story card">
          <span>Builder story</span>
          ${feedStory.whatShipped ? `<section><b>What shipped</b><strong>${escapeHtml(feedStory.whatShipped)}</strong></section>` : ""}
          ${feedStory.whyItMatters ? `<section><b>Why it matters</b><p>${escapeHtml(feedStory.whyItMatters)}</p></section>` : ""}
          ${feedStory.tradeoff ? `<section><b>Tradeoff</b><p>${escapeHtml(feedStory.tradeoff)}</p></section>` : ""}
          ${feedStory.nextFrontier ? `<section><b>Next frontier</b><p>${escapeHtml(feedStory.nextFrontier)}</p></section>` : ""}
          ${feedStory.provenance ? `<em>${escapeHtml(feedStory.provenance)}</em>` : ""}
        </div>`
      : "";
    const uncertaintyReceipt = remaining.length
      ? `<div class="feed-uncertainty"><b>Still uncertain</b>${remaining.map((item) => `<span>${escapeHtml(item)}</span>`).join("")}</div>`
      : "";
    const factReceipt = proofFacts.length
      ? `<div class="feed-facts">${proofFacts.map((item) => {
        const label = escapeHtml(item.label || "Signal");
        const value = escapeHtml(item.value || "");
        const note = item.note ? `<small>${escapeHtml(item.note)}</small>` : "";
        return `<span><b>${label}</b><strong>${value}</strong>${note}</span>`;
      }).join("")}</div>`
      : "";
    const shippedReceipt = shippedWork.length
      ? `<div class="feed-shipped-work" aria-label="Shipped work receipt">${shippedWork.map((item) => {
        const label = escapeHtml(item.label || "Evidence");
        const value = escapeHtml(item.value || "");
        const note = item.note ? `<small>${escapeHtml(item.note)}</small>` : "";
        const provenance = item.provenance ? `<em>${escapeHtml(item.provenance)}</em>` : "";
        return `<span><b>${label}</b><strong>${value}</strong>${note}${provenance}</span>`;
      }).join("")}</div>`
      : "";
    const safeReceipt = safeEvidenceReceipt.schema
      ? `<div class="feed-safe-receipt" aria-label="Safe evidence receipt">
          <b>Safe evidence receipt</b>
          <span>${escapeHtml(safeEvidenceReceipt.publicMaterial || "safe aggregate proof only")}</span>
          <small>Used: ${escapeHtml((safeEvidenceReceipt.usedEvidence || []).slice(0, 3).join(", ") || "generated identity JSON")}</small>
          <small>Never: ${escapeHtml((safeEvidenceReceipt.neverUsed || []).slice(0, 4).join(", ") || "raw transcripts, source code")}</small>
        </div>`
      : "";
    const signalTags = [
      ...(Array.isArray(builderSignals.topTags) ? builderSignals.topTags.slice(0, 4).map((item) => item.name) : []),
      ...(Array.isArray(builderSignals.topHosts) ? builderSignals.topHosts.slice(0, 3).map((item) => item.name) : []),
    ].filter(Boolean);
    const signalReceipt = builderSignals.schema && Number(builderSignals.signalCount || 0) > 0
      ? `<div class="feed-builder-signals" aria-label="Builder taste signals">
          <b>Reference radar</b>
          <span>${escapeHtml(String(builderSignals.signalCount || 0))} saved references shaped this builder's taste</span>
          <div>${signalTags.map((name) => `<em>${escapeHtml(name)}</em>`).join("")}</div>
          <small>Public proof shows aggregates only. Raw URLs, titles, notes, transcripts, and source code stay local.</small>
        </div>`
      : "";
    const nextActions = Array.isArray(nextActionPlan.actions) ? nextActionPlan.actions.slice(0, 3) : [];
    const nextActionReceipt = nextActionPlan.schema
      ? `<div class="feed-next-action" aria-label="Act verify share next-action plan">
          <b>Act next</b>
          <span>${escapeHtml(nextActionPlan.focus || "run one safe builder loop")}</span>
          ${nextActions.map((item) => `<small><code>${escapeHtml(item.command || "tokenbar claim")}</code>${escapeHtml(item.label || item.key || "Next action")}</small>`).join("")}
        </div>`
      : "";
    const theme = identityThemeFor(`${archetype} ${npc} ${profile.bucket || ""}`);
    return `<article class="feed-card shipped-card" data-identity-theme="${theme}">
      <div class="proof-network-strip">
        <span class="rank-dot ${index % 2 ? "green" : ""}">#${index + 1} ${region}</span>
        <span class="privacy-chip">safe aggregate only</span>
        ${token ? `<code>${token}</code>` : ""}
      </div>
      <div><strong>${nickname}</strong><small>${region} · ${archetype} · ${npc}</small></div>
      <p>${bio}</p>
      ${profileLinksHtml ? `<div class="feed-profile-links" aria-label="Builder public links">${profileLinksHtml}</div>` : ""}
      ${submissionCard}
      ${rankBadgeHtml}
      ${storyCard}
      <div class="proof-score-strip">
        <span><b>${score}</b><small>Proof</small></span>
        <span><b>${loopScore}</b><small>Loop</small></span>
        <span><b>${specificity}</b><small>Specificity</small></span>
        <span><b>${formatTokenCount(profile.tokenCount)}</b><small>Tokens</small></span>
      </div>
      ${proofReceipt}
      ${shippedReceipt}
      ${signalReceipt}
      ${nextActionReceipt}
      ${safeReceipt}
      ${factReceipt}
      ${nextFrontier}
      ${uncertaintyReceipt}
      <div class="feed-safety" aria-label="Safe sharing boundary">
        <span>${escapeHtml(rawSafe)}</span>
        <span>${escapeHtml(codeSafe)}</span>
        <span>${artifact}</span>
      </div>
      <div class="post-actions">
        <button type="button" data-share-proof data-share-url="${escapeHtml(shareUrl)}" data-share-text="${escapeHtml(shareCopy)}">Share proof</button>
        <a class="profile-card-link" href="${escapeHtml(publicProfileSurface.url || profile.profileUrl || shareUrl || "/profile")}">Discuss profile</a>
        ${renderProofLinks(profile) || `<a class="profile-card-link" href="/rankings">Rankings</a>`}
      </div>
    </article>`;
  }).join("");
  bindIdentityThemes(socialFeed);
  bindShareProofButtons(socialFeed);
}

function renderHackathonRoster(profiles) {
  if (!hackathonRoster) return;
  const rows = Array.isArray(profiles)
    ? profiles
        .filter((profile) => submissionForProfile(profile) || profile.token || profile.primaryArchetype)
        .slice(0, 12)
    : [];
  if (!rows.length) {
    hackathonRoster.innerHTML = `<article class="roster-card is-empty">
      <span>Roster pending</span>
      <strong>No public submissions yet</strong>
      <p>Run <code>tokenbar submit --project "My Codex App"</code> to create a safe profile token and appear here.</p>
    </article>`;
    return;
  }
  hackathonRoster.innerHTML = rows.map((profile, index) => {
    const submission = submissionForProfile(profile);
    const nickname = escapeHtml(profile.nickname || profile.title || "builder");
    const archetype = escapeHtml(profile.primaryArchetype || profile.bucket || "Builder");
    const region = escapeHtml(profile.region || "Global");
    const title = escapeHtml(submission?.title || "Identity proof");
    const event = escapeHtml([submission?.event, submission?.track].filter(Boolean).join(" · ") || "Independent build");
    const token = escapeHtml(profile.token || "");
    const score = formatScore(profile.score || profile.proofScore || profile.specificityScore);
    const loop = formatScore(profile.loopMaturity || profile.loopScore);
    const profileUrl = profile.profileUrl || surfaceFromBundle(profile, "publicProfile").url || profileHrefForToken(profile.token) || "/profile";
    const repoLink = submission?.repoUrl ? `<a href="${escapeHtml(submission.repoUrl)}" rel="noopener noreferrer">Repo</a>` : "";
    const demoLink = submission?.demoUrl ? `<a href="${escapeHtml(submission.demoUrl)}" rel="noopener noreferrer">Demo</a>` : "";
    const theme = identityThemeFor(`${profile.primaryArchetype || ""} ${profile.npcClass || ""} ${profile.bucket || ""}`);
    return `<article class="roster-card" data-identity-theme="${theme}">
      <div><span>#${index + 1} ${region}</span>${token ? `<code>${token}</code>` : ""}</div>
      <strong>${title}</strong>
      <p>${nickname} · ${archetype}</p>
      <small>${event}</small>
      <dl><div><dt>Proof</dt><dd>${score}</dd></div><div><dt>Loop</dt><dd>${loop}</dd></div></dl>
      <nav>${repoLink}${demoLink}<a href="${escapeHtml(profileUrl)}">Profile</a></nav>
    </article>`;
  }).join("");
  bindIdentityThemes(hackathonRoster);
}

function renderShareContract(contract) {
  if (!shareContractPanel || !contract) return;
  const neverPublic = Array.isArray(contract.neverPublic) ? contract.neverPublic : [];
  const publicCount = Number(contract.publicProofCount || 0);
  const unlistedCount = Number(contract.unlistedProofCount || 0);
  const privateCount = Number(contract.privateProofCount || 0);
  const leaderboardsUse = contract.leaderboardsUse || "public proof cards only";
  const tokenLookup = contract.tokenLookup || "public and unlisted tokens resolve directly; private proof tokens are disabled";
  const neverPublicText = neverPublic.length
    ? neverPublic.map((item) => item.replace(/([A-Z])/g, " $1").toLowerCase()).join(", ")
    : "raw transcripts, source code, credentials, private diffs, and env files";
  shareContractPanel.innerHTML = `
    <span>Public proof contract</span>
    <strong>Rankings use ${escapeHtml(leaderboardsUse)}.</strong>
    <p>${escapeHtml(tokenLookup)}. Never public: ${escapeHtml(neverPublicText)}.</p>
    <dl>
      <div><dt>Public</dt><dd>${publicCount} in feed</dd></div>
      <div><dt>Unlisted</dt><dd>${unlistedCount} direct link</dd></div>
      <div><dt>Private</dt><dd>${privateCount} owner only</dd></div>
    </dl>`;
}

function renderScoreboard(profiles, region = "Global") {
  if (!scoreboardList) return;
  const rows = Array.isArray(profiles) ? profiles.slice(0, 5) : [];
  if (scoreboardRegion) scoreboardRegion.textContent = region;
  if (!rows.length) {
    scoreboardList.innerHTML = `<a class="scoreboard-row is-empty" href="/docs">
      <span>0</span><strong>Waiting for first proof</strong><em>Run tokenbar submit</em><b>--</b>
    </a>`;
    return;
  }
  scoreboardList.innerHTML = rows.map((profile, index) => {
    const nickname = escapeHtml(profile.nickname || profile.title || "builder");
    const archetype = escapeHtml(profile.primaryArchetype || profile.bucket || "Builder");
    const submission = submissionForProfile(profile);
    const label = submission?.title || archetype;
    const score = Number(profile.score || profile.proofScore || profile.specificityScore || 0).toFixed(0);
    const href = profile.profileUrl || profile.proofCardUrl || profileHrefForToken(profile.token) || "/rankings";
    const theme = identityThemeFor(`${profile.primaryArchetype || ""} ${profile.npcClass || ""} ${profile.bucket || ""}`);
    return `<a class="scoreboard-row ${index === 0 ? "is-leading" : ""}" href="${escapeHtml(href)}" data-identity-theme="${theme}">
      <span>${index + 1}</span><strong>${nickname}<small>${escapeHtml(archetype)}</small></strong><em>${escapeHtml(label)}</em><b>${score}</b>
    </a>`;
  }).join("");
  bindIdentityThemes(scoreboardList);
}

function renderActionLoopRankings(entries) {
  if (!actionLoopRankings || !Array.isArray(entries) || !entries.length) return;
  actionLoopRankings.innerHTML = entries.slice(0, 6).map((profile, index) => {
    const title = escapeHtml(profile.title || profile.nickname || "Builder");
    const archetype = escapeHtml(profile.primaryArchetype || "Builder");
    const submission = submissionForProfile(profile);
    const loop = formatScore(profile.loopMaturity);
    const proof = formatScore(profile.proofScore);
    const signal = escapeHtml(profile.strongestSignal || "Evidence");
    const theme = identityThemeFor(`${profile.primaryArchetype || ""} ${profile.npcClass || ""}`);
    const href = proofHref(profile) || "#";
    return `<a class="action-loop-row" data-identity-theme="${theme}" href="${escapeHtml(href)}">
      <span>${index + 1}</span>
      <strong>${title}<small>${archetype} · ${signal}</small>${submission ? `<small class="ranking-project-line">${escapeHtml(submission.title || "Submitted project")}</small>` : ""}</strong>
      <em>Loop ${loop}<small>safe proof</small></em>
      <b>${proof}</b>
    </a>`;
  }).join("");
  bindIdentityThemes(actionLoopRankings);
}

function scoreForLeaderboard(profile, scoreKey) {
  if (!profile) return 0;
  if (profile[scoreKey] !== undefined && profile[scoreKey] !== null) return Number(profile[scoreKey]) || 0;
  const signals = profile.rankSignals || {};
  if (signals[scoreKey] !== undefined && signals[scoreKey] !== null) return Number(signals[scoreKey]) || 0;
  return Number(profile.score || profile.proofScore || profile.specificityScore || 0) || 0;
}

function renderRankingLeaderboards(leaderboards) {
  if (!rankingLeaderboards) return;
  const entries = Object.entries(leaderboards || {}).filter(([, board]) => Array.isArray(board?.items) && board.items.length);
  if (!entries.length) {
    rankingLeaderboards.innerHTML = `<article class="ranking-board-card is-empty"><h3>No public boards yet</h3><p>Run <code>tokenbar submit</code> to generate the first safe proof-card leaderboard entry with project context.</p></article>`;
    return;
  }
  rankingLeaderboards.innerHTML = entries.map(([key, board]) => {
    const scoreKey = board.scoreKey || "score";
    const items = board.items.slice(0, 5).map((profile, index) => {
      const title = escapeHtml(profile.nickname || profile.title || "Builder");
      const archetype = escapeHtml(profile.primaryArchetype || profile.npcClass || "Builder");
      const submission = submissionForProfile(profile);
      const score = scoreForLeaderboard(profile, scoreKey);
      const href = proofHref(profile) || "#";
      const theme = identityThemeFor(`${profile.primaryArchetype || ""} ${profile.npcClass || ""} ${profile.bucket || ""}`);
      return `<a class="ranking-board-row" href="${escapeHtml(href)}" data-identity-theme="${theme}">
        <span>${index + 1}</span>
        <strong>${title}<small>${archetype}</small>${submission ? `<small class="ranking-project-line">${escapeHtml(submission.title || "Submitted project")} · ${escapeHtml(submission.event || submission.track || "safe submission")}</small>` : ""}</strong>
        <b>${formatScore(score)}</b>
      </a>`;
    }).join("");
    return `<article class="ranking-board-card" data-board="${escapeHtml(key)}">
      <div><span>Public safe board</span><h3>${escapeHtml(board.label || key)}</h3><p>${escapeHtml(board.description || "Ranked from generated proof-card evidence only.")}</p></div>
      <div class="ranking-board-list">${items}</div>
    </article>`;
  }).join("");
  bindIdentityThemes(rankingLeaderboards);
}

function renderActionStats(payload) {
  const feed = Array.isArray(payload.feed) ? payload.feed : [];
  if (!feed.length) return;
  const average = (key) => feed.reduce((sum, item) => sum + (Number(item[key]) || 0), 0) / feed.length;
  const archetypeCounts = feed.reduce((acc, item) => {
    const key = item.primaryArchetype || "Builder";
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});
  const archetypePercentages = Object.fromEntries(
    Object.entries(archetypeCounts).map(([key, count]) => [key, (Number(count) / feed.length) * 100])
  );
  if (statsCount) statsCount.textContent = String(payload.proofCardCount ?? feed.length);
  if (statsSpecificity) statsSpecificity.textContent = `${average("proofScore").toFixed(0)}/100`;
  if (statsLoop) statsLoop.textContent = `${average("loopMaturity").toFixed(0)}/100`;
  if (statsCoverage) statsCoverage.textContent = `${Object.keys(archetypeCounts).length} active`;
  renderStatsRows(statsArchetypes, archetypeCounts, archetypePercentages);
  renderTopProfiles(statsTopProfiles, feed, { scoreKey: "score" });
  renderTopProfiles(statsTopLoopProfiles, payload.loopRankings || feed, { scoreKey: "loopMaturity" });
}

function renderRegion(region) {
  if (!regionList) return;
  const rows = regionalLeaderboards[region] || regionalLeaderboards.Global || [];
  if (!rows.length) {
    regionList.innerHTML = `<div class="region-row is-empty"><span>0</span><strong>No public proof yet</strong><em>Run tokenbar submit to enter</em><b>--</b></div>`;
    renderScoreboard([], region);
    return;
  }
  regionList.innerHTML = rows.slice(0, 10).map((profile, index) => {
    const nickname = escapeHtml(profile.nickname || profile.title || "builder");
    const archetype = escapeHtml(profile.primaryArchetype || "Builder");
    const submission = submissionForProfile(profile);
    const project = submission?.title || `${formatTokenCount(profile.tokenCount)} tokens`;
    const score = Number(profile.score || profile.specificityScore || 0).toFixed(0);
    const theme = identityThemeFor(`${archetype} ${profile.npcClass || ""} ${profile.bucket || ""}`);
    return `<div class="region-row" data-identity-theme="${theme}"><span>${index + 1}</span><strong>${nickname}</strong><em>${archetype} · ${escapeHtml(project)}</em><b>${score}</b></div>`;
  }).join("");
  bindIdentityThemes(regionList);
  renderScoreboard(rows, region);
}

regionTabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    regionTabs.forEach((item) => item.classList.toggle("is-active", item === tab));
    renderRegion(tab.dataset.regionTab || "Global");
  });
});

async function loadPublicStats() {
  if (!statsCount && !statsArchetypes && !statsNpcs && !socialFeed && !regionList && !scoreboardList && !statsTopLoopProfiles) return;
  try {
    const response = await fetch("/api/profiles", { headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const payload = await response.json();
    const stats = payload.stats || {};
    if (statsCount) statsCount.textContent = String(stats.profileCount ?? 0);
    if (statsSpecificity) statsSpecificity.textContent = `${stats.averageSpecificity ?? 0}/100`;
    if (statsLoop) statsLoop.textContent = `${stats.averageLoopMaturity ?? 0}/100`;
    if (statsCoverage) {
      const unique = Number(stats.uniqueLabelBucketCount) || 0;
      const total = Number(stats.labelSpaceSize) || 0;
      statsCoverage.textContent = total ? `${unique}/${total}` : "pending";
    }
    renderStatsRows(statsArchetypes, stats.archetypes, stats.archetypePercentages);
    renderStatsRows(statsNpcs, stats.npcClasses, stats.npcClassPercentages);
    renderStatsRows(statsBuckets, stats.labelBuckets, stats.labelBucketPercentages);
    renderBucketRanking(statsRarestBuckets, stats.publicRankings?.rarestBuckets || stats.rarestLabelBuckets);
    renderSignalRows(statsSessionSignals, stats.sessionSignalAverages);
    renderStatsRows(statsSpecificityBands, stats.specificityBands, stats.specificityBandPercentages);
    renderStatsRows(statsProviderCoverage, stats.providerCoverage, stats.providerCoveragePercentages);
    renderTopProfiles(statsTopProfiles, stats.topSpecificProfiles);
    const publicRankings = stats.publicRankings || {};
    renderTopProfiles(statsTopLoopProfiles, publicRankings.topLoopProfiles || [], { scoreKey: "loopMaturity" });
    const feed = publicRankings.socialFeed || stats.topSpecificProfiles || [];
    regionalLeaderboards = {
      Global: feed,
      ...(publicRankings.regionalLeaderboards || {}),
    };
    renderSocialFeed(feed);
    renderHackathonRoster(feed);
    renderRegion("Global");
  } catch {
    if (statsCount) statsCount.textContent = "offline";
    if (statsSpecificity) statsSpecificity.textContent = "local only";
    if (statsLoop) statsLoop.textContent = "local only";
    if (statsCoverage) statsCoverage.textContent = "local only";
  }
}

loadPublicStats();

async function loadActionFeed() {
  if (!socialFeed && !actionLoopRankings && !statsTopProfiles && !statsTopLoopProfiles && !statsCount && !scoreboardList && !regionList) return;
  try {
    const response = await fetch("/api/actions", { headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const payload = await response.json();
    if (Array.isArray(payload.feed) && payload.feed.length) {
      renderActionStats(payload);
      renderSocialFeed(payload.feed);
      renderHackathonRoster(payload.feed);
      renderShareContract(payload.shareContract);
      renderRankingLeaderboards(payload.leaderboards || {});
      regionalLeaderboards = {
        Global: payload.feed,
        ...(payload.regionalLeaderboards || {}),
      };
      renderRegion("Global");
    }
    renderActionLoopRankings(payload.loopRankings || []);
  } catch {
    // Static examples remain visible when the local action store is unavailable.
  }
}

loadActionFeed();

const atlasCards = Array.from(document.querySelectorAll("[data-atlas-card]"));
const atlasTitle = document.querySelector("[data-atlas-title]");
const atlasLine = document.querySelector("[data-atlas-line]");

function activateAtlasCard(card) {
  if (!card) return;
  atlasCards.forEach((item) => item.classList.toggle("is-active", item === card));
  if (atlasTitle) atlasTitle.textContent = card.dataset.title || "Builder profile";
  if (atlasLine) atlasLine.textContent = card.dataset.line || "";
}

atlasCards.forEach((card) => {
  card.addEventListener("click", () => activateAtlasCard(card));
  card.addEventListener("pointerenter", () => activateAtlasCard(card));
});

const revealItems = Array.from(document.querySelectorAll("[data-reveal]"));

if (revealItems.length && "IntersectionObserver" in window) {
  document.documentElement.classList.add("reveal-ready");
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    },
    { threshold: 0.04, rootMargin: "0px 0px -2% 0px" },
  );

  revealItems.forEach((item, index) => {
    item.style.setProperty("--reveal-delay", `${Math.min(index * 45, 220)}ms`);
    observer.observe(item);
  });

  window.setTimeout(() => {
    revealItems.forEach((item) => item.classList.add("is-visible"));
  }, 1200);
} else {
  revealItems.forEach((item) => item.classList.add("is-visible"));
}

function setLookupState(form, message, state = "idle") {
  const target = form.querySelector("[data-profile-lookup-state]") || document.querySelector("[data-profile-lookup-state]");
  if (!target) return;
  target.textContent = message;
  target.dataset.state = state;
}

function setReceiptState(form, message, state = "idle") {
  const target = form.querySelector("[data-proof-receipt-state]");
  if (!target) return;
  target.textContent = message;
  target.dataset.state = state;
}

function normalizeReceiptSurfaceEntries(receipt) {
  const surfaces = receipt?.surfaces || {};
  return Object.entries(surfaces)
    .filter(([, url]) => typeof url === "string" && url.trim())
    .map(([key, url]) => {
      const labels = {
        proofCard: "Proof card",
        publicProfile: "Public profile",
        socialFeed: "For You feed",
        rankings: "Leaderboards",
        loopRankings: "Loop rankings",
        privateAudit: "Private audit",
      };
      return { key, label: labels[key] || key, url };
    });
}

function renderLocalProofReceipt(form, receipt) {
  const preview = form.querySelector("[data-proof-receipt-preview]");
  if (!preview) return;
  const schema = receipt?.schema;
  if (schema !== "tokenbar.local_proof_receipt.v1") {
    throw new Error("This is not a TokenBar local proof receipt.");
  }
  const privacy = receipt.privacy || {};
  if (privacy.rawTranscriptsUploaded || privacy.sourceCodeUploaded) {
    throw new Error("Receipt privacy flags are unsafe. Raw transcripts or source code appear to be included.");
  }
  const surfaces = normalizeReceiptSurfaceEntries(receipt);
  const shareMode = receipt.shareMode || "public";
  const redactions = Object.entries(receipt.redactions || {})
    .filter(([, enabled]) => enabled)
    .map(([key]) => key.replace(/([A-Z])/g, " $1").toLowerCase());
  const publicSurfaces = surfaces.filter((surface) => surface.key !== "privateAudit");
  const visibleSurfaces = shareMode === "private" ? surfaces.filter((surface) => surface.key === "privateAudit") : publicSurfaces;
  const shareReceipt = receipt.shareReceipt || {};
  const token = receipt.token || "";
  const runId = receipt.runId || "";
  const receiptTitle = receipt.identity || "Builder Identity";
  preview.innerHTML = `
    <article class="receipt-card" data-identity-theme="${identityThemeFor(receiptTitle)}">
      <div class="receipt-card-top">
        <span>${escapeHtml(shareMode)} receipt</span>
        <code>${escapeHtml(token || runId || "local-only")}</code>
      </div>
      <strong>${escapeHtml(receiptTitle)}</strong>
      <p>Proof ${formatScore(receipt.proofScore)}/100 · loop maturity ${formatScore(receipt.loopMaturity)}/100. Raw transcripts uploaded: <b>no</b>. Source code uploaded: <b>no</b>.</p>
      <div class="receipt-surface-grid">
        ${visibleSurfaces.length
          ? visibleSurfaces.map((surface) => `<a href="${escapeHtml(surface.url)}"><b>${escapeHtml(surface.label)}</b><small>${escapeHtml(surface.url)}</small></a>`).join("")
          : `<span><b>No public surface</b><small>This receipt is private or local-only.</small></span>`}
      </div>
      <div class="receipt-boundary">
        <span>No raw transcripts</span>
        <span>No source code</span>
        <span>${escapeHtml((privacy.uploaded || "generated proof card + aggregate identity fields"))}</span>
        ${redactions.length ? `<span>Redacted: ${escapeHtml(redactions.join(", "))}</span>` : ""}
      </div>
      ${shareReceipt.schema ? `<small class="receipt-schema">${escapeHtml(shareReceipt.schema)} · ${escapeHtml(shareReceipt.shareMode || shareMode)}</small>` : ""}
      ${receipt.shareCopy ? `<button type="button" data-share-proof data-share-url="${escapeHtml(visibleSurfaces[0]?.url || "")}" data-share-text="${escapeHtml(receipt.shareCopy)}">Copy share text</button>` : ""}
    </article>`;
  bindIdentityThemes(preview);
  bindShareProofButtons(preview);
}

proofReceiptForms.forEach((form) => {
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const raw = String(new FormData(form).get("receipt") || "").trim();
    if (!raw) {
      setReceiptState(form, "Paste the JSON from tokenbar proof latest --json first.", "error");
      return;
    }
    try {
      renderLocalProofReceipt(form, JSON.parse(raw));
      setReceiptState(form, "Receipt preview is local and safe. Choose a surface or copy the share text.", "ok");
    } catch (error) {
      setReceiptState(form, error?.message || "Could not parse that receipt JSON.", "error");
    }
  });
});

function setSubmissionState(form, message, state = "idle") {
  const target = form.querySelector("[data-submission-update-state]");
  if (!target) return;
  target.textContent = message;
  target.dataset.state = state;
}

function renderSubmissionUpdatePreview(form, payload) {
  const preview = form.querySelector("[data-submission-update-preview]");
  if (!preview) return;
  const submission = payload?.submission || {};
  const token = payload?.token || "";
  const profileUrl = payload?.shareUrl || (token ? `/api/profiles?token=${encodeURIComponent(token)}` : "");
  const socialUrl = payload?.socialUrl || "/social";
  const rankingsUrl = payload?.rankingsUrl || "/rankings";
  preview.innerHTML = `
    <article class="submission-preview-card" data-identity-theme="${identityThemeFor(submission.projectTitle || payload?.profile?.title || "Builder")}">
      <span>Submission attached</span>
      <strong>${escapeHtml(submission.projectTitle || "Submitted project")}</strong>
      ${submission.tagline ? `<p>${escapeHtml(submission.tagline)}</p>` : ""}
      <small>${escapeHtml([submission.event, submission.track].filter(Boolean).join(" · ") || "Independent build")}</small>
      <div>
        ${profileUrl ? `<a href="${escapeHtml(profileUrl)}">Profile</a>` : ""}
        <a href="${escapeHtml(socialUrl)}">For You feed</a>
        <a href="${escapeHtml(rankingsUrl)}">Rankings</a>
      </div>
      <em>No raw repo upload · No transcripts · Public metadata only</em>
    </article>`;
  bindIdentityThemes(preview);
}

function formValue(form, name) {
  return String(new FormData(form).get(name) || "").trim();
}

submissionUpdateForms.forEach((form) => {
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const token = formValue(form, "token");
    if (!/^TBAR-[A-Za-z0-9._-]+$/.test(token)) {
      setSubmissionState(form, "Paste a valid TBAR token first.", "error");
      return;
    }
    const body = {
      schema: "tokenbar.hackathon_submission_update.v1",
      token,
      visibility: formValue(form, "visibility") || "public",
      hackathonSubmission: {
        schema: "tokenbar.hackathon_submission.v1",
        projectTitle: formValue(form, "projectTitle") || "Untitled project",
        tagline: formValue(form, "tagline"),
        event: formValue(form, "event") || "Independent build",
        track: formValue(form, "track") || "Builder identity",
        repoUrl: formValue(form, "repoUrl"),
        demoUrl: formValue(form, "demoUrl"),
        submittedAt: new Date().toISOString(),
        privacy: {
          rawRepoUploaded: false,
          sourceCodeUploaded: false,
          rawTranscriptsUploaded: false,
          publicMetadataOnly: true,
        },
      },
    };
    setSubmissionState(form, "Attaching safe project metadata to this proof token...", "loading");
    try {
      const response = await fetch("/api/profiles", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify(body),
      });
      const payload = await response.json();
      if (!response.ok || !payload.ok) {
        throw new Error(payload.error || `HTTP ${response.status}`);
      }
      renderSubmissionUpdatePreview(form, payload);
      setSubmissionState(form, "Project attached. Public surfaces now use safe project metadata only.", "ok");
    } catch (error) {
      setSubmissionState(form, error?.message || "Could not attach project metadata.", "error");
    }
  });
});

function surfaceHref(profile, key, fallback) {
  const value = profile?.[key] || profile?.actionLinks?.[key];
  return value || fallback || "";
}

function renderTokenSurfaceLauncher(form, token, profile) {
  const scope = form.closest(".profile-panel") || document;
  const launcher = scope.querySelector("[data-token-surface-launcher]") || document.querySelector("[data-token-surface-launcher]");
  if (!launcher) return false;
  const bundle = profile?.surfaceBundle || {};
  const bundleSurfaces = Array.isArray(bundle.surfaces) ? bundle.surfaces : [];
  const fallbackSurfaces = [
    {
      key: "proofCard",
      label: "Proof card",
      description: "60-second evidence surface",
      url: surfaceHref(profile, "proofCardUrl", `/api/actions?token=${encodeURIComponent(token)}`),
    },
    {
      key: "publicProfile",
      label: "Public profile",
      description: "identity narrative and receipt",
      url: surfaceHref(profile, "profileUrl", `/api/profiles?token=${encodeURIComponent(token)}`),
    },
    {
      key: "socialFeed",
      label: "For You feed",
      description: "shipped-work story card",
      url: surfaceHref(profile, "socialUrl", `/social?token=${encodeURIComponent(token)}`),
    },
    {
      key: "rankings",
      label: "Rankings",
      description: "loop and category boards",
      url: surfaceHref(profile, "rankingsUrl", `/rankings?token=${encodeURIComponent(token)}`),
    },
    {
      key: "loopRankings",
      label: "Loop rankings",
      description: "agent-loop maturity board",
      url: surfaceHref(profile, "loopRankingsUrl", `/rankings?token=${encodeURIComponent(token)}#loop`),
    },
  ];
  const surfaces = (bundleSurfaces.length ? bundleSurfaces : fallbackSurfaces)
    .filter((surface) => surface && surface.url)
    .slice(0, 6);
  const publicProfileSurface = surfaces.find((surface) => surface.key === "publicProfile") || surfaces[0] || {};
  const profileUrl = publicProfileSurface.url || `/api/profiles?token=${encodeURIComponent(token)}`;
  const shareCopy = bundle.shareCopy || profile?.shareCopy || `TokenBar builder proof ${token}: ${profileUrl}`;
  const neverPublic = bundle?.privacyBoundary?.neverPublic || ["raw transcripts", "source code", "credentials", "private diffs", "env files"];
  const submission = submissionForProfile(profile);
  const safeEvidenceReceipt = profile?.safeEvidenceReceipt || {};
  const safeReceipt = safeEvidenceReceipt.schema
    ? `<div class="token-safe-receipt" aria-label="Safe evidence receipt">
        <b>Safe evidence receipt</b>
        <span>${escapeHtml(safeEvidenceReceipt.publicMaterial || "safe aggregate proof only")}</span>
        <small>Never used: ${escapeHtml((safeEvidenceReceipt.neverUsed || []).slice(0, 5).join(", ") || neverPublic.join(", "))}</small>
      </div>`
    : "";
  launcher.innerHTML = `
    <span>Proof bundle unlocked</span>
    <strong>${escapeHtml(profile?.title || profile?.primaryArchetype || "TokenBar builder profile")}</strong>
    <p>Safe public surfaces for <code>${escapeHtml(token)}</code>. ${escapeHtml(neverPublic.join(", "))} stay out of this bundle.</p>
    ${renderTokenProofPassport(profile, token)}
    ${renderTokenSubmissionSummary(submission)}
    <div class="token-surface-grid">
      ${surfaces.map((surface) => `
        <a href="${escapeHtml(surface.url)}">
          <b>${escapeHtml(surface.label || surface.key || "Proof surface")}</b>
          <small>${escapeHtml(surface.description || "safe aggregate evidence")}</small>
        </a>
      `).join("")}
    </div>
    ${safeReceipt}
    <button type="button" data-share-proof data-share-url="${escapeHtml(profileUrl)}" data-share-text="${escapeHtml(shareCopy)}">Copy share preview</button>`;
  bindShareProofButtons(launcher);
  return true;
}

async function activateProfileToken(form, token) {
  const encoded = encodeURIComponent(token);
  setLookupState(form, "Checking safe profile token...", "loading");
  const profileResponse = await fetch(`/api/profiles?token=${encoded}`, { headers: { Accept: "application/json" } });
  if (profileResponse.ok) {
    const profilePayload = await profileResponse.json();
    const profile = profilePayload.profile || profilePayload || {};
    const renderedLauncher = renderTokenSurfaceLauncher(form, token, profile);
    rememberPublicToken(token, profile);
    setLookupState(form, renderedLauncher ? "Profile found. Choose a proof surface below." : "Profile found. Opening proof surface...", "ok");
    if (!renderedLauncher) window.location.href = `/api/profiles?token=${encoded}`;
    return;
  }

  let actionPayload = {};
  try {
    const actionResponse = await fetch(`/api/actions?token=${encoded}`, { headers: { Accept: "application/json" } });
    actionPayload = await actionResponse.json();
  } catch {
    actionPayload = {};
  }

  const error = String(actionPayload.error || "").toLowerCase();
  if (error.includes("private proof")) {
    setLookupState(form, "This token is private. Ask the owner for a public or unlisted proof, or inspect the run id instead.", "error");
    return;
  }

  setLookupState(form, "No public profile found for that token. Check the TBAR token or ask the builder to run tokenbar submit.", "error");
}

function tokenFromLocation() {
  const search = new URLSearchParams(window.location.search || "");
  const hashText = (window.location.hash || "").replace(/^#/, "");
  const hash = new URLSearchParams(hashText);
  const raw = search.get("token") || search.get("t") || hash.get("token") || hash.get("t") || "";
  const token = String(raw).trim();
  return /^TBAR-[A-Za-z0-9._-]+$/.test(token) ? token : "";
}

function rememberPublicToken(token, profile) {
  if (!token || typeof localStorage === "undefined") return;
  try {
    localStorage.setItem(
      "tokenbar:lastPublicToken",
      JSON.stringify({
        token,
        title: profile?.title || profile?.primaryArchetype || "TokenBar builder profile",
        savedAt: Date.now(),
      }),
    );
  } catch {
    // Local storage can be disabled; token lookup still works without it.
  }
}

function readRememberedPublicToken() {
  if (typeof localStorage === "undefined") return null;
  try {
    const parsed = JSON.parse(localStorage.getItem("tokenbar:lastPublicToken") || "null");
    if (!parsed || !/^TBAR-[A-Za-z0-9._-]+$/.test(String(parsed.token || ""))) return null;
    return parsed;
  } catch {
    return null;
  }
}

function renderRememberedTokenShortcut(form) {
  const remembered = readRememberedPublicToken();
  if (!remembered || !form || form.dataset.rememberedTokenReady === "1") return;
  const state = form.querySelector("[data-profile-lookup-state]");
  const input = form.querySelector('input[name="token"]');
  if (!state || !input) return;
  const shortcut = document.createElement("button");
  shortcut.type = "button";
  shortcut.className = "token-reopen-button";
  shortcut.textContent = `Open last proof ${remembered.token}`;
  shortcut.addEventListener("click", async () => {
    input.value = remembered.token;
    try {
      await activateProfileToken(form, remembered.token);
    } catch {
      setLookupState(form, "Could not reopen the saved proof token. Try again after the TokenBar server is running.", "error");
    }
  });
  state.insertAdjacentElement("afterend", shortcut);
  form.dataset.rememberedTokenReady = "1";
}

const profileLookupForms = Array.from(document.querySelectorAll("[data-profile-lookup]"));

profileLookupForms.forEach((profileLookup) => {
  profileLookup.addEventListener("submit", async (event) => {
    event.preventDefault();
    const formData = new FormData(profileLookup);
    const token = String(formData.get("token") || "").trim();
    if (!token) {
      setLookupState(profileLookup, "Paste a token first, for example TBAR-...", "error");
      return;
    }
    if (!/^TBAR-[A-Za-z0-9._-]+$/.test(token)) {
      setLookupState(profileLookup, "That does not look like a TokenBar identity token yet.", "error");
      return;
    }
    try {
      await activateProfileToken(profileLookup, token);
    } catch {
      setLookupState(profileLookup, "Could not reach the profile server. Try again after the local or hosted TokenBar server is running.", "error");
    }
  });
});

async function autoActivateProfileToken() {
  const token = tokenFromLocation();
  const form = profileLookupForms[0];
  if (!form) return;
  if (!token) {
    renderRememberedTokenShortcut(form);
    return;
  }
  const input = form.querySelector('input[name="token"]');
  if (input) input.value = token;
  try {
    await activateProfileToken(form, token);
  } catch {
    setLookupState(form, "Could not auto-open that profile token. Try again after the TokenBar server is running.", "error");
  }
}

autoActivateProfileToken();

const actionLookup = document.querySelector("[data-action-lookup]");
const actionLookupState = document.querySelector("[data-action-lookup-state]");
const actionResult = document.querySelector("[data-action-result]");

function renderProofAction(data) {
  if (!actionResult) return;
  const run = data?.run;
  const proof = data?.proof || run?.proof;
  const story = proof?.builderStory || {};
  const stages = run?.stages || data?.stages || [];
  if (!proof && !run) {
    actionResult.innerHTML = "";
    return;
  }
  const stageHtml = stages.length
    ? `<section class="proof-stage-section"><h4>Reloadable action stages</h4><ol class="proof-action-stages">${stages.map((item) => `<li><strong>${escapeHtml(item.name || "stage")}</strong><span>${escapeHtml(item.note || item.status || "")}</span></li>`).join("")}</ol></section>`
    : "";
  const facts = Array.isArray(proof?.facts)
    ? proof.facts.slice(0, 4).map((fact) => `<li><span>${escapeHtml(fact.label || "")}</span><strong>${escapeHtml(fact.value || "")}</strong><small>${escapeHtml(fact.note || "")}</small></li>`).join("")
    : "";
  const axes = Array.isArray(story?.axes)
    ? story.axes.map((axis) => `<li><span>${escapeHtml(axis.label || "")}</span><strong>${Number(axis.score || 0).toFixed(0)}</strong><small>${escapeHtml(axis.claim || "")}</small><em>${escapeHtml(axis.confidence || "low")} confidence</em></li>`).join("")
    : "";
  const proved = Array.isArray(story?.whatProved)
    ? story.whatProved.map((item) => `<li>${escapeHtml(item)}</li>`).join("")
    : "";
  const shippedWork = Array.isArray(story?.shippedWork)
    ? story.shippedWork.slice(0, 4).map((item) => {
      const label = escapeHtml(item.label || "Evidence");
      const value = escapeHtml(item.value || "");
      const note = item.note ? `<small>${escapeHtml(item.note)}</small>` : "";
      const provenance = item.provenance ? `<em>${escapeHtml(item.provenance)}</em>` : "";
      return `<span><b>${label}</b><strong>${value}</strong>${note}${provenance}</span>`;
    }).join("")
    : "";
  const uncertain = Array.isArray(story?.uncertainties)
    ? story.uncertainties.map((item) => `<li>${escapeHtml(item)}</li>`).join("")
    : "";
  const privacy = proof?.privacy || {};
  const rawState = privacy.rawTranscriptsIncluded === false ? "Redacted" : "Check required";
  const sourceState = privacy.sourceCodeIncluded === false ? "Redacted" : "Check required";
  const artifactState = privacy.uploadedArtifact || "generated proof artifact";
  const shareMode = proof?.publicVisibility || privacy.shareMode || proof?.shareControls?.visibility || "public";
  const redactions = privacy.redactions || proof?.shareControls?.redactions || {};
  const redactionState = Object.entries(redactions)
    .filter(([, enabled]) => Boolean(enabled))
    .map(([name]) => name)
    .join(", ") || "none";
  const selfComparison = proof?.selfComparison || {};
  const selfComparisonCards = Array.isArray(selfComparison.cards)
    ? selfComparison.cards.map((card) => `<li><span>${escapeHtml(card.label || "Self signal")}</span><strong>${escapeHtml(card.value || "")}</strong><small>${escapeHtml(card.note || "")}</small></li>`).join("")
    : "";
  const selfComparisonHtml = selfComparisonCards
    ? `<section class="proof-story-selective"><h4>Compared to yourself over time</h4><p>${escapeHtml(selfComparison.basis || "Safe aggregate windows only.")}</p><ul class="proof-fact-grid">${selfComparisonCards}</ul><p>${escapeHtml(selfComparison.uncertainty || "Multiple claims make this trend sharper.")}</p></section>`
    : "";
  const receipt = proof?.verificationReceipt || {};
  const receiptRedactions = receipt.redactions || redactions || {};
  const receiptRedactionState = Object.entries(receiptRedactions)
    .filter(([, enabled]) => Boolean(enabled))
    .map(([name]) => name)
    .join(", ") || "none";
  const receiptHtml = receipt.schema
    ? `<section class="proof-verification-receipt">
        <h4>Verification receipt</h4>
        <p>This proof was generated from safe aggregate identity data only. It does not include raw transcripts, source code, private diffs, or credentials.</p>
        <div>
          <span><b>Run</b>${escapeHtml(receipt.runId || run?.runId || "")}</span>
          <span><b>Stages</b>${escapeHtml(String(receipt.stageCount || stages.length || 0))}</span>
          <span><b>Share</b>${escapeHtml(String(receipt.shareMode || shareMode))}</span>
          <span><b>Redactions</b>${escapeHtml(receiptRedactionState)}</span>
          <span><b>Ranking</b>${escapeHtml(receipt.rankingPolicy?.antiPayToWin || "Token volume is capped.")}</span>
        </div>
      </section>`
    : "";
  actionResult.innerHTML = `
    <div class="proof-action-card" data-proof-mode="public">
      <span>${escapeHtml(run?.runId || proof?.token || "proof card")}</span>
      <h3>${escapeHtml(proof?.title || run?.result?.summary || "Builder proof card")}</h3>
      <p>${escapeHtml(proof?.verdict || run?.result?.nextAction || "Proof action is ready.")}</p>
      <div class="proof-share-controls" aria-label="Share preview mode">
        <button type="button" data-proof-view="public">Public</button>
        <button type="button" data-proof-view="selective">Selective</button>
        <button type="button" data-proof-view="private">Private</button>
      </div>
      <div class="proof-mode-guide">
        <section class="proof-mode-public"><strong>Public view</strong><span>Shows headline, proof score, safe facts, profile links, and no private session text.</span></section>
        <section class="proof-mode-selective"><strong>Selective view</strong><span>Adds what the run proves and the share copy you can paste into a portfolio, application, or social post.</span></section>
        <section class="proof-mode-private"><strong>Private view</strong><span>Adds axes, uncertainty, and diagnosis for the builder. This is for self-review before sharing.</span></section>
      </div>
      <div class="proof-redaction-strip">
        <span><b>Raw transcripts</b>${escapeHtml(rawState)}</span>
        <span><b>Source code</b>${escapeHtml(sourceState)}</span>
        <span><b>Share mode</b>${escapeHtml(String(shareMode))}</span>
        <span><b>Redactions</b>${escapeHtml(String(redactionState))}</span>
        <span><b>Uploaded artifact</b>${escapeHtml(String(artifactState))}</span>
      </div>
      ${facts ? `<ul class="proof-fact-grid">${facts}</ul>` : ""}
      ${story?.headline ? `<section class="proof-builder-story"><h4>${escapeHtml(story.headline)}</h4><p>${escapeHtml(story.summary || "")}</p></section>` : ""}
      ${selfComparisonHtml}
      ${axes ? `<section class="proof-story-private"><h4>Identity axes</h4><ul class="proof-axis-grid">${axes}</ul></section>` : ""}
      ${proved ? `<section class="proof-story-selective"><h4>What this proves</h4><ol>${proved}</ol></section>` : ""}
      ${shippedWork ? `<section class="proof-story-selective"><h4>Shipped-work receipt</h4><div class="proof-shipped-work">${shippedWork}</div></section>` : ""}
      ${uncertain ? `<section class="proof-story-private"><h4>Uncertainty to keep honest</h4><ol>${uncertain}</ol></section>` : ""}
      ${receiptHtml}
      ${proof?.shareCopy ? `<div class="proof-share-preview"><strong>Share preview</strong><p>${escapeHtml(proof.shareCopy)}</p></div>` : ""}
      ${stageHtml}
      <div class="proof-action-links">
        ${proof?.proofCardUrl ? `<a href="${escapeHtml(proof.proofCardUrl)}">Open proof card</a>` : ""}
        ${proof?.profileUrl ? `<a href="${escapeHtml(proof.profileUrl)}">Open profile</a>` : ""}
      </div>
    </div>
  `;
  const card = actionResult.querySelector("[data-proof-mode]");
  actionResult.querySelectorAll("[data-proof-view]").forEach((button) => {
    button.addEventListener("click", () => {
      const mode = button.getAttribute("data-proof-view") || "public";
      if (card) card.setAttribute("data-proof-mode", mode);
    });
  });
}

if (actionLookup) {
  actionLookup.addEventListener("submit", async (event) => {
    event.preventDefault();
    const formData = new FormData(actionLookup);
    const value = String(formData.get("action") || "").trim();
    if (!value) {
      if (actionLookupState) actionLookupState.textContent = "Paste a run id or TokenBar token first.";
      return;
    }
    const isRun = /^run_[A-Za-z0-9._-]+$/.test(value);
    const isToken = /^TBAR-[A-Za-z0-9._-]+$/.test(value);
    if (!isRun && !isToken) {
      if (actionLookupState) actionLookupState.textContent = "Expected a run_... id or TBAR-... token.";
      return;
    }
    if (actionLookupState) actionLookupState.textContent = "Checking proof action...";
    try {
      const query = isRun ? `run=${encodeURIComponent(value)}` : `token=${encodeURIComponent(value)}`;
      const response = await fetch(`/api/actions?${query}`, { headers: { Accept: "application/json" } });
      const data = await response.json();
      if (!response.ok || !data.ok) throw new Error(data.error || "Proof action not found.");
      renderProofAction(data);
      if (actionLookupState) actionLookupState.textContent = "Proof action loaded.";
    } catch (error) {
      if (actionLookupState) actionLookupState.textContent = error.message || "Could not load that proof action.";
      renderProofAction(null);
    }
  });
}

const identityCreateForm = document.querySelector("[data-identity-create]");
const identityCreateState = document.querySelector("[data-identity-create-state]");
const identityCreatePreview = document.querySelector("[data-identity-create-preview]");
const identityFileName = document.querySelector("[data-identity-file-name]");
const identityShareContract = document.querySelector("[data-identity-share-contract]");
const identityRetryButton = document.querySelector("[data-identity-retry]");

function setIdentityCreateStage(name, state, note) {
  const stage = document.querySelector(`[data-identity-stage="${name}"]`);
  if (!stage) return;
  stage.dataset.state = state;
  const detail = stage.querySelector("small");
  if (detail) detail.textContent = note;
}

function resetIdentityCreateStages() {
  ["artifact", "privacy", "passport", "share"].forEach((name) => setIdentityCreateStage(name, "waiting", "Waiting"));
}

function renderIdentityCreatePreview(payload, visibility) {
  if (!identityCreatePreview) return;
  const proof = payload?.proof || {};
  const receipt = proof?.safeEvidenceReceipt || {};
  const token = String(proof?.token || payload?.token || "");
  const title = String(proof?.title || "Builder identity passport");
  const archetype = String(proof?.primaryArchetype || proof?.builderStory?.headline || "Safe aggregate proof");
  const score = Number(proof?.proofScore || proof?.specificityScore || 0);
  const shareUrl = String(proof?.profileUrl || proof?.proofCardUrl || "");
  const shareCopy = String(proof?.shareCopy || `TokenBar builder identity: ${title}`);
  const excluded = Array.isArray(receipt?.neverUsed) ? receipt.neverUsed.slice(0, 2).join(" and ") : "raw transcripts and source code";
  identityCreatePreview.innerHTML = `
    <article class="identity-create-preview-card" data-identity-passport tabindex="-1">
      <div><span>${escapeHtml(visibility)} passport preview</span><strong>${escapeHtml(title)}</strong><p>${escapeHtml(archetype)}</p></div>
      <dl><div><dt>Proof</dt><dd>${Number.isFinite(score) ? score.toFixed(0) : "—"}/100</dd></div><div><dt>Token</dt><dd>${escapeHtml(token || "generated")}</dd></div></dl>
      <p class="identity-preview-boundary">Safe aggregate evidence only. Never used: ${escapeHtml(excluded)}.</p>
      <div class="identity-preview-actions">
        ${shareUrl ? `<a href="${escapeHtml(shareUrl)}">Open ${escapeHtml(visibility)} proof</a>` : ""}
        <button type="button" data-share-proof data-share-url="${escapeHtml(shareUrl)}" data-share-text="${escapeHtml(shareCopy)}">Copy share preview</button>
      </div>
    </article>`;
  bindShareProofButtons(identityCreatePreview);
}

if (identityCreateForm) {
  const artifactInput = identityCreateForm.querySelector('input[name="artifact"]');
  const identitySubmit = identityCreateForm.querySelector('button[type="submit"]');
  const identityVisibilityInputs = identityCreateForm.querySelectorAll('input[name="visibility"]');
  const MAX_IDENTITY_ARTIFACT_BYTES = 240_000;
  let identityArtifactIsSafe = false;
  let identityArtifactSelectionKey = "";

  function createIdentityArtifactSelectionKey() {
    const random = globalThis.crypto?.randomUUID?.();
    return random || `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  }

  function setIdentitySubmitEnabled(enabled) {
    if (!identitySubmit) return;
    identitySubmit.disabled = !enabled;
    identitySubmit.setAttribute("aria-disabled", String(!enabled));
  }

  function setIdentityRetryVisible(visible) {
    if (!identityRetryButton) return;
    identityRetryButton.hidden = !visible;
    identityRetryButton.disabled = !visible;
  }

  function setIdentityGenerationPending(pending) {
    identityCreateForm.setAttribute("aria-busy", String(pending));
    if (artifactInput) artifactInput.disabled = pending;
    identityVisibilityInputs.forEach((input) => { input.disabled = pending; });
    if (pending) setIdentitySubmitEnabled(false);
    else setIdentitySubmitEnabled(identityArtifactIsSafe);
  }

  function selectedIdentityVisibility() {
    return String(new FormData(identityCreateForm).get("visibility") || "unlisted");
  }

  function renderIdentityShareContract() {
    if (!identityShareContract) return;
    if (!identityArtifactIsSafe) {
      identityShareContract.hidden = true;
      identityShareContract.innerHTML = "";
      return;
    }
    const visibility = selectedIdentityVisibility();
    const contracts = {
      private: "No token, proof link, profile, feed, or ranking entry is created. This remains a review-only passport.",
      unlisted: "A direct-link proof and token are created, but it stays out of public discovery, feeds, and rankings.",
      public: "The share card can show its title, archetype, proof score, and token in TokenBar discovery."
    };
    identityShareContract.hidden = false;
    identityShareContract.innerHTML = `<strong>${escapeHtml(visibility)} share contract</strong><p>${escapeHtml(contracts[visibility])} Raw transcripts, source code, credentials, private diffs, and local paths stay excluded.</p>`;
  }

  function announceIdentityVisibility() {
    if (!identityArtifactIsSafe || !identityCreateState) return;
    const messages = {
      private: "Private keeps this passport out of token, profile, feed, and ranking lookups.",
      unlisted: "Unlisted creates a direct-link passport and keeps it out of public discovery.",
      public: "Public creates a share card that can appear in TokenBar discovery."
    };
    identityCreateState.textContent = `${messages[selectedIdentityVisibility()]} Raw transcripts and source code remain excluded.`;
    renderIdentityShareContract();
  }

  setIdentitySubmitEnabled(false);
  setIdentityRetryVisible(false);
  identityRetryButton?.addEventListener("click", () => {
    if (!identityArtifactIsSafe || identityCreateForm.getAttribute("aria-busy") === "true") return;
    setIdentityRetryVisible(false);
    identityCreateForm.requestSubmit();
  });
  identityVisibilityInputs.forEach((input) => input.addEventListener("change", announceIdentityVisibility));
  artifactInput?.addEventListener("change", async () => {
    const file = artifactInput.files?.[0];
    if (identityFileName) identityFileName.textContent = file ? file.name : "Choose generated identity JSON";
    // A previous passport belongs only to its already-checked artifact. Do not
    // leave its share link visible while a replacement is being inspected.
    if (identityCreatePreview) identityCreatePreview.innerHTML = "";
    setIdentityRetryVisible(false);
    resetIdentityCreateStages();
    setIdentityRetryVisible(false);
    identityArtifactIsSafe = false;
    identityArtifactSelectionKey = file ? createIdentityArtifactSelectionKey() : "";
    setIdentitySubmitEnabled(false);
    renderIdentityShareContract();
    if (!file) {
      if (identityCreateState) identityCreateState.textContent = "Nothing leaves this page until you choose an identity JSON and privacy mode.";
      return;
    }
    if (file.size > MAX_IDENTITY_ARTIFACT_BYTES) {
      setIdentityCreateStage("artifact", "error", "Too large to inspect");
      setIdentityCreateStage("privacy", "error", "Not uploaded");
      if (identityCreateState) identityCreateState.textContent = "Choose a generated identity JSON smaller than 240 KB. It was not read or uploaded.";
      return;
    }
    setIdentityCreateStage("artifact", "active", "Checking locally");
    if (identityCreateState) identityCreateState.textContent = "Checking the selected artifact locally. Nothing has been uploaded.";
    try {
      const identity = JSON.parse(await file.text());
      if (artifactInput.files?.[0] !== file) return;
      if (identity?.schema !== "tokenbar.identity.v1") throw new Error("Choose a generated tokenbar.identity.v1 JSON artifact.");
      setIdentityCreateStage("artifact", "complete", "Safe JSON selected");
      setIdentityCreateStage("privacy", "active", "Checking boundary");
      const privacy = identity?.privacy || {};
      if (privacy.rawTranscriptsIncluded !== false || privacy.sourceCodeIncluded !== false) {
        throw new Error("This artifact does not declare both raw transcripts and source code as excluded.");
      }
      setIdentityCreateStage("privacy", "complete", "Raw text and source excluded");
      identityArtifactIsSafe = true;
      setIdentitySubmitEnabled(true);
      announceIdentityVisibility();
    } catch (error) {
      if (artifactInput.files?.[0] !== file) return;
      setIdentityCreateStage("artifact", "error", "Choose another file");
      setIdentityCreateStage("privacy", "error", "Not uploaded");
      if (identityCreateState) identityCreateState.textContent = error?.message || "Could not read that identity artifact locally.";
    }
  });

  identityCreateForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    const file = artifactInput?.files?.[0];
    if (!file || !identityArtifactIsSafe) {
      if (identityCreateState) identityCreateState.textContent = file ? "Wait for the local privacy check to finish before generating a passport." : "Choose a generated identity JSON first.";
      return;
    }
    const submittedSelectionKey = identityArtifactSelectionKey;
    resetIdentityCreateStages();
    setIdentityCreateStage("artifact", "active", "Reading locally");
    if (identityCreateState) identityCreateState.textContent = "Reading the selected artifact locally…";
    if (identityCreatePreview) identityCreatePreview.innerHTML = "";
    let passportRequestStarted = false;
    setIdentityGenerationPending(true);
    try {
      const identity = JSON.parse(await file.text());
      if (artifactInput?.files?.[0] !== file || identityArtifactSelectionKey !== submittedSelectionKey) {
        throw new Error("The selected artifact changed. Review its local privacy check before generating a passport.");
      }
      if (identity?.schema !== "tokenbar.identity.v1") throw new Error("Choose a generated tokenbar.identity.v1 JSON artifact.");
      setIdentityCreateStage("artifact", "complete", "Safe JSON selected");
      setIdentityCreateStage("privacy", "active", "Checking boundary");
      const privacy = identity?.privacy || {};
      if (privacy.rawTranscriptsIncluded !== false || privacy.sourceCodeIncluded !== false) {
        throw new Error("This artifact does not declare both raw transcripts and source code as excluded.");
      }
      setIdentityCreateStage("privacy", "complete", "Raw text and source excluded");
      setIdentityCreateStage("passport", "active", "Generating");
      passportRequestStarted = true;
      const visibility = String(new FormData(identityCreateForm).get("visibility") || "unlisted");
      const response = await fetch("/api/actions", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          action: "builder_identity.proof_card.v1",
          identity,
          shareControls: { visibility },
          // A retry of this selection should be idempotent, while a newly
          // chosen artifact must never reopen a passport for an older file.
          idempotencyKey: `browser-${submittedSelectionKey}-${visibility}`,
        }),
      });
      const payload = await response.json();
      if (!response.ok || !payload.ok) throw new Error(payload.error || "Could not create a proof action.");
      setIdentityCreateStage("passport", "complete", "Passport ready");
      setIdentityCreateStage("share", "complete", `${visibility} preview ready`);
      if (identityCreateState) identityCreateState.textContent = `60-second passport ready in ${visibility} mode. Review the share card below.`;
      renderIdentityCreatePreview(payload, visibility);
      renderProofAction(payload);
      const passportPreview = identityCreatePreview?.querySelector("[data-identity-passport]");
      passportPreview?.scrollIntoView({ behavior: "smooth", block: "nearest" });
      passportPreview?.focus({ preventScroll: true });
    } catch (error) {
      if (passportRequestStarted) {
        setIdentityCreateStage("passport", "error", "Could not create");
        setIdentityCreateStage("share", "waiting", "Not created");
        setIdentityRetryVisible(true);
      } else {
        setIdentityCreateStage("artifact", "error", "Stopped");
        setIdentityCreateStage("privacy", "error", "Not uploaded");
      }
      if (identityCreateState) identityCreateState.textContent = error?.message || "Could not read that identity artifact.";
    } finally {
      setIdentityGenerationPending(false);
    }
  });
}

async function loadScript(src, attrs = {}) {
  await new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = src;
    script.async = true;
    script.crossOrigin = "anonymous";
    Object.entries(attrs).forEach(([key, value]) => script.setAttribute(key, value));
    script.onload = resolve;
    script.onerror = () => reject(new Error(`Failed to load ${src}`));
    document.head.appendChild(script);
  });
}

async function mountClerk() {
  const target = document.querySelector("[data-clerk-auth]");
  if (!target) return;
  try {
    const response = await fetch("/api/config", { headers: { Accept: "application/json" } });
    const config = await response.json();
    const publishableKey = config?.clerk?.publishableKey;
    if (!publishableKey) {
      target.innerHTML = `
        <div class="auth-placeholder">
          <strong>Clerk is ready to connect.</strong>
          <p>Add <code>NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY</code> in Vercel to turn on hosted sign-in.</p>
        </div>
      `;
      return;
    }
    const clerkDomain = atob(publishableKey.split("_")[2]).slice(0, -1);
    await loadScript(`https://${clerkDomain}/npm/@clerk/ui@1/dist/ui.browser.js`);
    await loadScript(`https://${clerkDomain}/npm/@clerk/clerk-js@6/dist/clerk.browser.js`, {
      "data-clerk-publishable-key": publishableKey,
    });
    await window.Clerk.load({ ui: { ClerkUI: window.__internal_ClerkUICtor } });
    target.innerHTML = window.Clerk.isSignedIn ? '<div id="clerk-user-button"></div>' : '<div id="clerk-sign-in"></div>';
    if (window.Clerk.isSignedIn) {
      window.Clerk.mountUserButton(document.getElementById("clerk-user-button"));
    } else {
      window.Clerk.mountSignIn(document.getElementById("clerk-sign-in"));
    }
  } catch {
    target.innerHTML = `
      <div class="auth-placeholder">
        <strong>Sign-in could not load.</strong>
        <p>The public profile flow still works with <code>tokenbar claim</code>.</p>
      </div>
    `;
  }
}

mountClerk();
