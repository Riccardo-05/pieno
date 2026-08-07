"""Arricchimento orari di apertura da OpenStreetMap (gratuito, copertura parziale).

Interroga Overpass per i distributori italiani che espongono il tag `opening_hours` e li
abbina agli impianti MIMIT per vicinanza geografica. È **best-effort**: se Overpass non
risponde o va in timeout, gli orari restano assenti e il resto della pipeline procede.

L'orario di apertura del distributore coincide di norma con l'orario in cui il servito è
disponibile (i pompisti sono al lavoro): il dato MIMIT non lo ha, OSM sì (dove mappato).
"""
from __future__ import annotations

import json
import urllib.parse
import urllib.request
from typing import Dict, List, Optional, Tuple

from .geo import distanza_metri

_UA = "Pieno-data-pipeline/0.1 (open data; +https://github.com/)"

# Solo i distributori italiani che hanno l'orario: risultato più piccolo e pertinente.
_QUERY = (
    "[out:json][timeout:180];"
    'area["ISO3166-1"="IT"][admin_level=2]->.it;'
    'nwr["amenity"="fuel"]["opening_hours"](area.it);'
    "out center tags;"
)


def scarica_orari(url: str, timeout: int = 200) -> List[dict]:
    """Ritorna [{lat, lon, oh}] dei distributori OSM con opening_hours."""
    corpo = urllib.parse.urlencode({"data": _QUERY}).encode()
    req = urllib.request.Request(url, data=corpo, headers={"User-Agent": _UA})
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # nosec B310 (URL da config)
        dati = json.loads(resp.read())
    punti: List[dict] = []
    for el in dati.get("elements", []):
        oh = (el.get("tags") or {}).get("opening_hours")
        if not oh:
            continue
        if el.get("type") == "node":
            lat, lon = el.get("lat"), el.get("lon")
        else:  # way/relation: usa il baricentro
            centro = el.get("center") or {}
            lat, lon = centro.get("lat"), centro.get("lon")
        if lat is None or lon is None:
            continue
        punti.append({"lat": float(lat), "lon": float(lon), "oh": oh})
    return punti


class IndiceOrari:
    """Griglia spaziale per abbinare velocemente gli impianti agli orari OSM."""

    def __init__(self, punti: List[dict], cella_gradi: float = 0.002):
        self.cella = cella_gradi
        self.griglia: Dict[Tuple[int, int], List[dict]] = {}
        for p in punti:
            chiave = (int(p["lat"] / self.cella), int(p["lon"] / self.cella))
            self.griglia.setdefault(chiave, []).append(p)

    def orario_vicino(self, lat: float, lon: float, max_metri: float = 120) -> Optional[str]:
        """Orario del distributore OSM più vicino entro max_metri, o None."""
        ci, cj = int(lat / self.cella), int(lon / self.cella)
        migliore, dmin = None, max_metri
        for i in range(ci - 1, ci + 2):
            for j in range(cj - 1, cj + 2):
                for p in self.griglia.get((i, j), ()):
                    d = distanza_metri((lat, lon), (p["lat"], p["lon"]))
                    if d <= dmin:
                        dmin, migliore = d, p["oh"]
        return migliore
