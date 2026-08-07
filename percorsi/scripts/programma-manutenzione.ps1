# Registra nell'Utilità di pianificazione le due attività del servizio percorsi.
# Da eseguire una volta sola, in PowerShell come amministratore:
#
#   powershell -ExecutionPolicy Bypass -File .\percorsi\scripts\programma-manutenzione.ps1
#
# La macchina è spenta dalle 02:00 alle 08:00: ogni lavoro programmato sta nella
# finestra di veglia, e l'API riparte da sé dopo l'accensione.
# Vedi ..\..\linee-guida\10-percorsi-e-backend.md, sezione «Manutenzione».

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$radice   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$binario  = Join-Path $radice 'percorsi.exe'
$script   = Join-Path $radice 'scripts\ricostruisci-grafo.sh'
$registri = Join-Path $radice 'log'
$bash     = 'C:\Program Files\Git\bin\bash.exe'

if (-not (Test-Path $binario)) { throw "manca $binario — costruiscilo prima con: go build -o percorsi.exe ." }
if (-not (Test-Path $bash))    { throw "manca $bash — serve Git for Windows per eseguire lo script di ricostruzione" }
New-Item -ItemType Directory -Force -Path $registri | Out-Null

# ---------- 1. L'API riparte da sola dopo l'accensione delle 08:00 ----------

$azioneApi = New-ScheduledTaskAction -Execute $binario -WorkingDirectory $radice
$avvio     = New-ScheduledTaskTrigger -AtStartup
$modo      = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
                                          -StartWhenAvailable -DontStopOnIdleEnd `
                                          -ExecutionTimeLimit ([TimeSpan]::Zero)
$utente    = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName 'Pieno · API percorsi' -Force `
  -Action $azioneApi -Trigger $avvio -Settings $modo -Principal $utente `
  -Description 'API dei percorsi di Pieno. Parte con la macchina e resta su fino allo spegnimento delle 02:00.' | Out-Null
Write-Host "registrata: Pieno · API percorsi (all'avvio)"

# ---------- 2. Ricostruzione mensile del grafo, dentro la finestra di veglia ----------

# La prima domenica del mese alle 09:00: ben lontano dalle 02:00, e con l'intera
# giornata davanti se qualcosa va storto.
$percorsoScript = $script -replace '\\', '/'
$percorsoLog    = $registri -replace '\\', '/'
$comando = "`"$bash`" -lc `"'$percorsoScript' >> '$percorsoLog/ricostruzione-`$(date +%Y-%m-%d).log' 2>&1`""

schtasks /Create /TN 'Pieno · Ricostruzione grafo' /F `
  /SC MONTHLY /MO FIRST /D SUN /ST 09:00 `
  /RU SYSTEM /RL HIGHEST `
  /TR $comando | Out-Null
Write-Host 'registrata: Pieno · Ricostruzione grafo (prima domenica del mese, 09:00)'

Write-Host ''
Write-Host 'Per provarle subito, senza aspettare:'
Write-Host '  Start-ScheduledTask -TaskName "Pieno · API percorsi"'
Write-Host '  Start-ScheduledTask -TaskName "Pieno · Ricostruzione grafo"'
Write-Host ''
Write-Host 'Il motore OSRM riparte da sé: il container ha --restart unless-stopped.'
Write-Host 'Il tunnel (Fase 3) si installa a parte con: cloudflared service install'
