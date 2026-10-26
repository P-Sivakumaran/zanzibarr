import 'editions/native_gate.dart';
import 'package:flutter/material.dart';
import 'editions/edition.dart';
import 'editions/restricted_access.dart';
import 'main.dart' show ZanzibarrBootstrap;
import 'settings/ui_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Edition.current != AppEdition.restricted) {
    throw StateError('Prepare a Restricted candidate before running');
  }
  runApp(
    EditionNativeGate(
      child: RestrictedAccessGate(
        session: RestrictedSession(
          authenticate: WindowsDeviceAuthentication.authenticate,
          cancelAuthentication: WindowsDeviceAuthentication.cancel,
          mayUnlock: () =>
              WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed,
        ),
        application: () => ZanzibarrBootstrap(
          uiPreferences: UiPreferencesController(UiPreferencesStore()),
        ),
      ),
    ),
  );
}
