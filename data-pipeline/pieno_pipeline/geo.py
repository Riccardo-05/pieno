"""Utilità geografiche: distanza, plausibilità coordinate, confini comunali.

La regola 1 (coordinate fuori dal confine comunale dichiarato) richiede i poligoni
ISTAT dei comuni. Finché la sorgente non è configurata (config.yaml -> confini_comunali),
il controllo di confine è "non disponibile" e viene segnalato nel report, non simulato.
"""
from __future__ import annotations

import math
from typing import Optional, Tuple

# Bounding box approssimativo dell'Italia (incl. isole), per il controllo di plausibilità.
IT_LAT = (35.0, 47.5)
IT_LON = (6.0, 19.0)


def distanza_metri(a: Tuple[float, float], b: Tuple[float, float]) -> float:
    """Distanza di Haversine in metri tra due coppie (lat, lon)."""
    R = 6_371_000.0
    lat1, lon1 = map(math.radians, a)
    lat2, lon2 = map(math.radians, b)
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def dentro_italia(lat: float, lon: float) -> bool:
    return IT_LAT[0] <= lat <= IT_LAT[1] and IT_LON[0] <= lon <= IT_LON[1]


def sembra_invertita(lat: Optional[float], lon: Optional[float]) -> bool:
    """Vero se (lat, lon) è fuori dall'Italia ma (lon, lat) ci sta: coordinate scambiate."""
    if lat is None or lon is None:
        return False
    return (not dentro_italia(lat, lon)) and dentro_italia(lon, lat)


class ConfiniComunali:
    """Provider dei confini comunali. Segnaposto: 'disponibile' è False finché non
    si collega la sorgente ISTAT. `contiene()` non deve essere chiamato se non disponibile.
    """

    def __init__(self, disponibile: bool = False):
        self.disponibile = disponibile

    def contiene(self, comune: str, lat: float, lon: float) -> bool:  # pragma: no cover
        raise NotImplementedError(
            "Confini comunali ISTAT non ancora collegati (config.yaml -> confini_comunali)."
        )
