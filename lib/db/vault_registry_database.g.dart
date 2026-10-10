// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_registry_database.dart';

// ignore_for_file: type=lint
class $VaultRegistryEntriesTable extends VaultRegistryEntries
    with TableInfo<$VaultRegistryEntriesTable, VaultRegistryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultRegistryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dbNameMeta = const VerificationMeta('dbName');
  @override
  late final GeneratedColumn<String> dbName = GeneratedColumn<String>(
    'db_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dbName,
    kind,
    label,
    email,
    createdAt,
    lastOpenedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_registry_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultRegistryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('db_name')) {
      context.handle(
        _dbNameMeta,
        dbName.isAcceptableOrUnknown(data['db_name']!, _dbNameMeta),
      );
    } else if (isInserting) {
      context.missing(_dbNameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOpenedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultRegistryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultRegistryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dbName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}db_name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      )!,
    );
  }

  @override
  $VaultRegistryEntriesTable createAlias(String alias) {
    return $VaultRegistryEntriesTable(attachedDatabase, alias);
  }
}

class VaultRegistryRow extends DataClass
    implements Insertable<VaultRegistryRow> {
  /// Stable id, unrelated to AAD/record ids — just a local identifier used
  /// to scope `AppDatabase`'s `dbName` and `LocalUnlockStore`'s keyring
  /// keys to one vault.
  final String id;

  /// The literal name passed to `AppDatabase`'s `driftDatabase(name: ...)`
  /// — stored explicitly (not derived from [id]); every vault uses
  /// `'moopro_vault_<id>'`.
  final String dbName;

  /// `'online'` | `'offline'` — see [VaultKind] in `vault/vault_registry.dart`.
  final String kind;

  /// User-facing name shown in the vault picker.
  final String label;

  /// Set for `kind == 'online'` vaults only — the account email, used to
  /// detect "log into an account already known on this device" so the
  /// same vault id (and therefore the same local cache) is reused instead
  /// of silently sharing/corrupting a different account's records.
  final String? email;
  final DateTime createdAt;

  /// Bumped every time this vault is selected — used to auto-pick "the"
  /// vault when there's only one, and to sort the picker by recency.
  final DateTime lastOpenedAt;
  const VaultRegistryRow({
    required this.id,
    required this.dbName,
    required this.kind,
    required this.label,
    this.email,
    required this.createdAt,
    required this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['db_name'] = Variable<String>(dbName);
    map['kind'] = Variable<String>(kind);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    return map;
  }

  VaultRegistryEntriesCompanion toCompanion(bool nullToAbsent) {
    return VaultRegistryEntriesCompanion(
      id: Value(id),
      dbName: Value(dbName),
      kind: Value(kind),
      label: Value(label),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      createdAt: Value(createdAt),
      lastOpenedAt: Value(lastOpenedAt),
    );
  }

  factory VaultRegistryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultRegistryRow(
      id: serializer.fromJson<String>(json['id']),
      dbName: serializer.fromJson<String>(json['dbName']),
      kind: serializer.fromJson<String>(json['kind']),
      label: serializer.fromJson<String>(json['label']),
      email: serializer.fromJson<String?>(json['email']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastOpenedAt: serializer.fromJson<DateTime>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dbName': serializer.toJson<String>(dbName),
      'kind': serializer.toJson<String>(kind),
      'label': serializer.toJson<String>(label),
      'email': serializer.toJson<String?>(email),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastOpenedAt': serializer.toJson<DateTime>(lastOpenedAt),
    };
  }

  VaultRegistryRow copyWith({
    String? id,
    String? dbName,
    String? kind,
    String? label,
    Value<String?> email = const Value.absent(),
    DateTime? createdAt,
    DateTime? lastOpenedAt,
  }) => VaultRegistryRow(
    id: id ?? this.id,
    dbName: dbName ?? this.dbName,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    email: email.present ? email.value : this.email,
    createdAt: createdAt ?? this.createdAt,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
  );
  VaultRegistryRow copyWithCompanion(VaultRegistryEntriesCompanion data) {
    return VaultRegistryRow(
      id: data.id.present ? data.id.value : this.id,
      dbName: data.dbName.present ? data.dbName.value : this.dbName,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
      email: data.email.present ? data.email.value : this.email,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultRegistryRow(')
          ..write('id: $id, ')
          ..write('dbName: $dbName, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('email: $email, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, dbName, kind, label, email, createdAt, lastOpenedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultRegistryRow &&
          other.id == this.id &&
          other.dbName == this.dbName &&
          other.kind == this.kind &&
          other.label == this.label &&
          other.email == this.email &&
          other.createdAt == this.createdAt &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class VaultRegistryEntriesCompanion extends UpdateCompanion<VaultRegistryRow> {
  final Value<String> id;
  final Value<String> dbName;
  final Value<String> kind;
  final Value<String> label;
  final Value<String?> email;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastOpenedAt;
  final Value<int> rowid;
  const VaultRegistryEntriesCompanion({
    this.id = const Value.absent(),
    this.dbName = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.email = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultRegistryEntriesCompanion.insert({
    required String id,
    required String dbName,
    required String kind,
    required String label,
    this.email = const Value.absent(),
    required DateTime createdAt,
    required DateTime lastOpenedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dbName = Value(dbName),
       kind = Value(kind),
       label = Value(label),
       createdAt = Value(createdAt),
       lastOpenedAt = Value(lastOpenedAt);
  static Insertable<VaultRegistryRow> custom({
    Expression<String>? id,
    Expression<String>? dbName,
    Expression<String>? kind,
    Expression<String>? label,
    Expression<String>? email,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dbName != null) 'db_name': dbName,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
      if (email != null) 'email': email,
      if (createdAt != null) 'created_at': createdAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultRegistryEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? dbName,
    Value<String>? kind,
    Value<String>? label,
    Value<String?>? email,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return VaultRegistryEntriesCompanion(
      id: id ?? this.id,
      dbName: dbName ?? this.dbName,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dbName.present) {
      map['db_name'] = Variable<String>(dbName.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultRegistryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('dbName: $dbName, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('email: $email, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$VaultRegistryDatabase extends GeneratedDatabase {
  _$VaultRegistryDatabase(QueryExecutor e) : super(e);
  $VaultRegistryDatabaseManager get managers =>
      $VaultRegistryDatabaseManager(this);
  late final $VaultRegistryEntriesTable vaultRegistryEntries =
      $VaultRegistryEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [vaultRegistryEntries];
}

typedef $$VaultRegistryEntriesTableCreateCompanionBuilder =
    VaultRegistryEntriesCompanion Function({
      required String id,
      required String dbName,
      required String kind,
      required String label,
      Value<String?> email,
      required DateTime createdAt,
      required DateTime lastOpenedAt,
      Value<int> rowid,
    });
typedef $$VaultRegistryEntriesTableUpdateCompanionBuilder =
    VaultRegistryEntriesCompanion Function({
      Value<String> id,
      Value<String> dbName,
      Value<String> kind,
      Value<String> label,
      Value<String?> email,
      Value<DateTime> createdAt,
      Value<DateTime> lastOpenedAt,
      Value<int> rowid,
    });

class $$VaultRegistryEntriesTableFilterComposer
    extends Composer<_$VaultRegistryDatabase, $VaultRegistryEntriesTable> {
  $$VaultRegistryEntriesTableFilterComposer({
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

  ColumnFilters<String> get dbName => $composableBuilder(
    column: $table.dbName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultRegistryEntriesTableOrderingComposer
    extends Composer<_$VaultRegistryDatabase, $VaultRegistryEntriesTable> {
  $$VaultRegistryEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get dbName => $composableBuilder(
    column: $table.dbName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultRegistryEntriesTableAnnotationComposer
    extends Composer<_$VaultRegistryDatabase, $VaultRegistryEntriesTable> {
  $$VaultRegistryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dbName =>
      $composableBuilder(column: $table.dbName, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );
}

class $$VaultRegistryEntriesTableTableManager
    extends
        RootTableManager<
          _$VaultRegistryDatabase,
          $VaultRegistryEntriesTable,
          VaultRegistryRow,
          $$VaultRegistryEntriesTableFilterComposer,
          $$VaultRegistryEntriesTableOrderingComposer,
          $$VaultRegistryEntriesTableAnnotationComposer,
          $$VaultRegistryEntriesTableCreateCompanionBuilder,
          $$VaultRegistryEntriesTableUpdateCompanionBuilder,
          (
            VaultRegistryRow,
            BaseReferences<
              _$VaultRegistryDatabase,
              $VaultRegistryEntriesTable,
              VaultRegistryRow
            >,
          ),
          VaultRegistryRow,
          PrefetchHooks Function()
        > {
  $$VaultRegistryEntriesTableTableManager(
    _$VaultRegistryDatabase db,
    $VaultRegistryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultRegistryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultRegistryEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$VaultRegistryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dbName = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultRegistryEntriesCompanion(
                id: id,
                dbName: dbName,
                kind: kind,
                label: label,
                email: email,
                createdAt: createdAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dbName,
                required String kind,
                required String label,
                Value<String?> email = const Value.absent(),
                required DateTime createdAt,
                required DateTime lastOpenedAt,
                Value<int> rowid = const Value.absent(),
              }) => VaultRegistryEntriesCompanion.insert(
                id: id,
                dbName: dbName,
                kind: kind,
                label: label,
                email: email,
                createdAt: createdAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultRegistryEntriesTable, VaultRegistryRow>(
                    table,
                  ),
                  BaseReferences<
                    _$VaultRegistryDatabase,
                    $VaultRegistryEntriesTable,
                    VaultRegistryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultRegistryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultRegistryDatabase,
      $VaultRegistryEntriesTable,
      VaultRegistryRow,
      $$VaultRegistryEntriesTableFilterComposer,
      $$VaultRegistryEntriesTableOrderingComposer,
      $$VaultRegistryEntriesTableAnnotationComposer,
      $$VaultRegistryEntriesTableCreateCompanionBuilder,
      $$VaultRegistryEntriesTableUpdateCompanionBuilder,
      (
        VaultRegistryRow,
        BaseReferences<
          _$VaultRegistryDatabase,
          $VaultRegistryEntriesTable,
          VaultRegistryRow
        >,
      ),
      VaultRegistryRow,
      PrefetchHooks Function()
    >;

class $VaultRegistryDatabaseManager {
  final _$VaultRegistryDatabase _db;
  $VaultRegistryDatabaseManager(this._db);
  $$VaultRegistryEntriesTableTableManager get vaultRegistryEntries =>
      $$VaultRegistryEntriesTableTableManager(_db, _db.vaultRegistryEntries);
}
