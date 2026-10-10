// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'domain_cache_database.dart';

// ignore_for_file: type=lint
class $AssetsTable extends Assets with TableInfo<$AssetsTable, Asset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alphaVantageSymbolMeta =
      const VerificationMeta('alphaVantageSymbol');
  @override
  late final GeneratedColumn<String> alphaVantageSymbol =
      GeneratedColumn<String>(
        'alpha_vantage_symbol',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _displaySymbolMeta = const VerificationMeta(
    'displaySymbol',
  );
  @override
  late final GeneratedColumn<String> displaySymbol = GeneratedColumn<String>(
    'display_symbol',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    symbol,
    name,
    alphaVantageSymbol,
    displaySymbol,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Asset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('alpha_vantage_symbol')) {
      context.handle(
        _alphaVantageSymbolMeta,
        alphaVantageSymbol.isAcceptableOrUnknown(
          data['alpha_vantage_symbol']!,
          _alphaVantageSymbolMeta,
        ),
      );
    }
    if (data.containsKey('display_symbol')) {
      context.handle(
        _displaySymbolMeta,
        displaySymbol.isAcceptableOrUnknown(
          data['display_symbol']!,
          _displaySymbolMeta,
        ),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Asset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Asset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      alphaVantageSymbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alpha_vantage_symbol'],
      ),
      displaySymbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_symbol'],
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $AssetsTable createAlias(String alias) {
    return $AssetsTable(attachedDatabase, alias);
  }
}

class Asset extends DataClass implements Insertable<Asset> {
  final String id;
  final String kind;
  final String symbol;
  final String name;
  final String? alphaVantageSymbol;
  final String? displaySymbol;
  final bool deleted;
  const Asset({
    required this.id,
    required this.kind,
    required this.symbol,
    required this.name,
    this.alphaVantageSymbol,
    this.displaySymbol,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['symbol'] = Variable<String>(symbol);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || alphaVantageSymbol != null) {
      map['alpha_vantage_symbol'] = Variable<String>(alphaVantageSymbol);
    }
    if (!nullToAbsent || displaySymbol != null) {
      map['display_symbol'] = Variable<String>(displaySymbol);
    }
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  AssetsCompanion toCompanion(bool nullToAbsent) {
    return AssetsCompanion(
      id: Value(id),
      kind: Value(kind),
      symbol: Value(symbol),
      name: Value(name),
      alphaVantageSymbol: alphaVantageSymbol == null && nullToAbsent
          ? const Value.absent()
          : Value(alphaVantageSymbol),
      displaySymbol: displaySymbol == null && nullToAbsent
          ? const Value.absent()
          : Value(displaySymbol),
      deleted: Value(deleted),
    );
  }

  factory Asset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Asset(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      symbol: serializer.fromJson<String>(json['symbol']),
      name: serializer.fromJson<String>(json['name']),
      alphaVantageSymbol: serializer.fromJson<String?>(
        json['alphaVantageSymbol'],
      ),
      displaySymbol: serializer.fromJson<String?>(json['displaySymbol']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'symbol': serializer.toJson<String>(symbol),
      'name': serializer.toJson<String>(name),
      'alphaVantageSymbol': serializer.toJson<String?>(alphaVantageSymbol),
      'displaySymbol': serializer.toJson<String?>(displaySymbol),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Asset copyWith({
    String? id,
    String? kind,
    String? symbol,
    String? name,
    Value<String?> alphaVantageSymbol = const Value.absent(),
    Value<String?> displaySymbol = const Value.absent(),
    bool? deleted,
  }) => Asset(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    symbol: symbol ?? this.symbol,
    name: name ?? this.name,
    alphaVantageSymbol: alphaVantageSymbol.present
        ? alphaVantageSymbol.value
        : this.alphaVantageSymbol,
    displaySymbol: displaySymbol.present
        ? displaySymbol.value
        : this.displaySymbol,
    deleted: deleted ?? this.deleted,
  );
  Asset copyWithCompanion(AssetsCompanion data) {
    return Asset(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      name: data.name.present ? data.name.value : this.name,
      alphaVantageSymbol: data.alphaVantageSymbol.present
          ? data.alphaVantageSymbol.value
          : this.alphaVantageSymbol,
      displaySymbol: data.displaySymbol.present
          ? data.displaySymbol.value
          : this.displaySymbol,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Asset(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('alphaVantageSymbol: $alphaVantageSymbol, ')
          ..write('displaySymbol: $displaySymbol, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    symbol,
    name,
    alphaVantageSymbol,
    displaySymbol,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Asset &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.symbol == this.symbol &&
          other.name == this.name &&
          other.alphaVantageSymbol == this.alphaVantageSymbol &&
          other.displaySymbol == this.displaySymbol &&
          other.deleted == this.deleted);
}

class AssetsCompanion extends UpdateCompanion<Asset> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> symbol;
  final Value<String> name;
  final Value<String?> alphaVantageSymbol;
  final Value<String?> displaySymbol;
  final Value<bool> deleted;
  final Value<int> rowid;
  const AssetsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.symbol = const Value.absent(),
    this.name = const Value.absent(),
    this.alphaVantageSymbol = const Value.absent(),
    this.displaySymbol = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetsCompanion.insert({
    required String id,
    required String kind,
    required String symbol,
    required String name,
    this.alphaVantageSymbol = const Value.absent(),
    this.displaySymbol = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       symbol = Value(symbol),
       name = Value(name);
  static Insertable<Asset> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? symbol,
    Expression<String>? name,
    Expression<String>? alphaVantageSymbol,
    Expression<String>? displaySymbol,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (symbol != null) 'symbol': symbol,
      if (name != null) 'name': name,
      if (alphaVantageSymbol != null)
        'alpha_vantage_symbol': alphaVantageSymbol,
      if (displaySymbol != null) 'display_symbol': displaySymbol,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? symbol,
    Value<String>? name,
    Value<String?>? alphaVantageSymbol,
    Value<String?>? displaySymbol,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return AssetsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      alphaVantageSymbol: alphaVantageSymbol ?? this.alphaVantageSymbol,
      displaySymbol: displaySymbol ?? this.displaySymbol,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (alphaVantageSymbol.present) {
      map['alpha_vantage_symbol'] = Variable<String>(alphaVantageSymbol.value);
    }
    if (displaySymbol.present) {
      map['display_symbol'] = Variable<String>(displaySymbol.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('alphaVantageSymbol: $alphaVantageSymbol, ')
          ..write('displaySymbol: $displaySymbol, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContainersTable extends Containers
    with TableInfo<$ContainersTable, Container> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContainersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _containerTypeMeta = const VerificationMeta(
    'containerType',
  );
  @override
  late final GeneratedColumn<String> containerType = GeneratedColumn<String>(
    'container_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    containerType,
    parentId,
    icon,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'containers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Container> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('container_type')) {
      context.handle(
        _containerTypeMeta,
        containerType.isAcceptableOrUnknown(
          data['container_type']!,
          _containerTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_containerTypeMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Container map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Container(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      containerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}container_type'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $ContainersTable createAlias(String alias) {
    return $ContainersTable(attachedDatabase, alias);
  }
}

class Container extends DataClass implements Insertable<Container> {
  final String id;
  final String name;
  final String containerType;
  final String? parentId;
  final String? icon;
  final bool deleted;
  const Container({
    required this.id,
    required this.name,
    required this.containerType,
    this.parentId,
    this.icon,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['container_type'] = Variable<String>(containerType);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  ContainersCompanion toCompanion(bool nullToAbsent) {
    return ContainersCompanion(
      id: Value(id),
      name: Value(name),
      containerType: Value(containerType),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      deleted: Value(deleted),
    );
  }

  factory Container.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Container(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      containerType: serializer.fromJson<String>(json['containerType']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      icon: serializer.fromJson<String?>(json['icon']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'containerType': serializer.toJson<String>(containerType),
      'parentId': serializer.toJson<String?>(parentId),
      'icon': serializer.toJson<String?>(icon),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Container copyWith({
    String? id,
    String? name,
    String? containerType,
    Value<String?> parentId = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    bool? deleted,
  }) => Container(
    id: id ?? this.id,
    name: name ?? this.name,
    containerType: containerType ?? this.containerType,
    parentId: parentId.present ? parentId.value : this.parentId,
    icon: icon.present ? icon.value : this.icon,
    deleted: deleted ?? this.deleted,
  );
  Container copyWithCompanion(ContainersCompanion data) {
    return Container(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      containerType: data.containerType.present
          ? data.containerType.value
          : this.containerType,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      icon: data.icon.present ? data.icon.value : this.icon,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Container(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('containerType: $containerType, ')
          ..write('parentId: $parentId, ')
          ..write('icon: $icon, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, containerType, parentId, icon, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Container &&
          other.id == this.id &&
          other.name == this.name &&
          other.containerType == this.containerType &&
          other.parentId == this.parentId &&
          other.icon == this.icon &&
          other.deleted == this.deleted);
}

class ContainersCompanion extends UpdateCompanion<Container> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> containerType;
  final Value<String?> parentId;
  final Value<String?> icon;
  final Value<bool> deleted;
  final Value<int> rowid;
  const ContainersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.containerType = const Value.absent(),
    this.parentId = const Value.absent(),
    this.icon = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContainersCompanion.insert({
    required String id,
    required String name,
    required String containerType,
    this.parentId = const Value.absent(),
    this.icon = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       containerType = Value(containerType);
  static Insertable<Container> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? containerType,
    Expression<String>? parentId,
    Expression<String>? icon,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (containerType != null) 'container_type': containerType,
      if (parentId != null) 'parent_id': parentId,
      if (icon != null) 'icon': icon,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContainersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? containerType,
    Value<String?>? parentId,
    Value<String?>? icon,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return ContainersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      containerType: containerType ?? this.containerType,
      parentId: parentId ?? this.parentId,
      icon: icon ?? this.icon,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (containerType.present) {
      map['container_type'] = Variable<String>(containerType.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContainersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('containerType: $containerType, ')
          ..write('parentId: $parentId, ')
          ..write('icon: $icon, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _postedAtMeta = const VerificationMeta(
    'postedAt',
  );
  @override
  late final GeneratedColumn<DateTime> postedAt = GeneratedColumn<DateTime>(
    'posted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CalendarDate, String>
  effectiveDate = GeneratedColumn<String>(
    'effective_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<CalendarDate>($TransactionsTable.$convertereffectiveDate);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _legOutContainerIdMeta = const VerificationMeta(
    'legOutContainerId',
  );
  @override
  late final GeneratedColumn<String> legOutContainerId =
      GeneratedColumn<String>(
        'leg_out_container_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _legOutAssetIdMeta = const VerificationMeta(
    'legOutAssetId',
  );
  @override
  late final GeneratedColumn<String> legOutAssetId = GeneratedColumn<String>(
    'leg_out_asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legOutQuantityMeta = const VerificationMeta(
    'legOutQuantity',
  );
  @override
  late final GeneratedColumn<String> legOutQuantity = GeneratedColumn<String>(
    'leg_out_quantity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legOutBalanceAfterMeta =
      const VerificationMeta('legOutBalanceAfter');
  @override
  late final GeneratedColumn<String> legOutBalanceAfter =
      GeneratedColumn<String>(
        'leg_out_balance_after',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _legInContainerIdMeta = const VerificationMeta(
    'legInContainerId',
  );
  @override
  late final GeneratedColumn<String> legInContainerId = GeneratedColumn<String>(
    'leg_in_container_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legInAssetIdMeta = const VerificationMeta(
    'legInAssetId',
  );
  @override
  late final GeneratedColumn<String> legInAssetId = GeneratedColumn<String>(
    'leg_in_asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legInQuantityMeta = const VerificationMeta(
    'legInQuantity',
  );
  @override
  late final GeneratedColumn<String> legInQuantity = GeneratedColumn<String>(
    'leg_in_quantity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legInBalanceAfterMeta = const VerificationMeta(
    'legInBalanceAfter',
  );
  @override
  late final GeneratedColumn<String> legInBalanceAfter =
      GeneratedColumn<String>(
        'leg_in_balance_after',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegOutContainerIdMeta =
      const VerificationMeta('budgetLegOutContainerId');
  @override
  late final GeneratedColumn<String> budgetLegOutContainerId =
      GeneratedColumn<String>(
        'budget_leg_out_container_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegOutAssetIdMeta =
      const VerificationMeta('budgetLegOutAssetId');
  @override
  late final GeneratedColumn<String> budgetLegOutAssetId =
      GeneratedColumn<String>(
        'budget_leg_out_asset_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegOutQuantityMeta =
      const VerificationMeta('budgetLegOutQuantity');
  @override
  late final GeneratedColumn<String> budgetLegOutQuantity =
      GeneratedColumn<String>(
        'budget_leg_out_quantity',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegOutBalanceAfterMeta =
      const VerificationMeta('budgetLegOutBalanceAfter');
  @override
  late final GeneratedColumn<String> budgetLegOutBalanceAfter =
      GeneratedColumn<String>(
        'budget_leg_out_balance_after',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegInContainerIdMeta =
      const VerificationMeta('budgetLegInContainerId');
  @override
  late final GeneratedColumn<String> budgetLegInContainerId =
      GeneratedColumn<String>(
        'budget_leg_in_container_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegInAssetIdMeta =
      const VerificationMeta('budgetLegInAssetId');
  @override
  late final GeneratedColumn<String> budgetLegInAssetId =
      GeneratedColumn<String>(
        'budget_leg_in_asset_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegInQuantityMeta =
      const VerificationMeta('budgetLegInQuantity');
  @override
  late final GeneratedColumn<String> budgetLegInQuantity =
      GeneratedColumn<String>(
        'budget_leg_in_quantity',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegInBalanceAfterMeta =
      const VerificationMeta('budgetLegInBalanceAfter');
  @override
  late final GeneratedColumn<String> budgetLegInBalanceAfter =
      GeneratedColumn<String>(
        'budget_leg_in_balance_after',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _manualOrderRankMeta = const VerificationMeta(
    'manualOrderRank',
  );
  @override
  late final GeneratedColumn<int> manualOrderRank = GeneratedColumn<int>(
    'manual_order_rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    postedAt,
    effectiveDate,
    note,
    kind,
    legOutContainerId,
    legOutAssetId,
    legOutQuantity,
    legOutBalanceAfter,
    legInContainerId,
    legInAssetId,
    legInQuantity,
    legInBalanceAfter,
    budgetLegOutContainerId,
    budgetLegOutAssetId,
    budgetLegOutQuantity,
    budgetLegOutBalanceAfter,
    budgetLegInContainerId,
    budgetLegInAssetId,
    budgetLegInQuantity,
    budgetLegInBalanceAfter,
    tags,
    manualOrderRank,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('posted_at')) {
      context.handle(
        _postedAtMeta,
        postedAt.isAcceptableOrUnknown(data['posted_at']!, _postedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_postedAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('leg_out_container_id')) {
      context.handle(
        _legOutContainerIdMeta,
        legOutContainerId.isAcceptableOrUnknown(
          data['leg_out_container_id']!,
          _legOutContainerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legOutContainerIdMeta);
    }
    if (data.containsKey('leg_out_asset_id')) {
      context.handle(
        _legOutAssetIdMeta,
        legOutAssetId.isAcceptableOrUnknown(
          data['leg_out_asset_id']!,
          _legOutAssetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legOutAssetIdMeta);
    }
    if (data.containsKey('leg_out_quantity')) {
      context.handle(
        _legOutQuantityMeta,
        legOutQuantity.isAcceptableOrUnknown(
          data['leg_out_quantity']!,
          _legOutQuantityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legOutQuantityMeta);
    }
    if (data.containsKey('leg_out_balance_after')) {
      context.handle(
        _legOutBalanceAfterMeta,
        legOutBalanceAfter.isAcceptableOrUnknown(
          data['leg_out_balance_after']!,
          _legOutBalanceAfterMeta,
        ),
      );
    }
    if (data.containsKey('leg_in_container_id')) {
      context.handle(
        _legInContainerIdMeta,
        legInContainerId.isAcceptableOrUnknown(
          data['leg_in_container_id']!,
          _legInContainerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legInContainerIdMeta);
    }
    if (data.containsKey('leg_in_asset_id')) {
      context.handle(
        _legInAssetIdMeta,
        legInAssetId.isAcceptableOrUnknown(
          data['leg_in_asset_id']!,
          _legInAssetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legInAssetIdMeta);
    }
    if (data.containsKey('leg_in_quantity')) {
      context.handle(
        _legInQuantityMeta,
        legInQuantity.isAcceptableOrUnknown(
          data['leg_in_quantity']!,
          _legInQuantityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legInQuantityMeta);
    }
    if (data.containsKey('leg_in_balance_after')) {
      context.handle(
        _legInBalanceAfterMeta,
        legInBalanceAfter.isAcceptableOrUnknown(
          data['leg_in_balance_after']!,
          _legInBalanceAfterMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_out_container_id')) {
      context.handle(
        _budgetLegOutContainerIdMeta,
        budgetLegOutContainerId.isAcceptableOrUnknown(
          data['budget_leg_out_container_id']!,
          _budgetLegOutContainerIdMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_out_asset_id')) {
      context.handle(
        _budgetLegOutAssetIdMeta,
        budgetLegOutAssetId.isAcceptableOrUnknown(
          data['budget_leg_out_asset_id']!,
          _budgetLegOutAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_out_quantity')) {
      context.handle(
        _budgetLegOutQuantityMeta,
        budgetLegOutQuantity.isAcceptableOrUnknown(
          data['budget_leg_out_quantity']!,
          _budgetLegOutQuantityMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_out_balance_after')) {
      context.handle(
        _budgetLegOutBalanceAfterMeta,
        budgetLegOutBalanceAfter.isAcceptableOrUnknown(
          data['budget_leg_out_balance_after']!,
          _budgetLegOutBalanceAfterMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_in_container_id')) {
      context.handle(
        _budgetLegInContainerIdMeta,
        budgetLegInContainerId.isAcceptableOrUnknown(
          data['budget_leg_in_container_id']!,
          _budgetLegInContainerIdMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_in_asset_id')) {
      context.handle(
        _budgetLegInAssetIdMeta,
        budgetLegInAssetId.isAcceptableOrUnknown(
          data['budget_leg_in_asset_id']!,
          _budgetLegInAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_in_quantity')) {
      context.handle(
        _budgetLegInQuantityMeta,
        budgetLegInQuantity.isAcceptableOrUnknown(
          data['budget_leg_in_quantity']!,
          _budgetLegInQuantityMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_in_balance_after')) {
      context.handle(
        _budgetLegInBalanceAfterMeta,
        budgetLegInBalanceAfter.isAcceptableOrUnknown(
          data['budget_leg_in_balance_after']!,
          _budgetLegInBalanceAfterMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('manual_order_rank')) {
      context.handle(
        _manualOrderRankMeta,
        manualOrderRank.isAcceptableOrUnknown(
          data['manual_order_rank']!,
          _manualOrderRankMeta,
        ),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      postedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}posted_at'],
      )!,
      effectiveDate: $TransactionsTable.$convertereffectiveDate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}effective_date'],
        )!,
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      legOutContainerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_out_container_id'],
      )!,
      legOutAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_out_asset_id'],
      )!,
      legOutQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_out_quantity'],
      )!,
      legOutBalanceAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_out_balance_after'],
      ),
      legInContainerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_in_container_id'],
      )!,
      legInAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_in_asset_id'],
      )!,
      legInQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_in_quantity'],
      )!,
      legInBalanceAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_in_balance_after'],
      ),
      budgetLegOutContainerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_out_container_id'],
      ),
      budgetLegOutAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_out_asset_id'],
      ),
      budgetLegOutQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_out_quantity'],
      ),
      budgetLegOutBalanceAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_out_balance_after'],
      ),
      budgetLegInContainerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_in_container_id'],
      ),
      budgetLegInAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_in_asset_id'],
      ),
      budgetLegInQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_in_quantity'],
      ),
      budgetLegInBalanceAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_in_balance_after'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      manualOrderRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manual_order_rank'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static TypeConverter<CalendarDate, String> $convertereffectiveDate =
      const CalendarDateConverter();
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final DateTime postedAt;
  final CalendarDate effectiveDate;
  final String? note;
  final String kind;
  final String legOutContainerId;
  final String legOutAssetId;
  final String legOutQuantity;
  final String? legOutBalanceAfter;
  final String legInContainerId;
  final String legInAssetId;
  final String legInQuantity;
  final String? legInBalanceAfter;
  final String? budgetLegOutContainerId;
  final String? budgetLegOutAssetId;
  final String? budgetLegOutQuantity;
  final String? budgetLegOutBalanceAfter;
  final String? budgetLegInContainerId;
  final String? budgetLegInAssetId;
  final String? budgetLegInQuantity;
  final String? budgetLegInBalanceAfter;
  final String tags;
  final int manualOrderRank;
  final bool deleted;
  const Transaction({
    required this.id,
    required this.postedAt,
    required this.effectiveDate,
    this.note,
    required this.kind,
    required this.legOutContainerId,
    required this.legOutAssetId,
    required this.legOutQuantity,
    this.legOutBalanceAfter,
    required this.legInContainerId,
    required this.legInAssetId,
    required this.legInQuantity,
    this.legInBalanceAfter,
    this.budgetLegOutContainerId,
    this.budgetLegOutAssetId,
    this.budgetLegOutQuantity,
    this.budgetLegOutBalanceAfter,
    this.budgetLegInContainerId,
    this.budgetLegInAssetId,
    this.budgetLegInQuantity,
    this.budgetLegInBalanceAfter,
    required this.tags,
    required this.manualOrderRank,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['posted_at'] = Variable<DateTime>(postedAt);
    {
      map['effective_date'] = Variable<String>(
        $TransactionsTable.$convertereffectiveDate.toSql(effectiveDate),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['kind'] = Variable<String>(kind);
    map['leg_out_container_id'] = Variable<String>(legOutContainerId);
    map['leg_out_asset_id'] = Variable<String>(legOutAssetId);
    map['leg_out_quantity'] = Variable<String>(legOutQuantity);
    if (!nullToAbsent || legOutBalanceAfter != null) {
      map['leg_out_balance_after'] = Variable<String>(legOutBalanceAfter);
    }
    map['leg_in_container_id'] = Variable<String>(legInContainerId);
    map['leg_in_asset_id'] = Variable<String>(legInAssetId);
    map['leg_in_quantity'] = Variable<String>(legInQuantity);
    if (!nullToAbsent || legInBalanceAfter != null) {
      map['leg_in_balance_after'] = Variable<String>(legInBalanceAfter);
    }
    if (!nullToAbsent || budgetLegOutContainerId != null) {
      map['budget_leg_out_container_id'] = Variable<String>(
        budgetLegOutContainerId,
      );
    }
    if (!nullToAbsent || budgetLegOutAssetId != null) {
      map['budget_leg_out_asset_id'] = Variable<String>(budgetLegOutAssetId);
    }
    if (!nullToAbsent || budgetLegOutQuantity != null) {
      map['budget_leg_out_quantity'] = Variable<String>(budgetLegOutQuantity);
    }
    if (!nullToAbsent || budgetLegOutBalanceAfter != null) {
      map['budget_leg_out_balance_after'] = Variable<String>(
        budgetLegOutBalanceAfter,
      );
    }
    if (!nullToAbsent || budgetLegInContainerId != null) {
      map['budget_leg_in_container_id'] = Variable<String>(
        budgetLegInContainerId,
      );
    }
    if (!nullToAbsent || budgetLegInAssetId != null) {
      map['budget_leg_in_asset_id'] = Variable<String>(budgetLegInAssetId);
    }
    if (!nullToAbsent || budgetLegInQuantity != null) {
      map['budget_leg_in_quantity'] = Variable<String>(budgetLegInQuantity);
    }
    if (!nullToAbsent || budgetLegInBalanceAfter != null) {
      map['budget_leg_in_balance_after'] = Variable<String>(
        budgetLegInBalanceAfter,
      );
    }
    map['tags'] = Variable<String>(tags);
    map['manual_order_rank'] = Variable<int>(manualOrderRank);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      postedAt: Value(postedAt),
      effectiveDate: Value(effectiveDate),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      kind: Value(kind),
      legOutContainerId: Value(legOutContainerId),
      legOutAssetId: Value(legOutAssetId),
      legOutQuantity: Value(legOutQuantity),
      legOutBalanceAfter: legOutBalanceAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(legOutBalanceAfter),
      legInContainerId: Value(legInContainerId),
      legInAssetId: Value(legInAssetId),
      legInQuantity: Value(legInQuantity),
      legInBalanceAfter: legInBalanceAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(legInBalanceAfter),
      budgetLegOutContainerId: budgetLegOutContainerId == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegOutContainerId),
      budgetLegOutAssetId: budgetLegOutAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegOutAssetId),
      budgetLegOutQuantity: budgetLegOutQuantity == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegOutQuantity),
      budgetLegOutBalanceAfter: budgetLegOutBalanceAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegOutBalanceAfter),
      budgetLegInContainerId: budgetLegInContainerId == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegInContainerId),
      budgetLegInAssetId: budgetLegInAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegInAssetId),
      budgetLegInQuantity: budgetLegInQuantity == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegInQuantity),
      budgetLegInBalanceAfter: budgetLegInBalanceAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegInBalanceAfter),
      tags: Value(tags),
      manualOrderRank: Value(manualOrderRank),
      deleted: Value(deleted),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      postedAt: serializer.fromJson<DateTime>(json['postedAt']),
      effectiveDate: serializer.fromJson<CalendarDate>(json['effectiveDate']),
      note: serializer.fromJson<String?>(json['note']),
      kind: serializer.fromJson<String>(json['kind']),
      legOutContainerId: serializer.fromJson<String>(json['legOutContainerId']),
      legOutAssetId: serializer.fromJson<String>(json['legOutAssetId']),
      legOutQuantity: serializer.fromJson<String>(json['legOutQuantity']),
      legOutBalanceAfter: serializer.fromJson<String?>(
        json['legOutBalanceAfter'],
      ),
      legInContainerId: serializer.fromJson<String>(json['legInContainerId']),
      legInAssetId: serializer.fromJson<String>(json['legInAssetId']),
      legInQuantity: serializer.fromJson<String>(json['legInQuantity']),
      legInBalanceAfter: serializer.fromJson<String?>(
        json['legInBalanceAfter'],
      ),
      budgetLegOutContainerId: serializer.fromJson<String?>(
        json['budgetLegOutContainerId'],
      ),
      budgetLegOutAssetId: serializer.fromJson<String?>(
        json['budgetLegOutAssetId'],
      ),
      budgetLegOutQuantity: serializer.fromJson<String?>(
        json['budgetLegOutQuantity'],
      ),
      budgetLegOutBalanceAfter: serializer.fromJson<String?>(
        json['budgetLegOutBalanceAfter'],
      ),
      budgetLegInContainerId: serializer.fromJson<String?>(
        json['budgetLegInContainerId'],
      ),
      budgetLegInAssetId: serializer.fromJson<String?>(
        json['budgetLegInAssetId'],
      ),
      budgetLegInQuantity: serializer.fromJson<String?>(
        json['budgetLegInQuantity'],
      ),
      budgetLegInBalanceAfter: serializer.fromJson<String?>(
        json['budgetLegInBalanceAfter'],
      ),
      tags: serializer.fromJson<String>(json['tags']),
      manualOrderRank: serializer.fromJson<int>(json['manualOrderRank']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'postedAt': serializer.toJson<DateTime>(postedAt),
      'effectiveDate': serializer.toJson<CalendarDate>(effectiveDate),
      'note': serializer.toJson<String?>(note),
      'kind': serializer.toJson<String>(kind),
      'legOutContainerId': serializer.toJson<String>(legOutContainerId),
      'legOutAssetId': serializer.toJson<String>(legOutAssetId),
      'legOutQuantity': serializer.toJson<String>(legOutQuantity),
      'legOutBalanceAfter': serializer.toJson<String?>(legOutBalanceAfter),
      'legInContainerId': serializer.toJson<String>(legInContainerId),
      'legInAssetId': serializer.toJson<String>(legInAssetId),
      'legInQuantity': serializer.toJson<String>(legInQuantity),
      'legInBalanceAfter': serializer.toJson<String?>(legInBalanceAfter),
      'budgetLegOutContainerId': serializer.toJson<String?>(
        budgetLegOutContainerId,
      ),
      'budgetLegOutAssetId': serializer.toJson<String?>(budgetLegOutAssetId),
      'budgetLegOutQuantity': serializer.toJson<String?>(budgetLegOutQuantity),
      'budgetLegOutBalanceAfter': serializer.toJson<String?>(
        budgetLegOutBalanceAfter,
      ),
      'budgetLegInContainerId': serializer.toJson<String?>(
        budgetLegInContainerId,
      ),
      'budgetLegInAssetId': serializer.toJson<String?>(budgetLegInAssetId),
      'budgetLegInQuantity': serializer.toJson<String?>(budgetLegInQuantity),
      'budgetLegInBalanceAfter': serializer.toJson<String?>(
        budgetLegInBalanceAfter,
      ),
      'tags': serializer.toJson<String>(tags),
      'manualOrderRank': serializer.toJson<int>(manualOrderRank),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Transaction copyWith({
    String? id,
    DateTime? postedAt,
    CalendarDate? effectiveDate,
    Value<String?> note = const Value.absent(),
    String? kind,
    String? legOutContainerId,
    String? legOutAssetId,
    String? legOutQuantity,
    Value<String?> legOutBalanceAfter = const Value.absent(),
    String? legInContainerId,
    String? legInAssetId,
    String? legInQuantity,
    Value<String?> legInBalanceAfter = const Value.absent(),
    Value<String?> budgetLegOutContainerId = const Value.absent(),
    Value<String?> budgetLegOutAssetId = const Value.absent(),
    Value<String?> budgetLegOutQuantity = const Value.absent(),
    Value<String?> budgetLegOutBalanceAfter = const Value.absent(),
    Value<String?> budgetLegInContainerId = const Value.absent(),
    Value<String?> budgetLegInAssetId = const Value.absent(),
    Value<String?> budgetLegInQuantity = const Value.absent(),
    Value<String?> budgetLegInBalanceAfter = const Value.absent(),
    String? tags,
    int? manualOrderRank,
    bool? deleted,
  }) => Transaction(
    id: id ?? this.id,
    postedAt: postedAt ?? this.postedAt,
    effectiveDate: effectiveDate ?? this.effectiveDate,
    note: note.present ? note.value : this.note,
    kind: kind ?? this.kind,
    legOutContainerId: legOutContainerId ?? this.legOutContainerId,
    legOutAssetId: legOutAssetId ?? this.legOutAssetId,
    legOutQuantity: legOutQuantity ?? this.legOutQuantity,
    legOutBalanceAfter: legOutBalanceAfter.present
        ? legOutBalanceAfter.value
        : this.legOutBalanceAfter,
    legInContainerId: legInContainerId ?? this.legInContainerId,
    legInAssetId: legInAssetId ?? this.legInAssetId,
    legInQuantity: legInQuantity ?? this.legInQuantity,
    legInBalanceAfter: legInBalanceAfter.present
        ? legInBalanceAfter.value
        : this.legInBalanceAfter,
    budgetLegOutContainerId: budgetLegOutContainerId.present
        ? budgetLegOutContainerId.value
        : this.budgetLegOutContainerId,
    budgetLegOutAssetId: budgetLegOutAssetId.present
        ? budgetLegOutAssetId.value
        : this.budgetLegOutAssetId,
    budgetLegOutQuantity: budgetLegOutQuantity.present
        ? budgetLegOutQuantity.value
        : this.budgetLegOutQuantity,
    budgetLegOutBalanceAfter: budgetLegOutBalanceAfter.present
        ? budgetLegOutBalanceAfter.value
        : this.budgetLegOutBalanceAfter,
    budgetLegInContainerId: budgetLegInContainerId.present
        ? budgetLegInContainerId.value
        : this.budgetLegInContainerId,
    budgetLegInAssetId: budgetLegInAssetId.present
        ? budgetLegInAssetId.value
        : this.budgetLegInAssetId,
    budgetLegInQuantity: budgetLegInQuantity.present
        ? budgetLegInQuantity.value
        : this.budgetLegInQuantity,
    budgetLegInBalanceAfter: budgetLegInBalanceAfter.present
        ? budgetLegInBalanceAfter.value
        : this.budgetLegInBalanceAfter,
    tags: tags ?? this.tags,
    manualOrderRank: manualOrderRank ?? this.manualOrderRank,
    deleted: deleted ?? this.deleted,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      postedAt: data.postedAt.present ? data.postedAt.value : this.postedAt,
      effectiveDate: data.effectiveDate.present
          ? data.effectiveDate.value
          : this.effectiveDate,
      note: data.note.present ? data.note.value : this.note,
      kind: data.kind.present ? data.kind.value : this.kind,
      legOutContainerId: data.legOutContainerId.present
          ? data.legOutContainerId.value
          : this.legOutContainerId,
      legOutAssetId: data.legOutAssetId.present
          ? data.legOutAssetId.value
          : this.legOutAssetId,
      legOutQuantity: data.legOutQuantity.present
          ? data.legOutQuantity.value
          : this.legOutQuantity,
      legOutBalanceAfter: data.legOutBalanceAfter.present
          ? data.legOutBalanceAfter.value
          : this.legOutBalanceAfter,
      legInContainerId: data.legInContainerId.present
          ? data.legInContainerId.value
          : this.legInContainerId,
      legInAssetId: data.legInAssetId.present
          ? data.legInAssetId.value
          : this.legInAssetId,
      legInQuantity: data.legInQuantity.present
          ? data.legInQuantity.value
          : this.legInQuantity,
      legInBalanceAfter: data.legInBalanceAfter.present
          ? data.legInBalanceAfter.value
          : this.legInBalanceAfter,
      budgetLegOutContainerId: data.budgetLegOutContainerId.present
          ? data.budgetLegOutContainerId.value
          : this.budgetLegOutContainerId,
      budgetLegOutAssetId: data.budgetLegOutAssetId.present
          ? data.budgetLegOutAssetId.value
          : this.budgetLegOutAssetId,
      budgetLegOutQuantity: data.budgetLegOutQuantity.present
          ? data.budgetLegOutQuantity.value
          : this.budgetLegOutQuantity,
      budgetLegOutBalanceAfter: data.budgetLegOutBalanceAfter.present
          ? data.budgetLegOutBalanceAfter.value
          : this.budgetLegOutBalanceAfter,
      budgetLegInContainerId: data.budgetLegInContainerId.present
          ? data.budgetLegInContainerId.value
          : this.budgetLegInContainerId,
      budgetLegInAssetId: data.budgetLegInAssetId.present
          ? data.budgetLegInAssetId.value
          : this.budgetLegInAssetId,
      budgetLegInQuantity: data.budgetLegInQuantity.present
          ? data.budgetLegInQuantity.value
          : this.budgetLegInQuantity,
      budgetLegInBalanceAfter: data.budgetLegInBalanceAfter.present
          ? data.budgetLegInBalanceAfter.value
          : this.budgetLegInBalanceAfter,
      tags: data.tags.present ? data.tags.value : this.tags,
      manualOrderRank: data.manualOrderRank.present
          ? data.manualOrderRank.value
          : this.manualOrderRank,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('postedAt: $postedAt, ')
          ..write('effectiveDate: $effectiveDate, ')
          ..write('note: $note, ')
          ..write('kind: $kind, ')
          ..write('legOutContainerId: $legOutContainerId, ')
          ..write('legOutAssetId: $legOutAssetId, ')
          ..write('legOutQuantity: $legOutQuantity, ')
          ..write('legOutBalanceAfter: $legOutBalanceAfter, ')
          ..write('legInContainerId: $legInContainerId, ')
          ..write('legInAssetId: $legInAssetId, ')
          ..write('legInQuantity: $legInQuantity, ')
          ..write('legInBalanceAfter: $legInBalanceAfter, ')
          ..write('budgetLegOutContainerId: $budgetLegOutContainerId, ')
          ..write('budgetLegOutAssetId: $budgetLegOutAssetId, ')
          ..write('budgetLegOutQuantity: $budgetLegOutQuantity, ')
          ..write('budgetLegOutBalanceAfter: $budgetLegOutBalanceAfter, ')
          ..write('budgetLegInContainerId: $budgetLegInContainerId, ')
          ..write('budgetLegInAssetId: $budgetLegInAssetId, ')
          ..write('budgetLegInQuantity: $budgetLegInQuantity, ')
          ..write('budgetLegInBalanceAfter: $budgetLegInBalanceAfter, ')
          ..write('tags: $tags, ')
          ..write('manualOrderRank: $manualOrderRank, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    postedAt,
    effectiveDate,
    note,
    kind,
    legOutContainerId,
    legOutAssetId,
    legOutQuantity,
    legOutBalanceAfter,
    legInContainerId,
    legInAssetId,
    legInQuantity,
    legInBalanceAfter,
    budgetLegOutContainerId,
    budgetLegOutAssetId,
    budgetLegOutQuantity,
    budgetLegOutBalanceAfter,
    budgetLegInContainerId,
    budgetLegInAssetId,
    budgetLegInQuantity,
    budgetLegInBalanceAfter,
    tags,
    manualOrderRank,
    deleted,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.postedAt == this.postedAt &&
          other.effectiveDate == this.effectiveDate &&
          other.note == this.note &&
          other.kind == this.kind &&
          other.legOutContainerId == this.legOutContainerId &&
          other.legOutAssetId == this.legOutAssetId &&
          other.legOutQuantity == this.legOutQuantity &&
          other.legOutBalanceAfter == this.legOutBalanceAfter &&
          other.legInContainerId == this.legInContainerId &&
          other.legInAssetId == this.legInAssetId &&
          other.legInQuantity == this.legInQuantity &&
          other.legInBalanceAfter == this.legInBalanceAfter &&
          other.budgetLegOutContainerId == this.budgetLegOutContainerId &&
          other.budgetLegOutAssetId == this.budgetLegOutAssetId &&
          other.budgetLegOutQuantity == this.budgetLegOutQuantity &&
          other.budgetLegOutBalanceAfter == this.budgetLegOutBalanceAfter &&
          other.budgetLegInContainerId == this.budgetLegInContainerId &&
          other.budgetLegInAssetId == this.budgetLegInAssetId &&
          other.budgetLegInQuantity == this.budgetLegInQuantity &&
          other.budgetLegInBalanceAfter == this.budgetLegInBalanceAfter &&
          other.tags == this.tags &&
          other.manualOrderRank == this.manualOrderRank &&
          other.deleted == this.deleted);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<DateTime> postedAt;
  final Value<CalendarDate> effectiveDate;
  final Value<String?> note;
  final Value<String> kind;
  final Value<String> legOutContainerId;
  final Value<String> legOutAssetId;
  final Value<String> legOutQuantity;
  final Value<String?> legOutBalanceAfter;
  final Value<String> legInContainerId;
  final Value<String> legInAssetId;
  final Value<String> legInQuantity;
  final Value<String?> legInBalanceAfter;
  final Value<String?> budgetLegOutContainerId;
  final Value<String?> budgetLegOutAssetId;
  final Value<String?> budgetLegOutQuantity;
  final Value<String?> budgetLegOutBalanceAfter;
  final Value<String?> budgetLegInContainerId;
  final Value<String?> budgetLegInAssetId;
  final Value<String?> budgetLegInQuantity;
  final Value<String?> budgetLegInBalanceAfter;
  final Value<String> tags;
  final Value<int> manualOrderRank;
  final Value<bool> deleted;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.postedAt = const Value.absent(),
    this.effectiveDate = const Value.absent(),
    this.note = const Value.absent(),
    this.kind = const Value.absent(),
    this.legOutContainerId = const Value.absent(),
    this.legOutAssetId = const Value.absent(),
    this.legOutQuantity = const Value.absent(),
    this.legOutBalanceAfter = const Value.absent(),
    this.legInContainerId = const Value.absent(),
    this.legInAssetId = const Value.absent(),
    this.legInQuantity = const Value.absent(),
    this.legInBalanceAfter = const Value.absent(),
    this.budgetLegOutContainerId = const Value.absent(),
    this.budgetLegOutAssetId = const Value.absent(),
    this.budgetLegOutQuantity = const Value.absent(),
    this.budgetLegOutBalanceAfter = const Value.absent(),
    this.budgetLegInContainerId = const Value.absent(),
    this.budgetLegInAssetId = const Value.absent(),
    this.budgetLegInQuantity = const Value.absent(),
    this.budgetLegInBalanceAfter = const Value.absent(),
    this.tags = const Value.absent(),
    this.manualOrderRank = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required DateTime postedAt,
    required CalendarDate effectiveDate,
    this.note = const Value.absent(),
    required String kind,
    required String legOutContainerId,
    required String legOutAssetId,
    required String legOutQuantity,
    this.legOutBalanceAfter = const Value.absent(),
    required String legInContainerId,
    required String legInAssetId,
    required String legInQuantity,
    this.legInBalanceAfter = const Value.absent(),
    this.budgetLegOutContainerId = const Value.absent(),
    this.budgetLegOutAssetId = const Value.absent(),
    this.budgetLegOutQuantity = const Value.absent(),
    this.budgetLegOutBalanceAfter = const Value.absent(),
    this.budgetLegInContainerId = const Value.absent(),
    this.budgetLegInAssetId = const Value.absent(),
    this.budgetLegInQuantity = const Value.absent(),
    this.budgetLegInBalanceAfter = const Value.absent(),
    this.tags = const Value.absent(),
    this.manualOrderRank = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       postedAt = Value(postedAt),
       effectiveDate = Value(effectiveDate),
       kind = Value(kind),
       legOutContainerId = Value(legOutContainerId),
       legOutAssetId = Value(legOutAssetId),
       legOutQuantity = Value(legOutQuantity),
       legInContainerId = Value(legInContainerId),
       legInAssetId = Value(legInAssetId),
       legInQuantity = Value(legInQuantity);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<DateTime>? postedAt,
    Expression<String>? effectiveDate,
    Expression<String>? note,
    Expression<String>? kind,
    Expression<String>? legOutContainerId,
    Expression<String>? legOutAssetId,
    Expression<String>? legOutQuantity,
    Expression<String>? legOutBalanceAfter,
    Expression<String>? legInContainerId,
    Expression<String>? legInAssetId,
    Expression<String>? legInQuantity,
    Expression<String>? legInBalanceAfter,
    Expression<String>? budgetLegOutContainerId,
    Expression<String>? budgetLegOutAssetId,
    Expression<String>? budgetLegOutQuantity,
    Expression<String>? budgetLegOutBalanceAfter,
    Expression<String>? budgetLegInContainerId,
    Expression<String>? budgetLegInAssetId,
    Expression<String>? budgetLegInQuantity,
    Expression<String>? budgetLegInBalanceAfter,
    Expression<String>? tags,
    Expression<int>? manualOrderRank,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (postedAt != null) 'posted_at': postedAt,
      if (effectiveDate != null) 'effective_date': effectiveDate,
      if (note != null) 'note': note,
      if (kind != null) 'kind': kind,
      if (legOutContainerId != null) 'leg_out_container_id': legOutContainerId,
      if (legOutAssetId != null) 'leg_out_asset_id': legOutAssetId,
      if (legOutQuantity != null) 'leg_out_quantity': legOutQuantity,
      if (legOutBalanceAfter != null)
        'leg_out_balance_after': legOutBalanceAfter,
      if (legInContainerId != null) 'leg_in_container_id': legInContainerId,
      if (legInAssetId != null) 'leg_in_asset_id': legInAssetId,
      if (legInQuantity != null) 'leg_in_quantity': legInQuantity,
      if (legInBalanceAfter != null) 'leg_in_balance_after': legInBalanceAfter,
      if (budgetLegOutContainerId != null)
        'budget_leg_out_container_id': budgetLegOutContainerId,
      if (budgetLegOutAssetId != null)
        'budget_leg_out_asset_id': budgetLegOutAssetId,
      if (budgetLegOutQuantity != null)
        'budget_leg_out_quantity': budgetLegOutQuantity,
      if (budgetLegOutBalanceAfter != null)
        'budget_leg_out_balance_after': budgetLegOutBalanceAfter,
      if (budgetLegInContainerId != null)
        'budget_leg_in_container_id': budgetLegInContainerId,
      if (budgetLegInAssetId != null)
        'budget_leg_in_asset_id': budgetLegInAssetId,
      if (budgetLegInQuantity != null)
        'budget_leg_in_quantity': budgetLegInQuantity,
      if (budgetLegInBalanceAfter != null)
        'budget_leg_in_balance_after': budgetLegInBalanceAfter,
      if (tags != null) 'tags': tags,
      if (manualOrderRank != null) 'manual_order_rank': manualOrderRank,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? postedAt,
    Value<CalendarDate>? effectiveDate,
    Value<String?>? note,
    Value<String>? kind,
    Value<String>? legOutContainerId,
    Value<String>? legOutAssetId,
    Value<String>? legOutQuantity,
    Value<String?>? legOutBalanceAfter,
    Value<String>? legInContainerId,
    Value<String>? legInAssetId,
    Value<String>? legInQuantity,
    Value<String?>? legInBalanceAfter,
    Value<String?>? budgetLegOutContainerId,
    Value<String?>? budgetLegOutAssetId,
    Value<String?>? budgetLegOutQuantity,
    Value<String?>? budgetLegOutBalanceAfter,
    Value<String?>? budgetLegInContainerId,
    Value<String?>? budgetLegInAssetId,
    Value<String?>? budgetLegInQuantity,
    Value<String?>? budgetLegInBalanceAfter,
    Value<String>? tags,
    Value<int>? manualOrderRank,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      postedAt: postedAt ?? this.postedAt,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      note: note ?? this.note,
      kind: kind ?? this.kind,
      legOutContainerId: legOutContainerId ?? this.legOutContainerId,
      legOutAssetId: legOutAssetId ?? this.legOutAssetId,
      legOutQuantity: legOutQuantity ?? this.legOutQuantity,
      legOutBalanceAfter: legOutBalanceAfter ?? this.legOutBalanceAfter,
      legInContainerId: legInContainerId ?? this.legInContainerId,
      legInAssetId: legInAssetId ?? this.legInAssetId,
      legInQuantity: legInQuantity ?? this.legInQuantity,
      legInBalanceAfter: legInBalanceAfter ?? this.legInBalanceAfter,
      budgetLegOutContainerId:
          budgetLegOutContainerId ?? this.budgetLegOutContainerId,
      budgetLegOutAssetId: budgetLegOutAssetId ?? this.budgetLegOutAssetId,
      budgetLegOutQuantity: budgetLegOutQuantity ?? this.budgetLegOutQuantity,
      budgetLegOutBalanceAfter:
          budgetLegOutBalanceAfter ?? this.budgetLegOutBalanceAfter,
      budgetLegInContainerId:
          budgetLegInContainerId ?? this.budgetLegInContainerId,
      budgetLegInAssetId: budgetLegInAssetId ?? this.budgetLegInAssetId,
      budgetLegInQuantity: budgetLegInQuantity ?? this.budgetLegInQuantity,
      budgetLegInBalanceAfter:
          budgetLegInBalanceAfter ?? this.budgetLegInBalanceAfter,
      tags: tags ?? this.tags,
      manualOrderRank: manualOrderRank ?? this.manualOrderRank,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (postedAt.present) {
      map['posted_at'] = Variable<DateTime>(postedAt.value);
    }
    if (effectiveDate.present) {
      map['effective_date'] = Variable<String>(
        $TransactionsTable.$convertereffectiveDate.toSql(effectiveDate.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (legOutContainerId.present) {
      map['leg_out_container_id'] = Variable<String>(legOutContainerId.value);
    }
    if (legOutAssetId.present) {
      map['leg_out_asset_id'] = Variable<String>(legOutAssetId.value);
    }
    if (legOutQuantity.present) {
      map['leg_out_quantity'] = Variable<String>(legOutQuantity.value);
    }
    if (legOutBalanceAfter.present) {
      map['leg_out_balance_after'] = Variable<String>(legOutBalanceAfter.value);
    }
    if (legInContainerId.present) {
      map['leg_in_container_id'] = Variable<String>(legInContainerId.value);
    }
    if (legInAssetId.present) {
      map['leg_in_asset_id'] = Variable<String>(legInAssetId.value);
    }
    if (legInQuantity.present) {
      map['leg_in_quantity'] = Variable<String>(legInQuantity.value);
    }
    if (legInBalanceAfter.present) {
      map['leg_in_balance_after'] = Variable<String>(legInBalanceAfter.value);
    }
    if (budgetLegOutContainerId.present) {
      map['budget_leg_out_container_id'] = Variable<String>(
        budgetLegOutContainerId.value,
      );
    }
    if (budgetLegOutAssetId.present) {
      map['budget_leg_out_asset_id'] = Variable<String>(
        budgetLegOutAssetId.value,
      );
    }
    if (budgetLegOutQuantity.present) {
      map['budget_leg_out_quantity'] = Variable<String>(
        budgetLegOutQuantity.value,
      );
    }
    if (budgetLegOutBalanceAfter.present) {
      map['budget_leg_out_balance_after'] = Variable<String>(
        budgetLegOutBalanceAfter.value,
      );
    }
    if (budgetLegInContainerId.present) {
      map['budget_leg_in_container_id'] = Variable<String>(
        budgetLegInContainerId.value,
      );
    }
    if (budgetLegInAssetId.present) {
      map['budget_leg_in_asset_id'] = Variable<String>(
        budgetLegInAssetId.value,
      );
    }
    if (budgetLegInQuantity.present) {
      map['budget_leg_in_quantity'] = Variable<String>(
        budgetLegInQuantity.value,
      );
    }
    if (budgetLegInBalanceAfter.present) {
      map['budget_leg_in_balance_after'] = Variable<String>(
        budgetLegInBalanceAfter.value,
      );
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (manualOrderRank.present) {
      map['manual_order_rank'] = Variable<int>(manualOrderRank.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('postedAt: $postedAt, ')
          ..write('effectiveDate: $effectiveDate, ')
          ..write('note: $note, ')
          ..write('kind: $kind, ')
          ..write('legOutContainerId: $legOutContainerId, ')
          ..write('legOutAssetId: $legOutAssetId, ')
          ..write('legOutQuantity: $legOutQuantity, ')
          ..write('legOutBalanceAfter: $legOutBalanceAfter, ')
          ..write('legInContainerId: $legInContainerId, ')
          ..write('legInAssetId: $legInAssetId, ')
          ..write('legInQuantity: $legInQuantity, ')
          ..write('legInBalanceAfter: $legInBalanceAfter, ')
          ..write('budgetLegOutContainerId: $budgetLegOutContainerId, ')
          ..write('budgetLegOutAssetId: $budgetLegOutAssetId, ')
          ..write('budgetLegOutQuantity: $budgetLegOutQuantity, ')
          ..write('budgetLegOutBalanceAfter: $budgetLegOutBalanceAfter, ')
          ..write('budgetLegInContainerId: $budgetLegInContainerId, ')
          ..write('budgetLegInAssetId: $budgetLegInAssetId, ')
          ..write('budgetLegInQuantity: $budgetLegInQuantity, ')
          ..write('budgetLegInBalanceAfter: $budgetLegInBalanceAfter, ')
          ..write('tags: $tags, ')
          ..write('manualOrderRank: $manualOrderRank, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PriceSnapshotsTable extends PriceSnapshots
    with TableInfo<$PriceSnapshotsTable, PriceSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PriceSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<String> price = GeneratedColumn<String>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyAssetIdMeta = const VerificationMeta(
    'currencyAssetId',
  );
  @override
  late final GeneratedColumn<String> currencyAssetId = GeneratedColumn<String>(
    'currency_asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetId,
    date,
    price,
    currencyAssetId,
    source,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'price_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<PriceSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('currency_asset_id')) {
      context.handle(
        _currencyAssetIdMeta,
        currencyAssetId.isAcceptableOrUnknown(
          data['currency_asset_id']!,
          _currencyAssetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyAssetIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PriceSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PriceSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price'],
      )!,
      currencyAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_asset_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $PriceSnapshotsTable createAlias(String alias) {
    return $PriceSnapshotsTable(attachedDatabase, alias);
  }
}

class PriceSnapshot extends DataClass implements Insertable<PriceSnapshot> {
  final String id;
  final String assetId;
  final DateTime date;
  final String price;
  final String currencyAssetId;
  final String source;
  final bool deleted;
  const PriceSnapshot({
    required this.id,
    required this.assetId,
    required this.date,
    required this.price,
    required this.currencyAssetId,
    required this.source,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['asset_id'] = Variable<String>(assetId);
    map['date'] = Variable<DateTime>(date);
    map['price'] = Variable<String>(price);
    map['currency_asset_id'] = Variable<String>(currencyAssetId);
    map['source'] = Variable<String>(source);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  PriceSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return PriceSnapshotsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      date: Value(date),
      price: Value(price),
      currencyAssetId: Value(currencyAssetId),
      source: Value(source),
      deleted: Value(deleted),
    );
  }

  factory PriceSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PriceSnapshot(
      id: serializer.fromJson<String>(json['id']),
      assetId: serializer.fromJson<String>(json['assetId']),
      date: serializer.fromJson<DateTime>(json['date']),
      price: serializer.fromJson<String>(json['price']),
      currencyAssetId: serializer.fromJson<String>(json['currencyAssetId']),
      source: serializer.fromJson<String>(json['source']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'assetId': serializer.toJson<String>(assetId),
      'date': serializer.toJson<DateTime>(date),
      'price': serializer.toJson<String>(price),
      'currencyAssetId': serializer.toJson<String>(currencyAssetId),
      'source': serializer.toJson<String>(source),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  PriceSnapshot copyWith({
    String? id,
    String? assetId,
    DateTime? date,
    String? price,
    String? currencyAssetId,
    String? source,
    bool? deleted,
  }) => PriceSnapshot(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    date: date ?? this.date,
    price: price ?? this.price,
    currencyAssetId: currencyAssetId ?? this.currencyAssetId,
    source: source ?? this.source,
    deleted: deleted ?? this.deleted,
  );
  PriceSnapshot copyWithCompanion(PriceSnapshotsCompanion data) {
    return PriceSnapshot(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      date: data.date.present ? data.date.value : this.date,
      price: data.price.present ? data.price.value : this.price,
      currencyAssetId: data.currencyAssetId.present
          ? data.currencyAssetId.value
          : this.currencyAssetId,
      source: data.source.present ? data.source.value : this.source,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PriceSnapshot(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('date: $date, ')
          ..write('price: $price, ')
          ..write('currencyAssetId: $currencyAssetId, ')
          ..write('source: $source, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, assetId, date, price, currencyAssetId, source, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceSnapshot &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.date == this.date &&
          other.price == this.price &&
          other.currencyAssetId == this.currencyAssetId &&
          other.source == this.source &&
          other.deleted == this.deleted);
}

class PriceSnapshotsCompanion extends UpdateCompanion<PriceSnapshot> {
  final Value<String> id;
  final Value<String> assetId;
  final Value<DateTime> date;
  final Value<String> price;
  final Value<String> currencyAssetId;
  final Value<String> source;
  final Value<bool> deleted;
  final Value<int> rowid;
  const PriceSnapshotsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.date = const Value.absent(),
    this.price = const Value.absent(),
    this.currencyAssetId = const Value.absent(),
    this.source = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PriceSnapshotsCompanion.insert({
    required String id,
    required String assetId,
    required DateTime date,
    required String price,
    required String currencyAssetId,
    required String source,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       assetId = Value(assetId),
       date = Value(date),
       price = Value(price),
       currencyAssetId = Value(currencyAssetId),
       source = Value(source);
  static Insertable<PriceSnapshot> custom({
    Expression<String>? id,
    Expression<String>? assetId,
    Expression<DateTime>? date,
    Expression<String>? price,
    Expression<String>? currencyAssetId,
    Expression<String>? source,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (date != null) 'date': date,
      if (price != null) 'price': price,
      if (currencyAssetId != null) 'currency_asset_id': currencyAssetId,
      if (source != null) 'source': source,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PriceSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? assetId,
    Value<DateTime>? date,
    Value<String>? price,
    Value<String>? currencyAssetId,
    Value<String>? source,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return PriceSnapshotsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      date: date ?? this.date,
      price: price ?? this.price,
      currencyAssetId: currencyAssetId ?? this.currencyAssetId,
      source: source ?? this.source,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (price.present) {
      map['price'] = Variable<String>(price.value);
    }
    if (currencyAssetId.present) {
      map['currency_asset_id'] = Variable<String>(currencyAssetId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PriceSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('date: $date, ')
          ..write('price: $price, ')
          ..write('currencyAssetId: $currencyAssetId, ')
          ..write('source: $source, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BalanceCheckpointsTable extends BalanceCheckpoints
    with TableInfo<$BalanceCheckpointsTable, BalanceCheckpoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BalanceCheckpointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _containerIdMeta = const VerificationMeta(
    'containerId',
  );
  @override
  late final GeneratedColumn<String> containerId = GeneratedColumn<String>(
    'container_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkpointDateMeta = const VerificationMeta(
    'checkpointDate',
  );
  @override
  late final GeneratedColumn<DateTime> checkpointDate =
      GeneratedColumn<DateTime>(
        'checkpoint_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<String> quantity = GeneratedColumn<String>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    containerId,
    assetId,
    checkpointDate,
    quantity,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'balance_checkpoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<BalanceCheckpoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('container_id')) {
      context.handle(
        _containerIdMeta,
        containerId.isAcceptableOrUnknown(
          data['container_id']!,
          _containerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_containerIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('checkpoint_date')) {
      context.handle(
        _checkpointDateMeta,
        checkpointDate.isAcceptableOrUnknown(
          data['checkpoint_date']!,
          _checkpointDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checkpointDateMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    containerId,
    assetId,
    checkpointDate,
  };
  @override
  BalanceCheckpoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BalanceCheckpoint(
      containerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}container_id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      checkpointDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checkpoint_date'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quantity'],
      )!,
    );
  }

  @override
  $BalanceCheckpointsTable createAlias(String alias) {
    return $BalanceCheckpointsTable(attachedDatabase, alias);
  }
}

class BalanceCheckpoint extends DataClass
    implements Insertable<BalanceCheckpoint> {
  final String containerId;
  final String assetId;
  final DateTime checkpointDate;
  final String quantity;
  const BalanceCheckpoint({
    required this.containerId,
    required this.assetId,
    required this.checkpointDate,
    required this.quantity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['container_id'] = Variable<String>(containerId);
    map['asset_id'] = Variable<String>(assetId);
    map['checkpoint_date'] = Variable<DateTime>(checkpointDate);
    map['quantity'] = Variable<String>(quantity);
    return map;
  }

  BalanceCheckpointsCompanion toCompanion(bool nullToAbsent) {
    return BalanceCheckpointsCompanion(
      containerId: Value(containerId),
      assetId: Value(assetId),
      checkpointDate: Value(checkpointDate),
      quantity: Value(quantity),
    );
  }

  factory BalanceCheckpoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BalanceCheckpoint(
      containerId: serializer.fromJson<String>(json['containerId']),
      assetId: serializer.fromJson<String>(json['assetId']),
      checkpointDate: serializer.fromJson<DateTime>(json['checkpointDate']),
      quantity: serializer.fromJson<String>(json['quantity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'containerId': serializer.toJson<String>(containerId),
      'assetId': serializer.toJson<String>(assetId),
      'checkpointDate': serializer.toJson<DateTime>(checkpointDate),
      'quantity': serializer.toJson<String>(quantity),
    };
  }

  BalanceCheckpoint copyWith({
    String? containerId,
    String? assetId,
    DateTime? checkpointDate,
    String? quantity,
  }) => BalanceCheckpoint(
    containerId: containerId ?? this.containerId,
    assetId: assetId ?? this.assetId,
    checkpointDate: checkpointDate ?? this.checkpointDate,
    quantity: quantity ?? this.quantity,
  );
  BalanceCheckpoint copyWithCompanion(BalanceCheckpointsCompanion data) {
    return BalanceCheckpoint(
      containerId: data.containerId.present
          ? data.containerId.value
          : this.containerId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      checkpointDate: data.checkpointDate.present
          ? data.checkpointDate.value
          : this.checkpointDate,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BalanceCheckpoint(')
          ..write('containerId: $containerId, ')
          ..write('assetId: $assetId, ')
          ..write('checkpointDate: $checkpointDate, ')
          ..write('quantity: $quantity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(containerId, assetId, checkpointDate, quantity);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BalanceCheckpoint &&
          other.containerId == this.containerId &&
          other.assetId == this.assetId &&
          other.checkpointDate == this.checkpointDate &&
          other.quantity == this.quantity);
}

class BalanceCheckpointsCompanion extends UpdateCompanion<BalanceCheckpoint> {
  final Value<String> containerId;
  final Value<String> assetId;
  final Value<DateTime> checkpointDate;
  final Value<String> quantity;
  final Value<int> rowid;
  const BalanceCheckpointsCompanion({
    this.containerId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.checkpointDate = const Value.absent(),
    this.quantity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BalanceCheckpointsCompanion.insert({
    required String containerId,
    required String assetId,
    required DateTime checkpointDate,
    required String quantity,
    this.rowid = const Value.absent(),
  }) : containerId = Value(containerId),
       assetId = Value(assetId),
       checkpointDate = Value(checkpointDate),
       quantity = Value(quantity);
  static Insertable<BalanceCheckpoint> custom({
    Expression<String>? containerId,
    Expression<String>? assetId,
    Expression<DateTime>? checkpointDate,
    Expression<String>? quantity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (containerId != null) 'container_id': containerId,
      if (assetId != null) 'asset_id': assetId,
      if (checkpointDate != null) 'checkpoint_date': checkpointDate,
      if (quantity != null) 'quantity': quantity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BalanceCheckpointsCompanion copyWith({
    Value<String>? containerId,
    Value<String>? assetId,
    Value<DateTime>? checkpointDate,
    Value<String>? quantity,
    Value<int>? rowid,
  }) {
    return BalanceCheckpointsCompanion(
      containerId: containerId ?? this.containerId,
      assetId: assetId ?? this.assetId,
      checkpointDate: checkpointDate ?? this.checkpointDate,
      quantity: quantity ?? this.quantity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (containerId.present) {
      map['container_id'] = Variable<String>(containerId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (checkpointDate.present) {
      map['checkpoint_date'] = Variable<DateTime>(checkpointDate.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(quantity.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BalanceCheckpointsCompanion(')
          ..write('containerId: $containerId, ')
          ..write('assetId: $assetId, ')
          ..write('checkpointDate: $checkpointDate, ')
          ..write('quantity: $quantity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [id, value, deleted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String id;
  final String value;
  final bool deleted;
  const Setting({required this.id, required this.value, required this.deleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['value'] = Variable<String>(value);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      value: Value(value),
      deleted: Value(deleted),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      id: serializer.fromJson<String>(json['id']),
      value: serializer.fromJson<String>(json['value']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'value': serializer.toJson<String>(value),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Setting copyWith({String? id, String? value, bool? deleted}) => Setting(
    id: id ?? this.id,
    value: value ?? this.value,
    deleted: deleted ?? this.deleted,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      id: data.id.present ? data.id.value : this.id,
      value: data.value.present ? data.value.value : this.value,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, value, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.id == this.id &&
          other.value == this.value &&
          other.deleted == this.deleted);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> id;
  final Value<String> value;
  final Value<bool> deleted;
  final Value<int> rowid;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.value = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String id,
    required String value,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? id,
    Expression<String>? value,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (value != null) 'value': value,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? id,
    Value<String>? value,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      value: value ?? this.value,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringTransactionTemplatesTable extends RecurringTransactionTemplates
    with
        TableInfo<
          $RecurringTransactionTemplatesTable,
          RecurringTransactionTemplate
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringTransactionTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _legOutContainerIdMeta = const VerificationMeta(
    'legOutContainerId',
  );
  @override
  late final GeneratedColumn<String> legOutContainerId =
      GeneratedColumn<String>(
        'leg_out_container_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _legOutAssetIdMeta = const VerificationMeta(
    'legOutAssetId',
  );
  @override
  late final GeneratedColumn<String> legOutAssetId = GeneratedColumn<String>(
    'leg_out_asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legOutQuantityMeta = const VerificationMeta(
    'legOutQuantity',
  );
  @override
  late final GeneratedColumn<String> legOutQuantity = GeneratedColumn<String>(
    'leg_out_quantity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legInContainerIdMeta = const VerificationMeta(
    'legInContainerId',
  );
  @override
  late final GeneratedColumn<String> legInContainerId = GeneratedColumn<String>(
    'leg_in_container_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legInAssetIdMeta = const VerificationMeta(
    'legInAssetId',
  );
  @override
  late final GeneratedColumn<String> legInAssetId = GeneratedColumn<String>(
    'leg_in_asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legInQuantityMeta = const VerificationMeta(
    'legInQuantity',
  );
  @override
  late final GeneratedColumn<String> legInQuantity = GeneratedColumn<String>(
    'leg_in_quantity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _budgetLegOutContainerIdMeta =
      const VerificationMeta('budgetLegOutContainerId');
  @override
  late final GeneratedColumn<String> budgetLegOutContainerId =
      GeneratedColumn<String>(
        'budget_leg_out_container_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegOutAssetIdMeta =
      const VerificationMeta('budgetLegOutAssetId');
  @override
  late final GeneratedColumn<String> budgetLegOutAssetId =
      GeneratedColumn<String>(
        'budget_leg_out_asset_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegOutQuantityMeta =
      const VerificationMeta('budgetLegOutQuantity');
  @override
  late final GeneratedColumn<String> budgetLegOutQuantity =
      GeneratedColumn<String>(
        'budget_leg_out_quantity',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegInContainerIdMeta =
      const VerificationMeta('budgetLegInContainerId');
  @override
  late final GeneratedColumn<String> budgetLegInContainerId =
      GeneratedColumn<String>(
        'budget_leg_in_container_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegInAssetIdMeta =
      const VerificationMeta('budgetLegInAssetId');
  @override
  late final GeneratedColumn<String> budgetLegInAssetId =
      GeneratedColumn<String>(
        'budget_leg_in_asset_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _budgetLegInQuantityMeta =
      const VerificationMeta('budgetLegInQuantity');
  @override
  late final GeneratedColumn<String> budgetLegInQuantity =
      GeneratedColumn<String>(
        'budget_leg_in_quantity',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _ruleUnitMeta = const VerificationMeta(
    'ruleUnit',
  );
  @override
  late final GeneratedColumn<String> ruleUnit = GeneratedColumn<String>(
    'rule_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruleIntervalMeta = const VerificationMeta(
    'ruleInterval',
  );
  @override
  late final GeneratedColumn<int> ruleInterval = GeneratedColumn<int>(
    'rule_interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CalendarDate, String>
  ruleStartDate =
      GeneratedColumn<String>(
        'rule_start_date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CalendarDate>(
        $RecurringTransactionTemplatesTable.$converterruleStartDate,
      );
  @override
  late final GeneratedColumnWithTypeConverter<CalendarDate?, String>
  ruleEndDate =
      GeneratedColumn<String>(
        'rule_end_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CalendarDate?>(
        $RecurringTransactionTemplatesTable.$converterruleEndDaten,
      );
  static const VerificationMeta _ruleMaxOccurrencesMeta =
      const VerificationMeta('ruleMaxOccurrences');
  @override
  late final GeneratedColumn<int> ruleMaxOccurrences = GeneratedColumn<int>(
    'rule_max_occurrences',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CalendarDate?, String>
  lastGeneratedOccurrenceDate =
      GeneratedColumn<String>(
        'last_generated_occurrence_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CalendarDate?>(
        $RecurringTransactionTemplatesTable
            .$converterlastGeneratedOccurrenceDaten,
      );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    legOutContainerId,
    legOutAssetId,
    legOutQuantity,
    legInContainerId,
    legInAssetId,
    legInQuantity,
    budgetLegOutContainerId,
    budgetLegOutAssetId,
    budgetLegOutQuantity,
    budgetLegInContainerId,
    budgetLegInAssetId,
    budgetLegInQuantity,
    note,
    tags,
    ruleUnit,
    ruleInterval,
    ruleStartDate,
    ruleEndDate,
    ruleMaxOccurrences,
    lastGeneratedOccurrenceDate,
    active,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_transaction_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringTransactionTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('leg_out_container_id')) {
      context.handle(
        _legOutContainerIdMeta,
        legOutContainerId.isAcceptableOrUnknown(
          data['leg_out_container_id']!,
          _legOutContainerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legOutContainerIdMeta);
    }
    if (data.containsKey('leg_out_asset_id')) {
      context.handle(
        _legOutAssetIdMeta,
        legOutAssetId.isAcceptableOrUnknown(
          data['leg_out_asset_id']!,
          _legOutAssetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legOutAssetIdMeta);
    }
    if (data.containsKey('leg_out_quantity')) {
      context.handle(
        _legOutQuantityMeta,
        legOutQuantity.isAcceptableOrUnknown(
          data['leg_out_quantity']!,
          _legOutQuantityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legOutQuantityMeta);
    }
    if (data.containsKey('leg_in_container_id')) {
      context.handle(
        _legInContainerIdMeta,
        legInContainerId.isAcceptableOrUnknown(
          data['leg_in_container_id']!,
          _legInContainerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legInContainerIdMeta);
    }
    if (data.containsKey('leg_in_asset_id')) {
      context.handle(
        _legInAssetIdMeta,
        legInAssetId.isAcceptableOrUnknown(
          data['leg_in_asset_id']!,
          _legInAssetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legInAssetIdMeta);
    }
    if (data.containsKey('leg_in_quantity')) {
      context.handle(
        _legInQuantityMeta,
        legInQuantity.isAcceptableOrUnknown(
          data['leg_in_quantity']!,
          _legInQuantityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_legInQuantityMeta);
    }
    if (data.containsKey('budget_leg_out_container_id')) {
      context.handle(
        _budgetLegOutContainerIdMeta,
        budgetLegOutContainerId.isAcceptableOrUnknown(
          data['budget_leg_out_container_id']!,
          _budgetLegOutContainerIdMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_out_asset_id')) {
      context.handle(
        _budgetLegOutAssetIdMeta,
        budgetLegOutAssetId.isAcceptableOrUnknown(
          data['budget_leg_out_asset_id']!,
          _budgetLegOutAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_out_quantity')) {
      context.handle(
        _budgetLegOutQuantityMeta,
        budgetLegOutQuantity.isAcceptableOrUnknown(
          data['budget_leg_out_quantity']!,
          _budgetLegOutQuantityMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_in_container_id')) {
      context.handle(
        _budgetLegInContainerIdMeta,
        budgetLegInContainerId.isAcceptableOrUnknown(
          data['budget_leg_in_container_id']!,
          _budgetLegInContainerIdMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_in_asset_id')) {
      context.handle(
        _budgetLegInAssetIdMeta,
        budgetLegInAssetId.isAcceptableOrUnknown(
          data['budget_leg_in_asset_id']!,
          _budgetLegInAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('budget_leg_in_quantity')) {
      context.handle(
        _budgetLegInQuantityMeta,
        budgetLegInQuantity.isAcceptableOrUnknown(
          data['budget_leg_in_quantity']!,
          _budgetLegInQuantityMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('rule_unit')) {
      context.handle(
        _ruleUnitMeta,
        ruleUnit.isAcceptableOrUnknown(data['rule_unit']!, _ruleUnitMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleUnitMeta);
    }
    if (data.containsKey('rule_interval')) {
      context.handle(
        _ruleIntervalMeta,
        ruleInterval.isAcceptableOrUnknown(
          data['rule_interval']!,
          _ruleIntervalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ruleIntervalMeta);
    }
    if (data.containsKey('rule_max_occurrences')) {
      context.handle(
        _ruleMaxOccurrencesMeta,
        ruleMaxOccurrences.isAcceptableOrUnknown(
          data['rule_max_occurrences']!,
          _ruleMaxOccurrencesMeta,
        ),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringTransactionTemplate map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringTransactionTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      legOutContainerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_out_container_id'],
      )!,
      legOutAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_out_asset_id'],
      )!,
      legOutQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_out_quantity'],
      )!,
      legInContainerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_in_container_id'],
      )!,
      legInAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_in_asset_id'],
      )!,
      legInQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_in_quantity'],
      )!,
      budgetLegOutContainerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_out_container_id'],
      ),
      budgetLegOutAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_out_asset_id'],
      ),
      budgetLegOutQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_out_quantity'],
      ),
      budgetLegInContainerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_in_container_id'],
      ),
      budgetLegInAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_in_asset_id'],
      ),
      budgetLegInQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_leg_in_quantity'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      ruleUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_unit'],
      )!,
      ruleInterval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rule_interval'],
      )!,
      ruleStartDate: $RecurringTransactionTemplatesTable.$converterruleStartDate
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}rule_start_date'],
            )!,
          ),
      ruleEndDate: $RecurringTransactionTemplatesTable.$converterruleEndDaten
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}rule_end_date'],
            ),
          ),
      ruleMaxOccurrences: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rule_max_occurrences'],
      ),
      lastGeneratedOccurrenceDate: $RecurringTransactionTemplatesTable
          .$converterlastGeneratedOccurrenceDaten
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}last_generated_occurrence_date'],
            ),
          ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $RecurringTransactionTemplatesTable createAlias(String alias) {
    return $RecurringTransactionTemplatesTable(attachedDatabase, alias);
  }

  static TypeConverter<CalendarDate, String> $converterruleStartDate =
      const CalendarDateConverter();
  static TypeConverter<CalendarDate, String> $converterruleEndDate =
      const CalendarDateConverter();
  static TypeConverter<CalendarDate?, String?> $converterruleEndDaten =
      NullAwareTypeConverter.wrap($converterruleEndDate);
  static TypeConverter<CalendarDate, String>
  $converterlastGeneratedOccurrenceDate = const CalendarDateConverter();
  static TypeConverter<CalendarDate?, String?>
  $converterlastGeneratedOccurrenceDaten = NullAwareTypeConverter.wrap(
    $converterlastGeneratedOccurrenceDate,
  );
}

class RecurringTransactionTemplate extends DataClass
    implements Insertable<RecurringTransactionTemplate> {
  final String id;
  final String kind;
  final String legOutContainerId;
  final String legOutAssetId;
  final String legOutQuantity;
  final String legInContainerId;
  final String legInAssetId;
  final String legInQuantity;
  final String? budgetLegOutContainerId;
  final String? budgetLegOutAssetId;
  final String? budgetLegOutQuantity;
  final String? budgetLegInContainerId;
  final String? budgetLegInAssetId;
  final String? budgetLegInQuantity;
  final String? note;
  final String tags;
  final String ruleUnit;
  final int ruleInterval;
  final CalendarDate ruleStartDate;
  final CalendarDate? ruleEndDate;
  final int? ruleMaxOccurrences;
  final CalendarDate? lastGeneratedOccurrenceDate;
  final bool active;
  final bool deleted;
  const RecurringTransactionTemplate({
    required this.id,
    required this.kind,
    required this.legOutContainerId,
    required this.legOutAssetId,
    required this.legOutQuantity,
    required this.legInContainerId,
    required this.legInAssetId,
    required this.legInQuantity,
    this.budgetLegOutContainerId,
    this.budgetLegOutAssetId,
    this.budgetLegOutQuantity,
    this.budgetLegInContainerId,
    this.budgetLegInAssetId,
    this.budgetLegInQuantity,
    this.note,
    required this.tags,
    required this.ruleUnit,
    required this.ruleInterval,
    required this.ruleStartDate,
    this.ruleEndDate,
    this.ruleMaxOccurrences,
    this.lastGeneratedOccurrenceDate,
    required this.active,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['leg_out_container_id'] = Variable<String>(legOutContainerId);
    map['leg_out_asset_id'] = Variable<String>(legOutAssetId);
    map['leg_out_quantity'] = Variable<String>(legOutQuantity);
    map['leg_in_container_id'] = Variable<String>(legInContainerId);
    map['leg_in_asset_id'] = Variable<String>(legInAssetId);
    map['leg_in_quantity'] = Variable<String>(legInQuantity);
    if (!nullToAbsent || budgetLegOutContainerId != null) {
      map['budget_leg_out_container_id'] = Variable<String>(
        budgetLegOutContainerId,
      );
    }
    if (!nullToAbsent || budgetLegOutAssetId != null) {
      map['budget_leg_out_asset_id'] = Variable<String>(budgetLegOutAssetId);
    }
    if (!nullToAbsent || budgetLegOutQuantity != null) {
      map['budget_leg_out_quantity'] = Variable<String>(budgetLegOutQuantity);
    }
    if (!nullToAbsent || budgetLegInContainerId != null) {
      map['budget_leg_in_container_id'] = Variable<String>(
        budgetLegInContainerId,
      );
    }
    if (!nullToAbsent || budgetLegInAssetId != null) {
      map['budget_leg_in_asset_id'] = Variable<String>(budgetLegInAssetId);
    }
    if (!nullToAbsent || budgetLegInQuantity != null) {
      map['budget_leg_in_quantity'] = Variable<String>(budgetLegInQuantity);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['tags'] = Variable<String>(tags);
    map['rule_unit'] = Variable<String>(ruleUnit);
    map['rule_interval'] = Variable<int>(ruleInterval);
    {
      map['rule_start_date'] = Variable<String>(
        $RecurringTransactionTemplatesTable.$converterruleStartDate.toSql(
          ruleStartDate,
        ),
      );
    }
    if (!nullToAbsent || ruleEndDate != null) {
      map['rule_end_date'] = Variable<String>(
        $RecurringTransactionTemplatesTable.$converterruleEndDaten.toSql(
          ruleEndDate,
        ),
      );
    }
    if (!nullToAbsent || ruleMaxOccurrences != null) {
      map['rule_max_occurrences'] = Variable<int>(ruleMaxOccurrences);
    }
    if (!nullToAbsent || lastGeneratedOccurrenceDate != null) {
      map['last_generated_occurrence_date'] = Variable<String>(
        $RecurringTransactionTemplatesTable
            .$converterlastGeneratedOccurrenceDaten
            .toSql(lastGeneratedOccurrenceDate),
      );
    }
    map['active'] = Variable<bool>(active);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  RecurringTransactionTemplatesCompanion toCompanion(bool nullToAbsent) {
    return RecurringTransactionTemplatesCompanion(
      id: Value(id),
      kind: Value(kind),
      legOutContainerId: Value(legOutContainerId),
      legOutAssetId: Value(legOutAssetId),
      legOutQuantity: Value(legOutQuantity),
      legInContainerId: Value(legInContainerId),
      legInAssetId: Value(legInAssetId),
      legInQuantity: Value(legInQuantity),
      budgetLegOutContainerId: budgetLegOutContainerId == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegOutContainerId),
      budgetLegOutAssetId: budgetLegOutAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegOutAssetId),
      budgetLegOutQuantity: budgetLegOutQuantity == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegOutQuantity),
      budgetLegInContainerId: budgetLegInContainerId == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegInContainerId),
      budgetLegInAssetId: budgetLegInAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegInAssetId),
      budgetLegInQuantity: budgetLegInQuantity == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLegInQuantity),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      tags: Value(tags),
      ruleUnit: Value(ruleUnit),
      ruleInterval: Value(ruleInterval),
      ruleStartDate: Value(ruleStartDate),
      ruleEndDate: ruleEndDate == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleEndDate),
      ruleMaxOccurrences: ruleMaxOccurrences == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleMaxOccurrences),
      lastGeneratedOccurrenceDate:
          lastGeneratedOccurrenceDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastGeneratedOccurrenceDate),
      active: Value(active),
      deleted: Value(deleted),
    );
  }

  factory RecurringTransactionTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringTransactionTemplate(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      legOutContainerId: serializer.fromJson<String>(json['legOutContainerId']),
      legOutAssetId: serializer.fromJson<String>(json['legOutAssetId']),
      legOutQuantity: serializer.fromJson<String>(json['legOutQuantity']),
      legInContainerId: serializer.fromJson<String>(json['legInContainerId']),
      legInAssetId: serializer.fromJson<String>(json['legInAssetId']),
      legInQuantity: serializer.fromJson<String>(json['legInQuantity']),
      budgetLegOutContainerId: serializer.fromJson<String?>(
        json['budgetLegOutContainerId'],
      ),
      budgetLegOutAssetId: serializer.fromJson<String?>(
        json['budgetLegOutAssetId'],
      ),
      budgetLegOutQuantity: serializer.fromJson<String?>(
        json['budgetLegOutQuantity'],
      ),
      budgetLegInContainerId: serializer.fromJson<String?>(
        json['budgetLegInContainerId'],
      ),
      budgetLegInAssetId: serializer.fromJson<String?>(
        json['budgetLegInAssetId'],
      ),
      budgetLegInQuantity: serializer.fromJson<String?>(
        json['budgetLegInQuantity'],
      ),
      note: serializer.fromJson<String?>(json['note']),
      tags: serializer.fromJson<String>(json['tags']),
      ruleUnit: serializer.fromJson<String>(json['ruleUnit']),
      ruleInterval: serializer.fromJson<int>(json['ruleInterval']),
      ruleStartDate: serializer.fromJson<CalendarDate>(json['ruleStartDate']),
      ruleEndDate: serializer.fromJson<CalendarDate?>(json['ruleEndDate']),
      ruleMaxOccurrences: serializer.fromJson<int?>(json['ruleMaxOccurrences']),
      lastGeneratedOccurrenceDate: serializer.fromJson<CalendarDate?>(
        json['lastGeneratedOccurrenceDate'],
      ),
      active: serializer.fromJson<bool>(json['active']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'legOutContainerId': serializer.toJson<String>(legOutContainerId),
      'legOutAssetId': serializer.toJson<String>(legOutAssetId),
      'legOutQuantity': serializer.toJson<String>(legOutQuantity),
      'legInContainerId': serializer.toJson<String>(legInContainerId),
      'legInAssetId': serializer.toJson<String>(legInAssetId),
      'legInQuantity': serializer.toJson<String>(legInQuantity),
      'budgetLegOutContainerId': serializer.toJson<String?>(
        budgetLegOutContainerId,
      ),
      'budgetLegOutAssetId': serializer.toJson<String?>(budgetLegOutAssetId),
      'budgetLegOutQuantity': serializer.toJson<String?>(budgetLegOutQuantity),
      'budgetLegInContainerId': serializer.toJson<String?>(
        budgetLegInContainerId,
      ),
      'budgetLegInAssetId': serializer.toJson<String?>(budgetLegInAssetId),
      'budgetLegInQuantity': serializer.toJson<String?>(budgetLegInQuantity),
      'note': serializer.toJson<String?>(note),
      'tags': serializer.toJson<String>(tags),
      'ruleUnit': serializer.toJson<String>(ruleUnit),
      'ruleInterval': serializer.toJson<int>(ruleInterval),
      'ruleStartDate': serializer.toJson<CalendarDate>(ruleStartDate),
      'ruleEndDate': serializer.toJson<CalendarDate?>(ruleEndDate),
      'ruleMaxOccurrences': serializer.toJson<int?>(ruleMaxOccurrences),
      'lastGeneratedOccurrenceDate': serializer.toJson<CalendarDate?>(
        lastGeneratedOccurrenceDate,
      ),
      'active': serializer.toJson<bool>(active),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  RecurringTransactionTemplate copyWith({
    String? id,
    String? kind,
    String? legOutContainerId,
    String? legOutAssetId,
    String? legOutQuantity,
    String? legInContainerId,
    String? legInAssetId,
    String? legInQuantity,
    Value<String?> budgetLegOutContainerId = const Value.absent(),
    Value<String?> budgetLegOutAssetId = const Value.absent(),
    Value<String?> budgetLegOutQuantity = const Value.absent(),
    Value<String?> budgetLegInContainerId = const Value.absent(),
    Value<String?> budgetLegInAssetId = const Value.absent(),
    Value<String?> budgetLegInQuantity = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? tags,
    String? ruleUnit,
    int? ruleInterval,
    CalendarDate? ruleStartDate,
    Value<CalendarDate?> ruleEndDate = const Value.absent(),
    Value<int?> ruleMaxOccurrences = const Value.absent(),
    Value<CalendarDate?> lastGeneratedOccurrenceDate = const Value.absent(),
    bool? active,
    bool? deleted,
  }) => RecurringTransactionTemplate(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    legOutContainerId: legOutContainerId ?? this.legOutContainerId,
    legOutAssetId: legOutAssetId ?? this.legOutAssetId,
    legOutQuantity: legOutQuantity ?? this.legOutQuantity,
    legInContainerId: legInContainerId ?? this.legInContainerId,
    legInAssetId: legInAssetId ?? this.legInAssetId,
    legInQuantity: legInQuantity ?? this.legInQuantity,
    budgetLegOutContainerId: budgetLegOutContainerId.present
        ? budgetLegOutContainerId.value
        : this.budgetLegOutContainerId,
    budgetLegOutAssetId: budgetLegOutAssetId.present
        ? budgetLegOutAssetId.value
        : this.budgetLegOutAssetId,
    budgetLegOutQuantity: budgetLegOutQuantity.present
        ? budgetLegOutQuantity.value
        : this.budgetLegOutQuantity,
    budgetLegInContainerId: budgetLegInContainerId.present
        ? budgetLegInContainerId.value
        : this.budgetLegInContainerId,
    budgetLegInAssetId: budgetLegInAssetId.present
        ? budgetLegInAssetId.value
        : this.budgetLegInAssetId,
    budgetLegInQuantity: budgetLegInQuantity.present
        ? budgetLegInQuantity.value
        : this.budgetLegInQuantity,
    note: note.present ? note.value : this.note,
    tags: tags ?? this.tags,
    ruleUnit: ruleUnit ?? this.ruleUnit,
    ruleInterval: ruleInterval ?? this.ruleInterval,
    ruleStartDate: ruleStartDate ?? this.ruleStartDate,
    ruleEndDate: ruleEndDate.present ? ruleEndDate.value : this.ruleEndDate,
    ruleMaxOccurrences: ruleMaxOccurrences.present
        ? ruleMaxOccurrences.value
        : this.ruleMaxOccurrences,
    lastGeneratedOccurrenceDate: lastGeneratedOccurrenceDate.present
        ? lastGeneratedOccurrenceDate.value
        : this.lastGeneratedOccurrenceDate,
    active: active ?? this.active,
    deleted: deleted ?? this.deleted,
  );
  RecurringTransactionTemplate copyWithCompanion(
    RecurringTransactionTemplatesCompanion data,
  ) {
    return RecurringTransactionTemplate(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      legOutContainerId: data.legOutContainerId.present
          ? data.legOutContainerId.value
          : this.legOutContainerId,
      legOutAssetId: data.legOutAssetId.present
          ? data.legOutAssetId.value
          : this.legOutAssetId,
      legOutQuantity: data.legOutQuantity.present
          ? data.legOutQuantity.value
          : this.legOutQuantity,
      legInContainerId: data.legInContainerId.present
          ? data.legInContainerId.value
          : this.legInContainerId,
      legInAssetId: data.legInAssetId.present
          ? data.legInAssetId.value
          : this.legInAssetId,
      legInQuantity: data.legInQuantity.present
          ? data.legInQuantity.value
          : this.legInQuantity,
      budgetLegOutContainerId: data.budgetLegOutContainerId.present
          ? data.budgetLegOutContainerId.value
          : this.budgetLegOutContainerId,
      budgetLegOutAssetId: data.budgetLegOutAssetId.present
          ? data.budgetLegOutAssetId.value
          : this.budgetLegOutAssetId,
      budgetLegOutQuantity: data.budgetLegOutQuantity.present
          ? data.budgetLegOutQuantity.value
          : this.budgetLegOutQuantity,
      budgetLegInContainerId: data.budgetLegInContainerId.present
          ? data.budgetLegInContainerId.value
          : this.budgetLegInContainerId,
      budgetLegInAssetId: data.budgetLegInAssetId.present
          ? data.budgetLegInAssetId.value
          : this.budgetLegInAssetId,
      budgetLegInQuantity: data.budgetLegInQuantity.present
          ? data.budgetLegInQuantity.value
          : this.budgetLegInQuantity,
      note: data.note.present ? data.note.value : this.note,
      tags: data.tags.present ? data.tags.value : this.tags,
      ruleUnit: data.ruleUnit.present ? data.ruleUnit.value : this.ruleUnit,
      ruleInterval: data.ruleInterval.present
          ? data.ruleInterval.value
          : this.ruleInterval,
      ruleStartDate: data.ruleStartDate.present
          ? data.ruleStartDate.value
          : this.ruleStartDate,
      ruleEndDate: data.ruleEndDate.present
          ? data.ruleEndDate.value
          : this.ruleEndDate,
      ruleMaxOccurrences: data.ruleMaxOccurrences.present
          ? data.ruleMaxOccurrences.value
          : this.ruleMaxOccurrences,
      lastGeneratedOccurrenceDate: data.lastGeneratedOccurrenceDate.present
          ? data.lastGeneratedOccurrenceDate.value
          : this.lastGeneratedOccurrenceDate,
      active: data.active.present ? data.active.value : this.active,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTransactionTemplate(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('legOutContainerId: $legOutContainerId, ')
          ..write('legOutAssetId: $legOutAssetId, ')
          ..write('legOutQuantity: $legOutQuantity, ')
          ..write('legInContainerId: $legInContainerId, ')
          ..write('legInAssetId: $legInAssetId, ')
          ..write('legInQuantity: $legInQuantity, ')
          ..write('budgetLegOutContainerId: $budgetLegOutContainerId, ')
          ..write('budgetLegOutAssetId: $budgetLegOutAssetId, ')
          ..write('budgetLegOutQuantity: $budgetLegOutQuantity, ')
          ..write('budgetLegInContainerId: $budgetLegInContainerId, ')
          ..write('budgetLegInAssetId: $budgetLegInAssetId, ')
          ..write('budgetLegInQuantity: $budgetLegInQuantity, ')
          ..write('note: $note, ')
          ..write('tags: $tags, ')
          ..write('ruleUnit: $ruleUnit, ')
          ..write('ruleInterval: $ruleInterval, ')
          ..write('ruleStartDate: $ruleStartDate, ')
          ..write('ruleEndDate: $ruleEndDate, ')
          ..write('ruleMaxOccurrences: $ruleMaxOccurrences, ')
          ..write('lastGeneratedOccurrenceDate: $lastGeneratedOccurrenceDate, ')
          ..write('active: $active, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    kind,
    legOutContainerId,
    legOutAssetId,
    legOutQuantity,
    legInContainerId,
    legInAssetId,
    legInQuantity,
    budgetLegOutContainerId,
    budgetLegOutAssetId,
    budgetLegOutQuantity,
    budgetLegInContainerId,
    budgetLegInAssetId,
    budgetLegInQuantity,
    note,
    tags,
    ruleUnit,
    ruleInterval,
    ruleStartDate,
    ruleEndDate,
    ruleMaxOccurrences,
    lastGeneratedOccurrenceDate,
    active,
    deleted,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringTransactionTemplate &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.legOutContainerId == this.legOutContainerId &&
          other.legOutAssetId == this.legOutAssetId &&
          other.legOutQuantity == this.legOutQuantity &&
          other.legInContainerId == this.legInContainerId &&
          other.legInAssetId == this.legInAssetId &&
          other.legInQuantity == this.legInQuantity &&
          other.budgetLegOutContainerId == this.budgetLegOutContainerId &&
          other.budgetLegOutAssetId == this.budgetLegOutAssetId &&
          other.budgetLegOutQuantity == this.budgetLegOutQuantity &&
          other.budgetLegInContainerId == this.budgetLegInContainerId &&
          other.budgetLegInAssetId == this.budgetLegInAssetId &&
          other.budgetLegInQuantity == this.budgetLegInQuantity &&
          other.note == this.note &&
          other.tags == this.tags &&
          other.ruleUnit == this.ruleUnit &&
          other.ruleInterval == this.ruleInterval &&
          other.ruleStartDate == this.ruleStartDate &&
          other.ruleEndDate == this.ruleEndDate &&
          other.ruleMaxOccurrences == this.ruleMaxOccurrences &&
          other.lastGeneratedOccurrenceDate ==
              this.lastGeneratedOccurrenceDate &&
          other.active == this.active &&
          other.deleted == this.deleted);
}

class RecurringTransactionTemplatesCompanion
    extends UpdateCompanion<RecurringTransactionTemplate> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> legOutContainerId;
  final Value<String> legOutAssetId;
  final Value<String> legOutQuantity;
  final Value<String> legInContainerId;
  final Value<String> legInAssetId;
  final Value<String> legInQuantity;
  final Value<String?> budgetLegOutContainerId;
  final Value<String?> budgetLegOutAssetId;
  final Value<String?> budgetLegOutQuantity;
  final Value<String?> budgetLegInContainerId;
  final Value<String?> budgetLegInAssetId;
  final Value<String?> budgetLegInQuantity;
  final Value<String?> note;
  final Value<String> tags;
  final Value<String> ruleUnit;
  final Value<int> ruleInterval;
  final Value<CalendarDate> ruleStartDate;
  final Value<CalendarDate?> ruleEndDate;
  final Value<int?> ruleMaxOccurrences;
  final Value<CalendarDate?> lastGeneratedOccurrenceDate;
  final Value<bool> active;
  final Value<bool> deleted;
  final Value<int> rowid;
  const RecurringTransactionTemplatesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.legOutContainerId = const Value.absent(),
    this.legOutAssetId = const Value.absent(),
    this.legOutQuantity = const Value.absent(),
    this.legInContainerId = const Value.absent(),
    this.legInAssetId = const Value.absent(),
    this.legInQuantity = const Value.absent(),
    this.budgetLegOutContainerId = const Value.absent(),
    this.budgetLegOutAssetId = const Value.absent(),
    this.budgetLegOutQuantity = const Value.absent(),
    this.budgetLegInContainerId = const Value.absent(),
    this.budgetLegInAssetId = const Value.absent(),
    this.budgetLegInQuantity = const Value.absent(),
    this.note = const Value.absent(),
    this.tags = const Value.absent(),
    this.ruleUnit = const Value.absent(),
    this.ruleInterval = const Value.absent(),
    this.ruleStartDate = const Value.absent(),
    this.ruleEndDate = const Value.absent(),
    this.ruleMaxOccurrences = const Value.absent(),
    this.lastGeneratedOccurrenceDate = const Value.absent(),
    this.active = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurringTransactionTemplatesCompanion.insert({
    required String id,
    required String kind,
    required String legOutContainerId,
    required String legOutAssetId,
    required String legOutQuantity,
    required String legInContainerId,
    required String legInAssetId,
    required String legInQuantity,
    this.budgetLegOutContainerId = const Value.absent(),
    this.budgetLegOutAssetId = const Value.absent(),
    this.budgetLegOutQuantity = const Value.absent(),
    this.budgetLegInContainerId = const Value.absent(),
    this.budgetLegInAssetId = const Value.absent(),
    this.budgetLegInQuantity = const Value.absent(),
    this.note = const Value.absent(),
    this.tags = const Value.absent(),
    required String ruleUnit,
    required int ruleInterval,
    required CalendarDate ruleStartDate,
    this.ruleEndDate = const Value.absent(),
    this.ruleMaxOccurrences = const Value.absent(),
    this.lastGeneratedOccurrenceDate = const Value.absent(),
    this.active = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       legOutContainerId = Value(legOutContainerId),
       legOutAssetId = Value(legOutAssetId),
       legOutQuantity = Value(legOutQuantity),
       legInContainerId = Value(legInContainerId),
       legInAssetId = Value(legInAssetId),
       legInQuantity = Value(legInQuantity),
       ruleUnit = Value(ruleUnit),
       ruleInterval = Value(ruleInterval),
       ruleStartDate = Value(ruleStartDate);
  static Insertable<RecurringTransactionTemplate> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? legOutContainerId,
    Expression<String>? legOutAssetId,
    Expression<String>? legOutQuantity,
    Expression<String>? legInContainerId,
    Expression<String>? legInAssetId,
    Expression<String>? legInQuantity,
    Expression<String>? budgetLegOutContainerId,
    Expression<String>? budgetLegOutAssetId,
    Expression<String>? budgetLegOutQuantity,
    Expression<String>? budgetLegInContainerId,
    Expression<String>? budgetLegInAssetId,
    Expression<String>? budgetLegInQuantity,
    Expression<String>? note,
    Expression<String>? tags,
    Expression<String>? ruleUnit,
    Expression<int>? ruleInterval,
    Expression<String>? ruleStartDate,
    Expression<String>? ruleEndDate,
    Expression<int>? ruleMaxOccurrences,
    Expression<String>? lastGeneratedOccurrenceDate,
    Expression<bool>? active,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (legOutContainerId != null) 'leg_out_container_id': legOutContainerId,
      if (legOutAssetId != null) 'leg_out_asset_id': legOutAssetId,
      if (legOutQuantity != null) 'leg_out_quantity': legOutQuantity,
      if (legInContainerId != null) 'leg_in_container_id': legInContainerId,
      if (legInAssetId != null) 'leg_in_asset_id': legInAssetId,
      if (legInQuantity != null) 'leg_in_quantity': legInQuantity,
      if (budgetLegOutContainerId != null)
        'budget_leg_out_container_id': budgetLegOutContainerId,
      if (budgetLegOutAssetId != null)
        'budget_leg_out_asset_id': budgetLegOutAssetId,
      if (budgetLegOutQuantity != null)
        'budget_leg_out_quantity': budgetLegOutQuantity,
      if (budgetLegInContainerId != null)
        'budget_leg_in_container_id': budgetLegInContainerId,
      if (budgetLegInAssetId != null)
        'budget_leg_in_asset_id': budgetLegInAssetId,
      if (budgetLegInQuantity != null)
        'budget_leg_in_quantity': budgetLegInQuantity,
      if (note != null) 'note': note,
      if (tags != null) 'tags': tags,
      if (ruleUnit != null) 'rule_unit': ruleUnit,
      if (ruleInterval != null) 'rule_interval': ruleInterval,
      if (ruleStartDate != null) 'rule_start_date': ruleStartDate,
      if (ruleEndDate != null) 'rule_end_date': ruleEndDate,
      if (ruleMaxOccurrences != null)
        'rule_max_occurrences': ruleMaxOccurrences,
      if (lastGeneratedOccurrenceDate != null)
        'last_generated_occurrence_date': lastGeneratedOccurrenceDate,
      if (active != null) 'active': active,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurringTransactionTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? legOutContainerId,
    Value<String>? legOutAssetId,
    Value<String>? legOutQuantity,
    Value<String>? legInContainerId,
    Value<String>? legInAssetId,
    Value<String>? legInQuantity,
    Value<String?>? budgetLegOutContainerId,
    Value<String?>? budgetLegOutAssetId,
    Value<String?>? budgetLegOutQuantity,
    Value<String?>? budgetLegInContainerId,
    Value<String?>? budgetLegInAssetId,
    Value<String?>? budgetLegInQuantity,
    Value<String?>? note,
    Value<String>? tags,
    Value<String>? ruleUnit,
    Value<int>? ruleInterval,
    Value<CalendarDate>? ruleStartDate,
    Value<CalendarDate?>? ruleEndDate,
    Value<int?>? ruleMaxOccurrences,
    Value<CalendarDate?>? lastGeneratedOccurrenceDate,
    Value<bool>? active,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return RecurringTransactionTemplatesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      legOutContainerId: legOutContainerId ?? this.legOutContainerId,
      legOutAssetId: legOutAssetId ?? this.legOutAssetId,
      legOutQuantity: legOutQuantity ?? this.legOutQuantity,
      legInContainerId: legInContainerId ?? this.legInContainerId,
      legInAssetId: legInAssetId ?? this.legInAssetId,
      legInQuantity: legInQuantity ?? this.legInQuantity,
      budgetLegOutContainerId:
          budgetLegOutContainerId ?? this.budgetLegOutContainerId,
      budgetLegOutAssetId: budgetLegOutAssetId ?? this.budgetLegOutAssetId,
      budgetLegOutQuantity: budgetLegOutQuantity ?? this.budgetLegOutQuantity,
      budgetLegInContainerId:
          budgetLegInContainerId ?? this.budgetLegInContainerId,
      budgetLegInAssetId: budgetLegInAssetId ?? this.budgetLegInAssetId,
      budgetLegInQuantity: budgetLegInQuantity ?? this.budgetLegInQuantity,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      ruleUnit: ruleUnit ?? this.ruleUnit,
      ruleInterval: ruleInterval ?? this.ruleInterval,
      ruleStartDate: ruleStartDate ?? this.ruleStartDate,
      ruleEndDate: ruleEndDate ?? this.ruleEndDate,
      ruleMaxOccurrences: ruleMaxOccurrences ?? this.ruleMaxOccurrences,
      lastGeneratedOccurrenceDate:
          lastGeneratedOccurrenceDate ?? this.lastGeneratedOccurrenceDate,
      active: active ?? this.active,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (legOutContainerId.present) {
      map['leg_out_container_id'] = Variable<String>(legOutContainerId.value);
    }
    if (legOutAssetId.present) {
      map['leg_out_asset_id'] = Variable<String>(legOutAssetId.value);
    }
    if (legOutQuantity.present) {
      map['leg_out_quantity'] = Variable<String>(legOutQuantity.value);
    }
    if (legInContainerId.present) {
      map['leg_in_container_id'] = Variable<String>(legInContainerId.value);
    }
    if (legInAssetId.present) {
      map['leg_in_asset_id'] = Variable<String>(legInAssetId.value);
    }
    if (legInQuantity.present) {
      map['leg_in_quantity'] = Variable<String>(legInQuantity.value);
    }
    if (budgetLegOutContainerId.present) {
      map['budget_leg_out_container_id'] = Variable<String>(
        budgetLegOutContainerId.value,
      );
    }
    if (budgetLegOutAssetId.present) {
      map['budget_leg_out_asset_id'] = Variable<String>(
        budgetLegOutAssetId.value,
      );
    }
    if (budgetLegOutQuantity.present) {
      map['budget_leg_out_quantity'] = Variable<String>(
        budgetLegOutQuantity.value,
      );
    }
    if (budgetLegInContainerId.present) {
      map['budget_leg_in_container_id'] = Variable<String>(
        budgetLegInContainerId.value,
      );
    }
    if (budgetLegInAssetId.present) {
      map['budget_leg_in_asset_id'] = Variable<String>(
        budgetLegInAssetId.value,
      );
    }
    if (budgetLegInQuantity.present) {
      map['budget_leg_in_quantity'] = Variable<String>(
        budgetLegInQuantity.value,
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (ruleUnit.present) {
      map['rule_unit'] = Variable<String>(ruleUnit.value);
    }
    if (ruleInterval.present) {
      map['rule_interval'] = Variable<int>(ruleInterval.value);
    }
    if (ruleStartDate.present) {
      map['rule_start_date'] = Variable<String>(
        $RecurringTransactionTemplatesTable.$converterruleStartDate.toSql(
          ruleStartDate.value,
        ),
      );
    }
    if (ruleEndDate.present) {
      map['rule_end_date'] = Variable<String>(
        $RecurringTransactionTemplatesTable.$converterruleEndDaten.toSql(
          ruleEndDate.value,
        ),
      );
    }
    if (ruleMaxOccurrences.present) {
      map['rule_max_occurrences'] = Variable<int>(ruleMaxOccurrences.value);
    }
    if (lastGeneratedOccurrenceDate.present) {
      map['last_generated_occurrence_date'] = Variable<String>(
        $RecurringTransactionTemplatesTable
            .$converterlastGeneratedOccurrenceDaten
            .toSql(lastGeneratedOccurrenceDate.value),
      );
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTransactionTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('legOutContainerId: $legOutContainerId, ')
          ..write('legOutAssetId: $legOutAssetId, ')
          ..write('legOutQuantity: $legOutQuantity, ')
          ..write('legInContainerId: $legInContainerId, ')
          ..write('legInAssetId: $legInAssetId, ')
          ..write('legInQuantity: $legInQuantity, ')
          ..write('budgetLegOutContainerId: $budgetLegOutContainerId, ')
          ..write('budgetLegOutAssetId: $budgetLegOutAssetId, ')
          ..write('budgetLegOutQuantity: $budgetLegOutQuantity, ')
          ..write('budgetLegInContainerId: $budgetLegInContainerId, ')
          ..write('budgetLegInAssetId: $budgetLegInAssetId, ')
          ..write('budgetLegInQuantity: $budgetLegInQuantity, ')
          ..write('note: $note, ')
          ..write('tags: $tags, ')
          ..write('ruleUnit: $ruleUnit, ')
          ..write('ruleInterval: $ruleInterval, ')
          ..write('ruleStartDate: $ruleStartDate, ')
          ..write('ruleEndDate: $ruleEndDate, ')
          ..write('ruleMaxOccurrences: $ruleMaxOccurrences, ')
          ..write('lastGeneratedOccurrenceDate: $lastGeneratedOccurrenceDate, ')
          ..write('active: $active, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DomainCacheDatabase extends GeneratedDatabase {
  _$DomainCacheDatabase(QueryExecutor e) : super(e);
  $DomainCacheDatabaseManager get managers => $DomainCacheDatabaseManager(this);
  late final $AssetsTable assets = $AssetsTable(this);
  late final $ContainersTable containers = $ContainersTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $PriceSnapshotsTable priceSnapshots = $PriceSnapshotsTable(this);
  late final $BalanceCheckpointsTable balanceCheckpoints =
      $BalanceCheckpointsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $RecurringTransactionTemplatesTable recurringTransactionTemplates =
      $RecurringTransactionTemplatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    assets,
    containers,
    transactions,
    priceSnapshots,
    balanceCheckpoints,
    settings,
    recurringTransactionTemplates,
  ];
}

typedef $$AssetsTableCreateCompanionBuilder =
    AssetsCompanion Function({
      required String id,
      required String kind,
      required String symbol,
      required String name,
      Value<String?> alphaVantageSymbol,
      Value<String?> displaySymbol,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$AssetsTableUpdateCompanionBuilder =
    AssetsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> symbol,
      Value<String> name,
      Value<String?> alphaVantageSymbol,
      Value<String?> displaySymbol,
      Value<bool> deleted,
      Value<int> rowid,
    });

class $$AssetsTableFilterComposer
    extends Composer<_$DomainCacheDatabase, $AssetsTable> {
  $$AssetsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alphaVantageSymbol => $composableBuilder(
    column: $table.alphaVantageSymbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displaySymbol => $composableBuilder(
    column: $table.displaySymbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AssetsTableOrderingComposer
    extends Composer<_$DomainCacheDatabase, $AssetsTable> {
  $$AssetsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alphaVantageSymbol => $composableBuilder(
    column: $table.alphaVantageSymbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displaySymbol => $composableBuilder(
    column: $table.displaySymbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssetsTableAnnotationComposer
    extends Composer<_$DomainCacheDatabase, $AssetsTable> {
  $$AssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get alphaVantageSymbol => $composableBuilder(
    column: $table.alphaVantageSymbol,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displaySymbol => $composableBuilder(
    column: $table.displaySymbol,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$AssetsTableTableManager
    extends
        RootTableManager<
          _$DomainCacheDatabase,
          $AssetsTable,
          Asset,
          $$AssetsTableFilterComposer,
          $$AssetsTableOrderingComposer,
          $$AssetsTableAnnotationComposer,
          $$AssetsTableCreateCompanionBuilder,
          $$AssetsTableUpdateCompanionBuilder,
          (Asset, BaseReferences<_$DomainCacheDatabase, $AssetsTable, Asset>),
          Asset,
          PrefetchHooks Function()
        > {
  $$AssetsTableTableManager(_$DomainCacheDatabase db, $AssetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> alphaVantageSymbol = const Value.absent(),
                Value<String?> displaySymbol = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetsCompanion(
                id: id,
                kind: kind,
                symbol: symbol,
                name: name,
                alphaVantageSymbol: alphaVantageSymbol,
                displaySymbol: displaySymbol,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String symbol,
                required String name,
                Value<String?> alphaVantageSymbol = const Value.absent(),
                Value<String?> displaySymbol = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetsCompanion.insert(
                id: id,
                kind: kind,
                symbol: symbol,
                name: name,
                alphaVantageSymbol: alphaVantageSymbol,
                displaySymbol: displaySymbol,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AssetsTable, Asset>(table),
                  BaseReferences<_$DomainCacheDatabase, $AssetsTable, Asset>(
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

typedef $$AssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$DomainCacheDatabase,
      $AssetsTable,
      Asset,
      $$AssetsTableFilterComposer,
      $$AssetsTableOrderingComposer,
      $$AssetsTableAnnotationComposer,
      $$AssetsTableCreateCompanionBuilder,
      $$AssetsTableUpdateCompanionBuilder,
      (Asset, BaseReferences<_$DomainCacheDatabase, $AssetsTable, Asset>),
      Asset,
      PrefetchHooks Function()
    >;
typedef $$ContainersTableCreateCompanionBuilder =
    ContainersCompanion Function({
      required String id,
      required String name,
      required String containerType,
      Value<String?> parentId,
      Value<String?> icon,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$ContainersTableUpdateCompanionBuilder =
    ContainersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> containerType,
      Value<String?> parentId,
      Value<String?> icon,
      Value<bool> deleted,
      Value<int> rowid,
    });

class $$ContainersTableFilterComposer
    extends Composer<_$DomainCacheDatabase, $ContainersTable> {
  $$ContainersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get containerType => $composableBuilder(
    column: $table.containerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContainersTableOrderingComposer
    extends Composer<_$DomainCacheDatabase, $ContainersTable> {
  $$ContainersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get containerType => $composableBuilder(
    column: $table.containerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContainersTableAnnotationComposer
    extends Composer<_$DomainCacheDatabase, $ContainersTable> {
  $$ContainersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get containerType => $composableBuilder(
    column: $table.containerType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$ContainersTableTableManager
    extends
        RootTableManager<
          _$DomainCacheDatabase,
          $ContainersTable,
          Container,
          $$ContainersTableFilterComposer,
          $$ContainersTableOrderingComposer,
          $$ContainersTableAnnotationComposer,
          $$ContainersTableCreateCompanionBuilder,
          $$ContainersTableUpdateCompanionBuilder,
          (
            Container,
            BaseReferences<_$DomainCacheDatabase, $ContainersTable, Container>,
          ),
          Container,
          PrefetchHooks Function()
        > {
  $$ContainersTableTableManager(
    _$DomainCacheDatabase db,
    $ContainersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContainersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContainersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContainersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> containerType = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContainersCompanion(
                id: id,
                name: name,
                containerType: containerType,
                parentId: parentId,
                icon: icon,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String containerType,
                Value<String?> parentId = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContainersCompanion.insert(
                id: id,
                name: name,
                containerType: containerType,
                parentId: parentId,
                icon: icon,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContainersTable, Container>(table),
                  BaseReferences<
                    _$DomainCacheDatabase,
                    $ContainersTable,
                    Container
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContainersTableProcessedTableManager =
    ProcessedTableManager<
      _$DomainCacheDatabase,
      $ContainersTable,
      Container,
      $$ContainersTableFilterComposer,
      $$ContainersTableOrderingComposer,
      $$ContainersTableAnnotationComposer,
      $$ContainersTableCreateCompanionBuilder,
      $$ContainersTableUpdateCompanionBuilder,
      (
        Container,
        BaseReferences<_$DomainCacheDatabase, $ContainersTable, Container>,
      ),
      Container,
      PrefetchHooks Function()
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required DateTime postedAt,
      required CalendarDate effectiveDate,
      Value<String?> note,
      required String kind,
      required String legOutContainerId,
      required String legOutAssetId,
      required String legOutQuantity,
      Value<String?> legOutBalanceAfter,
      required String legInContainerId,
      required String legInAssetId,
      required String legInQuantity,
      Value<String?> legInBalanceAfter,
      Value<String?> budgetLegOutContainerId,
      Value<String?> budgetLegOutAssetId,
      Value<String?> budgetLegOutQuantity,
      Value<String?> budgetLegOutBalanceAfter,
      Value<String?> budgetLegInContainerId,
      Value<String?> budgetLegInAssetId,
      Value<String?> budgetLegInQuantity,
      Value<String?> budgetLegInBalanceAfter,
      Value<String> tags,
      Value<int> manualOrderRank,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<DateTime> postedAt,
      Value<CalendarDate> effectiveDate,
      Value<String?> note,
      Value<String> kind,
      Value<String> legOutContainerId,
      Value<String> legOutAssetId,
      Value<String> legOutQuantity,
      Value<String?> legOutBalanceAfter,
      Value<String> legInContainerId,
      Value<String> legInAssetId,
      Value<String> legInQuantity,
      Value<String?> legInBalanceAfter,
      Value<String?> budgetLegOutContainerId,
      Value<String?> budgetLegOutAssetId,
      Value<String?> budgetLegOutQuantity,
      Value<String?> budgetLegOutBalanceAfter,
      Value<String?> budgetLegInContainerId,
      Value<String?> budgetLegInAssetId,
      Value<String?> budgetLegInQuantity,
      Value<String?> budgetLegInBalanceAfter,
      Value<String> tags,
      Value<int> manualOrderRank,
      Value<bool> deleted,
      Value<int> rowid,
    });

class $$TransactionsTableFilterComposer
    extends Composer<_$DomainCacheDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
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

  ColumnFilters<DateTime> get postedAt => $composableBuilder(
    column: $table.postedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CalendarDate, CalendarDate, String>
  get effectiveDate => $composableBuilder(
    column: $table.effectiveDate,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legOutContainerId => $composableBuilder(
    column: $table.legOutContainerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legOutAssetId => $composableBuilder(
    column: $table.legOutAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legOutQuantity => $composableBuilder(
    column: $table.legOutQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legOutBalanceAfter => $composableBuilder(
    column: $table.legOutBalanceAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legInContainerId => $composableBuilder(
    column: $table.legInContainerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legInAssetId => $composableBuilder(
    column: $table.legInAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legInQuantity => $composableBuilder(
    column: $table.legInQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legInBalanceAfter => $composableBuilder(
    column: $table.legInBalanceAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegOutContainerId => $composableBuilder(
    column: $table.budgetLegOutContainerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegOutAssetId => $composableBuilder(
    column: $table.budgetLegOutAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegOutQuantity => $composableBuilder(
    column: $table.budgetLegOutQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegOutBalanceAfter => $composableBuilder(
    column: $table.budgetLegOutBalanceAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegInContainerId => $composableBuilder(
    column: $table.budgetLegInContainerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegInAssetId => $composableBuilder(
    column: $table.budgetLegInAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegInQuantity => $composableBuilder(
    column: $table.budgetLegInQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegInBalanceAfter => $composableBuilder(
    column: $table.budgetLegInBalanceAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manualOrderRank => $composableBuilder(
    column: $table.manualOrderRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$DomainCacheDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get postedAt => $composableBuilder(
    column: $table.postedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveDate => $composableBuilder(
    column: $table.effectiveDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legOutContainerId => $composableBuilder(
    column: $table.legOutContainerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legOutAssetId => $composableBuilder(
    column: $table.legOutAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legOutQuantity => $composableBuilder(
    column: $table.legOutQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legOutBalanceAfter => $composableBuilder(
    column: $table.legOutBalanceAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legInContainerId => $composableBuilder(
    column: $table.legInContainerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legInAssetId => $composableBuilder(
    column: $table.legInAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legInQuantity => $composableBuilder(
    column: $table.legInQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legInBalanceAfter => $composableBuilder(
    column: $table.legInBalanceAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegOutContainerId => $composableBuilder(
    column: $table.budgetLegOutContainerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegOutAssetId => $composableBuilder(
    column: $table.budgetLegOutAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegOutQuantity => $composableBuilder(
    column: $table.budgetLegOutQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegOutBalanceAfter => $composableBuilder(
    column: $table.budgetLegOutBalanceAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegInContainerId => $composableBuilder(
    column: $table.budgetLegInContainerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegInAssetId => $composableBuilder(
    column: $table.budgetLegInAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegInQuantity => $composableBuilder(
    column: $table.budgetLegInQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegInBalanceAfter => $composableBuilder(
    column: $table.budgetLegInBalanceAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manualOrderRank => $composableBuilder(
    column: $table.manualOrderRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$DomainCacheDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get postedAt =>
      $composableBuilder(column: $table.postedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CalendarDate, String> get effectiveDate =>
      $composableBuilder(
        column: $table.effectiveDate,
        builder: (column) => column,
      );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get legOutContainerId => $composableBuilder(
    column: $table.legOutContainerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legOutAssetId => $composableBuilder(
    column: $table.legOutAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legOutQuantity => $composableBuilder(
    column: $table.legOutQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legOutBalanceAfter => $composableBuilder(
    column: $table.legOutBalanceAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legInContainerId => $composableBuilder(
    column: $table.legInContainerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legInAssetId => $composableBuilder(
    column: $table.legInAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legInQuantity => $composableBuilder(
    column: $table.legInQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legInBalanceAfter => $composableBuilder(
    column: $table.legInBalanceAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegOutContainerId => $composableBuilder(
    column: $table.budgetLegOutContainerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegOutAssetId => $composableBuilder(
    column: $table.budgetLegOutAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegOutQuantity => $composableBuilder(
    column: $table.budgetLegOutQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegOutBalanceAfter => $composableBuilder(
    column: $table.budgetLegOutBalanceAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegInContainerId => $composableBuilder(
    column: $table.budgetLegInContainerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegInAssetId => $composableBuilder(
    column: $table.budgetLegInAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegInQuantity => $composableBuilder(
    column: $table.budgetLegInQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegInBalanceAfter => $composableBuilder(
    column: $table.budgetLegInBalanceAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<int> get manualOrderRank => $composableBuilder(
    column: $table.manualOrderRank,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$DomainCacheDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (
            Transaction,
            BaseReferences<
              _$DomainCacheDatabase,
              $TransactionsTable,
              Transaction
            >,
          ),
          Transaction,
          PrefetchHooks Function()
        > {
  $$TransactionsTableTableManager(
    _$DomainCacheDatabase db,
    $TransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> postedAt = const Value.absent(),
                Value<CalendarDate> effectiveDate = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> legOutContainerId = const Value.absent(),
                Value<String> legOutAssetId = const Value.absent(),
                Value<String> legOutQuantity = const Value.absent(),
                Value<String?> legOutBalanceAfter = const Value.absent(),
                Value<String> legInContainerId = const Value.absent(),
                Value<String> legInAssetId = const Value.absent(),
                Value<String> legInQuantity = const Value.absent(),
                Value<String?> legInBalanceAfter = const Value.absent(),
                Value<String?> budgetLegOutContainerId = const Value.absent(),
                Value<String?> budgetLegOutAssetId = const Value.absent(),
                Value<String?> budgetLegOutQuantity = const Value.absent(),
                Value<String?> budgetLegOutBalanceAfter = const Value.absent(),
                Value<String?> budgetLegInContainerId = const Value.absent(),
                Value<String?> budgetLegInAssetId = const Value.absent(),
                Value<String?> budgetLegInQuantity = const Value.absent(),
                Value<String?> budgetLegInBalanceAfter = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> manualOrderRank = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                postedAt: postedAt,
                effectiveDate: effectiveDate,
                note: note,
                kind: kind,
                legOutContainerId: legOutContainerId,
                legOutAssetId: legOutAssetId,
                legOutQuantity: legOutQuantity,
                legOutBalanceAfter: legOutBalanceAfter,
                legInContainerId: legInContainerId,
                legInAssetId: legInAssetId,
                legInQuantity: legInQuantity,
                legInBalanceAfter: legInBalanceAfter,
                budgetLegOutContainerId: budgetLegOutContainerId,
                budgetLegOutAssetId: budgetLegOutAssetId,
                budgetLegOutQuantity: budgetLegOutQuantity,
                budgetLegOutBalanceAfter: budgetLegOutBalanceAfter,
                budgetLegInContainerId: budgetLegInContainerId,
                budgetLegInAssetId: budgetLegInAssetId,
                budgetLegInQuantity: budgetLegInQuantity,
                budgetLegInBalanceAfter: budgetLegInBalanceAfter,
                tags: tags,
                manualOrderRank: manualOrderRank,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime postedAt,
                required CalendarDate effectiveDate,
                Value<String?> note = const Value.absent(),
                required String kind,
                required String legOutContainerId,
                required String legOutAssetId,
                required String legOutQuantity,
                Value<String?> legOutBalanceAfter = const Value.absent(),
                required String legInContainerId,
                required String legInAssetId,
                required String legInQuantity,
                Value<String?> legInBalanceAfter = const Value.absent(),
                Value<String?> budgetLegOutContainerId = const Value.absent(),
                Value<String?> budgetLegOutAssetId = const Value.absent(),
                Value<String?> budgetLegOutQuantity = const Value.absent(),
                Value<String?> budgetLegOutBalanceAfter = const Value.absent(),
                Value<String?> budgetLegInContainerId = const Value.absent(),
                Value<String?> budgetLegInAssetId = const Value.absent(),
                Value<String?> budgetLegInQuantity = const Value.absent(),
                Value<String?> budgetLegInBalanceAfter = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> manualOrderRank = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                postedAt: postedAt,
                effectiveDate: effectiveDate,
                note: note,
                kind: kind,
                legOutContainerId: legOutContainerId,
                legOutAssetId: legOutAssetId,
                legOutQuantity: legOutQuantity,
                legOutBalanceAfter: legOutBalanceAfter,
                legInContainerId: legInContainerId,
                legInAssetId: legInAssetId,
                legInQuantity: legInQuantity,
                legInBalanceAfter: legInBalanceAfter,
                budgetLegOutContainerId: budgetLegOutContainerId,
                budgetLegOutAssetId: budgetLegOutAssetId,
                budgetLegOutQuantity: budgetLegOutQuantity,
                budgetLegOutBalanceAfter: budgetLegOutBalanceAfter,
                budgetLegInContainerId: budgetLegInContainerId,
                budgetLegInAssetId: budgetLegInAssetId,
                budgetLegInQuantity: budgetLegInQuantity,
                budgetLegInBalanceAfter: budgetLegInBalanceAfter,
                tags: tags,
                manualOrderRank: manualOrderRank,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionsTable, Transaction>(table),
                  BaseReferences<
                    _$DomainCacheDatabase,
                    $TransactionsTable,
                    Transaction
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$DomainCacheDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (
        Transaction,
        BaseReferences<_$DomainCacheDatabase, $TransactionsTable, Transaction>,
      ),
      Transaction,
      PrefetchHooks Function()
    >;
typedef $$PriceSnapshotsTableCreateCompanionBuilder =
    PriceSnapshotsCompanion Function({
      required String id,
      required String assetId,
      required DateTime date,
      required String price,
      required String currencyAssetId,
      required String source,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$PriceSnapshotsTableUpdateCompanionBuilder =
    PriceSnapshotsCompanion Function({
      Value<String> id,
      Value<String> assetId,
      Value<DateTime> date,
      Value<String> price,
      Value<String> currencyAssetId,
      Value<String> source,
      Value<bool> deleted,
      Value<int> rowid,
    });

class $$PriceSnapshotsTableFilterComposer
    extends Composer<_$DomainCacheDatabase, $PriceSnapshotsTable> {
  $$PriceSnapshotsTableFilterComposer({
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

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyAssetId => $composableBuilder(
    column: $table.currencyAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PriceSnapshotsTableOrderingComposer
    extends Composer<_$DomainCacheDatabase, $PriceSnapshotsTable> {
  $$PriceSnapshotsTableOrderingComposer({
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

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyAssetId => $composableBuilder(
    column: $table.currencyAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PriceSnapshotsTableAnnotationComposer
    extends Composer<_$DomainCacheDatabase, $PriceSnapshotsTable> {
  $$PriceSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get currencyAssetId => $composableBuilder(
    column: $table.currencyAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$PriceSnapshotsTableTableManager
    extends
        RootTableManager<
          _$DomainCacheDatabase,
          $PriceSnapshotsTable,
          PriceSnapshot,
          $$PriceSnapshotsTableFilterComposer,
          $$PriceSnapshotsTableOrderingComposer,
          $$PriceSnapshotsTableAnnotationComposer,
          $$PriceSnapshotsTableCreateCompanionBuilder,
          $$PriceSnapshotsTableUpdateCompanionBuilder,
          (
            PriceSnapshot,
            BaseReferences<
              _$DomainCacheDatabase,
              $PriceSnapshotsTable,
              PriceSnapshot
            >,
          ),
          PriceSnapshot,
          PrefetchHooks Function()
        > {
  $$PriceSnapshotsTableTableManager(
    _$DomainCacheDatabase db,
    $PriceSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PriceSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PriceSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PriceSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> price = const Value.absent(),
                Value<String> currencyAssetId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PriceSnapshotsCompanion(
                id: id,
                assetId: assetId,
                date: date,
                price: price,
                currencyAssetId: currencyAssetId,
                source: source,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String assetId,
                required DateTime date,
                required String price,
                required String currencyAssetId,
                required String source,
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PriceSnapshotsCompanion.insert(
                id: id,
                assetId: assetId,
                date: date,
                price: price,
                currencyAssetId: currencyAssetId,
                source: source,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PriceSnapshotsTable, PriceSnapshot>(table),
                  BaseReferences<
                    _$DomainCacheDatabase,
                    $PriceSnapshotsTable,
                    PriceSnapshot
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PriceSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$DomainCacheDatabase,
      $PriceSnapshotsTable,
      PriceSnapshot,
      $$PriceSnapshotsTableFilterComposer,
      $$PriceSnapshotsTableOrderingComposer,
      $$PriceSnapshotsTableAnnotationComposer,
      $$PriceSnapshotsTableCreateCompanionBuilder,
      $$PriceSnapshotsTableUpdateCompanionBuilder,
      (
        PriceSnapshot,
        BaseReferences<
          _$DomainCacheDatabase,
          $PriceSnapshotsTable,
          PriceSnapshot
        >,
      ),
      PriceSnapshot,
      PrefetchHooks Function()
    >;
typedef $$BalanceCheckpointsTableCreateCompanionBuilder =
    BalanceCheckpointsCompanion Function({
      required String containerId,
      required String assetId,
      required DateTime checkpointDate,
      required String quantity,
      Value<int> rowid,
    });
typedef $$BalanceCheckpointsTableUpdateCompanionBuilder =
    BalanceCheckpointsCompanion Function({
      Value<String> containerId,
      Value<String> assetId,
      Value<DateTime> checkpointDate,
      Value<String> quantity,
      Value<int> rowid,
    });

class $$BalanceCheckpointsTableFilterComposer
    extends Composer<_$DomainCacheDatabase, $BalanceCheckpointsTable> {
  $$BalanceCheckpointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get containerId => $composableBuilder(
    column: $table.containerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkpointDate => $composableBuilder(
    column: $table.checkpointDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BalanceCheckpointsTableOrderingComposer
    extends Composer<_$DomainCacheDatabase, $BalanceCheckpointsTable> {
  $$BalanceCheckpointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get containerId => $composableBuilder(
    column: $table.containerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkpointDate => $composableBuilder(
    column: $table.checkpointDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BalanceCheckpointsTableAnnotationComposer
    extends Composer<_$DomainCacheDatabase, $BalanceCheckpointsTable> {
  $$BalanceCheckpointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get containerId => $composableBuilder(
    column: $table.containerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<DateTime> get checkpointDate => $composableBuilder(
    column: $table.checkpointDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);
}

class $$BalanceCheckpointsTableTableManager
    extends
        RootTableManager<
          _$DomainCacheDatabase,
          $BalanceCheckpointsTable,
          BalanceCheckpoint,
          $$BalanceCheckpointsTableFilterComposer,
          $$BalanceCheckpointsTableOrderingComposer,
          $$BalanceCheckpointsTableAnnotationComposer,
          $$BalanceCheckpointsTableCreateCompanionBuilder,
          $$BalanceCheckpointsTableUpdateCompanionBuilder,
          (
            BalanceCheckpoint,
            BaseReferences<
              _$DomainCacheDatabase,
              $BalanceCheckpointsTable,
              BalanceCheckpoint
            >,
          ),
          BalanceCheckpoint,
          PrefetchHooks Function()
        > {
  $$BalanceCheckpointsTableTableManager(
    _$DomainCacheDatabase db,
    $BalanceCheckpointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BalanceCheckpointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BalanceCheckpointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BalanceCheckpointsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> containerId = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<DateTime> checkpointDate = const Value.absent(),
                Value<String> quantity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BalanceCheckpointsCompanion(
                containerId: containerId,
                assetId: assetId,
                checkpointDate: checkpointDate,
                quantity: quantity,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String containerId,
                required String assetId,
                required DateTime checkpointDate,
                required String quantity,
                Value<int> rowid = const Value.absent(),
              }) => BalanceCheckpointsCompanion.insert(
                containerId: containerId,
                assetId: assetId,
                checkpointDate: checkpointDate,
                quantity: quantity,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BalanceCheckpointsTable, BalanceCheckpoint>(
                    table,
                  ),
                  BaseReferences<
                    _$DomainCacheDatabase,
                    $BalanceCheckpointsTable,
                    BalanceCheckpoint
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BalanceCheckpointsTableProcessedTableManager =
    ProcessedTableManager<
      _$DomainCacheDatabase,
      $BalanceCheckpointsTable,
      BalanceCheckpoint,
      $$BalanceCheckpointsTableFilterComposer,
      $$BalanceCheckpointsTableOrderingComposer,
      $$BalanceCheckpointsTableAnnotationComposer,
      $$BalanceCheckpointsTableCreateCompanionBuilder,
      $$BalanceCheckpointsTableUpdateCompanionBuilder,
      (
        BalanceCheckpoint,
        BaseReferences<
          _$DomainCacheDatabase,
          $BalanceCheckpointsTable,
          BalanceCheckpoint
        >,
      ),
      BalanceCheckpoint,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String id,
      required String value,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> id,
      Value<String> value,
      Value<bool> deleted,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$DomainCacheDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
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

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$DomainCacheDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
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

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$DomainCacheDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$DomainCacheDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            Setting,
            BaseReferences<_$DomainCacheDatabase, $SettingsTable, Setting>,
          ),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$DomainCacheDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                value: value,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String value,
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                value: value,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<
                    _$DomainCacheDatabase,
                    $SettingsTable,
                    Setting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$DomainCacheDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$DomainCacheDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$RecurringTransactionTemplatesTableCreateCompanionBuilder =
    RecurringTransactionTemplatesCompanion Function({
      required String id,
      required String kind,
      required String legOutContainerId,
      required String legOutAssetId,
      required String legOutQuantity,
      required String legInContainerId,
      required String legInAssetId,
      required String legInQuantity,
      Value<String?> budgetLegOutContainerId,
      Value<String?> budgetLegOutAssetId,
      Value<String?> budgetLegOutQuantity,
      Value<String?> budgetLegInContainerId,
      Value<String?> budgetLegInAssetId,
      Value<String?> budgetLegInQuantity,
      Value<String?> note,
      Value<String> tags,
      required String ruleUnit,
      required int ruleInterval,
      required CalendarDate ruleStartDate,
      Value<CalendarDate?> ruleEndDate,
      Value<int?> ruleMaxOccurrences,
      Value<CalendarDate?> lastGeneratedOccurrenceDate,
      Value<bool> active,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$RecurringTransactionTemplatesTableUpdateCompanionBuilder =
    RecurringTransactionTemplatesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> legOutContainerId,
      Value<String> legOutAssetId,
      Value<String> legOutQuantity,
      Value<String> legInContainerId,
      Value<String> legInAssetId,
      Value<String> legInQuantity,
      Value<String?> budgetLegOutContainerId,
      Value<String?> budgetLegOutAssetId,
      Value<String?> budgetLegOutQuantity,
      Value<String?> budgetLegInContainerId,
      Value<String?> budgetLegInAssetId,
      Value<String?> budgetLegInQuantity,
      Value<String?> note,
      Value<String> tags,
      Value<String> ruleUnit,
      Value<int> ruleInterval,
      Value<CalendarDate> ruleStartDate,
      Value<CalendarDate?> ruleEndDate,
      Value<int?> ruleMaxOccurrences,
      Value<CalendarDate?> lastGeneratedOccurrenceDate,
      Value<bool> active,
      Value<bool> deleted,
      Value<int> rowid,
    });

class $$RecurringTransactionTemplatesTableFilterComposer
    extends
        Composer<_$DomainCacheDatabase, $RecurringTransactionTemplatesTable> {
  $$RecurringTransactionTemplatesTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legOutContainerId => $composableBuilder(
    column: $table.legOutContainerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legOutAssetId => $composableBuilder(
    column: $table.legOutAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legOutQuantity => $composableBuilder(
    column: $table.legOutQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legInContainerId => $composableBuilder(
    column: $table.legInContainerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legInAssetId => $composableBuilder(
    column: $table.legInAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legInQuantity => $composableBuilder(
    column: $table.legInQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegOutContainerId => $composableBuilder(
    column: $table.budgetLegOutContainerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegOutAssetId => $composableBuilder(
    column: $table.budgetLegOutAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegOutQuantity => $composableBuilder(
    column: $table.budgetLegOutQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegInContainerId => $composableBuilder(
    column: $table.budgetLegInContainerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegInAssetId => $composableBuilder(
    column: $table.budgetLegInAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetLegInQuantity => $composableBuilder(
    column: $table.budgetLegInQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleUnit => $composableBuilder(
    column: $table.ruleUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ruleInterval => $composableBuilder(
    column: $table.ruleInterval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CalendarDate, CalendarDate, String>
  get ruleStartDate => $composableBuilder(
    column: $table.ruleStartDate,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<CalendarDate?, CalendarDate, String>
  get ruleEndDate => $composableBuilder(
    column: $table.ruleEndDate,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get ruleMaxOccurrences => $composableBuilder(
    column: $table.ruleMaxOccurrences,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CalendarDate?, CalendarDate, String>
  get lastGeneratedOccurrenceDate => $composableBuilder(
    column: $table.lastGeneratedOccurrenceDate,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecurringTransactionTemplatesTableOrderingComposer
    extends
        Composer<_$DomainCacheDatabase, $RecurringTransactionTemplatesTable> {
  $$RecurringTransactionTemplatesTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legOutContainerId => $composableBuilder(
    column: $table.legOutContainerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legOutAssetId => $composableBuilder(
    column: $table.legOutAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legOutQuantity => $composableBuilder(
    column: $table.legOutQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legInContainerId => $composableBuilder(
    column: $table.legInContainerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legInAssetId => $composableBuilder(
    column: $table.legInAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legInQuantity => $composableBuilder(
    column: $table.legInQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegOutContainerId => $composableBuilder(
    column: $table.budgetLegOutContainerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegOutAssetId => $composableBuilder(
    column: $table.budgetLegOutAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegOutQuantity => $composableBuilder(
    column: $table.budgetLegOutQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegInContainerId => $composableBuilder(
    column: $table.budgetLegInContainerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegInAssetId => $composableBuilder(
    column: $table.budgetLegInAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetLegInQuantity => $composableBuilder(
    column: $table.budgetLegInQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleUnit => $composableBuilder(
    column: $table.ruleUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ruleInterval => $composableBuilder(
    column: $table.ruleInterval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleStartDate => $composableBuilder(
    column: $table.ruleStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleEndDate => $composableBuilder(
    column: $table.ruleEndDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ruleMaxOccurrences => $composableBuilder(
    column: $table.ruleMaxOccurrences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastGeneratedOccurrenceDate => $composableBuilder(
    column: $table.lastGeneratedOccurrenceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecurringTransactionTemplatesTableAnnotationComposer
    extends
        Composer<_$DomainCacheDatabase, $RecurringTransactionTemplatesTable> {
  $$RecurringTransactionTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get legOutContainerId => $composableBuilder(
    column: $table.legOutContainerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legOutAssetId => $composableBuilder(
    column: $table.legOutAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legOutQuantity => $composableBuilder(
    column: $table.legOutQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legInContainerId => $composableBuilder(
    column: $table.legInContainerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legInAssetId => $composableBuilder(
    column: $table.legInAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legInQuantity => $composableBuilder(
    column: $table.legInQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegOutContainerId => $composableBuilder(
    column: $table.budgetLegOutContainerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegOutAssetId => $composableBuilder(
    column: $table.budgetLegOutAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegOutQuantity => $composableBuilder(
    column: $table.budgetLegOutQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegInContainerId => $composableBuilder(
    column: $table.budgetLegInContainerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegInAssetId => $composableBuilder(
    column: $table.budgetLegInAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get budgetLegInQuantity => $composableBuilder(
    column: $table.budgetLegInQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get ruleUnit =>
      $composableBuilder(column: $table.ruleUnit, builder: (column) => column);

  GeneratedColumn<int> get ruleInterval => $composableBuilder(
    column: $table.ruleInterval,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<CalendarDate, String> get ruleStartDate =>
      $composableBuilder(
        column: $table.ruleStartDate,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<CalendarDate?, String> get ruleEndDate =>
      $composableBuilder(
        column: $table.ruleEndDate,
        builder: (column) => column,
      );

  GeneratedColumn<int> get ruleMaxOccurrences => $composableBuilder(
    column: $table.ruleMaxOccurrences,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<CalendarDate?, String>
  get lastGeneratedOccurrenceDate => $composableBuilder(
    column: $table.lastGeneratedOccurrenceDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$RecurringTransactionTemplatesTableTableManager
    extends
        RootTableManager<
          _$DomainCacheDatabase,
          $RecurringTransactionTemplatesTable,
          RecurringTransactionTemplate,
          $$RecurringTransactionTemplatesTableFilterComposer,
          $$RecurringTransactionTemplatesTableOrderingComposer,
          $$RecurringTransactionTemplatesTableAnnotationComposer,
          $$RecurringTransactionTemplatesTableCreateCompanionBuilder,
          $$RecurringTransactionTemplatesTableUpdateCompanionBuilder,
          (
            RecurringTransactionTemplate,
            BaseReferences<
              _$DomainCacheDatabase,
              $RecurringTransactionTemplatesTable,
              RecurringTransactionTemplate
            >,
          ),
          RecurringTransactionTemplate,
          PrefetchHooks Function()
        > {
  $$RecurringTransactionTemplatesTableTableManager(
    _$DomainCacheDatabase db,
    $RecurringTransactionTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringTransactionTemplatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RecurringTransactionTemplatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecurringTransactionTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> legOutContainerId = const Value.absent(),
                Value<String> legOutAssetId = const Value.absent(),
                Value<String> legOutQuantity = const Value.absent(),
                Value<String> legInContainerId = const Value.absent(),
                Value<String> legInAssetId = const Value.absent(),
                Value<String> legInQuantity = const Value.absent(),
                Value<String?> budgetLegOutContainerId = const Value.absent(),
                Value<String?> budgetLegOutAssetId = const Value.absent(),
                Value<String?> budgetLegOutQuantity = const Value.absent(),
                Value<String?> budgetLegInContainerId = const Value.absent(),
                Value<String?> budgetLegInAssetId = const Value.absent(),
                Value<String?> budgetLegInQuantity = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> ruleUnit = const Value.absent(),
                Value<int> ruleInterval = const Value.absent(),
                Value<CalendarDate> ruleStartDate = const Value.absent(),
                Value<CalendarDate?> ruleEndDate = const Value.absent(),
                Value<int?> ruleMaxOccurrences = const Value.absent(),
                Value<CalendarDate?> lastGeneratedOccurrenceDate =
                    const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringTransactionTemplatesCompanion(
                id: id,
                kind: kind,
                legOutContainerId: legOutContainerId,
                legOutAssetId: legOutAssetId,
                legOutQuantity: legOutQuantity,
                legInContainerId: legInContainerId,
                legInAssetId: legInAssetId,
                legInQuantity: legInQuantity,
                budgetLegOutContainerId: budgetLegOutContainerId,
                budgetLegOutAssetId: budgetLegOutAssetId,
                budgetLegOutQuantity: budgetLegOutQuantity,
                budgetLegInContainerId: budgetLegInContainerId,
                budgetLegInAssetId: budgetLegInAssetId,
                budgetLegInQuantity: budgetLegInQuantity,
                note: note,
                tags: tags,
                ruleUnit: ruleUnit,
                ruleInterval: ruleInterval,
                ruleStartDate: ruleStartDate,
                ruleEndDate: ruleEndDate,
                ruleMaxOccurrences: ruleMaxOccurrences,
                lastGeneratedOccurrenceDate: lastGeneratedOccurrenceDate,
                active: active,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String legOutContainerId,
                required String legOutAssetId,
                required String legOutQuantity,
                required String legInContainerId,
                required String legInAssetId,
                required String legInQuantity,
                Value<String?> budgetLegOutContainerId = const Value.absent(),
                Value<String?> budgetLegOutAssetId = const Value.absent(),
                Value<String?> budgetLegOutQuantity = const Value.absent(),
                Value<String?> budgetLegInContainerId = const Value.absent(),
                Value<String?> budgetLegInAssetId = const Value.absent(),
                Value<String?> budgetLegInQuantity = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> tags = const Value.absent(),
                required String ruleUnit,
                required int ruleInterval,
                required CalendarDate ruleStartDate,
                Value<CalendarDate?> ruleEndDate = const Value.absent(),
                Value<int?> ruleMaxOccurrences = const Value.absent(),
                Value<CalendarDate?> lastGeneratedOccurrenceDate =
                    const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringTransactionTemplatesCompanion.insert(
                id: id,
                kind: kind,
                legOutContainerId: legOutContainerId,
                legOutAssetId: legOutAssetId,
                legOutQuantity: legOutQuantity,
                legInContainerId: legInContainerId,
                legInAssetId: legInAssetId,
                legInQuantity: legInQuantity,
                budgetLegOutContainerId: budgetLegOutContainerId,
                budgetLegOutAssetId: budgetLegOutAssetId,
                budgetLegOutQuantity: budgetLegOutQuantity,
                budgetLegInContainerId: budgetLegInContainerId,
                budgetLegInAssetId: budgetLegInAssetId,
                budgetLegInQuantity: budgetLegInQuantity,
                note: note,
                tags: tags,
                ruleUnit: ruleUnit,
                ruleInterval: ruleInterval,
                ruleStartDate: ruleStartDate,
                ruleEndDate: ruleEndDate,
                ruleMaxOccurrences: ruleMaxOccurrences,
                lastGeneratedOccurrenceDate: lastGeneratedOccurrenceDate,
                active: active,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $RecurringTransactionTemplatesTable,
                    RecurringTransactionTemplate
                  >(table),
                  BaseReferences<
                    _$DomainCacheDatabase,
                    $RecurringTransactionTemplatesTable,
                    RecurringTransactionTemplate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecurringTransactionTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$DomainCacheDatabase,
      $RecurringTransactionTemplatesTable,
      RecurringTransactionTemplate,
      $$RecurringTransactionTemplatesTableFilterComposer,
      $$RecurringTransactionTemplatesTableOrderingComposer,
      $$RecurringTransactionTemplatesTableAnnotationComposer,
      $$RecurringTransactionTemplatesTableCreateCompanionBuilder,
      $$RecurringTransactionTemplatesTableUpdateCompanionBuilder,
      (
        RecurringTransactionTemplate,
        BaseReferences<
          _$DomainCacheDatabase,
          $RecurringTransactionTemplatesTable,
          RecurringTransactionTemplate
        >,
      ),
      RecurringTransactionTemplate,
      PrefetchHooks Function()
    >;

class $DomainCacheDatabaseManager {
  final _$DomainCacheDatabase _db;
  $DomainCacheDatabaseManager(this._db);
  $$AssetsTableTableManager get assets =>
      $$AssetsTableTableManager(_db, _db.assets);
  $$ContainersTableTableManager get containers =>
      $$ContainersTableTableManager(_db, _db.containers);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$PriceSnapshotsTableTableManager get priceSnapshots =>
      $$PriceSnapshotsTableTableManager(_db, _db.priceSnapshots);
  $$BalanceCheckpointsTableTableManager get balanceCheckpoints =>
      $$BalanceCheckpointsTableTableManager(_db, _db.balanceCheckpoints);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$RecurringTransactionTemplatesTableTableManager
  get recurringTransactionTemplates =>
      $$RecurringTransactionTemplatesTableTableManager(
        _db,
        _db.recurringTransactionTemplates,
      );
}
