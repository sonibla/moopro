import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/bank_parsers/pdf/boursorama_pea_cash_parser.dart';
import 'package:moopro/import/bank_parsers/statement_parser.dart';

import 'pdf_fixture_helpers.dart';
import 'package:moopro/domain/calendar_date.dart';

final _examplePages = pageLayoutsFromText([
  r'''
Boursorama - SA au capital de 53 576 889,20 ¤ - RCS Nanterre 351 058 151 - TVA 69 351 058 151 - N° ORIAS 07 022 916
44 rue Traversière - CS 80134 - 92772 Boulogne Billancourt Cedex - www.boursobank.com
Service Clientèle : 01 46 09 49 49 ou +33 146 09 49 49 depuis l'étranger, du lundi au vendredi de 8h à 20h et le samedi de 8h45 à 16h30
Adresse du médiateur : Monsieur le médiateur – BP 151 – 75422 PARIS Cedex 09
A réception d'un extrait de compte vous disposez d'un délai de quatre mois pour formulertoute réclamation auprès de votre service clientèle.
A défaut d'observation dans ce délai, nous considérons votre silence comme une approbation tacite des comptes.
* Montant de l'autorisation de découvert associée à votre compte, valeur du TAEG (Taux Annualisé Effectif Global) et total des frais bancaires pour la période.
Date N° de RIB Devise Période Page
Banque Guichet N° de Compte Clé RIB
02/06/2026 40618 80293 00090793214 92 EUR Du 01/05/2026 au 29/05/2026 1/1
Mod.25.91520-99
M DOE JOHN
1 RUE VICTOR HUGO
75000 PARIS
Extrait de votre compte en EUR
(Protégé par la Garantie des Dépôts www.garantiedesdepots.fr)
Compte à vue P.E.A.
B.I.C. BOUSFRPPXXX I.B.A.N. FR76 1234 1234 1234 1234 1234 492
Nouveau solde en EUR : 1 507,25
Cumul des coupons : nets fiscaux encaissés depuis le 1er janvier 2026 : 132,90 EUR
Date opération Libellé Date
Valeur
Débit
EUR
Crédit
EUR
Solde au 30/04/2026 84,17
11/05/2026 VIR Virement depuis BoursoBank 11/05/2026 500,00
DOE JOHN
11/05/2026 ACHAT COMPTANT 13/05/2026 176,82
Nom de la valeur: AIR LIQUIDE
Quantité: 1
20/05/2026 COUPONS ECHEANCE 20/05 20/05/2026 92,50
Nom de la valeur: AIR LIQUIDE
Quantité: 25
20/05/2026 COUPONS ECHEANCE 20/05 20/05/2026 7,40
Nom de la valeur: AIR LIQUIDE PF27
Quantité: 2
''',
]);
void main() {
  final parser = BoursoramaPeaCashParser();

  test(
    'canParse recognizes the PEA cash statement, rejects a checking-account one',
    () {
      expect(parser.canParse(_examplePages), isTrue);
      expect(
        parser.canParse(
          pageLayoutsFromText(const [
            'MOUVEMENTS EN EUR Extrait de votre compte en EUR',
          ]),
        ),
        isFalse,
      );
    },
  );

  group('real sample', () {
    late StatementParseResult result;
    setUp(
      () => result = parser.parse(_examplePages, sourceFileName: 'pea.pdf'),
    );

    test(
      'works around the spurious leading "1 " in "Nouveau solde en EUR" via reconciliation',
      () {
        expect(result.balanceInfo?.openingBalance, Decimal.parse('84.17'));
        expect(result.balanceInfo?.closingBalance, Decimal.parse('507.25'));
        expect(
          result.balanceInfo?.closingBalance,
          isNot(Decimal.parse('1507.25')),
        );
      },
    );

    test('parses all 4 rows with no row errors, reconciling exactly', () {
      expect(result.rowErrors, isEmpty);
      expect(result.transactionCandidates, hasLength(4));
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

    test(
      'resolves the ambiguous internal transfer as a credit via balance reconciliation',
      () {
        final transfer = result.transactionCandidates.firstWhere(
          (c) => c.description.contains('Virement depuis BoursoBank'),
        );
        expect(transfer.amount, Decimal.parse('500.00'));
        expect(transfer.tags, contains('likely-self-transfer'));
        expect(transfer.tradeAssetHint, isNull);
      },
    );

    test(
      'stages the ACHAT COMPTANT row as a trade with a paired price candidate',
      () {
        final achat = result.transactionCandidates.firstWhere(
          (c) => c.description.startsWith('ACHAT'),
        );
        expect(achat.amount, Decimal.parse('-176.82'));
        expect(achat.tradeAssetHint, 'AIR LIQUIDE');
        expect(achat.tradeAssetQuantity, Decimal.parse('1'));
        expect(achat.effectiveDate, CalendarDate(2026, 5, 13));
        expect(achat.postingDate, DateTime(2026, 5, 11));

        expect(result.priceCandidates, hasLength(1));
        final price = result.priceCandidates.single;
        expect(price.assetHint, 'AIR LIQUIDE');
        expect(price.price, Decimal.parse('176.82'));
        expect(price.currencyHint, 'EUR');
        expect(price.date, DateTime(2026, 5, 13));
      },
    );

    test(
      'stages coupon rows as plain income with no trade/price candidates',
      () {
        final coupons = result.transactionCandidates
            .where((c) => c.description.startsWith('COUPONS'))
            .toList();
        expect(coupons, hasLength(2));
        for (final c in coupons) {
          expect(c.amount > Decimal.zero, isTrue);
          expect(c.tradeAssetHint, isNull);
        }
        expect(
          coupons.map((c) => c.amount),
          containsAll(<Decimal>[Decimal.parse('92.50'), Decimal.parse('7.40')]),
        );
      },
    );
  });

  group(
    'real sample 2 ("Reprise solde compte" carried-over balance, from an anonymized real PDF)',
    () {
      late StatementParseResult result;
      setUp(
        () => result = parser.parse(
          loadPdfLayoutFixture('boursorama_pea_cash_reprise_solde_real'),
          sourceFileName: 'reprise.pdf',
        ),
      );

      test(
        'recognizes "Reprise solde compte" as a credit, not an unrecognized row',
        () {
          expect(result.rowErrors, isEmpty);
          final reprise = result.transactionCandidates.firstWhere(
            (c) => c.description.startsWith('Reprise solde compte'),
          );
          expect(reprise.amount, Decimal.parse('198.28'));
          expect(reprise.tags, contains('account-balance-carryover'));
          expect(reprise.tags, isNot(contains('likely-self-transfer')));
        },
      );

      test(
        'reconciles opening 0 against the closing balance despite the spurious leading "1 "',
        () {
          expect(result.balanceInfo?.openingBalance, Decimal.zero);
          expect(result.balanceInfo?.closingBalance, Decimal.parse('198.28'));
          expect(
            result.balanceInfo?.closingBalance,
            isNot(Decimal.parse('1198.28')),
          );
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
Compte à vue P.E.A.
Date opération Libellé Date
01/01/2023 VIR Virement depuis BoursoBank 01/01/2023 20,00
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

    test(
      'flags a trade row missing "Nom de la valeur"/"Quantité" and stages it as a plain expense',
      () {
        final pages = pageLayoutsFromText([
          '''
Compte à vue P.E.A.
Date opération Libellé Date
01/01/2023 ACHAT COMPTANT 01/01/2023 50,00
''',
        ]);
        final result = parser.parse(pages, sourceFileName: 'synthetic2.pdf');
        expect(result.transactionCandidates, hasLength(1));
        final c = result.transactionCandidates.single;
        expect(c.amount, Decimal.parse('-50.00'));
        expect(c.tradeAssetHint, isNull);
        expect(result.priceCandidates, isEmpty);
        expect(
          result.rowErrors.any((e) => e.message.contains('Nom de la valeur')),
          isTrue,
        );
      },
    );

    test('flags an unrecognized row type and defaults it to an expense', () {
      final pages = pageLayoutsFromText([
        '''
Compte à vue P.E.A.
Date opération Libellé Date
01/01/2023 MYSTERY OPERATION 01/01/2023 12,00
''',
      ]);
      final result = parser.parse(pages, sourceFileName: 'synthetic3.pdf');
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
