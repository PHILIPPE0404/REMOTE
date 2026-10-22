
@echo off
setlocal
title REMOTE - Chat
set "REMOTE_BAT=%~f0"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$s=Get-Content -LiteralPath $env:REMOTE_BAT | Where-Object { $_.StartsWith('#CS# ') } | ForEach-Object { $_.Substring(5) }; if (-not $s) { Write-Host 'Erreur : code interne introuvable.'; exit 2 }; Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll','System.Xml.dll','System.Runtime.Serialization.dll') -TypeDefinition ($s -join [Environment]::NewLine); [RemoteChat]::Run()"

if errorlevel 1 (
  echo.
  echo REMOTE a rencontre une erreur.
  pause
)
exit /b

#CS# using System;
#CS# using System.IO;
#CS# using System.Text;
#CS# using System.Net.WebSockets;
#CS# using System.Runtime.Serialization;
#CS# using System.Runtime.Serialization.Json;
#CS# using System.Threading;
#CS# using System.Threading.Tasks;
#CS#
#CS# [DataContract]
#CS# public class ChatPacket {
#CS#   [DataMember(Name="type")] public string type {get;set;}
#CS#   [DataMember(Name="id", EmitDefaultValue=false)] public string id {get;set;}
#CS#   [DataMember(Name="from", EmitDefaultValue=false)] public string from {get;set;}
#CS#   [DataMember(Name="text", EmitDefaultValue=false)] public string text {get;set;}
#CS# }
#CS#
#CS# public class RemoteChat {
#CS#   static ClientWebSocket ws;
#CS#   static readonly object sendLock = new object();
#CS#
#CS#   static byte[] Encode(ChatPacket p) {
#CS#     var serializer = new DataContractJsonSerializer(typeof(ChatPacket));
#CS#     using (var ms = new MemoryStream()) {
#CS#       serializer.WriteObject(ms, p);
#CS#       return ms.ToArray();
#CS#     }
#CS#   }
#CS#
#CS#   static ChatPacket Decode(byte[] b) {
#CS#     var serializer = new DataContractJsonSerializer(typeof(ChatPacket));
#CS#     using (var ms = new MemoryStream(b))
#CS#       return (ChatPacket)serializer.ReadObject(ms);
#CS#   }
#CS#
#CS#   static void Send(ChatPacket p) {
#CS#     byte[] bytes = Encode(p);
#CS#     lock (sendLock) {
#CS#       ws.SendAsync(new ArraySegment<byte>(bytes),
#CS#         WebSocketMessageType.Text, true, CancellationToken.None)
#CS#         .GetAwaiter().GetResult();
#CS#     }
#CS#   }
#CS#
#CS#   static async Task Receive() {
#CS#     byte[] buffer = new byte[4096];
#CS#     try {
#CS#       while (ws.State == WebSocketState.Open) {
#CS#         using (var ms = new MemoryStream()) {
#CS#           WebSocketReceiveResult result;
#CS#           do {
#CS#             result = await ws.ReceiveAsync(
#CS#               new ArraySegment<byte>(buffer), CancellationToken.None);
#CS#             if (result.MessageType == WebSocketMessageType.Close)
#CS#               return;
#CS#             ms.Write(buffer, 0, result.Count);
#CS#             if (ms.Length > 8192) return;
#CS#           } while (!result.EndOfMessage);
#CS#
#CS#           ChatPacket p = Decode(ms.ToArray());
#CS#           if (p.type == "message")
#CS#             Console.WriteLine("\n[" + p.from + "] " + p.text);
#CS#         }
#CS#       }
#CS#     } catch (Exception ex) {
#CS#       Console.WriteLine("\nConnexion interrompue : " + ex.Message);
#CS#     }
#CS#   }
#CS#
#CS#   public static void Run() {
#CS#     string id = "PC-" +
#CS#       Guid.NewGuid().ToString("N").Substring(0, 6).ToUpperInvariant();
#CS#     ws = new ClientWebSocket();
#CS#     try {
#CS#       Console.WriteLine("REMOTE - Salon commun");
#CS#       Console.WriteLine("Nom : " + id);
#CS#       Console.WriteLine("Connexion au serveur...");
#CS#
#CS#       ws.ConnectAsync(
#CS#         new Uri("wss://remote-ppij.onrender.com/ws"),
#CS#         CancellationToken.None).GetAwaiter().GetResult();
#CS#
#CS#       Send(new ChatPacket { type = "join", id = id });
#CS#       Console.WriteLine("Connecte. Tu peux discuter avec les autres.");
#CS#       Console.WriteLine("Tape un message puis Entree. /quit pour quitter.");
#CS#
#CS#       Task receiver = Task.Run(async () => await Receive());
#CS#       while (ws.State == WebSocketState.Open) {
#CS#         string line = Console.ReadLine();
#CS#         if (line == null || line.Trim() == "/quit") break;
#CS#         if (line.Trim().Length == 0) continue;
#CS#         Send(new ChatPacket { type = "message", text = line.Trim() });
#CS#       }
#CS#     } catch (Exception ex) {
#CS#       Console.WriteLine("Erreur : " + ex.Message);
#CS#       Console.WriteLine("Verifie le serveur Render et ta connexion Internet.");
#CS#     } finally {
#CS#       try {
#CS#         if (ws.State == WebSocketState.Open)
#CS#           ws.CloseAsync(WebSocketCloseStatus.NormalClosure,
#CS#             "Fermeture", CancellationToken.None)
#CS#             .GetAwaiter().GetResult();
#CS#       } catch {}
#CS#       ws.Dispose();
#CS#       Console.WriteLine("REMOTE ferme.");
#CS#     }
#CS#   }
#CS# }
