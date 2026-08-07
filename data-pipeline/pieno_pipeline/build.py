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


def _iso(dt) -> str | None:
    return dt.isoformat() if dt else None


def _record(imp: Impianto) -> dict:
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


def versione(data_dato: datetime | None) -> str:
    """Stringa di versione: data del dato + timestamp di build (UTC)."""
    base = (data_dato or datetime.now(timezone.utc)).strftime("%Y%m%d")
    ts = datetime.now(timezone.utc).strftime("%H%M%S")
    return f"{base}-{ts}"


def costruisci(impianti: Iterable[Impianto], cfg: Config, ver: str,
               data_dato: datetime | None) -> dict:
    """Scrive i file di provincia nella dir di staging e ritorna il manifest."""
    staging = cfg.path("dir_staging")
    prov_dir = staging / "province"
    if staging.exists():
        shutil.rmtree(staging)
    prov_dir.mkdir(parents=True, exist_ok=True)

    per_prov: Dict[str, List[Impianto]] = {}
    for imp in impianti:
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
            "impianti": [_record(i) for i in sorted(gruppo, key=lambda x: x.id)],
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
    return manifest


def pubblica_atomica(cfg: Config) -> Path:
    """Scambia staging -> public solo ora (dopo che tutto è stato scritto e validato)."""
    staging = cfg.path("dir_staging")
    pubblica = cfg.path("dir_pubblica")
    if not (staging / "manifest.json").exists():
        raise RuntimeError("Staging incompleto: manca manifest.json, pubblicazione annullata.")
    if pubblica.exists():
        precedente = pubblica.with_name(pubblica.name + "_precedente")
        if precedente.exists():
            shutil.rmtree(precedente)
        pubblica.rename(precedente)  # conserva il giorno prima (offline-first)
    pubblica.parent.mkdir(parents=True, exist_ok=True)
    staging.rename(pubblica)
    return pubblica
