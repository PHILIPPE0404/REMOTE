
@echo off
setlocal
title REMOTE - Client Windows
set "REMOTE_BAT=%~f0"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $lines=Get-Content -LiteralPath $env:REMOTE_BAT | Where-Object { $_.StartsWith('#CS# ') } | ForEach-Object { $_.Substring(5) }; Add-Type -AssemblyName System.Web.Extensions; Add-Type -TypeDefinition ($lines -join [Environment]::NewLine) -Language CSharp; [RemoteClient]::Run()"

if errorlevel 1 (
    echo.
    echo REMOTE a rencontre une erreur.
    pause
)
endlocal
exit /b

#CS# using System;
#CS# using System.Collections.Generic;
#CS# using System.Net.WebSockets;
#CS# using System.Text;
#CS# using System.Threading;
#CS# using System.Threading.Tasks;
#CS# using System.Web.Script.Serialization;
#CS#
#CS# public class RemoteClient
#CS# {
#CS#   static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
#CS#   static ClientWebSocket ws;
#CS#   static string id;
#CS#
#CS#   static async Task Send(object value)
#CS#   {
#CS#     string s = Json.Serialize(value);
#CS#     byte[] b = Encoding.UTF8.GetBytes(s);
#CS#     await ws.SendAsync(new ArraySegment<byte>(b),
#CS#       WebSocketMessageType.Text, true, CancellationToken.None);
#CS#   }
#CS#
#CS#   static async Task Receive()
#CS#   {
#CS#     byte[] buffer = new byte[4096];
#CS#     try
#CS#     {
#CS#       while (ws.State == WebSocketState.Open)
#CS#       {
#CS#         var result = new StringBuilder();
#CS#         WebSocketReceiveResult r;
#CS#         do
#CS#         {
#CS#           r = await ws.ReceiveAsync(new ArraySegment<byte>(buffer),
#CS#             CancellationToken.None);
#CS#           if (r.MessageType == WebSocketMessageType.Close) return;
#CS#           result.Append(Encoding.UTF8.GetString(buffer, 0, r.Count));
#CS#         } while (!r.EndOfMessage);
#CS#
#CS#         var d = Json.Deserialize<Dictionary<string, object>>(result.ToString());
#CS#         string type = d.ContainsKey("type") ? Convert.ToString(d["type"]) : "";
#CS#         if (type == "message")
#CS#           Console.WriteLine("\n[" + d["from"] + "] " + d["text"]);
#CS#         else if (type == "sent")
#CS#           Console.WriteLine("Message envoye a " + d["to"] + ".");
#CS#         else if (type == "error")
#CS#           Console.WriteLine("Erreur : " + d["text"]);
#CS#       }
#CS#     }
#CS#     catch (Exception e)
#CS#     {
#CS#       Console.WriteLine("\nConnexion interrompue : " + e.Message);
#CS#     }
#CS#   }
#CS#
#CS#   public static void Run()
#CS#   {
#CS#     Console.Write("URL Render (https://...): ");
#CS#     string url = Console.ReadLine().Trim().TrimEnd('/');
#CS#     if (!url.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
#CS#       throw new Exception("L'URL doit commencer par https://");
#CS#
#CS#     Console.Write("Nom de cette machine (PC1) : ");
#CS#     id = Console.ReadLine().Trim();
#CS#     if (!System.Text.RegularExpressions.Regex.IsMatch(id, @"^[a-zA-Z0-9_-]{1,32}$"))
#CS#       throw new Exception("Nom de machine invalide.");
#CS#
#CS#     Console.Write("Secret REMOTE_TOKEN : ");
#CS#     string token = Console.ReadLine();
#CS#     if (String.IsNullOrWhiteSpace(token))
#CS#       throw new Exception("Secret vide.");
#CS#
#CS#     Uri uri = new Uri(url);
#CS#     if (uri.Scheme != "https" || uri.AbsolutePath != "/" || !String.IsNullOrEmpty(uri.Query))
#CS#       throw new Exception("Entre uniquement l'URL de base de Render.");
#CS#
#CS#     ws = new ClientWebSocket();
#CS#     ws.ConnectAsync(new UriBuilder(uri) {
#CS#       Scheme = "wss", Path = "/ws"
#CS#     }.Uri, CancellationToken.None).GetAwaiter().GetResult();
#CS#
#CS#     Send(new Dictionary<string, object> {
#CS#       { "type", "auth" }, { "id", id }, { "token", token }
#CS#     }).GetAwaiter().GetResult();
#CS#
#CS#     Console.WriteLine("Connecte. Attente de confirmation du serveur...");
#CS#     Task receiver = Receive();
#CS#
#CS#     while (ws.State == WebSocketState.Open)
#CS#     {
#CS#       string line = Console.ReadLine();
#CS#       if (line == null || line.Trim() == "/quit") break;
#CS#       var match = System.Text.RegularExpressions.Regex.Match(
#CS#         line, @"^/to\s+([a-zA-Z0-9_-]{1,32})\s+(.+)$");
#CS#       if (!match.Success)
#CS#       {
#CS#         Console.WriteLine("Usage : /to PC2 Bonjour !");
#CS#         continue;
#CS#       }
#CS#       Send(new Dictionary<string, object> {
#CS#         { "type", "message" }, { "to", match.Groups[1].Value },
#CS#         { "text", match.Groups[2].Value }
#CS#       }).GetAwaiter().GetResult();
#CS#     }
#CS#
#CS#     ws.Dispose();
#CS#     receiver.GetAwaiter().GetResult();
#CS#   }
#CS# }
