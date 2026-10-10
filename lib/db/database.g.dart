// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LocalVaultRecordsTable extends LocalVaultRecords
    with TableInfo<$LocalVaultRecordsTable, LocalVaultRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalVaultRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ciphertextMeta = const VerificationMeta(
    'ciphertext',
  );
  @override
  late final GeneratedColumn<Uint8List> ciphertext = GeneratedColumn<Uint8List>(
    'ciphertext',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nonceMeta = const VerificationMeta('nonce');
  @override
  late final GeneratedColumn<Uint8List> nonce = GeneratedColumn<Uint8List>(
    'nonce',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _conflictedAtMeta = const VerificationMeta(
    'conflictedAt',
  );
  @override
  late final GeneratedColumn<DateTime> conflictedAt = GeneratedColumn<DateTime>(
    'conflicted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    ciphertext,
    nonce,
    deleted,
    version,
    updatedAt,
    dirty,
    conflictedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_vault_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalVaultRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('ciphertext')) {
      context.handle(
        _ciphertextMeta,
        ciphertext.isAcceptableOrUnknown(data['ciphertext']!, _ciphertextMeta),
      );
    } else if (isInserting) {
      context.missing(_ciphertextMeta);
    }
    if (data.containsKey('nonce')) {
      context.handle(
        _nonceMeta,
        nonce.isAcceptableOrUnknown(data['nonce']!, _nonceMeta),
      );
    } else if (isInserting) {
      context.missing(_nonceMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('conflicted_at')) {
      context.handle(
        _conflictedAtMeta,
        conflictedAt.isAcceptableOrUnknown(
          data['conflicted_at']!,
          _conflictedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalVaultRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalVaultRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      ciphertext: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}ciphertext'],
      )!,
      nonce: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}nonce'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      conflictedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}conflicted_at'],
      ),
    );
  }

  @override
  $LocalVaultRecordsTable createAlias(String alias) {
    return $LocalVaultRecordsTable(attachedDatabase, alias);
  }
}

class LocalVaultRecord extends DataClass
    implements Insertable<LocalVaultRecord> {
  /// Lowercase hex id string, same format as the backend's
  /// `IdConverter.to_api` (`backend/app/api/utility/id_parser.py`).
  final String id;
  final String type;
  final Uint8List ciphertext;
  final Uint8List nonce;
  final bool deleted;

  /// Null for a record created locally that hasn't been pushed yet.
  final int? version;
  final DateTime? updatedAt;

  /// True if local changes haven't been confirmed pushed to the server yet
  /// (new record, or edited/deleted since the last successful push).
  final bool dirty;

  /// Set when `SyncEngine.push()` abandons this record after a 409 (see
  /// "Conflict policy" in docs/architecture/e2ee-and-sync.md) — `dirty`
  /// alone can't distinguish "successfully pushed" from "abandoned by a
  /// conflict" once it clears, so this stays set (surfaced in the UI as
  /// "conflicted") until the user acknowledges it or a later push/pull
  /// resolves it. Purely local bookkeeping, like
  /// [RecordVersionHighWaterMark] — never sent to the server.
  final DateTime? conflictedAt;
  const LocalVaultRecord({
    required this.id,
    required this.type,
    required this.ciphertext,
    required this.nonce,
    required this.deleted,
    this.version,
    this.updatedAt,
    required this.dirty,
    this.conflictedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['ciphertext'] = Variable<Uint8List>(ciphertext);
    map['nonce'] = Variable<Uint8List>(nonce);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || conflictedAt != null) {
      map['conflicted_at'] = Variable<DateTime>(conflictedAt);
    }
    return map;
  }

  LocalVaultRecordsCompanion toCompanion(bool nullToAbsent) {
    return LocalVaultRecordsCompanion(
      id: Value(id),
      type: Value(type),
      ciphertext: Value(ciphertext),
      nonce: Value(nonce),
      deleted: Value(deleted),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      dirty: Value(dirty),
      conflictedAt: conflictedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictedAt),
    );
  }

  factory LocalVaultRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalVaultRecord(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      ciphertext: serializer.fromJson<Uint8List>(json['ciphertext']),
      nonce: serializer.fromJson<Uint8List>(json['nonce']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      version: serializer.fromJson<int?>(json['version']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      conflictedAt: serializer.fromJson<DateTime?>(json['conflictedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'ciphertext': serializer.toJson<Uint8List>(ciphertext),
      'nonce': serializer.toJson<Uint8List>(nonce),
      'deleted': serializer.toJson<bool>(deleted),
      'version': serializer.toJson<int?>(version),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'conflictedAt': serializer.toJson<DateTime?>(conflictedAt),
    };
  }

  LocalVaultRecord copyWith({
    String? id,
    String? type,
    Uint8List? ciphertext,
    Uint8List? nonce,
    bool? deleted,
    Value<int?> version = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? dirty,
    Value<DateTime?> conflictedAt = const Value.absent(),
  }) => LocalVaultRecord(
    id: id ?? this.id,
    type: type ?? this.type,
    ciphertext: ciphertext ?? this.ciphertext,
    nonce: nonce ?? this.nonce,
    deleted: deleted ?? this.deleted,
    version: version.present ? version.value : this.version,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    dirty: dirty ?? this.dirty,
    conflictedAt: conflictedAt.present ? conflictedAt.value : this.conflictedAt,
  );
  LocalVaultRecord copyWithCompanion(LocalVaultRecordsCompanion data) {
    return LocalVaultRecord(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      ciphertext: data.ciphertext.present
          ? data.ciphertext.value
          : this.ciphertext,
      nonce: data.nonce.present ? data.nonce.value : this.nonce,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      conflictedAt: data.conflictedAt.present
          ? data.conflictedAt.value
          : this.conflictedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalVaultRecord(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('nonce: $nonce, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty, ')
          ..write('conflictedAt: $conflictedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    $driftBlobEquality.hash(ciphertext),
    $driftBlobEquality.hash(nonce),
    deleted,
    version,
    updatedAt,
    dirty,
    conflictedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalVaultRecord &&
          other.id == this.id &&
          other.type == this.type &&
          $driftBlobEquality.equals(other.ciphertext, this.ciphertext) &&
          $driftBlobEquality.equals(other.nonce, this.nonce) &&
          other.deleted == this.deleted &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt &&
          other.dirty == this.dirty &&
          other.conflictedAt == this.conflictedAt);
}

class LocalVaultRecordsCompanion extends UpdateCompanion<LocalVaultRecord> {
  final Value<String> id;
  final Value<String> type;
  final Value<Uint8List> ciphertext;
  final Value<Uint8List> nonce;
  final Value<bool> deleted;
  final Value<int?> version;
  final Value<DateTime?> updatedAt;
  final Value<bool> dirty;
  final Value<DateTime?> conflictedAt;
  final Value<int> rowid;
  const LocalVaultRecordsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.ciphertext = const Value.absent(),
    this.nonce = const Value.absent(),
    this.deleted = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.conflictedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalVaultRecordsCompanion.insert({
    required String id,
    required String type,
    required Uint8List ciphertext,
    required Uint8List nonce,
    this.deleted = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.conflictedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       ciphertext = Value(ciphertext),
       nonce = Value(nonce);
  static Insertable<LocalVaultRecord> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<Uint8List>? ciphertext,
    Expression<Uint8List>? nonce,
    Expression<bool>? deleted,
    Expression<int>? version,
    Expression<DateTime>? updatedAt,
    Expression<bool>? dirty,
    Expression<DateTime>? conflictedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (ciphertext != null) 'ciphertext': ciphertext,
      if (nonce != null) 'nonce': nonce,
      if (deleted != null) 'deleted': deleted,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (dirty != null) 'dirty': dirty,
      if (conflictedAt != null) 'conflicted_at': conflictedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalVaultRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<Uint8List>? ciphertext,
    Value<Uint8List>? nonce,
    Value<bool>? deleted,
    Value<int?>? version,
    Value<DateTime?>? updatedAt,
    Value<bool>? dirty,
    Value<DateTime?>? conflictedAt,
    Value<int>? rowid,
  }) {
    return LocalVaultRecordsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      ciphertext: ciphertext ?? this.ciphertext,
      nonce: nonce ?? this.nonce,
      deleted: deleted ?? this.deleted,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
      conflictedAt: conflictedAt ?? this.conflictedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (ciphertext.present) {
      map['ciphertext'] = Variable<Uint8List>(ciphertext.value);
    }
    if (nonce.present) {
      map['nonce'] = Variable<Uint8List>(nonce.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (conflictedAt.present) {
      map['conflicted_at'] = Variable<DateTime>(conflictedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalVaultRecordsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('nonce: $nonce, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty, ')
          ..write('conflictedAt: $conflictedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedVersionMeta = const VerificationMeta(
    'lastSyncedVersion',
  );
  @override
  late final GeneratedColumn<int> lastSyncedVersion = GeneratedColumn<int>(
    'last_synced_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, lastSyncedVersion];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('last_synced_version')) {
      context.handle(
        _lastSyncedVersionMeta,
        lastSyncedVersion.isAcceptableOrUnknown(
          data['last_synced_version']!,
          _lastSyncedVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lastSyncedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_version'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final int id;
  final int lastSyncedVersion;
  const SyncStateData({required this.id, required this.lastSyncedVersion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['last_synced_version'] = Variable<int>(lastSyncedVersion);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      lastSyncedVersion: Value(lastSyncedVersion),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      id: serializer.fromJson<int>(json['id']),
      lastSyncedVersion: serializer.fromJson<int>(json['lastSyncedVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lastSyncedVersion': serializer.toJson<int>(lastSyncedVersion),
    };
  }

  SyncStateData copyWith({int? id, int? lastSyncedVersion}) => SyncStateData(
    id: id ?? this.id,
    lastSyncedVersion: lastSyncedVersion ?? this.lastSyncedVersion,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      id: data.id.present ? data.id.value : this.id,
      lastSyncedVersion: data.lastSyncedVersion.present
          ? data.lastSyncedVersion.value
          : this.lastSyncedVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('id: $id, ')
          ..write('lastSyncedVersion: $lastSyncedVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lastSyncedVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.id == this.id &&
          other.lastSyncedVersion == this.lastSyncedVersion);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<int> id;
  final Value<int> lastSyncedVersion;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.lastSyncedVersion = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    this.lastSyncedVersion = const Value.absent(),
  });
  static Insertable<SyncStateData> custom({
    Expression<int>? id,
    Expression<int>? lastSyncedVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastSyncedVersion != null) 'last_synced_version': lastSyncedVersion,
    });
  }

  SyncStateCompanion copyWith({Value<int>? id, Value<int>? lastSyncedVersion}) {
    return SyncStateCompanion(
      id: id ?? this.id,
      lastSyncedVersion: lastSyncedVersion ?? this.lastSyncedVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lastSyncedVersion.present) {
      map['last_synced_version'] = Variable<int>(lastSyncedVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('lastSyncedVersion: $lastSyncedVersion')
          ..write(')'))
        .toString();
  }
}

class $RecordVersionHighWaterMarkTable extends RecordVersionHighWaterMark
    with
        TableInfo<
          $RecordVersionHighWaterMarkTable,
          RecordVersionHighWaterMarkData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordVersionHighWaterMarkTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _highestVersionSeenMeta =
      const VerificationMeta('highestVersionSeen');
  @override
  late final GeneratedColumn<int> highestVersionSeen = GeneratedColumn<int>(
    'highest_version_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [recordId, highestVersionSeen];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'record_version_high_water_mark';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordVersionHighWaterMarkData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('highest_version_seen')) {
      context.handle(
        _highestVersionSeenMeta,
        highestVersionSeen.isAcceptableOrUnknown(
          data['highest_version_seen']!,
          _highestVersionSeenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_highestVersionSeenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordId};
  @override
  RecordVersionHighWaterMarkData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordVersionHighWaterMarkData(
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      highestVersionSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}highest_version_seen'],
      )!,
    );
  }

  @override
  $RecordVersionHighWaterMarkTable createAlias(String alias) {
    return $RecordVersionHighWaterMarkTable(attachedDatabase, alias);
  }
}

class RecordVersionHighWaterMarkData extends DataClass
    implements Insertable<RecordVersionHighWaterMarkData> {
  final String recordId;
  final int highestVersionSeen;
  const RecordVersionHighWaterMarkData({
    required this.recordId,
    required this.highestVersionSeen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['record_id'] = Variable<String>(recordId);
    map['highest_version_seen'] = Variable<int>(highestVersionSeen);
    return map;
  }

  RecordVersionHighWaterMarkCompanion toCompanion(bool nullToAbsent) {
    return RecordVersionHighWaterMarkCompanion(
      recordId: Value(recordId),
      highestVersionSeen: Value(highestVersionSeen),
    );
  }

  factory RecordVersionHighWaterMarkData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordVersionHighWaterMarkData(
      recordId: serializer.fromJson<String>(json['recordId']),
      highestVersionSeen: serializer.fromJson<int>(json['highestVersionSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordId': serializer.toJson<String>(recordId),
      'highestVersionSeen': serializer.toJson<int>(highestVersionSeen),
    };
  }

  RecordVersionHighWaterMarkData copyWith({
    String? recordId,
    int? highestVersionSeen,
  }) => RecordVersionHighWaterMarkData(
    recordId: recordId ?? this.recordId,
    highestVersionSeen: highestVersionSeen ?? this.highestVersionSeen,
  );
  RecordVersionHighWaterMarkData copyWithCompanion(
    RecordVersionHighWaterMarkCompanion data,
  ) {
    return RecordVersionHighWaterMarkData(
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      highestVersionSeen: data.highestVersionSeen.present
          ? data.highestVersionSeen.value
          : this.highestVersionSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordVersionHighWaterMarkData(')
          ..write('recordId: $recordId, ')
          ..write('highestVersionSeen: $highestVersionSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recordId, highestVersionSeen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordVersionHighWaterMarkData &&
          other.recordId == this.recordId &&
          other.highestVersionSeen == this.highestVersionSeen);
}

class RecordVersionHighWaterMarkCompanion
    extends UpdateCompanion<RecordVersionHighWaterMarkData> {
  final Value<String> recordId;
  final Value<int> highestVersionSeen;
  final Value<int> rowid;
  const RecordVersionHighWaterMarkCompanion({
    this.recordId = const Value.absent(),
    this.highestVersionSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordVersionHighWaterMarkCompanion.insert({
    required String recordId,
    required int highestVersionSeen,
    this.rowid = const Value.absent(),
  }) : recordId = Value(recordId),
       highestVersionSeen = Value(highestVersionSeen);
  static Insertable<RecordVersionHighWaterMarkData> custom({
    Expression<String>? recordId,
    Expression<int>? highestVersionSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recordId != null) 'record_id': recordId,
      if (highestVersionSeen != null)
        'highest_version_seen': highestVersionSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordVersionHighWaterMarkCompanion copyWith({
    Value<String>? recordId,
    Value<int>? highestVersionSeen,
    Value<int>? rowid,
  }) {
    return RecordVersionHighWaterMarkCompanion(
      recordId: recordId ?? this.recordId,
      highestVersionSeen: highestVersionSeen ?? this.highestVersionSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (highestVersionSeen.present) {
      map['highest_version_seen'] = Variable<int>(highestVersionSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordVersionHighWaterMarkCompanion(')
          ..write('recordId: $recordId, ')
          ..write('highestVersionSeen: $highestVersionSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalVaultKeyMaterialTable extends LocalVaultKeyMaterial
    with TableInfo<$LocalVaultKeyMaterialTable, LocalVaultKeyMaterialData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalVaultKeyMaterialTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kdfSaltMeta = const VerificationMeta(
    'kdfSalt',
  );
  @override
  late final GeneratedColumn<Uint8List> kdfSalt = GeneratedColumn<Uint8List>(
    'kdf_salt',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kdfParamsJsonMeta = const VerificationMeta(
    'kdfParamsJson',
  );
  @override
  late final GeneratedColumn<String> kdfParamsJson = GeneratedColumn<String>(
    'kdf_params_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrappedDekMeta = const VerificationMeta(
    'wrappedDek',
  );
  @override
  late final GeneratedColumn<Uint8List> wrappedDek = GeneratedColumn<Uint8List>(
    'wrapped_dek',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrapNonceMeta = const VerificationMeta(
    'wrapNonce',
  );
  @override
  late final GeneratedColumn<Uint8List> wrapNonce = GeneratedColumn<Uint8List>(
    'wrap_nonce',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kdfSalt,
    kdfParamsJson,
    wrappedDek,
    wrapNonce,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_vault_key_material';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalVaultKeyMaterialData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kdf_salt')) {
      context.handle(
        _kdfSaltMeta,
        kdfSalt.isAcceptableOrUnknown(data['kdf_salt']!, _kdfSaltMeta),
      );
    } else if (isInserting) {
      context.missing(_kdfSaltMeta);
    }
    if (data.containsKey('kdf_params_json')) {
      context.handle(
        _kdfParamsJsonMeta,
        kdfParamsJson.isAcceptableOrUnknown(
          data['kdf_params_json']!,
          _kdfParamsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_kdfParamsJsonMeta);
    }
    if (data.containsKey('wrapped_dek')) {
      context.handle(
        _wrappedDekMeta,
        wrappedDek.isAcceptableOrUnknown(data['wrapped_dek']!, _wrappedDekMeta),
      );
    } else if (isInserting) {
      context.missing(_wrappedDekMeta);
    }
    if (data.containsKey('wrap_nonce')) {
      context.handle(
        _wrapNonceMeta,
        wrapNonce.isAcceptableOrUnknown(data['wrap_nonce']!, _wrapNonceMeta),
      );
    } else if (isInserting) {
      context.missing(_wrapNonceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalVaultKeyMaterialData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalVaultKeyMaterialData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kdfSalt: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}kdf_salt'],
      )!,
      kdfParamsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kdf_params_json'],
      )!,
      wrappedDek: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}wrapped_dek'],
      )!,
      wrapNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}wrap_nonce'],
      )!,
    );
  }

  @override
  $LocalVaultKeyMaterialTable createAlias(String alias) {
    return $LocalVaultKeyMaterialTable(attachedDatabase, alias);
  }
}

class LocalVaultKeyMaterialData extends DataClass
    implements Insertable<LocalVaultKeyMaterialData> {
  final int id;
  final Uint8List kdfSalt;
  final String kdfParamsJson;
  final Uint8List wrappedDek;
  final Uint8List wrapNonce;
  const LocalVaultKeyMaterialData({
    required this.id,
    required this.kdfSalt,
    required this.kdfParamsJson,
    required this.wrappedDek,
    required this.wrapNonce,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kdf_salt'] = Variable<Uint8List>(kdfSalt);
    map['kdf_params_json'] = Variable<String>(kdfParamsJson);
    map['wrapped_dek'] = Variable<Uint8List>(wrappedDek);
    map['wrap_nonce'] = Variable<Uint8List>(wrapNonce);
    return map;
  }

  LocalVaultKeyMaterialCompanion toCompanion(bool nullToAbsent) {
    return LocalVaultKeyMaterialCompanion(
      id: Value(id),
      kdfSalt: Value(kdfSalt),
      kdfParamsJson: Value(kdfParamsJson),
      wrappedDek: Value(wrappedDek),
      wrapNonce: Value(wrapNonce),
    );
  }

  factory LocalVaultKeyMaterialData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalVaultKeyMaterialData(
      id: serializer.fromJson<int>(json['id']),
      kdfSalt: serializer.fromJson<Uint8List>(json['kdfSalt']),
      kdfParamsJson: serializer.fromJson<String>(json['kdfParamsJson']),
      wrappedDek: serializer.fromJson<Uint8List>(json['wrappedDek']),
      wrapNonce: serializer.fromJson<Uint8List>(json['wrapNonce']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kdfSalt': serializer.toJson<Uint8List>(kdfSalt),
      'kdfParamsJson': serializer.toJson<String>(kdfParamsJson),
      'wrappedDek': serializer.toJson<Uint8List>(wrappedDek),
      'wrapNonce': serializer.toJson<Uint8List>(wrapNonce),
    };
  }

  LocalVaultKeyMaterialData copyWith({
    int? id,
    Uint8List? kdfSalt,
    String? kdfParamsJson,
    Uint8List? wrappedDek,
    Uint8List? wrapNonce,
  }) => LocalVaultKeyMaterialData(
    id: id ?? this.id,
    kdfSalt: kdfSalt ?? this.kdfSalt,
    kdfParamsJson: kdfParamsJson ?? this.kdfParamsJson,
    wrappedDek: wrappedDek ?? this.wrappedDek,
    wrapNonce: wrapNonce ?? this.wrapNonce,
  );
  LocalVaultKeyMaterialData copyWithCompanion(
    LocalVaultKeyMaterialCompanion data,
  ) {
    return LocalVaultKeyMaterialData(
      id: data.id.present ? data.id.value : this.id,
      kdfSalt: data.kdfSalt.present ? data.kdfSalt.value : this.kdfSalt,
      kdfParamsJson: data.kdfParamsJson.present
          ? data.kdfParamsJson.value
          : this.kdfParamsJson,
      wrappedDek: data.wrappedDek.present
          ? data.wrappedDek.value
          : this.wrappedDek,
      wrapNonce: data.wrapNonce.present ? data.wrapNonce.value : this.wrapNonce,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalVaultKeyMaterialData(')
          ..write('id: $id, ')
          ..write('kdfSalt: $kdfSalt, ')
          ..write('kdfParamsJson: $kdfParamsJson, ')
          ..write('wrappedDek: $wrappedDek, ')
          ..write('wrapNonce: $wrapNonce')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    $driftBlobEquality.hash(kdfSalt),
    kdfParamsJson,
    $driftBlobEquality.hash(wrappedDek),
    $driftBlobEquality.hash(wrapNonce),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalVaultKeyMaterialData &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.kdfSalt, this.kdfSalt) &&
          other.kdfParamsJson == this.kdfParamsJson &&
          $driftBlobEquality.equals(other.wrappedDek, this.wrappedDek) &&
          $driftBlobEquality.equals(other.wrapNonce, this.wrapNonce));
}

class LocalVaultKeyMaterialCompanion
    extends UpdateCompanion<LocalVaultKeyMaterialData> {
  final Value<int> id;
  final Value<Uint8List> kdfSalt;
  final Value<String> kdfParamsJson;
  final Value<Uint8List> wrappedDek;
  final Value<Uint8List> wrapNonce;
  const LocalVaultKeyMaterialCompanion({
    this.id = const Value.absent(),
    this.kdfSalt = const Value.absent(),
    this.kdfParamsJson = const Value.absent(),
    this.wrappedDek = const Value.absent(),
    this.wrapNonce = const Value.absent(),
  });
  LocalVaultKeyMaterialCompanion.insert({
    this.id = const Value.absent(),
    required Uint8List kdfSalt,
    required String kdfParamsJson,
    required Uint8List wrappedDek,
    required Uint8List wrapNonce,
  }) : kdfSalt = Value(kdfSalt),
       kdfParamsJson = Value(kdfParamsJson),
       wrappedDek = Value(wrappedDek),
       wrapNonce = Value(wrapNonce);
  static Insertable<LocalVaultKeyMaterialData> custom({
    Expression<int>? id,
    Expression<Uint8List>? kdfSalt,
    Expression<String>? kdfParamsJson,
    Expression<Uint8List>? wrappedDek,
    Expression<Uint8List>? wrapNonce,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kdfSalt != null) 'kdf_salt': kdfSalt,
      if (kdfParamsJson != null) 'kdf_params_json': kdfParamsJson,
      if (wrappedDek != null) 'wrapped_dek': wrappedDek,
      if (wrapNonce != null) 'wrap_nonce': wrapNonce,
    });
  }

  LocalVaultKeyMaterialCompanion copyWith({
    Value<int>? id,
    Value<Uint8List>? kdfSalt,
    Value<String>? kdfParamsJson,
    Value<Uint8List>? wrappedDek,
    Value<Uint8List>? wrapNonce,
  }) {
    return LocalVaultKeyMaterialCompanion(
      id: id ?? this.id,
      kdfSalt: kdfSalt ?? this.kdfSalt,
      kdfParamsJson: kdfParamsJson ?? this.kdfParamsJson,
      wrappedDek: wrappedDek ?? this.wrappedDek,
      wrapNonce: wrapNonce ?? this.wrapNonce,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kdfSalt.present) {
      map['kdf_salt'] = Variable<Uint8List>(kdfSalt.value);
    }
    if (kdfParamsJson.present) {
      map['kdf_params_json'] = Variable<String>(kdfParamsJson.value);
    }
    if (wrappedDek.present) {
      map['wrapped_dek'] = Variable<Uint8List>(wrappedDek.value);
    }
    if (wrapNonce.present) {
      map['wrap_nonce'] = Variable<Uint8List>(wrapNonce.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalVaultKeyMaterialCompanion(')
          ..write('id: $id, ')
          ..write('kdfSalt: $kdfSalt, ')
          ..write('kdfParamsJson: $kdfParamsJson, ')
          ..write('wrappedDek: $wrappedDek, ')
          ..write('wrapNonce: $wrapNonce')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalVaultRecordsTable localVaultRecords =
      $LocalVaultRecordsTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $RecordVersionHighWaterMarkTable recordVersionHighWaterMark =
      $RecordVersionHighWaterMarkTable(this);
  late final $LocalVaultKeyMaterialTable localVaultKeyMaterial =
      $LocalVaultKeyMaterialTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localVaultRecords,
    syncState,
    recordVersionHighWaterMark,
    localVaultKeyMaterial,
  ];
}

typedef $$LocalVaultRecordsTableCreateCompanionBuilder =
    LocalVaultRecordsCompanion Function({
      required String id,
      required String type,
      required Uint8List ciphertext,
      required Uint8List nonce,
      Value<bool> deleted,
      Value<int?> version,
      Value<DateTime?> updatedAt,
      Value<bool> dirty,
      Value<DateTime?> conflictedAt,
      Value<int> rowid,
    });
typedef $$LocalVaultRecordsTableUpdateCompanionBuilder =
    LocalVaultRecordsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<Uint8List> ciphertext,
      Value<Uint8List> nonce,
      Value<bool> deleted,
      Value<int?> version,
      Value<DateTime?> updatedAt,
      Value<bool> dirty,
      Value<DateTime?> conflictedAt,
      Value<int> rowid,
    });

class $$LocalVaultRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalVaultRecordsTable> {
  $$LocalVaultRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get conflictedAt => $composableBuilder(
    column: $table.conflictedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalVaultRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalVaultRecordsTable> {
  $$LocalVaultRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get conflictedAt => $composableBuilder(
    column: $table.conflictedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalVaultRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalVaultRecordsTable> {
  $$LocalVaultRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get nonce =>
      $composableBuilder(column: $table.nonce, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<DateTime> get conflictedAt => $composableBuilder(
    column: $table.conflictedAt,
    builder: (column) => column,
  );
}

class $$LocalVaultRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalVaultRecordsTable,
          LocalVaultRecord,
          $$LocalVaultRecordsTableFilterComposer,
          $$LocalVaultRecordsTableOrderingComposer,
          $$LocalVaultRecordsTableAnnotationComposer,
          $$LocalVaultRecordsTableCreateCompanionBuilder,
          $$LocalVaultRecordsTableUpdateCompanionBuilder,
          (
            LocalVaultRecord,
            BaseReferences<
              _$AppDatabase,
              $LocalVaultRecordsTable,
              LocalVaultRecord
            >,
          ),
          LocalVaultRecord,
          PrefetchHooks Function()
        > {
  $$LocalVaultRecordsTableTableManager(
    _$AppDatabase db,
    $LocalVaultRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalVaultRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalVaultRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalVaultRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<Uint8List> ciphertext = const Value.absent(),
                Value<Uint8List> nonce = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> conflictedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalVaultRecordsCompanion(
                id: id,
                type: type,
                ciphertext: ciphertext,
                nonce: nonce,
                deleted: deleted,
                version: version,
                updatedAt: updatedAt,
                dirty: dirty,
                conflictedAt: conflictedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required Uint8List ciphertext,
                required Uint8List nonce,
                Value<bool> deleted = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> conflictedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalVaultRecordsCompanion.insert(
                id: id,
                type: type,
                ciphertext: ciphertext,
                nonce: nonce,
                deleted: deleted,
                version: version,
                updatedAt: updatedAt,
                dirty: dirty,
                conflictedAt: conflictedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalVaultRecordsTable, LocalVaultRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalVaultRecordsTable,
                    LocalVaultRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalVaultRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalVaultRecordsTable,
      LocalVaultRecord,
      $$LocalVaultRecordsTableFilterComposer,
      $$LocalVaultRecordsTableOrderingComposer,
      $$LocalVaultRecordsTableAnnotationComposer,
      $$LocalVaultRecordsTableCreateCompanionBuilder,
      $$LocalVaultRecordsTableUpdateCompanionBuilder,
      (
        LocalVaultRecord,
        BaseReferences<
          _$AppDatabase,
          $LocalVaultRecordsTable,
          LocalVaultRecord
        >,
      ),
      LocalVaultRecord,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({Value<int> id, Value<int> lastSyncedVersion});
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({Value<int> id, Value<int> lastSyncedVersion});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedVersion => $composableBuilder(
    column: $table.lastSyncedVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedVersion => $composableBuilder(
    column: $table.lastSyncedVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lastSyncedVersion => $composableBuilder(
    column: $table.lastSyncedVersion,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lastSyncedVersion = const Value.absent(),
              }) => SyncStateCompanion(
                id: id,
                lastSyncedVersion: lastSyncedVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lastSyncedVersion = const Value.absent(),
              }) => SyncStateCompanion.insert(
                id: id,
                lastSyncedVersion: lastSyncedVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateData>(table),
                  BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;
typedef $$RecordVersionHighWaterMarkTableCreateCompanionBuilder =
    RecordVersionHighWaterMarkCompanion Function({
      required String recordId,
      required int highestVersionSeen,
      Value<int> rowid,
    });
typedef $$RecordVersionHighWaterMarkTableUpdateCompanionBuilder =
    RecordVersionHighWaterMarkCompanion Function({
      Value<String> recordId,
      Value<int> highestVersionSeen,
      Value<int> rowid,
    });

class $$RecordVersionHighWaterMarkTableFilterComposer
    extends Composer<_$AppDatabase, $RecordVersionHighWaterMarkTable> {
  $$RecordVersionHighWaterMarkTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highestVersionSeen => $composableBuilder(
    column: $table.highestVersionSeen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordVersionHighWaterMarkTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordVersionHighWaterMarkTable> {
  $$RecordVersionHighWaterMarkTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highestVersionSeen => $composableBuilder(
    column: $table.highestVersionSeen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordVersionHighWaterMarkTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordVersionHighWaterMarkTable> {
  $$RecordVersionHighWaterMarkTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<int> get highestVersionSeen => $composableBuilder(
    column: $table.highestVersionSeen,
    builder: (column) => column,
  );
}

class $$RecordVersionHighWaterMarkTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordVersionHighWaterMarkTable,
          RecordVersionHighWaterMarkData,
          $$RecordVersionHighWaterMarkTableFilterComposer,
          $$RecordVersionHighWaterMarkTableOrderingComposer,
          $$RecordVersionHighWaterMarkTableAnnotationComposer,
          $$RecordVersionHighWaterMarkTableCreateCompanionBuilder,
          $$RecordVersionHighWaterMarkTableUpdateCompanionBuilder,
          (
            RecordVersionHighWaterMarkData,
            BaseReferences<
              _$AppDatabase,
              $RecordVersionHighWaterMarkTable,
              RecordVersionHighWaterMarkData
            >,
          ),
          RecordVersionHighWaterMarkData,
          PrefetchHooks Function()
        > {
  $$RecordVersionHighWaterMarkTableTableManager(
    _$AppDatabase db,
    $RecordVersionHighWaterMarkTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordVersionHighWaterMarkTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RecordVersionHighWaterMarkTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecordVersionHighWaterMarkTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> recordId = const Value.absent(),
                Value<int> highestVersionSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordVersionHighWaterMarkCompanion(
                recordId: recordId,
                highestVersionSeen: highestVersionSeen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recordId,
                required int highestVersionSeen,
                Value<int> rowid = const Value.absent(),
              }) => RecordVersionHighWaterMarkCompanion.insert(
                recordId: recordId,
                highestVersionSeen: highestVersionSeen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $RecordVersionHighWaterMarkTable,
                    RecordVersionHighWaterMarkData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RecordVersionHighWaterMarkTable,
                    RecordVersionHighWaterMarkData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordVersionHighWaterMarkTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordVersionHighWaterMarkTable,
      RecordVersionHighWaterMarkData,
      $$RecordVersionHighWaterMarkTableFilterComposer,
      $$RecordVersionHighWaterMarkTableOrderingComposer,
      $$RecordVersionHighWaterMarkTableAnnotationComposer,
      $$RecordVersionHighWaterMarkTableCreateCompanionBuilder,
      $$RecordVersionHighWaterMarkTableUpdateCompanionBuilder,
      (
        RecordVersionHighWaterMarkData,
        BaseReferences<
          _$AppDatabase,
          $RecordVersionHighWaterMarkTable,
          RecordVersionHighWaterMarkData
        >,
      ),
      RecordVersionHighWaterMarkData,
      PrefetchHooks Function()
    >;
typedef $$LocalVaultKeyMaterialTableCreateCompanionBuilder =
    LocalVaultKeyMaterialCompanion Function({
      Value<int> id,
      required Uint8List kdfSalt,
      required String kdfParamsJson,
      required Uint8List wrappedDek,
      required Uint8List wrapNonce,
    });
typedef $$LocalVaultKeyMaterialTableUpdateCompanionBuilder =
    LocalVaultKeyMaterialCompanion Function({
      Value<int> id,
      Value<Uint8List> kdfSalt,
      Value<String> kdfParamsJson,
      Value<Uint8List> wrappedDek,
      Value<Uint8List> wrapNonce,
    });

class $$LocalVaultKeyMaterialTableFilterComposer
    extends Composer<_$AppDatabase, $LocalVaultKeyMaterialTable> {
  $$LocalVaultKeyMaterialTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get kdfSalt => $composableBuilder(
    column: $table.kdfSalt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kdfParamsJson => $composableBuilder(
    column: $table.kdfParamsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get wrappedDek => $composableBuilder(
    column: $table.wrappedDek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get wrapNonce => $composableBuilder(
    column: $table.wrapNonce,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalVaultKeyMaterialTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalVaultKeyMaterialTable> {
  $$LocalVaultKeyMaterialTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get kdfSalt => $composableBuilder(
    column: $table.kdfSalt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kdfParamsJson => $composableBuilder(
    column: $table.kdfParamsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get wrappedDek => $composableBuilder(
    column: $table.wrappedDek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get wrapNonce => $composableBuilder(
    column: $table.wrapNonce,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalVaultKeyMaterialTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalVaultKeyMaterialTable> {
  $$LocalVaultKeyMaterialTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get kdfSalt =>
      $composableBuilder(column: $table.kdfSalt, builder: (column) => column);

  GeneratedColumn<String> get kdfParamsJson => $composableBuilder(
    column: $table.kdfParamsJson,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get wrappedDek => $composableBuilder(
    column: $table.wrappedDek,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get wrapNonce =>
      $composableBuilder(column: $table.wrapNonce, builder: (column) => column);
}

class $$LocalVaultKeyMaterialTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalVaultKeyMaterialTable,
          LocalVaultKeyMaterialData,
          $$LocalVaultKeyMaterialTableFilterComposer,
          $$LocalVaultKeyMaterialTableOrderingComposer,
          $$LocalVaultKeyMaterialTableAnnotationComposer,
          $$LocalVaultKeyMaterialTableCreateCompanionBuilder,
          $$LocalVaultKeyMaterialTableUpdateCompanionBuilder,
          (
            LocalVaultKeyMaterialData,
            BaseReferences<
              _$AppDatabase,
              $LocalVaultKeyMaterialTable,
              LocalVaultKeyMaterialData
            >,
          ),
          LocalVaultKeyMaterialData,
          PrefetchHooks Function()
        > {
  $$LocalVaultKeyMaterialTableTableManager(
    _$AppDatabase db,
    $LocalVaultKeyMaterialTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalVaultKeyMaterialTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalVaultKeyMaterialTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalVaultKeyMaterialTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<Uint8List> kdfSalt = const Value.absent(),
                Value<String> kdfParamsJson = const Value.absent(),
                Value<Uint8List> wrappedDek = const Value.absent(),
                Value<Uint8List> wrapNonce = const Value.absent(),
              }) => LocalVaultKeyMaterialCompanion(
                id: id,
                kdfSalt: kdfSalt,
                kdfParamsJson: kdfParamsJson,
                wrappedDek: wrappedDek,
                wrapNonce: wrapNonce,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Uint8List kdfSalt,
                required String kdfParamsJson,
                required Uint8List wrappedDek,
                required Uint8List wrapNonce,
              }) => LocalVaultKeyMaterialCompanion.insert(
                id: id,
                kdfSalt: kdfSalt,
                kdfParamsJson: kdfParamsJson,
                wrappedDek: wrappedDek,
                wrapNonce: wrapNonce,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalVaultKeyMaterialTable,
                    LocalVaultKeyMaterialData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalVaultKeyMaterialTable,
                    LocalVaultKeyMaterialData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalVaultKeyMaterialTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalVaultKeyMaterialTable,
      LocalVaultKeyMaterialData,
      $$LocalVaultKeyMaterialTableFilterComposer,
      $$LocalVaultKeyMaterialTableOrderingComposer,
      $$LocalVaultKeyMaterialTableAnnotationComposer,
      $$LocalVaultKeyMaterialTableCreateCompanionBuilder,
      $$LocalVaultKeyMaterialTableUpdateCompanionBuilder,
      (
        LocalVaultKeyMaterialData,
        BaseReferences<
          _$AppDatabase,
          $LocalVaultKeyMaterialTable,
          LocalVaultKeyMaterialData
        >,
      ),
      LocalVaultKeyMaterialData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalVaultRecordsTableTableManager get localVaultRecords =>
      $$LocalVaultRecordsTableTableManager(_db, _db.localVaultRecords);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$RecordVersionHighWaterMarkTableTableManager
  get recordVersionHighWaterMark =>
      $$RecordVersionHighWaterMarkTableTableManager(
        _db,
        _db.recordVersionHighWaterMark,
      );
  $$LocalVaultKeyMaterialTableTableManager get localVaultKeyMaterial =>
      $$LocalVaultKeyMaterialTableTableManager(_db, _db.localVaultKeyMaterial);
}
