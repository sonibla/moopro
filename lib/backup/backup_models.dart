import '../domain/models.dart';

class BackupEntity {
  final String id;
  final String type;
  final Map<String, dynamic> data;

  const BackupEntity({
    required this.id,
    required this.type,
    required this.data,
  });

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'data': data};

  factory BackupEntity.fromJson(Map<String, dynamic> json) => BackupEntity(
    id: json['id'] as String,
    type: json['type'] as String,
    data: json['data'] as Map<String, dynamic>,
  );
}

class BackupPayload {
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final DateTime exportedAt;
  final List<BackupEntity> entities;

  const BackupPayload({
    required this.schemaVersion,
    required this.exportedAt,
    required this.entities,
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'entities': entities.map((e) => e.toJson()).toList(),
  };

  factory BackupPayload.fromJson(Map<String, dynamic> json) => BackupPayload(
    schemaVersion: json['schemaVersion'] as int,
    exportedAt: DateTime.parse(json['exportedAt'] as String),
    entities: (json['entities'] as List)
        .map((e) => BackupEntity.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

List<BackupEntity> buildBackupEntities({
  required List<Asset> assets,
  required List<MoneyContainer> containers,
  required List<MoneyTransaction> transactions,
  required List<PriceSnapshot> priceSnapshots,
  required List<Setting> settings,
}) {
  return [
    for (final a in assets)
      BackupEntity(id: a.id, type: VaultRecordTypes.asset, data: a.toJson()),
    for (final c in containers)
      BackupEntity(
        id: c.id,
        type: VaultRecordTypes.container,
        data: c.toJson(),
      ),
    for (final t in transactions)
      BackupEntity(
        id: t.id,
        type: VaultRecordTypes.transaction,
        data: t.toJson(),
      ),
    for (final p in priceSnapshots)
      BackupEntity(
        id: p.id,
        type: VaultRecordTypes.priceSnapshot,
        data: p.toJson(),
      ),
    for (final s in settings)
      BackupEntity(id: s.id, type: VaultRecordTypes.setting, data: s.toJson()),
  ];
}
