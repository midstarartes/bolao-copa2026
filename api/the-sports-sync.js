const SUPABASE_URL =
  process.env.SUPABASE_URL || "https://zoktbengtliqczjlemdk.supabase.co";
const SUPABASE_ANON_KEY =
  process.env.SUPABASE_ANON_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpva3RiZW5ndGxpcWN6amxlbWRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNjIzODAsImV4cCI6MjA5MzczODM4MH0.sltr6vztakKxqeMjljCOMtlN3_eIl_jItY-xegxjeWE";
const THE_SPORTS_DB_BASE_URL = "https://www.thesportsdb.com/api/v1/json";
const THE_SPORTS_DB_API_KEY = process.env.THE_SPORTS_DB_API_KEY || "123";
const THE_SPORTS_DB_WORLD_CUP_LEAGUE_ID =
  process.env.THE_SPORTS_DB_WORLD_CUP_LEAGUE_ID || "4429";
const ADMIN_USERNAME = process.env.ADMIN_USERNAME || "";
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "";
const CRON_SECRET = process.env.CRON_SECRET || "";

const TEAM_ALIAS_MAP = {
  ALG: ["Argélia", "Algeria"],
  ARG: ["Argentina"],
  AUS: ["Austrália", "Australia"],
  AUT: ["Áustria", "Austria"],
  BEL: ["Bélgica", "Belgium"],
  BIH: [
    "Bósnia e Herzegovina",
    "Bosnia and Herzegovina",
    "Bosnia-Herzegovina",
  ],
  BRA: ["Brasil", "Brazil"],
  CAN: ["Canadá", "Canada"],
  CIV: ["Costa do Marfim", "Ivory Coast", "Cote d'Ivoire"],
  COD: ["RD Congo", "DR Congo", "Congo DR", "Democratic Republic of the Congo"],
  COL: ["Colômbia", "Colombia"],
  CPV: ["Cabo Verde", "Cape Verde"],
  CRO: ["Croácia", "Croatia"],
  CZE: ["República Tcheca", "Czech Republic", "Czechia"],
  CUW: ["Curaçao", "Curacao"],
  EQU: ["Equador", "Ecuador"],
  EGY: ["Egito", "Egypt"],
  ENG: ["Inglaterra", "England"],
  ESP: ["Espanha", "Spain"],
  FRA: ["França", "France"],
  GER: ["Alemanha", "Germany"],
  GHA: ["Gana", "Ghana"],
  HAI: ["Haiti"],
  IRN: ["Irã", "Iran"],
  IRQ: ["Iraque", "Iraq"],
  JPN: ["Japão", "Japan"],
  JOR: ["Jordânia", "Jordan"],
  KOR: ["Coreia do Sul", "South Korea", "Korea Republic", "Republic of Korea"],
  KSA: ["Arábia Saudita", "Saudi Arabia"],
  MAR: ["Marrocos", "Morocco"],
  MEX: ["México", "Mexico"],
  NED: ["Holanda", "Netherlands", "The Netherlands"],
  NOR: ["Noruega", "Norway"],
  NZL: ["Nova Zelândia", "New Zealand"],
  PAN: ["Panamá", "Panama"],
  PAR: ["Paraguai", "Paraguay"],
  POR: ["Portugal"],
  RSA: ["África do Sul", "South Africa"],
  SCO: ["Escócia", "Scotland"],
  SEN: ["Senegal"],
  SUI: ["Suíça", "Switzerland"],
  SWE: ["Suécia", "Sweden"],
  TUN: ["Tunísia", "Tunisia"],
  TUR: ["Turquia", "Turkey", "Türkiye", "Turkiye"],
  URU: ["Uruguai", "Uruguay"],
  USA: ["Estados Unidos", "United States", "USA", "USMNT"],
  UZB: ["Uzbequistão", "Uzbekistan"],
};

const TEAM_ALIAS_TO_CODE = Object.entries(TEAM_ALIAS_MAP).reduce(
  (accumulator, [code, aliases]) => {
    aliases.forEach((alias) => {
      accumulator[normalizeText(alias)] = code;
    });
    accumulator[normalizeText(code)] = code;
    return accumulator;
  },
  {}
);

function normalizeText(value = "") {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-zA-Z0-9]+/g, " ")
    .trim()
    .toLowerCase();
}

function isPlaceholderTeamName(value = "") {
  const normalized = String(value || "").trim().toUpperCase();
  return /^\d+[A-L]$/.test(normalized) || /^[WL]\d+$/.test(normalized);
}

function getTeamCodeFromApiName(name = "") {
  return TEAM_ALIAS_TO_CODE[normalizeText(name)] || "";
}

function getMatchApiDateKey(match) {
  return String(match?.starts_at || "").split("T")[0] || "";
}

function getApiEventTimestamp(event) {
  if (event?.strTimestamp) {
    const timestamp = new Date(event.strTimestamp);
    if (!Number.isNaN(timestamp.getTime())) return timestamp.getTime();
  }

  if (event?.dateEvent && event?.strTime) {
    const rawTime = String(event.strTime).trim();
    const normalizedTime = rawTime.length === 5 ? `${rawTime}:00` : rawTime;
    const timestamp = new Date(`${event.dateEvent}T${normalizedTime}Z`);
    if (!Number.isNaN(timestamp.getTime())) return timestamp.getTime();
  }

  return null;
}

function getApiEventScoreValue(event, keys) {
  for (const key of keys) {
    const rawValue = event?.[key];
    if (rawValue === null || rawValue === undefined || rawValue === "") continue;
    const parsed = Number.parseInt(rawValue, 10);
    if (Number.isInteger(parsed)) return parsed;
  }
  return null;
}

function mapApiEventStatus(event) {
  const rawStatus = normalizeText(
    event?.strStatus || event?.strProgress || event?.strResult || ""
  );

  if (
    rawStatus.includes("cancel") ||
    rawStatus.includes("postpon") ||
    rawStatus.includes("abandon")
  ) {
    return "cancelled";
  }

  if (
    rawStatus === "ft" ||
    rawStatus === "aet" ||
    rawStatus.includes("full time") ||
    rawStatus.includes("after extra time") ||
    rawStatus.includes("pen")
  ) {
    return "completed";
  }

  return "scheduled";
}

function scoreApiEventForMatch(match, event) {
  let score = 0;
  const matchHomeCode = String(match.home_code || "").toUpperCase();
  const matchAwayCode = String(match.away_code || "").toUpperCase();
  const apiHomeCode = getTeamCodeFromApiName(event?.strHomeTeam || "");
  const apiAwayCode = getTeamCodeFromApiName(event?.strAwayTeam || "");

  if (
    !isPlaceholderTeamName(match.home_team) &&
    matchHomeCode &&
    apiHomeCode === matchHomeCode
  ) {
    score += 80;
  } else if (
    !isPlaceholderTeamName(match.home_team) &&
    normalizeText(event?.strHomeTeam || "") === normalizeText(match.home_team || "")
  ) {
    score += 70;
  }

  if (
    !isPlaceholderTeamName(match.away_team) &&
    matchAwayCode &&
    apiAwayCode === matchAwayCode
  ) {
    score += 80;
  } else if (
    !isPlaceholderTeamName(match.away_team) &&
    normalizeText(event?.strAwayTeam || "") === normalizeText(match.away_team || "")
  ) {
    score += 70;
  }

  const matchTimestamp = new Date(match.starts_at).getTime();
  const apiTimestamp = getApiEventTimestamp(event);
  if (Number.isFinite(matchTimestamp) && Number.isFinite(apiTimestamp)) {
    const diffMinutes = Math.abs(matchTimestamp - apiTimestamp) / 60000;
    if (diffMinutes <= 20) score += 40;
    else if (diffMinutes <= 90) score += 28;
    else if (diffMinutes <= 360) score += 12;
  }

  if (getMatchApiDateKey(match) === String(event?.dateEvent || "")) {
    score += 10;
  }

  return score;
}

function findBestApiEventForMatch(match, events) {
  if (!match || !Array.isArray(events) || !events.length) return null;

  const scored = events
    .map((event) => ({ event, score: scoreApiEventForMatch(match, event) }))
    .sort((left, right) => right.score - left.score);

  const best = scored[0];
  if (!best || best.score < 25) return null;
  return best.event;
}

async function readJsonBody(req) {
  return await new Promise((resolve) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("end", () => {
      if (!body) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(body));
      } catch {
        resolve({});
      }
    });
  });
}

async function supabaseRpc(name, payload) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify(payload || {}),
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    throw new Error(data?.message || data?.error_description || data?.error || `RPC ${name} falhou.`);
  }

  return data;
}

async function supabaseSelectMatches(fromIso, toIso) {
  const url = new URL(`${SUPABASE_URL}/rest/v1/matches`);
  url.searchParams.set(
    "select",
    "id,match_number,phase,phase_label,group_name,home_team,away_team,home_code,away_code,starts_at,status,score_home,score_away,extra_time_home,extra_time_away,winner_team"
  );
  url.searchParams.set("starts_at", `gte.${fromIso}`);
  url.searchParams.append("starts_at", `lt.${toIso}`);
  url.searchParams.set("order", "starts_at.asc,match_number.asc");

  const response = await fetch(url, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
    },
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    throw new Error(data?.message || data?.error_description || data?.error || "Não foi possível carregar os jogos.");
  }

  return Array.isArray(data) ? data : [];
}

function getDateKeyWithOffset(offsetDays = 0) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  })
    .formatToParts(new Date())
    .reduce((accumulator, part) => {
      if (part.type !== "literal") accumulator[part.type] = part.value;
      return accumulator;
    }, {});

  const baseUtc = new Date(
    Date.UTC(
      Number(parts.year),
      Number(parts.month) - 1,
      Number(parts.day) + offsetDays,
      12,
      0,
      0
    )
  );

  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(baseUtc);
}

function getBrazilDayBounds(dateKey) {
  const [year, month, day] = dateKey.split("-").map(Number);
  const startUtc = new Date(Date.UTC(year, month - 1, day, 3, 0, 0));
  const endUtc = new Date(Date.UTC(year, month - 1, day + 1, 3, 0, 0));
  return {
    fromIso: startUtc.toISOString(),
    toIso: endUtc.toISOString(),
  };
}

async function fetchTheSportsDbEventsByDate(dateKey) {
  const primaryUrl = `${THE_SPORTS_DB_BASE_URL}/${THE_SPORTS_DB_API_KEY}/eventsday.php?d=${encodeURIComponent(dateKey)}&s=Soccer&id=${encodeURIComponent(THE_SPORTS_DB_WORLD_CUP_LEAGUE_ID)}`;
  const secondaryUrl = `${THE_SPORTS_DB_BASE_URL}/${THE_SPORTS_DB_API_KEY}/eventsday.php?d=${encodeURIComponent(dateKey)}&s=Soccer&l=${encodeURIComponent("FIFA World Cup")}`;

  const requestEvents = async (url) => {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error("Não foi possível consultar o TheSportsDB agora.");
    }
    const payload = await response.json();
    return Array.isArray(payload?.events) ? payload.events : [];
  };

  const primaryEvents = await requestEvents(primaryUrl);
  if (primaryEvents.length > 0) return primaryEvents;
  return await requestEvents(secondaryUrl);
}

async function authenticateCronAdmin() {
  if (!ADMIN_USERNAME || !ADMIN_PASSWORD) {
    throw new Error("ADMIN_USERNAME e ADMIN_PASSWORD precisam estar configurados na Vercel.");
  }

  const loginPayload = await supabaseRpc("app_login_user", {
    p_nickname: ADMIN_USERNAME,
    p_password: ADMIN_PASSWORD,
  });

  const loginData = Array.isArray(loginPayload) ? loginPayload[0] : loginPayload;
  if (!(loginData?.session_token || loginData?.token)) {
    throw new Error("Não foi possível autenticar o admin automático.");
  }

  return loginData.session_token || loginData.token;
}

async function resolveAdminTokenForRequest(req, body) {
  const authHeader = req.headers.authorization || "";
  if (CRON_SECRET && authHeader === `Bearer ${CRON_SECRET}`) {
    return await authenticateCronAdmin();
  }

  const sessionToken = body?.token || req.headers["x-session-token"] || "";
  if (!sessionToken) {
    throw new Error("Token administrativo ausente.");
  }

  const userData = await supabaseRpc("app_get_user_by_token", {
    session_token: sessionToken,
  });

  if (!userData?.is_admin) {
    throw new Error("Acesso administrativo necessário.");
  }

  return sessionToken;
}

function buildWinnerForMatch(match, event, homeScore, awayScore) {
  const explicitWinnerCode = event?.strWinner
    ? getTeamCodeFromApiName(event.strWinner)
    : "";

  if (
    explicitWinnerCode &&
    explicitWinnerCode === String(match.home_code || "").toUpperCase()
  ) {
    return match.home_team;
  }

  if (
    explicitWinnerCode &&
    explicitWinnerCode === String(match.away_code || "").toUpperCase()
  ) {
    return match.away_team;
  }

  if (Number.isInteger(homeScore) && Number.isInteger(awayScore) && homeScore !== awayScore) {
    return homeScore > awayScore ? match.home_team : match.away_team;
  }

  return null;
}

function mapEventToResultPayload(match, event) {
  const homeScore = getApiEventScoreValue(event, ["intHomeScore", "intHomeScore2"]);
  const awayScore = getApiEventScoreValue(event, ["intAwayScore", "intAwayScore2"]);
  const extraHome = getApiEventScoreValue(event, [
    "intHomeExtraScore",
    "intHomeScoreExtra",
    "intHomeScoreET",
  ]);
  const extraAway = getApiEventScoreValue(event, [
    "intAwayExtraScore",
    "intAwayScoreExtra",
    "intAwayScoreET",
  ]);

  return {
    found: true,
    matchId: match.id,
    eventName: event?.strEvent || `${event?.strHomeTeam || ""} x ${event?.strAwayTeam || ""}`.trim(),
    eventStatus: mapApiEventStatus(event),
    homeScore,
    awayScore,
    extraHome,
    extraAway,
    winnerTeam: buildWinnerForMatch(match, event, homeScore, awayScore),
    rawStatus: event?.strStatus || event?.strProgress || "",
  };
}

async function syncMatchResult(adminToken, match, event, { dryRun = false } = {}) {
  const mapped = mapEventToResultPayload(match, event);
  if (!Number.isInteger(mapped.homeScore) || !Number.isInteger(mapped.awayScore)) {
    return { updated: false, reason: "score-unavailable", mapped };
  }

  if (mapped.eventStatus === "scheduled") {
    return { updated: false, reason: "scheduled", mapped };
  }

  const changed =
    match.score_home !== mapped.homeScore ||
    match.score_away !== mapped.awayScore ||
    (match.extra_time_home ?? null) !== (Number.isInteger(mapped.extraHome) ? mapped.extraHome : null) ||
    (match.extra_time_away ?? null) !== (Number.isInteger(mapped.extraAway) ? mapped.extraAway : null) ||
    (match.winner_team || null) !== (mapped.winnerTeam || null) ||
    (match.status || "scheduled") !== mapped.eventStatus;

  if (!changed) {
    return { updated: false, reason: "unchanged", mapped };
  }

  if (!dryRun) {
    await supabaseRpc("app_admin_set_match_result", {
      p_token: adminToken,
      p_match_id: match.id,
      p_score_home: mapped.homeScore,
      p_score_away: mapped.awayScore,
      p_extra_time_home: Number.isInteger(mapped.extraHome) ? mapped.extraHome : null,
      p_extra_time_away: Number.isInteger(mapped.extraAway) ? mapped.extraAway : null,
      p_winner_team: mapped.winnerTeam,
      p_status: mapped.eventStatus,
    });
  }

  return { updated: true, reason: "updated", mapped };
}

async function syncSingleMatch(adminToken, matchId) {
  const matches = await supabaseSelectMatches(
    "2026-01-01T00:00:00.000Z",
    "2026-12-31T23:59:59.999Z"
  );
  const match = matches.find((entry) => entry.id === matchId);
  if (!match) {
    throw new Error("Jogo não encontrado no banco.");
  }

  const events = await fetchTheSportsDbEventsByDate(getMatchApiDateKey(match));
  const event = findBestApiEventForMatch(match, events);
  if (!event) {
    return { found: false, matchId };
  }

  return mapEventToResultPayload(match, event);
}

async function syncRelevantMatches(adminToken) {
  const dateKeys = [getDateKeyWithOffset(-1), getDateKeyWithOffset(0), getDateKeyWithOffset(1)];
  const uniqueDateKeys = [...new Set(dateKeys)];
  const eventsByDate = {};
  const matchesByDate = {};

  for (const dateKey of uniqueDateKeys) {
    const { fromIso, toIso } = getBrazilDayBounds(dateKey);
    matchesByDate[dateKey] = await supabaseSelectMatches(fromIso, toIso);
    eventsByDate[dateKey] = await fetchTheSportsDbEventsByDate(dateKey);
  }

  const results = [];

  for (const dateKey of uniqueDateKeys) {
    const matches = matchesByDate[dateKey] || [];
    const events = eventsByDate[dateKey] || [];

    for (const match of matches) {
      if (isPlaceholderTeamName(match.home_team) || isPlaceholderTeamName(match.away_team)) {
        results.push({ matchId: match.id, updated: false, reason: "placeholder-teams" });
        continue;
      }

      const event = findBestApiEventForMatch(match, events);
      if (!event) {
        results.push({ matchId: match.id, updated: false, reason: "not-found" });
        continue;
      }

      const outcome = await syncMatchResult(adminToken, match, event);
      results.push({
        matchId: match.id,
        updated: outcome.updated,
        reason: outcome.reason,
        eventName: outcome.mapped?.eventName || null,
      });
    }
  }

  return results;
}

module.exports = async function handler(req, res) {
  try {
    if (req.method === "GET") {
      const adminToken = await resolveAdminTokenForRequest(req, {});
      const results = await syncRelevantMatches(adminToken);
      const updated = results.filter((entry) => entry.updated).length;
      return res.status(200).json({
        ok: true,
        mode: "cron",
        updated,
        checked: results.length,
        results,
      });
    }

    if (req.method === "POST") {
      const body = await readJsonBody(req);
      const adminToken = await resolveAdminTokenForRequest(req, body);
      const mode = body?.mode || "match";

      if (mode === "match") {
        const matchId = body?.matchId || "";
        if (!matchId) {
          return res.status(400).json({ ok: false, message: "matchId é obrigatório." });
        }

        const preview = await syncSingleMatch(adminToken, matchId);
        return res.status(200).json({ ok: true, mode, preview });
      }

      if (mode === "today") {
        const results = await syncRelevantMatches(adminToken);
        const updated = results.filter((entry) => entry.updated).length;
        return res.status(200).json({
          ok: true,
          mode,
          updated,
          checked: results.length,
          results,
        });
      }

      return res.status(400).json({ ok: false, message: "Modo inválido." });
    }

    return res.status(405).json({ ok: false, message: "Método não suportado." });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      ok: false,
      message: error?.message || "Falha inesperada na sincronização da API.",
    });
  }
};
