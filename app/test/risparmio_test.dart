// Test del calcolo del più conveniente e del risparmio (Tappa 03).
// Nessuna rete, solo dominio.

import 'package:flutter_test/flutter_test.dart';
import 'package:pieno/domain/risparmio.dart';
import 'package:pieno/models/carburante.dart';
import 'package:pieno/models/impianto.dart';

Impianto imp(String id, double prezzoBenzina) => Impianto(
      id: id,
      nome: 'Imp $id',
      indirizzo: 'Via $id',
      comune: 'Milano',
      marchio: 'X',
      lat: 45.46,
      lon: 9.19,
      prezzi: {
        Carburante.benzina: Prezzo(
          carburante: Carburante.benzina,
          valore: prezzoBenzina,
          selfService: true,
          comunicatoIl: DateTime(2026, 8, 5),
        ),
      },
    );

void main() {
  final impianti = [imp('a', 1.800), imp('b', 1.900), imp('c', 2.000)];

  test('mediaZona è la media dei prezzi del carburante', () {
    expect(mediaZona(impianti, Carburante.benzina), closeTo(1.900, 1e-9));
    expect(mediaZona(impianti, Carburante.gpl), isNull);
  });

  test('risparmioSulPieno = (media - prezzo) * 50 litri', () {
    final media = mediaZona(impianti, Carburante.benzina)!;
    // migliore = 1.800; (1.900 - 1.800) * 50 = 5.00 €
    expect(risparmioSulPieno(1.800, media), closeTo(5.0, 1e-9));
  });

  test('sotto 0,50 € il risparmio non si mostra', () {
    expect(risparmioDaMostrare(0.49), isFalse);
    expect(risparmioDaMostrare(0.50), isTrue);
  });

  test('sopraLaMedia vero solo per prezzo > media (colore rame)', () {
    final media = mediaZona(impianti, Carburante.benzina)!;
    expect(sopraLaMedia(imp('c', 2.000), Carburante.benzina, media), isTrue);
    expect(sopraLaMedia(imp('a', 1.800), Carburante.benzina, media), isFalse);
  });
}
