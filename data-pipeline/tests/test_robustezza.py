"""Robustezza della build notturna: le tre cose che la fanno inciampare in silenzio.

- la deduplica, che confronta ogni impianto con tutti gli altri;
- il rilevamento del separatore, unica euristica fra la fonte e tutto il resto;
- lo scambio finale, che per un istante lasciava la cartella pubblica inesistente.
"""
import io
import json
import time
import unittest
from datetime import datetime, timedelta
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

from pieno_pipeline import build, parsing, pipeline, report, sources
from pieno_pipeline.model import Impianto, Prezzo
from pieno_pipeline.validation import REGOLE, _deduplica, valida


def imp(idi: str, lat: float, lon: float, marchio: str = "Eni") -> Impianto:
    return Impianto(id=idi, gestore="", marchio=marchio, tipo="", nome=f"Impianto {idi}",
                    indirizzo="", comune="Milano", provincia="MI", lat=lat, lon=lon)


class TestDeduplica(unittest.TestCase):
    def test_due_impianti_vicini_con_lo_stesso_marchio_diventano_uno(self):
        # ~11 m di distanza: sotto la soglia dei 25 m.
        lista = [imp("1", 45.4640, 9.1900), imp("2", 45.4641, 9.1900)]

        rimossi = _deduplica(lista, 25)

        self.assertEqual(rimossi, 1)
        self.assertEqual(sum(1 for i in lista if i.valido), 1)

    def test_marchi_diversi_restano_due(self):
        lista = [imp("1", 45.4640, 9.1900, "Eni"), imp("2", 45.4641, 9.1900, "Q8")]

        self.assertEqual(_deduplica(lista, 25), 0)

    def test_stesso_marchio_ma_lontani_restano_due(self):
        lista = [imp("1", 45.4640, 9.1900), imp("2", 45.4700, 9.1900)]

        self.assertEqual(_deduplica(lista, 25), 0)

    def test_il_marchio_si_normalizza_prima_di_confrontare(self):
        lista = [imp("1", 45.4640, 9.1900, " ENI  spa "), imp("2", 45.4641, 9.1900, "eni spa")]

        self.assertEqual(_deduplica(lista, 25), 1)

    def test_regge_l_italia_intera_senza_metterci_un_minuto(self):
        """Su 20.000 impianti il confronto a coppie sono 200 milioni di paragoni.

        Il margine è largo apposta: qui non si misura la velocità della macchina, si
        vuole solo che il costo non sia più quadratico. Col vecchio codice questo
        test impiegava circa un minuto e mezzo.
        """
        passo = 0.01  # ~1 km: nessuno è duplicato di nessuno
        lista = [imp(str(k), 41.0 + (k % 500) * passo, 9.0 + (k // 500) * passo)
                 for k in range(20_000)]

        inizio = time.monotonic()
        rimossi = _deduplica(lista, 25)
        durata = time.monotonic() - inizio

        self.assertEqual(rimossi, 0)
        self.assertLess(durata, 20, f"la deduplica ha impiegato {durata:.1f} s")


class TestSeparatore(unittest.TestCase):
    INTESTAZIONE = (
        b"Estrazione del 2026-08-05\n"
        b"idImpianto;Gestore;Bandiera;Tipo Impianto;Nome Impianto;Indirizzo;Comune;"
        b"Provincia;Latitudine;Longitudine\n"
    )

    def test_indirizzi_con_virgola_non_spostano_il_separatore(self):
        csv = self.INTESTAZIONE + (
            b"1001;Rossi;Eni;Stradale;Eni Centrale;VIA ROMA, 12;Milano;MI;45.464;9.190\n"
            b"1002;Bianchi;Q8;Stradale;Q8 Navigli;VIALE CERTOSA, 5;Milano;MI;45.450;9.178\n"
        )

        impianti = parsing.leggi_anagrafica(csv)

        self.assertEqual(len(impianti), 2)
        self.assertEqual(impianti["1001"].comune, "Milano")
        self.assertAlmostEqual(impianti["1001"].lat, 45.464)

    def test_se_il_fiuto_sbaglia_vince_il_separatore_dichiarato(self):
        """Il Sniffer è un'euristica: quando la sua scelta non produce le colonne
        che il file dichiara, si torna a quello che la configurazione dice."""
        csv = self.INTESTAZIONE + (
            b"1001;Rossi;Eni;Stradale;Eni Centrale;VIA ROMA 12;Milano;MI;45.464;9.190\n"
        )

        with mock.patch("csv.Sniffer.sniff") as fiuto:
            fiuto.return_value = mock.Mock(delimiter=",")
            impianti = parsing.leggi_anagrafica(csv)

        self.assertEqual(len(impianti), 1, "il file non deve svuotarsi per un fiuto sbagliato")
        self.assertEqual(impianti["1001"].provincia, "MI")


class TestPubblicazione(unittest.TestCase):
    def _config(self, radice: Path):
        cfg = mock.Mock()
        cfg.path.side_effect = lambda chiave: {
            "dir_staging": radice / "_staging",
            "dir_pubblica": radice / "public",
        }[chiave]
        return cfg

    def _prepara(self, radice: Path):
        (radice / "public").mkdir()
        (radice / "public" / "manifest.json").write_text("vecchio", encoding="utf-8")
        (radice / "_staging").mkdir()
        (radice / "_staging" / "manifest.json").write_text("nuovo", encoding="utf-8")

    def test_lo_scambio_conserva_il_giorno_prima(self):
        with TemporaryDirectory() as tmp:
            radice = Path(tmp)
            self._prepara(radice)

            build.pubblica_atomica(self._config(radice))

            self.assertEqual(
                (radice / "public" / "manifest.json").read_text(encoding="utf-8"), "nuovo")
            self.assertEqual(
                (radice / "public_precedente" / "manifest.json").read_text(encoding="utf-8"),
                "vecchio")

    def test_se_lo_scambio_fallisce_la_cartella_pubblica_resta_in_piedi(self):
        """Fra i due spostamenti c'era un istante senza cartella pubblica: se il
        secondo falliva, restava solo `public_precedente` e i passi a valle
        cercavano un percorso che non esisteva più."""
        with TemporaryDirectory() as tmp:
            radice = Path(tmp)
            self._prepara(radice)
            vero_rename = Path.rename

            def rename_che_fallisce_sullo_staging(self, destinazione):
                if self.name == "_staging":
                    raise OSError("disco pieno")
                return vero_rename(self, destinazione)

            with mock.patch.object(Path, "rename", rename_che_fallisce_sullo_staging):
                with self.assertRaises(OSError):
                    build.pubblica_atomica(self._config(radice))

            self.assertTrue((radice / "public" / "manifest.json").exists(),
                            "il dato di ieri deve restare servibile")
            self.assertEqual(
                (radice / "public" / "manifest.json").read_text(encoding="utf-8"), "vecchio")


class TestQuarantenaR4(unittest.TestCase):
    """R4 dichiara «quarantena fino alla conferma del giorno dopo».

    Il codice si fermava alla prima metà: toglieva il prezzo e basta. Siccome lo
    storico si ricostruisce dai file pubblicati, il valore nuovo non ci finiva mai, e
    il giorno dopo il confronto ripartiva dal vecchio: un rialzo di mercato vero
    faceva sparire il prezzo **finché il salto non rientrava da solo**.
    """

    def _cfg(self, radice: Path):
        cfg = mock.Mock()
        cfg.path.side_effect = lambda chiave: {
            "dir_staging": radice / "_staging",
            "dir_pubblica": radice / "public",
        }[chiave]
        cfg.validazione.prezzo_scarto_max_pct = 30
        cfg.validazione.salto_max_eur_litro_24h = 0.08
        cfg.validazione.eta_massima_giorni = 30
        cfg.validazione.dedup_distanza_metri = 25
        return cfg

    def _impianto_con(self, prezzo: float, quando: datetime) -> Impianto:
        i = imp("1001", 45.4640, 9.1900)
        i.prezzi["benzina"] = Prezzo(carburante="benzina", valore=prezzo,
                                     self_service=True, comunicato_il=quando)
        return i

    def test_il_prezzo_che_salta_esce_dai_mostrati_ma_resta_in_quarantena(self):
        oggi = datetime(2026, 8, 6, 8, 0, 0)
        impianti = {"1001": self._impianto_con(1.999, oggi)}

        valida(impianti, self._cfg(Path(".")), oggi, storico={"1001": {"benzina": 1.799}})

        i = impianti["1001"]
        self.assertNotIn("benzina", i.prezzi, "non si mostra un prezzo non confermato")
        self.assertIn("benzina", i.prezzi_in_quarantena)
        self.assertAlmostEqual(i.prezzi_in_quarantena["benzina"].valore, 1.999)

    def test_lo_storico_conserva_anche_i_prezzi_in_quarantena(self):
        """È questo che rende possibile la conferma: domani il confronto parte dal
        valore di oggi, non da quello di ieri."""
        with TemporaryDirectory() as tmp:
            radice = Path(tmp)
            cfg = self._cfg(radice)
            oggi = datetime(2026, 8, 6, 8, 0, 0)
            i = self._impianto_con(1.850, oggi)
            i.prezzi_in_quarantena["gasolio"] = Prezzo(
                carburante="gasolio", valore=1.999, self_service=True, comunicato_il=oggi)

            build.costruisci([i], cfg, "20260806-000000", oggi)
            build.pubblica_atomica(cfg)
            storico = sources.carica_storico(cfg)

        self.assertAlmostEqual(storico["1001"]["benzina"], 1.850)
        self.assertAlmostEqual(storico["1001"]["gasolio"], 1.999,
                               msg="senza questo, il prezzo in quarantena non si conferma mai")

    def test_il_giorno_dopo_il_prezzo_confermato_torna_visibile(self):
        oggi = datetime(2026, 8, 7, 8, 0, 0)
        impianti = {"1001": self._impianto_con(1.999, oggi)}

        # Lo storico porta il valore di ieri, quello che era stato messo in quarantena.
        valida(impianti, self._cfg(Path(".")), oggi, storico={"1001": {"benzina": 1.999}})

        self.assertIn("benzina", impianti["1001"].prezzi,
                      "confermato due giorni di fila, il prezzo è vero e va mostrato")


class TestDataConFuso(unittest.TestCase):
    """La data del dato deve dire a quale fuso appartiene.

    Il CSV ministeriale è in ora italiana; l'app faceva `adesso - dato_del`
    interpretandola come ora locale **del telefono**. Coincideva per caso in Italia
    d'inverno: d'estate sbagliava di un'ora, all'estero di più. È lo stesso genere di
    confusione che aveva già fatto saltare il job del 6 agosto.
    """

    def test_dato_del_porta_l_offset_italiano(self):
        with TemporaryDirectory() as tmp:
            radice = Path(tmp)
            cfg = mock.Mock()
            cfg.path.side_effect = lambda chiave: {
                "dir_staging": radice / "_staging",
                "dir_pubblica": radice / "public",
            }[chiave]
            i = imp("1001", 45.4640, 9.1900)
            i.prezzi["benzina"] = Prezzo(carburante="benzina", valore=1.85,
                                         self_service=True,
                                         comunicato_il=datetime(2026, 8, 5, 7, 30))

            build.costruisci([i], cfg, "20260805-000000", datetime(2026, 8, 5, 8, 0))

            manifest = json.loads((radice / "_staging" / "manifest.json").read_text(encoding="utf-8"))
            provincia = json.loads(
                (radice / "_staging" / "province" / "MI.json").read_text(encoding="utf-8"))

        # 5 agosto: ora legale italiana, +02:00.
        self.assertEqual(manifest["dato_del"], "2026-08-05T08:00:00+02:00")
        self.assertEqual(provincia["dato_del"], "2026-08-05T08:00:00+02:00")
        self.assertEqual(provincia["impianti"][0]["p"]["benzina"]["t"],
                         "2026-08-05T07:30:00+02:00")

    def test_d_inverno_l_offset_cambia_da_solo(self):
        with TemporaryDirectory() as tmp:
            radice = Path(tmp)
            cfg = mock.Mock()
            cfg.path.side_effect = lambda chiave: {
                "dir_staging": radice / "_staging",
                "dir_pubblica": radice / "public",
            }[chiave]
            i = imp("1001", 45.4640, 9.1900)
            i.prezzi["benzina"] = Prezzo(carburante="benzina", valore=1.85,
                                         self_service=True, comunicato_il=None)

            build.costruisci([i], cfg, "20260115-000000", datetime(2026, 1, 15, 8, 0))

            manifest = json.loads((radice / "_staging" / "manifest.json").read_text(encoding="utf-8"))

        self.assertEqual(manifest["dato_del"], "2026-01-15T08:00:00+01:00")


class TestConfiniDiProvincia(unittest.TestCase):
    """Il manifest porta anche il rettangolo della provincia, non solo il baricentro.

    Col solo baricentro, chi sta a Monza finisce su Milano: il baricentro milanese è
    più vicino di quello brianzolo. L'utente vede un elenco di impianti tutti lontani
    e non ha modo di capire perché.
    """

    def test_ogni_provincia_dichiara_il_suo_rettangolo(self):
        with TemporaryDirectory() as tmp:
            radice = Path(tmp)
            cfg = mock.Mock()
            cfg.path.side_effect = lambda chiave: {
                "dir_staging": radice / "_staging",
                "dir_pubblica": radice / "public",
            }[chiave]
            impianti = []
            for k, (lat, lon) in enumerate([(45.40, 9.10), (45.50, 9.30)]):
                i = imp(str(1000 + k), lat, lon)
                i.prezzi["benzina"] = Prezzo(carburante="benzina", valore=1.85,
                                             self_service=True, comunicato_il=None)
                impianti.append(i)

            manifest = build.costruisci(impianti, cfg, "v", datetime(2026, 8, 5, 8, 0))

        riquadro = manifest["province"][0]["riquadro"]
        self.assertAlmostEqual(riquadro["latMin"], 45.40)
        self.assertAlmostEqual(riquadro["latMax"], 45.50)
        self.assertAlmostEqual(riquadro["lonMin"], 9.10)
        self.assertAlmostEqual(riquadro["lonMax"], 9.30)


class TestOrologioIniettabile(unittest.TestCase):
    """Il report deve poter essere messo alla prova senza dipendere da che ore sono.

    Finché l'unico «adesso» era l'orologio di sistema, i test dovevano ancorarsi a
    `datetime.now()` per non far risultare vecchissimo il file di prova. Il risultato
    dipendeva quindi dal fuso della macchina: è così che il job del 6 agosto 2026 è
    fallito in CI (runner in UTC, freschezza misurata in ora italiana) mentre in locale
    passava.
    """

    def _cfg(self):
        cfg = mock.Mock()
        cfg.qualita.eta_massima_file_ore = 48
        cfg.qualita.freschezza_target_pct = 85
        cfg.qualita.impianti_senza_eta_ammessi = 0
        cfg.qualita.scarto_mediano_target_eur_litro = 0.01
        cfg.qualita.segnalazioni_target_permille = 5
        cfg.validazione.eta_massima_giorni = 30
        return cfg

    def _impianto(self, quando):
        i = imp("1001", 45.4640, 9.1900)
        i.prezzi["benzina"] = Prezzo(carburante="benzina", valore=1.85,
                                     self_service=True, comunicato_il=quando)
        return i

    def test_l_eta_si_misura_dall_istante_che_si_passa(self):
        dato = datetime(2026, 8, 6, 8, 0, 0)
        rep = build_report(self._cfg(), [self._impianto(dato)], dato,
                           adesso=dato + timedelta(hours=10))

        self.assertAlmostEqual(rep["misure_di_controllo"]["eta_file_ore"], 10.0, places=1)
        self.assertEqual(rep["esito_pubblicazione"], "ok")

    def test_lo_stesso_dato_oltre_soglia_blocca(self):
        dato = datetime(2026, 8, 6, 8, 0, 0)
        rep = build_report(self._cfg(), [self._impianto(dato)], dato,
                           adesso=dato + timedelta(hours=49))

        self.assertEqual(rep["esito_pubblicazione"], "bloccata")

    def test_senza_istante_si_usa_l_orologio_come_prima(self):
        dato = datetime.now().replace(microsecond=0)
        rep = build_report(self._cfg(), [self._impianto(dato)], dato)

        self.assertLess(rep["misure_di_controllo"]["eta_file_ore"], 24)


class TestAvvisiVisibili(unittest.TestCase):
    """Gli avvisi che nessuno legge non esistono.

    Quando lo storico manca, R4 non scatta e i salti di prezzo passano tutti. Oggi la
    pipeline lo dice su stderr e il job riesce lo stesso: in mezzo a mille righe di log
    non se ne accorge nessuno. Su GitHub esiste un modo per farlo vedere davvero — le
    annotazioni — e costa una riga.
    """

    def test_in_ci_l_avviso_diventa_un_annotazione(self):
        with mock.patch.dict("os.environ", {"GITHUB_ACTIONS": "true"}):
            with mock.patch("sys.stderr", new_callable=io.StringIO) as uscita:
                pipeline.avvisa("lo storico non c'era")

        self.assertTrue(uscita.getvalue().startswith("::warning::"))
        self.assertIn("lo storico non c'era", uscita.getvalue())

    def test_fuori_dalla_ci_resta_una_riga_leggibile(self):
        with mock.patch.dict("os.environ", {}, clear=True):
            with mock.patch("sys.stderr", new_callable=io.StringIO) as uscita:
                pipeline.avvisa("lo storico non c'era")

        self.assertFalse(uscita.getvalue().startswith("::warning::"))
        self.assertIn("lo storico non c'era", uscita.getvalue())


class TestConsoleWindows(unittest.TestCase):
    """La pipeline deve poter girare sulla macchina di chi la scrive.

    Scaricava, validava e deduplicava ventimila impianti, poi moriva sull'ultima riga
    stampata: la console Windows usa cp1252 e non sa scrivere `→` né `·`. Su Linux, dove
    gira la CI, non si vedeva — quindi il difetto è rimasto lì mentre dalla macchina di
    casa il job non poteva concludersi a nessuna ora.
    """

    def _console_cp1252(self):
        return io.TextIOWrapper(io.BytesIO(), encoding="cp1252")

    def test_una_freccia_non_fa_cadere_una_console_cp1252(self):
        console = self._console_cp1252()

        with mock.patch("sys.stdout", console):
            pipeline.configura_uscita()
            print("Età del file: 1.3 h (limite 48 h) → esito ok")
            print("Mostrati 21181 · scartati 2682")

        console.flush()  # nessuna eccezione: è tutto quello che serve

    def test_senza_configurare_la_stessa_riga_esplode(self):
        """Controprova: è davvero la console a rifiutare quei caratteri."""
        console = self._console_cp1252()

        with self.assertRaises(UnicodeEncodeError):
            console.write("→")
            console.flush()

    def test_su_uno_stream_che_non_si_puo_riconfigurare_non_si_lamenta(self):
        with mock.patch("sys.stdout", io.StringIO()):
            pipeline.configura_uscita()  # StringIO non ha reconfigure: si tira dritto


class TestMessaggioDiBlocco(unittest.TestCase):
    """Quando la build si blocca, dire la cosa che serve sapere.

    «Pubblicazione bloccata dal report di qualità» è vero e inutile: non dice che il file
    è quello di ieri, e che riprovare fra un minuto darà lo stesso esito.
    """

    def test_il_blocco_spiega_l_eta_e_cosa_aspettarsi(self):
        with mock.patch("sys.stderr", new_callable=io.StringIO) as uscita:
            pipeline.spiega_blocco(eta_ore=49.6, limite_ore=48)

        testo = uscita.getvalue()
        self.assertIn("49.6", testo)
        self.assertIn("48", testo)
        self.assertIn("--forza", testo)
        # La cosa che mancava: perché riprovare adesso non serve.
        self.assertRegex(testo.lower(), r"ministero|domani|nuovo file")


def build_report(cfg, impianti, dato, adesso=None):
    conteggi = {r[0]: 0 for r in REGOLE}
    return report.genera(impianti, conteggi, cfg, dato, "prova", adesso=adesso)


if __name__ == "__main__":
    unittest.main()
