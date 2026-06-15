import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exposes the GlobalKey of the mobile-web AppShell Scaffold so that
/// [buildAppBarActions] can call openDrawer() from any nested AppBar.
final shellScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>(
  (ref) => GlobalKey<ScaffoldState>(),
);
