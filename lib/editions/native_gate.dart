import 'package:flutter/material.dart';
import '../src/rust/frb_generated.dart';
import '../src/rust/api/simple.dart' show engineInfo;
import 'edition.dart';
import 'native_initialization.dart';

final _initialization = NativeInitialization();
Future<String> _initialize() async {
  if (!RustLib.instance.initialized) await _initialization.ensure(RustLib.init);
  return engineInfo();
}

/// Verify the actual loaded engine before exposing either edition's routes.
/// Audit-time hashes alone do not protect against a mixed local installation.
class EditionNativeGate extends StatefulWidget {
  const EditionNativeGate({super.key, required this.child, this.initialize});
  final Widget child;
  final Future<String> Function()? initialize;
  @override
  State<EditionNativeGate> createState() => _EditionNativeGateState();
}

class _EditionNativeGateState extends State<EditionNativeGate> {
  late Future<void> _verification = _verify();
  Future<void> _verify() async {
    final info = await (widget.initialize ?? _initialize)().timeout(
      const Duration(seconds: 25),
    );
    Edition.verifyNative(info);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _verification,
    builder: (context, snapshot) {
      final complete = snapshot.connectionState == ConnectionState.done;
      if (complete && !snapshot.hasError) return widget.child;
      return MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          appBar: AppBar(title: Text(Edition.displayName)),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!complete) const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    complete
                        ? 'Application verification failed'
                        : 'Verifying application...',
                  ),
                  if (complete) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'The application and native engine must have the '
                      'same edition and policy. Content remains unavailable.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() {
                        _verification = _verify();
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
