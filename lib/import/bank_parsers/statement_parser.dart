import 'package:decimal/decimal.dart';

import '../../domain/models.dart' show ContainerType;
import '../pdf_text_extractor.dart' show PdfPageLayout;
import '../../domain/calendar_date.dart';

class StatementRowError {
  final int rowIndex;
  final String message;

  const StatementRowError({required this.rowIndex, required this.message});
}

class StatementBalanceInfo {
  final Decimal? openingBalance;
  final Decimal? closingBalance;

  const StatementBalanceInfo({this.openingBalance, this.closingBalance});
}

class StagedTransactionCandidate {
  final String sourceFileName;

  final int sourceRowIndex;

  final CalendarDate effectiveDate;

  final DateTime? postingDate;

  DateTime get postedAt => postingDate ?? effectiveDate.toDateTime();

  final Decimal amount;

  final String description;

  final String containerHint;

  final ContainerType containerType;

  final String? resolvedContainerId;

  final String? budgetContainerId;

  final List<String> tags;

  final bool isCashTransaction;

  final String? tradeAssetHint;

  final Decimal? tradeAssetQuantity;

  final MatchSuggestion? matchedTransfer;

  const StagedTransactionCandidate({
    required this.sourceFileName,
    required this.sourceRowIndex,
    required this.effectiveDate,
    this.postingDate,
    required this.amount,
    required this.description,
    required this.containerHint,
    this.containerType = ContainerType.holder,
    this.resolvedContainerId,
    this.budgetContainerId,
    this.tags = const [],
    this.isCashTransaction = false,
    this.matchedTransfer,
    this.tradeAssetHint,
    this.tradeAssetQuantity,
  });

  String get candidateKey => '$sourceFileName#$sourceRowIndex';

  StagedTransactionCandidate copyWith({
    CalendarDate? effectiveDate,
    DateTime? postingDate,
    Decimal? amount,
    String? description,
    String? resolvedContainerId,
    String? budgetContainerId,
    List<String>? tags,
    bool? isCashTransaction,
    MatchSuggestion? matchedTransfer,
    bool clearMatchedTransfer = false,
    String? tradeAssetHint,
    Decimal? tradeAssetQuantity,
  }) => StagedTransactionCandidate(
    sourceFileName: sourceFileName,
    sourceRowIndex: sourceRowIndex,
    effectiveDate: effectiveDate ?? this.effectiveDate,
    postingDate: postingDate ?? this.postingDate,
    amount: amount ?? this.amount,
    description: description ?? this.description,
    containerHint: containerHint,
    containerType: containerType,
    resolvedContainerId: resolvedContainerId ?? this.resolvedContainerId,
    budgetContainerId: budgetContainerId ?? this.budgetContainerId,
    tags: tags ?? this.tags,
    isCashTransaction: isCashTransaction ?? this.isCashTransaction,
    matchedTransfer: clearMatchedTransfer
        ? null
        : (matchedTransfer ?? this.matchedTransfer),
    tradeAssetHint: tradeAssetHint ?? this.tradeAssetHint,
    tradeAssetQuantity: tradeAssetQuantity ?? this.tradeAssetQuantity,
  );
}

class StagedPriceSnapshotCandidate {
  final String sourceFileName;
  final int sourceRowIndex;

  final String assetHint;

  final DateTime date;
  final Decimal price;
  final String currencyHint;

  const StagedPriceSnapshotCandidate({
    required this.sourceFileName,
    required this.sourceRowIndex,
    required this.assetHint,
    required this.date,
    required this.price,
    required this.currencyHint,
  });

  String get candidateKey => '$sourceFileName#$sourceRowIndex';

  StagedPriceSnapshotCandidate copyWith({
    String? assetHint,
    DateTime? date,
    Decimal? price,
    String? currencyHint,
  }) => StagedPriceSnapshotCandidate(
    sourceFileName: sourceFileName,
    sourceRowIndex: sourceRowIndex,
    assetHint: assetHint ?? this.assetHint,
    date: date ?? this.date,
    price: price ?? this.price,
    currencyHint: currencyHint ?? this.currencyHint,
  );
}

class MatchSuggestion {
  final String? otherCandidateKey;

  final String? committedTransactionId;

  final String? duplicateOfCandidateKey;

  final bool isCertain;

  const MatchSuggestion.withCandidate(
    this.otherCandidateKey, {
    this.isCertain = false,
  }) : committedTransactionId = null,
       duplicateOfCandidateKey = null;

  const MatchSuggestion.withCommitted(this.committedTransactionId)
    : otherCandidateKey = null,
      duplicateOfCandidateKey = null,
      isCertain = false;

  const MatchSuggestion.duplicateOfCandidate(this.duplicateOfCandidateKey)
    : otherCandidateKey = null,
      committedTransactionId = null,
      isCertain = false;

  const MatchSuggestion.certainPair(this.otherCandidateKey)
    : committedTransactionId = null,
      duplicateOfCandidateKey = null,
      isCertain = true;
}

class StatementParseResult {
  final List<StagedTransactionCandidate> transactionCandidates;
  final List<StagedPriceSnapshotCandidate> priceCandidates;
  final List<StatementRowError> rowErrors;

  final StatementBalanceInfo? balanceInfo;

  const StatementParseResult({
    this.transactionCandidates = const [],
    this.priceCandidates = const [],
    this.rowErrors = const [],
    this.balanceInfo,
  });
}

abstract class StatementParser<TRaw> {
  String get parserId;

  bool canParse(TRaw raw);

  StatementParseResult parse(TRaw raw, {required String sourceFileName});
}

abstract class PdfStatementParser
    extends StatementParser<List<PdfPageLayout>> {}

abstract class TabularStatementParser
    extends StatementParser<List<List<String>>> {}
