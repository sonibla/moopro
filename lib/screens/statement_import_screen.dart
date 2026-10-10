import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/id_generator.dart';
import '../domain/models.dart';
import '../import/already_recorded_match_engine.dart';
import '../import/bank_parsers/statement_import_registry.dart';
import '../import/bank_parsers/statement_parser.dart';
import '../import/csv_row_extractor.dart';
import '../import/pdf_text_extractor.dart';
import '../import/statement_import_hint_memory.dart';
import '../import/transfer_match_engine.dart';
import '../import/xlsx_row_extractor.dart';
import '../import/zip_file_helper.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_form_dialog.dart';
import '../widgets/asset_picker.dart';
import '../widgets/container_picker.dart';
import '../domain/calendar_date.dart';

class StatementImportScreen extends ConsumerStatefulWidget {
  const StatementImportScreen({super.key});

  @override
  ConsumerState<StatementImportScreen> createState() =>
      _StatementImportScreenState();
}

enum _Step { pickFiles, parsing, review, importing, done }

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

enum _CandidateKindFilter { all, transactions, prices }

enum _FileKind { statement, unrecognized }

enum _SortKey { date, amount }

class _StatementImportScreenState extends ConsumerState<StatementImportScreen> {
  _Step _step = _Step.pickFiles;
  String? _pickError;

  int _parseDone = 0;
  int _parseTotal = 0;

  List<StagedTransactionCandidate> _txCandidates = [];
  final List<StagedPriceSnapshotCandidate> _priceCandidates = [];
  final Map<String, StatementBalanceInfo> _balanceInfoByFile = {};
  final Map<String, List<StatementRowError>> _rowErrorsByFile = {};
  final List<String> _unparsedFiles = [];
  final List<String> _duplicateFilesSkipped = [];

  final Map<String, String> _holderResolutions = {};
  final Map<String, String> _budgetTransferResolutions = {};
  final Map<String, String> _assetResolutions = {};
  final Set<String> _newlyCreatedAssetIds = {};
  String? _txAssetId;

  int _manualCandidateCounter = 0;

  String? _sourceFilter;
  bool _needsAttentionOnly = false;
  _CandidateKindFilter _kindFilter = _CandidateKindFilter.all;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _SortKey _sortKey = _SortKey.date;
  bool _sortAscending = true;

  final Set<String> _selectedCandidateKeys = {};
  bool _selectionModeForced = false;
  bool get _selecting =>
      _selectedCandidateKeys.isNotEmpty || _selectionModeForced;

  int _importDone = 0;
  int _importTotal = 0;
  int? _importedTxCount;
  int? _importedPriceCount;
  int? _skippedAlreadyRecordedCount;
  int? _skippedDuplicateInBatchCount;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (_step) {
      case _Step.pickFiles:
        body = _buildPickFiles(context);
        break;
      case _Step.parsing:
        body = _buildParsing(context);
        break;
      case _Step.review:
        body = _buildReview(context);
        break;
      case _Step.importing:
        body = _buildImporting(context);
        break;
      case _Step.done:
        body = _buildDone(context);
        break;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Import statements')),
      body: body,
    );
  }

  Widget _buildPickFiles(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pick one or more downloaded statements (PDF, CSV, or XLSX) and/or a .zip '
              'archive bundling any of these (optionally password-protected, '
              'subfolders OK) — they can be mixed in one import.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _pickAndParseFiles,
              icon: const Icon(Icons.file_open),
              label: const Text('Choose files'),
            ),
            if (_pickError != null) ...[
              const SizedBox(height: 16),
              Text(
                _pickError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParsing(BuildContext context) {
    final progress = _parseTotal == 0 ? 0.0 : _parseDone / _parseTotal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 16),
            Text('Parsed $_parseDone of $_parseTotal files'),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndParseFiles() async {
    setState(() => _pickError = null);
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _step = _Step.parsing);

    final entries = <(String name, Uint8List bytes)>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      if (looksLikeZip(file.name)) {
        final extracted = await _extractZipEntries(file.name, bytes);
        if (extracted == null) {
          _unparsedFiles.add(file.name);
        } else {
          entries.addAll([for (final e in extracted) (e.path, e.bytes)]);
        }
      } else {
        entries.add((file.name, bytes));
      }
    }

    final deduped = <(String name, Uint8List bytes)>[];
    for (final entry in entries) {
      (String name, Uint8List bytes)? earlierDuplicate;
      for (final seen in deduped) {
        if (_bytesEqual(seen.$2, entry.$2)) {
          earlierDuplicate = seen;
          break;
        }
      }
      if (earlierDuplicate != null) {
        _duplicateFilesSkipped.add(
          '${entry.$1} (identical to ${earlierDuplicate.$1})',
        );
      } else {
        deduped.add(entry);
      }
    }
    entries
      ..clear()
      ..addAll(deduped);

    setState(() {
      _parseDone = 0;
      _parseTotal = entries.length;
    });

    final registry = ref.read(statementImportRegistryProvider);
    final txCandidates = <StagedTransactionCandidate>[];
    final priceCandidates = <StagedPriceSnapshotCandidate>[];

    for (final entry in entries) {
      final bytes = entry.$2;
      final name = entry.$1;
      try {
        switch (_classifyFile(name)) {
          case _FileKind.statement:
            final parsed = await _parseStatementFile(name, bytes, registry);
            if (parsed == null) {
              _unparsedFiles.add(name);
            } else {
              txCandidates.addAll(parsed.transactionCandidates);
              priceCandidates.addAll(parsed.priceCandidates);
              if (parsed.rowErrors.isNotEmpty) {
                _rowErrorsByFile[name] = parsed.rowErrors;
              }
              if (parsed.balanceInfo != null) {
                _balanceInfoByFile[name] = parsed.balanceInfo!;
              }
            }
            break;
          case _FileKind.unrecognized:
            _unparsedFiles.add(name);
            break;
        }
      } catch (e) {
        _unparsedFiles.add(name);
        _rowErrorsByFile[name] = [
          StatementRowError(
            rowIndex: -1,
            message:
                'This file could not be parsed due to an unexpected error: $e',
          ),
        ];
      }
      if (!mounted) return;
      setState(() => _parseDone++);
    }

    final committedTransactions = await ref
        .read(domainRepositoryProvider)
        .watchTransactions()
        .first;
    var matched = const TransferMatchEngine().applyMatches(
      candidates: txCandidates,
      existingCommitted: committedTransferLegsFrom(committedTransactions),
    );
    matched = const AlreadyRecordedMatchEngine().applyMatches(
      candidates: matched,
      existingCommitted: committedCandidateSignaturesFrom(
        committedTransactions,
        fiatAssetId: _txAssetId,
      ),
    );

    await _prefillRememberedResolutions(
      candidates: matched,
      newPriceCandidates: priceCandidates,
    );

    if (!mounted) return;
    setState(() {
      _txCandidates = matched;
      _priceCandidates.addAll(priceCandidates);
      _step = _Step.review;
    });
  }

  Future<ImportHintResolutions> _readRememberedResolutions() async {
    final setting = await ref
        .read(domainRepositoryProvider)
        .watchSetting(SettingIds.statementImportHintResolutions)
        .first;
    return ImportHintResolutions.decode(setting?.value);
  }

  Future<void> _prefillRememberedResolutions({
    required List<StagedTransactionCandidate> candidates,
    required List<StagedPriceSnapshotCandidate> newPriceCandidates,
  }) async {
    final remembered = await _readRememberedResolutions();

    final domainRepository = ref.read(domainRepositoryProvider);
    final containerIds = (await domainRepository.watchContainers().first)
        .map((c) => c.id)
        .toSet();
    final assetIds = (await domainRepository.watchAssets().first)
        .map((a) => a.id)
        .toSet();

    for (final c in candidates) {
      if (c.resolvedContainerId != null) continue;
      final rememberedMap = c.containerType == ContainerType.budget
          ? remembered.budgetTransfers
          : remembered.holders;
      final resolutions = c.containerType == ContainerType.budget
          ? _budgetTransferResolutions
          : _holderResolutions;
      if (resolutions.containsKey(c.containerHint)) continue;
      final rememberedId = rememberedMap[c.containerHint];
      if (rememberedId != null && containerIds.contains(rememberedId)) {
        resolutions[c.containerHint] = rememberedId;
      }
    }

    final assetHints = {
      ...candidates.map((c) => c.tradeAssetHint).whereType<String>(),
      ...newPriceCandidates.expand((c) => [c.assetHint, c.currencyHint]),
    };
    for (final hint in assetHints) {
      if (_assetResolutions.containsKey(hint)) continue;
      final rememberedId = remembered.assets[hint];
      if (rememberedId != null && assetIds.contains(rememberedId)) {
        _assetResolutions[hint] = rememberedId;
      }
    }
  }

  Future<void> _persistHolderResolution(String hint, String containerId) async {
    final remembered = await _readRememberedResolutions();
    await ref
        .read(domainRepositoryProvider)
        .setSetting(
          SettingIds.statementImportHintResolutions,
          remembered.withHolder(hint, containerId).encode(),
        );
  }

  Future<void> _persistBudgetTransferResolution(
    String hint,
    String containerId,
  ) async {
    final remembered = await _readRememberedResolutions();
    await ref
        .read(domainRepositoryProvider)
        .setSetting(
          SettingIds.statementImportHintResolutions,
          remembered.withBudgetTransfer(hint, containerId).encode(),
        );
  }

  Future<void> _persistAssetResolution(String hint, String assetId) async {
    final remembered = await _readRememberedResolutions();
    await ref
        .read(domainRepositoryProvider)
        .setSetting(
          SettingIds.statementImportHintResolutions,
          remembered.withAsset(hint, assetId).encode(),
        );
  }

  _FileKind _classifyFile(String name) {
    final lower = name.toLowerCase();
    final ext = lower.contains('.') ? lower.split('.').last : '';
    return const {'pdf', 'csv', 'xlsx', 'xls'}.contains(ext)
        ? _FileKind.statement
        : _FileKind.unrecognized;
  }

  Future<StatementParseResult?> _parseStatementFile(
    String fileName,
    Uint8List bytes,
    StatementImportRegistry registry,
  ) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'pdf':
        final pages = await extractPdfPageLayouts(bytes);
        return registry.tryParsePdf(pages, fileName);
      case 'csv':
        final rows = extractCsvRows(utf8.decode(bytes, allowMalformed: true));
        return registry.tryParseTabular(rows, fileName);
      case 'xlsx':
      case 'xls':
        final rows = extractXlsxRows(bytes);
        return registry.tryParseTabular(rows, fileName);
      default:
        return null;
    }
  }

  Future<List<ExtractedZipEntry>?> _extractZipEntries(
    String name,
    Uint8List bytes,
  ) async {
    try {
      return extractZip(bytes);
    } on ZipPasswordRequiredException {
      // ignore: empty_catches
    } on ZipTooLargeException catch (e) {
      _rowErrorsByFile[name] = [
        StatementRowError(rowIndex: -1, message: e.toString()),
      ];
      return null;
    }

    while (true) {
      if (!mounted) return null;
      final password = await _promptZipPassword(name);
      if (password == null) return null;
      try {
        return extractZip(bytes, password: password);
      } on ZipTooLargeException catch (e) {
        _rowErrorsByFile[name] = [
          StatementRowError(rowIndex: -1, message: e.toString()),
        ];
        return null;
      } catch (_) {
        if (!mounted) return null;
        final retry = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Decryption failed'),
            content: const Text(
              'Wrong password, or this is not a valid password-protected zip. Try again?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
        if (retry != true) return null;
      }
    }
  }

  Future<String?> _promptZipPassword(String fileName) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Encrypted archive: $fileName'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Zip password'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Decrypt'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  void _setTxAssetId(String id) {
    setState(() => _txAssetId = id);
    unawaited(_applyAlreadyRecordedTradeMatches());
  }

  Future<void> _applyAlreadyRecordedTradeMatches() async {
    final committedTransactions = await ref
        .read(domainRepositoryProvider)
        .watchTransactions()
        .first;
    final matched = const AlreadyRecordedMatchEngine().applyMatches(
      candidates: _txCandidates,
      existingCommitted: committedCandidateSignaturesFrom(
        committedTransactions,
        fiatAssetId: _txAssetId,
      ),
    );
    if (!mounted) return;
    setState(() => _txCandidates = matched);
  }

  bool _isSkippedOnCommit(StagedTransactionCandidate c) =>
      c.matchedTransfer?.committedTransactionId != null ||
      c.matchedTransfer?.duplicateOfCandidateKey != null;

  Set<String> get _uniqueHolderHints => _txCandidates
      .where(
        (c) =>
            c.containerType == ContainerType.holder &&
            c.resolvedContainerId == null &&
            !_isSkippedOnCommit(c),
      )
      .map((c) => c.containerHint)
      .toSet();

  Set<String> get _uniqueBudgetTransferHints => _txCandidates
      .where(
        (c) =>
            c.containerType == ContainerType.budget &&
            c.resolvedContainerId == null &&
            !_isSkippedOnCommit(c),
      )
      .map((c) => c.containerHint)
      .toSet();

  Set<String> get _uniquePriceAssetHints =>
      _priceCandidates.expand((c) => [c.assetHint, c.currencyHint]).toSet();

  Set<String> get _uniqueTradeAssetHints =>
      _txCandidates.map((c) => c.tradeAssetHint).whereType<String>().toSet();

  Set<String> get _uniqueAssetHintsToResolve => {
    ..._uniquePriceAssetHints,
    ..._uniqueTradeAssetHints,
  };

  bool get _needsTxAsset => _txCandidates.isNotEmpty;

  bool _needsBudgetAssignment(StagedTransactionCandidate c) =>
      c.containerType == ContainerType.holder &&
      c.matchedTransfer == null &&
      c.budgetContainerId == null;

  bool _fileHasBalanceMismatch(String fileName) {
    final info = _balanceInfoByFile[fileName];
    final opening = info?.openingBalance;
    final closing = info?.closingBalance;
    if (opening == null || closing == null) return false;
    final parsedSum = _txCandidates
        .where((c) => c.sourceFileName == fileName)
        .fold(Decimal.zero, (sum, c) => sum + c.amount);
    return (closing - opening) - parsedSum != Decimal.zero;
  }

  bool _needsAttention(StagedTransactionCandidate c) {
    if (c.resolvedContainerId == null) {
      final resolved = c.containerType == ContainerType.budget
          ? _budgetTransferResolutions.containsKey(c.containerHint)
          : _holderResolutions.containsKey(c.containerHint);
      if (!resolved) return true;
    }
    if (_needsBudgetAssignment(c)) return true;
    if (_fileHasBalanceMismatch(c.sourceFileName)) return true;
    if (c.tradeAssetHint != null &&
        !_assetResolutions.containsKey(c.tradeAssetHint!)) {
      return true;
    }
    return false;
  }

  bool _priceCandidateNeedsAttention(StagedPriceSnapshotCandidate c) =>
      !_assetResolutions.containsKey(c.assetHint) ||
      !_assetResolutions.containsKey(c.currencyHint);

  List<String> get _availableSources => {
    for (final c in _txCandidates) c.sourceFileName,
    for (final c in _priceCandidates) c.sourceFileName,
  }.toList()..sort();

  List<StagedTransactionCandidate> get _visibleTxCandidates {
    final filtered = _txCandidates.where((c) {
      if (_kindFilter == _CandidateKindFilter.prices) return false;
      if (_sourceFilter != null && c.sourceFileName != _sourceFilter) {
        return false;
      }
      if (_needsAttentionOnly && !_needsAttention(c)) return false;
      if (_searchQuery.isNotEmpty &&
          !c.description.toLowerCase().contains(_searchQuery) &&
          !c.containerHint.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();
    filtered.sort((a, b) {
      final cmp = _sortKey == _SortKey.date
          ? a.effectiveDate.compareTo(b.effectiveDate)
          : a.amount.compareTo(b.amount);
      return _sortAscending ? cmp : -cmp;
    });
    return filtered;
  }

  void _toggleSelected(String candidateKey, bool selected) {
    setState(() {
      if (selected) {
        _selectedCandidateKeys.add(candidateKey);
      } else {
        _selectedCandidateKeys.remove(candidateKey);
      }
    });
  }

  void _enterSelectionMode() => setState(() => _selectionModeForced = true);

  void _clearSelection() => setState(() {
    _selectedCandidateKeys.clear();
    _selectionModeForced = false;
  });

  bool get _allVisibleSelected {
    final visible = _visibleTxCandidates;
    return visible.isNotEmpty &&
        visible.every((c) => _selectedCandidateKeys.contains(c.candidateKey));
  }

  void _toggleSelectAllVisible(bool selectAll) {
    setState(() {
      final visibleKeys = _visibleTxCandidates.map((c) => c.candidateKey);
      if (selectAll) {
        _selectedCandidateKeys.addAll(visibleKeys);
      } else {
        _selectedCandidateKeys.removeAll(visibleKeys);
      }
    });
  }

  Future<void> _bulkAssignBudget() async {
    final count = _selectedCandidateKeys.length;
    final result = await showContainerPicker(
      context: context,
      type: ContainerType.budget,
      title: 'Assign a budget to $count transaction${count == 1 ? '' : 's'}',
    );
    final budgetId = result?.containerId;
    if (budgetId == null) return;
    setState(() {
      for (var i = 0; i < _txCandidates.length; i++) {
        if (_selectedCandidateKeys.contains(_txCandidates[i].candidateKey)) {
          _txCandidates[i] = _txCandidates[i].copyWith(
            budgetContainerId: budgetId,
          );
        }
      }
    });
    _clearSelection();
  }

  Future<void> _bulkDelete() async {
    final count = _selectedCandidateKeys.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count candidate${count == 1 ? '' : 's'}?'),
        content: const Text(
          'This only removes them from this import review — nothing has been committed yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      final toRemove = <String>{..._selectedCandidateKeys};
      for (final key in _selectedCandidateKeys) {
        final c = _txCandidates.firstWhere((x) => x.candidateKey == key);
        final match = c.matchedTransfer;
        if (match?.otherCandidateKey != null) {
          if (match!.isCertain) {
            toRemove.add(match.otherCandidateKey!);
          } else {
            final idx = _txCandidates.indexWhere(
              (x) => x.candidateKey == match.otherCandidateKey,
            );
            if (idx != -1) {
              _txCandidates[idx] = _txCandidates[idx].copyWith(
                clearMatchedTransfer: true,
              );
            }
          }
        }
      }
      _txCandidates.removeWhere((x) => toRemove.contains(x.candidateKey));
    });
    _clearSelection();
  }

  List<StagedPriceSnapshotCandidate> get _visiblePriceCandidates =>
      _priceCandidates.where((c) {
        if (_kindFilter == _CandidateKindFilter.transactions) return false;
        if (_sourceFilter != null && c.sourceFileName != _sourceFilter) {
          return false;
        }
        if (_needsAttentionOnly && !_priceCandidateNeedsAttention(c)) {
          return false;
        }
        return true;
      }).toList();

  bool get _canCommit =>
      (_txCandidates.isNotEmpty || _priceCandidates.isNotEmpty) &&
      (!_needsTxAsset || _txAssetId != null) &&
      _uniqueHolderHints.every((h) => _holderResolutions.containsKey(h)) &&
      _uniqueBudgetTransferHints.every(
        (h) => _budgetTransferResolutions.containsKey(h),
      ) &&
      _uniqueAssetHintsToResolve.every(
        (h) => _assetResolutions.containsKey(h),
      ) &&
      _txCandidates.every((c) => !_needsBudgetAssignment(c));

  static const double _candidateRowHeight = 72;

  Widget _buildReview(BuildContext context) {
    final assets = ref.watch(assetsStreamProvider).value ?? const [];
    final containers = ref.watch(containersStreamProvider).value ?? const [];
    final visibleTx = _visibleTxCandidates;

    return Column(
      children: [
        _selecting ? _buildBulkActionBar(context) : _buildToolbar(context),
        const Divider(height: 1),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_unparsedFiles.isNotEmpty)
                        _sectionCard(
                          context,
                          title:
                              '${_unparsedFiles.length} file(s) no parser recognized',
                          color: Theme.of(context).colorScheme.error,
                          children: [for (final f in _unparsedFiles) Text(f)],
                        ),
                      if (_duplicateFilesSkipped.isNotEmpty)
                        _sectionCard(
                          context,
                          title:
                              '${_duplicateFilesSkipped.length} duplicate file(s) skipped',
                          children: [
                            for (final f in _duplicateFilesSkipped) Text(f),
                          ],
                        ),
                      for (final entry in _rowErrorsByFile.entries)
                        _sectionCard(
                          context,
                          title:
                              '${entry.key}: ${entry.value.length} row(s) could not be parsed',
                          children: [
                            for (final e in entry.value)
                              Text('Row ${e.rowIndex}: ${e.message}'),
                          ],
                        ),
                      for (final entry in _balanceInfoByFile.entries)
                        _buildReconciliation(context, entry.key, entry.value),
                      if (_needsTxAsset)
                        _buildAssetForTransactions(context, assets),
                      if (_uniqueHolderHints.isNotEmpty) ...[
                        const Divider(height: 32),
                        Text(
                          'Assign each account to a holder',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final hint in _uniqueHolderHints)
                          _buildHolderResolutionTile(context, hint, containers),
                      ],
                      if (_uniqueBudgetTransferHints.isNotEmpty) ...[
                        const Divider(height: 32),
                        Text(
                          'Assign each budget transfer leg to a budget',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final hint in _uniqueBudgetTransferHints)
                          _buildBudgetTransferResolutionTile(
                            context,
                            hint,
                            containers,
                          ),
                      ],
                      if (_uniqueAssetHintsToResolve.isNotEmpty) ...[
                        const Divider(height: 32),
                        Text(
                          'Assign each asset',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final hint in _uniqueAssetHintsToResolve)
                          _buildAssetResolutionTile(context, hint, assets),
                      ],
                      if (_txCandidates.isNotEmpty) ...[
                        const Divider(height: 32),
                        Text(
                          '${visibleTx.length} of ${_txCandidates.length} transaction candidates',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
              ),
              if (visibleTx.isEmpty && _txCandidates.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Text(
                      'No candidates match the current search/filters.',
                    ),
                  ),
                )
              else
                SliverFixedExtentList(
                  itemExtent: _candidateRowHeight,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCandidateRow(
                      context,
                      visibleTx[index],
                      containers,
                    ),
                    childCount: visibleTx.length,
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildPriceCandidatesSection(context, assets),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
        _buildCommitBar(context),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final sources = _availableSources;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search description or account',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<_SortKey>(
                tooltip: 'Sort by',
                icon: const Icon(Icons.sort),
                onSelected: (key) => setState(() {
                  if (_sortKey == key) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortKey = key;
                    _sortAscending = true;
                  }
                }),
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: _SortKey.date,
                    checked: _sortKey == _SortKey.date,
                    child: const Text('Sort by date'),
                  ),
                  CheckedPopupMenuItem(
                    value: _SortKey.amount,
                    checked: _sortKey == _SortKey.amount,
                    child: const Text('Sort by amount'),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: 'Select transactions',
                onPressed: _txCandidates.isEmpty ? null : _enterSelectionMode,
              ),
              TextButton.icon(
                onPressed: _addManualTransactionCandidate,
                icon: const Icon(Icons.add),
                label: const Text('Add transaction'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                avatar: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Needs attention'),
                selected: _needsAttentionOnly,
                onSelected: (v) => setState(() => _needsAttentionOnly = v),
              ),
              SegmentedButton<_CandidateKindFilter>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _CandidateKindFilter.all,
                    label: Text('All'),
                  ),
                  ButtonSegment(
                    value: _CandidateKindFilter.transactions,
                    label: Text('Transactions'),
                  ),
                  ButtonSegment(
                    value: _CandidateKindFilter.prices,
                    label: Text('Prices'),
                  ),
                ],
                selected: {_kindFilter},
                onSelectionChanged: (selection) =>
                    setState(() => _kindFilter = selection.first),
              ),
            ],
          ),
          if (sources.length > 1) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _sourceFilter,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Source',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All sources')),
                for (final source in sources)
                  DropdownMenuItem(
                    value: source,
                    child: Text(source, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _sourceFilter = v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBulkActionBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = TextStyle(
      color: scheme.onInverseSurface,
      fontWeight: FontWeight.w600,
    );
    return Material(
      color: scheme.inverseSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: _allVisibleSelected,
              onChanged: (v) => _toggleSelectAllVisible(v ?? false),
            ),
            Expanded(
              child: Text(
                '${_selectedCandidateKeys.length} selected',
                style: TextStyle(
                  color: scheme.onInverseSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _selectedCandidateKeys.isEmpty
                  ? null
                  : _bulkAssignBudget,
              child: Text('Assign budget', style: textStyle),
            ),
            TextButton(
              onPressed: _selectedCandidateKeys.isEmpty ? null : _bulkDelete,
              child: Text('Delete', style: textStyle),
            ),
            TextButton(
              onPressed: _clearSelection,
              child: Text('Cancel', style: textStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitBar(BuildContext context) {
    return Material(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_txCandidates.length} transaction(s) · ${_priceCandidates.length} price(s)',
              ),
            ),
            FilledButton(
              onPressed: _canCommit ? _runImport : null,
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    Color? color,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        iconColor: color,
        collapsedIconColor: color,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildReconciliation(
    BuildContext context,
    String fileName,
    StatementBalanceInfo info,
  ) {
    if (!_fileHasBalanceMismatch(fileName)) return const SizedBox.shrink();
    final opening = info.openingBalance!;
    final closing = info.closingBalance!;
    final parsedSum = _txCandidates
        .where((c) => c.sourceFileName == fileName)
        .fold(Decimal.zero, (sum, c) => sum + c.amount);
    final diff = (closing - opening) - parsedSum;
    return _sectionCard(
      context,
      title: '$fileName: $diff unaccounted for',
      color: Theme.of(context).colorScheme.error,
      children: [
        const Text(
          'This statement\'s declared balance doesn\'t match the '
          'parsed rows — it may have rows the parser couldn\'t read.',
        ),
      ],
    );
  }

  Widget _buildAssetForTransactions(
    BuildContext context,
    List<ldb.Asset> assets,
  ) {
    if (_txAssetId != null) return const SizedBox.shrink();
    final fiatAssets = assets
        .where((a) => a.kind == AssetKind.fiat.name)
        .toList();
    if (fiatAssets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _txAssetId == null) _setTxAssetId(fiatAssets.first.id);
      });
      return const SizedBox.shrink();
    }
    return _sectionCard(
      context,
      title: 'No fiat asset exists yet',
      children: [
        FilledButton(
          onPressed: () async {
            final eur = await ref
                .read(domainRepositoryProvider)
                .createAsset(kind: AssetKind.fiat, symbol: 'EUR', name: 'Euro');
            if (mounted) _setTxAssetId(eur.id);
          },
          child: const Text('Create EUR asset'),
        ),
      ],
    );
  }

  Widget _buildHolderResolutionTile(
    BuildContext context,
    String hint,
    List<ldb.Container> containers,
  ) {
    final resolvedId = _holderResolutions[hint];
    final resolvedName = resolvedId == null
        ? null
        : containers
              .where((c) => c.id == resolvedId)
              .map((c) => c.name)
              .firstOrNull;
    return ListTile(
      title: Text(hint),
      subtitle: resolvedName == null
          ? const Text('Not assigned yet')
          : Text('-> $resolvedName'),
      trailing: FilledButton(
        onPressed: () async {
          final result = await showContainerPicker(
            context: context,
            type: ContainerType.holder,
            title: 'Assign "$hint" to a holder',
            selectedId: resolvedId,
          );
          if (result?.containerId != null) {
            setState(() => _holderResolutions[hint] = result!.containerId!);
            await _persistHolderResolution(hint, result!.containerId!);
          }
        },
        child: Text(resolvedName == null ? 'Assign' : 'Change'),
      ),
    );
  }

  Widget _buildBudgetTransferResolutionTile(
    BuildContext context,
    String hint,
    List<ldb.Container> containers,
  ) {
    final resolvedId = _budgetTransferResolutions[hint];
    final resolvedName = resolvedId == null
        ? null
        : containers
              .where((c) => c.id == resolvedId)
              .map((c) => c.name)
              .firstOrNull;
    return ListTile(
      title: Text(hint),
      subtitle: resolvedName == null
          ? const Text('Not assigned yet')
          : Text('-> $resolvedName'),
      trailing: FilledButton(
        onPressed: () async {
          final result = await showContainerPicker(
            context: context,
            type: ContainerType.budget,
            title: 'Assign "$hint" to a budget',
            selectedId: resolvedId,
          );
          if (result?.containerId != null) {
            setState(
              () => _budgetTransferResolutions[hint] = result!.containerId!,
            );
            await _persistBudgetTransferResolution(hint, result!.containerId!);
          }
        },
        child: Text(resolvedName == null ? 'Assign' : 'Change'),
      ),
    );
  }

  Widget _buildAssetResolutionTile(
    BuildContext context,
    String hint,
    List<ldb.Asset> assets,
  ) {
    final resolvedId = _assetResolutions[hint];
    final resolvedName = resolvedId == null
        ? null
        : assets
              .where((a) => a.id == resolvedId)
              .map((a) => a.symbol)
              .firstOrNull;
    return ListTile(
      title: Text(hint),
      subtitle: resolvedName == null
          ? const Text('Not assigned yet')
          : Text('-> $resolvedName'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () async {
              final created = await showDialog<Asset>(
                context: context,
                builder: (_) => const AssetFormDialog(),
              );
              if (created != null) {
                setState(() {
                  _assetResolutions[hint] = created.id;
                  _newlyCreatedAssetIds.add(created.id);
                });
                await _persistAssetResolution(hint, created.id);
              }
            },
            child: const Text('Create new'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              final result = await showAssetPicker(
                context: context,
                assets: assets,
                selectedId: resolvedId,
                title: 'Assign "$hint"',
              );
              if (result != null) {
                setState(() => _assetResolutions[hint] = result);
                await _persistAssetResolution(hint, result);
              }
            },
            child: Text(resolvedName == null ? 'Assign' : 'Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateRow(
    BuildContext context,
    StagedTransactionCandidate c,
    List<ldb.Container> containers,
  ) {
    final theme = Theme.of(context);
    final selected = _selectedCandidateKeys.contains(c.candidateKey);
    final needsAttention = _needsAttention(c);
    final isNegative = c.amount < Decimal.zero;
    final amountColor = isNegative
        ? AppTheme.negativeAmountColor(theme.brightness)
        : AppTheme.positiveAmountColor(theme.brightness);
    final budgetName = c.budgetContainerId == null
        ? null
        : containers
              .where((x) => x.id == c.budgetContainerId)
              .map((x) => x.name)
              .firstOrNull;

    return Container(
      height: _candidateRowHeight,
      color: selected ? AppTheme.accentSoft(theme.brightness) : null,
      child: InkWell(
        onTap: _selecting
            ? () => _toggleSelected(c.candidateKey, !selected)
            : () => _editTransactionCandidate(c),
        onLongPress: () => _toggleSelected(c.candidateKey, true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: _selecting
                    ? Checkbox(
                        value: selected,
                        onChanged: (v) =>
                            _toggleSelected(c.candidateKey, v ?? false),
                      )
                    : Tooltip(
                        message: needsAttention
                            ? _attentionReasons(c).join('\n')
                            : 'Ready to import',
                        child: Icon(
                          needsAttention
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          size: 20,
                          color: needsAttention
                              ? theme.colorScheme.error
                              : AppTheme.positiveAmountColor(theme.brightness),
                        ),
                      ),
              ),
              SizedBox(
                width: 76,
                child: Text(
                  c.effectiveDate.toIso(),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: 84,
                child: Text(
                  c.amount.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: AppTheme.amountTextStyle(
                    theme.textTheme.bodyMedium,
                  ).copyWith(color: amountColor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.tradeAssetHint == null
                          ? c.description
                          : 'Trade: ${isNegative ? 'buy' : 'sell'} ${c.tradeAssetQuantity} '
                                '${c.tradeAssetHint} — ${c.description}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      needsAttention
                          ? _attentionReasons(c).join(' · ')
                          : c.sourceFileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: needsAttention
                            ? theme.colorScheme.error
                            : AppTheme.inkFaint(theme.brightness),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildCandidateStatus(context, c, budgetName),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
                onPressed: () => _editTransactionCandidate(c),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                onPressed: () => _deleteTransactionCandidate(c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateStatus(
    BuildContext context,
    StagedTransactionCandidate c,
    String? budgetName,
  ) {
    final theme = Theme.of(context);
    final match = c.matchedTransfer;

    if (match != null) {
      if (match.committedTransactionId != null) {
        return _compactActionText(
          context,
          'Already recorded',
          onReject: () => _clearCandidateMatch(c),
        );
      }
      if (match.duplicateOfCandidateKey != null) {
        return _compactActionText(
          context,
          'Duplicate in this import',
          onReject: () => _clearCandidateMatch(c),
        );
      }
      if (match.isCertain) {
        final label = c.tags.contains('confirmed-by-statement')
            ? 'Known transfer (confirmed by statement)'
            : 'Known transfer';
        return Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        );
      }
      return _compactActionText(
        context,
        'Matched transfer',
        onReject: () => _clearCandidateMatch(c),
      );
    }
    if (_needsBudgetAssignment(c)) {
      return SizedBox(
        height: 30,
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: () => _assignBudgetToSingle(c),
          child: const Text('Assign budget', style: TextStyle(fontSize: 12)),
        ),
      );
    }
    if (c.tradeAssetHint != null &&
        !_assetResolutions.containsKey(c.tradeAssetHint!)) {
      return Text(
        'Asset not assigned yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
    return Text(
      budgetName ?? '—',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall,
    );
  }

  Widget _compactActionText(
    BuildContext context,
    String label, {
    required VoidCallback onReject,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 14),
          tooltip: 'Reject match',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.only(left: 4),
          onPressed: onReject,
        ),
      ],
    );
  }

  List<String> _attentionReasons(StagedTransactionCandidate c) {
    final reasons = <String>[];
    if (c.resolvedContainerId == null) {
      final resolved = c.containerType == ContainerType.budget
          ? _budgetTransferResolutions.containsKey(c.containerHint)
          : _holderResolutions.containsKey(c.containerHint);
      if (!resolved) reasons.add('Account not assigned yet');
    }
    if (_needsBudgetAssignment(c)) reasons.add('No budget assigned');
    if (_fileHasBalanceMismatch(c.sourceFileName)) {
      reasons.add('Statement balance mismatch');
    }
    if (c.tradeAssetHint != null &&
        !_assetResolutions.containsKey(c.tradeAssetHint!)) {
      reasons.add('Trade asset not assigned yet');
    }
    return reasons;
  }

  void _clearCandidateMatch(StagedTransactionCandidate c) {
    setState(() {
      final index = _txCandidates.indexWhere(
        (x) => x.candidateKey == c.candidateKey,
      );
      _txCandidates[index] = c.copyWith(clearMatchedTransfer: true);
    });
  }

  Future<void> _assignBudgetToSingle(StagedTransactionCandidate c) async {
    final result = await showContainerPicker(
      context: context,
      type: ContainerType.budget,
      title: 'Assign a budget',
      selectedId: c.budgetContainerId,
    );
    if (result?.containerId == null) return;
    setState(() {
      final index = _txCandidates.indexWhere(
        (x) => x.candidateKey == c.candidateKey,
      );
      _txCandidates[index] = _txCandidates[index].copyWith(
        budgetContainerId: result!.containerId,
      );
    });
  }

  Future<void> _editTransactionCandidate(StagedTransactionCandidate c) async {
    final result = await showDialog<_TxEditResult>(
      context: context,
      builder: (_) => _TransactionCandidateEditDialog(candidate: c),
    );
    if (result == null) return;
    setState(() {
      final index = _txCandidates.indexWhere(
        (x) => x.candidateKey == c.candidateKey,
      );
      _txCandidates[index] = c.copyWith(
        effectiveDate: result.effectiveDate,
        amount: result.amount,
        description: result.description,
      );
    });
  }

  void _deleteTransactionCandidate(StagedTransactionCandidate c) {
    setState(() {
      final toRemove = <String>{c.candidateKey};

      final match = c.matchedTransfer;
      if (match?.otherCandidateKey != null) {
        if (match!.isCertain) {
          toRemove.add(match.otherCandidateKey!);
        } else {
          final idx = _txCandidates.indexWhere(
            (x) => x.candidateKey == match.otherCandidateKey,
          );
          if (idx != -1) {
            _txCandidates[idx] = _txCandidates[idx].copyWith(
              clearMatchedTransfer: true,
            );
          }
        }
      }

      _txCandidates.removeWhere((x) => toRemove.contains(x.candidateKey));
    });
  }

  Future<void> _addManualTransactionCandidate() async {
    final result = await showDialog<_TxEditResult>(
      context: context,
      builder: (_) => const _TransactionCandidateEditDialog(candidate: null),
    );
    if (result == null) return;
    setState(() {
      _manualCandidateCounter++;
      _txCandidates.add(
        StagedTransactionCandidate(
          sourceFileName: 'Manual entry',
          sourceRowIndex: _manualCandidateCounter,
          effectiveDate: result.effectiveDate,
          amount: result.amount,
          description: result.description,
          containerHint: 'Manual entry #$_manualCandidateCounter',
        ),
      );
    });
  }

  Widget _buildPriceCandidatesSection(
    BuildContext context,
    List<ldb.Asset> assets,
  ) {
    final visible = _visiblePriceCandidates;
    if (_priceCandidates.isEmpty) return const SizedBox.shrink();

    final byAssetHint = <String, List<StagedPriceSnapshotCandidate>>{};
    for (final c in visible) {
      (byAssetHint[c.assetHint] ??= []).add(c);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          '${visible.length} of ${_priceCandidates.length} price candidates',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final entry in byAssetHint.entries)
          _buildAssetPriceGroup(context, entry.key, entry.value, assets),
      ],
    );
  }

  Widget _buildAssetPriceGroup(
    BuildContext context,
    String assetHint,
    List<StagedPriceSnapshotCandidate> snapshots,
    List<ldb.Asset> assets,
  ) {
    final resolvedId = _assetResolutions[assetHint];
    final isNew =
        resolvedId != null && _newlyCreatedAssetIds.contains(resolvedId);
    final sorted = [...snapshots]..sort((a, b) => a.date.compareTo(b.date));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    assetHint,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (isNew)
                  const Chip(
                    label: Text('New asset'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            for (final s in sorted) _buildPriceSnapshotRow(context, s),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSnapshotRow(
    BuildContext context,
    StagedPriceSnapshotCandidate c,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${c.date.toIso8601String().split('T').first}  ${c.price} ${c.currencyHint}',
            ),
          ),
          Text(c.sourceFileName, style: Theme.of(context).textTheme.bodySmall),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => _editPriceCandidate(c),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => setState(
              () => _priceCandidates.removeWhere(
                (x) => x.candidateKey == c.candidateKey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPriceCandidate(StagedPriceSnapshotCandidate c) async {
    final result = await showDialog<_PriceEditResult>(
      context: context,
      builder: (_) => _PriceCandidateEditDialog(candidate: c),
    );
    if (result == null) return;
    setState(() {
      final index = _priceCandidates.indexWhere(
        (x) => x.candidateKey == c.candidateKey,
      );
      _priceCandidates[index] = c.copyWith(
        date: result.date,
        price: result.price,
      );
    });
  }

  Future<void> _runImport() async {
    setState(() {
      _step = _Step.importing;
      _importDone = 0;
      _importTotal = _txCandidates.length + _priceCandidates.length;
    });

    final transactions = <MoneyTransaction>[];
    var skippedAlreadyRecorded = 0;
    var skippedDuplicateInBatch = 0;
    final handled = <String>{};

    for (final c in _txCandidates) {
      if (handled.contains(c.candidateKey)) continue;
      handled.add(c.candidateKey);

      final match = c.matchedTransfer;
      if (match == null) {
        transactions.add(_buildFromUnmatched(c));
      } else if (match.committedTransactionId != null) {
        skippedAlreadyRecorded++;
      } else if (match.duplicateOfCandidateKey != null) {
        skippedDuplicateInBatch++;
      } else {
        final other = _txCandidates.firstWhere(
          (x) => x.candidateKey == match.otherCandidateKey,
        );
        handled.add(other.candidateKey);
        transactions.add(_buildFromMatchedPair(c, other));
      }
    }

    final priceSnapshots = [
      for (final c in _priceCandidates) _buildPriceSnapshot(c),
    ];

    final repo = ref.read(domainRepositoryProvider);
    await repo.importResolvedTransactions(
      containersToCreate: const [],
      transactions: transactions,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() => _importDone = done);
      },
    );
    await repo.importPriceSnapshots(
      snapshots: priceSnapshots,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() => _importDone = transactions.length + done);
      },
    );

    if (!mounted) return;
    setState(() {
      _importedTxCount = transactions.length;
      _importedPriceCount = priceSnapshots.length;
      _skippedAlreadyRecordedCount = skippedAlreadyRecorded;
      _skippedDuplicateInBatchCount = skippedDuplicateInBatch;
      _step = _Step.done;
    });
  }

  String _resolveContainerId(StagedTransactionCandidate c) {
    if (c.resolvedContainerId != null) return c.resolvedContainerId!;
    return c.containerType == ContainerType.budget
        ? _budgetTransferResolutions[c.containerHint]!
        : _holderResolutions[c.containerHint]!;
  }

  MoneyTransaction _buildFromUnmatched(StagedTransactionCandidate c) {
    if (c.tradeAssetHint != null) return _buildTrade(c);

    final holderId = _resolveContainerId(c);
    final budgetId = c.budgetContainerId!;
    final assetId = _txAssetId!;
    final amount = c.amount.abs();
    final holderLeg = TransactionLeg(
      containerId: holderId,
      assetId: assetId,
      quantity: amount,
    );
    final budgetLeg = TransactionLeg(
      containerId: budgetId,
      assetId: assetId,
      quantity: amount,
    );
    final externalHolderLeg = TransactionLeg(
      containerId: externalHolderContainerId,
      assetId: assetId,
      quantity: amount,
    );
    final externalBudgetLeg = TransactionLeg(
      containerId: externalBudgetContainerId,
      assetId: assetId,
      quantity: amount,
    );
    final isIncome = c.amount > Decimal.zero;
    return MoneyTransaction(
      id: generateRecordId(),
      postedAt: c.postedAt,
      effectiveDate: c.effectiveDate,
      note: c.description,
      kind: isIncome ? TransactionKind.income : TransactionKind.expense,
      legOut: isIncome ? externalHolderLeg : holderLeg,
      legIn: isIncome ? holderLeg : externalHolderLeg,
      budgetLegOut: isIncome ? externalBudgetLeg : budgetLeg,
      budgetLegIn: isIncome ? budgetLeg : externalBudgetLeg,
      tags: c.tags,
    );
  }

  MoneyTransaction _buildTrade(StagedTransactionCandidate c) {
    final holderId = _resolveContainerId(c);
    final budgetId = c.budgetContainerId!;
    final fiatAssetId = _txAssetId!;
    final tradeAssetId = _assetResolutions[c.tradeAssetHint!]!;
    final fiatLeg = TransactionLeg(
      containerId: holderId,
      assetId: fiatAssetId,
      quantity: c.amount.abs(),
    );
    final tradeLeg = TransactionLeg(
      containerId: holderId,
      assetId: tradeAssetId,
      quantity: c.tradeAssetQuantity!,
    );
    final fiatBudgetLeg = TransactionLeg(
      containerId: budgetId,
      assetId: fiatAssetId,
      quantity: c.amount.abs(),
    );
    final tradeBudgetLeg = TransactionLeg(
      containerId: budgetId,
      assetId: tradeAssetId,
      quantity: c.tradeAssetQuantity!,
    );
    final isBuy = c.amount < Decimal.zero;
    return MoneyTransaction(
      id: generateRecordId(),
      postedAt: c.postedAt,
      effectiveDate: c.effectiveDate,
      note: c.description,
      kind: TransactionKind.trade,
      legOut: isBuy ? fiatLeg : tradeLeg,
      legIn: isBuy ? tradeLeg : fiatLeg,
      budgetLegOut: isBuy ? fiatBudgetLeg : tradeBudgetLeg,
      budgetLegIn: isBuy ? tradeBudgetLeg : fiatBudgetLeg,
      tags: c.tags,
    );
  }

  MoneyTransaction _buildFromMatchedPair(
    StagedTransactionCandidate a,
    StagedTransactionCandidate b,
  ) {
    final outCandidate = a.amount < Decimal.zero ? a : b;
    final inCandidate = a.amount < Decimal.zero ? b : a;
    final assetId = _txAssetId!;
    final kind = a.containerType == ContainerType.budget
        ? TransactionKind.budgetTransfer
        : TransactionKind.holderTransfer;
    return MoneyTransaction(
      id: generateRecordId(),
      postedAt: outCandidate.postedAt,
      effectiveDate: outCandidate.effectiveDate,
      kind: kind,
      legOut: TransactionLeg(
        containerId: _resolveContainerId(outCandidate),
        assetId: assetId,
        quantity: outCandidate.amount.abs(),
      ),
      legIn: TransactionLeg(
        containerId: _resolveContainerId(inCandidate),
        assetId: assetId,
        quantity: inCandidate.amount.abs(),
      ),
    );
  }

  PriceSnapshot _buildPriceSnapshot(StagedPriceSnapshotCandidate c) {
    return PriceSnapshot(
      id: generateRecordId(),
      assetId: _assetResolutions[c.assetHint]!,
      date: c.date,
      price: c.price,
      currencyAssetId: _assetResolutions[c.currencyHint]!,
      source: PriceSnapshotSource.manual,
    );
  }

  Widget _buildImporting(BuildContext context) {
    final progress = _importTotal == 0 ? 0.0 : _importDone / _importTotal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 16),
            Text('Imported $_importDone of $_importTotal'),
          ],
        ),
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 48),
            const SizedBox(height: 16),
            Text(
              'Imported $_importedTxCount transactions and $_importedPriceCount price snapshots.',
            ),
            if ((_skippedAlreadyRecordedCount ?? 0) > 0)
              Text(
                '$_skippedAlreadyRecordedCount rows matched an already-recorded transaction and were skipped.',
              ),
            if ((_skippedDuplicateInBatchCount ?? 0) > 0)
              Text(
                '$_skippedDuplicateInBatchCount rows duplicated another row in this same import and were skipped.',
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxEditResult {
  final CalendarDate effectiveDate;
  final Decimal amount;
  final String description;

  const _TxEditResult({
    required this.effectiveDate,
    required this.amount,
    required this.description,
  });
}

class _TransactionCandidateEditDialog extends StatefulWidget {
  final StagedTransactionCandidate? candidate;

  const _TransactionCandidateEditDialog({required this.candidate});

  @override
  State<_TransactionCandidateEditDialog> createState() =>
      _TransactionCandidateEditDialogState();
}

class _TransactionCandidateEditDialogState
    extends State<_TransactionCandidateEditDialog> {
  late CalendarDate _date;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.candidate;
    _date = c?.effectiveDate ?? CalendarDate.today();
    _amountController = TextEditingController(text: c?.amount.toString() ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.candidate == null ? 'Add transaction' : 'Edit transaction',
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date: ${_date.toIso()}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date.toDateTime(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => _date = CalendarDate.fromDateTime(picked));
                }
              },
            ),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (negative = money out)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amount = Decimal.tryParse(_amountController.text.trim());
            if (amount == null) {
              setState(() => _error = 'Enter a valid amount.');
              return;
            }
            Navigator.of(context).pop(
              _TxEditResult(
                effectiveDate: _date,
                amount: amount,
                description: _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PriceEditResult {
  final DateTime date;
  final Decimal price;

  const _PriceEditResult({required this.date, required this.price});
}

class _PriceCandidateEditDialog extends StatefulWidget {
  final StagedPriceSnapshotCandidate candidate;

  const _PriceCandidateEditDialog({required this.candidate});

  @override
  State<_PriceCandidateEditDialog> createState() =>
      _PriceCandidateEditDialogState();
}

class _PriceCandidateEditDialogState extends State<_PriceCandidateEditDialog> {
  late DateTime _date;
  late final TextEditingController _priceController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = widget.candidate.date;
    _priceController = TextEditingController(
      text: widget.candidate.price.toString(),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit price'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date: ${_date.toIso8601String().split('T').first}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Price (${widget.candidate.currencyHint})',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final price = Decimal.tryParse(_priceController.text.trim());
            if (price == null) {
              setState(() => _error = 'Enter a valid price.');
              return;
            }
            Navigator.of(
              context,
            ).pop(_PriceEditResult(date: _date, price: price));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
