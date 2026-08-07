# Registra nell'Utilita' di pianificazione le due attivita' del servizio percorsi.
# Da eseguire una volta sola, in PowerShell come amministratore:
#
#   powershell -ExecutionPolicy Bypass -File .\percorsi\scripts\programma-manutenzione.ps1
#
# La macchina e' spenta dalle 02:00 alle 08:00: ogni lavoro programmato sta nella
# finestra di veglia, e l'API riparte da se' dopo l'accensione.
# Vedi ..\..\linee-guida\10-percorsi-e-backend.md, sezione "Manutenzione".
#
# NOTA: questo file e' scritto in solo ASCII. Windows PowerShell 5.1 legge gli
# script come cp1252 quando manca il BOM, e le lettere accentate diventano
# sequenze che il parser scambia per virgolette. Con l'ASCII il problema non
# puo' presentarsi, su nessuna macchina e con nessun editor.

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$radice   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$binario  = Join-Path $radice 'percorsi.exe'
$script   = Join-Path $radice 'scripts\ricostruisci-grafo.sh'
$registri = Join-Path $radice 'log'
$bash     = 'C:\Program Files\Git\bin\bash.exe'

if (-not (Test-Path $binario)) {
    throw "manca $binario - costruiscilo prima con: go build -o percorsi.exe ."
}
if (-not (Test-Path $script)) {
    throw "manca $script"
}
if (-not (Test-Path $bash)) {
    throw "manca $bash - serve Git for Windows per eseguire lo script di ricostruzione"
}
New-Item -ItemType Directory -Force -Path $registri | Out-Null

$utente = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

# ---------- 1. L'API riparte da sola dopo l'accensione delle 08:00 ----------

$modoApi = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
                                        -StartWhenAvailable -DontStopOnIdleEnd `
                                        -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask -TaskName 'Pieno - API percorsi' -Force `
  -Action (New-ScheduledTaskAction -Execute $binario -WorkingDirectory $radice) `
  -Trigger (New-ScheduledTaskTrigger -AtStartup) `
  -Settings $modoApi -Principal $utente `
  -Description 'API dei percorsi di Pieno. Parte con la macchina e resta su fino allo spegnimento delle 02:00.' | Out-Null
Write-Host "registrata: Pieno - API percorsi (all'avvio)"

# ---------- 2. Ricostruzione mensile del grafo, dentro la finestra di veglia ----------

# Domenica alle 09:00 ogni quattro settimane: ben lontano dalle 02:00, e con
# l'intera giornata davanti se qualcosa va storto.
#
# Lo script scrive da se' il proprio registro in percorsi\log\, quindi qui non
# servono redirezioni: l'attivita' lo lancia e basta. Le virgolette annidate in
# una riga di comando di Windows sono il modo piu' rapido di rompere tutto.
# C:\una\cartella  ->  /c/una/cartella
# Si usa .Replace() e non -replace: il secondo e' una regex, e una barra
# rovesciata dentro una regex e' una fonte di errori silenziosi.
$percorsoBash = '/' + $script.Replace(':', '').Replace('\', '/')
$percorsoBash = $percorsoBash.Substring(0, 2).ToLower() + $percorsoBash.Substring(2)

$modoGrafo = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd `
                                          -ExecutionTimeLimit (New-TimeSpan -Hours 4)

Register-ScheduledTask -TaskName 'Pieno - Ricostruzione grafo' -Force `
  -Action (New-ScheduledTaskAction -Execute $bash -Argument "-lc `"$percorsoBash`"" -WorkingDirectory $radice) `
  -Trigger (New-ScheduledTaskTrigger -Weekly -WeeksInterval 4 -DaysOfWeek Sunday -At '09:00') `
  -Settings $modoGrafo -Principal $utente `
  -Description 'Ricostruzione del grafo OSRM con scambio atomico. Dentro la finestra di veglia, mai a cavallo delle 02:00.' | Out-Null
Write-Host 'registrata: Pieno - Ricostruzione grafo (domenica 09:00, ogni 4 settimane)'

Write-Host ''
Write-Host 'Verifica:'
Write-Host '  Get-ScheduledTask -TaskName "Pieno*" | Format-Table TaskName, State'
Write-Host ''
Write-Host 'Per provarle subito, senza aspettare:'
Write-Host '  Start-ScheduledTask -TaskName "Pieno - API percorsi"'
Write-Host ''
Write-Host 'Il motore OSRM riparte da se: il container ha --restart unless-stopped,'
Write-Host 'ma Docker Desktop parte al login, non all avvio: serve il login automatico.'
Write-Host 'Il tunnel (Fase 3) si installa a parte con: cloudflared service install'
