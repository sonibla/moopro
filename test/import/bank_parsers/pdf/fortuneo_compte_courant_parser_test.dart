import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/bank_parsers/pdf/fortuneo_compte_courant_parser.dart';
import 'package:moopro/import/bank_parsers/statement_parser.dart';

import 'pdf_fixture_helpers.dart';
import 'package:moopro/domain/calendar_date.dart';

final _example1Pages = pageLayoutsFromText([
  r'''
Titulaire(s) du compte : M DOE JOHN
NUMÉRO DE COMPTE 16436 12345 10294786492 57
IBAN FR76 1234 1234 1234 1234 1234 123 BIC FTNOFRP1XXX
N° 8 - 2025
FORTUNEO
TOUR TRINITY
1B PLACE DE LA DEFENSE
92400 COURBEVOIE
COMPTE COURANT
Relevé de Compte
0267
M DOE JOHN
1 RUE DE VICTOR HUGO
75000 PARIS
Page 1/2
SERVICE CLIENTS TEL 0 811 135 135
SERVICE CLIENTS FAX 0 820 820 407
SOS CARTES 02 98 28 42 28
SITE INTERNET www.fortuneo.fr
Émis le 31/08/2025 Réf : DWQJK
Arrêté au 31 août 2025
Date Date de Valeur Opération Débit Crédit
ANCIEN SOLDE CRÉDITEUR AU 31 JUILLET 2025 4 399,64 €
 01/08 01/08/2025 CARTE 30/07 FDJ BOULOGNE BILL 10,00
06/08 06/08/2025 VIR M. DOE JOHN 500,00
07/08 07/08/2025 PRLV SEPA SDC 10022 4,69
SOLDE CHARGES 01 01 2024 31 12 2024
FR90ZZZ87309C
W0202001757579775968489
E2E-685009070CE7E969C8233BDC
11/08 11/08/2025 PRLV SEPA SDC 10022 79,70
APPEL PROVISIONS SUR CHARGES 01 07 2025 3 4 2 3 PR
ELEVEMENT
FR90ZZZ87309C
W0202001757579775968489
E2E-684F46CB62B9B6EDE85B7608
11/08 11/08/2025 PRLV SEPA SDC 10022 9,50
COTISATION FONDS TRAVAUX 01 07 2025 3 4 2 3 PRELEV
EMENT
FR90ZZZ87309C
W0202001757579775968489
E2E-684F46CC62B9B6EDE85B7703
13/08 13/08/2025 VIR M. DOE JOHN 500,00
18/08 18/08/2025 VIR INST M. DOE JOHN 500,00
25230IP1RT197069671
19/08 19/08/2025 CARTE 18/08 lordgunbicycles. Brescia 64,42
20/08 20/08/2025 VIR M. DOE JOHN 500,00
20/08 20/08/2025 CARTE 18/08 AMAZON PAYMENTS PARIS 10,69
25/08 24/08/2025 CARTE 23/08 Airwair In Northampto 140,00 EUR 140,00
25/08 25/08/2025 CARTE 23/08 SNCF VOYAGEURS PARIS 12 40,00
26/08 26/08/2025 VIR INST M. DOE JOHN 500,00
25238IP1RT201153445


''',
  r'''
Relevé de Compte
Titulaire(s) du compte : M DOE JOHN
N° 8 - 2025
COMPTE COURANT Page 2/2
Émis le 31/08/2025 Réf : MRELDEB
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
26/08 26/08/2025 VIR INST JOHN DOE 1 500,00
25238IP1RT201160452
27/08 27/08/2025 VIR M. DOE JOHN 500,00

 TOTAL DES OPÉRATIONS DU RELEVÉ 1 859,00 3 000,00
NOUVEAU SOLDE CRÉDITEUR AU 31 AOÛT 2025 5 540,64 €
 Garantie de vos dépôts
Votre compte relève de la Garantie des Dépôts du FGDR (www.garantiedesdepots.fr)
 Total de vos services et frais bancaires du 1er au 31 juillet 2025 Débit Crédit
Services et frais facturés 0,00 €
TOTAL facturé 0,00 €
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
  final parser = FortuneoCompteCourantParser();

  group('canParse', () {
    test(
      'recognizes a Fortuneo "COMPTE COURANT" / "Relevé de Compte" statement',
      () {
        expect(parser.canParse(_example1Pages), isTrue);
      },
    );

    test('rejects unrelated content', () {
      expect(
        parser.canParse(pageLayoutsFromText(['some other bank entirely'])),
        isFalse,
      );
    });

    test('rejects a Fortuneo LDDS statement (different account type)', () {
      expect(
        parser.canParse(
          pageLayoutsFromText(['FORTUNEO', 'Relevé LDDS', 'Compte 123 45']),
        ),
        isFalse,
      );
    });
  });

  test('example 1: checking account, card-date override, EUR-restatement glitch, hard-wrapped '
      'PRLV reference codes, and the title-marker in/outgoing transfer split', () {
    final result = parser.parse(_example1Pages, sourceFileName: 'example1.pdf');

    expect(result.rowErrors, isEmpty);
    expect(result.balanceInfo?.openingBalance, Decimal.parse('4399.64'));
    expect(result.balanceInfo?.closingBalance, Decimal.parse('5540.64'));

    const selfTransfer = ['likely-self-transfer'];
    _expectCandidates(result.transactionCandidates, [
      _Expected(
        DateTime(2025, 7, 30),
        DateTime(2025, 8, 1),
        '-10.00',
        'CARTE 30/07 FDJ BOULOGNE BILL',
      ),
      _Expected(
        DateTime(2025, 8, 6),
        DateTime(2025, 8, 6),
        '500.00',
        'VIR M. DOE JOHN',
        tags: selfTransfer,
      ),
      _Expected(
        DateTime(2025, 8, 7),
        DateTime(2025, 8, 7),
        '-4.69',
        'PRLV SEPA SDC 10022 SOLDE CHARGES 01 01 2024 31 12 2024 FR90ZZZ87309C '
            'W0202001757579775968489 E2E-685009070CE7E969C8233BDC',
      ),
      _Expected(
        DateTime(2025, 8, 11),
        DateTime(2025, 8, 11),
        '-79.70',
        'PRLV SEPA SDC 10022 APPEL PROVISIONS SUR CHARGES 01 07 2025 3 4 2 3 PRELEVEMENT '
            'FR90ZZZ87309C W0202001757579775968489 E2E-684F46CB62B9B6EDE85B7608',
      ),
      _Expected(
        DateTime(2025, 8, 11),
        DateTime(2025, 8, 11),
        '-9.50',
        'PRLV SEPA SDC 10022 COTISATION FONDS TRAVAUX 01 07 2025 3 4 2 3 PRELEVEMENT '
            'FR90ZZZ87309C W0202001757579775968489 E2E-684F46CC62B9B6EDE85B7703',
      ),
      _Expected(
        DateTime(2025, 8, 13),
        DateTime(2025, 8, 13),
        '500.00',
        'VIR M. DOE JOHN',
        tags: selfTransfer,
      ),
      _Expected(
        DateTime(2025, 8, 18),
        DateTime(2025, 8, 18),
        '500.00',
        'VIR INST M. DOE JOHN 25230IP1RT197069671',
        tags: selfTransfer,
      ),
      _Expected(
        DateTime(2025, 8, 18),
        DateTime(2025, 8, 19),
        '-64.42',
        'CARTE 18/08 lordgunbicycles. Brescia',
      ),
      _Expected(
        DateTime(2025, 8, 20),
        DateTime(2025, 8, 20),
        '500.00',
        'VIR M. DOE JOHN',
        tags: selfTransfer,
      ),
      _Expected(
        DateTime(2025, 8, 18),
        DateTime(2025, 8, 20),
        '-10.69',
        'CARTE 18/08 AMAZON PAYMENTS PARIS',
      ),
      _Expected(
        DateTime(2025, 8, 23),
        DateTime(2025, 8, 24),
        '-140.00',
        'CARTE 23/08 Airwair In Northampto',
      ),
      _Expected(
        DateTime(2025, 8, 23),
        DateTime(2025, 8, 25),
        '-40.00',
        'CARTE 23/08 SNCF VOYAGEURS PARIS 12',
      ),
      _Expected(
        DateTime(2025, 8, 26),
        DateTime(2025, 8, 26),
        '500.00',
        'VIR INST M. DOE JOHN 25238IP1RT201153445',
        tags: selfTransfer,
      ),
      _Expected(
        DateTime(2025, 8, 26),
        DateTime(2025, 8, 26),
        '-1500.00',
        'VIR INST JOHN DOE 25238IP1RT201160452',
        tags: selfTransfer,
      ),
      _Expected(
        DateTime(2025, 8, 27),
        DateTime(2025, 8, 27),
        '500.00',
        'VIR M. DOE JOHN',
        tags: selfTransfer,
      ),
    ]);
  });

  group(
    'real sample 2 (column-position sign detection, from an anonymized real PDF)',
    () {
      late StatementParseResult result;
      setUp(
        () => result = parser.parse(
          loadPdfLayoutFixture('fortuneo_compte_courant_real'),
          sourceFileName: 'real2.pdf',
        ),
      );

      test('reconciles opening/closing balance with no row errors', () {
        expect(result.rowErrors, isEmpty);
        expect(result.balanceInfo?.openingBalance, Decimal.parse('1414.75'));
        expect(result.balanceInfo?.closingBalance, Decimal.parse('1574.18'));
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
        'every bare "VIR M <name>" row (title present, no INST) resolves as a debit via '
        'column position — the opposite of what the title-marker keyword rule alone would '
        'guess (title present -> not flipped -> credit, per the class doc comment\'s '
        '"confirmed fragile" note); only reconciling because column position is now the '
        'primary sign source',
        () {
          final bareVirM = result.transactionCandidates
              .where(
                (c) =>
                    c.description.startsWith('VIR M ') &&
                    !c.description.contains('INST'),
              )
              .toList();
          expect(bareVirM, hasLength(3));
          for (final c in bareVirM) {
            expect(c.amount < Decimal.zero, isTrue, reason: c.description);
          }
        },
      );

      test(
        '"VIR INST" transfers resolve individually via column position, not as a block: '
        'incoming ones (from the linked PEA, or a titled echo) are credits, but the one '
        'untitled "VIR INST <name>" row is a debit — matching what the keyword rule\'s own '
        'title-marker logic would also guess for that specific row',
        () {
          final virInst = result.transactionCandidates
              .where((c) => c.description.startsWith('VIR INST'))
              .toList();
          expect(virInst, hasLength(7));
          final credits = virInst.where((c) => c.amount > Decimal.zero);
          final debits = virInst.where((c) => c.amount < Decimal.zero);
          expect(credits, hasLength(6));
          expect(debits, hasLength(1));
          expect(debits.single.description, contains('VIR INST JOHN DOE'));
        },
      );

      test(
        'the EUR-restatement glitch (a card purchase in USD restating its EUR debit) still '
        'resolves via column position, keeping only the real trailing amount',
        () {
          final github = result.transactionCandidates.firstWhere(
            (c) => c.description.contains('GITHUB'),
          );
          expect(github.amount, Decimal.parse('-85.53'));
        },
      );
    },
  );

  test(
    'a description matching no known debit/credit rule defaults to expense and is flagged',
    () {
      const page = '''
FORTUNEO
COMPTE COURANT
Relevé de Compte
NUMÉRO DE COMPTE 123 456
ANCIEN SOLDE CRÉDITEUR AU 01 JANVIER 2024 100,00 €
01/01 01/01/2024 SOME UNRECOGNIZED LABEL 10,00
TOTAL DES OPÉRATIONS DU RELEVÉ 10,00 0,00
NOUVEAU SOLDE CRÉDITEUR AU 31 JANVIER 2024 90,00 €
''';
      final result = parser.parse(
        pageLayoutsFromText([page]),
        sourceFileName: 'odd.pdf',
      );

      expect(result.transactionCandidates, hasLength(1));
      expect(
        result.transactionCandidates.single.amount,
        Decimal.parse('-10.00'),
      );
      expect(result.rowErrors, hasLength(1));
      expect(
        result.rowErrors.single.message,
        contains('SOME UNRECOGNIZED LABEL'),
      );
    },
  );

  test('a "salaire" description is tagged as salary income', () {
    const page = '''
FORTUNEO
COMPTE COURANT
Relevé de Compte
NUMÉRO DE COMPTE 123 456
ANCIEN SOLDE CRÉDITEUR AU 01 JANVIER 2024 100,00 €
05/01 05/01/2024 VIR Acme Corp Salaire Janvier 2024 2 000,00
TOTAL DES OPÉRATIONS DU RELEVÉ 0,00 2 000,00
NOUVEAU SOLDE CRÉDITEUR AU 31 JANVIER 2024 2 100,00 €
''';
    final result = parser.parse(
      pageLayoutsFromText([page]),
      sourceFileName: 'salary.pdf',
    );

    expect(result.rowErrors, isEmpty);
    expect(result.transactionCandidates, hasLength(1));
    expect(result.transactionCandidates.single.tags, contains('salary'));
  });

  test(
    'mismatched stated totals produce a StatementRowError instead of a silently wrong sign',
    () {
      const page = '''
FORTUNEO
COMPTE COURANT
Relevé de Compte
NUMÉRO DE COMPTE 123 456
ANCIEN SOLDE CRÉDITEUR AU 01 JANVIER 2024 100,00 €
01/01 01/01/2024 CARTE 01/01 Some Shop 10,00
TOTAL DES OPÉRATIONS DU RELEVÉ 999,00 0,00
NOUVEAU SOLDE CRÉDITEUR AU 31 JANVIER 2024 90,00 €
''';
      final result = parser.parse(
        pageLayoutsFromText([page]),
        sourceFileName: 'mismatch.pdf',
      );

      expect(result.transactionCandidates, hasLength(1));
      expect(result.rowErrors, hasLength(1));
      expect(result.rowErrors.single.message, contains('do not match'));
    },
  );

  test(
    'a row with no extractable amount is flagged instead of silently dropped',
    () {
      const page = '''
FORTUNEO
COMPTE COURANT
Relevé de Compte
NUMÉRO DE COMPTE 123 456
ANCIEN SOLDE CRÉDITEUR AU 01 JANVIER 2024 100,00 €
01/01 01/01/2024 CARTE Some Shop With No Amount
TOTAL DES OPÉRATIONS DU RELEVÉ 0,00 0,00
NOUVEAU SOLDE CRÉDITEUR AU 31 JANVIER 2024 100,00 €
''';
      final result = parser.parse(
        pageLayoutsFromText([page]),
        sourceFileName: 'noamount.pdf',
      );

      expect(result.transactionCandidates, isEmpty);
      expect(result.rowErrors, hasLength(1));
      expect(
        result.rowErrors.single.message,
        contains('Could not find an amount'),
      );
    },
  );
}
