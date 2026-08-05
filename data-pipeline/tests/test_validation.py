"""Test del validatore (regole di pag. 12). Eseguibile con:  python -m unittest -v"""
from __future__ import annotations

import unittest
from datetime import datetime, timedelta

from pieno_pipeline.config import carica
from pieno_pipeline.geo import sembra_invertita, distanza_metri
from pieno_pipeline.model import Impianto, Prezzo, normalizza_carburante
from pieno_pipeline.validation import valida, normalizza_marchio

OGGI = datetime(2026, 8, 5, 8, 0, 0)
CFG = carica()


def impianto(idi, lat, lon, prezzi, marchio="Eni", quando=OGGI, provincia="MI"):
    imp = Impianto(id=idi, gestore="G", marchio=marchio, tipo="Stradale", nome="N",
                   indirizzo="Via", comune="Milano", provincia=provincia, lat=lat, lon=lon)
    for carb, val in prezzi.items():
        imp.prezzi[carb] = Prezzo(carburante=carb, valore=val, self_service=True, comunicato_il=quando)
    return imp


class TestModello(unittest.TestCase):
    def test_normalizza_carburante(self):
        self.assertEqual(normalizza_carburante("Blue Diesel"), "gasolio")
        self.assertEqual(normalizza_carburante("Hi-Q Diesel"), "gasolio")
        self.assertEqual(normalizza_carburante("Benzina 98"), "benzina")
        self.assertEqual(normalizza_carburante("GPL"), "gpl")
        self.assertEqual(normalizza_carburante("Metano"), "metano")
        self.assertIsNone(normalizza_carburante("Idrogeno"))

    def test_marchio(self):
        self.assertEqual(normalizza_marchio("  Eni   "), "eni")


class TestGeo(unittest.TestCase):
    def test_inversione(self):
        # Milano ~ (45.46, 9.19); scambiate (9.19, 45.46) cadono fuori dall'Italia.
        self.assertTrue(sembra_invertita(9.19, 45.46))
        self.assertFalse(sembra_invertita(45.46, 9.19))

    def test_distanza(self):
        d = distanza_metri((45.4640, 9.1890), (45.4642, 9.1890))
        self.assertTrue(20 < d < 30)


class TestRegole(unittest.TestCase):
    def test_R2_inversione_corretta_e_quarantena(self):
        imp = impianto("1", 9.19, 45.46, {"benzina": 1.8})
        valida({"1": imp}, CFG, OGGI)
        self.assertAlmostEqual(imp.lat, 45.46)
        self.assertAlmostEqual(imp.lon, 9.19)
        self.assertTrue(imp.quarantena)

    def test_R3_outlier_prezzo(self):
        base = {f"n{i}": impianto(f"n{i}", 45.46, 9.19 + i * 0.01, {"benzina": 1.80})
                for i in range(5)}
        base["out"] = impianto("out", 45.50, 9.50, {"benzina": 3.00})  # +66% sulla mediana
        valida(base, CFG, OGGI)
        self.assertNotIn("benzina", base["out"].prezzi)  # non mostrato
        self.assertTrue(base["out"].quarantena)

    def test_R5_dato_troppo_vecchio(self):
        # Oltre la soglia configurata (eta_massima_giorni). Usiamo un margine ampio.
        vecchio = impianto("v", 45.46, 9.19, {"benzina": 1.80},
                           quando=OGGI - timedelta(days=CFG.validazione.eta_massima_giorni + 5))
        valida({"v": vecchio}, CFG, OGGI)
        self.assertTrue(vecchio.scartato)

    def test_R6_deduplica(self):
        a = impianto("a", 45.4640, 9.1890, {"benzina": 1.80, "gasolio": 1.70}, marchio="Eni")
        b = impianto("b", 45.4641, 9.1890, {"benzina": 1.80}, marchio="Eni")  # ~11 m, meno prezzi
        valida({"a": a, "b": b}, CFG, OGGI)
        self.assertTrue(b.scartato)      # il meno completo
        self.assertFalse(a.scartato)

    def test_R4_salto_prezzo(self):
        imp = impianto("s", 45.46, 9.19, {"benzina": 2.00})
        storico = {"s": {"benzina": 1.80}}  # salto 0,20 > 0,08
        valida({"s": imp}, CFG, OGGI, storico=storico)
        self.assertNotIn("benzina", imp.prezzi)
        self.assertTrue(imp.quarantena)


if __name__ == "__main__":
    unittest.main(verbosity=2)
