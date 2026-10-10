import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/bank_parsers/pdf/fortuneo_ldds_parser.dart';
import 'package:moopro/import/bank_parsers/statement_parser.dart';

import 'pdf_fixture_helpers.dart';
import 'package:moopro/domain/calendar_date.dart';

final _example2Pages = pageLayoutsFromText([
  r'''
Titulaire(s) du compte : M DOE JOHN
N° 1 - 2025
FORTUNEO
TOUR TRINITY
1B PLACE DE LA DEFENSE
92400 COURBEVOIE
Compte 9148029 58
Relevé LDDS
0267
M DOE JOHN
1 RUE DE VICTOR HUGO
75000 PARIS
Page 1/1
SERVICE CLIENTS TEL 0 811 135 135
SERVICE CLIENTS FAX 0 820 820 407
SOS CARTES 02 98 28 42 28
SITE INTERNET www.fortuneo.fr
Émis le 03/01/2026 Réf : JFEINJ
Arrêté au 31 décembre 2025
Fortuneo est une marque commerciale d’Arkéa Direct Bank. Arkéa Direct Bank, Société Anonyme à Directoire et Conseil de Surveillance au capital de 89 198 952 euros.
 RCS Nanterre 384 288 890. Siège social : Tour Trinity 1 bis place de la Défense, 92400 Courbevoie. Adresse postale : TSA 41707 - 35917 RENNES CEDEX 9.
 Horaires Service Clients : du lundi au vendredi de 08h30 à 20h00 (de 08h00 jusqu’à 22h00 pour les ordres de bourse) et le samedi de 09h00 à 13h30.
 Ce document est unique et personnel. Conservez-le confidentiellement sans limitation de durée.
 Pour toute demande portant sur la bonne exécution d’un contrat et le traitement d’une réclamation, vous pouvez contacter :
 1 - Le Service Clients via le site "www.fortuneo.fr" , Rubrique « Nous contacter » ou par courrier adressé TSA 41707 - 35917 RENNES CEDEX 9.
 2 - En cas de difficultés persistantes, le Service Réclamations par courrier adressé TSA 41707 - 35917 RENNES CEDEX 9 ou au 02 98 42 65 34.
 3 - Et en ultime étape de conciliation, et uniquement dans les cas relevant de sa compétence, le Médiateur auprés de Fortuneo. Saisine soit à l’adresse postale :
 Monsieur Le Médiateur 29809 BREST CEDEX 9, soit sur le site : https://lemediateur.creditmutuelarkea.fr/
Date Date de Valeur Opération Débit Crédit
ANCIEN SOLDE CRÉDITEUR AU 31 DÉCEMBRE 2024 8 299,06 €
 04/01 16/01/2025 VIR Virement avec Fortuneo LDDS 700,94
08/01 16/01/2025 VIR Virement avec Fortuneo LDDS 1 000,00
31/01 01/02/2025 VIR 1 000,00
06/02 16/02/2025 VIR 500,00
15/02 16/02/2025 VIR 500,00
25/11 16/11/2025 VIR M DOE JOHN 11 990,00
28/11 01/12/2025 VIR 3 000,00
05/12 16/12/2025 VIR 990,00
09/12 16/12/2025 VIR 1 500,00
31/12 01/01/2026 VIR 3 500,00
31/12 01/01/2026 INTERETS 2025 231,40

 TOTAL DES OPÉRATIONS DU RELEVÉ 11 990,00 12 922,34
NOUVEAU SOLDE CRÉDITEUR AU 31 DÉCEMBRE 2025 9 231,40 €
 Garantie de vos dépôts
Votre compte bénéficie de la Garantie de l'Etat (www.garantiedesdepots.fr)
''',
]);

class _Expected {
  final DateTime posting;
  final DateTime effective;
  final String amount;
  final String description;
  final List<String> tags;
  const _Expected(
    this.posting,
    this.effective,
    this.amount,
    this.description, {
    this.tags = const [],
  });
}

void _expectCandidates(
  List<StagedTransactionCandidate> actual,
  List<_Expected> expected,
) {
  expect(actual.length, expected.length, reason: 'candidate count mismatch');
  for (var i = 0; i < expected.length; i++) {
    final a = actual[i];
    final e = expected[i];
    expect(a.postingDate, e.posting, reason: 'row $i postingDate');
    expect(
      a.effectiveDate,
      CalendarDate.fromDateTime(e.effective),
      reason: 'row $i effectiveDate',
    );
    expect(a.amount, Decimal.parse(e.amount), reason: 'row $i amount');
    expect(a.description, e.description, reason: 'row $i description');
    expect(a.tags, e.tags, reason: 'row $i tags');
  }
}

void main() {
  final parser = FortuneoLddsParser();

  group('canParse', () {
    test('recognizes a Fortuneo "Relevé LDDS" statement', () {
      expect(parser.canParse(_example2Pages), isTrue);
    });

    test('rejects unrelated content', () {
      expect(
        parser.canParse(pageLayoutsFromText(['some other bank entirely'])),
        isFalse,
      );
    });

    test(
      'rejects a Fortuneo checking account statement (different account type)',
      () {
        expect(
          parser.canParse(
            pageLayoutsFromText([
              'FORTUNEO',
              'COMPTE COURANT',
              'Relevé de Compte',
            ]),
          ),
          isFalse,
        );
      },
    );
  });

  test(
    'example 2: interest is always income, and the sole outgoing transfer is resolved by '
    'matching a subset of transfer amounts to the stated debit total — even though the '
    'description text alone can\'t tell it apart from an incoming one (both print "VIR M '
    'DOE JOHN"-style holder names) and a competing 8-transfer combination would sum to the '
    'exact same total',
    () {
      final result = parser.parse(
        _example2Pages,
        sourceFileName: 'example2.pdf',
      );

      expect(result.rowErrors, isEmpty);
      expect(result.balanceInfo?.openingBalance, Decimal.parse('8299.06'));
      expect(result.balanceInfo?.closingBalance, Decimal.parse('9231.40'));

      const selfTransfer = ['likely-self-transfer'];
      _expectCandidates(result.transactionCandidates, [
        _Expected(
          DateTime(2025, 1, 4),
          DateTime(2025, 1, 16),
          '700.94',
          'VIR Virement avec Fortuneo LDDS',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 1, 8),
          DateTime(2025, 1, 16),
          '1000.00',
          'VIR Virement avec Fortuneo LDDS',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 1, 31),
          DateTime(2025, 2, 1),
          '1000.00',
          'VIR',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 2, 6),
          DateTime(2025, 2, 16),
          '500.00',
          'VIR',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 2, 15),
          DateTime(2025, 2, 16),
          '500.00',
          'VIR',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 11, 25),
          DateTime(2025, 11, 16),
          '-11990.00',
          'VIR M DOE JOHN',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 11, 28),
          DateTime(2025, 12, 1),
          '3000.00',
          'VIR',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 12, 5),
          DateTime(2025, 12, 16),
          '990.00',
          'VIR',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 12, 9),
          DateTime(2025, 12, 16),
          '1500.00',
          'VIR',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 12, 31),
          DateTime(2026, 1, 1),
          '3500.00',
          'VIR',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 12, 31),
          DateTime(2026, 1, 1),
          '231.40',
          'INTERETS 2025',
        ),
      ]);
    },
  );

  test(
    'no combination of transfer amounts matches the stated debit total: defaults every '
    'transfer to incoming and flags it instead of guessing',
    () {
      const page = '''
FORTUNEO
Relevé LDDS
Compte 123 45
ANCIEN SOLDE CRÉDITEUR AU 01 JANVIER 2024 1 000,00 €
01/01 01/01/2024 VIR 100,00
02/01 02/01/2024 VIR 200,00
TOTAL DES OPÉRATIONS DU RELEVÉ 999,00 300,00
NOUVEAU SOLDE CRÉDITEUR AU 31 JANVIER 2024 1 300,00 €
''';
      final result = parser.parse(
        pageLayoutsFromText([page]),
        sourceFileName: 'nomatch.pdf',
      );

      expect(result.transactionCandidates, hasLength(2));
      expect(
        result.transactionCandidates.every((c) => c.amount > Decimal.zero),
        isTrue,
      );
      expect(
        result.rowErrors.any((e) => e.message.contains('no combination')),
        isTrue,
      );
    },
  );

  test(
    'no stated totals at all: defaults every transfer to incoming and flags it instead of '
    'guessing',
    () {
      const page = '''
FORTUNEO
Relevé LDDS
Compte 123 45
ANCIEN SOLDE CRÉDITEUR AU 01 JANVIER 2024 1 000,00 €
01/01 01/01/2024 VIR 100,00
NOUVEAU SOLDE CRÉDITEUR AU 31 JANVIER 2024 1 100,00 €
''';
      final result = parser.parse(
        pageLayoutsFromText([page]),
        sourceFileName: 'nototals.pdf',
      );

      expect(result.transactionCandidates, hasLength(1));
      expect(
        result.transactionCandidates.single.amount,
        Decimal.parse('100.00'),
      );
      expect(
        result.rowErrors.any((e) => e.message.contains('does not state')),
        isTrue,
      );
    },
  );

  test('an unrecognized operation type defaults to expense and is flagged', () {
    const page = '''
FORTUNEO
Relevé LDDS
Compte 123 45
ANCIEN SOLDE CRÉDITEUR AU 01 JANVIER 2024 1 000,00 €
01/01 01/01/2024 SOME UNRECOGNIZED LABEL 50,00
TOTAL DES OPÉRATIONS DU RELEVÉ 50,00 0,00
NOUVEAU SOLDE CRÉDITEUR AU 31 JANVIER 2024 950,00 €
''';
    final result = parser.parse(
      pageLayoutsFromText([page]),
      sourceFileName: 'unrecognized.pdf',
    );

    expect(result.transactionCandidates, hasLength(1));
    expect(result.transactionCandidates.single.amount, Decimal.parse('-50.00'));
    expect(
      result.rowErrors.any(
        (e) => e.message.contains('Unrecognized LDDS operation type'),
      ),
      isTrue,
    );
  });
}
