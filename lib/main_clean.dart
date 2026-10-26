import 'editions/native_gate.dart';
import 'package:flutter/material.dart';
import 'editions/clean_app.dart';
import 'editions/edition.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Edition.current != AppEdition.clean) {
    throw StateError(
      'Prepare a Clean candidate before running this entrypoint',
    );
  }
  runApp(const EditionNativeGate(child: CleanApp()));
}
