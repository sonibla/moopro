import 'package:drift/native.dart';
import 'package:drift/drift.dart';

QueryExecutor openDomainCacheConnection() => NativeDatabase.memory();
