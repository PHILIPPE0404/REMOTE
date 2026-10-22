
const express = require("express");
const http = require("http");
const path = require("path");
const WebSocket = require("ws");

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ noServer: true });
const clients = new Map();
const PORT = process.env.PORT || 10000;

app.get("/", (_req, res) => res.send("REMOTE chat is online."));

app.get("/REMOTE.bat", (_req, res) => {
  res.type("application/octet-stream");
  res.set("Content-Disposition", 'attachment; filename="REMOTE.bat"');
  res.sendFile(path.join(__dirname, "REMOTE.bat"));
});

server.on("upgrade", (req, socket, head) => {
  if (req.url !== "/ws") return socket.destroy();
  wss.handleUpgrade(req, socket, head, ws => wss.emit("connection", ws));
});

wss.on("connection", ws => {
  let id = null;

  ws.on("message", raw => {
    if (raw.length > 4096) return ws.close();

    let data;
    try {
      data = JSON.parse(raw.toString());
    } catch {
      return;
    }

    if (!id) {
      if (data.type !== "join" ||
          typeof data.id !== "string" ||
          !/^[A-Za-z0-9_-]{1,32}$/.test(data.id)) {
        return ws.close();
      }

      id = data.id;
      clients.set(id, ws);
      ws.send(JSON.stringify({ type: "ready", id }));

      const notice = JSON.stringify({
        type: "message",
        from: "REMOTE",
        text: id + " a rejoint le salon."
      });

      for (const [otherId, client] of clients) {
        if (otherId !== id && client.readyState === WebSocket.OPEN) {
          client.send(notice);
        }
      }
      console.log("Salon :", id);
      return;
    }

    if (data.type !== "message" ||
        typeof data.text !== "string" ||
        !data.text.trim() ||
        data.text.length > 2000) return;

    const message = JSON.stringify({
      type: "message",
      from: id,
      text: data.text.trim().slice(0, 2000)
    });

    for (const client of clients.values()) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    }
  });

  ws.on("close", () => {
    if (id && clients.get(id) === ws) {
      clients.delete(id);
      const notice = JSON.stringify({
        type: "message",
        from: "REMOTE",
        text: id + " a quitte le salon."
      });
      for (const client of clients.values()) {
        if (client.readyState === WebSocket.OPEN) client.send(notice);
      }
    }
  });

  ws.on("error", () => {});
});

server.listen(PORT, "0.0.0.0", () =>
  console.log("REMOTE chat listening on " + PORT)
);
