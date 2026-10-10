import 'package:flutter/material.dart';

String themeModeStorageValue(ThemeMode mode) => mode.name;

ThemeMode themeModeFromStorage(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};
