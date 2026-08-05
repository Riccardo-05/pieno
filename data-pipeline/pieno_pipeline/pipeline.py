"""Orchestrazione della pipeline (CLI).

    scarico → analisi → validazione → normalizzazione marchi →
    controllo geografico → deduplica → storico → pubblicazione atomica

Esecuzione tipica (Roadmap 01, esito: "un URL pubblico con dati puliti e datati"):

    # con scarico reale dalle URL di config.yaml
    python -m pieno_pipeline.pipeline --scarica

    # con file locali già scaricati (utile in sviluppo/test)
    python -m pieno_pipeline.pipeline --anagrafica anagrafica.csv --prezzi prezzo_alle_8.csv
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone

from . import build, parsing, report, sources, validation
from .config import carica
from .geo import ConfiniComunali


def esegui(args: argparse.Namespace) -> int:
    cfg = carica(args.config)

    # --- scarico -------------------------------------------------------------------
    s_ana = cfg.sorgenti["mimit_anagrafica"]
    s_pre = cfg.sorgenti["mimit_prezzi"]
    if not args.scarica and not (args.anagrafica and args.prezzi):
        print("Errore: usa --scarica oppure --anagrafica FILE --prezzi FILE", file=sys.stderr)
        return 2
    raw_ana = sources.ottieni(s_ana, args.anagrafica)
    raw_pre = sources.ottieni(s_pre, args.prezzi)

    # --- analisi -------------------------------------------------------------------
    data_dato = (
        parsing.data_estrazione(raw_pre, s_pre.codifica_attesa)
        or parsing.data_estrazione(raw_ana, s_ana.codifica_attesa)
        or datetime.now(timezone.utc).replace(tzinfo=None)
    )
    impianti = parsing.leggi_anagrafica(raw_ana, s_ana.codifica_attesa, s_ana.separatore_atteso)
    n_prezzi = parsing.applica_prezzi(impianti, raw_pre, s_pre.codifica_attesa, s_pre.separatore_atteso)
    print(f"Letti {len(impianti)} impianti, {n_prezzi} righe prezzo. Dato del {data_dato:%d/%m/%Y}.")

    # --- storico + validazione (incl. normalizzazione marchi, geo, deduplica) ------
    storico = sources.carica_storico(cfg)
    confini = ConfiniComunali(disponibile=cfg.sorgenti["confini_comunali"].abilitato)
    conteggi = validation.valida(impianti, cfg, data_dato, storico=storico, confini=confini)

    # --- report --------------------------------------------------------------------
    ver = build.versione(data_dato)
    rep = report.genera(impianti.values(), conteggi, cfg, data_dato, ver)
    print(f"Mostrati {rep['mostrati']} · scartati {rep['scartati']} · quarantena {rep['in_quarantena']}")
    print(f"Freschezza 24h: {rep['misure_di_controllo']['freschezza_pct_24h']}% "
          f"(target {cfg.qualita.freschezza_target_pct}%) → esito {rep['esito_pubblicazione']}")

    # --- pubblicazione atomica (solo se il report supera le soglie) ----------------
    if rep["esito_pubblicazione"] != "ok" and not args.forza:
        print("Pubblicazione bloccata dal report di qualità. Uso --forza per ignorare (sconsigliato).",
              file=sys.stderr)
        build.costruisci(impianti.values(), cfg, ver, data_dato)  # in staging, non pubblicato
        report.scrivi(rep, cfg)
        return 1

    build.costruisci(impianti.values(), cfg, ver, data_dato)
    dest = build.pubblica_atomica(cfg)
    report.scrivi(rep, cfg)
    print(f"Pubblicato in {dest} (versione {ver}).")
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Pipeline dati Pieno — Tappa 01.")
    p.add_argument("--config", default=None, help="Percorso a config.yaml")
    p.add_argument("--scarica", action="store_true", help="Scarica dalle URL di config.yaml")
    p.add_argument("--anagrafica", help="File locale anagrafica_impianti_attivi.csv")
    p.add_argument("--prezzi", help="File locale prezzo_alle_8.csv")
    p.add_argument("--forza", action="store_true", help="Pubblica anche se il report è sotto soglia")
    return esegui(p.parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main())
