import { APP_CONFIG } from "./modules/config.js";
import { api } from "./modules/api.js";
import { officialWorldCupGroups, rulesSummary, worldCupSelections, zebraTournamentOptions } from "./modules/mock-data.js";
import { avatarPresets } from "./modules/avatar-presets.js";
import {
  buildAvatarMarkup,
  buildTeamLabel,
  escapeHtml,
  fileToDataUrl,
  formatDateTime,
  getPredictionDeadline,
  getWinnerFromRegularTime,
  hasScores,
  isPredictionLocked,
  normalizeLooseText,
  parseSafeDate,
  requiresExtraTime,
  scorePrediction,
  sortRanking,
  summarizeCountdown,
} from "./modules/utils.js";

const selectionMap = new Map(worldCupSelections.map((selection) => [selection.name, selection]));
const GROUP_ORDER = "ABCDEFGHIJKL".split("");
const KNOCKOUT_ORDER = ["round32", "round16", "quarterfinal", "semifinal", "third-place", "final"];
const MATCHES_PER_PAGE = 12;

const getSortableTime = (value) => parseSafeDate(value)?.getTime() ?? Number.POSITIVE_INFINITY;
const chunkIntoPages = (items, pageSize = 4) =>
  ensureArray(items, "chunkIntoPages.items").reduce((pages, item, index) => {
    const pageIndex = Math.floor(index / pageSize);
    pages[pageIndex] ||= [];
    pages[pageIndex].push(item);
    return pages;
  }, []);
const getPhaseOrderIndex = (match) => {
  if (match?.phase === "group") return -1;
  const index = KNOCKOUT_ORDER.indexOf(match?.phase);
  return index === -1 ? Number.POSITIVE_INFINITY : index + GROUP_ORDER.length;
};

const state = {
  users: [],
  matches: [],
  predictions: [],
  bonusPredictions: {},
  coinEvents: [],
  chatMessages: [],
  minoritySnapshots: {},
  settings: {},
  currentUser: null,
  activeTab: "jogos",
  rankingFilter: "overall",
  phaseFilter: "all",
  matchFilter: "all",
  matchGroupFilter: "all",
  matchesPage: 1,
  selectedAvatarPreset: avatarPresets[0].id,
  editingPredictions: new Set(),
  editingBonusFields: new Set(),
  bonusDrafts: {},
  openCoinPanels: new Set(),
  openAnnulSelectors: new Set(),
  recentlySavedMatches: new Set(),
  matchSliderIndex: {},
  sliderTouch: null,
  coinTooltipTimer: null,
  activeCoinTooltipButton: null,
};

const elements = {
  bannerSlot: document.querySelector("#banner-slot"),
  rankingList: document.querySelector("#ranking-list"),
  upcomingMatches: document.querySelector("#upcoming-matches"),
  matchesGrid: document.querySelector("#matches-grid"),
  bonusForm: document.querySelector("#bonus-form"),
  bonusLockStatus: document.querySelector("#bonus-lock-status"),
  chatList: document.querySelector("#chat-list"),
  adminPanel: document.querySelector("#admin-panel"),
  adminUsersList: document.querySelector("#admin-users-list"),
  adminStats: document.querySelector("#admin-stats"),
  rulesSummary: document.querySelector("#rules-summary"),
  groupsGrid: document.querySelector("#groups-grid"),
  personalSummary: document.querySelector("#personal-summary"),
  quickPicksList: document.querySelector("#quick-picks-list"),
  predictionHistory: document.querySelector("#prediction-history"),
  nextDeadline: document.querySelector("#next-deadline"),
  matchesCount: document.querySelector("#matches-count"),
  playersCount: document.querySelector("#players-count"),
  themeToggle: document.querySelector("#theme-toggle"),
  authOpenButton: document.querySelector("#auth-open-button"),
  authRegisterTopButton: document.querySelector("#auth-register-top-button"),
  authDialog: document.querySelector("#auth-dialog"),
  authCloseButton: document.querySelector("#auth-close-button"),
  loginForm: document.querySelector("#login-form"),
  registerForm: document.querySelector("#register-form"),
  avatarPresets: document.querySelector("#avatar-presets"),
  rankingFilter: document.querySelector("#ranking-filter"),
  phaseFilter: document.querySelector("#phase-filter"),
  matchFilter: document.querySelector("#match-filter"),
  groupFilter: document.querySelector("#group-filter"),
  matchesPagination: document.querySelector("#matches-pagination"),
  chatForm: document.querySelector("#chat-form"),
  chatInput: document.querySelector("#chat-input"),
  toastSlot: document.querySelector("#toast-slot"),
  pendingAlertSlot: document.querySelector("#pending-alert-slot"),
  bannerForm: document.querySelector("#banner-form"),
  bannerInput: document.querySelector("#banner-input"),
  authTabs: [...document.querySelectorAll("[data-auth-tab]")],
  sessionChip: document.querySelector("#session-chip"),
  tabButtons: [...document.querySelectorAll("[data-tab-target]")],
  tabPanels: [...document.querySelectorAll("[data-tab-panel]")],
};

const bonusFieldDefinitions = [
  { key: "champion", label: "Campeao", type: "selection" },
  { key: "runnerUp", label: "Vice", type: "selection" },
  { key: "thirdPlace", label: "3Âº lugar", type: "selection" },
  { key: "fourthPlace", label: "4Âº lugar", type: "selection" },
  { key: "topScorer", label: "Artilheiro", type: "text" },
  { key: "bestGroupStageTeam", label: "Melhor campanha da fase de grupos", type: "selection" },
  { key: "totalGoals", label: "Total de gols da Copa", type: "number" },
  { key: "tournamentZebra", label: "Zebra do torneio", type: "zebra" },
];

const BOT_PROFILE = {
  id: "bot-central-da-resenha",
  userId: "bot-central-da-resenha",
  nickname: "CENTRAL DA RESENHA",
  avatarType: "preset",
  avatarValue: "preset-7",
  isBot: true,
};

const COIN_ACTION_TOOLTIPS = {
  "draw-protection": "Custa 1 moeda. Se seu palpite for empate e o jogo nÃ£o terminar empatado, vocÃª nÃ£o perde pontos.",
  "error-shield": "Custa 2 moedas. Se errar este jogo, a pontuaÃ§Ã£o negativa vira zero.",
  "annul-prediction": "Custa 3 moedas. Escolha um rival para zerar a pontuaÃ§Ã£o dele neste jogo. SÃ³ vale atÃ© as quartas.",
  "points-x2": "Custa 4 moedas. Multiplica por 2 os pontos ganhos ou perdidos neste jogo. SÃ³ vale atÃ© as quartas.",
  "points-x3": "Custa 5 moedas. Multiplica por 3 os pontos ganhos ou perdidos neste jogo. SÃ³ vale atÃ© as quartas.",
};

const getPredictionByUser = (userId, matchId) =>
  state.predictions.find((entry) => entry.userId === userId && entry.matchId === matchId);

const getCurrentUserPrediction = (matchId) =>
  state.currentUser ? getPredictionByUser(state.currentUser.id, matchId) : null;

const getSelection = (teamName) => selectionMap.get(teamName) || null;

const renderTeamMarkup = (teamName, extraClass = "", options = {}) => {
  const team = getSelection(teamName);
  const codeMarkup = team?.code && options.showCode ? `<span class="team-code">${escapeHtml(team.code)}</span>` : "";
  if (!team) {
    return `<span class="team-inline ${extraClass}">${codeMarkup}<span class="team-label-text">${escapeHtml(teamName)}</span></span>`;
  }
  return `<span class="team-inline ${extraClass}">${codeMarkup}${buildTeamLabel(team)}</span>`;
};

const loadTheme = () => {
  const saved = localStorage.getItem("bolao-theme");
  if (saved === "dark") document.body.classList.add("dark");
};

const toggleTheme = () => {
  document.body.classList.toggle("dark");
  localStorage.setItem("bolao-theme", document.body.classList.contains("dark") ? "dark" : "light");
};

const showToast = (message, type = "info") => {
  const node = document.createElement("div");
  node.className = `toast ${type}`;
  node.textContent = message;
  elements.toastSlot.appendChild(node);
  setTimeout(() => node.remove(), 3200);
};

const markMatchAsRecentlySaved = (matchId) => {
  if (!matchId) return;
  state.recentlySavedMatches.add(matchId);
  window.setTimeout(() => {
    state.recentlySavedMatches.delete(matchId);
    renderMatches();
  }, 1800);
};

const ensureArray = (value, label) => {
  if (Array.isArray(value)) return value;
  console.warn(`[bolao] ${label} nao veio como array. Usando fallback vazio.`, value);
  return [];
};

const ensureObject = (value, label) => {
  if (value && typeof value === "object" && !Array.isArray(value)) return value;
  console.warn(`[bolao] ${label} nao veio como objeto. Usando fallback vazio.`, value);
  return {};
};

const applyFreshData = (data) => {
  state.users = ensureArray(data?.users, "users");
  state.matches = ensureArray(data?.matches, "matches");
  state.predictions = ensureArray(data?.predictions, "predictions");
  state.bonusPredictions = ensureObject(data?.bonusPredictions, "bonusPredictions");
  state.coinEvents = ensureArray(data?.coinEvents, "coinEvents");
  state.chatMessages = ensureArray(data?.chatMessages, "chatMessages");
  state.minoritySnapshots = ensureObject(data?.minoritySnapshots, "minoritySnapshots");
  state.settings = ensureObject(data?.settings, "settings");
  state.currentUser = data.session || state.currentUser;
};

const syncState = async () => {
  const data = await api.bootstrap();
  applyFreshData(data);
  await freezeMinoritySnapshots();
  renderAll();
};

const hasBonusValue = (value) => {
  if (typeof value === "number") return Number.isFinite(value);
  return value != null && String(value).trim() !== "";
};

const getCurrentBonusValues = () => {
  return {
    ...(state.bonusPredictions[state.currentUser?.id] || {}),
    ...state.bonusDrafts,
  };
};

const placeholderPattern = /^(?:[12].{0,2}\s+do\s+Grupo\s+[A-L]|Melhor\s+3.{0,2}\s+(?:colocado|entre)|Vencedor\s+.+|Perdedor\s+.+)$/i;
const isPlaceholderTeam = (teamName = "") => placeholderPattern.test(String(teamName).trim());
const BONUS_VISIBILITY_WINDOW_MS = 24 * 60 * 60 * 1000;

const hashString = (value = "") =>
  String(value)
    .split("")
    .reduce((accumulator, character) => ((accumulator * 33 + character.charCodeAt(0)) >>> 0), 5381);

const getBonusGameIds = () => {
  const matches = [...ensureArray(state.matches, "state.matches")];
  if (!matches.length) return new Set();

  const targetSize = Math.max(1, Math.round(matches.length * 0.1));
  const ordered = matches
    .map((match) => ({
      id: match.id,
      weight: hashString(`${match.id}-${match.startsAt}-${match.phase}-${match.number}`),
    }))
    .sort((a, b) => a.weight - b.weight || a.id.localeCompare(b.id))
    .slice(0, targetSize);

  return new Set(ordered.map((entry) => entry.id));
};

const isBonusGame = (match) => Boolean(match?.id) && getBonusGameIds().has(match.id);

const isBonusVisible = (match) => {
  if (!isBonusGame(match)) return false;
  const startTime = getSortableTime(match?.startsAt);
  if (!Number.isFinite(startTime)) return false;
  return Date.now() >= startTime - BONUS_VISIBILITY_WINDOW_MS;
};

const getMatchMultiplier = (match) => (isBonusVisible(match) ? 2 : 1);

const applyMatchPoints = (match, partialScore) => ({
  ...partialScore,
  points: partialScore.points * getMatchMultiplier(match),
});

const isMatchReadyForPredictions = (match) => {
  if (!match) return false;
  if (match.phase === "group") return true;
  return !isPlaceholderTeam(match.homeTeam) && !isPlaceholderTeam(match.awayTeam);
};

const isTodayMatch = (match) => {
  const parsedDate = parseSafeDate(match?.startsAt);
  if (!parsedDate) return false;
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const matchDay = formatter.format(parsedDate);
  const today = formatter.format(new Date());
  return matchDay === today;
};

const getGroupPredictionPercentages = (matchId) => {
  const match = ensureArray(state.matches, "state.matches").find((entry) => entry.id === matchId);
  const predictions = ensureArray(state.predictions, "state.predictions").filter(
    (entry) => entry.matchId === matchId && !getPredictionAnnulment(entry.userId, matchId)
  );

  if (!match || !predictions.length) {
    return { home: 0, draw: 0, away: 0, total: predictions.length };
  }

  const tally = predictions.reduce(
    (accumulator, entry) => {
      if (!hasScores(entry.homeScore, entry.awayScore)) return accumulator;
      if (Number(entry.homeScore) === Number(entry.awayScore)) accumulator.draw += 1;
      else if (Number(entry.homeScore) > Number(entry.awayScore)) accumulator.home += 1;
      else accumulator.away += 1;
      return accumulator;
    },
    { home: 0, draw: 0, away: 0 }
  );

  const total = Math.max(predictions.length, 1);
  return {
    home: Math.round((tally.home / total) * 100),
    draw: Math.round((tally.draw / total) * 100),
    away: Math.round((tally.away / total) * 100),
    total: predictions.length,
  };
};

const getUserStats = (userId) => {
  const user = ensureArray(state.users, "state.users").find((entry) => entry.id === userId);
  if (!user) return null;

  const rankingEntry = getRanking().find((entry) => entry.id === userId);
  const allMatches = ensureArray(state.matches, "state.matches");
  const userPredictions = ensureArray(state.predictions, "state.predictions").filter((entry) => entry.userId === userId);
  const readyMatches = allMatches.filter((match) => isMatchReadyForPredictions(match));
  const pendingMatches = readyMatches.filter((match) => !getPredictionByUser(userId, match.id) && !isPredictionLocked(match));
  const completedBreakdowns = allMatches.map((match) => {
    const prediction = getPredictionByUser(userId, match.id);
    return getPredictionBreakdown(match, prediction ? { ...prediction, userId } : null);
  });
  const errors = completedBreakdowns.filter((entry) => entry.status === "miss").length;
  const resolved = completedBreakdowns.filter((entry) => entry.status !== "pending");
  const hitCount = completedBreakdowns.filter((entry) => entry.status === "exact" || entry.status === "result").length;
  const coinUsage = getCoinUsageCounts(userId);

  return {
    user,
    rank: rankingEntry?.rank || "-",
    points: rankingEntry?.points || 0,
    exact: rankingEntry?.exact || 0,
    result: rankingEntry?.result || 0,
    predicted: userPredictions.length,
    pending: pendingMatches.length,
    errors,
    considered: rankingEntry?.considered || 0,
    accuracy: resolved.length ? Math.round((hitCount / resolved.length) * 100) : 0,
    coins: getCoinBalance(userId),
    coinUsage,
  };
};

const getPerformanceTone = (accuracy) => {
  if (accuracy >= 65) return "good";
  if (accuracy >= 40) return "medium";
  return "low";
};

const pickMessage = (seed, options) => options[hashString(seed) % options.length];

const COIN_START_BALANCE = 10;
const LATE_EDIT_COST = 4;
const DRAW_PROTECTION_COST = 1;
const ERROR_SHIELD_COST = 2;
const ANNUL_COST = 3;
const POINTS_X2_COST = 4;
const POINTS_X3_COST = 5;
const PERSONAL_BONUS_COST = POINTS_X2_COST;
const LATE_EDIT_LIMIT = 2;
const LATE_EDIT_WINDOW_MS = 60 * 60 * 1000;
const ANNUL_ALLOWED_PHASES = new Set(["group", "round32", "round16", "quarterfinal"]);
const COIN_PHASES = new Set(["group", "round32", "round16", "quarterfinal"]);
const zebraStagePoints = {
  groupQualified: 1,
  round16: 2,
  quarterfinal: 3,
  semifinal: 4,
  final: 5,
};

const getCoinEvents = () => ensureArray(state.coinEvents, "state.coinEvents");

const getCoinBalance = (userId) => {
  const user = state.users.find((entry) => entry.id === userId);
  const spent = getCoinEvents()
    .filter((entry) => entry.userId === userId && !entry.cancelledAt)
    .reduce((sum, entry) => sum + Number(entry.cost || 0), 0);
  return Number(user?.coins ?? COIN_START_BALANCE) - spent;
};

const getCoinUsageCounts = (userId) =>
  getCoinEvents()
    .filter((entry) => entry.userId === userId && !entry.cancelledAt)
    .reduce(
      (accumulator, entry) => {
        if (entry.type === "points-x2" || entry.type === "personal-bonus") accumulator.personalBonus += 1;
        if (entry.type === "points-x3") accumulator.superBonus += 1;
        if (entry.type === "draw-protection") accumulator.drawProtection += 1;
        if (entry.type === "error-shield") accumulator.errorShield += 1;
        if (entry.type === "late-edit") accumulator.lateEdit += 1;
        if (entry.type === "annul-prediction") accumulator.annul += 1;
        accumulator.totalSpent += Number(entry.cost || 0);
        return accumulator;
      },
      { personalBonus: 0, superBonus: 0, drawProtection: 0, errorShield: 0, lateEdit: 0, annul: 0, totalSpent: 0 }
    );

const getUserMatchEvents = (userId, matchId) =>
  getCoinEvents().filter((entry) => entry.matchId === matchId && (entry.userId === userId || entry.targetUserId === userId));

const getLatestCoinEvent = (predicate) =>
  [...getCoinEvents()].reverse().find(predicate) || null;

const getLatestActiveCoinEvent = (predicate) =>
  getLatestCoinEvent((entry) => !entry.cancelledAt && predicate(entry));

const getPredictionOutcome = (prediction) => {
  if (!prediction || !hasScores(prediction.homeScore, prediction.awayScore)) return null;
  if (Number(prediction.homeScore) === Number(prediction.awayScore)) return "draw";
  return Number(prediction.homeScore) > Number(prediction.awayScore) ? "home" : "away";
};

const getMinorityEligiblePredictions = (match) => {
  const deadline = getPredictionDeadline(match.startsAt);
  const cutoff = parseSafeDate(deadline)?.getTime() ?? Number.POSITIVE_INFINITY;
  return ensureArray(state.predictions, "state.predictions").filter((entry) => {
    if (entry.matchId !== match.id) return false;
    if (!hasScores(entry.homeScore, entry.awayScore)) return false;
    if (getPredictionAnnulment(entry.userId, match.id)) return false;
    const updatedAt = parseSafeDate(entry.updatedAt || entry.createdAt)?.getTime();
    return !updatedAt || updatedAt <= cutoff;
  });
};

const computeMinoritySnapshot = (match) => {
  const predictions = getMinorityEligiblePredictions(match);
  const total = predictions.length;
  const tally = predictions.reduce(
    (accumulator, entry) => {
      const outcome = getPredictionOutcome(entry);
      if (outcome) accumulator[outcome] += 1;
      return accumulator;
    },
    { home: 0, draw: 0, away: 0 }
  );

  const minorityOutcomes = total
    ? Object.entries(tally)
        .filter(([, count]) => (count / total) * 100 <= 20)
        .map(([outcome]) => outcome)
    : [];

  return {
    matchId: match.id,
    total,
    tally,
    minorityOutcomes,
    lockedAt: getPredictionDeadline(match.startsAt),
  };
};

const ensureMinoritySnapshot = async (match) => {
  if (!match || !isPredictionLocked(match) || state.minoritySnapshots[match.id]) return state.minoritySnapshots[match.id] || null;
  const snapshot = computeMinoritySnapshot(match);
  state.minoritySnapshots[match.id] = snapshot;
  if (typeof api.saveMinoritySnapshot === "function") {
    await api.saveMinoritySnapshot(match.id, snapshot);
  }
  return snapshot;
};

const freezeMinoritySnapshots = async () => {
  const lockedMatches = ensureArray(state.matches, "state.matches").filter((match) => isPredictionLocked(match));
  for (const match of lockedMatches) {
    await ensureMinoritySnapshot(match);
  }
};

const getPredictionAnnulment = (userId, matchId) =>
  getLatestActiveCoinEvent((entry) => entry.type === "annul-prediction" && entry.targetUserId === userId && entry.matchId === matchId);

const getUserAnnulmentAction = (userId, matchId) =>
  getLatestActiveCoinEvent((entry) => entry.type === "annul-prediction" && entry.userId === userId && entry.matchId === matchId);

const getPersonalBonusEvent = (userId, matchId) =>
  getLatestActiveCoinEvent((entry) => (entry.type === "personal-bonus" || entry.type === "points-x2") && entry.userId === userId && entry.matchId === matchId);

const getSuperBonusEvent = (userId, matchId) =>
  getLatestActiveCoinEvent((entry) => entry.type === "points-x3" && entry.userId === userId && entry.matchId === matchId);

const getDrawProtectionEvent = (userId, matchId) =>
  getLatestActiveCoinEvent((entry) => entry.type === "draw-protection" && entry.userId === userId && entry.matchId === matchId);

const getErrorShieldEvent = (userId, matchId) =>
  getLatestActiveCoinEvent((entry) => entry.type === "error-shield" && entry.userId === userId && entry.matchId === matchId);

const getLateEditEvent = (userId, matchId) =>
  getLatestActiveCoinEvent((entry) => entry.type === "late-edit" && entry.userId === userId && entry.matchId === matchId);

const getAutomaticMultiplier = (match) => {
  if (!match) return 1;
  if (match.phase === "final") return 3;
  if (match.phase === "semifinal" || match.phase === "third-place") return 2;
  return 1;
};

const canUseLateEditWindow = (match) => {
  const start = getSortableTime(match?.startsAt);
  return Number.isFinite(start) && Date.now() >= start && Date.now() <= start + LATE_EDIT_WINDOW_MS;
};

const getUserMatchEffects = (userId, match) => {
  const autoMultiplier = getAutomaticMultiplier(match);
  if (!userId || !match) {
    const multiplier = Math.max(autoMultiplier, getMatchMultiplier(match));
    return {
      multiplier,
      bonusLabel: multiplier >= 3 ? "Jogo Super BÃ´nus x3" : multiplier === 2 ? "Jogo BÃ´nus x2" : null,
      autoMultiplier,
      personalBonus: false,
      superBonus: false,
      globalBonus: isBonusVisible(match),
      drawProtection: false,
      errorShield: false,
      lateEdit: false,
      annulled: false,
      annulledBy: null,
    };
  }

  const personalBonus = Boolean(getPersonalBonusEvent(userId, match.id));
  const superBonus = Boolean(getSuperBonusEvent(userId, match.id));
  const drawProtection = Boolean(getDrawProtectionEvent(userId, match.id));
  const errorShield = Boolean(getErrorShieldEvent(userId, match.id));
  const lateEditEvent = getLateEditEvent(userId, match.id);
  const lateEdit = Boolean(lateEditEvent);
  const annulment = getPredictionAnnulment(userId, match.id);
  const globalBonus = isBonusVisible(match);
  const manualMultiplier = superBonus ? 3 : personalBonus || globalBonus ? 2 : 1;
  const multiplier = autoMultiplier > 1 ? autoMultiplier : manualMultiplier;
  const bonusLabel = multiplier === 3 ? "Jogo Super BÃ´nus x3" : multiplier === 2 ? "Jogo BÃ´nus x2" : null;

  return {
    multiplier,
    bonusLabel,
    autoMultiplier,
    personalBonus,
    superBonus,
    globalBonus,
    drawProtection,
    errorShield,
    lateEdit,
    lateEditUnlocked: Boolean(lateEditEvent && !lateEditEvent.consumedAt),
    annulled: Boolean(annulment),
    annulledBy: annulment?.userId || null,
    annulment,
  };
};

const getPredictionBreakdown = (match, prediction) => {
  const userId = prediction?.userId || null;
  const effects = getUserMatchEffects(userId, match);

  if (effects.annulled) {
    return { status: "annulled", label: "Palpite anulado", points: 0, exact: 0, result: 0, considered: 0, minorityBonus: 0, effects };
  }

  if (!prediction) {
    return { status: "pending", label: "Pendente", points: 0, exact: 0, result: 0, considered: 0, minorityBonus: 0, effects };
  }

  if (match.scoreHome == null || match.scoreAway == null) {
    return { status: "pending", label: "Aguardando resultado", points: 0, exact: 0, result: 0, considered: 0, minorityBonus: 0, effects };
  }

  let partial = scorePrediction(match, prediction);
  if (effects.drawProtection && getPredictionOutcome(prediction) === "draw" && partial.points < 0) {
    partial = { ...partial, points: 0 };
  }
  if (effects.errorShield && partial.points < 0) {
    partial = { ...partial, points: 0 };
  }

  const snapshot = state.minoritySnapshots[match.id] || null;
  const outcome = getPredictionOutcome(prediction);
  const minorityBonus = snapshot && outcome && snapshot.minorityOutcomes.includes(outcome) && (partial.exact > 0 || partial.result > 0) ? 0.25 : 0;
  const totalPoints = (partial.points + minorityBonus) * effects.multiplier;

  if (partial.exact > 0) {
    return { status: "exact", label: "Acertou o placar", points: totalPoints, exact: partial.exact, result: partial.result, considered: partial.considered, minorityBonus, effects };
  }
  if (partial.result > 0) {
    return { status: "result", label: "Acertou o resultado", points: totalPoints, exact: partial.exact, result: partial.result, considered: partial.considered, minorityBonus, effects };
  }
  return { status: "miss", label: "Errou", points: totalPoints, exact: partial.exact, result: partial.result, considered: partial.considered, minorityBonus, effects };
};

const getZebraStagePoints = (teamName, resultsData) => {
  const stage = resultsData?.zebraStageByTeam?.[teamName];
  if (!stage) return 0;
  let points = 0;
  if (stage === "groupQualified" || stage === "round16" || stage === "quarterfinal" || stage === "semifinal" || stage === "final") {
    points += zebraStagePoints.groupQualified;
  }
  if (stage === "round16" || stage === "quarterfinal" || stage === "semifinal" || stage === "final") {
    points += zebraStagePoints.round16;
  }
  if (stage === "quarterfinal" || stage === "semifinal" || stage === "final") {
    points += zebraStagePoints.quarterfinal;
  }
  if (stage === "semifinal" || stage === "final") {
    points += zebraStagePoints.semifinal;
  }
  if (stage === "final") {
    points += zebraStagePoints.final;
  }
  return points;
};

const getEligibleAnnulTargets = (match, currentUserId) =>
  ensureArray(state.users, "state.users").filter((user) => {
    if (user.id === currentUserId) return false;
    if (!getPredictionByUser(user.id, match.id)) return false;
    if (getPredictionAnnulment(user.id, match.id)) return false;
    return true;
  });

const getRanking = () => {
  const results = ensureArray(state.users, "state.users").map((user) => {
    const stats = {
      ...user,
      points: 0,
      exact: 0,
      result: 0,
      considered: 0,
    };

    ensureArray(state.matches, "state.matches").forEach((match) => {
      const prediction = getPredictionByUser(user.id, match.id);
      const breakdown = getPredictionBreakdown(match, prediction ? { ...prediction, userId: user.id } : null);
      stats.points += breakdown.points;
      stats.exact += breakdown.exact || 0;
      stats.result += breakdown.result || 0;
      stats.considered += breakdown.considered || 0;
    });

    if (state.bonusPredictions[user.id] && state.settings?.bonusResults) {
      const bonus = state.bonusPredictions[user.id];
      const resultsData = state.settings.bonusResults;
      if (bonus.champion === resultsData.champion) stats.points += 5;
      if (bonus.runnerUp === resultsData.runnerUp) stats.points += 3;
      if (bonus.thirdPlace === resultsData.thirdPlace) stats.points += 2;
      if (bonus.fourthPlace === resultsData.fourthPlace) stats.points += 2;
      if (normalizeLooseText(bonus.topScorer) === normalizeLooseText(resultsData.topScorer)) stats.points += 1.5;
      if (bonus.bestGroupStageTeam === resultsData.bestGroupStageTeam) stats.points += 2;
      if (
        typeof bonus.totalGoals === "number" &&
        typeof resultsData.totalGoals === "number" &&
        Math.abs(resultsData.totalGoals - bonus.totalGoals) === resultsData.totalGoalsWinnerDistance
      ) {
        stats.points += 1;
      }
      if (bonus.tournamentZebra) {
        stats.points += getZebraStagePoints(bonus.tournamentZebra, resultsData);
      }
    }

    return stats;
  });

  const ranking = sortRanking(results).map((entry, index) => ({
    ...entry,
    rank: index + 1,
    movement:
      entry.previousRank == null
        ? "same"
        : entry.previousRank > index + 1
          ? "up"
          : entry.previousRank < index + 1
            ? "down"
            : "same",
  }));

  if (state.rankingFilter === "exact") {
    return [...ranking].sort((a, b) => b.exact - a.exact || b.points - a.points);
  }

  if (state.rankingFilter === "results") {
    return [...ranking].sort((a, b) => b.result - a.result || b.points - a.points);
  }

  return ranking;
};

const getVisibleMatches = () =>
  ensureArray(state.matches, "state.matches").filter((match) => {
    const matchesPhase =
      state.phaseFilter === "all"
        ? true
        : state.phaseFilter === "knockout"
          ? match?.phase !== "group"
          : match?.phase === state.phaseFilter;

    if (!matchesPhase) return false;
    if (state.matchGroupFilter !== "all") {
      if (match?.phase !== "group") return false;
      if (match?.group !== state.matchGroupFilter) return false;
    }

    if (state.matchFilter === "all") return true;
    if (state.matchFilter === "pending") {
      return state.currentUser ? !getCurrentUserPrediction(match.id) && isMatchReadyForPredictions(match) : true;
    }
    if (state.matchFilter === "predicted") {
      return state.currentUser ? Boolean(getCurrentUserPrediction(match.id)) : false;
    }
    if (state.matchFilter === "today") return isTodayMatch(match);
    if (state.matchFilter === "upcoming") return getSortableTime(match?.startsAt) >= Date.now();
    if (state.matchFilter === "bonus") return isBonusVisible(match);
    return true;
  }).sort((a, b) => {
    if (a?.phase === "group" && b?.phase === "group") {
      const groupDiff = GROUP_ORDER.indexOf(a.group) - GROUP_ORDER.indexOf(b.group);
      if (groupDiff !== 0) return groupDiff;
      return getSortableTime(a?.startsAt) - getSortableTime(b?.startsAt);
    }
    if (a?.phase === "group") return -1;
    if (b?.phase === "group") return 1;
    const phaseDiff = getPhaseOrderIndex(a) - getPhaseOrderIndex(b);
    if (phaseDiff !== 0) return phaseDiff;
    return getSortableTime(a?.startsAt) - getSortableTime(b?.startsAt);
  });

const groupVisibleMatches = (matches) => {
  const sections = [];
  GROUP_ORDER.forEach((group) => {
    const groupMatches = matches.filter((match) => match.phase === "group" && match.group === group);
    if (groupMatches.length) {
      sections.push({ key: `group-${group}`, label: `Grupo ${group}`, matches: groupMatches });
    }
  });

  KNOCKOUT_ORDER.forEach((phase) => {
    const phaseMatches = matches.filter((match) => match.phase === phase);
    if (phaseMatches.length) {
      sections.push({ key: `phase-${phase}`, label: phaseMatches[0].phaseLabel, matches: phaseMatches });
    }
  });

  return sections;
};

const getPaginatedMatches = (matches) => {
  const totalPages = Math.max(1, Math.ceil(matches.length / MATCHES_PER_PAGE));
  state.matchesPage = Math.min(Math.max(state.matchesPage, 1), totalPages);
  const startIndex = (state.matchesPage - 1) * MATCHES_PER_PAGE;
  return {
    pageMatches: matches.slice(startIndex, startIndex + MATCHES_PER_PAGE),
    totalPages,
    currentPage: state.matchesPage,
  };
};

const getSelectionOptions = (selectedValue = "") =>
  worldCupSelections
    .map((selection) => {
      return `<option value="${escapeHtml(selection.name)}" ${selectedValue === selection.name ? "selected" : ""}>${escapeHtml(selection.name)}</option>`;
    })
    .join("");

const getZebraOptions = (selectedValue = "") =>
  ensureArray(state.settings.zebraTournamentOptions || zebraTournamentOptions, "zebraTournamentOptions")
    .map((entry) => {
      const label = `${entry.team} â€¢ Grupo ${entry.group}`;
      return `<option value="${escapeHtml(entry.team)}" ${selectedValue === entry.team ? "selected" : ""}>${escapeHtml(label)}</option>`;
    })
    .join("");

const renderGroups = () => {
  if (!elements.groupsGrid) return;

  elements.groupsGrid.innerHTML = officialWorldCupGroups.length
    ? officialWorldCupGroups
        .map(
          (groupEntry) => `
            <article class="group-table-card">
              <header class="group-table-header">
                <h4>Grupo ${escapeHtml(groupEntry.group)}</h4>
                <span class="muted">${groupEntry.teams.length} selecoes</span>
              </header>
              <ol class="group-team-list">
                ${groupEntry.teams
                  .map(
                    (team, index) => `
                      <li class="group-team-row">
                        <span class="group-team-rank">${index + 1}</span>
                        <div class="group-team-name">${buildTeamLabel(team, "team-flag--small")}</div>
                      </li>
                    `
                  )
                  .join("")}
              </ol>
            </article>
          `
        )
        .join("")
      : `<div class="empty-state">Nao foi possivel carregar os grupos.</div>`;
};

const renderPersonalSummary = () => {
  if (!elements.personalSummary) return;
  if (!state.currentUser) {
    elements.personalSummary.innerHTML = `<div class="empty-state">Entre para acompanhar seu desempenho pessoal.</div>`;
    return;
  }

  const stats = getUserStats(state.currentUser.id);
  if (!stats) {
    elements.personalSummary.innerHTML = `<div class="empty-state">Resumo indisponivel no momento.</div>`;
    return;
  }

  const tone = getPerformanceTone(stats.accuracy);
  const successTotal = stats.exact + stats.result;
  const barBase = Math.max(successTotal + stats.errors, 1);
  const successRatio = Math.round((successTotal / barBase) * 100);
  const missRatio = 100 - successRatio;
  const summaryCards = [
    { icon: "#", label: "PosiÃ§Ã£o", value: `#${stats.rank}` },
    { icon: "â—Ž", label: "Pontos", value: stats.points.toFixed(2) },
    { icon: "%", label: "Aproveitamento", value: `${stats.accuracy}%` },
    { icon: "â—", label: "Exatos", value: `${stats.exact}` },
    { icon: "â—", label: "Acertos", value: `${stats.result}` },
    { icon: "ðŸª™", label: "Moedas", value: `${stats.coins}` },
  ];

  elements.personalSummary.innerHTML = `
    <section class="personal-dashboard-card">
      <div class="personal-dashboard-header">
        <div>
          <p class="eyebrow">Seu painel</p>
          <h4>${escapeHtml(stats.user.nickname)}</h4>
        </div>
        <span class="pill ${tone === "good" ? "success" : tone === "medium" ? "warning" : "danger"}">${stats.pending} pendente(s)</span>
      </div>

      <div class="personal-kpi-grid">
        ${summaryCards
          .map(
            (card) => `
              <article class="personal-kpi-card">
                <span class="personal-kpi-icon">${card.icon}</span>
                <div>
                  <span class="personal-kpi-label">${card.label}</span>
                  <strong class="personal-kpi-value">${card.value}</strong>
                </div>
              </article>
            `
          )
          .join("")}
      </div>

      <div class="personal-dashboard-split">
        <article class="personal-insight-card">
          <div class="personal-progress-header">
            <span>Aproveitamento</span>
            <strong>${stats.accuracy}%</strong>
          </div>
          <div class="personal-progress-bar">
            <span class="personal-progress-fill personal-progress-fill--${tone}" style="width:${stats.accuracy}%;"></span>
          </div>
          <div class="personal-mini-stats">
            <span>${stats.predicted} palpites</span>
            <span>${stats.considered} jogos valendo</span>
          </div>
        </article>

        <article class="personal-insight-card">
          <div class="personal-progress-header">
            <span>Acertos x erros</span>
            <strong>${successTotal} / ${stats.errors}</strong>
          </div>
          <div class="personal-dual-bar">
            <span class="personal-dual-bar__hit" style="width:${successRatio}%;"></span>
            <span class="personal-dual-bar__miss" style="width:${missRatio}%;"></span>
          </div>
          <div class="personal-mini-stats">
            <span>Acertos: ${successTotal}</span>
            <span>Erros: ${stats.errors}</span>
          </div>
        </article>
      </div>

      <div class="personal-coin-grid">
        <article class="personal-coin-card">
          <span class="personal-kpi-label">Moedas usadas</span>
          <strong class="personal-kpi-value">${stats.coinUsage.totalSpent}</strong>
        </article>
        <article class="personal-coin-card">
          <span class="personal-kpi-label">BÃ´nus x2 pessoal</span>
          <strong class="personal-kpi-value">${stats.coinUsage.personalBonus}</strong>
        </article>
        <article class="personal-coin-card">
          <span class="personal-kpi-label">PontuaÃ§Ã£o x3</span>
          <strong class="personal-kpi-value">${stats.coinUsage.superBonus}</strong>
        </article>
        <article class="personal-coin-card">
          <span class="personal-kpi-label">Empate protegido</span>
          <strong class="personal-kpi-value">${stats.coinUsage.drawProtection}</strong>
        </article>
        <article class="personal-coin-card">
          <span class="personal-kpi-label">Seguro</span>
          <strong class="personal-kpi-value">${stats.coinUsage.errorShield}</strong>
        </article>
        <article class="personal-coin-card">
          <span class="personal-kpi-label">AlteraÃ§Ã£o tardia</span>
          <strong class="personal-kpi-value">${stats.coinUsage.lateEdit}/${LATE_EDIT_LIMIT}</strong>
        </article>
        <article class="personal-coin-card">
          <span class="personal-kpi-label">AnulaÃ§Ãµes</span>
          <strong class="personal-kpi-value">${stats.coinUsage.annul}</strong>
        </article>
      </div>
    </section>
  `;
};

const getBotMessages = () => {
  return getLiveBotMessages();

  Object.entries(bonusMap).forEach(([bucket, matchId]) => {
    const match = ensureArray(state.matches, "state.matches").find((entry) => entry.id === matchId);
    if (!match) return;
    messages.push({
      ...BOT_PROFILE,
      id: `bot-bonus-${bucket}`,
      message: `${match.phaseLabel}: ${match.homeTeam} x ${match.awayTeam}. Este aqui vale dobrado. Calma e planilha.`,
      createdAt: match.startsAt,
    });
  });

  const leader = ranking[0];
  if (leader) {
    messages.push({
      ...BOT_PROFILE,
      id: `bot-leader-${leader.id}`,
      message: `${leader.nickname} virou lider. O regulamento nao cita soberba, mas recomenda moderaÃ§Ã£o.`,
      createdAt: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
    });
  }

  ranking
    .filter((entry) => entry.movement === "up")
    .slice(0, 2)
    .forEach((entry, index) => {
      messages.push({
        ...BOT_PROFILE,
        id: `bot-rise-${entry.id}`,
        message: `${entry.nickname} subiu no ranking. Planejamento ou caos bem administrado, seguimos apurando.`,
        createdAt: new Date(Date.now() - 1000 * 60 * (18 + index)).toISOString(),
      });
    });

  ensureArray(state.predictions, "state.predictions")
    .slice(-4)
    .forEach((entry, index) => {
      const user = ensureArray(state.users, "state.users").find((item) => item.id === entry.userId);
      const match = ensureArray(state.matches, "state.matches").find((item) => item.id === entry.matchId);
      if (!user || !match) return;
      messages.push({
        ...BOT_PROFILE,
        id: `bot-prediction-${entry.userId}-${entry.matchId}`,
        message: `${user.nickname} salvou palpite em ${match.homeTeam} x ${match.awayTeam}. Planejamento ou excesso de confianÃ§a, ainda nao sabemos.`,
        createdAt: new Date(Date.now() - 1000 * 60 * (4 + index)).toISOString(),
      });
    });

  ensureArray(state.matches, "state.matches")
    .filter((match) => isMatchReadyForPredictions(match) && match.phase !== "group")
    .slice(0, 2)
    .forEach((match, index) => {
      messages.push({
        ...BOT_PROFILE,
        id: `bot-knockout-${match.id}`,
        message: `${match.phaseLabel} liberado: ${match.homeTeam} x ${match.awayTeam}. O drama agora tem CPF.`,
        createdAt: new Date(Date.now() - 1000 * 60 * (22 + index)).toISOString(),
      });
    });

  ensureArray(state.users, "state.users")
    .slice(0, 2)
    .forEach((user, index) => {
      const pending = getUserStats(user.id)?.pending || 0;
      if (!pending) return;
      messages.push({
        ...BOT_PROFILE,
        id: `bot-pending-${user.id}`,
        message: `${user.nickname} ainda tem ${pending} palpite(s) pendente(s). O prazo segue correndo sem apego emocional.`,
        createdAt: new Date(Date.now() - 1000 * 60 * (28 + index)).toISOString(),
      });
    });

  ensureArray(state.matches, "state.matches")
    .filter((match) => match.scoreHome != null && match.scoreAway != null)
    .slice(0, 4)
    .forEach((match, index) => {
      ensureArray(state.predictions, "state.predictions")
        .filter((entry) => entry.matchId === match.id)
        .slice(0, 1)
        .forEach((entry) => {
          const user = ensureArray(state.users, "state.users").find((item) => item.id === entry.userId);
          if (!user) return;
          const breakdown = getPredictionBreakdown(match, entry);
          if (breakdown.status === "pending") return;
          const messageByStatus = {
            exact: `${user.nickname} cravou o placar em ${match.homeTeam} x ${match.awayTeam}. Investigaremos acesso indevido ao futuro.`,
            result: `${user.nickname} acertou o resultado de ${match.homeTeam} x ${match.awayTeam}. Meio ponto de autoestima, no minimo.`,
            miss: `${user.nickname} errou com conviccao em ${match.homeTeam} x ${match.awayTeam}. O histÃ³rico registrou sem julgamento, quase sem julgamento.`,
          };
          messages.push({
            ...BOT_PROFILE,
            id: `bot-result-${entry.userId}-${match.id}`,
            message: messageByStatus[breakdown.status],
            createdAt: new Date(Date.now() - 1000 * 60 * (36 + index)).toISOString(),
          });
        });
    });

  return messages;
};

const renderBanner = () => {
  const banner = state.settings.banner;
  document.body.classList.toggle("has-sticky-banner", Boolean(banner?.message));
  elements.bannerSlot.innerHTML = banner?.message
    ? `<div class="banner"><strong>Aviso:</strong> ${escapeHtml(banner.message)}</div>`
    : "";
};

const renderSummary = () => {
  if (!elements.nextDeadline && !elements.matchesCount && !elements.playersCount) return;
  if (elements.matchesCount) elements.matchesCount.textContent = ensureArray(state.matches, "state.matches").length;
  if (elements.playersCount) elements.playersCount.textContent = ensureArray(state.users, "state.users").length;

  const nextMatch = [...ensureArray(state.matches, "state.matches")]
    .filter((match) => !isPredictionLocked(match))
    .sort((a, b) => getSortableTime(a?.startsAt) - getSortableTime(b?.startsAt))[0];

  const nextDeadline = nextMatch ? getPredictionDeadline(nextMatch.startsAt) : null;
  if (elements.nextDeadline) {
    elements.nextDeadline.textContent = nextMatch ? formatDateTime(nextDeadline) : "Todos fechados";
  }
};

const renderSessionChip = () => {
  if (!state.currentUser) {
    elements.sessionChip.hidden = true;
    elements.sessionChip.innerHTML = "";
    return;
  }

  elements.sessionChip.hidden = false;
  elements.sessionChip.innerHTML = `
    ${buildAvatarMarkup(state.currentUser)}
    <div>
      <strong>${escapeHtml(state.currentUser.nickname)}</strong>
      <span>${state.currentUser.isAdmin ? "Administrador" : "Participante"} â€¢ ${getCoinBalance(state.currentUser.id)} moedas</span>
    </div>
  `;
};

const renderRanking = () => {
  const ranking = getRanking();
  elements.rankingList.innerHTML = ranking.length
    ? ranking
        .map((entry) => {
          const icon = entry.movement === "up" ? "â–²" : entry.movement === "down" ? "â–¼" : "â€”";
          return `
            <article class="ranking-item ${entry.rank <= 3 ? "ranking-item--highlight" : ""} ranking-item--top-${entry.rank} ${state.currentUser?.id === entry.id ? "ranking-item--current-user" : ""}">
              <div class="ranking-position ranking-position--top-${entry.rank}">${entry.rank}</div>
              <div class="user-chip">
                ${buildAvatarMarkup(entry)}
                <div class="user-chip-text">
                  <strong class="ranking-nickname">${escapeHtml(entry.nickname)}</strong>
                  <div class="ranking-realname">${escapeHtml(entry.realName)}</div>
                </div>
              </div>
              <div class="ranking-side">
                <div class="ranking-points">${entry.points.toFixed(2)} pts</div>
                <div class="ranking-substats">${entry.exact} exatos â€¢ ${entry.result} resultados</div>
              </div>
              <div class="ranking-move ranking-move--${entry.movement}">
                <span>${icon}</span>
              </div>
            </article>
          `;
        })
        .join("")
    : `<div class="empty-state">Nenhum usuario cadastrado.</div>`;
};

const renderUpcomingMatches = () => {
  if (!elements.upcomingMatches) return;
  const nextMatches = [...ensureArray(state.matches, "state.matches")]
    .filter((match) => !isPredictionLocked(match))
    .sort((a, b) => getSortableTime(a?.startsAt) - getSortableTime(b?.startsAt))
    .slice(0, 6);

  elements.upcomingMatches.innerHTML = nextMatches.length
    ? nextMatches
        .map(
          (match) => `
            <article class="match-card match-card--compact">
              <header>
                <strong>${escapeHtml(match.phaseLabel)}</strong>
                <span class="pill warning">${summarizeCountdown(match.startsAt)}</span>
              </header>
              <div class="match-team">
                <div class="match-team-block">${renderTeamMarkup(match.homeTeam, "team-flag--small")}</div>
                <span class="match-fut-score-divider">x</span>
                <div class="match-team-block match-team-block--right">${renderTeamMarkup(match.awayTeam, "team-flag--small")}</div>
              </div>
              <div class="muted">${formatDateTime(match.startsAt)} â€¢ ${escapeHtml(match.stadium)}</div>
            </article>
          `
        )
        .join("")
    : `<div class="empty-state">Sem jogos abertos no momento.</div>`;
};

const renderPendingAlert = () => {
  if (!state.currentUser) {
    elements.pendingAlertSlot.innerHTML = "";
    return;
  }

  const pending = ensureArray(state.matches, "state.matches").filter((match) => {
    const untilStart = new Date(match.startsAt).getTime() - Date.now();
    return (
      untilStart > 0 &&
      untilStart <= APP_CONFIG.pendingPredictionWarningHours * 3600 * 1000 &&
      !getCurrentUserPrediction(match.id) &&
      !isPredictionLocked(match)
    );
  });

  elements.pendingAlertSlot.innerHTML = pending.length
    ? `<div class="banner"><strong>AtenÃ§Ã£o:</strong> voce ainda tem ${pending.length} palpite(s) pendente(s) nas proximas ${APP_CONFIG.pendingPredictionWarningHours} horas.</div>`
    : "";
};

const getMatchDeadlineMs = (startsAt) => parseSafeDate(getPredictionDeadline(startsAt))?.getTime() ?? 0;

const buildMatchStatus = (match, prediction) => {
  if (isPredictionLocked(match)) {
    return { label: "Fechado", className: "status-closed" };
  }
  if (prediction && !state.editingPredictions.has(match.id)) {
    return { label: "Palpite salvo", className: "saved" };
  }
  const timeUntilDeadline = getMatchDeadlineMs(match.startsAt) - Date.now();
  if (timeUntilDeadline <= 60 * 60 * 1000) {
    return { label: summarizeCountdown(match.startsAt), className: "status-critical pill--pulse" };
  }
  if (timeUntilDeadline <= 6 * 60 * 60 * 1000) {
    return { label: summarizeCountdown(match.startsAt), className: "status-urgent" };
  }
  if (timeUntilDeadline <= 24 * 60 * 60 * 1000) {
    return { label: summarizeCountdown(match.startsAt), className: "status-attention" };
  }
  return { label: summarizeCountdown(match.startsAt), className: "status-open" };
};

const getCompactPointsState = (breakdown) => {
  if (!breakdown || breakdown.status === "pending") {
    return { className: "compact-points-earned--waiting", label: "Em espera" };
  }
  const points = Number(breakdown.points || 0);
  if (points > 0) {
    return { className: "compact-points-earned--positive", label: `+${points.toFixed(2)} pts` };
  }
  if (points < 0) {
    return { className: "compact-points-earned--negative", label: `${points.toFixed(2)} pts` };
  }
  return { className: "compact-points-earned--neutral", label: "0 pts" };
};

const renderCompactDistribution = (percentages) => {
  const home = Number(percentages?.home || 0);
  const draw = Number(percentages?.draw || 0);
  const away = Number(percentages?.away || 0);
  return `
    <div class="compact-market">
      <div class="compact-market-bar" aria-hidden="true">
        <span class="compact-market-bar__slice compact-market-bar__slice--home" style="width:${home}%;"></span>
        <span class="compact-market-bar__slice compact-market-bar__slice--draw" style="width:${draw}%;"></span>
        <span class="compact-market-bar__slice compact-market-bar__slice--away" style="width:${away}%;"></span>
      </div>
      <div class="compact-market-legend">
        <span>C ${home}%</span>
        <span>E ${draw}%</span>
        <span>F ${away}%</span>
      </div>
    </div>
  `;
};

const renderMechanicBadges = (effects) => {
  const badges = [];
  if (effects.bonusLabel) badges.push(`<span class="pill bonus-pill">âš¡ ${effects.bonusLabel}</span>`);
  if (effects.drawProtection) badges.push(`<span class="pill neutral">âš– Empate protegido</span>`);
  if (effects.errorShield) badges.push(`<span class="pill neutral">ðŸª™ Seguro de erro</span>`);
  if (effects.lateEdit) badges.push(`<span class="pill warning">ðŸª™ AlteraÃ§Ã£o tardia</span>`);
  if (effects.annulled) badges.push(`<span class="pill danger">ðŸ’£ Palpite anulado</span>`);
  return badges.join("");
};

const getCoinActionAvailability = (match, prediction, effects, userId) => {
  const balance = getCoinBalance(userId);
  const lateEditCount = getCoinUsageCounts(userId).lateEdit;
  const eligibleTargets = getEligibleAnnulTargets(match, userId);
  const existingAnnulment = getUserAnnulmentAction(userId, match.id);
  const hasPrediction = Boolean(prediction);
  const canInteract = hasPrediction && !effects.annulled;
  const coinPhaseAllowed = COIN_PHASES.has(match.phase);
  const autoMultiplierActive = getAutomaticMultiplier(match) > 1;
  const predictionOutcome = getPredictionOutcome(prediction);
  return {
    canDrawProtection:
      canInteract &&
      coinPhaseAllowed &&
      !effects.drawProtection &&
      predictionOutcome === "draw" &&
      balance >= DRAW_PROTECTION_COST &&
      !isPredictionLocked(match),
    canPersonalBonus:
      canInteract &&
      coinPhaseAllowed &&
      !effects.personalBonus &&
      !effects.superBonus &&
      balance >= POINTS_X2_COST &&
      !isPredictionLocked(match) &&
      !effects.globalBonus &&
      !autoMultiplierActive,
    canSuperBonus:
      canInteract &&
      coinPhaseAllowed &&
      !effects.superBonus &&
      !effects.personalBonus &&
      balance >= POINTS_X3_COST &&
      !isPredictionLocked(match) &&
      !effects.globalBonus &&
      !autoMultiplierActive,
    canErrorShield:
      canInteract &&
      coinPhaseAllowed &&
      !effects.errorShield &&
      balance >= ERROR_SHIELD_COST &&
      !isPredictionLocked(match),
    canLateEditUnlock:
      canInteract &&
      !effects.lateEditUnlocked &&
      balance >= LATE_EDIT_COST &&
      canUseLateEditWindow(match) &&
      lateEditCount < LATE_EDIT_LIMIT,
    canAnnul:
      Boolean(existingAnnulment) ||
      (balance >= ANNUL_COST &&
        !isPredictionLocked(match) &&
        ANNUL_ALLOWED_PHASES.has(match.phase) &&
        eligibleTargets.length > 0),
    coinPhaseAllowed,
    autoMultiplierActive,
    eligibleTargets,
    lateEditCount,
  };
};

const renderMatchCard = (match) => {
  if (!match || typeof match !== "object") {
    return `<article class="match-card"><div class="empty-state">Dados do jogo indisponiveis.</div></article>`;
  }

  const locked = isPredictionLocked(match);
  const prediction = getCurrentUserPrediction(match.id);
  const enrichedPrediction = prediction ? { ...prediction, userId: state.currentUser?.id } : null;
  const isKnockout = match.phase !== "group";
  const effects = getUserMatchEffects(state.currentUser?.id, match);
  const canLockedEdit = effects.lateEditUnlocked && canUseLateEditWindow(match);
  const isSaved = Boolean(prediction) && !(locked && canLockedEdit) && !state.editingPredictions.has(match.id);
  const disableFields = (locked && !canLockedEdit) || isSaved;
  const extraFieldsVisible = isKnockout && requiresExtraTime(prediction?.homeScore ?? "", prediction?.awayScore ?? "");
  const publicPredictions = locked ? state.predictions.filter((entry) => entry.matchId === match.id) : [];
  const status = buildMatchStatus(match, prediction);
  const winnerValue = extraFieldsVisible
    ? prediction?.winnerTeam || ""
    : getWinnerFromRegularTime(match.homeTeam, match.awayTeam, prediction?.homeScore ?? "", prediction?.awayScore ?? "");
  const readyForPrediction = isMatchReadyForPredictions(match);
  const percentages = getGroupPredictionPercentages(match.id);
  const bonusBadge = renderMechanicBadges(effects);
  const actionState = state.currentUser ? getCoinActionAvailability(match, prediction, effects, state.currentUser.id) : null;
  const annulledByUser = effects.annulled ? state.users.find((user) => user.id === effects.annulledBy) : null;
  const coinPanelOpen = state.openCoinPanels.has(match.id);
  const predictionDeadline = getPredictionDeadline(match.startsAt);

  return `
    <article class="match-card ${locked ? "match-card--locked" : ""} ${isSaved ? "match-card--saved" : "match-card--open"}">
      <header>
        <div>
          <strong>J${match.number} â€¢ ${escapeHtml(match.phaseLabel)}</strong>
          <div class="muted">${formatDateTime(match.startsAt)} â€¢ ${escapeHtml(match.location)}</div>
        </div>
        <span class="pill ${status.className}">${status.label}</span>
      </header>

      <div class="match-team">
        <div class="match-team-block">${renderTeamMarkup(match.homeTeam)}</div>
        <span class="match-fut-score-divider">x</span>
        <div class="match-team-block match-team-block--right">${renderTeamMarkup(match.awayTeam)}</div>
      </div>

      <div class="prediction-market-share">
        <span>${percentages.home}% casa</span>
        <span>${percentages.draw}% empate</span>
        <span>${percentages.away}% fora</span>
        <span>${percentages.total} palpite(s)</span>
      </div>

      <div class="match-effect-badges">${bonusBadge}</div>

      ${
        state.currentUser
          ? `
            <form
              class="prediction-form"
              data-match-id="${match.id}"
              data-home-team="${escapeHtml(match.homeTeam)}"
              data-away-team="${escapeHtml(match.awayTeam)}"
              data-knockout="${isKnockout}"
              >
                <div class="prediction-area ${isSaved ? "prediction-area--saved" : ""}">
                  ${effects.annulled ? `<div class="saved-note saved-note--danger">${escapeHtml(annulledByUser?.nickname || "Alguem")} pagou 5 moedas e anulou seu palpite para este jogo.</div>` : ""}
                  ${!readyForPrediction ? `<div class="saved-note">Palpite sera liberado quando o confronto oficial for definido.</div>` : ""}
                  <div class="score-grid">
                  <label class="score-field">
                    <span>${escapeHtml(match.homeCode)}</span>
                      <input class="text-input score-input" type="number" min="0" name="homeScore" placeholder="0" value="${prediction?.homeScore ?? ""}" ${(disableFields || !readyForPrediction) ? "disabled" : ""} />
                  </label>
                  <label class="score-field">
                    <span>${escapeHtml(match.awayCode)}</span>
                      <input class="text-input score-input" type="number" min="0" name="awayScore" placeholder="0" value="${prediction?.awayScore ?? ""}" ${(disableFields || !readyForPrediction) ? "disabled" : ""} />
                  </label>
                </div>

                ${
                  isKnockout
                    ? `
                      <div class="knockout-panel">
                        <div class="match-helper">
                          ${
                            extraFieldsVisible
                              ? "Empate detectado no tempo normal. Preencha a prorrogacao e escolha quem avanca."
                              : "Sem empate no tempo normal, a prorrogacao fica escondida e o classificado acompanha o placar."
                          }
                        </div>

                        <div class="knockout-extra-fields" ${extraFieldsVisible ? "" : "hidden"}>
                          <div class="knockout-grid">
                            <label class="score-field">
                              <span>Prorrogacao ${escapeHtml(match.homeCode)}</span>
                              <input class="text-input score-input" type="number" min="0" name="extraTimeHome" placeholder="0" value="${extraFieldsVisible ? prediction?.extraTimeHome ?? "" : ""}" ${(disableFields || !extraFieldsVisible) ? "disabled" : ""} />
                            </label>
                            <label class="score-field">
                              <span>Prorrogacao ${escapeHtml(match.awayCode)}</span>
                              <input class="text-input score-input" type="number" min="0" name="extraTimeAway" placeholder="0" value="${extraFieldsVisible ? prediction?.extraTimeAway ?? "" : ""}" ${(disableFields || !extraFieldsVisible) ? "disabled" : ""} />
                            </label>
                          </div>
                        </div>

                        <label class="field-stack">
                          <span class="field-label">Quem avanca</span>
                          <select class="select-input" name="winnerTeam" ${(disableFields || !readyForPrediction || (!extraFieldsVisible && hasScores(prediction?.homeScore ?? "", prediction?.awayScore ?? ""))) ? "disabled" : ""}>
                            <option value="">Selecione</option>
                            <option value="${escapeHtml(match.homeTeam)}" ${winnerValue === match.homeTeam ? "selected" : ""}>${escapeHtml((getSelection(match.homeTeam)?.flag || "") + " " + match.homeTeam)}</option>
                            <option value="${escapeHtml(match.awayTeam)}" ${winnerValue === match.awayTeam ? "selected" : ""}>${escapeHtml((getSelection(match.awayTeam)?.flag || "") + " " + match.awayTeam)}</option>
                          </select>
                        </label>
                      </div>
                    `
                    : ""
                }

                <div class="prediction-actions">
                  ${
                    effects.annulled
                      ? `<span class="saved-note saved-note--danger">Este palpite foi anulado.</span>`
                      : locked && !canLockedEdit
                      ? `<span class="saved-note">Palpites fechados para este jogo.</span>`
                      : locked && canLockedEdit
                        ? `<span class="saved-note">AlteraÃ§Ã£o tardia liberada por moeda atÃ© 60 min apÃ³s o inÃ­cio.</span>`
                      : !readyForPrediction
                        ? `<span class="saved-note">Aguardando confronto oficial.</span>`
                      : isSaved
                          ? `
                            <span class="saved-note">Palpite salvo com sucesso.</span>
                          <button class="mini-button edit-prediction-button" data-edit-match="${match.id}" type="button">Editar palpite</button>
                        `
                        : `<button class="primary-button" type="submit">Salvar palpite</button>`
                  }
                </div>
                ${
                  actionState
                    ? `
                      <div class="match-tools-row">
                        <button class="ghost-button coin-toggle-button" data-toggle-coins="${match.id}" type="button">
                          ${coinPanelOpen ? "Ocultar moedas" : "Usar moedas"}
                        </button>
                      </div>
                    `
                    : ""
                }
              </div>
            </form>
            ${
              actionState && coinPanelOpen
                ? `
                  <div class="coin-actions-card">
                    <div class="coin-actions-header">
                      <strong>Moedas</strong>
                      <span class="pill neutral">Saldo: ${getCoinBalance(state.currentUser.id)}</span>
                    </div>
                    <div class="coin-actions-grid">
                      <button class="mini-button" data-coin-action="personal-bonus" data-match-id="${match.id}" type="button" ${actionState.canPersonalBonus ? "" : "disabled"}>âš¡ BÃ´nus x2 â€¢ 2ðŸª™</button>
                      <button class="mini-button" data-coin-action="error-shield" data-match-id="${match.id}" type="button" ${actionState.canErrorShield ? "" : "disabled"}>ðŸª™ Seguro â€¢ 1</button>
                      <button class="mini-button" data-coin-action="late-edit" data-match-id="${match.id}" type="button" ${actionState.canLateEditUnlock ? "" : "disabled"}>ðŸ•’ Alterar â€¢ 4</button>
                    </div>
                    <div class="coin-actions-footer">
                      <span class="muted">AlteraÃ§Ã£o tardia: ${actionState.lateEditCount}/${LATE_EDIT_LIMIT} uso(s).</span>
                      ${
                        actionState.canAnnul
                          ? `
                            <div class="annul-action-row">
                              <select class="select-input" data-annul-target="${match.id}">
                                <option value="">Escolha um rival</option>
                                ${actionState.eligibleTargets
                                  .map((user) => `<option value="${user.id}">${escapeHtml(user.nickname)}</option>`)
                                  .join("")}
                              </select>
                              <button class="danger-button" data-coin-action="annul-prediction" data-match-id="${match.id}" type="button">ðŸ’£ Anular â€¢ 5</button>
                            </div>
                          `
                          : `<span class="muted">AnulaÃ§Ã£o disponÃ­vel sÃ³ atÃ© as quartas, com mercado aberto e alvo jÃ¡ palpitado.</span>`
                      }
                    </div>
                  </div>
                `
                : ""
            }
          `
          : `<div class="empty-state">Entre para palpitar neste jogo.</div>`
      }

      ${
        publicPredictions.length
          ? `
            <div class="public-predictions">
              <strong>Palpites liberados</strong>
              <div class="matches-list">
                ${publicPredictions
                  .map((entry) => {
                    const user = state.users.find((item) => item.id === entry.userId);
                    return `
                      <div class="match-row public-prediction-row">
                        ${buildAvatarMarkup(user)}
                        <span>
                          ${escapeHtml(user.nickname)}: ${entry.homeScore} x ${entry.awayScore}
                          ${entry.winnerTeam ? ` â€¢ ${escapeHtml(entry.winnerTeam)}` : ""}
                        </span>
                      </div>
                    `;
                  })
                  .join("")}
              </div>
            </div>
          `
          : ""
      }
    </article>
  `;
};

const renderCoinToggleButton = ({ action, matchId, label, cost, active, disabled }) => `
  <button
    class="coin-action-toggle ${active ? "coin-action-toggle--active" : ""}"
    data-coin-action="${action}"
    data-match-id="${matchId}"
    data-tooltip="${escapeHtml(COIN_ACTION_TOOLTIPS[action] || label)}"
    type="button"
    ${disabled && !active ? "disabled" : ""}
    title="${escapeHtml(label)}"
  >
    <strong>${escapeHtml(label)}</strong>
    <small>${Array.from({ length: Math.max(1, cost) }, () => "●").join(" ")}</small>
  </button>
`;

const renderCompactMechanicBadges = (effects) => {
  const badges = [];
  if (effects.bonusLabel && (effects.autoMultiplier > 1 || effects.globalBonus)) {
    badges.push(`<span class="pill bonus-pill bonus-pill--system">⚡ x${effects.autoMultiplier > 1 ? effects.autoMultiplier : 2} ativo</span>`);
  }
  if (effects.drawProtection) badges.push(`<span class="pill neutral">⚖ empate protegido</span>`);
  if (effects.errorShield) badges.push(`<span class="pill warning">🔒 seguro ativo</span>`);
  if (effects.annulled) badges.push(`<span class="pill danger">💣 adversário anulado</span>`);
  return badges.join("");
};

const renderCompactMatchCard = (match) => {
  if (!match || typeof match !== "object") {
    return `<article class="match-card match-card--compact-line"><div class="empty-state">Dados do jogo indisponiveis.</div></article>`;
  }

  const locked = isPredictionLocked(match);
  const prediction = getCurrentUserPrediction(match.id);
  const effects = getUserMatchEffects(state.currentUser?.id, match);
  const isKnockout = match.phase !== "group";
  const readyForPrediction = isMatchReadyForPredictions(match);
  const canLockedEdit = effects.lateEditUnlocked && canUseLateEditWindow(match);
  const isSaved = Boolean(prediction) && !(locked && canLockedEdit) && !state.editingPredictions.has(match.id);
  const disableFields = (locked && !canLockedEdit) || isSaved || !readyForPrediction || effects.annulled;
  const status = buildMatchStatus(match, prediction);
  const percentages = getGroupPredictionPercentages(match.id);
  const breakdown = state.currentUser
    ? getPredictionBreakdown(match, prediction ? { ...prediction, userId: state.currentUser.id } : null)
    : null;
  const actionState = state.currentUser ? getCoinActionAvailability(match, prediction, effects, state.currentUser.id) : null;
  const userAnnulment = state.currentUser ? getUserAnnulmentAction(state.currentUser.id, match.id) : null;
  const annulledTargetUser = userAnnulment ? state.users.find((user) => user.id === userAnnulment.targetUserId) : null;
  const annulSelectorOpen = state.openAnnulSelectors.has(match.id) && !userAnnulment;
  const targetOptions = actionState?.eligibleTargets
    ?.map((user) => `<option value="${user.id}">${escapeHtml(user.nickname)}</option>`)
    .join("") || "";
  const pointsState = getCompactPointsState(breakdown);

  return `
    <article class="match-card match-card-fut ${isSaved ? "match-card--saved" : ""} ${state.recentlySavedMatches.has(match.id) ? "match-card--recently-saved" : ""}">
      <form
        class="prediction-form match-fut-shell"
        data-match-id="${match.id}"
        data-home-team="${escapeHtml(match.homeTeam)}"
        data-away-team="${escapeHtml(match.awayTeam)}"
        data-knockout="${isKnockout}"
      >
        <div class="match-fut-header">
          <div class="match-fut-heading">
            <strong>JOGO ${match.number}</strong>
          </div>
          <small>${escapeHtml(match.group || match.phaseLabel)} • ${formatDateTime(match.startsAt).replace(",", " •")}</small>
          <span class="pill ${status.className}">${status.label}</span>
        </div>

        <div class="match-fut-teams"><div class="match-fut-team-card match-fut-team-card--home">${renderTeamMarkup(match.homeTeam, "", { showCode: true })}</div>

        <div class="match-fut-score">
          ${renderCompactDistribution(percentages)}
          <div class="match-fut-score-box">
            <input class="text-input score-input" type="number" min="0" name="homeScore" placeholder="0" value="${prediction?.homeScore ?? ""}" ${disableFields ? "disabled" : ""} />
            <span class="match-fut-score-divider">x</span>
            <input class="text-input score-input" type="number" min="0" name="awayScore" placeholder="0" value="${prediction?.awayScore ?? ""}" ${disableFields ? "disabled" : ""} />
            <input type="hidden" name="extraTimeHome" value="${prediction?.extraTimeHome ?? ""}" />
            <input type="hidden" name="extraTimeAway" value="${prediction?.extraTimeAway ?? ""}" />
            <input type="hidden" name="winnerTeam" value="${prediction?.winnerTeam ?? ""}" />
          </div>
        </div>

        <div class="match-fut-team-card match-fut-team-card--away">${renderTeamMarkup(match.awayTeam, "", { showCode: true })}</div></div>

        <div class="compact-actions">
          ${
            !state.currentUser
              ? `<span class="saved-note">Entre para palpitar</span>`
              : effects.annulled
                ? `<span class="saved-note saved-note--danger">Palpite anulado</span>`
                : locked && !canLockedEdit
                  ? `<span class="saved-note">Fechado</span>`
                  : !readyForPrediction
                    ? `<span class="saved-note">Aguardando confronto</span>`
                    : isSaved
                      ? `<button class="edit-prediction-button edit-prediction-button--saved match-fut-submit" data-edit-match="${match.id}" type="button">🔴 EDITAR PALPITE</button>`
                      : `<button class="primary-button compact-save-button match-fut-submit" type="submit">🟢 SALVAR PALPITE</button>`
          }
        </div>
      <div class="match-fut-strategy">
        <div class="match-fut-strategy-title">Estratégia</div><div class="match-fut-effects-wrap">
          ${renderCompactMechanicBadges(effects) ? `<div class="match-fut-effects">${renderCompactMechanicBadges(effects)}</div>` : ""}
          </div><div class="match-fut-footer"><div class="compact-points-earned ${pointsState.className}">
            <span class="compact-points-earned__label">Pontos neste jogo:</span>
            <strong class="compact-points-earned__value">${!state.currentUser ? "â€”" : pointsState.label}</strong>
          </div>
          <div class="match-fut-footer-actions">${
              !state.currentUser
                ? `<span class="saved-note">Entre para palpitar</span>`
                : effects.annulled
                  ? `<span class="saved-note saved-note--danger">Palpite anulado</span>`
                  : locked && !canLockedEdit
                    ? `<span class="saved-note">Fechado</span>`
                    : !readyForPrediction
                      ? `<span class="saved-note">Aguardando confronto</span>`
                      : isSaved
                        ? `<button class="edit-prediction-button edit-prediction-button--saved match-fut-submit" data-edit-match="${match.id}" type="button">🔴 EDITAR PALPITE</button>`
                        : `<button class="primary-button compact-save-button match-fut-submit" type="submit">🟢 SALVAR PALPITE</button>`
            }</div></div>
        ${
          actionState
            ? `
              <div class="compact-coin-actions match-fut-chips">
                ${renderCoinToggleButton({ action: "draw-protection", matchId: match.id, label: "Empate protegido", cost: DRAW_PROTECTION_COST, active: effects.drawProtection, disabled: !actionState.canDrawProtection })}
                ${renderCoinToggleButton({ action: "error-shield", matchId: match.id, label: "Seguro de erro", cost: ERROR_SHIELD_COST, active: effects.errorShield, disabled: !actionState.canErrorShield })}
                <div class="compact-annul-picker">
                  ${
                    annulSelectorOpen
                      ? `
                        <label class="compact-annul-select">
                          <select class="select-input" data-annul-target="${match.id}">
                            <option value="">Selecione um adversÃ¡rio</option>
                            ${targetOptions}
                          </select>
                        </label>
                      `
                      : ""
                  }
                  ${renderCoinToggleButton({
                    action: "annul-prediction",
                    matchId: match.id,
                    label: userAnnulment ? `${annulledTargetUser?.nickname || "Rival"} anulado` : "Anular Palpite Adv.",
                    cost: ANNUL_COST,
                    active: Boolean(userAnnulment),
                    disabled: !actionState.canAnnul && !userAnnulment,
                  })}
                </div>
                ${renderCoinToggleButton({ action: "points-x2", matchId: match.id, label: "PontuaÃ§Ã£o x2", cost: POINTS_X2_COST, active: effects.personalBonus && effects.autoMultiplier <= 1, disabled: !actionState.canPersonalBonus })}
                ${renderCoinToggleButton({ action: "points-x3", matchId: match.id, label: "PontuaÃ§Ã£o x3", cost: POINTS_X3_COST, active: effects.superBonus && effects.autoMultiplier <= 1, disabled: !actionState.canSuperBonus })}
              </div>
            `
            : ""
        }
      </div>
      </form>
    </article>
  `;
};

const renderMatchSection = (section) => {
  const sectionMatches = ensureArray(section.matches, "section.matches");
  const pages = [sectionMatches];
  const currentPage = 0;

  return `
    <section class="match-group-section">
      <div class="match-group-heading">
        <div>
          <h4>${escapeHtml(section.label)}</h4>
          <span class="muted">${sectionMatches.length} jogo(s)</span>
        </div>
        <div class="slider-controls">
          ${
            pages.length > 1
              ? `
                <button class="ghost-button slider-button" type="button" data-slider-direction="prev" data-slider-key="${section.key}" ${currentPage === 0 ? "disabled" : ""}>â†</button>
                <span class="slider-counter">${currentPage + 1}/${pages.length}</span>
                <button class="ghost-button slider-button" type="button" data-slider-direction="next" data-slider-key="${section.key}" ${currentPage === pages.length - 1 ? "disabled" : ""}>â†’</button>
              `
              : `<span class="slider-counter">${sectionMatches.length} jogo(s)</span>`
          }
        </div>
      </div>
      <div class="match-slider" data-slider-key="${section.key}">
        <div class="match-slider-track" style="transform: translateX(-${currentPage * 100}%);">
          ${pages
            .map(
              (pageMatches) => `
                <div class="match-slider-page">
                  <div class="match-group-grid">
                    ${pageMatches.map((match) => renderCompactMatchCard(match)).join("")}
                  </div>
                </div>
              `
            )
            .join("")}
        </div>
      </div>
    </section>
  `;
};

const renderMatchesPagination = (currentPage, totalPages) => {
  if (!elements.matchesPagination) return;
  if (totalPages <= 1) {
    elements.matchesPagination.innerHTML = "";
    return;
  }

  const pageButtons = Array.from({ length: totalPages }, (_, index) => {
    const page = index + 1;
    return `<button class="mini-button ${page === currentPage ? "active-page-button" : ""}" data-matches-page="${page}" type="button">${page}</button>`;
  }).join("");

  elements.matchesPagination.innerHTML = `
    <div class="matches-pagination-inner">
      <button class="ghost-button" data-matches-page="${Math.max(1, currentPage - 1)}" type="button" ${currentPage === 1 ? "disabled" : ""}>Anterior</button>
      <div class="matches-pagination-pages">${pageButtons}</div>
      <button class="ghost-button" data-matches-page="${Math.min(totalPages, currentPage + 1)}" type="button" ${currentPage === totalPages ? "disabled" : ""}>PrÃ³xima</button>
    </div>
  `;
};

const renderGameCardV2 = (match) => {
  if (!match || typeof match !== "object") {
    return `<article class="game-card-v2"><div class="empty-state">Dados do jogo indisponiveis.</div></article>`;
  }

  const locked = isPredictionLocked(match);
  const prediction = getCurrentUserPrediction(match.id);
  const effects = getUserMatchEffects(state.currentUser?.id, match);
  const isKnockout = match.phase !== "group";
  const readyForPrediction = isMatchReadyForPredictions(match);
  const canLockedEdit = effects.lateEditUnlocked && canUseLateEditWindow(match);
  const isSaved = Boolean(prediction) && !(locked && canLockedEdit) && !state.editingPredictions.has(match.id);
  const disableFields = (locked && !canLockedEdit) || isSaved || !readyForPrediction || effects.annulled;
  const status = buildMatchStatus(match, prediction);
  const percentages = getGroupPredictionPercentages(match.id);
  const breakdown = state.currentUser
    ? getPredictionBreakdown(match, prediction ? { ...prediction, userId: state.currentUser.id } : null)
    : null;
  const actionState = state.currentUser ? getCoinActionAvailability(match, prediction, effects, state.currentUser.id) : null;
  const userAnnulment = state.currentUser ? getUserAnnulmentAction(state.currentUser.id, match.id) : null;
  const annulledTargetUser = userAnnulment ? state.users.find((user) => user.id === userAnnulment.targetUserId) : null;
  const annulSelectorOpen = state.openAnnulSelectors.has(match.id) && !userAnnulment;
  const strategyOpen = state.openCoinPanels.has(match.id);
  const targetOptions = actionState?.eligibleTargets
    ?.map((user) => `<option value="${user.id}">${escapeHtml(user.nickname)}</option>`)
    .join("") || "";
  const pointsState = getCompactPointsState(breakdown);
  const activeEffects = renderCompactMechanicBadges(effects);

  return `
    <article class="game-card-v2 ${state.recentlySavedMatches.has(match.id) ? "game-card-v2--saved-flash" : ""}">
      <form
        class="prediction-form game-shell-v2"
        data-match-id="${match.id}"
        data-home-team="${escapeHtml(match.homeTeam)}"
        data-away-team="${escapeHtml(match.awayTeam)}"
        data-knockout="${isKnockout}"
      >
        <div class="game-header-v2">
          <div class="game-title-v2">
            <strong>${escapeHtml(match.group || match.phaseLabel)} • JOGO ${match.number}</strong>
            <span>${formatDateTime(match.startsAt).replace(",", " •")}</span>
          </div>
          <span class="pill ${status.className}">${status.label}</span>
        </div>

        <div class="teams-stage-v2">
          <div class="team-card-v2 team-card-v2--home">
            ${renderTeamMarkup(match.homeTeam, "", { showCode: true })}
          </div>

          <div class="score-box-v2">
            <div class="compact-market game-market-v2">
              ${renderCompactDistribution(percentages)}
            </div>
            <div class="score-grid-v2">
              <input class="text-input score-input score-input-v2" type="number" min="0" name="homeScore" placeholder="0" value="${prediction?.homeScore ?? ""}" ${disableFields ? "disabled" : ""} />
              <span class="score-divider-v2">x</span>
              <input class="text-input score-input score-input-v2" type="number" min="0" name="awayScore" placeholder="0" value="${prediction?.awayScore ?? ""}" ${disableFields ? "disabled" : ""} />
              <input type="hidden" name="extraTimeHome" value="${prediction?.extraTimeHome ?? ""}" />
              <input type="hidden" name="extraTimeAway" value="${prediction?.extraTimeAway ?? ""}" />
              <input type="hidden" name="winnerTeam" value="${prediction?.winnerTeam ?? ""}" />
            </div>
          </div>

          <div class="team-card-v2 team-card-v2--away">
            ${renderTeamMarkup(match.awayTeam, "", { showCode: true })}
          </div>
        </div>

        ${
          strategyOpen
            ? `
              <div class="strategy-drawer-v2">
                <div class="strategy-title-v2">Estratégia</div>
                ${activeEffects ? `<div class="match-fut-effects">${activeEffects}</div>` : ""}
                ${
                  actionState
                    ? `
                      <div class="compact-coin-actions game-chips-v2">
                        ${renderCoinToggleButton({ action: "draw-protection", matchId: match.id, label: "Empate protegido", cost: DRAW_PROTECTION_COST, active: effects.drawProtection, disabled: !actionState.canDrawProtection })}
                        ${renderCoinToggleButton({ action: "error-shield", matchId: match.id, label: "Seguro de erro", cost: ERROR_SHIELD_COST, active: effects.errorShield, disabled: !actionState.canErrorShield })}
                        <div class="compact-annul-picker">
                          ${
                            annulSelectorOpen
                              ? `
                                <label class="compact-annul-select">
                                  <select class="select-input" data-annul-target="${match.id}">
                                    <option value="">Selecione um adversário</option>
                                    ${targetOptions}
                                  </select>
                                </label>
                              `
                              : ""
                          }
                          ${renderCoinToggleButton({
                            action: "annul-prediction",
                            matchId: match.id,
                            label: userAnnulment ? `${annulledTargetUser?.nickname || "Rival"} anulado` : "Anular Palpite Adv.",
                            cost: ANNUL_COST,
                            active: Boolean(userAnnulment),
                            disabled: !actionState.canAnnul && !userAnnulment,
                          })}
                        </div>
                        ${renderCoinToggleButton({ action: "points-x2", matchId: match.id, label: "Pontuação x2", cost: POINTS_X2_COST, active: effects.personalBonus && effects.autoMultiplier <= 1, disabled: !actionState.canPersonalBonus })}
                        ${renderCoinToggleButton({ action: "points-x3", matchId: match.id, label: "Pontuação x3", cost: POINTS_X3_COST, active: effects.superBonus && effects.autoMultiplier <= 1, disabled: !actionState.canSuperBonus })}
                      </div>
                    `
                    : `<div class="saved-note">Entre para usar estratégias.</div>`
                }
              </div>
            `
            : ""
        }

        <div class="game-footer-v2">
          <div class="compact-points-earned ${pointsState.className}">
            <span class="compact-points-earned__label">Pontos neste jogo:</span>
            <strong class="compact-points-earned__value">${!state.currentUser ? "—" : pointsState.label}</strong>
          </div>

          <div class="game-actions-v2">
            ${
              !state.currentUser
                ? `<span class="saved-note">Entre para palpitar</span>`
                : effects.annulled
                  ? `<span class="saved-note saved-note--danger">Palpite anulado</span>`
                  : locked && !canLockedEdit
                    ? `<span class="saved-note">Fechado</span>`
                    : !readyForPrediction
                      ? `<span class="saved-note">Aguardando confronto</span>`
                      : isSaved
                        ? `<button class="edit-prediction-button edit-prediction-button--saved submit-button-v2" data-edit-match="${match.id}" type="button">EDITAR PALPITE</button>`
                        : `<button class="primary-button submit-button-v2" type="submit">SALVAR PALPITE</button>`
            }
            ${
              state.currentUser
                ? `<button class="ghost-button strategy-toggle-v2" data-toggle-coins="${match.id}" type="button">${strategyOpen ? "Fechar estratégia" : "Estratégia"}</button>`
                : ""
            }
          </div>
        </div>
      </form>
    </article>
  `;
};

const renderGamesTabV2 = (pageMatches) => {
  const sections = groupVisibleMatches(pageMatches);
  return `
    <div class="games-v2">
      ${sections
        .map(
          (section) => `
            <section class="games-v2-section">
              <div class="games-v2-section-header">
                <h4>${escapeHtml(section.label)}</h4>
                <span class="muted">${ensureArray(section.matches, "section.matches").length} jogo(s)</span>
              </div>
              <div class="games-v2-list">
                ${ensureArray(section.matches, "section.matches").map((match) => renderGameCardV2(match)).join("")}
              </div>
            </section>
          `
        )
        .join("")}
    </div>
  `;
};

const renderMatches = () => {
  try {
    const visibleMatches = getVisibleMatches();
    if (!visibleMatches.length) {
      elements.matchesGrid.innerHTML = `<div class="empty-state">Nenhum jogo disponivel para este filtro no momento.</div>`;
      renderMatchesPagination(1, 1);
      return;
    }

    const { pageMatches, currentPage, totalPages } = getPaginatedMatches(visibleMatches);
    elements.matchesGrid.innerHTML = renderGamesTabV2(pageMatches);
    renderMatchesPagination(currentPage, totalPages);
  } catch (error) {
    console.error("[bolao] Falha ao renderizar jogos.", error);
    elements.matchesGrid.innerHTML = `<div class="empty-state">Nao foi possivel carregar os jogos agora.</div>`;
    renderMatchesPagination(1, 1);
  }
};

const renderQuickPicks = () => {
  if (!elements.quickPicksList) return;
  const quickMatches = ensureArray(state.matches, "state.matches")
    .filter((match) => match.phase === "group")
    .filter((match) => !isPredictionLocked(match))
    .filter((match) => isMatchReadyForPredictions(match))
    .sort((a, b) => getSortableTime(a?.startsAt) - getSortableTime(b?.startsAt))
    .slice(0, 12);

  if (!state.currentUser) {
    elements.quickPicksList.innerHTML = `<div class="empty-state">Entre para usar o palpite rapido.</div>`;
    return;
  }

  elements.quickPicksList.innerHTML = quickMatches.length
    ? quickMatches
        .map((match) => {
          const prediction = getCurrentUserPrediction(match.id);
          const effects = getUserMatchEffects(state.currentUser.id, match);
          const saved = Boolean(prediction) && !state.editingPredictions.has(match.id);
          const bonusBadge = renderMechanicBadges(effects);
          return `
            <form class="quick-pick-row prediction-form ${saved ? "quick-pick-row--saved" : ""}" data-match-id="${match.id}" data-home-team="${escapeHtml(match.homeTeam)}" data-away-team="${escapeHtml(match.awayTeam)}" data-knockout="${match.phase !== "group"}">
              <div class="quick-pick-main">
                <div class="quick-pick-header">
                  <strong>${escapeHtml(match.phaseLabel)}</strong>
                  ${bonusBadge}
                </div>
                <div class="quick-pick-teams">
                  <span>${renderTeamMarkup(match.homeTeam, "team-flag--small", { showCode: true })}</span>
                  <span class="match-fut-score-divider">x</span>
                  <span>${renderTeamMarkup(match.awayTeam, "team-flag--small", { showCode: true })}</span>
                </div>
                <div class="quick-pick-meta">${formatDateTime(match.startsAt)}</div>
                ${effects.annulled ? `<div class="saved-note saved-note--danger">ðŸ’£ Palpite anulado</div>` : ""}
              </div>
              <div class="quick-pick-inputs">
                <input class="text-input score-input" type="number" min="0" name="homeScore" placeholder="0" value="${prediction?.homeScore ?? ""}" ${saved ? "disabled" : ""} />
                <input class="text-input score-input" type="number" min="0" name="awayScore" placeholder="0" value="${prediction?.awayScore ?? ""}" ${saved ? "disabled" : ""} />
                ${
                  saved
                    ? `<button class="mini-button" data-edit-match="${match.id}" type="button">Editar</button>`
                    : `<button class="primary-button" type="submit">Salvar</button>`
                }
              </div>
            </form>
          `;
        })
        .join("")
    : `<div class="empty-state">Nao ha jogos liberados para palpite rapido agora.</div>`;
};

const renderPredictionHistory = () => {
  if (!elements.predictionHistory) return;
  if (!state.currentUser) {
    elements.predictionHistory.innerHTML = `<div class="empty-state">Entre para acompanhar seu historico.</div>`;
    return;
  }

  const historyRows = ensureArray(state.matches, "state.matches")
    .filter((match) => getCurrentUserPrediction(match.id))
    .sort((a, b) => getSortableTime(b?.startsAt) - getSortableTime(a?.startsAt))
    .map((match) => {
      const prediction = getCurrentUserPrediction(match.id);
      const breakdown = getPredictionBreakdown(match, prediction ? { ...prediction, userId: state.currentUser.id } : null);
      const effects = getUserMatchEffects(state.currentUser.id, match);
      const statusLabel = {
        exact: "Acertou placar",
        result: "Acertou resultado",
        miss: "Errou",
        pending: "Pendente",
        annulled: "Palpite anulado",
      }[breakdown.status];

      return `
        <article class="history-card history-card--${breakdown.status}">
          <div class="history-main">
            <div class="history-heading">
              <strong>${renderTeamMarkup(match.homeTeam, "team-flag--small")} <span class="match-fut-score-divider">x</span> ${renderTeamMarkup(match.awayTeam, "team-flag--small")}</strong>
              ${isBonusVisible(match) ? `<span class="pill bonus-pill">Jogo bÃ´nus x2</span>` : ""}
            </div>
            <div class="history-meta">${formatDateTime(match.startsAt)} â€¢ ${escapeHtml(match.phaseLabel)}</div>
          </div>
          <div class="history-side">
            <div>Seu palpite: <strong>${prediction.homeScore} x ${prediction.awayScore}</strong></div>
            <div>Resultado real: <strong>${match.scoreHome ?? "-"} x ${match.scoreAway ?? "-"}</strong></div>
            <div class="match-effect-badges">${renderMechanicBadges(effects)}${breakdown.minorityBonus ? `<span class="pill success">ðŸª™ Minoria +0,25</span>` : ""}</div>
            <div class="history-status">${statusLabel}</div>
            ${effects.annulled ? `<div class="history-status history-status--danger">ðŸ’£ ${escapeHtml(state.users.find((user) => user.id === effects.annulledBy)?.nickname || "AlguÃ©m")} anulou este palpite.</div>` : ""}
            <div class="history-points history-points--${breakdown.status === "pending" ? "pending" : breakdown.points > 0 ? "positive" : breakdown.points < 0 ? "negative" : "neutral"}">${breakdown.status === "pending" ? "Em espera" : `${breakdown.points.toFixed(2)} pts`}</div>
          </div>
        </article>
      `;
    });

  elements.predictionHistory.innerHTML = historyRows.length
    ? historyRows.join("")
    : `<div class="empty-state">Seu historico aparece aqui assim que voce salvar palpites.</div>`;
};

const renderBonusRow = (field, values, lockedByDate) => {
  const value = values[field.key];
  const isEditing = state.editingBonusFields.has(field.key);
  const isSaved = hasBonusValue(value) && !isEditing;
  const disabled = lockedByDate || isSaved;
  let controlMarkup = "";

  if (field.type === "selection") {
    controlMarkup = `
      <select class="select-input" name="${field.key}" ${disabled ? "disabled" : ""}>
        <option value="">Selecione uma selecao</option>
        ${getSelectionOptions(value ?? "")}
      </select>
    `;
  }

  if (field.type === "zebra") {
    controlMarkup = `
      <select class="select-input" name="${field.key}" ${disabled ? "disabled" : ""}>
        <option value="">Selecione uma zebra</option>
        ${getZebraOptions(value ?? "")}
      </select>
    `;
  }

  if (field.type === "text") {
    controlMarkup = `<input class="text-input" name="${field.key}" value="${value ?? ""}" ${disabled ? "disabled" : ""} />`;
  }

  if (field.type === "number") {
    controlMarkup = `<input class="text-input" name="${field.key}" type="number" min="0" value="${value ?? ""}" ${disabled ? "disabled" : ""} />`;
  }

  return `
    <article class="bonus-field-card ${isSaved ? "bonus-field-card--saved" : ""}" data-bonus-field="${field.key}">
      <div class="bonus-field-header">
        <div>
          <strong>${field.label}</strong>
          ${
            field.type === "text"
              ? `<div class="muted">Texto livre. A comparacao futura esta preparada para variacoes pequenas de escrita.</div>`
              : field.type === "number"
                ? `<div class="muted">Numero livre positivo, sem teto artificial.</div>`
                : field.type === "zebra"
                  ? `<div class="muted">Pontuacao cumulativa: +1 grupos, +2 oitavas, +3 quartas, +4 semi, +5 final.</div>`
                : ""
          }
        </div>
        ${
          lockedByDate
            ? `<span class="pill danger">Fechado</span>`
            : isSaved
              ? `<button class="mini-button" data-bonus-action="edit" data-bonus-key="${field.key}" type="button">Editar</button>`
              : `<button class="primary-button bonus-save-button" data-bonus-action="save" data-bonus-key="${field.key}" type="button">Salvar</button>`
        }
      </div>
      ${controlMarkup}
    </article>
  `;
};

const renderBonusForm = () => {
  try {
    const settings = ensureObject(state.settings, "state.settings");
    const lockAt = settings.bonusLockAt;
    const locked = lockAt ? Date.now() >= new Date(lockAt).getTime() : false;
    const values = state.currentUser ? getCurrentBonusValues() : {};

    elements.bonusLockStatus.className = `pill ${locked ? "danger" : "success"}`;
    elements.bonusLockStatus.textContent = locked
      ? "Palpites extras fechados"
      : `Fecha em ${lockAt ? formatDateTime(lockAt) : "breve"}`;

    if (!state.currentUser) {
      elements.bonusForm.innerHTML = `<div class="empty-state">Entre para preencher seus palpites extras.</div>`;
      return;
    }

    if (!bonusFieldDefinitions.length) {
      elements.bonusForm.innerHTML = `<div class="empty-state">Nenhum campo extra configurado.</div>`;
      return;
    }

    elements.bonusForm.innerHTML = bonusFieldDefinitions
      .map((field) => renderBonusRow(field, values, locked))
      .join("");
  } catch (error) {
    console.error("[bolao] Falha ao renderizar palpites extras.", error);
    elements.bonusLockStatus.className = "pill danger";
    elements.bonusLockStatus.textContent = "Erro ao carregar";
    elements.bonusForm.innerHTML = `<div class="empty-state">Nao foi possivel carregar os palpites extras.</div>`;
  }
};

const getLiveBotMessages = () => {
  const messages = [];
  const ranking = getRanking();
  const bonusLines = [
    "Esse jogo agora vale mais. NÃ£o pergunte o porquÃª.",
    "PontuaÃ§Ã£o dobrada. Use com responsabilidade.",
    "Esse aqui ficou mais caro de errar.",
    "Resolveram dobrar a tensÃ£o. A matemÃ¡tica sÃ³ assinou embaixo.",
    "Esse aqui resolveu valer mais. CoincidÃªncia Ã© uma palavra forte.",
  ];
  const leaderLines = [
    "{nickname} virou lÃ­der. O regulamento nÃ£o proÃ­be arrogÃ¢ncia, sÃ³ registra.",
    "{nickname} assumiu a ponta. Sinal de consistÃªncia ou teatro bem ensaiado.",
    "{nickname} estÃ¡ em primeiro. O resto do grupo pediu revisÃ£o, sem sucesso.",
  ];
  const riseLines = [
    "{nickname} subiu no ranking. A planilha foi vista sorrindo de lado.",
    "{nickname} ganhou posiÃ§Ãµes. Nada sobrenatural, sÃ³ estatÃ­stica bem penteada.",
    "{nickname} avanÃ§ou no ranking. O caos, Ã s vezes, escolhe favoritos.",
  ];
  const savedLines = [
    "{nickname} salvou palpite em {match}. Planejamento ou excesso de confianÃ§a, ainda nÃ£o sabemos.",
    "{nickname} registrou {match}. O futuro nÃ£o respondeu, mas a ousadia sim.",
    "{nickname} adiantou {match}. Coragem e convicÃ§Ã£o entraram juntas no formulÃ¡rio.",
  ];
  const knockoutLines = [
    "{phase}: {match}. Agora sim o mata-mata ganhou documento e foto 3x4.",
    "{phase} liberado: {match}. O drama deixou de ser rascunho.",
    "{phase}: {match}. A chave resolveu se comportar como chave de verdade.",
  ];
  const pendingLines = [
    "{nickname} ainda tem {count} palpite(s) pendente(s). O relÃ³gio continua sem empatia.",
    "{nickname} estÃ¡ devendo {count} palpite(s). O prazo jÃ¡ viu e anotou.",
    "{nickname} deixou {count} jogo(s) aberto(s). Coragem Ã© uma palavra, agenda Ã© outra.",
  ];
  const resultLines = {
    exact: [
      "{nickname} cravou {match}. Investigaremos acesso indevido ao futuro.",
      "{nickname} acertou em cheio {match}. Um abuso estatÃ­stico elegante.",
      "{nickname} pregou o placar de {match}. O VAR do tempo estÃ¡ desconfiado.",
    ],
    result: [
      "{nickname} acertou o resultado de {match}. Meio caminho andado e alguma marra junto.",
      "{nickname} leu bem {match}. NÃ£o foi clarividÃªncia, mas deu trabalho igual.",
      "{nickname} pegou o resultado de {match}. JÃ¡ dÃ¡ para sustentar o argumento no grupo.",
    ],
    miss: [
      "{nickname} errou {match} com convicÃ§Ã£o. A histÃ³ria registrou sem dÃ³.",
      "{nickname} passou longe em {match}. Pelo menos houve personalidade.",
      "{nickname} tropeÃ§ou em {match}. O palpite foi valente, o placar nÃ£o colaborou.",
    ],
  };
  const coinEventLines = {
    "personal-bonus": [
      "{nickname} pagou por um Jogo BÃ´nus x2 pessoal em {match}. PrudÃªncia foi convidada e nÃ£o veio.",
      "{nickname} colocou moedas em {match}. A planilha ouviu o barulho.",
    ],
    "error-shield": [
      "{nickname} comprou Seguro de erro em {match}. Ã‰ o medo com orÃ§amento.",
      "{nickname} blindou {match}. O pessimismo agora trabalha com suporte financeiro.",
    ],
    "late-edit": [
      "{nickname} liberou alteraÃ§Ã£o tardia em {match}. RevisÃ£o premium da prÃ³pria ansiedade.",
      "{nickname} reabriu {match} com moedas. O prazo fingiu surpresa.",
    ],
    "annul-prediction": [
      "{nickname} anulou o palpite de {target} em {match}. Diplomacia zero, efeito mÃ¡ximo.",
      "{nickname} pagou para silenciar o palpite de {target} em {match}. Argumento caro, porÃ©m objetivo.",
    ],
  };
  const minorityLines = [
    "{nickname} acertou {match} na contramÃ£o do grupo. Minoria premiada, ego abastecido.",
    "{nickname} buscou {match} onde pouca gente quis ir. Veio +0,25 de teimosia recompensada.",
  ];
  const zebraLines = [
    "A zebra {team} avanÃ§ou. Quem comprou esse caos por antecipaÃ§Ã£o jÃ¡ estÃ¡ sorrindo de lado.",
    "{team} segue viva como zebra. O mercado chamou exagero, o torneio discordou.",
  ];

  ensureArray(state.matches, "state.matches")
    .filter((match) => isBonusVisible(match))
    .forEach((match) => {
      messages.push({
        ...BOT_PROFILE,
        id: `bot-bonus-${match.id}`,
        message: pickMessage(`bonus-${match.id}`, bonusLines),
        createdAt: new Date(Math.max(getSortableTime(match.startsAt) - BONUS_VISIBILITY_WINDOW_MS, Date.now() - 1000 * 60 * 15)).toISOString(),
      });
    });

  getCoinEvents()
    .slice(-8)
    .forEach((entry, index) => {
      const user = state.users.find((item) => item.id === entry.userId);
      const target = state.users.find((item) => item.id === entry.targetUserId);
      const match = state.matches.find((item) => item.id === entry.matchId);
      const lineSet = coinEventLines[entry.type];
      if (!user || !match || !lineSet) return;
      messages.push({
        ...BOT_PROFILE,
        id: `bot-coin-${entry.id}`,
        message: pickMessage(`coin-${entry.id}`, lineSet)
          .replace("{nickname}", user.nickname)
          .replace("{target}", target?.nickname || "alguÃ©m")
          .replace("{match}", `${match.homeTeam} x ${match.awayTeam}`),
        createdAt: new Date(new Date(entry.createdAt).getTime() + index).toISOString(),
      });
    });

  const leader = ranking[0];
  if (leader) {
    messages.push({
      ...BOT_PROFILE,
      id: `bot-leader-${leader.id}`,
      message: pickMessage(`leader-${leader.id}`, leaderLines).replace("{nickname}", leader.nickname),
      createdAt: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
    });
  }

  ranking
    .filter((entry) => entry.movement === "up")
    .slice(0, 2)
    .forEach((entry, index) => {
      messages.push({
        ...BOT_PROFILE,
        id: `bot-rise-${entry.id}`,
        message: pickMessage(`rise-${entry.id}`, riseLines).replace("{nickname}", entry.nickname),
        createdAt: new Date(Date.now() - 1000 * 60 * (18 + index)).toISOString(),
      });
    });

  ensureArray(state.predictions, "state.predictions")
    .slice(-4)
    .forEach((entry, index) => {
      const user = ensureArray(state.users, "state.users").find((item) => item.id === entry.userId);
      const match = ensureArray(state.matches, "state.matches").find((item) => item.id === entry.matchId);
      if (!user || !match) return;
      messages.push({
        ...BOT_PROFILE,
        id: `bot-prediction-${entry.userId}-${entry.matchId}`,
        message: pickMessage(`saved-${entry.userId}-${entry.matchId}`, savedLines)
          .replace("{nickname}", user.nickname)
          .replace("{match}", `${match.homeTeam} x ${match.awayTeam}`),
        createdAt: new Date(Date.now() - 1000 * 60 * (4 + index)).toISOString(),
      });
    });

  ensureArray(state.matches, "state.matches")
    .filter((match) => isMatchReadyForPredictions(match) && match.phase !== "group")
    .slice(0, 2)
    .forEach((match, index) => {
      messages.push({
        ...BOT_PROFILE,
        id: `bot-knockout-${match.id}`,
        message: pickMessage(`knockout-${match.id}`, knockoutLines)
          .replace("{phase}", match.phaseLabel)
          .replace("{match}", `${match.homeTeam} x ${match.awayTeam}`),
        createdAt: new Date(Date.now() - 1000 * 60 * (22 + index)).toISOString(),
      });
    });

  ensureArray(state.users, "state.users")
    .slice(0, 2)
    .forEach((user, index) => {
      const pending = getUserStats(user.id)?.pending || 0;
      if (!pending) return;
      messages.push({
        ...BOT_PROFILE,
        id: `bot-pending-${user.id}`,
        message: pickMessage(`pending-${user.id}`, pendingLines)
          .replace("{nickname}", user.nickname)
          .replace("{count}", String(pending)),
        createdAt: new Date(Date.now() - 1000 * 60 * (28 + index)).toISOString(),
      });
    });

  ensureArray(state.matches, "state.matches")
    .filter((match) => match.scoreHome != null && match.scoreAway != null)
    .slice(0, 4)
    .forEach((match, index) => {
      ensureArray(state.predictions, "state.predictions")
        .filter((entry) => entry.matchId === match.id)
        .slice(0, 1)
        .forEach((entry) => {
          const user = ensureArray(state.users, "state.users").find((item) => item.id === entry.userId);
          if (!user) return;
          const breakdown = getPredictionBreakdown(match, entry);
          if (breakdown.status === "pending") return;
          messages.push({
            ...BOT_PROFILE,
            id: `bot-result-${entry.userId}-${match.id}`,
            message: pickMessage(`${breakdown.status}-${entry.userId}-${match.id}`, resultLines[breakdown.status])
              .replace("{nickname}", user.nickname)
              .replace("{match}", `${match.homeTeam} x ${match.awayTeam}`),
            createdAt: new Date(Date.now() - 1000 * 60 * (36 + index)).toISOString(),
          });
        });
    });

  ensureArray(state.matches, "state.matches")
    .filter((match) => match.scoreHome != null && match.scoreAway != null)
    .forEach((match) => {
      ensureArray(state.predictions, "state.predictions")
        .filter((entry) => entry.matchId === match.id)
        .forEach((entry) => {
          const breakdown = getPredictionBreakdown(match, entry);
          const user = state.users.find((item) => item.id === entry.userId);
          if (!user || !breakdown.minorityBonus) return;
          messages.push({
            ...BOT_PROFILE,
            id: `bot-minority-${entry.userId}-${match.id}`,
            message: pickMessage(`minority-${entry.userId}-${match.id}`, minorityLines)
              .replace("{nickname}", user.nickname)
              .replace("{match}", `${match.homeTeam} x ${match.awayTeam}`),
            createdAt: new Date(Date.now() - 1000 * 60 * 10).toISOString(),
          });
        });
    });

  const zebraResults = state.settings?.bonusResults?.zebraStageByTeam || {};
  Object.keys(zebraResults)
    .slice(0, 4)
    .forEach((team) => {
      messages.push({
        ...BOT_PROFILE,
        id: `bot-zebra-${team}`,
        message: pickMessage(`zebra-${team}`, zebraLines).replace("{team}", team),
        createdAt: new Date(Date.now() - 1000 * 60 * 8).toISOString(),
      });
    });

  return messages;
};

const renderChat = () => {
  if (!elements.chatList) return;
  const messages = [...ensureArray(state.chatMessages, "state.chatMessages"), ...getLiveBotMessages()];
  elements.chatList.innerHTML = messages.length
    ? messages
        .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt))
        .map((message) => {
          const canDelete = state.currentUser?.isAdmin && !message.isBot;
          return `
            <article class="chat-item ${message.isBot ? "chat-item--bot" : ""}">
              <div class="chat-meta">
                ${buildAvatarMarkup(message)}
                <div class="chat-meta-text">
                  <strong>${escapeHtml(message.nickname)}</strong>
                  <div class="muted">${formatDateTime(message.createdAt)}</div>
                </div>
                ${canDelete ? `<button class="mini-button" data-delete-message="${message.id}" type="button">Apagar</button>` : ""}
              </div>
              <div class="chat-message">${escapeHtml(message.message)}</div>
            </article>
          `;
        })
        .join("")
    : `<div class="empty-state">O chat ainda esta vazio.</div>`;
};

const renderRules = () => {
  try {
    const renderList = (items) =>
      ensureArray(items, "rules.items")
        .map(
          (item) => `
            <li class="rule-item">
            <span>${escapeHtml(item.label)}</span>
            <strong>${escapeHtml(item.points)}</strong>
          </li>
        `
      )
      .join("");

    const safeRules = ensureObject(rulesSummary, "rulesSummary");
    elements.rulesSummary.innerHTML = `
      <article class="rule-block">
        <h4>A. Fase de grupos</h4>
        <ul class="rule-list">${renderList(safeRules.groupStage)}</ul>
      </article>
      <article class="rule-block">
        <h4>B. Mata-mata</h4>
        <ul class="rule-list">${renderList(safeRules.knockout)}</ul>
      </article>
      <article class="rule-block">
        <h4>C. Extras</h4>
        <ul class="rule-list">${renderList(safeRules.extras)}</ul>
      </article>
      <article class="rule-block">
        <h4>D. Buffs com moedas</h4>
        <ul class="rule-list">${renderList(safeRules.coinBuffs)}</ul>
      </article>
      <article class="rule-block rule-block--details">
        <h4>E. Explicacoes complementares</h4>
        <div class="rule-details-list">
          ${ensureArray(safeRules.details, "rulesSummary.details").map((item) => `<p>${escapeHtml(item)}</p>`).join("")}
        </div>
      </article>
    `;
  } catch (error) {
    console.error("[bolao] Falha ao renderizar regras.", error);
    elements.rulesSummary.innerHTML = `<div class="empty-state">Nao foi possivel carregar o resumo das regras.</div>`;
  }
};

const renderAdmin = () => {
  const isAdmin = state.currentUser?.isAdmin;
  elements.adminPanel.hidden = !isAdmin;
  if (!isAdmin) return;

  elements.bannerInput.value = state.settings.banner?.message || "";
  elements.adminUsersList.innerHTML = state.users
    .map(
      (user) => `
        <article class="admin-user-row">
          <div class="user-chip">
            ${buildAvatarMarkup(user)}
            <div>
              <strong>${escapeHtml(user.nickname)}</strong>
              <div class="muted">${escapeHtml(user.realName)}</div>
            </div>
          </div>
          <div class="admin-user-actions">
            <button class="mini-button" data-admin-action="rename-user" data-user-id="${user.id}" type="button">Renomear</button>
            <button class="mini-button" data-admin-action="change-avatar" data-user-id="${user.id}" type="button">Foto</button>
            <button class="mini-button" data-admin-action="toggle-block" data-user-id="${user.id}" type="button">${user.isBlocked ? "Desbloquear" : "Bloquear"}</button>
            <button class="mini-button" data-admin-action="reset-password" data-user-id="${user.id}" type="button">Resetar senha</button>
            <button class="danger-button" data-admin-action="delete-user" data-user-id="${user.id}" type="button">Excluir</button>
          </div>
        </article>
      `
    )
    .join("");

  elements.adminStats.innerHTML = [
    ["Usuarios", `${state.users.length}/${APP_CONFIG.maxUsers}`],
    ["Jogos", `${state.matches.length}`],
    ["Palpites", `${state.predictions.length}`],
    ["Mensagens", `${state.chatMessages.length}`],
  ]
    .map(
      ([label, value]) => `
        <article class="stat-card">
          <span>${label}</span>
          <strong>${value}</strong>
        </article>
      `
    )
    .join("");
};

const renderAuthButton = () => {
  elements.authOpenButton.textContent = state.currentUser ? "Sair" : "Entrar";
  if (elements.authRegisterTopButton) {
    elements.authRegisterTopButton.hidden = Boolean(state.currentUser);
  }
  renderSessionChip();
};

const setActiveTab = (tabId) => {
  state.activeTab = tabId;

  elements.tabButtons.forEach((button) => {
    const isActive =
      button.dataset.tabTarget === tabId ||
      button.getAttribute("href") === `#${tabId}` ||
      (tabId === "jogos" && button.getAttribute("href") === "#palpites");
    button.classList.toggle("active", isActive);
  });

  elements.tabPanels.forEach((panel) => {
    const shouldShow = panel.dataset.tabPanel === tabId;
    if (panel.id === "admin-panel") {
      panel.hidden = !shouldShow || !state.currentUser?.isAdmin;
      return;
    }
    panel.hidden = !shouldShow;
  });
};

const renderAvatarPresets = () => {
  elements.avatarPresets.innerHTML = avatarPresets
    .map(
      (preset) => `
        <button class="avatar-option ${state.selectedAvatarPreset === preset.id ? "selected" : ""}" data-avatar-id="${preset.id}" type="button">
          <div class="avatar" style="background:${preset.gradient}">
            ${preset.imageUrl ? `<img src="${preset.imageUrl}" alt="${preset.name}" />` : preset.emoji || ""}
          </div>
          <span class="avatar-option-label">${escapeHtml(preset.name || preset.code || preset.id)}</span>
        </button>
      `
    )
    .join("");
};

const renderAll = () => {
  const safeRender = (label, callback) => {
    try {
      callback();
    } catch (error) {
      console.error(`[bolao] Falha em ${label}.`, error);
    }
  };

  safeRender("renderBanner", renderBanner);
  safeRender("renderSummary", renderSummary);
  safeRender("renderRanking", renderRanking);
  safeRender("renderUpcomingMatches", renderUpcomingMatches);
  safeRender("renderPersonalSummary", renderPersonalSummary);
  safeRender("renderPendingAlert", renderPendingAlert);
  safeRender("renderMatches", renderMatches);
  safeRender("renderQuickPicks", renderQuickPicks);
  safeRender("renderGroups", renderGroups);
  safeRender("renderBonusForm", renderBonusForm);
  safeRender("renderPredictionHistory", renderPredictionHistory);
  safeRender("renderChat", renderChat);
  safeRender("renderRules", renderRules);
  safeRender("renderAdmin", renderAdmin);
  safeRender("renderAuthButton", renderAuthButton);
  safeRender("renderAvatarPresets", renderAvatarPresets);
  safeRender("setActiveTab", () => setActiveTab(state.activeTab));
};

const closeAuthDialog = () => {
  if (elements.authDialog.open) elements.authDialog.close();
};

const openAuthDialog = (tab = "login") => {
  if (!elements.authDialog.open) {
    elements.authDialog.showModal();
  }
  elements.authTabs.forEach((button) => button.classList.toggle("active", button.dataset.authTab === tab));
  elements.loginForm.hidden = tab !== "login";
  elements.registerForm.hidden = tab !== "register";
};

const syncKnockoutFormState = (form) => {
  if (form.dataset.knockout !== "true") return;

  const extraFields = form.querySelector(".knockout-extra-fields");
  const winnerSelect = form.querySelector('select[name="winnerTeam"]');
  const extraTimeHome = form.querySelector('input[name="extraTimeHome"]');
  const extraTimeAway = form.querySelector('input[name="extraTimeAway"]');
  const homeScore = form.querySelector('input[name="homeScore"]').value;
  const awayScore = form.querySelector('input[name="awayScore"]').value;
  const homeTeam = form.dataset.homeTeam;
  const awayTeam = form.dataset.awayTeam;
  const isEditing = !form.querySelector('input[name="homeScore"]').disabled;
  const shouldShowExtraTime = requiresExtraTime(homeScore, awayScore);
  const automaticWinner = getWinnerFromRegularTime(homeTeam, awayTeam, homeScore, awayScore);

  if (extraFields) {
    extraFields.hidden = !shouldShowExtraTime;
  }

  if (shouldShowExtraTime) {
    extraTimeHome.disabled = !isEditing;
    extraTimeAway.disabled = !isEditing;
    winnerSelect.disabled = !isEditing;
    return;
  }

  extraTimeHome.value = "";
  extraTimeAway.value = "";
  extraTimeHome.disabled = true;
  extraTimeAway.disabled = true;
  winnerSelect.value = automaticWinner;
  winnerSelect.disabled = true;
};

const parsePredictionPayload = (form) => {
  const matchId = form.dataset.matchId;
  const homeTeam = form.dataset.homeTeam;
  const awayTeam = form.dataset.awayTeam;
  const match = ensureArray(state.matches, "state.matches").find((entry) => entry.id === matchId);
  const homeScore = form.homeScore.value;
  const awayScore = form.awayScore.value;

  if (!isMatchReadyForPredictions(match)) {
    throw new Error("Palpite sera liberado quando o confronto oficial for definido.");
  }

  if (isPredictionLocked(match)) {
    const lateEditEvent = getLateEditEvent(state.currentUser?.id, match.id);
    if (!lateEditEvent || !canUseLateEditWindow(match)) {
      throw new Error("O prazo normal deste jogo ja fechou.");
    }
  }

  if (!hasScores(homeScore, awayScore)) {
    throw new Error("Preencha o placar completo antes de salvar.");
  }

  const payload = {
    matchId,
    homeScore: Number(homeScore),
    awayScore: Number(awayScore),
    extraTimeHome: null,
    extraTimeAway: null,
    winnerTeam: null,
  };

  if (form.dataset.knockout !== "true") {
    return payload;
  }

  if (requiresExtraTime(homeScore, awayScore)) {
    if (!hasScores(form.extraTimeHome.value, form.extraTimeAway.value)) {
      throw new Error("No mata-mata empatado, preencha a prorrogacao.");
    }
    if (!form.winnerTeam.value) {
      throw new Error("Selecione quem avanca.");
    }
    payload.extraTimeHome = Number(form.extraTimeHome.value);
    payload.extraTimeAway = Number(form.extraTimeAway.value);
    payload.winnerTeam = form.winnerTeam.value;
    return payload;
  }

  payload.winnerTeam = getWinnerFromRegularTime(homeTeam, awayTeam, homeScore, awayScore);
  form.winnerTeam.value = payload.winnerTeam;
  form.extraTimeHome.value = "";
  form.extraTimeAway.value = "";
  return payload;
};

const handlePredictionSubmit = async (event) => {
  const form = event.target.closest(".prediction-form");
  if (!form) return;
  event.preventDefault();

  if (!state.currentUser) {
    showToast("Faca login para palpitar.", "error");
    return;
  }

  try {
    const payload = parsePredictionPayload(form);
    await api.savePrediction(state.currentUser.id, payload);
    state.editingPredictions.delete(payload.matchId);
    const lateEditEvent = getLateEditEvent(state.currentUser.id, payload.matchId);
    if (lateEditEvent && !lateEditEvent.consumedAt) {
      await api.updateCoinEvent(lateEditEvent.id, { consumedAt: new Date().toISOString() });
    }
    const fresh = await api.refresh();
    applyFreshData(fresh);
    await freezeMinoritySnapshots();
    markMatchAsRecentlySaved(payload.matchId);
    showToast("Palpite salvo com sucesso.", "success");
    renderAll();
  } catch (error) {
    showToast(error.message, "error");
  }
};

const handleBonusClick = async (event) => {
  const button = event.target.closest("[data-bonus-action]");
  if (!button || !state.currentUser) return;

  const key = button.dataset.bonusKey;
  const action = button.dataset.bonusAction;

  if (action === "edit") {
    state.editingBonusFields.add(key);
    renderBonusForm();
    return;
  }

  if (action !== "save") return;

  const fieldValue = state.bonusDrafts[key] ?? state.bonusPredictions[state.currentUser.id]?.[key];

  if (!hasBonusValue(fieldValue)) {
    showToast("Preencha esse campo antes de salvar.", "error");
    return;
  }

  const payload = {
    ...(state.bonusPredictions[state.currentUser.id] || {}),
    [key]: fieldValue,
  };

  await api.saveBonusPrediction(state.currentUser.id, payload);
  state.bonusPredictions[state.currentUser.id] = payload;
  delete state.bonusDrafts[key];
  state.editingBonusFields.delete(key);
  showToast("Palpite extra salvo.", "success");
  renderBonusForm();
};

const toggleCoinEvent = async ({ userId, matchId, type, cost, targetUserId = null }) => {
  const existing = getLatestActiveCoinEvent(
    (entry) =>
      entry.userId === userId &&
      entry.matchId === matchId &&
      entry.type === type &&
      (targetUserId ? entry.targetUserId === targetUserId : true)
  );

  if (existing) {
    await api.updateCoinEvent(existing.id, { cancelledAt: new Date().toISOString() });
    return { active: false };
  }

  const entry = await api.saveCoinEvent({ userId, matchId, type, cost, ...(targetUserId ? { targetUserId } : {}) });
  return { active: true, entry };
};

const handleAnnulmentSelection = async (matchId, selectedTargetUserId = "") => {
  if (!state.currentUser) return true;

  const match = ensureArray(state.matches, "state.matches").find((entry) => entry.id === matchId);
  const balance = getCoinBalance(state.currentUser.id);
  if (!match) throw new Error("Jogo nao encontrado.");

  const existingAnnulment = getUserAnnulmentAction(state.currentUser.id, matchId);
  if (existingAnnulment) {
    await api.updateCoinEvent(existingAnnulment.id, { cancelledAt: new Date().toISOString() });
    state.openAnnulSelectors.delete(matchId);
    showToast("Anulacao removida.", "success");
    return true;
  }

  const targetUserId = selectedTargetUserId;
  const targetUser = state.users.find((entry) => entry.id === targetUserId);
  const targetPrediction = getPredictionByUser(targetUserId, matchId);

  if (!ANNUL_ALLOWED_PHASES.has(match.phase)) throw new Error("Anulacao so vale ate as quartas de final.");
  if (isPredictionLocked(match)) throw new Error("Mercado ja fechado para este jogo.");
  if (!targetUserId || !targetUser) throw new Error("Escolha um rival para anular.");
  if (!targetPrediction) throw new Error("O rival escolhido ainda nao salvou palpite neste jogo.");
  if (getPredictionAnnulment(targetUserId, matchId)) throw new Error("Esse palpite ja foi anulado.");
  if (balance < ANNUL_COST) throw new Error("Moedas insuficientes.");
  if (!window.confirm(`Anular o palpite de ${targetUser.nickname} neste jogo por ${ANNUL_COST} moedas?`)) return true;

  await api.saveCoinEvent({
    userId: state.currentUser.id,
    targetUserId,
    matchId,
    type: "annul-prediction",
    cost: ANNUL_COST,
  });
  state.openAnnulSelectors.delete(matchId);
  showToast("Palpite rival anulado.", "success");
  return true;
};

const handleCoinAction = async (event) => {
  const button = event.target.closest("[data-coin-action]");
  if (!button || !state.currentUser) return false;

  const matchId = button.dataset.matchId;
  const action = button.dataset.coinAction;
  const match = ensureArray(state.matches, "state.matches").find((entry) => entry.id === matchId);
  const prediction = getCurrentUserPrediction(matchId);
  const effects = getUserMatchEffects(state.currentUser.id, match);
  const balance = getCoinBalance(state.currentUser.id);
  const usage = getCoinUsageCounts(state.currentUser.id);

  if (!match) {
    showToast("Jogo nao encontrado.", "error");
    return true;
  }

  try {
    const activeEvent = getLatestActiveCoinEvent(
      (entry) => entry.userId === state.currentUser.id && entry.matchId === matchId && entry.type === action
    );
    const needsPrediction = ["draw-protection", "error-shield", "points-x2", "points-x3"].includes(action);
    const coinPhaseAction = ["draw-protection", "error-shield", "points-x2", "points-x3"].includes(action);

    if (needsPrediction && !prediction) throw new Error("Salve um palpite antes de usar moedas neste jogo.");
    if (coinPhaseAction && !COIN_PHASES.has(match.phase)) throw new Error("Moedas manuais so podem ser usadas ate as quartas.");

    if (action === "draw-protection") {
      if (!activeEvent && getPredictionOutcome(prediction) !== "draw") throw new Error("Empate protegido so vale para palpite de empate.");
      if (!activeEvent && balance < DRAW_PROTECTION_COST) throw new Error("Moedas insuficientes.");
      const result = await toggleCoinEvent({ userId: state.currentUser.id, matchId, type: "draw-protection", cost: DRAW_PROTECTION_COST });
      showToast(result.active ? "Empate protegido ativado." : "Empate protegido removido.", "success");
    }

    if (action === "points-x2") {
      if (getAutomaticMultiplier(match) > 1) throw new Error("Este jogo ja tem multiplicador automatico.");
      if (!activeEvent && getSuperBonusEvent(state.currentUser.id, matchId)) throw new Error("Remova o x3 antes de usar x2 neste jogo.");
      if (!activeEvent && balance < POINTS_X2_COST) throw new Error("Moedas insuficientes.");
      const result = await toggleCoinEvent({ userId: state.currentUser.id, matchId, type: "points-x2", cost: POINTS_X2_COST });
      showToast(result.active ? "Pontuacao x2 ativada." : "Pontuacao x2 removida.", "success");
    }

    if (action === "points-x3") {
      if (getAutomaticMultiplier(match) > 1) throw new Error("Este jogo ja tem multiplicador automatico.");
      if (!activeEvent && getPersonalBonusEvent(state.currentUser.id, matchId)) throw new Error("Remova o x2 antes de usar x3 neste jogo.");
      if (!activeEvent && balance < POINTS_X3_COST) throw new Error("Moedas insuficientes.");
      const result = await toggleCoinEvent({ userId: state.currentUser.id, matchId, type: "points-x3", cost: POINTS_X3_COST });
      showToast(result.active ? "Pontuacao x3 ativada." : "Pontuacao x3 removida.", "success");
    }

    if (action === "personal-bonus") {
      if (!prediction) throw new Error("Salve um palpite antes de usar moedas neste jogo.");
      if (effects.globalBonus) throw new Error("Este jogo ja e bonus global.");
      if (effects.personalBonus) throw new Error("Voce ja ativou o bonus pessoal neste jogo.");
      if (balance < PERSONAL_BONUS_COST) throw new Error("Moedas insuficientes.");
      await api.saveCoinEvent({ userId: state.currentUser.id, matchId, type: "personal-bonus", cost: PERSONAL_BONUS_COST });
      showToast("Jogo Bonus x2 pessoal ativado.", "success");
    }

    if (action === "error-shield") {
      if (!activeEvent && balance < ERROR_SHIELD_COST) throw new Error("Moedas insuficientes.");
      const result = await toggleCoinEvent({ userId: state.currentUser.id, matchId, type: "error-shield", cost: ERROR_SHIELD_COST });
      showToast(result.active ? "Seguro de erro ativado." : "Seguro de erro removido.", "success");
    }

    if (action === "late-edit") {
      if (!prediction) throw new Error("Voce precisa ter um palpite salvo para usar alteracao tardia.");
      if (effects.lateEdit) throw new Error("A alteracao tardia deste jogo ja foi usada.");
      if (!canUseLateEditWindow(match)) throw new Error("Alteracao tardia disponivel so ate 60 minutos apos o inicio.");
      if (usage.lateEdit >= LATE_EDIT_LIMIT) throw new Error("Voce ja usou o limite de alteracao tardia no torneio.");
      if (balance < LATE_EDIT_COST) throw new Error("Moedas insuficientes.");
      await api.saveCoinEvent({ userId: state.currentUser.id, matchId, type: "late-edit", cost: LATE_EDIT_COST, consumedAt: null });
      state.editingPredictions.add(matchId);
      showToast("Alteracao tardia liberada para este jogo.", "success");
    }

    if (action === "annul-prediction") {
      const existingAnnulment = getUserAnnulmentAction(state.currentUser.id, matchId);
      if (existingAnnulment) {
        await handleAnnulmentSelection(matchId);
      } else if (state.openAnnulSelectors.has(matchId)) {
        state.openAnnulSelectors.delete(matchId);
        renderMatches();
        return true;
      } else {
        state.openAnnulSelectors.add(matchId);
        renderMatches();
        return true;
      }
    }

    const fresh = await api.refresh();
    applyFreshData(fresh);
    await freezeMinoritySnapshots();
    renderAll();
  } catch (error) {
    showToast(error.message, "error");
  }

  return true;
};

const handleLogin = async (event) => {
  event.preventDefault();
  try {
    state.currentUser = await api.login({
      nickname: document.querySelector("#login-nickname").value,
      password: document.querySelector("#login-password").value,
    });
    closeAuthDialog();
    showToast("Login realizado com sucesso.", "success");
    renderAll();
  } catch (error) {
    showToast(error.message, "error");
  }
};

const handleRegister = async (event) => {
  event.preventDefault();
  try {
    const file = document.querySelector("#register-avatar-upload").files[0];
    let avatarType = "preset";
    let avatarValue = state.selectedAvatarPreset;

    if (file) {
      if (file.size > APP_CONFIG.maxAvatarSizeMb * 1024 * 1024) {
        throw new Error(`A foto deve ter no maximo ${APP_CONFIG.maxAvatarSizeMb}MB.`);
      }
      avatarType = "upload";
      avatarValue = await fileToDataUrl(file);
    }

    state.currentUser = await api.register({
      nickname: document.querySelector("#register-nickname").value.trim(),
      realName: document.querySelector("#register-name").value.trim(),
      password: document.querySelector("#register-password").value,
      avatarType,
      avatarValue,
    });

    const fresh = await api.refresh();
    applyFreshData(fresh);
    await freezeMinoritySnapshots();
    closeAuthDialog();
    showToast("Conta criada com sucesso.", "success");
    renderAll();
  } catch (error) {
    showToast(error.message, "error");
  }
};

const handleChatSubmit = async (event) => {
  if (!elements.chatInput) return;
  event.preventDefault();
  if (!state.currentUser) {
    showToast("Faca login para conversar.", "error");
    return;
  }

  const message = elements.chatInput.value.trim();
  if (!message) return;

  await api.sendMessage(state.currentUser, message);
  elements.chatInput.value = "";
  const fresh = await api.refresh();
  state.chatMessages = fresh.chatMessages;
  renderChat();
};

const clearCoinTooltipState = () => {
  if (state.coinTooltipTimer) {
    clearTimeout(state.coinTooltipTimer);
    state.coinTooltipTimer = null;
  }
  if (state.activeCoinTooltipButton) {
    state.activeCoinTooltipButton.classList.remove("coin-action-toggle--tooltip");
    state.activeCoinTooltipButton = null;
  }
};

const handleCoinTooltipStart = (event) => {
  const button = event.target.closest(".coin-action-toggle");
  if (!button) return;
  clearCoinTooltipState();
  state.coinTooltipTimer = setTimeout(() => {
    button.classList.add("coin-action-toggle--tooltip");
    state.activeCoinTooltipButton = button;
  }, 360);
};

const handleCoinTooltipEnd = () => {
  clearCoinTooltipState();
};

const handleAdminClick = async (event) => {
  const deleteMessageId = event.target.dataset.deleteMessage;
  if (deleteMessageId && state.currentUser?.isAdmin) {
    await api.deleteMessage(deleteMessageId);
    const fresh = await api.refresh();
    state.chatMessages = fresh.chatMessages;
    renderChat();
    showToast("Mensagem removida.", "success");
    return;
  }

  const action = event.target.dataset.adminAction;
  const userId = event.target.dataset.userId;
  if (!action || !userId || !state.currentUser?.isAdmin) return;

  if (action === "toggle-block") {
    const user = state.users.find((entry) => entry.id === userId);
    await api.adminUpdateUser(userId, { isBlocked: !user.isBlocked });
    showToast("Status do usuario atualizado.", "success");
  }

  if (action === "rename-user") {
    const user = state.users.find((entry) => entry.id === userId);
    const nickname = window.prompt("Novo apelido do usuario:", user.nickname);
    if (nickname) {
      await api.adminUpdateUser(userId, { nickname: nickname.trim() });
      showToast("Apelido atualizado.", "success");
    }
  }

  if (action === "change-avatar") {
    const avatarValue = window.prompt("Informe o preset (ex.: preset-3) ou uma URL da foto:");
    if (avatarValue) {
      await api.adminUpdateUser(userId, {
        avatarType: avatarValue.startsWith("http") ? "upload" : "preset",
        avatarValue: avatarValue.trim(),
      });
      showToast("Avatar atualizado.", "success");
    }
  }

  if (action === "reset-password") {
    await api.adminUpdateUser(userId, { password: "1234" });
    showToast("Senha resetada para 1234.", "success");
  }

  if (action === "delete-user") {
    await api.adminDeleteUser(userId);
    showToast("Usuario excluido.", "success");
  }

  const fresh = await api.refresh();
  applyFreshData(fresh);
  await freezeMinoritySnapshots();
  renderAll();
};

const handleBannerSubmit = async (event) => {
  event.preventDefault();
  if (!state.currentUser?.isAdmin) return;
  await api.publishBanner(elements.bannerInput.value.trim());
  const fresh = await api.refresh();
  state.settings = fresh.settings;
  renderBanner();
  showToast("Banner publicado.", "success");
};

const updateSliderPage = (sliderKey, direction) => {
  const visibleSection = groupVisibleMatches(getVisibleMatches()).find((section) => section.key === sliderKey);
  if (!visibleSection) return;

  const pages = chunkIntoPages(visibleSection.matches, 4);
  const currentPage = state.matchSliderIndex[sliderKey] || 0;
  const nextPage =
    direction === "next"
      ? Math.min(currentPage + 1, pages.length - 1)
      : Math.max(currentPage - 1, 0);

  if (nextPage === currentPage) return;
  state.matchSliderIndex[sliderKey] = nextPage;
  renderMatches();
};

const handleMatchGridClick = (event) => {
  if (event.target.closest("[data-coin-action]")) {
    handleCoinAction(event);
    return;
  }

  const coinToggleButton = event.target.closest("[data-toggle-coins]");
  if (coinToggleButton) {
    const matchId = coinToggleButton.dataset.toggleCoins;
    if (state.openCoinPanels.has(matchId)) {
      state.openCoinPanels.delete(matchId);
    } else {
      state.openCoinPanels.add(matchId);
    }
    renderMatches();
    return;
  }

  const pageButton = event.target.closest("[data-matches-page]");
  if (pageButton) {
    state.matchesPage = Number(pageButton.dataset.matchesPage) || 1;
    renderMatches();
    return;
  }

  const sliderButton = event.target.closest("[data-slider-direction]");
  if (sliderButton) {
    updateSliderPage(sliderButton.dataset.sliderKey, sliderButton.dataset.sliderDirection);
    return;
  }

  const editButton = event.target.closest("[data-edit-match]");
  if (!editButton) return;
  state.editingPredictions.add(editButton.dataset.editMatch);
  renderAll();
};

const handleMatchGridInput = (event) => {
  const form = event.target.closest(".prediction-form");
  if (!form) return;
  syncKnockoutFormState(form);
};

const handleMatchGridChange = async (event) => {
  const target = event.target.closest("[data-annul-target]");
  if (!target || !state.currentUser) return;
  if (!target.value) return;

  try {
    await handleAnnulmentSelection(target.dataset.annulTarget, target.value);
    const fresh = await api.refresh();
    applyFreshData(fresh);
    await freezeMinoritySnapshots();
    renderAll();
  } catch (error) {
    showToast(error.message, "error");
  }
};

const handleMatchGridTouchStart = (event) => {
  const slider = event.target.closest("[data-slider-key]");
  if (!slider) return;

  state.sliderTouch = {
    key: slider.dataset.sliderKey,
    startX: event.changedTouches[0]?.clientX ?? 0,
  };
};

const handleMatchGridTouchEnd = (event) => {
  if (!state.sliderTouch) return;

  const endX = event.changedTouches[0]?.clientX ?? state.sliderTouch.startX;
  const deltaX = endX - state.sliderTouch.startX;
  const activeKey = state.sliderTouch.key;
  state.sliderTouch = null;

  if (Math.abs(deltaX) < 42) return;
  updateSliderPage(activeKey, deltaX < 0 ? "next" : "prev");
};

const bindEvents = () => {
  elements.themeToggle.addEventListener("click", toggleTheme);
  elements.authOpenButton.addEventListener("click", async () => {
    if (!state.currentUser) {
      openAuthDialog("login");
      return;
    }
    await api.logout();
    state.currentUser = null;
    state.editingPredictions.clear();
    state.editingBonusFields.clear();
    state.bonusDrafts = {};
    renderAll();
    showToast("Sessao encerrada.", "success");
  });
  elements.authRegisterTopButton?.addEventListener("click", () => openAuthDialog("register"));
  elements.authCloseButton.addEventListener("click", closeAuthDialog);
  elements.loginForm.addEventListener("submit", handleLogin);
  elements.registerForm.addEventListener("submit", handleRegister);
  elements.chatForm?.addEventListener("submit", handleChatSubmit);
  elements.bannerForm.addEventListener("submit", handleBannerSubmit);
  elements.matchesGrid.addEventListener("submit", handlePredictionSubmit);
  elements.matchesGrid.addEventListener("click", handleMatchGridClick);
  elements.matchesGrid.addEventListener("input", handleMatchGridInput);
  elements.matchesGrid.addEventListener("change", handleMatchGridChange);
  elements.matchesGrid.addEventListener("pointerdown", handleCoinTooltipStart);
  elements.matchesGrid.addEventListener("pointerup", handleCoinTooltipEnd);
  elements.matchesGrid.addEventListener("pointerleave", handleCoinTooltipEnd);
  elements.matchesGrid.addEventListener("pointercancel", handleCoinTooltipEnd);
  elements.matchesGrid.addEventListener("touchstart", handleMatchGridTouchStart, { passive: true });
  elements.matchesGrid.addEventListener("touchend", handleMatchGridTouchEnd, { passive: true });
  elements.quickPicksList?.addEventListener("submit", handlePredictionSubmit);
  elements.quickPicksList?.addEventListener("click", handleMatchGridClick);
  elements.bonusForm.addEventListener("click", handleBonusClick);
  elements.bonusForm.addEventListener("input", (event) => {
    const field = event.target.closest("[name]");
    if (!field) return;
    state.bonusDrafts[field.name] = field.type === "number"
      ? (field.value === "" ? null : Number(field.value))
      : field.value;
  });
  elements.chatList?.addEventListener("click", handleAdminClick);
  elements.adminUsersList.addEventListener("click", handleAdminClick);

  elements.rankingFilter.addEventListener("change", (event) => {
    state.rankingFilter = event.target.value;
    renderRanking();
  });

  elements.phaseFilter.addEventListener("change", (event) => {
    state.phaseFilter = event.target.value;
    state.matchesPage = 1;
    state.matchSliderIndex = {};
    renderAll();
  });

  elements.matchFilter?.addEventListener("change", (event) => {
    state.matchFilter = event.target.value;
    state.matchesPage = 1;
    state.matchSliderIndex = {};
    renderAll();
  });

  elements.groupFilter?.addEventListener("change", (event) => {
    state.matchGroupFilter = event.target.value;
    state.matchesPage = 1;
    state.matchSliderIndex = {};
    renderAll();
  });

  document.body.addEventListener("click", (event) => {
    const tabButton = event.target.closest("[data-tab-target], .bottom-nav a");
    if (tabButton) {
      event.preventDefault();
      const tabId =
        tabButton.dataset.tabTarget ||
        tabButton.getAttribute("href")?.replace("#", "") ||
        "jogos";
      setActiveTab(tabId === "palpites" ? "jogos" : tabId);
      return;
    }

    const avatarButton = event.target.closest("[data-avatar-id]");
    if (avatarButton) {
      state.selectedAvatarPreset = avatarButton.dataset.avatarId;
      renderAvatarPresets();
      return;
    }

    const authTabButton = event.target.closest("[data-auth-tab]");
    if (authTabButton) {
      openAuthDialog(authTabButton.dataset.authTab);
    }
  });

  document.body.addEventListener("change", (event) => {
    const toggle = event.target.closest("[data-password-toggle]");
    if (!toggle) return;
    const target = document.getElementById(toggle.dataset.passwordToggle);
    if (target) {
      target.type = toggle.checked ? "text" : "password";
    }
  });
};

loadTheme();
bindEvents();
syncState().catch((error) => {
  console.error(error);
  showToast(error.message || "Erro ao iniciar o sistema.", "error");
});

setInterval(() => {
  api.refresh()
    .then(async (fresh) => {
      applyFreshData(fresh);
      await freezeMinoritySnapshots();
      renderAll();
    })
    .catch(() => {});
}, 30000);

