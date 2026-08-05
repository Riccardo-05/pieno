"""Report giornaliero di qualità e misure di controllo (pag. 12).

Il report decide la pubblicazione: se le soglie verificabili in questa fase non sono
superate, la build non va scambiata (offline-first: resta il giorno prima).
"""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, Iterable, List

from .config import Config
from .model import Impianto


def genera(impianti: Iterable[Impianto], conteggi: Dict[str, int], cfg: Config,
           data_riferimento: datetime, ver: str) -> dict:
    lista = list(impianti)
    validi = [i for i in lista if i.valido and i.prezzi]

    # Freschezza: % impianti mostrati con dato non più vecchio di 24 h.
    limite_24h = data_riferimento - timedelta(hours=24)
    con_eta = [i for i in validi if i.ultima_comunicazione is not None]
    freschi = [i for i in con_eta if i.ultima_comunicazione >= limite_24h]
    freschezza_pct = (100.0 * len(freschi) / len(validi)) if validi else 0.0
    senza_eta = len(validi) - len(con_eta)

    misure = {
        "freschezza_pct_24h": round(freschezza_pct, 2),
        "freschezza_target_pct": cfg.qualita.freschezza_target_pct,
        "freschezza_ok": freschezza_pct >= cfg.qualita.freschezza_target_pct,
        "impianti_senza_eta": senza_eta,
        "impianti_senza_eta_ammessi": cfg.qualita.impianti_senza_eta_ammessi,
        "senza_eta_ok": senza_eta <= cfg.qualita.impianti_senza_eta_ammessi,
        # Misurabili solo con audit sul campo / in produzione: qui non calcolabili.
        "scarto_mediano_eur_litro": "da definire (audit sul campo mensile, 100 impianti)",
        "segnalazioni_permille": "da definire (misurato in produzione)",
    }

    report = {
        "versione": ver,
        "generato_il": datetime.now(timezone.utc).isoformat(),
        "dato_del": data_riferimento.isoformat(),
        "totale_letti": len(lista),
        "mostrati": len(validi),
        "scartati": sum(1 for i in lista if i.scartato),
        "in_quarantena": sum(1 for i in lista if i.quarantena and not i.scartato),
        "regole": conteggi,
        "misure_di_controllo": misure,
        "esito_pubblicazione": "ok" if (misure["freschezza_ok"] and misure["senza_eta_ok"]) else "bloccata",
    }
    return report


def scrivi(report: dict, cfg: Config) -> Path:
    """Scrive il report JSON e una versione Markdown leggibile nella dir pubblica."""
    dest = cfg.path("dir_pubblica")
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "report-qualita.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (dest / "report-qualita.md").write_text(_markdown(report), encoding="utf-8")
    return dest / "report-qualita.json"


def _markdown(r: dict) -> str:
    m = r["misure_di_controllo"]
    righe = [
        f"# Report di qualità — versione {r['versione']}",
        "",
        f"- Dato del: {r['dato_del']}",
        f"- Generato il: {r['generato_il']}",
        f"- Impianti letti: {r['totale_letti']}",
        f"- Impianti mostrati: {r['mostrati']}",
        f"- Scartati: {r['scartati']} · In quarantena: {r['in_quarantena']}",
        f"- **Esito pubblicazione: {r['esito_pubblicazione']}**",
        "",
        "## Misure di controllo",
        "",
        f"- Freschezza < 24 h: {m['freschezza_pct_24h']}% (target > {m['freschezza_target_pct']}%) → {'OK' if m['freschezza_ok'] else 'SOTTO SOGLIA'}",
        f"- Impianti senza età del dato: {m['impianti_senza_eta']} (ammessi {m['impianti_senza_eta_ammessi']}) → {'OK' if m['senza_eta_ok'] else 'SOTTO SOGLIA'}",
        f"- Scarto mediano prezzo mostrato/reale: {m['scarto_mediano_eur_litro']}",
        f"- Segnalazioni ogni 1.000 navigazioni: {m['segnalazioni_permille']}",
        "",
        "## Regole di validazione (conteggi)",
        "",
    ]
    for chiave, valore in r["regole"].items():
        righe.append(f"- {chiave}: {valore}")
    return "\n".join(righe) + "\n"
