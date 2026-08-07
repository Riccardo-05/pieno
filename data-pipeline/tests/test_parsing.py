"""Analisi dei CSV MIMIT: data di estrazione e regola self/servito.

Questi test presidiano due guasti realmente avvenuti in produzione:

1. La riga "Estrazione del 2026-08-05" (senza due punti) non veniva letta: la pipeline
   ripiegava sull'ora del job, la freschezza confrontava l'orologio con sé stesso e l'app
   dichiarava "aggiornato oggi" un file di due giorni prima.
2. Scartare le righe servito cancellava gli impianti che non hanno il self: il 96% del
   GPL, il 93% del metano e 924 impianti spariti del tutto. Ora il servito resta dove è
   l'unico prezzo, ed è dichiarato.
"""
import unittest
from datetime import datetime

from pieno_pipeline import parsing


def _csv(prima_riga: str, righe: str) -> bytes:
    return (prima_riga + "\n" + righe).encode("utf-8")


ANAGRAFICA = _csv(
    "Estrazione del : 05/08/2026 08:00:00",
    "idImpianto;Gestore;Bandiera;Tipo Impianto;Nome Impianto;Indirizzo;Comune;Provincia;Latitudine;Longitudine\n"
    "1;Tizio;Eni;Stradale;Eni Roma;Via Colombo 680;Roma;RM;41.80;12.47\n"
    "2;Caio;Q8;Stradale;Q8 Roma;Via Tuscolana 1;Roma;RM;41.86;12.55\n",
)


class TestDataEstrazione(unittest.TestCase):
    def test_forma_con_due_punti(self):
        dati = _csv("Estrazione del : 05/08/2026 08:00:00", "idImpianto;x")
        self.assertEqual(parsing.data_estrazione(dati), datetime(2026, 8, 5, 8, 0, 0))

    def test_forma_senza_due_punti_e_data_iso(self):
        # È la forma osservata sul file reale il 7 agosto 2026: prima non veniva letta.
        dati = _csv("Estrazione del 2026-08-05", "idImpianto;x")
        self.assertEqual(parsing.data_estrazione(dati), datetime(2026, 8, 5))

    def test_riga_assente_o_illeggibile(self):
        self.assertIsNone(parsing.data_estrazione(_csv("idImpianto;x", "1;2")))
        self.assertIsNone(parsing.data_estrazione(_csv("Estrazione del boh", "1;2")))


class TestSelfEServito(unittest.TestCase):
    def _prezzi(self, righe: str):
        impianti = parsing.leggi_anagrafica(ANAGRAFICA, separatore_atteso=";")
        parsing.applica_prezzi(
            impianti,
            _csv("Estrazione del 2026-08-05",
                 "idImpianto;descCarburante;prezzo;isSelf;dtComu\n" + righe),
            separatore_atteso=";",
        )
        return impianti

    def test_benzina_solo_servita_viene_tenuta_e_dichiarata(self):
        # 928 impianti hanno solo il servito per la benzina: scartarli li faceva sparire.
        imp = self._prezzi("1;Benzina;2.499;0;05/08/2026 08:00:00\n")
        self.assertEqual(imp["1"].prezzi["benzina"].valore, 2.499)
        self.assertFalse(imp["1"].prezzi["benzina"].self_service)

    def test_benzina_tiene_il_self_anche_se_arriva_dopo_il_servito(self):
        imp = self._prezzi(
            "1;Benzina;2.499;0;05/08/2026 09:00:00\n"
            "1;Benzina;1.899;1;05/08/2026 08:00:00\n"
        )
        self.assertEqual(imp["1"].prezzi["benzina"].valore, 1.899)
        self.assertTrue(imp["1"].prezzi["benzina"].self_service)

    def test_gpl_servito_viene_tenuto(self):
        # Il caso che aveva svuotato l'app: in Italia il GPL è quasi sempre servito.
        imp = self._prezzi("1;GPL;0.719;0;05/08/2026 08:00:00\n")
        self.assertEqual(imp["1"].prezzi["gpl"].valore, 0.719)
        self.assertFalse(imp["1"].prezzi["gpl"].self_service)

    def test_metano_servito_viene_tenuto(self):
        imp = self._prezzi("2;Metano;1.399;0;05/08/2026 08:00:00\n")
        self.assertEqual(imp["2"].prezzi["metano"].valore, 1.399)

    def test_gpl_preferisce_il_self_quando_esiste(self):
        imp = self._prezzi(
            "1;GPL;0.759;0;05/08/2026 09:00:00\n"
            "1;GPL;0.699;1;05/08/2026 08:00:00\n"
        )
        self.assertEqual(imp["1"].prezzi["gpl"].valore, 0.699)
        self.assertTrue(imp["1"].prezzi["gpl"].self_service)

    def test_a_parita_di_modalita_vince_la_comunicazione_piu_recente(self):
        imp = self._prezzi(
            "1;Benzina;1.899;1;05/08/2026 08:00:00\n"
            "1;Benzina;1.879;1;05/08/2026 10:00:00\n"
        )
        self.assertEqual(imp["1"].prezzi["benzina"].valore, 1.879)


if __name__ == "__main__":
    unittest.main()
