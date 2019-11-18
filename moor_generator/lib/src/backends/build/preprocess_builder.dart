import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:moor_generator/src/backends/build/serialized_types.dart';
import 'package:moor_generator/src/utils/string_escaper.dart';
import 'package:sqlparser/sqlparser.dart';

/// A support builder that runs before the main moor_generator to parse and
/// resolve inline Dart resources in a moor file.
///
/// We use this builder to extract and analyze inline Dart expressions from moor
/// files, which are mainly used for type converters. For instance, let's say
/// we had a moor file like this:
/// ```
/// -- called input.moor
/// import 'package:my_package/converter.dart';
///
/// CREATE TABLE users (
///   preferences TEXT MAPPED BY `const PreferencesConverter()`
/// );
/// ```
/// For that file, the [PreprocessBuilder] would generate a `.dart_in_moor` file
/// which contains information about the static type of all expressions in the
/// moor file. The main generator can then read the `.dart_in_moor` file to
/// resolve those expressions.
class PreprocessBuilder extends Builder {
  @override
  final Map<String, List<String>> buildExtensions = const {
    '.moor': ['.temp.dart', '.dart_in_moor'],
  };

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final input = buildStep.inputId;
    final moorFileContent = await buildStep.readAsString(input);
    final engine = SqlEngine(useMoorExtensions: true);

    final parsed = engine.parseMoorFile(moorFileContent);

    final dartLexemes = parsed.tokens
        .whereType<InlineDartToken>()
        .map((token) => token.dartCode)
        .toList();

    if (dartLexemes.isEmpty) return; // nothing to do, no Dart in this moor file

    final importedFiles = parsed.rootNode.allDescendants
        .whereType<ImportStatement>()
        .map((stmt) => stmt.importedFile)
        .where((import) => import.endsWith('.dart'));

    // to analyze the expressions, generate a fake Dart file that declares each
    // expression in a `var`, we can then read the static type.

    final dartBuffer = StringBuffer();
    for (final import in importedFiles) {
      dartBuffer.write('import ${asDartLiteral(import)};\n');
    }

    for (var i = 0; i < dartLexemes.length; i++) {
      dartBuffer.write('var ${_nameForDartExpr(i)} = ${dartLexemes[i]};\n');
    }

    final tempDartAsset = input.changeExtension('.temp.dart');
    await buildStep.writeAsString(tempDartAsset, dartBuffer.toString());

    // we can now resolve the library we just wrote

    final createdLibrary = await buildStep.resolver.libraryFor(tempDartAsset);
    final resolveResult = await createdLibrary.session
        .getResolvedLibraryByElement(createdLibrary);

    final serializer = TypeSerializer(buildStep.resolver);
    final codeToType = <String, SerializedType>{};

    for (var i = 0; i < dartLexemes.length; i++) {
      final member =
          _findVariableDefinition(_nameForDartExpr(i), createdLibrary);
      final node = resolveResult.getElementDeclaration(member).node
          as VariableDeclaration;

      final type = node.initializer.staticType;
      codeToType[dartLexemes[i]] = await serializer.serialize(type);
    }

    final outputAsset = input.changeExtension('.dart_in_moor');
    await buildStep.writeAsString(outputAsset, jsonEncode(codeToType));
  }

  String _nameForDartExpr(int i) => 'expr_$i';

  TopLevelVariableElement _findVariableDefinition(
      String name, LibraryElement element) {
    return element.units
        .expand((u) => u.topLevelVariables)
        .firstWhere((e) => e.name == name);
  }
}
