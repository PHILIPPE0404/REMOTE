
@echo off
setlocal
title REMOTE - Client
set "REMOTE_BAT=%~f0"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p=Join-Path $env:TEMP 'REMOTE-runtime.ps1'; Get-Content -LiteralPath $env:REMOTE_BAT | Where-Object { $_.StartsWith('#PS# ') } | ForEach-Object { $_.Substring(5) } | Set-Content -LiteralPath $p -Encoding UTF8; & $p; $c=$LASTEXITCODE; Remove-Item $p -Force -ErrorAction SilentlyContinue; exit $c"

if errorlevel 1 (
    echo.
    echo REMOTE a rencontre une erreur.
    pause
)
endlocal
exit /b

#PS# $ErrorActionPreference = 'Stop'
#PS# Add-Type -AssemblyName System.Runtime.Serialization
#PS# 
#PS# function ConvertTo-JsonBytes($obj, [type]$type) {
#PS#     $serializer = New-Object System.Runtime.Serialization.Json.DataContractJsonSerializer($type)
#PS#     $stream = New-Object System.IO.MemoryStream
#PS#     $serializer.WriteObject($stream, $obj)
#PS#     $bytes = $stream.ToArray()
#PS#     $stream.Dispose()
#PS#     return ,$bytes
#PS# }
#PS# 
#PS# function ConvertFrom-JsonBytes([byte[]]$bytes, [type]$type) {
#PS#     $serializer = New-Object System.Runtime.Serialization.Json.DataContractJsonSerializer($type)
#PS#     $stream = New-Object System.IO.MemoryStream(, $bytes)
#PS#     try { return $serializer.ReadObject($stream) }
#PS#     finally { $stream.Dispose() }
#PS# }
#PS# 
#PS# $source = @'
#PS# using System.Runtime.Serialization;
#PS# [DataContract]
#PS# public class RemoteAuth {
#PS#   [DataMember(Name="type")] public string type {get;set;}
#PS#   [DataMember(Name="id")] public string id {get;set;}
#PS#   [DataMember(Name="token")] public string token {get;set;}
#PS# }
#PS# [DataContract]
#PS# public class RemoteMessage {
#PS#   [DataMember(Name="type")] public string type {get;set;}
#PS#   [DataMember(Name="to", EmitDefaultValue=false)] public string to {get;set;}
#PS#   [DataMember(Name="text", EmitDefaultValue=false)] public string text {get;set;}
#PS# }
#PS# [DataContract]
#PS# public class RemoteResponse {
#PS#   [DataMember(Name="type")] public string type {get;set;}
#PS#   [DataMember(Name="id", EmitDefaultValue=false)] public string id {get;set;}
#PS#   [DataMember(Name="from", EmitDefaultValue=false)] public string from {get;set;}
#PS#   [DataMember(Name="to", EmitDefaultValue=false)] public string to {get;set;}
#PS#   [DataMember(Name="text", EmitDefaultValue=false)] public string text {get;set;}
#PS# }
#PS# '@
#PS# Add-Type -TypeDefinition $source -ReferencedAssemblies System.Runtime.Serialization.dll
#PS# 
#PS# try {
#PS#     $url = (Read-Host 'URL Render (https://remote-ppij.onrender.com)').Trim().TrimEnd('/')
#PS#     if ($url -notmatch '^https://[a-zA-Z0-9.-]+$') { throw 'URL HTTPS invalide.' }
#PS# 
#PS#     $id = (Read-Host 'Nom de cette machine (PC1 ou PC2)').Trim()
#PS#     if ($id -notmatch '^[a-zA-Z0-9_-]{1,32}$') { throw 'Nom invalide.' }
#PS# 
#PS#     $token = Read-Host 'Secret REMOTE_TOKEN'
#PS#     if ([string]::IsNullOrWhiteSpace($token)) { throw 'Secret vide.' }
#PS# 
#PS#     $ws = New-Object System.Net.WebSockets.ClientWebSocket
#PS#     $uri = [Uri]($url -replace '^https:', 'wss:' )
#PS#     $uri = New-Object UriBuilder($uri)
#PS#     $uri.Path = '/ws'
#PS#     $ws.ConnectAsync($uri.Uri, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
#PS# 
#PS#     $auth = New-Object RemoteAuth
#PS#     $auth.type = 'auth'; $auth.id = $id; $auth.token = $token
#PS#     $bytes = ConvertTo-JsonBytes $auth ([RemoteAuth])
#PS#     $ws.SendAsync([ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
#PS# 
#PS#     Write-Host 'Connexion en cours...' -ForegroundColor Cyan
#PS#     $buffer = New-Object byte[] 8192
#PS#     $result = $ws.ReceiveAsync([ArraySegment[byte]]::new($buffer), [Threading.CancellationToken]::None).GetAwaiter().GetResult()
#PS#     $first = New-Object byte[] $result.Count
#PS#     [Array]::Copy($buffer, $first, $result.Count)
#PS#     $response = ConvertFrom-JsonBytes $first ([RemoteResponse])
#PS#     if ($response.type -ne 'ready') { throw 'Authentification refusee par le serveur.' }
#PS# 
#PS#     Write-Host "REMOTE connecte sous $id" -ForegroundColor Green
#PS#     Write-Host 'Envoi : /to PC2 Bonjour !'
#PS#     Write-Host 'Quitter : /quit'
#PS# 
#PS#     $receiveTask = [System.Threading.Tasks.Task]::Run([Action]{
#PS#         while ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
#PS#             try {
#PS#                 $buf = New-Object byte[] 8192
#PS#                 $ms = New-Object System.IO.MemoryStream
#PS#                 do {
#PS#                     $r = $ws.ReceiveAsync([ArraySegment[byte]]::new($buf), [Threading.CancellationToken]::None).GetAwaiter().GetResult()
#PS#                     if ($r.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { return }
#PS#                     $ms.Write($buf, 0, $r.Count)
#PS#                 } while (-not $r.EndOfMessage)
#PS#                 $bytes = $ms.ToArray(); $ms.Dispose()
#PS#                 $msg = ConvertFrom-JsonBytes $bytes ([RemoteResponse])
#PS#                 if ($msg.type -eq 'message') { [Console]::WriteLine("`n[$($msg.from)] $($msg.text)") }
#PS#                 elseif ($msg.type -eq 'sent') { [Console]::WriteLine("Message envoye a $($msg.to).") }
#PS#                 elseif ($msg.type -eq 'error') { [Console]::WriteLine("Erreur : $($msg.text)") }
#PS#             } catch { return }
#PS#         }
#PS#     })
#PS# 
#PS#     while ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
#PS#         $line = [Console]::ReadLine()
#PS#         if ($null -eq $line -or $line.Trim() -eq '/quit') { break }
#PS#         if ($line -notmatch '^/to\s+([a-zA-Z0-9_-]{1,32})\s+(.+)$') {
#PS#             Write-Host 'Format : /to PC2 Bonjour !'; continue
#PS#         }
#PS#         $msg = New-Object RemoteMessage
#PS#         $msg.type = 'message'; $msg.to = $Matches[1]; $msg.text = $Matches[2]
#PS#         $bytes = ConvertTo-JsonBytes $msg ([RemoteMessage])
#PS#         $ws.SendAsync([ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
#PS#     }
#PS#     $ws.Dispose()
#PS# } catch {
#PS#     Write-Host "Erreur REMOTE : $($_.Exception.Message)" -ForegroundColor Red
#PS#     exit 1
#PS# }
