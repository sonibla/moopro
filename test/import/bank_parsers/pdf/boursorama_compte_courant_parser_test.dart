import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/bank_parsers/pdf/boursorama_compte_courant_parser.dart';
import 'package:moopro/import/bank_parsers/statement_parser.dart';

import 'pdf_fixture_helpers.dart';

final _example1Pages = pageLayoutsFromText([
  r'''
Boursorama - Société Anonyme au capital de 43 774 464,00 ¤ - RCS Nanterre 351 058 151 - TVA 69 351 058 151 - N° ORIAS 07 022 916
44 rue Traversière - CS 80134 - 92772 Boulogne Billancourt Cedex - e www.boursorama.com
Service Clientèle : 01 46 09 49 49 ou +33 146 09 49 49 depuis l'étranger, du lundi au vendredi de 8h à 22h et le samedi de 8h45 à 16h30
Adresse du médiateur : Monsieur le médiateur – BP 151 – 75422 PARIS Cedex 09
Date N° de RIB Devise Période Montant DA* TAEG* Page
Banque Guichet N° de compte Clé RIB
30/04/2022 40618 80368 00040457950 9 EUR du 01/04/2022 au 29/04/2022 0,00 ¤ 0,000000 % 1/2
Mod.25.91520-99
M DOE JOHN
1 RUE VICTOR HUGO
75000 PARIS
Extrait de votre compte en EUR
(Protégé par la Garantie des Dépôts www.garantiedesdepots.fr)
BOURSORAMA BANQUE
A réception d'un extrait de compte vous disposez d'un délai de quatre mois pour formulertoute réclamation auprès de votre service clientèle.
A défaut d'observation dans ce délai, nous considérons votre silence comme une approbation tacite des comptes.
* Montant de l'autorisation de découvert associée à votre compte, valeur du TAEG (Taux Annualisé Effectif Global) et total des frais bancaires pour la période.
B.I.C. BOUSFRPPXXX I.B.A.N. FR76 1234 1234 1234 1234 1234 009
MOUVEMENTS EN EUR
Date
opération Libellé Valeur Débit Crédit
SOLDE AU : 31/03/2022 2.845,51
01/04/2022 VIR SEPA DOE JOHN 01/04/2022 432,98
-
Réf : 2209093147270001
01/04/2022 VIR SEPA DOE JOHN 01/04/2022 267,10
Réf : AGRIFRPP861C0120220331131831454917
08/04/2022 PRLV SEPA SNCF SA VOYAGEURS 08/04/2022 57,00
Prelevement SEPA abonnement annuel SNCF
- 87165340001202203
9422084CUUYQWSDT
RUM: AATPS00000LOR26SLI038094100000
13/04/2022 VIR SEPA DOE JOHN 13/04/2022 358,20
Réf : 2210211714880001
19/04/2022 VIR SEPA DOE JOHN 19/04/2022 300,00
Réf : AGRIFRPP861C0120220414125556336393
28/04/2022 VIR SEPA DOE JOHN 28/04/2022 255,00
Réf : AGRIFRPP861C0120220428115040317310
''',
  r'''
Boursorama - Société Anonyme au capital de 43 774 464,00 ¤ - RCS Nanterre 351 058 151 - TVA 69 351 058 151 - N° ORIAS 07 022 916
44 rue Traversière - CS 80134 - 92772 Boulogne Billancourt Cedex - e www.boursorama.com
Service Clientèle : 01 46 09 49 49 ou +33 146 09 49 49 depuis l'étranger, du lundi au vendredi de 8h à 22h et le samedi de 8h45 à 16h30
Adresse du médiateur : Monsieur le médiateur – BP 151 – 75422 PARIS Cedex 09
A réception d'un extrait de compte vous disposez d'un délai de quatre mois pour formulertoute réclamation auprès de votre service clientèle.
A défaut d'observation dans ce délai, nous considérons votre silence comme une approbation tacite des comptes.
* Montant de l'autorisation de découvert associée à votre compte, valeur du TAEG (Taux Annualisé Effectif Global) et total des frais bancaires pour la période. Mod.25.91520-99
Date N° de RIB Devise Période MontantDA* TAEG* Page
Banque Guichet N° de compte Clé RIB
30/04/2022 40618 80368 00040457950 9 EUR du 01/04/2022 au 29/04/2022 0,00 ¤ 0,000000 % 2/2
B.I.C. BOUSFRPPXXX I.B.A.N. FR76 4061 8803 6800 0404 5795 009
MOUVEMENTS EN EUR
Nouveau solde en EUR :
Montant frais bancaires* :
0,00
5.280,79
0,00
Date
opération Libellé Valeur Débit Crédit
28/04/2022 VIR SEPA John Doe 28/04/2022 390,00
-
32ac32b268c8461a864dad6b3872b052
Réf : 32ac32b268c8461a864dad6b3872b052
29/04/2022 VIR SEPA DOE JOHN 29/04/2022 489,00
-
Réf : 2211830958240001
''',
]);
final _example2Pages = pageLayoutsFromText([
  r'''
Boursorama - SA au capital de 53 576 889,20 ¤ - RCS Nanterre 351 058 151 - TVA 69 351 058 151 - N° ORIAS 07 022 916
44 rue Traversière - CS 80134 - 92772 Boulogne Billancourt Cedex - www.boursobank.com
Service Clientèle : 01 46 09 49 49 ou +33 146 09 49 49 depuis l'étranger, du lundi au vendredi de 8h à 20h et le samedi de 8h45 à 16h30
Adresse du médiateur : Monsieur le médiateur – BP 151 – 75422 PARIS Cedex 09
Date N° de RIB Devise Période Montant DA* TAEG* Page
Banque Guichet N° de compte Clé RIB
30/05/2026 40618 80368 00040457950 09 EUR du 01/05/2026 au 29/05/2026 0,00 ¤ 0,000000 % 1/2
Mod.25.91520-99
Extrait de votre compte en EUR
(Protégé par la Garantie des Dépôts www.garantiedesdepots.fr)
BOURSOBANK
A réception d'un extrait de compte vous disposez d'un délai de quatre mois pour formulertoute réclamation auprès de votre service clientèle.
A défaut d'observation dans ce délai, nous considérons votre silence comme une approbation tacite des comptes.
* Montant de l'autorisation de découvert associée à votre compte, valeur du TAEG (Taux Annualisé Effectif Global) et total des frais bancaires pour la période.
M DOE JOHN
1 RUE VICTOR HUGO
75000 PARIS
B.I.C. BOUSFRPPXXX I.B.A.N. FR76 1234 1234 1234 1234 1234 009
MOUVEMENTS EN EUR
Date
opération Libellé Valeur Débit Crédit
SOLDE AU : 30/04/2026 2.022,83
05/05/2026 PRLV SEPA BOUYGUES TELECOM 05/05/2026 7,99
06xxxxx642
03764N2202662028867649
RUM BT1150W2M1W45
08/05/2026 PRLV SEPA SNCF VOYAGEURS - TER 08/05/2026 105,90
8926125AYBTAZSDT
RUM NAS00000LORUF0701029225177339488226
11/05/2026 VIR Virement depuis BoursoBank 11/05/2026 500,00
DOE JOHN
Rèf : SCT406182026051100675429676
21/05/2026 VIR SEPA LEMONWAY 21/05/2026 104,63
LENDIX-1998032
7278566
Rèf ZZ1KI3RNZBS8VY34FZZ1KI3RO0IZWXAXU7
25/05/2026 VIR SEPA LEMONWAY 25/05/2026 98,37
LENDIX-1999584
7293710
Rèf ZZ1KIYFG49PTXYBD7ZZ1KIYFG9RK5YBD6Z
''',
  r'''
Boursorama - SA au capital de 53 576 889,20 ¤ - RCS Nanterre 351 058 151 - TVA 69 351 058 151 - N° ORIAS 07 022 916
44 rue Traversière - CS 80134 - 92772 Boulogne Billancourt Cedex - www.boursobank.com
Service Clientèle : 01 46 09 49 49 ou +33 146 09 49 49 depuis l'étranger, du lundi au vendredi de 8h à 20h et le samedi de 8h45 à 16h30
Adresse du médiateur : Monsieur le médiateur – BP 151 – 75422 PARIS Cedex 09
A réception d'un extrait de compte vous disposez d'un délai de quatre mois pour formulertoute réclamation auprès de votre service clientèle.
A défaut d'observation dans ce délai, nous considérons votre silence comme une approbation tacite des comptes.
* Montant de l'autorisation de découvert associée à votre compte, valeur du TAEG (Taux Annualisé Effectif Global) et total des frais bancaires pour la période. Mod.25.91520-99
Date N° de RIB Devise Période MontantDA* TAEG* Page
Banque Guichet N° de compte Clé RIB
30/05/2026 40618 80368 00040457950 09 EUR du 01/05/2026 au 29/05/2026 0,00 ¤ 0,000000 % 2/2
B.I.C. BOUSFRPPXXX I.B.A.N. FR76 4061 8803 6800 0404 5795 009
MOUVEMENTS EN EUR
Nouveau solde en EUR :
Montant frais bancaires* :
0,00
1.589,95
0,00
Date
opération Libellé Valeur Débit Crédit
29/05/2026 PRLV SEPA FREE MOBILE 29/05/2026 21,99
7126147D4LVDXSDT
RUM FM-96750176-3
''',
]);
void main() {
  final parser = BoursoramaCompteCourantParser();

  test('canParse recognizes both branding eras, rejects PEA statements', () {
    expect(parser.canParse(_example1Pages), isTrue);
    expect(parser.canParse(_example2Pages), isTrue);
    expect(
      parser.canParse(
        pageLayoutsFromText(const [
          'Compte à vue P.E.A. MOUVEMENTS EN EUR Extrait de votre compte en EUR',
        ]),
      ),
      isFalse,
    );
  });

  group('legacy "Boursorama Banque" sample (example 1)', () {
    late StatementParseResult result;
    setUp(
      () => result = parser.parse(_example1Pages, sourceFileName: 'cc1.pdf'),
    );

    test('reconciles opening/closing balance with no unaccounted rows', () {
      expect(result.balanceInfo?.openingBalance, Decimal.parse('2845.51'));
      expect(result.balanceInfo?.closingBalance, Decimal.parse('5280.79'));
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

    test('parses every row with the right sign, and no row errors', () {
      expect(result.rowErrors, isEmpty);
      expect(result.transactionCandidates, hasLength(8));
      final amounts = result.transactionCandidates
          .map((c) => c.amount)
          .toList();
      expect(
        amounts,
        containsAll(<Decimal>[
          Decimal.parse('432.98'),
          Decimal.parse('267.10'),
          Decimal.parse('-57.00'),
          Decimal.parse('358.20'),
          Decimal.parse('300.00'),
          Decimal.parse('255.00'),
          Decimal.parse('390.00'),
          Decimal.parse('489.00'),
        ]),
      );
    });

    test(
      'strips the bare "-" continuation-line artifact from descriptions',
      () {
        final sncf = result.transactionCandidates.firstWhere(
          (c) => c.amount == Decimal.parse('-57.00'),
        );
        expect(sncf.description, contains('87165340001202203'));
        expect(sncf.description, isNot(contains('- 87165340001202203')));
        expect(sncf.description, isNot(startsWith('-')));
      },
    );

    test(
      'tags VIR SEPA rows mentioning the holder as likely-self-transfer',
      () {
        final vir = result.transactionCandidates.firstWhere(
          (c) => c.amount == Decimal.parse('432.98'),
        );
        expect(vir.tags, contains('likely-self-transfer'));
        final prlv = result.transactionCandidates.firstWhere(
          (c) => c.amount == Decimal.parse('-57.00'),
        );
        expect(prlv.tags, isNot(contains('likely-self-transfer')));
      },
    );

    test('every candidate carries the same holder container hint', () {
      final hints = result.transactionCandidates
          .map((c) => c.containerHint)
          .toSet();
      expect(hints, hasLength(1));
      expect(hints.single, contains('40618'));
    });
  });

  group(
    'rebranded "BoursoBank" sample with an ambiguous internal transfer (example 2)',
    () {
      late StatementParseResult result;
      setUp(
        () => result = parser.parse(_example2Pages, sourceFileName: 'cc2.pdf'),
      );

      test('reconciles opening/closing balance with no unaccounted rows', () {
        expect(result.balanceInfo?.openingBalance, Decimal.parse('2022.83'));
        expect(result.balanceInfo?.closingBalance, Decimal.parse('1589.95'));
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
        'resolves "VIR Virement depuis BoursoBank" as an outgoing transfer via reconciliation',
        () {
          expect(result.rowErrors, isEmpty);
          final internal = result.transactionCandidates.firstWhere(
            (c) => c.description.contains('Virement depuis BoursoBank'),
          );
          expect(internal.amount, Decimal.parse('-500.00'));
          expect(internal.tags, contains('likely-self-transfer'));
        },
      );

      test(
        'LemonWay credits are not tagged as a self-transfer (no holder name match)',
        () {
          final lemonway = result.transactionCandidates
              .where((c) => c.description.contains('LEMONWAY'))
              .toList();
          expect(lemonway, hasLength(2));
          for (final c in lemonway) {
            expect(c.amount > Decimal.zero, isTrue);
            expect(c.tags, isNot(contains('likely-self-transfer')));
          }
        },
      );

      test('direct debits are always negative', () {
        final debits = result.transactionCandidates.where(
          (c) => c.description.startsWith('PRLV'),
        );
        expect(debits, hasLength(3));
        for (final c in debits) {
          expect(c.amount < Decimal.zero, isTrue);
        }
      });
    },
  );

  group(
    'real sample 2 (column-position sign detection, from an anonymized real PDF)',
    () {
      late StatementParseResult result;
      setUp(
        () => result = parser.parse(
          loadPdfLayoutFixture('boursorama_compte_courant_real'),
          sourceFileName: 'real2.pdf',
        ),
      );

      test('reconciles opening/closing balance with no row errors', () {
        expect(result.rowErrors, isEmpty);
        expect(result.balanceInfo?.openingBalance, Decimal.parse('11622.07'));
        expect(result.balanceInfo?.closingBalance, Decimal.parse('3005.20'));
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
        'every "VIR INST <name>" row (some with "Virement depuis BoursoBank" trailing as a '
        'continuation line, some without) resolves as a debit via column position — the '
        'opposite of what the keyword-only default would guess (an unqualified "vir" row '
        'defaults to credit, and this description never matches _internalTransferPattern '
        'since "Virement depuis BoursoBank" is a continuation line rather than the '
        'description\'s own prefix, so the old code would never even have reached the '
        'balance-solver fallback for these rows at all — see the class doc comment\'s '
        '"confirmed fragile" note)',
        () {
          final linked = result.transactionCandidates
              .where((c) => c.description.startsWith('VIR INST'))
              .toList();
          expect(linked, hasLength(7));
          for (final c in linked) {
            expect(c.amount < Decimal.zero, isTrue, reason: c.description);
            expect(c.tags, contains('likely-self-transfer'));
          }
        },
      );

      test(
        'direct debits (PRLV) are still correctly negative via column position',
        () {
          final debits = result.transactionCandidates.where(
            (c) => c.description.startsWith('PRLV'),
          );
          expect(debits, hasLength(4));
          for (final c in debits) {
            expect(c.amount < Decimal.zero, isTrue);
          }
        },
      );
    },
  );

  group('defensive fallbacks', () {
    test(
      'defaults an ambiguous internal transfer to incoming and flags an error when balance '
      'reconciliation is unavailable',
      () {
        final pages = pageLayoutsFromText([
          '''
MOUVEMENTS EN EUR
Extrait de votre compte en EUR
Date
operation Libelle Valeur Debit Credit
01/01/2023 PRLV SEPA TEST 01/01/2023 10,00
02/01/2023 VIR Virement depuis BoursoBank 02/01/2023 20,00
''',
        ]);
        final result = parser.parse(pages, sourceFileName: 'synthetic.pdf');
        expect(result.transactionCandidates, hasLength(2));
        final internal = result.transactionCandidates.firstWhere(
          (c) => c.amount.abs() == Decimal.parse('20.00'),
        );
        expect(internal.amount, Decimal.parse('20.00'));
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
MOUVEMENTS EN EUR
Extrait de votre compte en EUR
Date
operation Libelle Valeur Debit Credit
SOLDE AU : 01/01/2023 100,00
03/01/2023 CHQ 123456 03/01/2023 15,00
''',
      ]);
      final result = parser.parse(pages, sourceFileName: 'synthetic2.pdf');
      expect(result.transactionCandidates, hasLength(1));
      expect(
        result.transactionCandidates.single.amount,
        Decimal.parse('-15.00'),
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
