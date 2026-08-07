"""Caricamento della configurazione (config.yaml) in oggetti tipizzati e leggibili."""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "Manca PyYAML. Installa le dipendenze: pip install -r requirements.txt"
    ) from exc

RADICE = Path(__file__).resolve().parent.parent
CONFIG_DEFAULT = RADICE / "config.yaml"


@dataclass(frozen=True)
class Sorgente:
    url: str
    codifica_attesa: str = "utf-8"
    separatore_atteso: str = ";"
    abilitato: bool = True


@dataclass(frozen=True)
class SoglieValidazione:
    prezzo_scarto_max_pct: float
    salto_max_eur_litro_24h: float
    eta_massima_giorni: int
    dedup_distanza_metri: float


@dataclass(frozen=True)
class Risparmio:
    base_litri: int
    soglia_minima_mostrata_eur: float
    confronto: str


@dataclass(frozen=True)
class Qualita:
    freschezza_target_pct: float
    eta_massima_file_ore: float
    scarto_mediano_target_eur_litro: float
    segnalazioni_target_permille: float
    impianti_senza_eta_ammessi: int


@dataclass(frozen=True)
class Pubblicazione:
    dir_staging: str
    dir_pubblica: str
    formato: str


@dataclass(frozen=True)
class Config:
    sorgenti: Dict[str, Sorgente]
    carburanti: List[str]
    validazione: SoglieValidazione
    risparmio: Risparmio
    qualita: Qualita
    pubblicazione: Pubblicazione
    radice: Path = field(default=RADICE)

    def path(self, chiave: str) -> Path:
        """Percorso assoluto per una dir di pubblicazione (staging/public)."""
        rel = getattr(self.pubblicazione, chiave)
        return (self.radice / rel).resolve()


def carica(percorso: os.PathLike | str | None = None) -> Config:
    percorso = Path(percorso) if percorso else CONFIG_DEFAULT
    dati = yaml.safe_load(percorso.read_text(encoding="utf-8"))

    sorgenti = {
        nome: Sorgente(
            url=s["url"],
            codifica_attesa=s.get("codifica_attesa", "utf-8"),
            separatore_atteso=s.get("separatore_atteso", ";"),
            abilitato=s.get("abilitato", True),
        )
        for nome, s in dati["sorgenti"].items()
    }
    v = dati["validazione"]
    r = dati["risparmio"]
    q = dati["qualita"]
    p = dati["pubblicazione"]
    return Config(
        sorgenti=sorgenti,
        carburanti=list(dati["carburanti"]),
        validazione=SoglieValidazione(
            prezzo_scarto_max_pct=float(v["prezzo_scarto_max_pct"]),
            salto_max_eur_litro_24h=float(v["salto_max_eur_litro_24h"]),
            eta_massima_giorni=int(v["eta_massima_giorni"]),
            dedup_distanza_metri=float(v["dedup_distanza_metri"]),
        ),
        risparmio=Risparmio(
            base_litri=int(r["base_litri"]),
            soglia_minima_mostrata_eur=float(r["soglia_minima_mostrata_eur"]),
            confronto=str(r["confronto"]),
        ),
        qualita=Qualita(
            freschezza_target_pct=float(q["freschezza_target_pct"]),
            eta_massima_file_ore=float(q.get("eta_massima_file_ore", 48)),
            scarto_mediano_target_eur_litro=float(q["scarto_mediano_target_eur_litro"]),
            segnalazioni_target_permille=float(q["segnalazioni_target_permille"]),
            impianti_senza_eta_ammessi=int(q["impianti_senza_eta_ammessi"]),
        ),
        pubblicazione=Pubblicazione(
            dir_staging=p["dir_staging"],
            dir_pubblica=p["dir_pubblica"],
            formato=p["formato"],
        ),
    )
