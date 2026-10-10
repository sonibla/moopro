import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/bank_parsers/pdf/credit_agricole_releve_compte_parser.dart';
import 'package:moopro/import/bank_parsers/statement_parser.dart';

import 'pdf_fixture_helpers.dart';
import 'package:moopro/domain/calendar_date.dart';

final _example1Pages = pageLayoutsFromText([
  r'''
015033 230109 
210137 033022
018371
0001 0003 17774
 12334 
000001 000001 034123 017321
 0
2 
 RELEVE DE COMPTES EN EUROS N° 001
Date d'arrêté : 06 Janvier 2021
CREDIT AGRICOLE
DE LORRAINE
00861 FLRV001 00765
M. DOE JOHN 
1 RUE DE VICROT HUGO 
75000 PARIS
 CA Paris 39841 21309 123
Votre agence
Paris les champs
2 rue de Paris
75000 Paris
Tél : 03 12 34 45 56
Fax :
 
03 12 34 45 56
Votre conseiller
Jane Doe
Tél : 03 12 34 45 56
Vos contacts
Internet : www.ca-lorraine.fr (1)
Webmobile:https://m.ca-lorraine.fr(1)
Smartphone/tablette: application
gratuite "Ma Banque" (1)
Comment joindre votre Conseiller ?
par e-mail en utilisant le Format
adresse : prenom.nom@ca-lorraine.fr
Page 1 / 
SYNTHESE
M. Doe John
Compte Chèque n° 73829164728 + 175,51
M. Benmouffek Alban - Compte Chèque n° 73829164728
IBAN : FR76 1234 1234 1234 1234 1234 123 BIC : AGRIFRPP736
þ
Ancien solde créditeur au 07.12.2020 527,63
09.12 09.12 Virement Shopmium
Operation 39392350 20201207
Shopmium - Ref: £39392350
0,89 ¨
14.12 14.12 Carte Auchan B2C Drive Villeneuv 11/12 26,35 ¨
15.12 15.12 Carte Amazon Payments PAYLI24415 12/12 48,10 ¨
16.12 16.12 Carte Auchan B2C Drive Villeneuv 15/12 26,42 ¨
16.12 16.12 Carte Résidence Servi Savigny Su 15/12 2,80 ¨
16.12 16.12 Carte Résidence Servi Savigny Su 15/12 1,50 ¨
17.12 17.12 Carte Selecta Gare Est Le Bourge 16/12 2,00 ¨
17.12 17.12 Carte SNCF Cergy 16/12 12,30 ¨
21.12 21.12 Virement Shopmium
Operation 39714428 20201217Shopmium - Ref: £39714428
1,20 ¨
23.12 23.12 Virement Shopmium
Operation 39836785 20201221Shopmium - Ref: £39836785
3,30 ¨
23.12 22.12 Avoir Carte Act*time to 22/12 7,00 ¨
23.12 23.12 Carte Cora Moulins Les Metz 22/12 7,98 ¨
23.12 23.12 Carte Remy Antoine Metz 22/12 25,00 ¨
26.12 26.12 Virement De Maman 11,00 ¨
30.12 30.12 Virement De Papa 800,00 ¨
02.01 02.01 Virement Web Papa 700,00 ¨
05.01 05.01 Virement Shopmium
Operation 40064117 20201231Shopmium - Ref: £40064117
1,32 ¨
05.01 05.01 Carte Auchan B2C Drive Villeneuv 04/01 28,52 ¨
Date
opé.
Date
valeur Libellé des opérations Débit Crédit
''',
  r'''
2 
 RELEVE DE COMPTES EN EUROS N° 001
Date d'arrêté : 06 Janvier 2021
Page 2 / 
M. Doe John - Compte Chèque n° 73829164728 (suite) 
þ
05.01 05.01 Prlv Arpej
LPAM003969221600-AR-00000063324-02-2019-00002064
FR05ZZZ386174 Core
271,36 ¨
06.01 06.01 Carte SNCF Internet Paris 10 05/01 24,50 ¨
Total des opérations 1 176,83 824,71
Nouveau solde créditeur au 06.01.2021 175,51
Le taux d'intérêt débiteur associé à votre compte n° 73829164728 est de 20,66 %.
Indice de référence servant au calcul du taux d'intérêt débiteur publié par BDF : seuil de l'usure pour découvert < 3000 Eur soit 21,16 % au 01.01.
2021.
Compte Chèque n° 73829164728 
En cas de perte ou de vol de votre carte, téléphonez au 0912344567 (appel non surtaxé). Réclamation : si la réponse apportée par votre agence ne
vous donne pas satisfaction, le service Qualité Relation Clients est à votre écoute par courrier à l'adresse de la Caisse Régionale ou par mail :
qualite.relation.clients@ca-lorraine.fr. En cas de différend non résolu et selon l'artL316-1 CMF, vous pouvez écrire à M. le Médiateur du Crédit
Agricole de Lorraine CS 71700 54017 NANCY Cedex, ou via le site : www.lemedi ateur-ca-lorraine.fr. Pour tout litige relatif à un contrat ou une
opération réalisée en ligne, vous pouvez recourir à la platef orme Européenne de Règlement des Litiges en ligne sur:
https://webgate.ec.europa.eu/odr. ** Frais bancaires - (1) Accès gratuit et illimité, hors coût de communication variable selon opérateur. CAISSE
REGIONALE DE CREDIT AGRICOLE MUTUEL DE LORRAINE - Société coopérative à capital variable. Etablissement de crédit. Société de courtage
d'assurances - 775 616 162 RCS METZ - Immatriculée au Registre des Intermédiaires en Assurance sous le nø 07 142 719 - Siège Social : 52
avenue André Malraux 57000 Paris - Adresse postale : CS 71700 54017 PARIS CEDEX.
Date
opé.
Date
valeur Libellé des opérations Débit Crédit
Vos conditions de dépassement d'autorisation de découvert ou de solde de compte 
Les sommes figurant sur le(s) compte(s) et/ou le(s) livret(s) suivant(s) sont protégées par la Garantie des Dépôts dans
la limite du plafond défini par la loi (www.garantiedesdepots.fr) :
''',
]);

final _example2Pages = pageLayoutsFromText([
  r'''
7328276 31413 0001 0013 38192 000001 000002 2312839 001462
1 
 RELEVE DE COMPTES EN EUROS N° 002
Date d'arrêté : 08 Décembre 2025
CREDIT AGRICOLE
DE LORRAINE
00821 FLRV001 00365
M. DOE JOHN 
1 RUE DE VICROT HUGO 
75000 PARIS
 CA Paris 39841 21309 123
Votre agence
Paris les champs
2 rue de Paris
75000 Paris
Tél : 03 12 34 45 56
Fax :
 
03 12 34 45 56
Votre conseiller
Jane Doe
Tél : 03 12 23 34 45
Vos contacts
Internet : www.ca-lorraine.fr (1)
Webmobile:https://m.ca-lorraine.fr(1)
Smartphone/tablette: application
gratuite "Ma Banque" (1)
Comment joindre votre Conseiller ?
par e-mail en utilisant le Format
adresse : prenom.nom@ca-lorraine.fr
Page 1 / 
SYNTHESE
M. Doe John
Livret A n° 7187498273 + 1 950,00
M. Doe John - Livret A n° 7187498273
þ
Ancien solde créditeur au 06.01.2025 1 950,00
20.11 01.12 Virement De M. Doe John 300,00 ¨
20.11 16.11 Virement Web M. Doe John 300,00 ¨
Total des opérations 300,00 300,00
Nouveau solde créditeur au 08.12.2025 1 950,00
Livret A n° 7187498273
En cas de perte ou de vol de votre carte, téléphonez au 09123678214 (appel non surtaxé). Réclamation : si la réponse apportée par votre agence ne
vous donne pas satisfaction, le service Qualité Relation Clients est à votre écoute par courrier à l'adresse de la Caisse Régionale ou par mail :
qualite.relation.clients@ca-lorraine.fr. En cas de différend non résolu ou deux mois après une première réclamation écrite et selon l'art L316-1 CMF,
vous pouvez écrire au médiateur bancaire : Monsieur Xavier de Kergommeaux, Médiateur de la Consommation auprès du Crédit Agricole de
Lorraine, 68 Avenue d'Iéna 75116 Paris ou sur le site www.kergommeaux-me diateur-consommation.fr. Pour tout litige relatif à un contrat ou une
opération réalisée en ligne, vous pouvez recourir à la plate forme Européenne de Règlement des Litiges en ligne sur :
htts://webgate.ec.europa.eu/odr. **Frais bancaires - (1) Accès gratuit et illimité, hors coût de communication variable selon opérateur. CAISSE
REGIONALE DE CREDIT AGRICOLE MUTUEL DE LORRAINE - Société d e courtage d'assurances - 775 616 162 RCS METZ - Immatriculée au Registre
des Intermédiaires en Assurance sous le nø 07 022 719 - Siège Social : 50 avenue André Malraux 57000 PARIS - Adresse postale : CS 71700
54017 NANCY CEDEX.
Date
opé.
Date
valeur Libellé des opérations Débit Crédit
Les sommes figurant sur le(s) livret(s) suivant(s) sont protégées par la Garantie de l'État dans la limite du plafond
défini par la loi (www.garantiedesdepots.fr) :
''',
]);

final _example3Pages = pageLayoutsFromText([
  r'''
738291 2389100 0001 0005 2318794 000001 000001 123789 009565
1 
 RELEVE DE COMPTES EN EUROS N° 001
Date d'arrêté : 06 Janvier 2026
CREDIT AGRICOLE
DE LORRAINE
00861 FLRV001 00765
M. DOE JOHN 
1 RUE DE VICROT HUGO 
75000 PARIS
 CA Paris 39841 21309 123
Votre agence
Paris les champs
2 rue de Paris
75000 Paris
Tél : 03 12 34 45 56
Fax :
 
03 12 34 45 56
Votre conseiller
Jane Doe
Tél : 03 12 23 34 45
Vos contacts
Internet : www.ca-lorraine.fr (1)
Webmobile:https://m.ca-lorraine.fr(1)
Smartphone/tablette: application
gratuite "Ma Banque" (1)
Comment joindre votre Conseiller ?
par e-mail en utilisant le Format
adresse : prenom.nom@ca-lorraine.fr
Page 1 / 
SYNTHESE
M. John Doe
Livret A n° 7187498273 + 2 950,00
M. John Doe - Livret A n° 7187498273
þ
Ancien solde créditeur au 08.12.2025 2 950,00
31.12 01.01 Intérêts De L'année Taux 2,400% 275,40 ¨
31.12 01.01 Intérêts De L'année Taux 3,000% 57,37 ¨
31.12 01.01 Intérêts De L'année Taux 1,700% 162,35 ¨
31.12 16.12 Virement Web M. John Doe 495,12 ¨
Total des opérations 495,12 495,12
Nouveau solde créditeur au 06.01.2026 2 950,00
Livret A n° 7187498273
En cas de perte ou de vol de votre carte, téléphonez au 09216387647 (appel non surtaxé). Réclamation : si la réponse apportée par votre agence ne
vous donne pas satisfaction, le service Qualité Relation Clients est à votre écoute par courrier à l'adresse de la Caisse Régionale ou par mail :
qualite.relation.clients@ca-lorraine.fr. En cas de différend non résolu ou deux mois après une première réclamation écrite et selon l'art L316-1 CMF,
vous pouvez écrire au médiateur bancaire : Monsieur Xavier de Kergommeaux, Médiateur de la Consommation auprès du Crédit Agricole de
Lorraine, 68 Avenue d'Iéna 75116 Paris ou sur le site www.kergommeaux-me diateur-consommation.fr. Pour tout litige relatif à un contrat ou une
opération réalisée en ligne, vous pouvez recourir à la plate forme Européenne de Règlement des Litiges en ligne sur :
htts://webgate.ec.europa.eu/odr. **Frais bancaires - (1) Accès gratuit et illimité, hors coût de communication variable selon opérateur. CAISSE
REGIONALE DE CREDIT AGRICOLE MUTUEL DE LORRAINE - Société d e courtage d'assurances - 775 616 162 RCS METZ - Immatriculée au Registre
des Intermédiaires en Assurance sous le nø 07 022 719 - Siège Social : 50 avenue André Malraux 57000 PARIS - Adresse postale : CS 71700
54017 NANCY CEDEX.
Date
opé.
Date
valeur Libellé des opérations Débit Crédit
Les sommes figurant sur le(s) livret(s) suivant(s) sont protégées par la Garantie de l'État dans la limite du plafond
défini par la loi (www.garantiedesdepots.fr) :
''',
]);

final _example4Pages = pageLayoutsFromText([
  r'''
628719 00912873 0001 0012 14011 000001 21389 324991 007681
2 
 RELEVE DE COMPTES EN EUROS N° 009
Date d'arrêté : 08 Septembre 2025
CREDIT AGRICOLE
DE LORRAINE
00861 FLRV001 00765
M. DOE JOHN 
1 RUE DE VICROT HUGO 
75000 PARIS
 CA Paris 39841 37218 123
Votre agence
Paris les champs
2 rue de Paris
75000 Paris
Tél : 03 12 34 45 56
Fax :
 
03 12 34 45 56
Votre conseiller
Jane Doe
Tél : 03 12 23 34 45
Vos contacts
Internet : www.ca-lorraine.fr (1)
Webmobile:https://m.ca-lorraine.fr(1)
Smartphone/tablette: application
gratuite "Ma Banque" (1)
Comment joindre votre Conseiller ?
par e-mail en utilisant le Format
adresse : prenom.nom@ca-lorraine.fr
Page 1 / 
SYNTHESE
M. Doe John
Compte Chèque n° 931874923888 + 6 160,71
M. Doe John - Compte Chèque n° 931874923888
IBAN : FR76 1234 1234 1234 1234 1234 1234 BIC : AGRIFRPP123
þ
Ancien solde créditeur au 06.08.2025 14 265,15
13.08 13.08 Virement Web John Doe
M. Doe John
500,00 ¨
18.08 18.08 Virement Vir Inst vers John Doe 750,00 ¨
18.08 18.08 Virement Vir Inst vers John Doe 250,00 ¨
18.08 18.08 Virement Vir Inst vers John Doe 1 500,00 ¨
18.08 18.08 Virement Vir Inst vers John Doe 500,00 ¨
20.08 20.08 Virement Web John Doe
M. Doe John
1 000,00 ¨
20.08 20.08 Virement Web John Doe
M. Doe John
500,00 ¨
26.08 26.08 Virement Acme Corp S.a.
CDWQAD3C22HNCQ94EE2HK4XGH5 7Salary 08/2025
4 831,58 ¨
26.08 26.08 Virement Vir Inst vers John Doe 750,00 ¨
26.08 26.08 Virement Vir Inst vers John Doe 1 500,00 ¨
26.08 26.08 Virement Vir Inst vers John Doe 250,00 ¨
26.08 26.08 Virement Vir Inst vers John Doe 500,00 ¨
27.08 27.08 Virement Web John Doe
M. Doe John
500,00 ¨
02.09 02.09 Virement Vir Inst vers John Doe 1 500,00 ¨
02.09 02.09 Virement Vir Inst vers John Doe 1 500,00 ¨
02.09 05.09 Règlement Assu. Caae Prêt Habitat 09/25 26,97 ¨
Date
opé.
Date
valeur Libellé des opérations Débit Crédit
''',
  r'''
2 
 RELEVE DE COMPTES EN EUROS N° 009
Date d'arrêté : 08 Septembre 2025
Page 2 / 
M. Doe John - Compte Chèque n° 931874923888 (suite) 
þ
03.09 03.09 Prlv 0214846 CRCAM De Lorraine
Crédit Agricole AssuranceHabitation -echeance 09/2025Cotisation Du
Contrat Pacifica1329964290700000000000000000000013127158907PCK
FR73ZZZ141674 Core
27,10 ¨
03.09 03.09 Virement Web John Doe
M. Doe John
500,00 ¨
05.09 05.09 Prlv Uem
Uem gaz EC2808202523828UEM206125 FR40ZZZ002976 Core
12,00 ¨
05.09 05.09 Prlv Uem
Uem electricite EC2808202523824UEM206125 FR40ZZZ002976 Core
27,00 ¨
05.09 05.09 Ech Prêt 86474303241 Echéance 05/09/25 86,00 ¨
05.09 05.09 Ech Prêt 86474303240 Echéance 05/09/25 756,95 ¨
Total des opérations 12 936,02 4 831,58
Nouveau solde créditeur au 08.09.2025 6 160,71
Le taux d'intérêt débiteur associé à votre compte n° 931874923888 est de 22,89 %.
Indice de référence servant au calcul du taux d'intérêt débiteur publié par BDF : seuil de l'usure pour découvert < 3000 Eur soit 23,39 % au 01.07.
2025.
Compte Chèque n° 931874923888 
En cas de perte ou de vol de votre carte, téléphonez au 0987312747 (appel non surtaxé). Réclamation : si la réponse apportée par votre agence ne
vous donne pas satisfaction, le service Qualité Relation Clients est à votre écoute par courrier à l'adresse de la Caisse Régionale ou par mail :
qualite.relation.clients@ca-lorraine.fr. En cas de différend non résolu ou deux mois après une première réclamation écrite et selon l'art L316-1 CMF,
vous pouvez écrire au médiateur bancaire : Monsieur Xavier de Kergommeaux, Médiateur de la Consommation auprès du Crédit Agricole de
Lorraine, 68 Avenue d'Iéna 75116 Paris ou sur le site www.kergommeaux-me diateur-consommation.fr. Pour tout litige relatif à un contrat ou une
opération réalisée en ligne, vous pouvez recourir à la plate forme Européenne de Règlement des Litiges en ligne sur :
htts://webgate.ec.europa.eu/odr. **Frais bancaires - (1) Accès gratuit et illimité, hors coût de communication variable selon opérateur. CAISSE
REGIONALE DE CREDIT AGRICOLE MUTUEL DE LORRAINE - Société d e courtage d'assurances - 775 616 162 RCS METZ - Immatriculée au Registre
des Intermédiaires en Assurance sous le nø 07 022 719 - Siège Social : 59 avenue André Malraux 57000 PARIS - Adresse postale : CS 71700
54017 NANCY CEDEX.
Date
opé.
Date
valeur Libellé des opérations Débit Crédit
Vos conditions de dépassement d'autorisation de découvert ou de solde de compte 
Les sommes figurant sur le(s) compte(s) et/ou le(s) livret(s) suivant(s) sont protégées par la Garantie des Dépôts dans
la limite du plafond défini par la loi (www.garantiedesdepots.fr) :
''',
]);

final _example5Pages = pageLayoutsFromText([
  r'''
 210107 
210107 011021
011021
0001 0004 17334
 17334 
000001 000003 034690 017023
 0
1 
 RELEVE DE COMPTES EN EUROS N° 001
Date d'arrêté : 06 Janvier 2021
CREDIT AGRICOLE
DE LORRAINE
00861 FLRV001 00765
M. DOE JOHN 
1 RUE VICTOR HUGO
75000 PARIS
 CA Lorraine 54017 NANCY CEDEX 775 616 162 RCS PARIS
Votre agence
Paris Hauts De Queuleu
31 Rue Du Pre Gonde
75070 Paris
Tél : 03 12 23 34 45
Fax :
 
03 13 24 32 46
Votre conseiller
Jane Doe
Tél : 03 12 23 34 45
Vos contacts
Internet : www.ca-lorraine.fr (1)
Webmobile:https://m.ca-lorraine.fr(1)
Smartphone/tablette: application
gratuite "Ma Banque" (1)
Comment joindre votre Conseiller ?
par e-mail en utilisant le Format
adresse : prenom.nom@ca-lorraine.fr
Page 1 / 
SYNTHESE
M. Doe John
Livret A n° 17382941314 + 10,73
M. Doe John - Livret A n° 17382941314
þ
Ancien solde créditeur au 06.02.2020 10,69
31.12 01.01 Intérêts De L'année Taux 0,500% 0,04 ¨
Total des opérations 0,04
Nouveau solde créditeur au 06.01.2021 10,73
Livret A n° 17382941314
En cas de perte ou de vol de votre carte, téléphonez au 09438721648 (appel non surtaxé). Réclamation : si la réponse apportée par votre agence ne
vous donne pas satisfaction, le service Qualité Relation Clients est à votre écoute par courrier à l'adresse de la Caisse Régionale ou par mail :
qualite.relation.clients@ca-lorraine.fr. En cas de différend non résolu et selon l'artL316-1 CMF, vous pouvez écrire à M. le Médiateur du Crédit
Agricole de Lorraine CS 71700 54017 NANCY Cedex, ou via le site : www.lemedi ateur-ca-lorraine.fr. Pour tout litige relatif à un contrat ou une
opération réalisée en ligne, vous pouvez recourir à la platef orme Européenne de Règlement des Litiges en ligne sur:
https://webgate.ec.europa.eu/odr. ** Frais bancaires - (1) Accès gratuit et illimité, hors coût de communication variable selon opérateur. CAISSE
REGIONALE DE CREDIT AGRICOLE MUTUEL DE LORRAINE - Société coopérative à capital variable. Etablissement de crédit. Société de courtage
d'assurances - 775 616 162 RCS METZ - Immatriculée au Registre des Intermédiaires en Assurance sous le nø 07 022 719 - Siège Social : 59
avenue André Malraux 57000 PARIS - Adresse postale : CS 71700 54017 NANCY CEDEX.
Date
opé.
Date
valeur Libellé des opérations Débit Crédit
Les sommes figurant sur le(s) livret(s) suivant(s) sont protégées par la Garantie de l'État dans la limite du plafond
défini par la loi (www.garantiedesdepots.fr) :
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
  final parser = CreditAgricoleReleveCompteParser();

  group('canParse', () {
    test('recognizes a Credit Agricole "RELEVE DE COMPTES" statement', () {
      expect(parser.canParse(_example1Pages), isTrue);
    });

    test('rejects unrelated content', () {
      expect(
        parser.canParse(pageLayoutsFromText(['some other bank entirely'])),
        isFalse,
      );
    });
  });

  group('real sample 2 (multi-section column position, from an anonymized real PDF)', () {
    late StatementParseResult result;
    setUp(
      () => result = parser.parse(
        loadPdfLayoutFixture('credit_agricole_multi_section_real'),
        sourceFileName: 'real2.pdf',
      ),
    );

    test('reconciles opening/closing balance with no row errors', () {
      expect(result.rowErrors, isEmpty);
      expect(result.balanceInfo?.openingBalance, Decimal.parse('13580.92'));
      expect(result.balanceInfo?.closingBalance, Decimal.parse('6726.48'));
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
      'a "Virement <payee name>" row with no keyword indicating direction resolves as a debit '
      'via column position — the keyword fallback\'s own default ("virement" not matching '
      '"vers"/"web" -> credit) would have gotten this one wrong, and did until column '
      'position was consulted for every row on this page instead of falling back to keyword '
      'classification entirely (nothing preceded these rows\' own header occurrence before '
      'the "nearest following" fallback was added)',
      () {
        final notaryPayment = result.transactionCandidates.firstWhere(
          (c) => c.description.contains('Mahler'),
        );
        expect(notaryPayment.amount, Decimal.parse('-8151.70'));
      },
    );

    test(
      'a description starting with "Frais" (a fee) — a label with no dedicated keyword rule '
      'at all — still resolves via column position, not the keyword fallback\'s default',
      () {
        final fees = result.transactionCandidates
            .where((c) => c.description.contains('Frais'))
            .toList();
        expect(fees, hasLength(4));
        for (final c in fees) {
          expect(c.amount < Decimal.zero, isTrue, reason: c.description);
        }
      },
    );
  });

  test(
    'example 1: checking account, Dec 2020 -> Jan 2021 (crosses a year boundary)',
    () {
      final result = parser.parse(
        _example1Pages,
        sourceFileName: 'example1.pdf',
      );

      expect(result.rowErrors, isEmpty);
      expect(result.balanceInfo?.openingBalance, Decimal.parse('527.63'));
      expect(result.balanceInfo?.closingBalance, Decimal.parse('175.51'));

      _expectCandidates(result.transactionCandidates, [
        _Expected(
          DateTime(2020, 12, 9),
          DateTime(2020, 12, 9),
          '0.89',
          'Virement Shopmium Operation 39392350 20201207 Shopmium - Ref: £39392350',
        ),
        _Expected(
          DateTime(2020, 12, 14),
          DateTime(2020, 12, 14),
          '-26.35',
          'Carte Auchan B2C Drive Villeneuv 11/12',
        ),
        _Expected(
          DateTime(2020, 12, 15),
          DateTime(2020, 12, 15),
          '-48.10',
          'Carte Amazon Payments PAYLI24415 12/12',
        ),
        _Expected(
          DateTime(2020, 12, 16),
          DateTime(2020, 12, 16),
          '-26.42',
          'Carte Auchan B2C Drive Villeneuv 15/12',
        ),
        _Expected(
          DateTime(2020, 12, 16),
          DateTime(2020, 12, 16),
          '-2.80',
          'Carte Résidence Servi Savigny Su 15/12',
        ),
        _Expected(
          DateTime(2020, 12, 16),
          DateTime(2020, 12, 16),
          '-1.50',
          'Carte Résidence Servi Savigny Su 15/12',
        ),
        _Expected(
          DateTime(2020, 12, 17),
          DateTime(2020, 12, 17),
          '-2.00',
          'Carte Selecta Gare Est Le Bourge 16/12',
        ),
        _Expected(
          DateTime(2020, 12, 17),
          DateTime(2020, 12, 17),
          '-12.30',
          'Carte SNCF Cergy 16/12',
        ),
        _Expected(
          DateTime(2020, 12, 21),
          DateTime(2020, 12, 21),
          '1.20',
          'Virement Shopmium Operation 39714428 20201217Shopmium - Ref: £39714428',
        ),
        _Expected(
          DateTime(2020, 12, 23),
          DateTime(2020, 12, 23),
          '3.30',
          'Virement Shopmium Operation 39836785 20201221Shopmium - Ref: £39836785',
        ),
        _Expected(
          DateTime(2020, 12, 23),
          DateTime(2020, 12, 22),
          '7.00',
          'Avoir Carte Act*time to 22/12',
        ),
        _Expected(
          DateTime(2020, 12, 23),
          DateTime(2020, 12, 23),
          '-7.98',
          'Carte Cora Moulins Les Metz 22/12',
        ),
        _Expected(
          DateTime(2020, 12, 23),
          DateTime(2020, 12, 23),
          '-25.00',
          'Carte Remy Antoine Metz 22/12',
        ),
        _Expected(
          DateTime(2020, 12, 26),
          DateTime(2020, 12, 26),
          '11.00',
          'Virement De Maman',
        ),
        _Expected(
          DateTime(2020, 12, 30),
          DateTime(2020, 12, 30),
          '800.00',
          'Virement De Papa',
        ),
        _Expected(
          DateTime(2021, 1, 2),
          DateTime(2021, 1, 2),
          '-700.00',
          'Virement Web Papa',
        ),
        _Expected(
          DateTime(2021, 1, 5),
          DateTime(2021, 1, 5),
          '1.32',
          'Virement Shopmium Operation 40064117 20201231Shopmium - Ref: £40064117',
        ),
        _Expected(
          DateTime(2021, 1, 5),
          DateTime(2021, 1, 5),
          '-28.52',
          'Carte Auchan B2C Drive Villeneuv 04/01',
        ),
        _Expected(
          DateTime(2021, 1, 5),
          DateTime(2021, 1, 5),
          '-271.36',
          'Prlv Arpej LPAM003969221600-AR-00000063324-02-2019-00002064 FR05ZZZ386174 Core',
        ),
        _Expected(
          DateTime(2021, 1, 6),
          DateTime(2021, 1, 6),
          '-24.50',
          'Carte SNCF Internet Paris 10 05/01',
        ),
      ]);
    },
  );

  test(
    'example 2: Livret A, self-transfer in and out (both "Virement De"/"Virement Web")',
    () {
      final result = parser.parse(
        _example2Pages,
        sourceFileName: 'example2.pdf',
      );

      expect(result.rowErrors, isEmpty);
      expect(result.balanceInfo?.openingBalance, Decimal.parse('1950'));
      expect(result.balanceInfo?.closingBalance, Decimal.parse('1950'));

      _expectCandidates(result.transactionCandidates, [
        _Expected(
          DateTime(2025, 11, 20),
          DateTime(2025, 12, 1),
          '300.00',
          'Virement De M. Doe John',
          tags: const ['likely-self-transfer'],
        ),
        _Expected(
          DateTime(2025, 11, 20),
          DateTime(2025, 11, 16),
          '-300.00',
          'Virement Web M. Doe John',
          tags: const ['likely-self-transfer'],
        ),
      ]);
    },
  );

  test('example 3: Livret A interest credits + one outgoing transfer', () {
    final result = parser.parse(_example3Pages, sourceFileName: 'example3.pdf');

    expect(result.rowErrors, isEmpty);
    expect(result.balanceInfo?.openingBalance, Decimal.parse('2950'));
    expect(result.balanceInfo?.closingBalance, Decimal.parse('2950'));

    _expectCandidates(result.transactionCandidates, [
      _Expected(
        DateTime(2025, 12, 31),
        DateTime(2026, 1, 1),
        '275.40',
        "Intérêts De L'année Taux 2,400%",
      ),
      _Expected(
        DateTime(2025, 12, 31),
        DateTime(2026, 1, 1),
        '57.37',
        "Intérêts De L'année Taux 3,000%",
      ),
      _Expected(
        DateTime(2025, 12, 31),
        DateTime(2026, 1, 1),
        '162.35',
        "Intérêts De L'année Taux 1,700%",
      ),
      _Expected(
        DateTime(2025, 12, 31),
        DateTime(2025, 12, 16),
        '-495.12',
        'Virement Web M. John Doe',
        tags: const ['likely-self-transfer'],
      ),
    ]);
  });

  test(
    'example 4: checking account, salary tag + multiple outgoing transfer variants',
    () {
      final result = parser.parse(
        _example4Pages,
        sourceFileName: 'example4.pdf',
      );

      expect(result.rowErrors, isEmpty);
      expect(result.balanceInfo?.openingBalance, Decimal.parse('14265.15'));
      expect(result.balanceInfo?.closingBalance, Decimal.parse('6160.71'));

      const selfTransfer = ['likely-self-transfer'];
      _expectCandidates(result.transactionCandidates, [
        _Expected(
          DateTime(2025, 8, 13),
          DateTime(2025, 8, 13),
          '-500.00',
          'Virement Web John Doe M. Doe John',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 8, 18),
          DateTime(2025, 8, 18),
          '-750.00',
          'Virement Vir Inst vers John Doe',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 8, 18),
          DateTime(2025, 8, 18),
          '-250.00',
          'Virement Vir Inst vers John Doe',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 8, 18),
          DateTime(2025, 8, 18),
          '-1500.00',
          'Virement Vir Inst vers John Doe',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 8, 18),
          DateTime(2025, 8, 18),
          '-500.00',
          'Virement Vir Inst vers John Doe',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 8, 20),
          DateTime(2025, 8, 20),
          '-1000.00',
          'Virement Web John Doe M. Doe John',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 8, 20),
          DateTime(2025, 8, 20),
          '-500.00',
          'Virement Web John Doe M. Doe John',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 8, 26),
          DateTime(2025, 8, 26),
          '4831.58',
          'Virement Acme Corp S.a. CDWQAD3C22HNCQ94EE2HK4XGH5 7Salary 08/2025',
          tags: const ['salary'],
        ),
        _Expected(
          DateTime(2025, 8, 26),
          DateTime(2025, 8, 26),
          '-750.00',
          'Virement Vir Inst vers John Doe',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 8, 26),
          DateTime(2025, 8, 26),
          '-1500.00',
          'Virement Vir Inst vers John Doe',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 8, 26),
          DateTime(2025, 8, 26),
          '-250.00',
          'Virement Vir Inst vers John Doe',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 8, 26),
          DateTime(2025, 8, 26),
          '-500.00',
          'Virement Vir Inst vers John Doe',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 8, 27),
          DateTime(2025, 8, 27),
          '-500.00',
          'Virement Web John Doe M. Doe John',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 9, 2),
          DateTime(2025, 9, 2),
          '-1500.00',
          'Virement Vir Inst vers John Doe',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 9, 2),
          DateTime(2025, 9, 2),
          '-1500.00',
          'Virement Vir Inst vers John Doe',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 9, 2),
          DateTime(2025, 9, 5),
          '-26.97',
          'Règlement Assu. Caae Prêt Habitat 09/25',
        ),
        _Expected(
          DateTime(2025, 9, 3),
          DateTime(2025, 9, 3),
          '-27.10',
          'Prlv 0214846 CRCAM De Lorraine Crédit Agricole AssuranceHabitation -echeance '
              '09/2025Cotisation Du Contrat Pacifica1329964290700000000000000000000013127158907PCK '
              'FR73ZZZ141674 Core',
        ),
        _Expected(
          DateTime(2025, 9, 3),
          DateTime(2025, 9, 3),
          '-500.00',
          'Virement Web John Doe M. Doe John',
          tags: selfTransfer,
        ),
        _Expected(
          DateTime(2025, 9, 5),
          DateTime(2025, 9, 5),
          '-12.00',
          'Prlv Uem Uem gaz EC2808202523828UEM206125 FR40ZZZ002976 Core',
        ),
        _Expected(
          DateTime(2025, 9, 5),
          DateTime(2025, 9, 5),
          '-27.00',
          'Prlv Uem Uem electricite EC2808202523824UEM206125 FR40ZZZ002976 Core',
        ),
        _Expected(
          DateTime(2025, 9, 5),
          DateTime(2025, 9, 5),
          '-86.00',
          'Ech Prêt 86474303241 Echéance 05/09/25',
        ),
        _Expected(
          DateTime(2025, 9, 5),
          DateTime(2025, 9, 5),
          '-756.95',
          'Ech Prêt 86474303240 Echéance 05/09/25',
        ),
      ]);
    },
  );

  test(
    'example 5: Livret A with only credit operations that period — "Total des opérations" '
    'prints a single number instead of two, and must not be mistaken for a parse failure',
    () {
      final result = parser.parse(
        _example5Pages,
        sourceFileName: 'example5.pdf',
      );

      expect(result.rowErrors, isEmpty);
      expect(result.balanceInfo?.openingBalance, Decimal.parse('10.69'));
      expect(result.balanceInfo?.closingBalance, Decimal.parse('10.73'));

      _expectCandidates(result.transactionCandidates, [
        _Expected(
          DateTime(2020, 12, 31),
          DateTime(2021, 1, 1),
          '0.04',
          "Intérêts De L'année Taux 0,500%",
        ),
      ]);
    },
  );

  test(
    'a transaction row with no terminating amount produces a StatementRowError instead of '
    'being silently dropped',
    () {
      const brokenPage = '''
CREDIT AGRICOLE
DE LORRAINE
 RELEVE DE COMPTES EN EUROS N° 001
M. Doe John - Compte Chèque n° 123456
þ
Ancien solde créditeur au 01.01.2024 100,00
01.01 01.01 Carte Some Shop
Total des opérations 0,00 0,00
Nouveau solde créditeur au 31.01.2024 100,00
''';
      final result = parser.parse(
        pageLayoutsFromText([brokenPage]),
        sourceFileName: 'broken.pdf',
      );

      expect(result.transactionCandidates, isEmpty);
      expect(result.rowErrors, hasLength(1));
      expect(result.rowErrors.single.message, contains('Carte Some Shop'));
    },
  );

  test(
    'a description matching no known debit/credit rule defaults to expense and is flagged',
    () {
      const oddPage = '''
CREDIT AGRICOLE
DE LORRAINE
 RELEVE DE COMPTES EN EUROS N° 001
M. Doe John - Compte Chèque n° 123456
þ
Ancien solde créditeur au 01.01.2024 100,00
01.01 01.01 Some Unrecognized Label 10,00 ¨
Total des opérations 10,00 0,00
Nouveau solde créditeur au 31.01.2024 90,00
''';
      final result = parser.parse(
        pageLayoutsFromText([oddPage]),
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
        contains('Some Unrecognized Label'),
      );
    },
  );

  test(
    'a description naming the account holder is tagged as a likely self-transfer, unlike '
    'a transfer to a family member',
    () {
      const page = '''
CREDIT AGRICOLE
DE LORRAINE
 RELEVE DE COMPTES EN EUROS N° 001
M. DOE JOHN
M. Doe John - Compte Chèque n° 123456
þ
Ancien solde créditeur au 01.01.2024 100,00
01.01 01.01 Virement Web Doe John 50,00 ¨
02.01 02.01 Virement De Maman 20,00 ¨
Total des opérations 50,00 20,00
Nouveau solde créditeur au 31.01.2024 70,00
''';
      final result = parser.parse(
        pageLayoutsFromText([page]),
        sourceFileName: 'holder.pdf',
      );

      expect(result.rowErrors, isEmpty);
      final selfTransfer = result.transactionCandidates.firstWhere(
        (c) => c.description.contains('Doe John'),
      );
      expect(selfTransfer.tags, contains('likely-self-transfer'));
      final familyTransfer = result.transactionCandidates.firstWhere(
        (c) => c.description.contains('Maman'),
      );
      expect(familyTransfer.tags, isNot(contains('likely-self-transfer')));
    },
  );

  test(
    'falls back to "Date d\'arrêté" for dating rows when "Nouveau solde" is missing, and '
    'flags the balance as unreconciled instead of silently dropping the rows',
    () {
      const page = '''
CREDIT AGRICOLE
DE LORRAINE
 RELEVE DE COMPTES EN EUROS N° 001
Date d'arrêté : 31 Janvier 2024
M. Doe John - Compte Chèque n° 123456
þ
Ancien solde créditeur au 01.01.2024 100,00
15.01 15.01 Carte Some Shop 10,00 ¨
Total des opérations 10,00 0,00
''';
      final result = parser.parse(
        pageLayoutsFromText([page]),
        sourceFileName: 'nonouveau.pdf',
      );

      expect(result.transactionCandidates, hasLength(1));
      expect(
        result.transactionCandidates.single.effectiveDate,
        CalendarDate(2024, 1, 15),
      );
      expect(result.rowErrors, hasLength(1));
      expect(result.rowErrors.single.message, contains('Nouveau solde'));
      expect(result.balanceInfo?.openingBalance, Decimal.parse('100.00'));
      expect(result.balanceInfo?.closingBalance, isNull);
    },
  );

  test(
    'a section missing "Ancien solde" reports a clear error instead of silently losing its '
    'rows',
    () {
      const page = '''
CREDIT AGRICOLE
DE LORRAINE
 RELEVE DE COMPTES EN EUROS N° 001
M. Doe John - Compte Chèque n° 123456
þ
15.01 15.01 Carte Some Shop 10,00 ¨
Total des opérations 10,00 0,00
Nouveau solde créditeur au 31.01.2024 90,00
''';
      final result = parser.parse(
        pageLayoutsFromText([page]),
        sourceFileName: 'noancien.pdf',
      );

      expect(result.transactionCandidates, isEmpty);
      expect(result.rowErrors, hasLength(1));
      expect(result.rowErrors.single.message, contains('Ancien solde'));
    },
  );

  test(
    'a document with no recognizable account section reports a clear error instead of '
    'silently returning nothing',
    () {
      const page = '''
CREDIT AGRICOLE
DE LORRAINE
 RELEVE DE COMPTES EN EUROS N° 001
Some unexpected layout with no section header at all.
''';
      final result = parser.parse(
        pageLayoutsFromText([page]),
        sourceFileName: 'weird.pdf',
      );

      expect(result.transactionCandidates, isEmpty);
      expect(result.rowErrors, hasLength(1));
      expect(
        result.rowErrors.single.message,
        contains('could not find any account section'),
      );
    },
  );

  test(
    'a section with rows on both sides but only one stated total skips the totals check '
    'instead of risking a false mismatch',
    () {
      const page = '''
CREDIT AGRICOLE
DE LORRAINE
 RELEVE DE COMPTES EN EUROS N° 001
M. Doe John - Compte Chèque n° 123456
þ
Ancien solde créditeur au 01.01.2024 100,00
01.01 01.01 Carte Some Shop 10,00 ¨
02.01 02.01 Virement Shopmium 5,00 ¨
Total des opérations 5,00
Nouveau solde créditeur au 31.01.2024 95,00
''';
      final result = parser.parse(
        pageLayoutsFromText([page]),
        sourceFileName: 'ambiguous.pdf',
      );

      expect(result.transactionCandidates, hasLength(2));
      expect(result.rowErrors, isEmpty);
    },
  );
}
