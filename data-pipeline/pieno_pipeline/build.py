"""Generazione dei file statici per provincia, compatti e versionati, e pubblicazione atomica.

- Un file JSON compatto per provincia (chiavi corte, lette dall'app).
- Un manifest con versione e sha256 per file: l'app riscarica solo ciò che cambia.
- Pubblicazione atomica: si costruisce in staging e si scambia solo a build completo.
"""
from __future__ import annotations

import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List

from .config import Config
from .model import Impianto

ATTRIBUZIONE = (
    "Dati: Ministero delle Imprese e del Made in Italy — IODL 2.0. "
    "© OpenStreetMap contributors."
)


def _fuso_italiano():
    """Il fuso in cui il Ministero scrive le sue date. None se il sistema non ha il
    database dei fusi (Windows senza `tzdata`): in quel caso si resta come prima."""
    try:
        from zoneinfo import ZoneInfo

        return ZoneInfo("Europe/Rome")
    except Exception:  # noqa: BLE001 - fuso non disponibile
        return None


def _iso(dt) -> str | None:
    """Data in ISO-8601 **con l'offset**.

    Le date dei CSV ministeriali sono ore italiane senza fuso. Scriverle così com'erano
    voleva dire che il telefono le rileggeva come ora *sua*: l'età del dato tornava
    giusta per caso in Italia d'inverno, sbagliata di un'ora d'estate e di più per chi
    è all'estero. Un istante scritto senza fuso non è un istante, è un numero.
    """
    if not dt:
        return None
    if dt.tzinfo is None:
        fuso = _fuso_italiano()
        if fuso is not None:
            dt = dt.replace(tzinfo=fuso)
    return dt.isoformat()


def carica_fattori(percorso) -> Dict[str, float]:
    """Fattori stradali per impianto, prodotti dal servizio percorsi.

    Il file lo genera `percorsi/cmd/fattori` una volta al mese sul mini PC
    (linee-guida/10-percorsi-e-backend.md, Fase 5). È **facoltativo**: se manca o è
    illeggibile la build prosegue senza, e l'app resta alla linea d'aria pura —
    che almeno viene dichiarata tale. Nessun dato inventato.
    """
    if not percorso:
        return {}
    p = Path(percorso)
    if not p.exists():
        return {}
    try:
        contenuto = json.loads(p.read_text(encoding="utf-8"))
        fattori = contenuto.get("fattori") or {}
        return {
            str(k): float(v)
            for k, v in fattori.items()
            if isinstance(v, (int, float)) and 1.0 <= float(v) <= 20.0
        }
    except (ValueError, OSError):
        return {}


def _record(imp: Impianto, fattori: Dict[str, float]) -> dict:
    """Record compatto di un impianto (chiavi corte per ridurre il peso del file)."""
    return {
        "id": imp.id,
        "n": imp.nome or imp.gestore,
        "v": imp.indirizzo,
        "c": imp.comune,
        "m": imp.marchio,
        "lat": round(imp.lat, 6) if imp.lat is not None else None,
        "lon": round(imp.lon, 6) if imp.lon is not None else None,
        "p": {
            chiave: {
                "v": round(prezzo.valore, 3),
                "s": prezzo.self_service,
                "t": _iso(prezzo.comunicato_il),
            }
            for chiave, prezzo in sorted(imp.prezzi.items())
        },
        # Orario di apertura (OpenStreetMap), solo se abbinato: chiave assente altrimenti.
        **({"oh": imp.orari} if imp.orari else {}),
        # Fattore stradale (servizio percorsi, Fase 5): chiave assente dove manca.
        **({"fs": fattori[imp.id]} if imp.id in fattori else {}),
    }


def _medie_provinciali(gruppo: List[Impianto]) -> Dict[str, float]:
    """Prezzo medio della provincia per carburante.

    È il termine di paragone del «risparmi X € sul pieno» (config: `risparmio.confronto:
    provincia`). Calcolarlo qui invece che nell'app lo rende **stabile**: l'app lo faceva
    sull'elenco già filtrato per raggio ed età, quindi bastava allargare il raggio perché
    il risparmio dichiarato cambiasse a parità di prezzo. Mai la media regionale: dentro
    la stessa provincia i prezzi variano più della media (pag. 12).
    """
    somme: Dict[str, List[float]] = {}
    for imp in gruppo:
        for chiave, prezzo in imp.prezzi.items():
            somme.setdefault(chiave, []).append(prezzo.valore)
    return {c: round(sum(v) / len(v), 3) for c, v in sorted(somme.items()) if v}


def _centroide(gruppo: List[Impianto]) -> dict | None:
    """Baricentro della provincia: media delle coordinate valide degli impianti.
    Serve all'app per scegliere la provincia più vicina alla posizione dell'utente
    (Tappa 04) usando i nostri stessi dati, senza servizi esterni.
    """
    coord = [(i.lat, i.lon) for i in gruppo if i.lat is not None and i.lon is not None]
    if not coord:
        return None
    lat = sum(c[0] for c in coord) / len(coord)
    lon = sum(c[1] for c in coord) / len(coord)
    return {"lat": round(lat, 6), "lon": round(lon, 6)}


def _riquadro(gruppo: List[Impianto]) -> dict | None:
    """Rettangolo che contiene tutti gli impianti della provincia.

    Serve all'app per non sbagliare provincia a ridosso di un confine. Col solo
    baricentro chi sta a Monza finisce su Milano — il baricentro milanese è più vicino
    di quello brianzolo — e si ritrova un elenco di impianti tutti lontani senza
    capirne il motivo. Il rettangolo non è il confine amministrativo, ma dice una cosa
    che il baricentro non sa dire: *fin dove arrivano* i nostri impianti.
    """
    coord = [(i.lat, i.lon) for i in gruppo if i.lat is not None and i.lon is not None]
    if not coord:
        return None
    lat = [c[0] for c in coord]
    lon = [c[1] for c in coord]
    return {
        "latMin": round(min(lat), 6),
        "latMax": round(max(lat), 6),
        "lonMin": round(min(lon), 6),
        "lonMax": round(max(lon), 6),
    }


def versione(data_dato: datetime | None) -> str:
    """Stringa di versione: data del dato + timestamp di build (UTC)."""
    base = (data_dato or datetime.now(timezone.utc)).strftime("%Y%m%d")
    ts = datetime.now(timezone.utc).strftime("%H%M%S")
    return f"{base}-{ts}"


def costruisci(impianti: Iterable[Impianto], cfg: Config, ver: str,
               data_dato: datetime | None,
               fattori: Dict[str, float] | None = None) -> dict:
    """Scrive i file di provincia nella dir di staging e ritorna il manifest.

    `fattori` è la mappa id → fattore stradale di `carica_fattori()`: facoltativa,
    perché la build notturna non deve dipendere da una macchina di casa.
    """
    fattori = fattori or {}
    # Si scorre più volte (province e storico): l'iterabile va materializzato una volta.
    tutti = list(impianti)
    staging = cfg.path("dir_staging")
    prov_dir = staging / "province"
    if staging.exists():
        shutil.rmtree(staging)
    prov_dir.mkdir(parents=True, exist_ok=True)

    per_prov: Dict[str, List[Impianto]] = {}
    for imp in tutti:
        if not imp.valido or not imp.prezzi:
            continue
        per_prov.setdefault(imp.provincia or "??", []).append(imp)

    generato_il = datetime.now(timezone.utc).isoformat()
    voci = []
    for sigla, gruppo in sorted(per_prov.items()):
        contenuto = {
            "versione": ver,
            "dato_del": _iso(data_dato),
            "generato_il": generato_il,
            "provincia": sigla,
            "attribuzione": ATTRIBUZIONE,
            # Media provinciale per carburante: termine di paragone stabile del risparmio.
            "medie": _medie_provinciali(gruppo),
            "impianti": [_record(i, fattori) for i in sorted(gruppo, key=lambda x: x.id)],
        }
        blob = json.dumps(contenuto, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        (prov_dir / f"{sigla}.json").write_bytes(blob)
        voci.append({
            "sigla": sigla,
            "impianti": len(gruppo),
            "file": f"province/{sigla}.json",
            "sha256": hashlib.sha256(blob).hexdigest(),
            "bytes": len(blob),
            "centro": _centroide(gruppo),
            "riquadro": _riquadro(gruppo),
        })

    manifest = {
        "versione": ver,
        "dato_del": _iso(data_dato),
        "generato_il": generato_il,
        "attribuzione": ATTRIBUZIONE,
        "province": voci,
        "totale_impianti": sum(v["impianti"] for v in voci),
    }
    (staging / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    # Storico per la regola R4: **tutti** i prezzi letti oggi, compresi quelli messi in
    # quarantena. Ricostruirlo dai file di provincia, come si faceva, lasciava fuori
    # proprio quelli — cioè quelli che domani vanno confermati — e la conferma non
    # arrivava mai. Non è un file per l'app: è la memoria che la regola richiede.
    (staging / "storico.json").write_text(
        json.dumps(_storico(tutti), ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    return manifest


def _storico(impianti: List[Impianto]) -> dict:
    """{id: {carburante: prezzo}} con i prezzi mostrati **e** quelli in quarantena."""
    prezzi: Dict[str, Dict[str, float]] = {}
    for imp in impianti:
        voce = {c: round(p.valore, 3) for c, p in imp.prezzi.items()}
        voce.update({c: round(p.valore, 3) for c, p in imp.prezzi_in_quarantena.items()})
        if voce:
            prezzi[imp.id] = voce
    return {"prezzi": prezzi}


def pubblica_atomica(cfg: Config) -> Path:
    """Scambia staging -> public solo ora (dopo che tutto è stato scritto e validato).

    Fra i due spostamenti c'è un istante in cui la cartella pubblica non esiste. Non lo
    si può eliminare rinominando directory, ma non lo si deve nemmeno subire: se il
    secondo spostamento fallisce (disco pieno, permessi, un file tenuto aperto) il
    giorno prima torna al suo posto. Senza, restava solo `public_precedente` e il passo
    successivo del job cercava un percorso sparito — con l'aggravante che il dato buono
    di ieri c'era ancora, solo sotto un altro nome.
    """
    staging = cfg.path("dir_staging")
    pubblica = cfg.path("dir_pubblica")
    if not (staging / "manifest.json").exists():
        raise RuntimeError("Staging incompleto: manca manifest.json, pubblicazione annullata.")

    precedente = None
    if pubblica.exists():
        precedente = pubblica.with_name(pubblica.name + "_precedente")
        if precedente.exists():
            shutil.rmtree(precedente)
        pubblica.rename(precedente)  # conserva il giorno prima (offline-first)

    pubblica.parent.mkdir(parents=True, exist_ok=True)
    try:
        staging.rename(pubblica)
    except OSError:
        if precedente is not None and not pubblica.exists():
            precedente.rename(pubblica)
        raise
    return pubblica
