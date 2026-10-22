
@echo off
setlocal
title REMOTE - Chat
set "REMOTE_BAT=%~f0"
set "REMOTE_MODE=%~1"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$s=Get-Content -LiteralPath $env:REMOTE_BAT | Where-Object { $_.StartsWith('REM PS ') } | ForEach-Object { $_.Substring(7) }; if(-not $s){Write-Host 'Code REMOTE introuvable.'; pause; exit 2}; Invoke-Expression ($s -join [Environment]::NewLine)"

if errorlevel 1 (
  echo.
  echo REMOTE a rencontre une erreur.
  pause
)
exit /b

REM PS $ErrorActionPreference = 'Stop'
REM PS $base = 'https://remote-ppij.onrender.com'
REM PS
REM PS function ApiPost($route, $data) {
REM PS   $json = ConvertTo-Json -InputObject $data -Compress
REM PS   Invoke-RestMethod -Uri ($base + $route) -Method Post -ContentType 'application/json' -Body $json
REM PS }
REM PS
REM PS try {
REM PS   $name = 'PC-' + ([Guid]::NewGuid().ToString('N').Substring(0,6).ToUpper())
REM PS   Clear-Host
REM PS   Write-Host '===================================='
REM PS   Write-Host '             REMOTE CHAT'
REM PS   Write-Host '===================================='
REM PS   Write-Host ('Ton nom : ' + $name)
REM PS   Write-Host 'Connexion au serveur...'
REM PS
REM PS   $joined = ApiPost '/api/join' @{ name = $name }
REM PS   $token = $joined.session
REM PS   $cursor = [long]$joined.cursor
REM PS   $isAdmin = $false
REM PS
REM PS   if ($env:REMOTE_MODE -eq '/admin') {
REM PS     $password = Read-Host 'Mot de passe administrateur'
REM PS     $login = ApiPost '/api/admin/login' @{ session = $token; password = $password }
REM PS     if (-not $login.admin) { throw 'Connexion administrateur refusee.' }
REM PS     $isAdmin = $true
REM PS     Write-Host 'Mode administrateur active.'
REM PS   }
REM PS
REM PS   Write-Host ''
REM PS   Write-Host 'Connecte au salon.'
REM PS   Write-Host 'Entree = envoyer | /quit = quitter'
REM PS   if ($isAdmin) { Write-Host 'Mode admin : liste des utilisateurs activee.' }
REM PS   Write-Host ''
REM PS
REM PS   $line = ''
REM PS   $lastUsers = ''
REM PS   $lastPoll = [DateTime]::MinValue
REM PS
REM PS   while ($true) {
REM PS     while ([Console]::KeyAvailable) {
REM PS       $key = [Console]::ReadKey($true)
REM PS       if ($key.Key -eq 'Enter') {
REM PS         Write-Host ''
REM PS         $text = $line.Trim()
REM PS         $line = ''
REM PS         if ($text -eq '/quit') { break }
REM PS         if ($text.Length -gt 0) {
REM PS           $null = ApiPost '/api/send' @{ session = $token; text = $text }
REM PS         }
REM PS       } elseif ($key.Key -eq 'Backspace') {
REM PS         if ($line.Length -gt 0) {
REM PS           $line = $line.Substring(0, $line.Length - 1)
REM PS           Write-Host "`b `b" -NoNewline
REM PS         }
REM PS       } elseif (-not [char]::IsControl($key.KeyChar)) {
REM PS         $line += $key.KeyChar
REM PS         Write-Host $key.KeyChar -NoNewline
REM PS       }
REM PS     }
REM PS
REM PS     if ($text -eq '/quit') { break }
REM PS
REM PS     if (([DateTime]::UtcNow - $lastPoll).TotalMilliseconds -ge 1000) {
REM PS       $url = $base + '/api/poll?session=' + $token + '&since=' + $cursor
REM PS       $data = Invoke-RestMethod -Uri $url -Method Get
REM PS
REM PS       foreach ($message in $data.messages) {
REM PS         Write-Host ''
REM PS         Write-Host ('[' + $message.from + '] ' + $message.text)
REM PS         if ($line.Length -gt 0) {
REM PS           Write-Host ('> ' + $line) -NoNewline
REM PS         }
REM PS       }
REM PS
REM PS       $cursor = [long]$data.next
REM PS
REM PS       if ($isAdmin) {
REM PS         $names = @($data.users | ForEach-Object { $_.name + $(if ($_.admin) { ' (admin)' } else { '' }) })
REM PS         $signature = $names -join ', '
REM PS         if ($signature -ne $lastUsers) {
REM PS           Write-Host ''
REM PS           Write-Host ('--- Utilisateurs connectes (' + $names.Count + ') ---')
REM PS           if ($names.Count -eq 0) { Write-Host 'Aucun utilisateur.' }
REM PS           else { foreach ($n in $names) { Write-Host (' - ' + $n) } }
REM PS           Write-Host '--------------------------------------'
REM PS           $lastUsers = $signature
REM PS           if ($line.Length -gt 0) { Write-Host ('> ' + $line) -NoNewline }
REM PS         }
REM PS       }
REM PS       $lastPoll = [DateTime]::UtcNow
REM PS     }
REM PS     Start-Sleep -Milliseconds 150
REM PS   }
REM PS
REM PS   try { $null = ApiPost '/api/leave' @{ session = $token } } catch {}
REM PS   Write-Host ''
REM PS   Write-Host 'Deconnecte.'
REM PS } catch {
REM PS   Write-Host ''
REM PS   Write-Host ('Erreur REMOTE : ' + $_.Exception.Message)
REM PS   Write-Host 'Verifie Render, le mot de passe admin et PowerShell.'
REM PS }
REM PS Read-Host 'Appuie sur Entree pour fermer'
