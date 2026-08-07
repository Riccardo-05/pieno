"""Media provinciale per carburante: il termine di paragone del risparmio.

Sta nella pipeline e non nell'app perché deve essere **stabile**: l'app la calcolava
sull'elenco già filtrato per raggio ed età, quindi bastava allargare il raggio perché il
«risparmi X €» cambiasse a parità di prezzo.
"""
import unittest
from datetime import datetime

from pieno_pipeline.build import _medie_provinciali
from pieno_pipeline.model import Impianto, Prezzo

OGGI = datetime(2026, 8, 6, 8, 0, 0)


def imp(idi: str, prezzi: dict) -> Impianto:
    i = Impianto(id=idi, gestore="", marchio="Eni", tipo="", nome=f"Impianto {idi}",
                 indirizzo="", comune="Roma", provincia="RM", lat=41.9, lon=12.5)
    for chiave, valore in prezzi.items():
        i.prezzi[chiave] = Prezzo(carburante=chiave, valore=valore,
                                  self_service=True, comunicato_il=OGGI)
    return i


class TestMedieProvinciali(unittest.TestCase):
    def test_media_per_carburante(self):
        gruppo = [imp("1", {"benzina": 1.800, "gasolio": 1.700}),
                  imp("2", {"benzina": 1.900, "gasolio": 1.750}),
                  imp("3", {"benzina": 2.000})]
        medie = _medie_provinciali(gruppo)
        self.assertAlmostEqual(medie["benzina"], 1.900, places=3)
        self.assertAlmostEqual(medie["gasolio"], 1.725, places=3)

    def test_carburante_assente_non_compare(self):
        medie = _medie_provinciali([imp("1", {"benzina": 1.800})])
        self.assertIn("benzina", medie)
        self.assertNotIn("gpl", medie)

    def test_gruppo_vuoto(self):
        self.assertEqual(_medie_provinciali([]), {})

    def test_tre_decimali(self):
        # I prezzi sono a tre decimali: la media non deve portarsi dietro una coda binaria.
        medie = _medie_provinciali([imp("1", {"gpl": 0.700}), imp("2", {"gpl": 0.719})])
        self.assertEqual(medie["gpl"], 0.71)


if __name__ == "__main__":
    unittest.main()
