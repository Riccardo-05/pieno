"""Validatore: le regole di pag. 12 del documento di progetto.

ATTENZIONE ALLA FONTE: il testo di pag. 12 parla di "sette regole", ma la tabella
ne elenca SEI. Qui sono implementate le sei documentate; la settima è "da definire"
(non inventata). Vedi REGOLE più sotto e linee-guida/05-dati-e-qualita.md.
"""
from __future__ import annotations

import statistics
from datetime import datetime, timedelta
from typing import Dict, List, Optional

from .config import Config
from .geo import ConfiniComunali, distanza_metri, sembra_invertita
from .model import Impianto

# Elenco esplicito delle regole (per report e tracciabilità con il PDF).
REGOLE = [
    ("R1", "Coordinate fuori dal confine comunale dichiarato", "Scarto e segnalazione nel report"),
    ("R2", "Latitudine e longitudine invertite", "Correzione tentata, poi quarantena"),
    ("R3", "Prezzo oltre ±30% dalla mediana nazionale", "Quarantena, non mostrato"),
    ("R4", "Salto superiore a 0,08 €/l in 24 ore", "Quarantena fino alla conferma del giorno dopo"),
    ("R5", "Nessuna comunicazione da oltre 2 giorni", "Escluso dai risultati (soglia regolabile)"),
    ("R6", "Due impianti a meno di 25 m con stesso marchio", "Deduplica"),
    ("R7", "da definire", "da definire"),  # il PDF cita 7 regole ma ne elenca 6
]


def normalizza_marchio(marchio: str) -> str:
    """Normalizzazione marchi: minuscole, senza spazi doppi. Base per la deduplica.
    Mappature aggiuntive (alias di bandiera) DA DEFINIRE con l'anagrafica reale.
    """
    return " ".join((marchio or "").strip().lower().split())


def valida(
    impianti: Dict[str, Impianto],
    cfg: Config,
    data_riferimento: datetime,
    storico: Optional[Dict[str, Dict[str, float]]] = None,
    confini: Optional[ConfiniComunali] = None,
) -> Dict[str, int]:
    """Applica le regole in ordine. Modifica gli impianti in-place (quarantena/scarto)
    e ritorna un contatore per il report di qualità.
    """
    conteggi: Dict[str, int] = {r[0]: 0 for r in REGOLE}
    conteggi["coord_assenti"] = 0
    conteggi["R1_non_verificata"] = 0

    lista = list(impianti.values())

    # --- Pre-controllo coordinate + R2 (inversione) --------------------------------
    for imp in lista:
        if imp.lat is None or imp.lon is None:
            imp.segna("coordinate assenti", scarto=True)
            conteggi["coord_assenti"] += 1
            continue
        if sembra_invertita(imp.lat, imp.lon):
            imp.lat, imp.lon = imp.lon, imp.lat          # correzione tentata
            imp.segna("coordinate invertite: corrette, in quarantena", quarantena=True)
            conteggi["R2"] += 1

    # --- R1: confine comunale ------------------------------------------------------
    if confini is not None and confini.disponibile:
        for imp in lista:
            if not imp.valido or imp.lat is None:
                continue
            if not confini.contiene(imp.comune, imp.lat, imp.lon):
                imp.segna("coordinate fuori dal confine comunale", scarto=True)
                conteggi["R1"] += 1
    else:
        conteggi["R1_non_verificata"] = sum(1 for i in lista if i.lat is not None)

    # --- R3: prezzo oltre ±30% dalla mediana nazionale (per carburante) ------------
    mediane = _mediane_nazionali(lista)
    tol = cfg.validazione.prezzo_scarto_max_pct / 100.0
    for imp in lista:
        if not imp.valido:
            continue
        for chiave, prezzo in list(imp.prezzi.items()):
            med = mediane.get(chiave)
            if med is None or med <= 0:
                continue
            if abs(prezzo.valore - med) / med > tol:
                del imp.prezzi[chiave]                    # non mostrato
                imp.segna(f"{chiave}: prezzo fuori ±30% dalla mediana (quarantena)", quarantena=True)
                conteggi["R3"] += 1

    # --- R4: salto > 0,08 €/l in 24 h rispetto allo storico ------------------------
    if storico:
        soglia = cfg.validazione.salto_max_eur_litro_24h
        for imp in lista:
            if not imp.valido:
                continue
            ieri = storico.get(imp.id, {})
            for chiave, prezzo in list(imp.prezzi.items()):
                prec = ieri.get(chiave)
                if prec is None:
                    continue
                if abs(prezzo.valore - prec) > soglia:
                    del imp.prezzi[chiave]
                    imp.segna(f"{chiave}: salto > {soglia} €/l in 24 h (quarantena)", quarantena=True)
                    conteggi["R4"] += 1

    # --- R5: nessuna comunicazione da oltre N giorni -------------------------------
    limite = data_riferimento - timedelta(days=cfg.validazione.eta_massima_giorni)
    for imp in lista:
        if not imp.valido:
            continue
        ultima = imp.ultima_comunicazione
        if ultima is None or ultima < limite:
            imp.segna("dato più vecchio della soglia: escluso", scarto=True)
            conteggi["R5"] += 1

    # --- R6: deduplica (< 25 m, stesso marchio) ------------------------------------
    conteggi["R6"] = _deduplica(lista, cfg.validazione.dedup_distanza_metri)

    return conteggi


def _mediane_nazionali(lista: List[Impianto]) -> Dict[str, float]:
    per_carb: Dict[str, List[float]] = {}
    for imp in lista:
        if imp.scartato:
            continue
        for chiave, prezzo in imp.prezzi.items():
            per_carb.setdefault(chiave, []).append(prezzo.valore)
    return {c: statistics.median(v) for c, v in per_carb.items() if v}


def _deduplica(lista: List[Impianto], distanza_max: float) -> int:
    """Marca come scartati i duplicati (<= distanza_max, stesso marchio normalizzato),
    tenendo l'impianto con più prezzi (a parità, comunicazione più recente).
    """
    candidati = [i for i in lista if i.valido and i.lat is not None and i.lon is not None]
    rimossi = 0
    for i in range(len(candidati)):
        a = candidati[i]
        if not a.valido:
            continue
        for b in candidati[i + 1:]:
            if not b.valido or normalizza_marchio(a.marchio) != normalizza_marchio(b.marchio):
                continue
            if distanza_metri((a.lat, a.lon), (b.lat, b.lon)) <= distanza_max:
                peggiore = _peggiore(a, b)
                peggiore.segna("duplicato (< 25 m, stesso marchio): deduplica", scarto=True)
                rimossi += 1
                if peggiore is a:
                    break
    return rimossi


def _peggiore(a: Impianto, b: Impianto) -> Impianto:
    if len(a.prezzi) != len(b.prezzi):
        return a if len(a.prezzi) < len(b.prezzi) else b
    ua, ub = a.ultima_comunicazione, b.ultima_comunicazione
    if ua and ub:
        return a if ua < ub else b
    return b if ua else a
