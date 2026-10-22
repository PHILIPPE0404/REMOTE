
const express = require("express");
const http = require("http");
const fs = require("fs");
const path = require("path");
const WebSocket = require("ws");
const crypto = require("crypto");

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ noServer: true });

const PORT = process.env.PORT || 10000;
const TOKEN = process.env.REMOTE_TOKEN;
const clients = new Map();

if (!TOKEN || TOKEN.length < 32) {
  throw new Error("Configure REMOTE_TOKEN (32 caracteres minimum).");
}

app.get("/", (_req, res) => {
  res.send("REMOTE server is online.");
});

app.get("/REMOTE.bat", (_req, res) => {
  res.type("application/octet-stream");
  res.set("Content-Disposition", 'attachment; filename="REMOTE.bat"');
  res.sendFile(path.join(__dirname, "REMOTE.bat"));
});

server.on("upgrade", (req, socket, head) => {
  if (req.url !== "/ws") {
    socket.destroy();
    return;
  }

  wss.handleUpgrade(req, socket, head, ws => {
    wss.emit("connection", ws);
  });
});

function sameSecret(value) {
  if (typeof value !== "string") return false;
  const a = Buffer.from(value);
  const b = Buffer.from(TOKEN);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

wss.on("connection", ws => {
  let id = null;
  let authenticated = false;

  const timer = setTimeout(() => {
    if (!authenticated) ws.close(4001, "Authentication required");
  }, 10000);

  ws.on("message", raw => {
    if (raw.length > 8192) {
      ws.close(1009, "Message too large");
      return;
    }

    let data;
    try {
      data = JSON.parse(raw.toString());
    } catch {
      ws.close(1007, "Invalid JSON");
      return;
    }

    if (!authenticated) {
      if (
        data.type !== "auth" ||
        !sameSecret(data.token) ||
        typeof data.id !== "string" ||
        !/^[a-zA-Z0-9_-]{1,32}$/.test(data.id)
      ) {
        ws.close(4003, "Authentication refused");
        return;
      }

      id = data.id;
      authenticated = true;
      clearTimeout(timer);

      if (clients.has(id)) {
        clients.get(id).close(4002, "Session replaced");
      }

      clients.set(id, ws);
      ws.send(JSON.stringify({ type: "ready", id }));
      console.log("Connected:", id);
      return;
    }

    if (
      data.type !== "message" ||
      typeof data.to !== "string" ||
      !/^[a-zA-Z0-9_-]{1,32}$/.test(data.to) ||
      typeof data.text !== "string" ||
      !data.text.trim() ||
      data.text.length > 4000
    ) return;

    const recipient = clients.get(data.to);

    if (recipient && recipient.readyState === WebSocket.OPEN) {
      recipient.send(JSON.stringify({
        type: "message",
        from: id,
        text: data.text
      }));
      ws.send(JSON.stringify({ type: "sent", to: data.to }));
    } else {
      ws.send(JSON.stringify({
        type: "error",
        text: "Destinataire non connecte."
      }));
    }
  });

  ws.on("close", () => {
    clearTimeout(timer);
    if (id && clients.get(id) === ws) clients.delete(id);
  });

  ws.on("error", () => {});
});

server.listen(PORT, "0.0.0.0", () => {
  console.log("REMOTE listening on port " + PORT);
});
