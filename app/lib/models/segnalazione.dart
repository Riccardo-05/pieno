// Segnalazione di prezzo errato e "ritorno dopo il rifornimento" (Tappa 06, pag. 8/9).
// Senza backend restano sul dispositivo: la regola delle tre conferme è lato server.

class Segnalazione {
  final String impiantoId;
  final String nome;
  final double prezzoMostrato;
  final double? prezzoVisto;
  final String? nota;
  final DateTime quando;

  const Segnalazione({
    required this.impiantoId,
    required this.nome,
    required this.prezzoMostrato,
    required this.prezzoVisto,
    required this.nota,
    required this.quando,
  });

  Map<String, dynamic> toJson() => {
        'id': impiantoId,
        'n': nome,
        'pm': prezzoMostrato,
        'pv': prezzoVisto,
        'nota': nota,
        't': quando.toIso8601String(),
      };

  factory Segnalazione.fromJson(Map<String, dynamic> j) => Segnalazione(
        impiantoId: j['id'] as String,
        nome: j['n'] as String? ?? '',
        prezzoMostrato: (j['pm'] as num).toDouble(),
        prezzoVisto: (j['pv'] as num?)?.toDouble(),
        nota: j['nota'] as String?,
        quando: DateTime.tryParse(j['t'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Rifornimento in sospeso: impostato quando si preme «Portami qui», usato al ritorno
/// per chiedere se il pieno è stato fatto e se il prezzo corrispondeva.
class Rientro {
  final String impiantoId;
  final String nome;
  final double prezzoMostrato;
  final DateTime quando;

  const Rientro({
    required this.impiantoId,
    required this.nome,
    required this.prezzoMostrato,
    required this.quando,
  });

  Map<String, dynamic> toJson() => {
        'id': impiantoId,
        'n': nome,
        'pm': prezzoMostrato,
        't': quando.toIso8601String(),
      };

  factory Rientro.fromJson(Map<String, dynamic> j) => Rientro(
        impiantoId: j['id'] as String,
        nome: j['n'] as String? ?? '',
        prezzoMostrato: (j['pm'] as num).toDouble(),
        quando: DateTime.tryParse(j['t'] as String? ?? '') ?? DateTime.now(),
      );
}
