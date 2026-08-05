"""Pipeline dati "Pieno" — Tappa 01 della roadmap.

scarico -> analisi -> validazione -> normalizzazione marchi ->
controllo geografico -> deduplica -> storico -> pubblicazione atomica

Vedi linee-guida/05-dati-e-qualita.md e linee-guida/08-roadmap.md.
"""

__all__ = ["config", "model", "parsing", "geo", "validation", "build", "report", "pipeline"]
