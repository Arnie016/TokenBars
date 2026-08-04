const API_URL = "http://127.0.0.1:8769/v1/bundle";
const STATS_URL = "http://127.0.0.1:8769/v1/stats";
const REMINDERS_URL = "http://127.0.0.1:8769/v1/reminders";
const MEMORY_URL = "http://127.0.0.1:8769/v1/memory-pressure";
const GUIDE_URL = "http://127.0.0.1:8769/v1/guide";
const WASTE_URL = "http://127.0.0.1:8769/v1/waste-lens";
const PLAYBOOKS_URL = "http://127.0.0.1:8769/v1/playbooks";
const PROVIDERS_URL = "http://127.0.0.1:8769/v1/providers";
const COMPARISON_URL = "http://127.0.0.1:8769/v1/comparison-lens";
const PROOF_PACKET_URL = "http://127.0.0.1:8769/v1/proof-packet";
const API_COMMAND = "tokenbar api";

const shell = document.querySelector(".companion-shell");
const accountLabel = document.querySelector("[data-account-label]");
const accountState = document.querySelector("[data-account-state]");
const connectionLabel = document.querySelector("[data-connection-label]");
const todayTokens = document.querySelector("[data-today-tokens]");
const budgetState = document.querySelector("[data-budget-state]");
const budgetRing = document.querySelector("[data-budget-ring]");
const cadenceState = document.querySelector("[data-cadence-state]");
const costState = document.querySelector("[data-cost-state]");
const guideQuestion = document.querySelector("[data-guide-question]");
const guideState = document.querySelector("[data-guide-state]");
const guideOptions = document.querySelector("[data-guide-options]");
const guideAnswer = document.querySelector("[data-guide-answer]");
const guideCommand = document.querySelector("[data-guide-command]");
const guideBoundary = document.querySelector("[data-guide-boundary]");
const guideCopyButton = document.querySelector("[data-guide-copy]");
const guideButtons = document.querySelectorAll("[data-guide-choice]");
const costTitle = document.querySelector("[data-cost-title]");
const costRange = document.querySelector("[data-cost-range]");
const costEstimate = document.querySelector("[data-cost-estimate]");
const costUncertainty = document.querySelector("[data-cost-uncertainty]");
const costAction = document.querySelector("[data-cost-action]");
const wasteTitle = document.querySelector("[data-waste-title]");
const wasteMeter = document.querySelector("[data-waste-meter]");
const wasteScore = document.querySelector("[data-waste-score]");
const wasteLabel = document.querySelector("[data-waste-label]");
const wasteDriver = document.querySelector("[data-waste-driver]");
const wasteLevers = document.querySelector("[data-waste-levers]");
const wasteCopy = document.querySelector("[data-waste-copy]");
const playbooksTitle = document.querySelector("[data-playbooks-title]");
const playbooksTier = document.querySelector("[data-playbooks-tier]");
const playbooksFreeCount = document.querySelector("[data-playbooks-free-count]");
const playbooksProCount = document.querySelector("[data-playbooks-pro-count]");
const playbooksCatalogCount = document.querySelector("[data-playbooks-catalog-count]");
const playbooksList = document.querySelector("[data-playbooks-list]");
const playbooksCopy = document.querySelector("[data-playbooks-copy]");
const playbooksMarketplace = document.querySelector("[data-playbooks-marketplace]");
const playbooksBoundary = document.querySelector("[data-playbooks-boundary]");
const reminderState = document.querySelector("[data-reminder-state]");
const runwayTitle = document.querySelector("[data-runway-title]");
const runwayState = document.querySelector("[data-runway-state]");
const runwayMaterial = document.querySelector("[data-runway-material]");
const runwayReason = document.querySelector("[data-runway-reason]");
const runwayPrompt = document.querySelector("[data-runway-prompt]");
const runwayBoundary = document.querySelector("[data-runway-boundary]");
const runwayCopy = document.querySelector("[data-runway-copy]");
const memoryTitle = document.querySelector("[data-memory-title]");
const memoryState = document.querySelector("[data-memory-pressure-state]");
const memoryBubble = document.querySelector("[data-memory-bubble]");
const memoryPercent = document.querySelector("[data-memory-percent]");
const memoryLane = document.querySelector("[data-memory-lane]");
const memoryDetail = document.querySelector("[data-memory-detail]");
const memoryAction = document.querySelector("[data-memory-action]");
const storyKicker = document.querySelector("[data-story-kicker]");
const storyTitle = document.querySelector("[data-story-title]");
const storyCopy = document.querySelector("[data-story-copy]");
const relayTitle = document.querySelector("[data-relay-title]");
const relayTier = document.querySelector("[data-relay-tier]");
const relayValue = document.querySelector("[data-relay-value]");
const relayCommand = document.querySelector("[data-relay-command]");
const relayGate = document.querySelector("[data-relay-gate]");
const relayFlow = document.querySelector("[data-relay-flow]");
const relayTabs = document.querySelector("[data-relay-tabs]");
const compositionTitle = document.querySelector("[data-composition-title]");
const compositionStack = document.querySelector("[data-composition-stack]");
const providerList = document.querySelector("[data-provider-list]");
const providerSummary = document.querySelector("[data-provider-summary]");
const providerStrip = document.querySelector("[data-provider-strip]");
const providerDetail = document.querySelector("[data-provider-detail]");
const providerDetailName = document.querySelector("[data-provider-detail-name]");
const providerDetailStatus = document.querySelector("[data-provider-detail-status]");
const providerDetailProof = document.querySelector("[data-provider-detail-proof]");
const providerDetailAction = document.querySelector("[data-provider-detail-action]");
const providerSetupFlow = document.querySelector("[data-provider-setup-flow]");
const providerDetailCopy = document.querySelector("[data-provider-detail-copy]");
const comparisonTitle = document.querySelector("[data-comparison-title]");
const comparisonState = document.querySelector("[data-comparison-state]");
const comparisonOrbit = document.querySelector("[data-comparison-orbit]");
const comparisonMetrics = document.querySelector("[data-comparison-metrics]");
const comparisonCopy = document.querySelector("[data-comparison-copy]");
const comparisonCopyCommand = document.querySelector("[data-comparison-copy-command]");
const proofTitle = document.querySelector("[data-proof-title]");
const proofState = document.querySelector("[data-proof-state]");
const proofFields = document.querySelector("[data-proof-fields]");
const proofCopy = document.querySelector("[data-proof-copy]");
const proofCopyCommand = document.querySelector("[data-proof-copy-command]");
const launchTitle = document.querySelector("[data-launch-title]");
const launchState = document.querySelector("[data-launch-state]");
const launchSteps = document.querySelector("[data-launch-steps]");
const refreshButton = document.querySelector("[data-refresh]");
const copyApiButton = document.querySelector("[data-copy-api]");
const commandButtons = document.querySelectorAll("[data-copy-command]");
let guideChoices = [];
const PROVIDER_STATUS_CLASSES = {
  measured: "status-measured",
  setup: "status-setup",
};
let providerChoices = [];
let selectedProviderKey = "";
let selectedWasteCommand = "tokenbar playbooks copy mission-lock";
let selectedPlaybookCommand = "tokenbar playbooks copy mission-lock";
let selectedComparisonCommand = "tokenbar comparison-lens";
let selectedProofCommand = "tokenbar proof-packet json";
let relayChoices = [];
let selectedRelayKey = "menu";

function compactTokens(value) {
  const numeric = Number(value || 0);
  if (!Number.isFinite(numeric) || numeric <= 0) return "0";
  if (numeric >= 1_000_000_000) return `${(numeric / 1_000_000_000).toFixed(2)}B`;
  if (numeric >= 1_000_000) return `${Math.round(numeric / 1_000_000)}M`;
  if (numeric >= 1_000) return `${Math.round(numeric / 1_000)}K`;
  return String(Math.round(numeric));
}

function firstDefined(...values) {
  return values.find((value) => value !== undefined && value !== null && value !== "");
}

function clampPercent(value, fallback = 68) {
  const numeric = Math.round(Number(value));
  if (!Number.isFinite(numeric)) return fallback;
  return Math.max(0, Math.min(100, numeric));
}

function formatCost(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric <= 0) return "Set price";
  if (numeric >= 100) return `$${Math.round(numeric)}`;
  return `$${numeric.toFixed(2)}`;
}

function formatMemory(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric <= 0) return "0 MB";
  if (numeric >= 1024) return `${(numeric / 1024).toFixed(numeric >= 10_240 ? 0 : 1)} GB`;
  return `${Math.round(numeric)} MB`;
}

function activeDays(dayTokens = {}) {
  return Object.values(dayTokens).filter((value) => Number(value || 0) > 0).length;
}

function topProviders(modelTokens = {}) {
  const palette = ["#ffad7a", "#78a5ff", "#7fd8e8", "#b990ff", "#71d5ae"];
  const rows = Object.entries(modelTokens)
    .map(([name, tokens]) => ({ name: String(name || "Unknown").slice(0, 28), tokens: Number(tokens || 0) }))
    .filter((row) => Number.isFinite(row.tokens) && row.tokens > 0)
    .sort((a, b) => b.tokens - a.tokens)
    .slice(0, 5);

  const total = rows.reduce((sum, row) => sum + row.tokens, 0);
  if (!total) {
    return [
      { name: "Codex", percent: 44, accent: palette[0] },
      { name: "Claude Code", percent: 28, accent: palette[1] },
      { name: "Cursor", percent: 18, accent: palette[2] },
      { name: "OpenCode", percent: 10, accent: palette[3] },
    ];
  }

  return rows.map((row, index) => ({
    name: row.name,
    percent: Math.max(1, Math.round((row.tokens / total) * 100)),
    accent: palette[index % palette.length],
  }));
}

function renderComposition(rows) {
  compositionStack.replaceChildren();
  providerList.replaceChildren();

  rows.forEach((row) => {
    const segment = document.createElement("i");
    segment.style.setProperty("--weight", String(row.percent));
    segment.style.setProperty("--accent", row.accent);
    compositionStack.append(segment);

    const item = document.createElement("li");
    const label = document.createElement("span");
    const value = document.createElement("b");
    label.textContent = row.name;
    value.textContent = `${row.percent}%`;
    item.append(label, value);
    providerList.append(item);
  });
}

function fallbackSurfaceRelay() {
  return [
    {
      key: "cli",
      surface: "CLI evidence line",
      command: "tokenbar usage",
      tier: "Free",
      gate: "Local read only",
      value: "Scriptable usage, cost passport, reminders, playbooks, launch kit, and local JSON.",
    },
    {
      key: "menu",
      surface: "Menu-bar cockpit",
      command: "tokenbar status",
      tier: "Free",
      gate: "No provider sign-in",
      value: "Active account, measured providers, time-window tokens, budget pressure, and next suggested action.",
    },
    {
      key: "companion",
      surface: "Browser context rail",
      command: "tokenbar api",
      tier: "Free preview",
      gate: "127.0.0.1 only",
      value: "Budget, reminders, memory pressure, and prompt playbooks beside Codex, GitHub, Product Hunt, and provider pages.",
    },
    {
      key: "studio",
      surface: "Mac studio archive",
      command: "tokenbar proof-packet",
      tier: "Free app",
      gate: "Review before share",
      value: "Story, Timeline, Threads, Profile, Report, Storage, and proof packets from aggregate evidence.",
    },
    {
      key: "pro",
      surface: "Pro proof market",
      command: "tokenbar playbooks",
      tier: "Pro",
      gate: "No auto-billing",
      value: "Paid prompt playbooks, public proof cards, cohort comparison, and premium reports after account review.",
    },
  ];
}

function setRelayChoice(key) {
  const choice = relayChoices.find((item) => item.key === key) || relayChoices[1] || relayChoices[0] || fallbackSurfaceRelay()[1];
  selectedRelayKey = choice.key;
  relayTabs?.querySelectorAll("[data-relay-key]").forEach((button) => {
    button.classList.toggle("is-selected", button.dataset.relayKey === selectedRelayKey);
  });
  const relayIndex = Math.max(0, relayChoices.findIndex((item) => item.key === selectedRelayKey));
  relayFlow?.style.setProperty("--relay-index", String(relayIndex));
  relayFlow?.querySelectorAll("i").forEach((node, index) => {
    node.classList.toggle("is-selected", index === relayIndex);
  });
  relayTitle.textContent = String(firstDefined(choice.surface, "TokenBar surface")).slice(0, 34);
  relayTier.textContent = String(firstDefined(choice.tier, "Free")).slice(0, 18);
  relayValue.textContent = String(firstDefined(choice.value, "Local TokenBar surface.")).slice(0, 132);
  relayCommand.textContent = String(firstDefined(choice.command, "tokenbar usage")).slice(0, 52);
  relayGate.textContent = String(firstDefined(choice.gate, "Review first")).slice(0, 34);
}

function renderSurfaceRelay(surfaceRelay = []) {
  const source = Array.isArray(surfaceRelay) && surfaceRelay.length ? surfaceRelay : fallbackSurfaceRelay();
  relayChoices = source.slice(0, 5).map((item, index) => ({
    key: String(firstDefined(item.key, item.surface, `relay-${index}`)).toLowerCase().replace(/\s+/g, "-").slice(0, 24),
    surface: String(firstDefined(item.surface, "TokenBar surface")).slice(0, 48),
    command: String(firstDefined(item.command, "tokenbar usage")).slice(0, 80),
    tier: String(firstDefined(item.tier, "Free")).slice(0, 24),
    gate: String(firstDefined(item.gate, "Review first")).slice(0, 48),
    value: String(firstDefined(item.value, "Local TokenBar surface.")).slice(0, 180),
  }));
  relayTabs?.replaceChildren();
  relayChoices.forEach((choice) => {
    const button = document.createElement("button");
    button.type = "button";
    button.dataset.relayKey = choice.key;
    button.textContent = choice.key === "companion" ? "Rail" : choice.key.charAt(0).toUpperCase() + choice.key.slice(1);
    button.addEventListener("click", () => setRelayChoice(choice.key));
    relayTabs.append(button);
  });
  setRelayChoice(selectedRelayKey);
}

function fallbackProviders() {
  const flow = [
    { label: "Detect", copy: "Local evidence", done: false },
    { label: "Connect", copy: "Approved source", done: false },
    { label: "Review", copy: "Measured proof", done: false },
  ];
  return {
    summary: { measuredCount: 0, setupCount: 5, primary: "No measured provider yet" },
    providers: [
      { key: "codex", name: "Codex", status: "setup", tokensLabel: "setup", command: "tokenbar providers", setupFlow: flow, proof: "No local aggregate token evidence loaded for Codex yet.", action: "Run the local API or usage import. No account changes. No provider calls." },
      { key: "claude-code", name: "Claude Code", status: "setup", tokensLabel: "setup", command: "tokenbar providers", setupFlow: flow, proof: "No local aggregate token evidence loaded for Claude Code yet.", action: "Connect only after an approved local source exists. No provider calls." },
      { key: "cursor", name: "Cursor", status: "setup", tokensLabel: "setup", command: "tokenbar providers", setupFlow: flow, proof: "No local aggregate token evidence loaded for Cursor yet.", action: "Connect only after an approved local source exists. No provider calls." },
      { key: "antigravity", name: "Antigravity", status: "setup", tokensLabel: "setup", command: "tokenbar providers", setupFlow: flow, proof: "No local aggregate token evidence loaded for Antigravity yet.", action: "Connect only after an approved local source exists. No provider calls." },
      { key: "opencode", name: "OpenCode", status: "setup", tokensLabel: "setup", command: "tokenbar providers", setupFlow: flow, proof: "No local aggregate token evidence loaded for OpenCode yet.", action: "Run the local API or usage import. No account changes. No provider calls." },
    ],
  };
}

function inferredProviderPayload(modelTokens = {}) {
  const targets = [
    { name: "Codex", aliases: ["codex", "gpt", "openai"] },
    { name: "Claude Code", aliases: ["claude", "sonnet", "opus"] },
    { name: "Cursor", aliases: ["cursor"] },
    { name: "Antigravity", aliases: ["antigravity", "anti-gravity"] },
    { name: "OpenCode", aliases: ["opencode", "open code", "open-code"] },
  ];
  const providers = targets.map((target) => {
    const tokens = Object.entries(modelTokens).reduce((sum, [name, value]) => {
      const lower = String(name || "").toLowerCase();
      return target.aliases.some((alias) => lower.includes(alias)) ? sum + Number(value || 0) : sum;
    }, 0);
    return {
      key: target.name.toLowerCase().replace(/\s+/g, "-"),
      name: target.name,
      status: tokens > 0 ? "measured" : "setup",
      tokensLabel: tokens > 0 ? compactTokens(tokens) : "setup",
      proof: tokens > 0 ? "Local model token evidence exists." : "No local aggregate token evidence yet.",
      action: tokens > 0 ? "Review local aggregate trend before changing budget." : "Add a user-approved usage export before calling this measured.",
      command: tokens > 0 ? "tokenbar usage" : "tokenbar providers",
      setupFlow: [
        { label: "Detect", copy: "Local evidence", done: tokens > 0 },
        { label: "Connect", copy: "Approved source", done: tokens > 0 },
        { label: "Review", copy: "Measured proof", done: tokens > 0 },
      ],
    };
  });
  const measuredCount = providers.filter((provider) => provider.status === "measured").length;
  return { summary: { measuredCount, setupCount: providers.length - measuredCount }, providers };
}

function fallbackWasteLens() {
  return {
    schema: "tokenbar.waste_lens.v1",
    score: 42,
    label: "Watch",
    primaryDriver: "Run tokenbar api to turn aggregate usage into saver advice.",
    levers: [
      { title: "Scope before run", copy: "Mission Lock", command: "tokenbar playbooks copy mission-lock", impact: "Prevents runaway context." },
      { title: "Shorten output", copy: "Output Budget", command: "tokenbar playbooks copy output-budget", impact: "Cuts answer spillover." },
      { title: "Review cost", copy: "Cost Passport", command: "tokenbar cost-passport", impact: "Turns volume into a budget decision." },
    ],
  };
}

function renderWasteLens(waste = {}, live = false) {
  const payload = waste?.schema === "tokenbar.waste_lens.v1" ? waste : fallbackWasteLens();
  const score = clampPercent(payload.score, 42);
  const levers = Array.isArray(payload.levers) && payload.levers.length ? payload.levers : fallbackWasteLens().levers;
  const firstLever = levers[0] || fallbackWasteLens().levers[0];
  selectedWasteCommand = String(firstDefined(firstLever.command, "tokenbar playbooks copy mission-lock")).slice(0, 120);
  wasteTitle.textContent = live ? "Spend fewer tokens on the next run." : "Preview the next-run saver lens.";
  wasteMeter.style.setProperty("--waste-score", String(score));
  wasteScore.textContent = String(score);
  wasteLabel.textContent = String(firstDefined(payload.label, "Watch")).slice(0, 12);
  wasteDriver.textContent = String(firstDefined(payload.primaryDriver, "Aggregate usage shape will point to the next saver playbook.")).slice(0, 128);
  wasteLevers.replaceChildren();
  levers.slice(0, 3).forEach((lever) => {
    const item = document.createElement("li");
    const title = document.createElement("b");
    const copy = document.createElement("span");
    title.textContent = String(firstDefined(lever.title, "Saver lever")).slice(0, 24);
    copy.textContent = String(firstDefined(lever.copy, lever.impact, lever.command, "Local aggregate advice")).slice(0, 42);
    item.title = String(firstDefined(lever.impact, lever.command, "Local aggregate advice")).slice(0, 120);
    item.append(title, copy);
    wasteLevers.append(item);
  });
  wasteCopy.dataset.copyCommand = selectedWasteCommand;
}

function fallbackPlaybooks() {
  return {
    schema: "tokenbar.playbooks.v1",
    summary: {
      freeCount: 5,
      proPreviewCount: 6,
      catalogCount: 100,
      primaryCommand: "tokenbar playbooks copy mission-lock",
      marketplaceUrl: "https://www.tokenbar.site/playbooks",
      businessState: "Freemium preview only; payment and entitlement checks are not performed by the companion.",
    },
    tiers: [
      {
        name: "Free",
        playbooks: [
          { title: "Mission Lock", command: "tokenbar playbooks copy mission-lock" },
          { title: "Budget Brief", command: "tokenbar playbooks copy budget-runway" },
          { title: "Cost Saver Header", command: "tokenbar playbooks copy cost-saver" },
        ],
      },
      { name: "Pro", playbooks: [{ title: "System Prompt Hardener" }, { title: "Cost Passport" }, { title: "Comparison Engine" }] },
    ],
  };
}

function renderPlaybookVault(playbooks = {}, live = false) {
  const payload = playbooks?.schema === "tokenbar.playbooks.v1" ? playbooks : fallbackPlaybooks();
  const summary = payload.summary || fallbackPlaybooks().summary;
  const freeTier = (Array.isArray(payload.tiers) ? payload.tiers : []).find((tier) => tier.name === "Free") || fallbackPlaybooks().tiers[0];
  const proTier = (Array.isArray(payload.tiers) ? payload.tiers : []).find((tier) => tier.name === "Pro") || fallbackPlaybooks().tiers[1];
  const freePlaybooks = Array.isArray(freeTier.playbooks) ? freeTier.playbooks : [];
  selectedPlaybookCommand = String(firstDefined(summary.primaryCommand, freePlaybooks[0]?.command, "tokenbar playbooks copy mission-lock")).slice(0, 120);
  playbooksTitle.textContent = live ? "Copy a better operating order." : "Preview the prompt vault.";
  playbooksTier.textContent = live ? "Free + Pro" : "Preview";
  playbooksFreeCount.textContent = String(firstDefined(summary.freeCount, freePlaybooks.length, 5));
  playbooksProCount.textContent = String(firstDefined(summary.proPreviewCount, Array.isArray(proTier.playbooks) ? proTier.playbooks.length : 6));
  playbooksCatalogCount.textContent = String(firstDefined(summary.catalogCount, 100));
  playbooksMarketplace.href = String(firstDefined(summary.marketplaceUrl, payload.links?.marketplace, "https://www.tokenbar.site/playbooks"));
  playbooksList.replaceChildren();
  freePlaybooks.slice(0, 3).forEach((playbook) => {
    const item = document.createElement("li");
    const title = document.createElement("b");
    const command = document.createElement("span");
    title.textContent = String(firstDefined(playbook.title, "Playbook")).slice(0, 28);
    command.textContent = String(firstDefined(playbook.command, "tokenbar playbooks")).slice(0, 52);
    item.title = String(firstDefined(playbook.wastePrevented, playbook.copy, "Copy before the next run.")).slice(0, 130);
    item.append(title, command);
    playbooksList.append(item);
  });
  playbooksCopy.dataset.copyCommand = selectedPlaybookCommand;
  playbooksBoundary.textContent = String(firstDefined(
    summary.businessState,
    "No payments or unlocks from the companion. Pro is a preview until the account layer verifies subscription.",
  )).slice(0, 150);
}

function setProviderDetail(key, shouldCopy = false) {
  const provider = providerChoices.find((item) => item.key === key) || providerChoices[0] || fallbackProviders().providers[0];
  selectedProviderKey = provider.key;
  providerStrip.querySelectorAll(".provider-pill").forEach((pill) => {
    pill.classList.toggle("is-selected", pill.dataset.providerKey === selectedProviderKey);
  });
  const state = String(provider.status || "setup").toLowerCase();
  const command = String(firstDefined(provider.command, state === "measured" ? "tokenbar usage" : "tokenbar providers"));
  providerDetailName.textContent = String(provider.name || "Provider").slice(0, 24);
  providerDetailStatus.textContent = state === "measured" ? `Measured · ${firstDefined(provider.tokensLabel, "0")}` : "Setup needed";
  providerDetailProof.textContent = String(firstDefined(provider.proof, provider.evidenceNeeded, "Provider status is local and read-only.")).slice(0, 118);
  providerDetailAction.textContent = String(firstDefined(provider.action, provider.evidenceNeeded, "No account changes. No provider calls.")).slice(0, 118);
  providerSetupFlow.replaceChildren();
  (Array.isArray(provider.setupFlow) && provider.setupFlow.length ? provider.setupFlow : fallbackProviders().providers[0].setupFlow).slice(0, 3).forEach((step) => {
    const item = document.createElement("li");
    const label = document.createElement("b");
    const copy = document.createElement("span");
    item.classList.toggle("is-done", step.done === true);
    label.textContent = String(firstDefined(step.label, "Step")).slice(0, 16);
    copy.textContent = String(firstDefined(step.copy, "Local proof")).slice(0, 32);
    item.append(label, copy);
    providerSetupFlow.append(item);
  });
  providerDetailCopy.textContent = shouldCopy ? "Copying..." : "Copy local check";
  providerDetailCopy.dataset.copyCommand = command;
  if (shouldCopy) {
    navigator.clipboard?.writeText(command).then(() => {
      providerDetailCopy.textContent = "Copied";
    }).catch(() => {
      providerDetailCopy.textContent = command;
    });
  }
}

function renderProviderTruth(providersPayload = {}, modelTokens = {}) {
  const payload = providersPayload?.schema === "tokenbar.providers.v1"
    ? providersPayload
    : (Object.keys(modelTokens || {}).length ? inferredProviderPayload(modelTokens) : fallbackProviders());
  const providers = Array.isArray(payload.providers) && payload.providers.length ? payload.providers : fallbackProviders().providers;
  providerChoices = providers.slice(0, 5).map((provider, index) => ({
    key: String(firstDefined(provider.key, provider.name, `provider-${index}`)).toLowerCase().replace(/\s+/g, "-").slice(0, 32),
    name: String(firstDefined(provider.name, "Provider")).slice(0, 32),
    status: String(firstDefined(provider.status, "setup")).toLowerCase(),
    tokens: Number(provider.tokens || 0),
    tokensLabel: String(firstDefined(provider.tokensLabel, compactTokens(provider.tokens), "0")).slice(0, 16),
    proof: String(firstDefined(provider.proof, "Provider status is local and read-only.")).slice(0, 160),
    evidenceNeeded: String(firstDefined(provider.evidenceNeeded, "Aggregate provider token evidence.")).slice(0, 160),
    action: String(firstDefined(provider.action, "No account changes. No provider calls.")).slice(0, 160),
    command: String(firstDefined(provider.command, provider.status === "measured" ? "tokenbar usage" : "tokenbar providers")).slice(0, 80),
    setupFlow: Array.isArray(provider.setupFlow) ? provider.setupFlow.slice(0, 3) : fallbackProviders().providers[0].setupFlow,
  }));
  const measuredCount = Number(payload.summary?.measuredCount || providers.filter((provider) => provider.status === "measured").length);
  const setupCount = Number(payload.summary?.setupCount || providers.filter((provider) => provider.status === "setup").length);

  providerSummary.textContent = measuredCount
    ? `${measuredCount} measured · ${setupCount} setup`
    : "No measured providers yet";
  providerStrip.replaceChildren();
  providerChoices.forEach((provider) => {
    const pill = document.createElement("button");
    const label = document.createElement("span");
    const status = document.createElement("b");
    const state = String(provider.status || "demo").toLowerCase();
    pill.type = "button";
    pill.dataset.providerKey = provider.key;
    pill.className = `provider-pill ${PROVIDER_STATUS_CLASSES[state] || PROVIDER_STATUS_CLASSES.setup}`;
    label.textContent = String(provider.name || "Provider").slice(0, 18);
    status.textContent = state === "measured"
      ? String(firstDefined(provider.tokensLabel, compactTokens(provider.tokens), "measured")).slice(0, 12)
      : state;
    pill.title = String(firstDefined(provider.proof, provider.action, "Provider status is local and read-only.")).slice(0, 180);
    pill.append(label, status);
    pill.addEventListener("click", () => setProviderDetail(provider.key));
    providerStrip.append(pill);
  });
  setProviderDetail(selectedProviderKey || providerChoices[0]?.key || "");
}

function fallbackComparisonLens() {
  return {
    schema: "tokenbar.comparison_lens.v1",
    title: "Compare the pattern, not the person.",
    command: "tokenbar comparison-lens",
    summary: {
      state: "locked",
      percentile: "locked",
      disclaimer: "Population percentiles stay locked until a measured opt-in cohort exists.",
    },
    metrics: [
      { label: "Cadence", score: 68, basis: "Self-over-time comparison from aggregate token counts only." },
      { label: "Momentum", score: 54, basis: "Self-over-time comparison from aggregate token counts only." },
      { label: "Cost control", score: 72, basis: "Self-over-time comparison from aggregate token counts only." },
      { label: "Scope discipline", score: 46, basis: "Self-over-time comparison from aggregate token counts only." },
    ],
    claimPolicy: {
      minCohortSize: 10,
      blocked: ["top-percentile claims without cohort data", "identity worth rankings", "raw transcript or source-code comparisons"],
    },
  };
}

function renderComparisonLens(comparison = {}, live = false) {
  const payload = comparison?.schema === "tokenbar.comparison_lens.v1" ? comparison : fallbackComparisonLens();
  const fallback = fallbackComparisonLens();
  const metrics = Array.isArray(payload.metrics) && payload.metrics.length ? payload.metrics : fallback.metrics;
  const summary = payload.summary || {};
  const policy = payload.claimPolicy || payload.claim_policy || {};
  const disclaimer = firstDefined(
    payload.disclaimer,
    summary.disclaimer,
    "Population percentiles stay locked until a measured opt-in cohort exists.",
  );
  const percentile = firstDefined(summary.percentile, payload.percentile, "locked");
  selectedComparisonCommand = String(firstDefined(payload.command, "tokenbar comparison-lens")).slice(0, 80);

  comparisonTitle.textContent = String(firstDefined(payload.title, fallback.title)).slice(0, 72);
  comparisonState.textContent = live ? `Cohort ${firstDefined(policy.minCohortSize, 10)}+` : "Locked";
  comparisonCopy.textContent = `${String(disclaimer).slice(0, 116)} Percentile: ${String(percentile).slice(0, 18)}.`;
  comparisonCopyCommand.dataset.copyCommand = selectedComparisonCommand;
  comparisonMetrics.replaceChildren();
  comparisonOrbit.replaceChildren();

  metrics.slice(0, 4).forEach((metric, index) => {
    const score = clampPercent(firstDefined(metric.score, metric.value, 50), 50);
    const labelText = String(firstDefined(metric.label, metric.key, "Metric")).slice(0, 22);
    const basis = String(firstDefined(metric.basis, metric.copy, "Self-over-time aggregate comparison.")).slice(0, 120);
    const item = document.createElement("li");
    const label = document.createElement("span");
    const value = document.createElement("b");
    const node = document.createElement("i");
    label.textContent = labelText;
    value.textContent = live ? `${score}` : "self";
    item.title = basis;
    item.append(label, value);
    node.style.setProperty("--score", String(score));
    node.style.setProperty("--angle", `${index * 90}deg`);
    node.style.setProperty("--accent", ["#7fd8e8", "#ffad7a", "#78a5ff", "#b990ff"][index % 4]);
    comparisonMetrics.append(item);
    comparisonOrbit.append(node);
  });
}

function fallbackProofPacket() {
  return {
    schema: "tokenbar.launch_proof_packet.v1",
    title: "Show proof without exposing the work.",
    command: "tokenbar proof-packet json",
    state: "review first",
    cards: [
      { title: "Usage evidence", summary: "Aggregate token counts and active days." },
      { title: "Cost passport", summary: "Estimated cost range, not provider invoices." },
      { title: "Waste lens", summary: "Prompt and scope levers before the next run." },
      { title: "Approval gates", summary: "No posting, uploads, purchases, or account changes." },
    ],
    privacy: {
      blockedFields: ["raw prompts", "transcripts", "source code", "credentials", "provider cookies", "local paths"],
      blockedActions: ["posting", "uploads", "purchases", "account switching", "provider calls"],
    },
  };
}

function renderProofPacket(packet = {}, live = false) {
  const payload = packet?.schema === "tokenbar.launch_proof_packet.v1" ? packet : fallbackProofPacket();
  const fallback = fallbackProofPacket();
  const cards = Array.isArray(payload.cards) && payload.cards.length ? payload.cards : fallback.cards;
  const privacy = payload.privacy || {};
  const blocked = [
    ...(Array.isArray(privacy.blockedFields) ? privacy.blockedFields : []),
    ...(Array.isArray(privacy.blockedActions) ? privacy.blockedActions : []),
  ];
  selectedProofCommand = String(firstDefined(payload.command, "tokenbar proof-packet json")).slice(0, 90);

  proofTitle.textContent = String(firstDefined(payload.title, fallback.title)).slice(0, 74);
  proofState.textContent = live ? "Local proof" : String(firstDefined(payload.state, fallback.state)).slice(0, 18);
  proofCopy.textContent = blocked.length
    ? `Blocked: ${blocked.slice(0, 6).join(", ")}. Review before sharing.`
    : "Public-ready aggregates only. Review before sharing.";
  proofCopyCommand.dataset.copyCommand = selectedProofCommand;
  proofFields.replaceChildren();

  cards.slice(0, 4).forEach((card) => {
    const item = document.createElement("li");
    item.textContent = String(firstDefined(card.title, card.label, "Proof field")).slice(0, 32);
    item.title = String(firstDefined(card.summary, card.copy, "Aggregate proof only.")).slice(0, 120);
    proofFields.append(item);
  });
}

function formatUncertainty(value) {
  const numeric = Math.round(Number(value));
  if (!Number.isFinite(numeric) || numeric <= 0) return "Forecast range appears after local usage is indexed.";
  return `Forecast range: expected pace plus or minus ${numeric}%.`;
}

function renderCostPassport({ estimate, range, uncertainty, action, live }) {
  const visibleEstimate = formatCost(estimate);
  costTitle.textContent = live ? "Cost before the next long run." : "Turn usage into a cost story.";
  costRange.textContent = String(range || "30-day local window").slice(0, 46);
  costEstimate.textContent = visibleEstimate;
  costUncertainty.textContent = String(formatUncertainty(uncertainty)).slice(0, 82);
  costAction.textContent = String(
    firstDefined(
      action,
      Number(estimate) > 0
        ? "Review the passport before sharing or raising a budget."
        : "Use a price assumption before treating this as a budget signal.",
    ),
  ).slice(0, 92);
}

function renderMemoryPressure(memory = {}, live = false) {
  const summary = memory?.summary || {};
  const categories = Array.isArray(memory?.categories) ? memory.categories : [];
  const actions = Array.isArray(memory?.actions) ? memory.actions : [];
  const pressure = String(summary.pressure || (live ? "unknown" : "preview")).toUpperCase();
  const percent = clampPercent(summary.observedPercent, live ? 0 : 42);
  const topLane = categories[0] || { name: "Chrome + Codex lane", rssMb: null, processes: 0 };
  const action = actions[0] || {};

  memoryTitle.textContent = live ? "Memory before the next cleanup." : "Explain overload before cleanup.";
  memoryState.textContent = pressure;
  memoryBubble?.style.setProperty("--memory-pressure", String(percent));
  memoryPercent.textContent = `${percent}%`;
  memoryLane.textContent = `${String(topLane.name || "Memory lane").replace(/_/g, " ")} · ${formatMemory(topLane.rssMb)}`;
  memoryDetail.textContent = live
    ? `${formatMemory(summary.browserAgentMemoryMb)} browser + agent pressure. ${topLane.processes || 0} processes in the largest lane.`
    : "Run tokenbar api to see local process lanes.";
  const actionTitle = firstDefined(action.title, "No cleanup suggested");
  memoryAction.textContent = live
    ? `${actionTitle}. Approval required.`
    : "No apps closed. Approval required before cleanup.";
}

function fallbackGuide() {
  return {
    question: "What should TokenBar help with before your next AI coding run?",
    priority: "playbook",
    choices: [
      {
        key: "install",
        label: "Install",
        title: "Install or refresh the menu-bar cockpit.",
        why: "Use this when the icon bar, CLI, or local API needs a refresh.",
        command: "curl -fsSL https://raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh | bash",
        approvalRequired: false,
      },
      {
        key: "analyze",
        label: "Analyze",
        title: "Refresh the local usage story.",
        why: "Read aggregate tokens, cadence, cost, and provider state first.",
        command: "tokenbar usage",
        approvalRequired: false,
      },
      {
        key: "budget",
        label: "Budget",
        title: "Set a budget brief before the next long run.",
        why: "Budget reminders become useful once token and cost limits are explicit.",
        command: "tokenbar reminders",
        approvalRequired: true,
      },
      {
        key: "playbook",
        label: "Playbook",
        title: "Copy a cheaper operating prompt.",
        why: "A scoped prompt lowers wasted output tokens and makes verification cheaper.",
        command: "tokenbar playbooks copy budget-runway",
        approvalRequired: false,
      },
      {
        key: "proof",
        label: "Proof",
        title: "Review the launch proof packet.",
        why: "Share generated aggregates only after reviewing the artifact.",
        command: "tokenbar proof-packet",
        approvalRequired: true,
      },
    ],
  };
}

function guideCopy(choice) {
  const approval = choice.approvalRequired ? " Approval required before changes." : " Safe to copy.";
  return `${choice.title} ${approval} Command: ${choice.command}`;
}

function setGuideChoice(key, shouldCopy = false) {
  const choice = guideChoices.find((item) => item.key === key) || guideChoices[0] || fallbackGuide().choices[1];
  guideOptions.querySelectorAll("[data-guide-choice]").forEach((button) => {
    button.classList.toggle("is-selected", button.dataset.guideChoice === choice.key);
  });
  guideCommand.textContent = choice.command;
  guideBoundary.textContent = choice.approvalRequired ? "Approval required." : "Copy-only.";
  guideAnswer.textContent = guideCopy(choice).slice(0, 180);
  if (shouldCopy && choice.command) {
    navigator.clipboard?.writeText(choice.command).then(() => {
      guideAnswer.textContent = `Copied ${choice.command}. ${choice.approvalRequired ? "Approval required before changes." : "Use it before the next run."}`;
    }).catch(() => {
      guideAnswer.textContent = choice.command;
    });
  }
}

function renderGuide(guide = fallbackGuide(), live = false) {
  const normalized = {
    question: firstDefined(guide.question, fallbackGuide().question),
    priority: firstDefined(guide.priority, fallbackGuide().priority),
    choices: Array.isArray(guide.choices) && guide.choices.length ? guide.choices : fallbackGuide().choices,
  };
  guideChoices = normalized.choices.map((choice) => ({
    key: String(firstDefined(choice.key, choice.label, "choice")).slice(0, 24),
    label: String(firstDefined(choice.label, choice.title, "Guide")).slice(0, 28),
    title: String(firstDefined(choice.title, choice.label, "Choose a TokenBar guide.")).slice(0, 84),
    why: String(firstDefined(choice.why, "Suggested from local aggregate evidence.")).slice(0, 92),
    command: String(firstDefined(choice.command, "tokenbar playbooks")).slice(0, 80),
    approvalRequired: choice.approvalRequired === true,
  }));

  guideQuestion.textContent = String(normalized.question).slice(0, 88);
  guideState.textContent = live ? "Local guide" : "Suggested";

  guideOptions.replaceChildren();
  guideChoices.slice(0, 5).forEach((choice) => {
    const button = document.createElement("button");
    button.type = "button";
    button.dataset.guideChoice = choice.key;
    button.addEventListener("click", () => setGuideChoice(choice.key, true));
    const label = document.createElement("b");
    const copy = document.createElement("span");
    label.textContent = choice.label;
    copy.textContent = choice.why;
    button.append(label, copy);
    guideOptions.append(button);
  });
  setGuideChoice(String(normalized.priority));
}

function launchStep(label, copy) {
  return { label: String(label || "").slice(0, 22), copy: String(copy || "").slice(0, 92) };
}

function fallbackLaunchCoach() {
  return {
    title: "Prepare the public story without posting.",
    state: "No-submit",
    steps: [
      launchStep("Launch map", "Check demo proof before Product Hunt or Macapp Supply."),
      launchStep("Playbook", "Use Mission Lock before long generation loops."),
      launchStep("Proof", "Share aggregates only after reviewing the artifact."),
    ],
  };
}

function renderLaunchCoach(coach = fallbackLaunchCoach()) {
  const normalized = {
    title: firstDefined(coach.title, fallbackLaunchCoach().title),
    state: firstDefined(coach.state, fallbackLaunchCoach().state),
    steps: Array.isArray(coach.steps) && coach.steps.length ? coach.steps : fallbackLaunchCoach().steps,
  };

  launchTitle.textContent = String(normalized.title).slice(0, 80);
  launchState.textContent = String(normalized.state).slice(0, 18);
  launchSteps.replaceChildren();

  normalized.steps.slice(0, 3).forEach((step) => {
    const article = document.createElement("article");
    const label = document.createElement("b");
    const copy = document.createElement("span");
    label.textContent = firstDefined(step.label, step.title, "Step");
    copy.textContent = firstDefined(step.copy, step.proof, step.action, "Review the proof before publishing.");
    article.append(label, copy);
    launchSteps.append(article);
  });
}

function fallbackRunwayBrief() {
  return {
    title: "Prepare the next run before it expands.",
    state: "calm",
    reason: "TokenBar will suggest the smallest next guardrail after local usage is indexed.",
    recommendedLimit: "Set a daily or weekly guardrail",
    setupPrompt: "Budget: Focus | Route: one bounded implementation | Timebox: one verifier | Context cap: touched files only | Stop: approval-gated external actions.",
    commands: {
      copyPrompt: "tokenbar playbooks copy budget-runway",
      openReminders: "tokenbar reminders json",
    },
    scheduledNotifications: false,
  };
}

function riskToPercent(state) {
  const normalized = String(state || "").toLowerCase();
  if (normalized === "over") return 94;
  if (normalized === "high") return 76;
  if (normalized === "watch") return 58;
  return 34;
}

function renderRunwayBrief(brief = fallbackRunwayBrief(), live = false) {
  const fallback = fallbackRunwayBrief();
  const normalized = {
    title: firstDefined(brief.title, fallback.title),
    state: firstDefined(brief.state, fallback.state),
    reason: firstDefined(brief.reason, brief.trigger, fallback.reason),
    recommendedLimit: firstDefined(brief.recommendedLimit, fallback.recommendedLimit),
    setupPrompt: firstDefined(brief.setupPrompt, fallback.setupPrompt),
    command: firstDefined(brief?.commands?.copyPrompt, brief?.commands?.openReminders, fallback.commands.copyPrompt),
    scheduledNotifications: brief.scheduledNotifications === true,
  };

  runwayTitle.textContent = String(normalized.title).slice(0, 72);
  runwayState.textContent = live ? String(normalized.state).slice(0, 16) : "Preview";
  runwayMaterial.style.setProperty("--runway-risk", String(riskToPercent(normalized.state)));
  runwayReason.textContent = `${String(normalized.reason).slice(0, 118)} ${String(normalized.recommendedLimit).slice(0, 62)}.`;
  runwayPrompt.textContent = String(normalized.setupPrompt).slice(0, 118);
  runwayCopy.dataset.copyCommand = normalized.command;
  runwayBoundary.textContent = normalized.scheduledNotifications
    ? "Unexpected schedule flag. Review before trusting this surface."
    : "Suggested only. No notification scheduled.";
}

function renderFallback() {
  shell?.classList.remove("is-live");
  accountLabel.textContent = "Local preview";
  accountState.textContent = "Preview";
  connectionLabel.textContent = "Start tokenbar api for live data";
  todayTokens.textContent = "84M";
  budgetState.textContent = "68%";
  budgetRing.style.setProperty("--budget-left", "68");
  cadenceState.textContent = "21d";
  costState.textContent = "Set price";
  renderCostPassport({
    estimate: null,
    range: "30-day local window",
    uncertainty: null,
    action: "Set dollars per million tokens, then copy the passport.",
    live: false,
  });
  renderGuide({}, false);
  renderSurfaceRelay();
  renderWasteLens({}, false);
  renderPlaybookVault({}, false);
  reminderState.textContent = "Open a playbook before the run grows.";
  renderRunwayBrief({}, false);
  renderMemoryPressure({}, false);
  storyKicker.textContent = "Local-only preview";
  storyTitle.textContent = "Run tokenbar api to connect the companion.";
  storyCopy.textContent = "This popup is read-only. It requests TokenBar's localhost bundle and never reads page text, prompts, source code, credentials, or accounts.";
  compositionTitle.textContent = "Preview provider mix";
  renderComposition(topProviders());
  renderProviderTruth({}, {});
  renderComparisonLens({}, false);
  renderProofPacket({}, false);
  renderLaunchCoach();
}

function renderBundle(bundle) {
  const identity = bundle?.identity || bundle?.builderIdentity || {};
  const stats = bundle?.stats || bundle?.usage || {};
  const reminders = bundle?.reminders || {};
  const memoryPressure = bundle?.memoryPressure || bundle?.memory_pressure || {};
  const guide = bundle?.guide || {};
  const wasteLens = bundle?.wasteLens || bundle?.waste_lens || {};
  const playbooks = bundle?.playbooks || {};
  const providers = bundle?.providers || {};
  const comparisonLens = bundle?.comparisonLens || bundle?.comparison_lens || {};
  const proofPacket = bundle?.proofPacket || bundle?.proof_packet || {};
  const surfaceRelay = bundle?.ecosystem?.surfaceRelay || bundle?.surfaceRelay || bundle?.surface_relay || [];
  const usage = identity?.usage || {};
  const account = firstDefined(bundle?.account?.label, usage.accountLabel, identity.owner, identity.title, "Local TokenBar");
  const dayTokens = stats.dayTokens || usage.dayTokens || {};
  const modelTokens = stats.modelTokens || usage.modelTokens || {};
  const today = firstDefined(stats.todayTokens, usage.today_tokens, usage.today, usage.lastDayTokens, Object.values(dayTokens).at(-1), 0);
  const budgetPercent = clampPercent(firstDefined(usage.weeklyBudgetLeftPercent, usage.budgetLeftPercent, usage.guardrailLeftPercent, 68));
  const cadence = firstDefined(stats.activeDayCount, usage.active_days_last30, activeDays(dayTokens), 0);
  const cost = firstDefined(usage.projected_weekly_cost, usage.projectedWeeklyCost, usage.estimated_30d_cost, usage.estimated30dCost, null);
  const estimatedWindowCost = firstDefined(usage.estimated_30d_cost, usage.estimated30dCost, usage.projected_30d_cost, usage.projected30dCost, cost);
  const uncertainty = firstDefined(usage.uncertainty_percent, usage.uncertaintyPercent, stats.uncertainty_percent, stats.uncertaintyPercent, null);
  const costRange = firstDefined(usage.costWindowLabel, usage.windowLabel, stats.windowLabel, "30-day local window");
  const topReminder = reminders?.topReminder || {};
  const launchCoach = bundle?.launchCoach || bundle?.launch || {};
  const reminder = firstDefined(
    topReminder.action,
    topReminder.title,
    usage.topReminder,
    usage.reminder,
    identity.growthEdge,
    "Open a verifier-first playbook before the next long run.",
  );
  const title = firstDefined(identity.title, identity.profileTitle, identity.identityLabel, identity.archetype, "Builder proof ready");
  const subtitle = firstDefined(identity.subtitle, identity.labelRationale, "Local aggregate evidence is ready for the next budget decision.");

  shell?.classList.add("is-live");
  accountLabel.textContent = String(account).slice(0, 42);
  accountState.textContent = "Local";
  connectionLabel.textContent = "Live from 127.0.0.1:8769";
  todayTokens.textContent = compactTokens(today);
  budgetState.textContent = `${budgetPercent}%`;
  budgetRing.style.setProperty("--budget-left", String(budgetPercent));
  cadenceState.textContent = `${cadence}d`;
  costState.textContent = formatCost(cost);
  renderCostPassport({
    estimate: estimatedWindowCost,
    range: costRange,
    uncertainty,
    action: firstDefined(
      usage.costNextAction,
      usage.nextCostAction,
      Number(estimatedWindowCost) > 0
        ? "Copy the passport before changing budgets or sharing proof."
        : "Set a price assumption before using this as a cost signal.",
    ),
    live: true,
  });
  renderGuide(guide, Boolean(guide?.schema));
  renderSurfaceRelay(surfaceRelay);
  renderWasteLens(wasteLens, Boolean(wasteLens?.schema));
  renderPlaybookVault(playbooks, Boolean(playbooks?.schema));
  reminderState.textContent = String(reminder).slice(0, 86);
  renderRunwayBrief(reminders?.runwayBrief || bundle?.runwayBrief || {}, Boolean(reminders?.runwayBrief || bundle?.runwayBrief));
  renderMemoryPressure(memoryPressure, Boolean(memoryPressure?.schema));
  storyKicker.textContent = "Live local evidence";
  storyTitle.textContent = String(title).slice(0, 72);
  storyCopy.textContent = String(subtitle).slice(0, 170);
  compositionTitle.textContent = "Provider mix from local usage";
  renderComposition(topProviders(modelTokens));
  renderProviderTruth(providers, modelTokens);
  renderComparisonLens(comparisonLens, Boolean(comparisonLens?.schema));
  renderProofPacket(proofPacket, Boolean(proofPacket?.schema));
  renderLaunchCoach(launchCoach);
}

async function fetchJson(url, controller) {
  const response = await fetch(url, { signal: controller.signal, cache: "no-store" });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return response.json();
}

async function refreshBundle() {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 1600);
  try {
    renderBundle(await fetchJson(API_URL, controller));
    return;
  } catch {
    try {
      const statsPayload = await fetchJson(STATS_URL, controller);
      let remindersPayload = {};
      try {
        remindersPayload = await fetchJson(REMINDERS_URL, controller);
      } catch {
        remindersPayload = {};
      }
      let memoryPayload = {};
      try {
        memoryPayload = await fetchJson(MEMORY_URL, controller);
      } catch {
        memoryPayload = {};
      }
      let guidePayload = {};
      try {
        guidePayload = await fetchJson(GUIDE_URL, controller);
      } catch {
        guidePayload = {};
      }
      let wastePayload = {};
      try {
        wastePayload = await fetchJson(WASTE_URL, controller);
      } catch {
        wastePayload = {};
      }
      let playbooksPayload = {};
      try {
        playbooksPayload = await fetchJson(PLAYBOOKS_URL, controller);
      } catch {
        playbooksPayload = {};
      }
      let providersPayload = {};
      try {
        providersPayload = await fetchJson(PROVIDERS_URL, controller);
      } catch {
        providersPayload = {};
      }
      let comparisonPayload = {};
      try {
        comparisonPayload = await fetchJson(COMPARISON_URL, controller);
      } catch {
        comparisonPayload = {};
      }
      let proofPayload = {};
      try {
        proofPayload = await fetchJson(PROOF_PACKET_URL, controller);
      } catch {
        proofPayload = {};
      }
      renderBundle({ identity: null, stats: statsPayload.stats, reminders: remindersPayload, memoryPressure: memoryPayload, guide: guidePayload, wasteLens: wastePayload, playbooks: playbooksPayload, providers: providersPayload, comparisonLens: comparisonPayload, proofPacket: proofPayload, privacy: statsPayload.privacy });
      return;
    } catch {
      renderFallback();
    }
  } finally {
    clearTimeout(timeout);
  }
}

async function copyApiCommand() {
  try {
    await navigator.clipboard.writeText(API_COMMAND);
    copyApiButton.textContent = "Copied";
    setTimeout(() => { copyApiButton.textContent = "Copy API command"; }, 1200);
  } catch {
    copyApiButton.textContent = API_COMMAND;
  }
}

async function copyCommand(button) {
  const command = button?.dataset?.copyCommand;
  if (!command) return;
  try {
    await navigator.clipboard.writeText(command);
    const previous = button.textContent;
    button.textContent = "Copied";
    setTimeout(() => { button.textContent = previous; }, 1100);
  } catch {
    button.textContent = command;
  }
}

refreshButton?.addEventListener("click", refreshBundle);
copyApiButton?.addEventListener("click", copyApiCommand);
commandButtons.forEach((button) => button.addEventListener("click", () => copyCommand(button)));
guideButtons.forEach((button) => button.addEventListener("click", () => setGuideChoice(button.dataset.guideChoice, true)));
guideCopyButton?.addEventListener("click", () => {
  const selectedButtons = Array.from(guideOptions.querySelectorAll("[data-guide-choice]"));
  const selected = guideChoices.find((choice) => selectedButtons.some((button) => button.classList.contains("is-selected") && button.dataset.guideChoice === choice.key));
  if (!selected) return;
  setGuideChoice(selected.key, true);
});
wasteCopy?.addEventListener("click", () => copyCommand(wasteCopy));
playbooksCopy?.addEventListener("click", () => copyCommand(playbooksCopy));
runwayCopy?.addEventListener("click", () => copyCommand(runwayCopy));
providerDetailCopy?.addEventListener("click", () => {
  if (!selectedProviderKey) return;
  setProviderDetail(selectedProviderKey, true);
});
comparisonCopyCommand?.addEventListener("click", () => {
  comparisonCopyCommand.dataset.copyCommand = selectedComparisonCommand;
  copyCommand(comparisonCopyCommand);
});
proofCopyCommand?.addEventListener("click", () => {
  proofCopyCommand.dataset.copyCommand = selectedProofCommand;
  copyCommand(proofCopyCommand);
});
refreshBundle();
