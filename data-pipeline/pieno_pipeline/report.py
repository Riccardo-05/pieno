"""Report giornaliero di qualità e misure di controllo (pag. 12).

Il report decide la pubblicazione: se le soglie verificabili in questa fase non sono
superate, la build non va scambiata (offline-first: resta il giorno prima).
"""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional

from .config import Config
from .model import Impianto


def _adesso_italia() -> datetime:
    """Ora corrente in Italia, senza fuso (come la data di estrazione del CSV MIMIT,
    che è ora locale italiana).

    Serve perché il job gira su runner in UTC: confrontando direttamente con
    `datetime.now()` l'età del file risultava negativa di un paio d'ore e veniva
    azzerata. Su sistemi senza database dei fusi (Windows senza `tzdata`) si ricade
    sull'orologio di sistema: per chi sviluppa in Italia è già l'ora giusta.
    """
    try:
        from zoneinfo import ZoneInfo

        return datetime.now(ZoneInfo("Europe/Rome")).replace(tzinfo=None)
    except Exception:  # noqa: BLE001 - fuso non disponibile: si usa l'ora di sistema
        return datetime.now()


def genera(impianti: Iterable[Impianto], conteggi: Dict[str, int], cfg: Config,
           data_riferimento: datetime, ver: str,
           storico: Optional[Dict[str, Dict[str, float]]] = None,
           data_letta: bool = True) -> dict:
    lista = list(impianti)
    validi = [i for i in lista if i.valido and i.prezzi]

    # Freschezza del DATASET: età del file ministeriale servito (la "data del dato").
    # Tutti gli impianti mostrati provengono dallo stesso file, quindi la loro "età del
    # dato" è l'età del file. Il PDF (pag. 12) chiede 24 ore; la soglia effettiva è in
    # config (`eta_massima_file_ore`, 48) perché il file ministeriale nasce già vecchio di
    # un giorno e la sua intestazione non porta l'ora — la motivazione, con le misure, sta
    # in config.yaml e in linee-guida/05-dati-e-qualita.md.
    limite_ore = cfg.qualita.eta_massima_file_ore
    eta_file_ore = max(0.0, (_adesso_italia() - data_riferimento).total_seconds() / 3600.0)
    dataset_fresco = eta_file_ore < limite_ore
    freschezza_pct = 100.0 if dataset_fresco else 0.0
    # Ogni impianto mostrato ha un'età (quella del file): 0 senza età se il file è datato.
    senza_eta = 0 if data_riferimento is not None else len(validi)

    # Diagnostica NON vincolante: quota di listini ritoccati di recente (onestà sul dato).
    def _mod_entro(giorni: int) -> float:
        limite = data_riferimento - timedelta(days=giorni)
        n = sum(1 for i in validi if i.ultima_comunicazione and i.ultima_comunicazione >= limite)
        return round(100.0 * n / len(validi), 1) if validi else 0.0

    misure = {
        # False = la data del dato è l'ora del job, non quella dichiarata dal CSV: la
        # freschezza qui sotto confronta l'orologio con sé stesso e passa sempre.
        "data_dato_letta": data_letta,
        "eta_file_ore": round(eta_file_ore, 1),
        "eta_massima_file_ore": limite_ore,
        "freschezza_pct_24h": round(freschezza_pct, 2),
        "freschezza_target_pct": cfg.qualita.freschezza_target_pct,
        "freschezza_ok": dataset_fresco,
        "impianti_senza_eta": senza_eta,
        "impianti_senza_eta_ammessi": cfg.qualita.impianti_senza_eta_ammessi,
        "senza_eta_ok": senza_eta <= cfg.qualita.impianti_senza_eta_ammessi,
        "listini_ritoccati_24h_pct": _mod_entro(1),
        "listini_ritoccati_7g_pct": _mod_entro(7),
        "listini_ritoccati_30g_pct": _mod_entro(30),
        # Senza la build precedente la regola R4 (salto in 24 h) non ha con cosa
        # confrontare e non scatta mai. Normale alla primissima esecuzione; se compare
        # su una build successiva, il recupero della build precedente si è rotto.
        "storico_disponibile": bool(storico),
        "storico_impianti": len(storico or {}),
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
        f"- Data del dato letta dal CSV: {'sì' if m['data_dato_letta'] else '**NO — è l’ora del job, freschezza non attendibile**'}",
        f"- Età del file servito: {m['eta_file_ore']} ore",
        f"- Freschezza del dataset < {m['eta_massima_file_ore']:.0f} h → {'OK' if m['freschezza_ok'] else 'SOTTO SOGLIA'}",
        f"- Impianti senza età del dato: {m['impianti_senza_eta']} (ammessi {m['impianti_senza_eta_ammessi']}) → {'OK' if m['senza_eta_ok'] else 'SOTTO SOGLIA'}",
        f"- Scarto mediano prezzo mostrato/reale: {m['scarto_mediano_eur_litro']}",
        f"- Segnalazioni ogni 1.000 navigazioni: {m['segnalazioni_permille']}",
        "",
        "### Diagnostica listini (non vincolante)",
        "",
        f"- Ritoccati nelle 24 h: {m['listini_ritoccati_24h_pct']}%",
        f"- Ritoccati in 7 giorni: {m['listini_ritoccati_7g_pct']}%",
        f"- Ritoccati in 30 giorni: {m['listini_ritoccati_30g_pct']}%",
        (f"- Storico del giorno prima: {m['storico_impianti']} impianti"
         if m["storico_disponibile"]
         else "- Storico del giorno prima: **assente** → la regola R4 (salto in 24 h) "
              "non è stata applicata"),
        "",
        "## Regole di validazione (conteggi)",
        "",
    ]
    for chiave, valore in r["regole"].items():
        righe.append(f"- {chiave}: {valore}")
    return "\n".join(righe) + "\n"
