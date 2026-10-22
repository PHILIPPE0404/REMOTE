
@echo off
setlocal
title REMOTE - Chat
set "REMOTE_BAT=%~f0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s=Get-Content -LiteralPath $env:REMOTE_BAT | Where-Object { $_.StartsWith('#CS# ') } | ForEach-Object { $_.Substring(5) }; Add-Type -ReferencedAssemblies System.Runtime.Serialization.dll -TypeDefinition ($s -join [Environment]::NewLine); [RemoteChat]::Run()"

if errorlevel 1 pause
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
#CS#   static byte[] Encode(ChatPacket p) {
#CS#     var s = new DataContractJsonSerializer(typeof(ChatPacket));
#CS#     using (var m = new MemoryStream()) {
#CS#       s.WriteObject(m, p);
#CS#       return m.ToArray();
#CS#     }
#CS#   }
#CS#   static ChatPacket Decode(byte[] b) {
#CS#     var s = new DataContractJsonSerializer(typeof(ChatPacket));
#CS#     using (var m = new MemoryStream(b)) return (ChatPacket)s.ReadObject(m);
#CS#   }
#CS#   static void Send(ChatPacket p) {
#CS#     byte[] b = Encode(p);
#CS#     ws.SendAsync(new ArraySegment<byte>(b), WebSocketMessageType.Text,
#CS#       true, CancellationToken.None).GetAwaiter().GetResult();
#CS#   }
#CS#   static async Task Receive() {
#CS#     var buf = new byte[4096];
#CS#     while (ws.State == WebSocketState.Open) {
#CS#       try {
#CS#         using (var m = new MemoryStream()) {
#CS#           WebSocketReceiveResult r;
#CS#           do {
#CS#             r = await ws.ReceiveAsync(new ArraySegment<byte>(buf), CancellationToken.None);
#CS#             if (r.MessageType == WebSocketMessageType.Close) return;
#CS#             m.Write(buf, 0, r.Count);
#CS#           } while (!r.EndOfMessage);
#CS#           var p = Decode(m.ToArray());
#CS#           if (p.type == "message")
#CS#             Console.WriteLine("\n[" + p.from + "] " + p.text);
#CS#         }
#CS#       } catch { Console.WriteLine("\nConnexion interrompue."); return; }
#CS#     }
#CS#   }
#CS#   public static void Run() {
#CS#     string id = "PC-" + Guid.NewGuid().ToString("N").Substring(0, 6).ToUpperInvariant();
#CS#     Console.WriteLine("REMOTE - Salon commun");
#CS#     Console.WriteLine("Ton nom : " + id);
#CS#     ws = new ClientWebSocket();
#CS#     ws.ConnectAsync(new Uri("wss://remote-ppij.onrender.com/ws"),
#CS#       CancellationToken.None).GetAwaiter().GetResult();
#CS#     Send(new ChatPacket { type="join", id=id });
#CS#     Console.WriteLine("Connecte au salon ! Les messages de tous les clients apparaitront ici.");
#CS#     Console.WriteLine("Tape ton message puis Entree. /quit pour quitter.");
#CS#     var receiver = Task.Run((Action)(() => Receive().GetAwaiter().GetResult()));
#CS#     while (ws.State == WebSocketState.Open) {
#CS#       string line = Console.ReadLine();
#CS#       if (line == null || line.Trim() == "/quit") break;
#CS#       if (line.Trim().Length == 0) continue;
#CS#       Send(new ChatPacket { type="message", text=line.Trim() });
#CS#     }
#CS#     ws.Dispose();
#CS#   }
#CS# }
