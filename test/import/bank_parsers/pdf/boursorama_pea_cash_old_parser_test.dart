import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/bank_parsers/pdf/boursorama_pea_cash_old_parser.dart';
import 'package:moopro/import/bank_parsers/statement_parser.dart';

import 'pdf_fixture_helpers.dart';

final _exampleJanPages = pageLayoutsFromText([
  r'''
Service Clientèle : 01 46 09 49 49 ou +33 146 09 49 49 depuis l'étranger, du lundi au vendredi de 8h à 20h et le samedi de 8h45 à 16h30 – www.boursobank.com
Boursorama S.A. au capital de 53 576 889,20 € - RCS Nanterre 351 058 151 - TVA 69 351 058 151 - 44 rue Traversière - CS 80134 - 92772 Boulogne Billancourt Cedex
Adresse du médiateur : Médiateur de l'AMF - 17, place de la Bourse - 75082 PARIS CEDEX 02
000000 F1 P617035 1/1
 000000
P617035

b&E<UEK<SU\!JfM+)T!MqDF(oent=x|+
~@'8	x&x**TaM? H SV?	FA
>
5X*n+ nTV
a!!!a!!a!aaaa!aaa!a!aaa!a!!a!aa!!!a!aa!aaa!aa!a!
M DOE JOHN
1 RUE VICTOR HUGO
75000 PARIS
AA1
RELEVE COMPTE ESPECES : JANVIER 2026
Feuillet 1/1
Edité le 30/01/2026
Extrait au 30/01/2026
Références de votre compte espèces
40618 80293 00090793214 Compte PEA
Résident Français
RELEVE D'IDENTITE BANCAIRE
Titulaire : MR DOE JOHN
Domiciliation : BOURSOBANK
30003 04970 00001104594 21
RIB du compte espèces : 40618 80293 00090793214 92
IBAN : FR76 12341 23412 12341234124 92
BIC - Adresse SWIFT : BOUSFRPPXXX
Date de
compta. Libellé de l'opération Quantité Nom de la valeur Débit EUR Crédit EUR
31/12/2025 ANCIEN SOLDE 640,60
02/01/2026 VIR Virement depuis BoursoBank 800,00
02/01/2026 ACHAT COMPTANT 10 AM.SP 500 ETF ACC 516,52
05/01/2026 COUPONS ECHEANCE 05/01 15 TOTALENERGIES SE 12,75
07/01/2026 SOUSCRIPTION D'OPC 2,337 PEA PROF.DYNAM.C5D 300,00
30/01/2026 ACHAT COMPTANT 10 AM.SP 500 ETF ACC 509,84
30/01/2026 ACHAT COMPTANT 1 AIR LIQUIDE 158,88
30/01/2026 VIR Virement depuis BoursoBank 600,00
31/01/2026 NOUVEAU SOLDE 568,11
Cumul des coupons : nets fiscaux encaissés depuis le 1er Janvier 2026 : 12,75 EUR
Protégé par la Garantie des Dépôts www.garantiedesdepots.fr
''',
]);
final _exampleMarPages = pageLayoutsFromText([
  r'''
Service Clientèle : 01 46 09 49 49 ou +33 146 09 49 49 depuis l'étranger, du lundi au vendredi de 8h à 20h et le samedi de 8h45 à 16h30 – www.boursobank.com
Boursorama S.A. au capital de 51 171 597,60 € - RCS Nanterre 351 058 151 - TVA 69 351 058 151 - 44 rue Traversière - CS 80134 - 92772 Boulogne Billancourt Cedex
Adresse du médiateur : Médiateur de l'AMF - 17, place de la Bourse - 75082 PARIS CEDEX 02
000000 F1 P328473 1/1
 000000
P328473

b&E;XEKs&E|!JfM+)T!MqDFxr#P-Zy	z+
~0G8	x&x))TaN1P SV.P!3\]	WWL-xXSV
a!!!a!!a!a!a!!aaa!a!aaa!a!!a!aa!!!a!a!aaaaa!a!a!
M DOE JOHN
1 RUE VICTOR HUGO
75000 PARIS
AA1
RELEVE COMPTE ESPECES : MARS 2025
Feuillet 1/1
Edité le 31/03/2025
Extrait au 31/03/2025
Références de votre compte espèces
40618 80293 00090793214 Compte PEA
Résident Français
RELEVE D'IDENTITE BANCAIRE
Titulaire : MR DOE JOHN
Domiciliation : BOURSOBANK
30003 04970 00001104594 21
RIB du compte espèces : 40618 80293 00090793214 92
IBAN : FR76 12341 23412 12341234124 92
BIC - Adresse SWIFT : BOUSFRPPXXX
Date de
compta. Libellé de l'opération Quantité Nom de la valeur Débit EUR Crédit EUR
28/02/2025 ANCIEN SOLDE 421,60
05/03/2025 ACHAT COMPTANT 1 AIR LIQUIDE 182,47
31/03/2025 ACHAT COMPTANT 1 AIR LIQUIDE 176,25
31/03/2025 NOUVEAU SOLDE 62,88
Cumul des coupons : nets fiscaux encaissés depuis le 1er Janvier 2025 : 11,85 EUR
Protégé par la Garantie des Dépôts www.garantiedesdepots.fr
''',
]);
void main() {
  final parser = BoursoramaPeaCashOldParser();

  test('canParse recognizes the old RELEVE COMPTE ESPECES format only', () {
    expect(parser.canParse(_exampleJanPages), isTrue);
    expect(parser.canParse(_exampleMarPages), isTrue);
    expect(
      parser.canParse(pageLayoutsFromText(const ['Compte à vue P.E.A.'])),
      isFalse,
    );
  });

  group(
    'January 2026 sample (two ambiguous transfers, both resolve as credits)',
    () {
      late StatementParseResult result;
      setUp(
        () =>
            result = parser.parse(_exampleJanPages, sourceFileName: 'jan.pdf'),
      );

      test('reconciles opening/closing balance with no row errors', () {
        expect(result.rowErrors, isEmpty);
        expect(result.balanceInfo?.openingBalance, Decimal.parse('640.60'));
        expect(result.balanceInfo?.closingBalance, Decimal.parse('568.11'));
        final sum = result.transactionCandidates.fold(
          Decimal.zero,
          (s, c) => s + c.amount,
        );
        expect(
          result.balanceInfo!.closingBalance! -
              result.balanceInfo!.openingBalance!,
          sum,
        );
      });

      test('resolves both ambiguous internal transfers as credits', () {
        final transfers = result.transactionCandidates
            .where((c) => c.description.contains('Virement depuis BoursoBank'))
            .toList();
        expect(transfers, hasLength(2));
        for (final t in transfers) {
          expect(t.amount > Decimal.zero, isTrue);
          expect(t.tags, contains('likely-self-transfer'));
        }
        expect(
          transfers.map((t) => t.amount),
          containsAll(<Decimal>[
            Decimal.parse('800.00'),
            Decimal.parse('600.00'),
          ]),
        );
      });

      test(
        'stages every ACHAT COMPTANT/SOUSCRIPTION D\'OPC row as a trade with a price candidate',
        () {
          final trades = result.transactionCandidates
              .where((c) => c.tradeAssetHint != null)
              .toList();
          expect(trades, hasLength(4));
          for (final t in trades) {
            expect(t.amount < Decimal.zero, isTrue);
          }
          expect(result.priceCandidates, hasLength(4));

          final fund = trades.firstWhere(
            (t) => t.tradeAssetHint == "PEA PROF.DYNAM.C5D",
          );
          expect(fund.amount, Decimal.parse('-300.00'));
          expect(fund.tradeAssetQuantity, Decimal.parse('2.337'));

          final etf = trades
              .where((t) => t.tradeAssetHint == 'AM.SP 500 ETF ACC')
              .toList();
          expect(etf, hasLength(2));
          expect(
            etf.map((c) => c.amount),
            containsAll(<Decimal>[
              Decimal.parse('-516.52'),
              Decimal.parse('-509.84'),
            ]),
          );
        },
      );

      test('stages the coupon row as plain income, no trade fields', () {
        final coupon = result.transactionCandidates.firstWhere(
          (c) => c.description.startsWith('COUPONS'),
        );
        expect(coupon.amount, Decimal.parse('12.75'));
        expect(coupon.tradeAssetHint, isNull);
      });

      test('extracts the account number from the RIB line', () {
        final hints = result.transactionCandidates
            .map((c) => c.containerHint)
            .toSet();
        expect(hints, hasLength(1));
        expect(hints.single, contains('40618'));
      });
    },
  );

  group('March 2025 sample (unambiguous purchases only)', () {
    late StatementParseResult result;
    setUp(
      () => result = parser.parse(_exampleMarPages, sourceFileName: 'mar.pdf'),
    );

    test('reconciles with no row errors and no ambiguous rows', () {
      expect(result.rowErrors, isEmpty);
      expect(result.balanceInfo?.openingBalance, Decimal.parse('421.60'));
      expect(result.balanceInfo?.closingBalance, Decimal.parse('62.88'));
      expect(result.transactionCandidates, hasLength(2));
      for (final c in result.transactionCandidates) {
        expect(c.tradeAssetHint, 'AIR LIQUIDE');
        expect(c.amount < Decimal.zero, isTrue);
      }
      final sum = result.transactionCandidates.fold(
        Decimal.zero,
        (s, c) => s + c.amount,
      );
      expect(
        result.balanceInfo!.closingBalance! -
            result.balanceInfo!.openingBalance!,
        sum,
      );
    });
  });

  group(
    'real sample 3 (several "VIR" label variants, from an anonymized real PDF)',
    () {
      late StatementParseResult result;
      setUp(
        () => result = parser.parse(
          loadPdfLayoutFixture('boursorama_pea_cash_old_real'),
          sourceFileName: 'real3.pdf',
        ),
      );

      test('reconciles opening/closing balance with no row errors', () {
        expect(result.rowErrors, isEmpty);
        expect(result.balanceInfo?.openingBalance, Decimal.zero);
        expect(result.balanceInfo?.closingBalance, Decimal.parse('110'));
      });

      test(
        'every "VIR" row, regardless of its exact wording, is tagged and resolved as a '
        'credit via column position, not flagged as unrecognized',
        () {
          final transfers = result.transactionCandidates
              .where((c) => c.description.startsWith('VIR'))
              .toList();
          expect(transfers, hasLength(3));
          for (final c in transfers) {
            expect(c.amount > Decimal.zero, isTrue, reason: c.description);
            expect(c.tags, contains('likely-self-transfer'));
          }
        },
      );
    },
  );

  group('defensive fallbacks', () {
    test(
      'defaults an ambiguous transfer to incoming and flags an error with no balance info',
      () {
        final pages = pageLayoutsFromText([
          '''
RELEVE COMPTE ESPECES : JANVIER 2023
01/01/2023 VIR Virement depuis BoursoBank 20,00
''',
        ]);
        final result = parser.parse(pages, sourceFileName: 'synthetic.pdf');
        expect(result.transactionCandidates, hasLength(1));
        expect(
          result.transactionCandidates.single.amount,
          Decimal.parse('20.00'),
        );
        expect(
          result.rowErrors.any(
            (e) => e.message.contains('Could not tell which'),
          ),
          isTrue,
        );
      },
    );

    test('flags an unrecognized row type and defaults it to an expense', () {
      final pages = pageLayoutsFromText([
        '''
RELEVE COMPTE ESPECES : JANVIER 2023
01/01/2023 MYSTERY OPERATION 12,00
''',
      ]);
      final result = parser.parse(pages, sourceFileName: 'synthetic2.pdf');
      expect(
        result.transactionCandidates.single.amount,
        Decimal.parse('-12.00'),
      );
      expect(
        result.rowErrors.any(
          (e) => e.message.contains('Could not tell whether'),
        ),
        isTrue,
      );
    });
  });
}
