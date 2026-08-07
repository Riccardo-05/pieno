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

from . import build, orari, parsing, report, sources, validation
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
    # Data del dato: quella dichiarata dal CSV. Il ripiego sull'ora del job non è neutro —
    # rende la misura di freschezza un confronto dell'orologio con sé stesso, che passa
    # sempre — quindi va dichiarato, non subìto in silenzio.
    data_dato = parsing.data_estrazione(raw_pre, s_pre.codifica_attesa) or parsing.data_estrazione(
        raw_ana, s_ana.codifica_attesa
    )
    data_letta = data_dato is not None
    if not data_letta:
        data_dato = datetime.now(timezone.utc).replace(tzinfo=None)
        print(
            "Attenzione: data di estrazione non leggibile dalla prima riga dei CSV. "
            "Si ripiega sull'ora del job: la misura di freschezza NON è attendibile "
            "(vedi 'data_dato_letta' nel report).",
            file=sys.stderr,
        )
    impianti = parsing.leggi_anagrafica(raw_ana, s_ana.codifica_attesa, s_ana.separatore_atteso)
    n_prezzi = parsing.applica_prezzi(impianti, raw_pre, s_pre.codifica_attesa, s_pre.separatore_atteso)
    print(f"Letti {len(impianti)} impianti, {n_prezzi} righe prezzo. Dato del {data_dato:%d/%m/%Y}.")

    # --- storico + validazione (incl. normalizzazione marchi, geo, deduplica) ------
    storico = sources.carica_storico(cfg)
    confini = ConfiniComunali(disponibile=cfg.sorgenti["confini_comunali"].abilitato)
    conteggi = validation.valida(impianti, cfg, data_dato, storico=storico, confini=confini)

    # --- arricchimento orari OSM (best-effort, gratuito) ---------------------------
    s_osm = cfg.sorgenti.get("osm_orari")
    if s_osm is not None and s_osm.abilitato:
        try:
            punti = orari.scarica_orari(s_osm.url)
            indice = orari.IndiceOrari(punti)
            n = 0
            for imp in impianti.values():
                if imp.lat is not None and imp.lon is not None:
                    oh = indice.orario_vicino(imp.lat, imp.lon)
                    if oh:
                        imp.orari = oh
                        n += 1
            print(f"Orari OSM: abbinati {n}/{len(impianti)} impianti (su {len(punti)} POI con orario).")
        except Exception as e:  # noqa: BLE001 — best-effort: non deve bloccare la build
            print(f"Orari OSM non disponibili ({e}): si prosegue senza.", file=sys.stderr)

    # --- report --------------------------------------------------------------------
    ver = build.versione(data_dato)
    rep = report.genera(impianti.values(), conteggi, cfg, data_dato, ver, storico=storico,
                        data_letta=data_letta)
    print(f"Mostrati {rep['mostrati']} · scartati {rep['scartati']} · quarantena {rep['in_quarantena']}")
    if not rep["misure_di_controllo"]["storico_disponibile"]:
        print("Attenzione: nessuna build precedente trovata → la regola R4 (salto in 24 h) "
              "non è stata applicata.", file=sys.stderr)
    m = rep["misure_di_controllo"]
    print(f"Età del file: {m['eta_file_ore']} h (limite {m['eta_massima_file_ore']:.0f} h) "
          f"→ esito {rep['esito_pubblicazione']}")

    # Fattori stradali del servizio percorsi (Fase 5): facoltativi. La build notturna
    # gira su GitHub Actions e non deve dipendere da una macchina di casa: se il file
    # non c'è, i record escono senza `fs` e l'app resta alla stima in linea d'aria.
    fattori = build.carica_fattori(args.fattori)
    if args.fattori and not fattori:
        print(f"Attenzione: nessun fattore stradale letto da {args.fattori} → le distanze "
              "stimate resteranno in linea d'aria.", file=sys.stderr)

    # --- pubblicazione atomica (solo se il report supera le soglie) ----------------
    if rep["esito_pubblicazione"] != "ok" and not args.forza:
        print("Pubblicazione bloccata dal report di qualità. Uso --forza per ignorare (sconsigliato).",
              file=sys.stderr)
        build.costruisci(impianti.values(), cfg, ver, data_dato, fattori)  # staging, non pubblicato
        report.scrivi(rep, cfg)
        return 1

    build.costruisci(impianti.values(), cfg, ver, data_dato, fattori)
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
    p.add_argument("--fattori", default=None,
                   help="fattori-stradali.json del servizio percorsi (facoltativo, Fase 5)")
    return esegui(p.parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main())
