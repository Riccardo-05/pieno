#!/usr/bin/env bash
# Ricostruzione mensile del grafo OSRM, con scambio atomico.
#
# Si costruisce il nuovo grafo mentre il vecchio serve le richieste, si verifica
# che risponda, e solo allora l'API cambia motore. Se qualcosa va storto, resta
# in piedi quello buono: è lo stesso principio della pubblicazione atomica della
# pipeline dati.
#
# Va eseguito DENTRO la finestra di veglia (la macchina è spenta 02:00–08:00).
# Vedi ../../linee-guida/10-percorsi-e-backend.md, sezione «Manutenzione».

set -euo pipefail
export MSYS_NO_PATHCONV=1 # Git Bash non deve tradurre /data in un percorso Windows

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMMAGINE="ghcr.io/project-osrm/osrm-backend:latest"
# Sovrascrivibile dall'ambiente: serve a provare che una sorgente rotta lasci in
# piedi il grafo vecchio, senza dover aspettare i due giga dell'estratto vero.
ESTRATTO="${ESTRATTO:-https://download.geofabrik.de/europe/italy-latest.osm.pbf}"
CONTENITORE="pieno-osrm"
PORTA_PROVA=5001
STATO="$QUI/.grafo-attivo"

dire() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
morire() { dire "INTERROTTO: $*"; exit 1; }

# ---------- 1. quale volume è vivo, e quale si può ricostruire ----------

# Lo stato tiene il nome del volume vivo. Alla prima esecuzione non c'è, e vale
# «pieno-osrm»: è il volume costruito a mano nella Fase 1.
attivo="$(cat "$STATO" 2>/dev/null || echo pieno-osrm)"
case "$attivo" in
  pieno-osrm-a) volume=pieno-osrm-b ;;
  *)            volume=pieno-osrm-a ;;
esac
dire "grafo vivo: $attivo. Si costruisce su $volume."

# Il volume di destinazione riparte pulito: un residuo di una build fallita
# darebbe un grafo mezzo vecchio e mezzo nuovo.
docker volume rm "$volume" >/dev/null 2>&1 || true
docker volume create "$volume" >/dev/null

# ---------- 2. scarico verificato ----------

dire "scarico dell'estratto italiano"
docker run --rm -v "$volume:/data" alpine:3 sh -c '
  set -e
  apk add --no-cache wget >/dev/null 2>&1
  cd /data
  wget -q -O italy-latest.osm.pbf "'"$ESTRATTO"'"
  wget -q -O italy-latest.osm.pbf.md5 "'"$ESTRATTO"'.md5"
  md5sum -c italy-latest.osm.pbf.md5
' || morire "scarico o md5 falliti — resta in piedi il grafo «$attivo»"

# ---------- 3. costruzione ----------

dire "costruzione del grafo (extract, partition, customize) — una decina di minuti"
docker run --rm -v "$volume:/data" "$IMMAGINE" sh -c '
  set -e
  osrm-extract -p /opt/car.lua -t 8 /data/italy-latest.osm.pbf
  osrm-partition /data/italy-latest.osrm
  osrm-customize /data/italy-latest.osrm
  echo "italy-latest · $(date -u +%Y-%m-%d) · MLD · profilo car" > /data/versione-grafo.txt
' || morire "costruzione fallita — resta in piedi il grafo «$attivo»"

# ---------- 4. verifica prima dello scambio ----------

dire "verifica del grafo nuovo su porta $PORTA_PROVA"
docker rm -f pieno-osrm-prova >/dev/null 2>&1 || true
docker run -d --name pieno-osrm-prova \
  -v "$volume:/data" -p "127.0.0.1:$PORTA_PROVA:5000" "$IMMAGINE" \
  osrm-routed --algorithm mld --max-table-size 1000 /data/italy-latest.osrm >/dev/null

verificato=no
for _ in $(seq 1 30); do
  sleep 4
  risposta="$(curl -s "http://127.0.0.1:$PORTA_PROVA/route/v1/driving/9.190000,45.464000;9.227000,45.478000" || true)"
  case "$risposta" in *'"code":"Ok"'*) verificato=si; break ;; esac
done
docker rm -f pieno-osrm-prova >/dev/null 2>&1 || true
[ "$verificato" = si ] || morire "il grafo nuovo non risponde — resta in piedi il grafo «$attivo»"
dire "il grafo nuovo risponde: si scambia"

# ---------- 5. scambio ----------

docker rm -f "$CONTENITORE" >/dev/null 2>&1 || true
docker run -d --name "$CONTENITORE" --restart unless-stopped \
  -v "$volume:/data" -p 127.0.0.1:5000:5000 "$IMMAGINE" \
  osrm-routed --algorithm mld --max-table-size 1000 --max-matching-size 100 /data/italy-latest.osrm >/dev/null

echo -n "$volume" > "$STATO"
docker run --rm -v "$volume:/data" alpine:3 cat /data/versione-grafo.txt > "$QUI/versione-grafo.txt"
dire "fatto. Grafo attivo: $volume — $(cat "$QUI/versione-grafo.txt")"

# Il volume precedente resta dov'è: è il ritorno indietro se qualcosa emerge
# solo con l'uso. Lo cancella la ricostruzione successiva.
dire "il grafo $attivo resta sul disco come ritorno indietro"
