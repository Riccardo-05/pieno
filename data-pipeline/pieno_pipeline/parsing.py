"""Analisi dei due CSV MIMIT: rilevamento codifica/separatore e mappatura in modello.

Formato osservato (DA CONFERMARE a ogni scarico, Roadmap 01 task 1). Vedi
data-pipeline/docs/formato-csv-mimit.md:

  anagrafica_impianti_attivi.csv
    riga 0: "Estrazione del : dd/mm/yyyy hh:mm:ss"
    header : idImpianto;Gestore;Bandiera;Tipo Impianto;Nome Impianto;Indirizzo;Comune;Provincia;Latitudine;Longitudine
  prezzo_alle_8.csv
    riga 0: "Estrazione del : dd/mm/yyyy hh:mm:ss"
    header : idImpianto;descCarburante;prezzo;isSelf;dtComu
"""
from __future__ import annotations

import csv
import io
from datetime import datetime
from typing import Dict, Iterable, List, Optional, Tuple

from .model import Impianto, Prezzo, normalizza_carburante

FORMATI_DATA = ("%d/%m/%Y %H:%M:%S", "%d/%m/%Y")


def _decodifica(dati: bytes, codifica_attesa: str) -> str:
    """Decodifica tollerante: prova la codifica attesa, poi utf-8-sig, poi latin-1."""
    for cod in (codifica_attesa, "utf-8-sig", "latin-1"):
        try:
            return dati.decode(cod)
        except (UnicodeDecodeError, LookupError):
            continue
    return dati.decode("utf-8", errors="replace")


def _righe_utili(testo: str) -> List[str]:
    """Scarta la prima riga 'Estrazione del ...' se presente."""
    righe = testo.splitlines()
    if righe and righe[0].lower().startswith("estrazione"):
        righe = righe[1:]
    return [r for r in righe if r.strip()]


def data_estrazione(dati: bytes, codifica_attesa: str = "utf-8") -> Optional[datetime]:
    """Legge la data di estrazione dalla prima riga del CSV MIMIT."""
    testo = _decodifica(dati, codifica_attesa)
    prima = testo.splitlines()[0] if testo else ""
    if ":" in prima:
        coda = prima.split(":", 1)[1].strip()
        return _parse_data(coda)
    return None


def _parse_data(grezzo: str) -> Optional[datetime]:
    grezzo = (grezzo or "").strip()
    for fmt in FORMATI_DATA:
        try:
            return datetime.strptime(grezzo, fmt)
        except ValueError:
            continue
    return None


def _num(grezzo: str) -> Optional[float]:
    """Converte '1,809' o '1.809' in float. None se vuoto/non numerico."""
    g = (grezzo or "").strip().replace(",", ".")
    if not g:
        return None
    try:
        return float(g)
    except ValueError:
        return None


def _lettore(testo: str, separatore_atteso: str) -> csv.DictReader:
    righe = _righe_utili(testo)
    campione = "\n".join(righe[:20])
    sep = separatore_atteso
    try:  # conferma il separatore col Sniffer, senza fidarsi ciecamente
        sep = csv.Sniffer().sniff(campione, delimiters=";,\t|").delimiter
    except csv.Error:
        pass
    return csv.DictReader(io.StringIO("\n".join(righe)), delimiter=sep)


def _get(riga: Dict[str, str], *nomi: str) -> str:
    for n in nomi:
        if n in riga and riga[n] is not None:
            return riga[n].strip()
    return ""


def leggi_anagrafica(dati: bytes, codifica_attesa: str = "utf-8",
                     separatore_atteso: str = ";") -> Dict[str, Impianto]:
    testo = _decodifica(dati, codifica_attesa)
    impianti: Dict[str, Impianto] = {}
    for riga in _lettore(testo, separatore_atteso):
        idi = _get(riga, "idImpianto", "idimpianto", "id")
        if not idi:
            continue
        impianti[idi] = Impianto(
            id=idi,
            gestore=_get(riga, "Gestore"),
            marchio=_get(riga, "Bandiera"),
            tipo=_get(riga, "Tipo Impianto"),
            nome=_get(riga, "Nome Impianto"),
            indirizzo=_get(riga, "Indirizzo"),
            comune=_get(riga, "Comune"),
            provincia=_get(riga, "Provincia").upper(),
            lat=_num(_get(riga, "Latitudine")),
            lon=_num(_get(riga, "Longitudine")),
        )
    return impianti


def applica_prezzi(impianti: Dict[str, Impianto], dati: bytes,
                   codifica_attesa: str = "utf-8", separatore_atteso: str = ";") -> int:
    """Aggiunge i prezzi agli impianti. Ritorna il numero di righe prezzo applicate.

    Se per uno stesso impianto+carburante arrivano più righe (self/servito), tiene
    il prezzo self quando disponibile (è quello mostrato all'utente).
    """
    testo = _decodifica(dati, codifica_attesa)
    applicati = 0
    for riga in _lettore(testo, separatore_atteso):
        idi = _get(riga, "idImpianto", "idimpianto", "id")
        imp = impianti.get(idi)
        if imp is None:
            continue
        chiave = normalizza_carburante(_get(riga, "descCarburante", "carburante"))
        if chiave is None:
            continue
        valore = _num(_get(riga, "prezzo"))
        if valore is None:
            continue
        is_self = _get(riga, "isSelf") in ("1", "true", "True", "SI", "Si")
        nuovo = Prezzo(
            carburante=chiave,
            valore=round(valore, 3),
            self_service=is_self,
            comunicato_il=_parse_data(_get(riga, "dtComu")),
        )
        vecchio = imp.prezzi.get(chiave)
        # Preferenza al self; a parità, alla comunicazione più recente.
        if vecchio is None or (nuovo.self_service and not vecchio.self_service):
            imp.prezzi[chiave] = nuovo
        applicati += 1
    return applicati
