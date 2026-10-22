
const express = require("express");
const path = require("path");
const crypto = require("crypto");

const app = express();
const PORT = process.env.PORT || 10000;
const ADMIN_PASSWORD = process.env.REMOTE_ADMIN_PASSWORD;

app.use(express.json({ limit: "10kb" }));

const sessions = new Map();
const messages = [];
let nextMessageId = 1;

const SESSION_TIMEOUT = 60_000;
const MAX_MESSAGES = 200;

function cleanName(value) {
  if (typeof value !== "string") return "";
  return value.replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 32);
}

function addMessage(from, text) {
  messages.push({
    id: nextMessageId++,
    from,
    text: String(text).slice(0, 1000),
    time: new Date().toISOString()
  });

  while (messages.length > MAX_MESSAGES) messages.shift();
}

function getSession(req) {
  const token = req.body?.session || req.query.session;
  if (typeof token !== "string") return null;

  const session = sessions.get(token);
  if (!session) return null;

  if (Date.now() - session.lastSeen > SESSION_TIMEOUT) {
    sessions.delete(token);
    return null;
  }

  session.lastSeen = Date.now();
  return session;
}

function cleanupSessions() {
  const now = Date.now();

  for (const [token, session] of sessions) {
    if (now - session.lastSeen > SESSION_TIMEOUT) {
      sessions.delete(token);
      addMessage("REMOTE", session.name + " a quitte le salon.");
    }
  }
}

app.get("/", (_req, res) => {
  res.type("text/plain").send("REMOTE est en ligne.");
});

app.get("/REMOTE.bat", (_req, res) => {
  res.download(path.join(__dirname, "REMOTE.bat"), "REMOTE.bat");
});

app.get("/health", (_req, res) => {
  res.json({ online: true });
});

app.post("/api/join", (req, res) => {
  cleanupSessions();

  const name = cleanName(req.body?.name);
  if (!name) {
    return res.status(400).json({ error: "Nom invalide." });
  }

  const token = crypto.randomBytes(24).toString("hex");

  const session = {
    name,
    lastSeen: Date.now(),
    admin: false
  };

  sessions.set(token, session);

  const cursor = nextMessageId - 1;
  addMessage("REMOTE", name + " a rejoint le salon.");

  res.json({
    ok: true,
    session: token,
    name,
    cursor
  });
});

app.post("/api/admin/login", (req, res) => {
  const session = getSession(req);

  if (!session) {
    return res.status(401).json({ error: "Session invalide." });
  }

  if (!ADMIN_PASSWORD) {
    return res.status(503).json({
      error: "Configure REMOTE_ADMIN_PASSWORD dans Render."
    });
  }

  const supplied = String(req.body?.password || "");
  const expected = String(ADMIN_PASSWORD);

  const a = Buffer.from(supplied);
  const b = Buffer.from(expected);

  const valid =
    a.length === b.length &&
    crypto.timingSafeEqual(a, b);

  if (!valid) {
    return res.status(403).json({ error: "Mot de passe incorrect." });
  }

  session.admin = true;

  res.json({ ok: true, admin: true });
});

app.post("/api/send", (req, res) => {
  const session = getSession(req);

  if (!session) {
    return res.status(401).json({ error: "Session expiree. Relance REMOTE." });
  }

  if (typeof req.body?.text !== "string") {
    return res.status(400).json({ error: "Message invalide." });
  }

  const text = req.body.text.trim();

  if (!text || text.length > 1000) {
    return res.status(400).json({
      error: "Le message doit contenir entre 1 et 1000 caracteres."
    });
  }

  addMessage(session.name, text);
  res.json({ ok: true });
});

app.get("/api/poll", (req, res) => {
  cleanupSessions();

  const session = getSession(req);

  if (!session) {
    return res.status(401).json({ error: "Session expiree." });
  }

  const since = Math.max(0, Number.parseInt(req.query.since, 10) || 0);

  const result = {
    ok: true,
    messages: messages.filter(message => message.id > since),
    next: nextMessageId - 1
  };

  if (session.admin) {
    result.users = Array.from(sessions.values()).map(user => ({
      name: user.name,
      admin: user.admin
    }));
  }

  res.set("Cache-Control", "no-store");
  res.json(result);
});

app.post("/api/leave", (req, res) => {
  const token = req.body?.session;
  const session = typeof token === "string" ? sessions.get(token) : null;

  if (session) {
    sessions.delete(token);
    addMessage("REMOTE", session.name + " a quitte le salon.");
  }

  res.json({ ok: true });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log("REMOTE fonctionne sur le port " + PORT);
});
