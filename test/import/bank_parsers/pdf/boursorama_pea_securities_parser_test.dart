import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/bank_parsers/pdf/boursorama_pea_securities_parser.dart';
import 'package:moopro/import/bank_parsers/statement_parser.dart';

import 'pdf_fixture_helpers.dart';

final _examplePages = pageLayoutsFromText([
  r'''
Service Clientèle : 01 46 09 49 49 ou +33 146 09 49 49 depuis l'étranger, du lundi au vendredi de 8h à 20h et le samedi de 8h45 à 16h30 – www.boursobank.com
Boursorama S.A. au capital de 53 576 889,20 € - RCS Nanterre 351 058 151 - TVA 69 351 058 151 - 44 rue Traversière - CS 80134 - 92772 Boulogne Billancourt Cedex
Adresse du médiateur : Médiateur de l'AMF - 17, place de la Bourse - 75082 PARIS CEDEX 02
000000 F1 P1193291 1/1
 000000
P1193291

b&E;XEK<W]"L!JfM+)T!MqCNB
EH-Exy+
~@7xIx&w)*TaN8
`
!cV
%09[dST"U7E$#GTV
a!!!a!!a!aa!a!aaa!a!aaa!a!!aaa!!!!a!aa!a!!a!!!!!
M DOE JOHN
1 RUE VICTOR HUGO
75000 PARIS
AA1
RELEVE COMPTE TITRES : JUIN 2026
Valorisé au 30/06/2026
Feuillet 1/1
Références de votre compte titres
40618 80293 00088793214 Compte PEA
Résident Français
Quantité Nom de la valeur (code)
F
(1)
P
(2)
Cours du titre
en devise de négociation Valorisation de la ligne
%
Portef. Prix de revient fiscal unitaire
VALEURS FRANCAISES EUR EUR EUR
ACTIONS
29 AIR LIQUIDE (FR0000120073) * 173,28 5 025,12 29,99 160,77
15 TOTALENERGIES SE (FR0000120271) * 68,03 1 020,45 6,09 65,10
1 LVMH MOET VUITTON (FR0000121014) * 484,10 484,10 2,88 473,87
2 AIR LIQUIDE (FR001400T5U9) * N 173,28 346,56 2,06 160,77
83 AM.SP 500 ETF ACC (FR0011871128) * 57,49 4 771,67 28,47 51,27
Sous-Total 11 647,90 69,51
OPC AUTRES
37,91572 PEA PROF.DYNAM.C5D (FR001400AEJ2) * 134,700 5 107,24 30,48 113,146
Sous-Total 5 107,24 30,48
TOTAL VALEURS FRANCAISES 16 755,14 100,00
TOTAL EUR 16 755,14 100,00
REPARTITION DU PORTEFEUILLE PAR GRANDES MASSES
Type de valeur
%
Portef. Valorisation en EUR
FRANCE ACTIONS 69,51 11 647,90
OPC AUTRES 30,48 5 107,24
TOTAL DU PORTEFEUILLE 16 755,14 EUR
SOLDE ESPECES (EUR) 461,34 EUR
TOTAL DE L'ACTIF 17 216,48 EUR
Sous réserve de dénouement des éventuelles opérations en cours.
* Instrument soumis aux règles de la directive 2014/65/UE (MiFID 2)
(1) FORMES (F) : Porteur ( ), Nominatif (N) (2) PARTICULARITES (P) : Valeur Echue (E), Valeur Indisponible (I), Actionnariat (A), Stock options (S), Monep (M)
''',
]);
void main() {
  final parser = BoursoramaPeaSecuritiesParser();

  test('canParse recognizes the securities/valuation statement only', () {
    expect(parser.canParse(_examplePages), isTrue);
    expect(
      parser.canParse(pageLayoutsFromText(const ['RELEVE COMPTE ESPECES'])),
      isFalse,
    );
    expect(
      parser.canParse(pageLayoutsFromText(const ['Compte à vue P.E.A.'])),
      isFalse,
    );
  });

  group('real sample', () {
    late StatementParseResult result;
    setUp(
      () => result = parser.parse(_examplePages, sourceFileName: 'assets.pdf'),
    );

    test('produces only price candidates, never transactions', () {
      expect(result.transactionCandidates, isEmpty);
      expect(result.priceCandidates, hasLength(6));
      expect(result.rowErrors, isEmpty);
    });

    test('every price is dated to the statement\'s "Valorisé au" date', () {
      for (final p in result.priceCandidates) {
        expect(p.date, DateTime(2026, 6, 30));
        expect(p.currencyHint, 'EUR');
      }
    });

    test(
      'keeps the two distinct "AIR LIQUIDE" ISINs as separate asset hints',
      () {
        final airLiquide = result.priceCandidates
            .where((p) => p.assetHint.startsWith('AIR LIQUIDE'))
            .toList();
        expect(airLiquide, hasLength(2));
        final hints = airLiquide.map((p) => p.assetHint).toSet();
        expect(
          hints,
          containsAll(<String>[
            'AIR LIQUIDE (FR0000120073)',
            'AIR LIQUIDE (FR001400T5U9)',
          ]),
        );
        for (final p in airLiquide) {
          expect(p.price, Decimal.parse('173.28'));
        }
      },
    );

    test('parses the fractional-quantity OPC holding price correctly', () {
      final opc = result.priceCandidates.firstWhere(
        (p) => p.assetHint.contains('PEA PROF.DYNAM.C5D'),
      );
      expect(opc.assetHint, 'PEA PROF.DYNAM.C5D (FR001400AEJ2)');
      expect(opc.price, Decimal.parse('134.700'));
    });

    test(
      'reconciles the sum of parsed valuations against the stated TOTAL EUR',
      () {
        const expectedValuations = [
          '5025.12',
          '1020.45',
          '484.10',
          '346.56',
          '4771.67',
          '5107.24',
        ];
        final sum = expectedValuations
            .map(Decimal.parse)
            .fold(Decimal.zero, (a, b) => a + b);
        expect(sum, Decimal.parse('16755.14'));
      },
    );
  });

  test('flags a mismatch between parsed holdings and the stated total', () {
    final pages = pageLayoutsFromText([
      '''
RELEVE COMPTE TITRES : JUIN 2026
Valorisé au 30/06/2026
ACTIONS
1 SOME STOCK (FR0000000001) * 100,00 100,00 100,00 90,00
TOTAL EUR 999,00 100,00
''',
    ]);
    final result = parser.parse(pages, sourceFileName: 'synthetic.pdf');
    expect(result.priceCandidates, hasLength(1));
    expect(
      result.rowErrors.any((e) => e.message.contains('does not match')),
      isTrue,
    );
  });
}
