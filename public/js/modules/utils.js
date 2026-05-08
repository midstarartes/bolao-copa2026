import { APP_CONFIG } from "./config.js";
import { avatarPresets } from "./avatar-presets.js";

export const parseSafeDate = (value) => {
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }

  if (typeof value === "number") {
    const parsedFromNumber = new Date(value);
    return Number.isNaN(parsedFromNumber.getTime()) ? null : parsedFromNumber;
  }

  if (typeof value !== "string") {
    return null;
  }

  const trimmedValue = value.trim();
  if (!trimmedValue) return null;

  const brDateTimeMatch = trimmedValue.match(
    /^(\d{2})\/(\d{2})\/(\d{4})(?:,\s*|\s+)?(\d{2}):(\d{2})(?::(\d{2}))?$/
  );
  if (brDateTimeMatch) {
    const [, day, month, year, hours, minutes, seconds = "00"] = brDateTimeMatch;
    const parsedFromBr = new Date(`${year}-${month}-${day}T${hours}:${minutes}:${seconds}`);
    return Number.isNaN(parsedFromBr.getTime()) ? null : parsedFromBr;
  }

  const normalizedValue = /^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?$/.test(trimmedValue)
    ? trimmedValue.replace(" ", "T")
    : trimmedValue;

  const parsedDate = new Date(normalizedValue);
  return Number.isNaN(parsedDate.getTime()) ? null : parsedDate;
};

export const isValidDate = (value) => Boolean(parseSafeDate(value));

export const formatDateTime = (value) => {
  const parsedDate = parseSafeDate(value);
  if (!parsedDate) return "Data a definir";

  try {
    return new Intl.DateTimeFormat("pt-BR", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
      timeZone: "America/Sao_Paulo",
    }).format(parsedDate);
  } catch (error) {
    console.error("formatDateTime: falha ao formatar data", value, error);
    return "Data a definir";
  }
};

export const minutesUntil = (value) => {
  const parsedDate = parseSafeDate(value);
  if (!parsedDate) return Number.POSITIVE_INFINITY;
  return Math.floor((parsedDate.getTime() - Date.now()) / 60000);
};

export const getPredictionDeadline = (startsAt) => {
  const parsedDate = parseSafeDate(startsAt);
  if (!parsedDate) return null;
  return new Date(parsedDate.getTime() - APP_CONFIG.predictionLockMinutes * 60 * 1000);
};

export const isPredictionLocked = (match) => {
  const deadline = getPredictionDeadline(match?.startsAt);
  if (!deadline) return false;
  return Date.now() >= deadline.getTime();
};

export const getResultType = (home, away) => {
  if (home === away) return "draw";
  return home > away ? "home" : "away";
};

export const hasScores = (home, away) =>
  home !== "" &&
  away !== "" &&
  home != null &&
  away != null &&
  Number.isFinite(Number(home)) &&
  Number.isFinite(Number(away));

export const requiresExtraTime = (home, away) =>
  hasScores(home, away) && Number(home) === Number(away);

export const getWinnerFromRegularTime = (homeTeam, awayTeam, home, away) => {
  if (!hasScores(home, away) || Number(home) === Number(away)) return "";
  return Number(home) > Number(away) ? homeTeam : awayTeam;
};

export const scorePrediction = (match, prediction) => {
  if (!prediction || match.scoreHome == null || match.scoreAway == null) {
    return { points: 0, exact: 0, result: 0, considered: 0 };
  }

  const realResult = getResultType(match.scoreHome, match.scoreAway);
  const predictedResult = getResultType(prediction.homeScore, prediction.awayScore);
  const isKnockout = match.phase !== "group";
  let points = 0;
  let exact = 0;
  let result = 0;

  if (!isKnockout) {
    if (prediction.homeScore === match.scoreHome && prediction.awayScore === match.scoreAway) {
      points += 1;
      exact += 1;
      result += 1;
    } else if (predictedResult === realResult) {
      points += 0.5;
      result += 1;
    } else {
      points -= 0.25;
    }
    return { points, exact, result, considered: 1 };
  }

  if (prediction.homeScore === match.scoreHome && prediction.awayScore === match.scoreAway) {
    points += 1.5;
    exact += 1;
    result += 1;
  } else if (predictedResult === realResult) {
    points += 0.5;
    result += 1;
  }

  if (
    prediction.extraTimeHome != null &&
    prediction.extraTimeAway != null &&
    match.extraTimeHome != null &&
    match.extraTimeAway != null &&
    prediction.extraTimeHome === match.extraTimeHome &&
    prediction.extraTimeAway === match.extraTimeAway
  ) {
    points += 0.5;
  }

  if (prediction.winnerTeam && match.winnerTeam) {
    points += prediction.winnerTeam === match.winnerTeam ? 0.5 : -0.5;
  }

  return { points, exact, result, considered: 1 };
};

export const buildAvatarMarkup = (user, extraClass = "") => {
  if (user.avatarType === "upload" && user.avatarValue) {
    return `<div class="avatar ${extraClass}"><img src="${user.avatarValue}" alt="${user.nickname}" /></div>`;
  }
  const preset = avatarPresets.find((item) => item.id === user.avatarValue) || avatarPresets[0];
  if (preset.imageUrl) {
    return `<div class="avatar ${extraClass}" style="background:${preset.gradient}"><img src="${preset.imageUrl}" alt="${preset.name || user.nickname}" /></div>`;
  }
  return `<div class="avatar ${extraClass}" style="background:${preset.gradient}">${preset.emoji || ""}</div>`;
};

export const buildTeamLabel = (team, extraClass = "") => {
  if (!team) return "";
  const flag = team.flagUrl
    ? `<span class="team-flag ${extraClass}"><img class="team-flag-image" src="${team.flagUrl}" alt="Bandeira de ${escapeHtml(team.name)}" loading="lazy" /></span>`
    : team.flag
      ? `<span class="team-flag ${extraClass}">${team.flag}</span>`
      : "";
  return `${flag}<span class="team-label-text">${escapeHtml(team.name)}</span>`;
};

export const escapeHtml = (value = "") =>
  String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");

export const fileToDataUrl = (file) =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });

const stableTieBreaker = (value) =>
  String(value)
    .split("")
    .reduce((accumulator, char, index) => accumulator + char.charCodeAt(0) * (index + 1), 0);

export const sortRanking = (entries) =>
  [...entries].sort((a, b) => {
    if (b.points !== a.points) return b.points - a.points;
    if (b.exact !== a.exact) return b.exact - a.exact;
    if (b.result !== a.result) return b.result - a.result;
    return stableTieBreaker(a.nickname) - stableTieBreaker(b.nickname);
  });

export const summarizeCountdown = (startsAt) => {
  const deadline = getPredictionDeadline(startsAt);
  const minutes = minutesUntil(deadline);
  if (!deadline || !Number.isFinite(minutes)) return "Data a definir";
  if (minutes <= 0) return "Fechado";
  const days = Math.floor(minutes / (60 * 24));
  const remainingAfterDays = minutes - days * 60 * 24;
  const hours = Math.floor(remainingAfterDays / 60);
  const remainingMinutes = remainingAfterDays % 60;
  return `${days}d ${String(hours).padStart(2, "0")}h ${String(remainingMinutes).padStart(2, "0")}m`;
};

// Preparado para futura comparação aproximada de nomes de artilheiro.
// Hoje o mock ainda usa comparação textual simples, mas essa normalização já
// reduz diferenças superficiais como maiúsculas, acentos e espaços extras.
export const normalizeLooseText = (value = "") =>
  value
    .normalize("NFD")
    .replaceAll(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim()
    .replaceAll(/\s+/g, " ");
