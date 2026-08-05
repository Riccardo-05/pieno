"""Scarico delle sorgenti (o lettura da file locale) e lettura dello storico.

Usa solo la libreria standard (urllib): nessuna dipendenza a pagamento, nessun servizio
esterno oltre alla sorgente MIMIT.
"""
from __future__ import annotations

import json
import urllib.request
from pathlib import Path
from typing import Dict, Optional

from .config import Config, Sorgente

UA = "Pieno-data-pipeline/0.1 (+https://github.com/; open data MIMIT)"


def scarica(sorgente: Sorgente, timeout: int = 60) -> bytes:
    req = urllib.request.Request(sorgente.url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # nosec B310 (URL da config)
        return resp.read()


def leggi_locale(percorso: str | Path) -> bytes:
    return Path(percorso).read_bytes()


def ottieni(sorgente: Sorgente, locale: Optional[str | Path], timeout: int = 60) -> bytes:
    """Ritorna i byte grezzi: da file locale se fornito, altrimenti scarica."""
    if locale:
        return leggi_locale(locale)
    return scarica(sorgente, timeout=timeout)


def carica_storico(cfg: Config) -> Dict[str, Dict[str, float]]:
    """Ricostruisce {id_impianto: {carburante: prezzo}} dai file di provincia pubblicati
    in precedenza, per la regola R4 (salto in 24 h). Vuoto al primo avvio.
    """
    storico: Dict[str, Dict[str, float]] = {}
    prov_dir = cfg.path("dir_pubblica") / "province"
    if not prov_dir.exists():
        return storico
    for file in prov_dir.glob("*.json"):
        try:
            dati = json.loads(file.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        for imp in dati.get("impianti", []):
            prezzi = {c: p["v"] for c, p in imp.get("p", {}).items() if "v" in p}
            if prezzi:
                storico[imp["id"]] = prezzi
    return storico
