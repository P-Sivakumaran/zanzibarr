import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'edition.dart';

Future<Directory> editionSupportDirectory() async =>
    editionDirectory(await getApplicationSupportDirectory());

Future<Directory> editionTemporaryDirectory() async =>
    editionDirectory(await getTemporaryDirectory());

/// New editions never inherit a Legacy directory. Create the scoped parent
/// before passing browser/cache paths to platform APIs.
Future<Directory> editionDirectory(
  Directory parent, {
  AppEdition? edition,
}) async {
  final scope = edition ?? Edition.current;
  if (scope == AppEdition.legacy) return parent;
  return Directory(
    '${parent.path}/editions/${scope.name}',
  ).create(recursive: true);
}
