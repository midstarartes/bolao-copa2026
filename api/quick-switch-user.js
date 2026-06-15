const SUPABASE_URL =
  process.env.SUPABASE_URL || "https://zoktbengtliqczjlemdk.supabase.co";
const SUPABASE_ANON_KEY =
  process.env.SUPABASE_ANON_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhc2UiLCJyZWYiOiJ6b2t0YmVuZ3RsaXFjempsZW1kayIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzc4MTYyMzgwLCJleHAiOjIwOTM3MzgzODB9.sltr6vztakKxqeMjljCOMtlN3_eIl_jItY-xegxjeWE";

const ADMIN_USERNAME = process.env.ADMIN_USERNAME || "ADMIN";
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "";
const PERSONAL_USERNAME = process.env.QUICK_SWITCH_PERSONAL_USERNAME || "LORDEWEL";
const PERSONAL_PASSWORD = process.env.QUICK_SWITCH_PERSONAL_PASSWORD || "";

function normalizeNickname(value = "") {
  return String(value || "").trim().toUpperCase();
}

async function readJsonBody(req) {
  return await new Promise((resolve) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("end", () => {
      try {
        resolve(body ? JSON.parse(body) : {});
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
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    const message = data?.message || data?.error || "Falha ao consultar o Supabase.";
    throw new Error(message);
  }

  return Array.isArray(data) ? data[0] : data;
}

async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ ok: false, message: "Metodo nao suportado." });
  }

  try {
    const body = await readJsonBody(req);
    const token = body?.token || "";
    const target = normalizeNickname(body?.target);

    if (!token || !target) {
      return res.status(400).json({ ok: false, message: "Token e destino sao obrigatorios." });
    }

    const currentUser = await supabaseRpc("app_get_user_by_token", {
      session_token: token,
    });

    if (!currentUser?.nickname) {
      return res.status(401).json({ ok: false, message: "Sessao atual invalida." });
    }

    const currentNickname = normalizeNickname(currentUser.nickname);
    const adminNickname = normalizeNickname(ADMIN_USERNAME);
    const personalNickname = normalizeNickname(PERSONAL_USERNAME);

    let loginNickname = "";
    let loginPassword = "";

    if (target === adminNickname) {
      if (currentNickname !== personalNickname || currentUser.is_admin) {
        return res.status(403).json({ ok: false, message: "Troca para ADMIN nao permitida." });
      }
      loginNickname = ADMIN_USERNAME;
      loginPassword = ADMIN_PASSWORD;
    } else if (target === personalNickname) {
      if (currentNickname !== adminNickname || !currentUser.is_admin) {
        return res.status(403).json({ ok: false, message: "Troca para LORDEWEL nao permitida." });
      }
      loginNickname = PERSONAL_USERNAME;
      loginPassword = PERSONAL_PASSWORD;
    } else {
      return res.status(400).json({ ok: false, message: "Destino invalido." });
    }

    if (!loginPassword) {
      return res.status(500).json({
        ok: false,
        message: "Senha segura da troca rapida nao configurada na Vercel.",
      });
    }

    const loggedUser = await supabaseRpc("app_login_user", {
      p_nickname: loginNickname,
      p_password: loginPassword,
    });

    return res.status(200).json({
      ok: true,
      token: loggedUser?.token || "",
      user: loggedUser,
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      ok: false,
      message: error?.message || "Falha inesperada na troca rapida.",
    });
  }
}

module.exports = handler;
