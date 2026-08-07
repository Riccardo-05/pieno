"""Modello dati: impianti, prezzi e i quattro carburanti canonici.

Carburanti canonici (linee-guida/05-dati-e-qualita.md):
    benzina, gasolio (diesel), gpl, metano
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional

# Chiavi canoniche -> etichetta leggibile. Unica fonte di verità nel codice.
CARBURANTI: Dict[str, str] = {
    "benzina": "Benzina",
    "gasolio": "Gasolio (diesel)",
    "gpl": "GPL",
    "metano": "Metano",
}


def normalizza_carburante(descrizione: str) -> Optional[str]:
    """Mappa la descrizione MIMIT (es. 'Blue Diesel', 'Hi-Q Diesel', 'Benzina 98')
    su una delle quattro chiavi canoniche. Restituisce None se non riconducibile.
    """
    d = (descrizione or "").strip().lower()
    if not d:
        return None
    if "gpl" in d:
        return "gpl"
    if "metano" in d or "gnc" in d:
        return "metano"
    if "gasolio" in d or "diesel" in d:
        return "gasolio"
    if "benzina" in d:
        return "benzina"
    return None


@dataclass
class Prezzo:
    carburante: str            # chiave canonica
    valore: float              # €/l, tre decimali
    self_service: bool
    comunicato_il: Optional[datetime]


@dataclass
class Impianto:
    id: str
    gestore: str
    marchio: str               # "bandiera" MIMIT, normalizzata a valle
    tipo: str
    nome: str
    indirizzo: str
    comune: str
    provincia: str             # sigla, es. "MI"
    lat: Optional[float]
    lon: Optional[float]
    prezzi: Dict[str, Prezzo] = field(default_factory=dict)

    # Prezzi tolti dalla vista dalla validazione ma **non buttati**: R4 dice
    # «quarantena fino alla conferma del giorno dopo», e senza conservarli la conferma
    # non potrebbe mai arrivare. Non finiscono nei file di provincia — non si mostrano —
    # ma finiscono nello storico, che è ciò con cui domani ci si confronta.
    prezzi_in_quarantena: Dict[str, Prezzo] = field(default_factory=dict)

    # Orari di apertura (formato OpenStreetMap `opening_hours`), quando abbinabili da OSM.
    # Non presenti nei dati MIMIT: arricchimento parziale e best-effort.
    orari: Optional[str] = None

    # Esito della validazione
    quarantena: bool = False
    scartato: bool = False
    motivi: List[str] = field(default_factory=list)

    @property
    def valido(self) -> bool:
        return not self.quarantena and not self.scartato

    @property
    def ultima_comunicazione(self) -> Optional[datetime]:
        date = [p.comunicato_il for p in self.prezzi.values() if p.comunicato_il]
        return max(date) if date else None

    def segna(self, motivo: str, *, scarto: bool = False, quarantena: bool = False) -> None:
        self.motivi.append(motivo)
        if scarto:
            self.scartato = True
        if quarantena:
            self.quarantena = True
