import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";
import { SUPABASE_CONFIG } from "./config.js";
import {
  MOCK_DATA_VERSION,
  mockBonusPredictions,
  mockChatMessages,
  mockCoinEvents,
  mockMatches,
  mockMinoritySnapshots,
  mockPredictions,
  mockSettings,
  mockUsers,
} from "./mock-data.js";

const LS_KEY = `bolao-copa-2026-mock-db-${MOCK_DATA_VERSION}`;
const SESSION_KEY = "bolao-copa-2026-session";
const MECHANICS_KEY = `bolao-copa-2026-mechanics-${MOCK_DATA_VERSION}`;

const deepClone = (value) => JSON.parse(JSON.stringify(value));
const ensureArray = (value) => (Array.isArray(value) ? value : []);
const ensureObject = (value) => (value && typeof value === "object" && !Array.isArray(value) ? value : {});
const loadMechanicsStore = () => {
  const existing = localStorage.getItem(MECHANICS_KEY);
  if (existing) {
    try {
      const parsed = JSON.parse(existing);
      return {
        coinEvents: ensureArray(parsed?.coinEvents),
        minoritySnapshots: ensureObject(parsed?.minoritySnapshots),
      };
    } catch (error) {
      console.error("[bolao] Falha ao ler store de mecanicas. Recriando.", error);
    }
  }
  const seed = { coinEvents: [], minoritySnapshots: {} };
  localStorage.setItem(MECHANICS_KEY, JSON.stringify(seed));
  return seed;
};
const saveMechanicsStore = (store) =>
  localStorage.setItem(
    MECHANICS_KEY,
    JSON.stringify({
      coinEvents: ensureArray(store?.coinEvents),
      minoritySnapshots: ensureObject(store?.minoritySnapshots),
    })
  );
const normalizeDb = (db) => ({
  users: ensureArray(db?.users),
  matches: ensureArray(db?.matches),
  predictions: ensureArray(db?.predictions),
  bonusPredictions: ensureObject(db?.bonusPredictions),
  coinEvents: ensureArray(db?.coinEvents),
  chatMessages: ensureArray(db?.chatMessages),
  minoritySnapshots: ensureObject(db?.minoritySnapshots),
  settings: ensureObject(db?.settings),
});

const loadMockDb = () => {
  const existing = localStorage.getItem(LS_KEY);
  if (existing) {
    try {
      return normalizeDb(JSON.parse(existing));
    } catch (error) {
      console.error("[bolao] Falha ao ler localStorage mock. Recriando base.", error);
    }
  }
  const seed = {
    users: deepClone(mockUsers),
    matches: deepClone(mockMatches),
    predictions: deepClone(mockPredictions),
    bonusPredictions: deepClone(mockBonusPredictions),
    coinEvents: deepClone(mockCoinEvents),
    chatMessages: deepClone(mockChatMessages),
    minoritySnapshots: deepClone(mockMinoritySnapshots),
    settings: deepClone(mockSettings),
  };
  localStorage.setItem(LS_KEY, JSON.stringify(seed));
  return normalizeDb(seed);
};

const saveMockDb = (db) => localStorage.setItem(LS_KEY, JSON.stringify(normalizeDb(db)));

const normalizeUser = (user) => {
  const { password, ...safeUser } = user;
  return safeUser;
};

class MockApiClient {
  constructor() {
    this.db = loadMockDb();
  }

  persist() {
    saveMockDb(this.db);
  }

  async bootstrap() {
    return this.getInitialData();
  }

  async getInitialData() {
    return {
      users: this.db.users.map(normalizeUser),
      matches: this.db.matches,
      predictions: this.db.predictions,
      bonusPredictions: this.db.bonusPredictions,
      coinEvents: this.db.coinEvents,
      chatMessages: this.db.chatMessages,
      minoritySnapshots: this.db.minoritySnapshots,
      settings: this.db.settings,
      session: this.getStoredSession(),
    };
  }

  getStoredSession() {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const session = JSON.parse(raw);
    const user = this.db.users.find((entry) => entry.id === session.userId && !entry.isBlocked);
    return user ? normalizeUser(user) : null;
  }

  setSession(user) {
    localStorage.setItem(SESSION_KEY, JSON.stringify({ userId: user.id }));
  }

  clearSession() {
    localStorage.removeItem(SESSION_KEY);
  }

  async login({ nickname, password }) {
    const user = this.db.users.find(
      (entry) => entry.nickname.toLowerCase() === nickname.toLowerCase() && entry.password === password
    );
    if (!user) throw new Error("Apelido ou senha invalidos.");
    if (user.isBlocked) throw new Error("Usuario bloqueado.");
    this.setSession(user);
    return normalizeUser(user);
  }

  async register(payload) {
    if (this.db.users.length >= 20) {
      throw new Error("Limite de usuarios atingido.");
    }
    if (this.db.users.some((entry) => entry.nickname.toLowerCase() === payload.nickname.toLowerCase())) {
      throw new Error("Esse apelido ja esta em uso.");
    }
    const user = {
      id: `u${crypto.randomUUID()}`,
      nickname: payload.nickname.trim(),
      realName: payload.realName.trim(),
      password: payload.password,
      avatarType: payload.avatarType,
      avatarValue: payload.avatarValue,
      isAdmin: false,
      isBlocked: false,
      previousRank: this.db.users.length + 1,
    };
    this.db.users.push(user);
    this.persist();
    this.setSession(user);
    return normalizeUser(user);
  }

  async logout() {
    this.clearSession();
  }

  async savePrediction(userId, prediction) {
    const timestamp = new Date().toISOString();
    const existing = this.db.predictions.find(
      (item) => item.userId === userId && item.matchId === prediction.matchId
    );
    if (existing) {
      Object.assign(existing, prediction, { updatedAt: timestamp, createdAt: existing.createdAt || timestamp });
    } else {
      this.db.predictions.push({ userId, ...prediction, createdAt: timestamp, updatedAt: timestamp });
    }
    this.persist();
  }

  async saveBonusPrediction(userId, bonusPrediction) {
    this.db.bonusPredictions[userId] = bonusPrediction;
    this.persist();
  }

  async saveCoinEvent(event) {
    const entry = {
      id: event.id || crypto.randomUUID(),
      createdAt: event.createdAt || new Date().toISOString(),
      ...event,
    };
    this.db.coinEvents.push(entry);
    this.persist();
    return entry;
  }

  async updateCoinEvent(eventId, updates) {
    const entry = this.db.coinEvents.find((item) => item.id === eventId);
    if (!entry) throw new Error("Evento de moeda nao encontrado.");
    Object.assign(entry, updates);
    this.persist();
    return entry;
  }

  async saveMinoritySnapshot(matchId, snapshot) {
    this.db.minoritySnapshots[matchId] = snapshot;
    this.persist();
    return snapshot;
  }

  async sendMessage(user, message) {
    const entry = {
      id: crypto.randomUUID(),
      userId: user.id,
      nickname: user.nickname,
      avatarType: user.avatarType,
      avatarValue: user.avatarValue,
      message,
      createdAt: new Date().toISOString(),
    };
    this.db.chatMessages.push(entry);
    this.persist();
  }

  async deleteMessage(messageId) {
    this.db.chatMessages = this.db.chatMessages.filter((entry) => entry.id !== messageId);
    this.persist();
  }

  async publishBanner(message) {
    this.db.settings.banner = { message, updatedAt: new Date().toISOString() };
    this.persist();
  }

  async adminUpdateUser(userId, updates) {
    const user = this.db.users.find((entry) => entry.id === userId);
    if (!user) throw new Error("Usuario nao encontrado.");
    Object.assign(user, updates);
    this.persist();
    return normalizeUser(user);
  }

  async adminDeleteUser(userId) {
    this.db.users = this.db.users.filter((entry) => entry.id !== userId);
    this.db.predictions = this.db.predictions.filter((entry) => entry.userId !== userId);
    delete this.db.bonusPredictions[userId];
    this.db.coinEvents = this.db.coinEvents.filter((entry) => entry.userId !== userId && entry.targetUserId !== userId);
    this.db.chatMessages = this.db.chatMessages.filter((entry) => entry.userId !== userId);
    this.persist();
  }

  async refresh() {
    this.db = loadMockDb();
    return this.getInitialData();
  }
}

class SupabaseApiClient {
  constructor() {
    this.client = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }

  getToken() {
    return localStorage.getItem(SESSION_KEY);
  }

  setToken(token) {
    localStorage.setItem(SESSION_KEY, token);
  }

  clearToken() {
    localStorage.removeItem(SESSION_KEY);
  }

  mapSettings(row) {
    const value = row?.value || {};
    return {
      banner: value.banner ? { message: value.banner, updatedAt: row.updated_at } : null,
      bonusLockAt: value.bonus_lock_at || null,
      bonusResults: value.bonus_results || null,
    };
  }

  mapUser(entry) {
    return {
      id: entry.id,
      nickname: entry.nickname,
      realName: entry.real_name,
      avatarType: entry.avatar_type,
      avatarValue: entry.avatar_value,
      isAdmin: entry.is_admin,
      isBlocked: entry.is_blocked,
      previousRank: entry.previous_rank,
    };
  }

  async bootstrap() {
    const [usersResult, matchesResult, predictionsResult, bonusResult, settingsResult, chatResult] = await Promise.all([
      this.client.from("app_users").select("id,nickname,real_name,avatar_type,avatar_value,is_admin,is_blocked,previous_rank"),
      this.client.from("matches").select("*").order("match_number"),
      this.client.from("predictions").select("*"),
      this.client.from("bonus_predictions").select("*"),
      this.client.from("app_settings").select("*").eq("key", "system").maybeSingle(),
      this.client.from("chat_messages").select("id,user_id,message,created_at"),
    ]);

    if (usersResult.error) throw usersResult.error;
    if (matchesResult.error) throw matchesResult.error;
    if (predictionsResult.error) throw predictionsResult.error;
    if (bonusResult.error) throw bonusResult.error;
    if (settingsResult.error) throw settingsResult.error;
    if (chatResult.error) throw chatResult.error;

    const users = usersResult.data.map((entry) => this.mapUser(entry));
    const session = await this.getStoredSession(users);
    const chatMessages = chatResult.data.map((entry) => {
      const user = users.find((item) => item.id === entry.user_id);
      return {
        id: entry.id,
        userId: entry.user_id,
        nickname: user?.nickname || "usuario",
        avatarType: user?.avatarType || "preset",
        avatarValue: user?.avatarValue || "preset-1",
        message: entry.message,
        createdAt: entry.created_at,
      };
    });

    return {
      users,
      matches: matchesResult.data.map((entry) => ({
        id: entry.id,
        number: entry.match_number,
        phase: entry.phase,
        phaseLabel: entry.phase_label,
        group: entry.group_name,
        homeTeam: entry.home_team,
        awayTeam: entry.away_team,
        homeCode: entry.home_code,
        awayCode: entry.away_code,
        startsAt: entry.starts_at,
        stadium: entry.stadium,
        location: entry.location,
        status: entry.status,
        scoreHome: entry.score_home,
        scoreAway: entry.score_away,
        extraTimeHome: entry.extra_time_home,
        extraTimeAway: entry.extra_time_away,
        winnerTeam: entry.winner_team,
      })),
      predictions: predictionsResult.data.map((entry) => ({
        userId: entry.user_id,
        matchId: entry.match_id,
        homeScore: entry.home_score,
        awayScore: entry.away_score,
        extraTimeHome: entry.extra_time_home,
        extraTimeAway: entry.extra_time_away,
        winnerTeam: entry.winner_team,
      })),
      bonusPredictions: Object.fromEntries(
        bonusResult.data.map((entry) => [
          entry.user_id,
          {
            champion: entry.champion,
            runnerUp: entry.runner_up,
            thirdPlace: entry.third_place,
            fourthPlace: entry.fourth_place,
            topScorer: entry.top_scorer,
            bestGroupStageTeam: entry.best_group_stage_team,
            tournamentZebra: entry.tournament_zebra,
            totalGoals: entry.total_goals,
          },
        ])
      ),
      coinEvents: loadMechanicsStore().coinEvents,
      chatMessages,
      minoritySnapshots: loadMechanicsStore().minoritySnapshots,
      settings: this.mapSettings(settingsResult.data),
      session,
    };
  }

  async getStoredSession(users = null) {
    const token = this.getToken();
    if (!token) return null;
    const { data, error } = await this.client.rpc("app_get_user_by_token", { session_token: token });
    if (error || !data) {
      this.clearToken();
      return null;
    }
    return users?.find((entry) => entry.id === data.id) || this.mapUser(data);
  }

  async login({ nickname, password }) {
    const { data, error } = await this.client.rpc("app_login_user", {
      p_nickname: nickname,
      p_password: password,
    });
    if (error) throw error;
    const row = data?.[0];
    this.setToken(row.token);
    return {
      id: row.user_id,
      nickname: row.nickname,
      realName: row.real_name,
      avatarType: row.avatar_type,
      avatarValue: row.avatar_value,
      isAdmin: row.is_admin,
      isBlocked: row.is_blocked,
    };
  }

  async register(payload) {
    const { data, error } = await this.client.rpc("app_register_user", {
      p_nickname: payload.nickname,
      p_real_name: payload.realName,
      p_password: payload.password,
      p_avatar_type: payload.avatarType,
      p_avatar_value: payload.avatarValue,
    });
    if (error) throw error;
    const row = data?.[0];
    this.setToken(row.token);
    return {
      id: row.user_id,
      nickname: row.nickname,
      realName: row.real_name,
      avatarType: row.avatar_type,
      avatarValue: row.avatar_value,
      isAdmin: row.is_admin,
      isBlocked: row.is_blocked,
    };
  }

  async logout() {
    const token = this.getToken();
    if (!token) return;
    await this.client.rpc("app_logout_user", { p_token: token });
    this.clearToken();
  }

  async savePrediction(userId, prediction) {
    const token = this.getToken();
    const { error } = await this.client.rpc("app_save_prediction", {
      p_token: token,
      p_match_id: prediction.matchId,
      p_home_score: prediction.homeScore,
      p_away_score: prediction.awayScore,
      p_extra_time_home: prediction.extraTimeHome,
      p_extra_time_away: prediction.extraTimeAway,
      p_winner_team: prediction.winnerTeam,
    });
    if (error) throw error;
  }

  async saveBonusPrediction(userId, bonusPrediction) {
    const token = this.getToken();
    const { error } = await this.client.rpc("app_save_bonus_prediction", {
      p_token: token,
      p_champion: bonusPrediction.champion,
      p_runner_up: bonusPrediction.runnerUp,
      p_third_place: bonusPrediction.thirdPlace,
      p_fourth_place: bonusPrediction.fourthPlace,
      p_top_scorer: bonusPrediction.topScorer,
      p_best_group_stage_team: bonusPrediction.bestGroupStageTeam,
      p_tournament_zebra: bonusPrediction.tournamentZebra,
      p_total_goals: bonusPrediction.totalGoals,
    });
    if (error) throw error;
  }

  async saveCoinEvent(event) {
    const store = loadMechanicsStore();
    const entry = {
      id: event.id || crypto.randomUUID(),
      createdAt: event.createdAt || new Date().toISOString(),
      ...event,
    };
    store.coinEvents.push(entry);
    saveMechanicsStore(store);
    return entry;
  }

  async updateCoinEvent(eventId, updates) {
    const store = loadMechanicsStore();
    const entry = store.coinEvents.find((item) => item.id === eventId);
    if (!entry) throw new Error("Evento de moeda nao encontrado.");
    Object.assign(entry, updates);
    saveMechanicsStore(store);
    return entry;
  }

  async saveMinoritySnapshot(matchId, snapshot) {
    const store = loadMechanicsStore();
    store.minoritySnapshots[matchId] = snapshot;
    saveMechanicsStore(store);
    return snapshot;
  }

  async sendMessage(user, message) {
    const token = this.getToken();
    const { error } = await this.client.rpc("app_send_chat_message", {
      p_token: token,
      p_message: message,
    });
    if (error) throw error;
  }

  async deleteMessage(messageId) {
    const token = this.getToken();
    const { error } = await this.client.rpc("app_admin_delete_message", {
      p_token: token,
      p_message_id: messageId,
    });
    if (error) throw error;
  }

  async publishBanner(message) {
    const token = this.getToken();
    const { error } = await this.client.rpc("app_admin_set_banner", {
      p_token: token,
      p_message: message,
    });
    if (error) throw error;
  }

  async adminUpdateUser(userId, updates) {
    const token = this.getToken();
    const { error } = await this.client.rpc("app_admin_update_user", {
      p_token: token,
      p_user_id: userId,
      p_nickname: updates.nickname ?? null,
      p_real_name: updates.realName ?? null,
      p_password: updates.password ?? null,
      p_avatar_type: updates.avatarType ?? null,
      p_avatar_value: updates.avatarValue ?? null,
      p_is_blocked: updates.isBlocked ?? null,
    });
    if (error) throw error;
  }

  async adminDeleteUser(userId) {
    const token = this.getToken();
    const { error } = await this.client.rpc("app_admin_delete_user", {
      p_token: token,
      p_user_id: userId,
    });
    if (error) throw error;
  }

  async refresh() {
    return this.bootstrap();
  }
}

export const api =
  SUPABASE_CONFIG.enabled && !SUPABASE_CONFIG.url.includes("COLE_AQUI")
    ? new SupabaseApiClient()
    : new MockApiClient();
