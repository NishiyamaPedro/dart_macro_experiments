// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:macros/macros.dart';

macro class DataClassMacro
    implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const DataClassMacro();

  @override
  FutureOr<void> buildDeclarationsForClass(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    final (str, obj) = await (
      builder.resolveIdentifier(_dartCore, 'String'),
      builder.resolveIdentifier(_dartCore, 'Object'),
    ).wait;

    await (
      _declareGet(clazz, builder, obj, str),
      _declareSet(clazz, builder, obj, str),
    ).wait;
  }

  @override
  FutureOr<void> buildDefinitionForClass(ClassDeclaration clazz, TypeDefinitionBuilder builder) async {
    final introspectionData = await _SharedIntrospectionData.build(builder, clazz);
    final methods = await builder.methodsOf(clazz);

    await (
      _defineGet(builder, introspectionData, methods),
      _defineSet(builder, introspectionData, methods),
    ).wait;
  }

  Future<bool> _checkMethodNotPresent(
      DeclarationBuilder builder,
      ClassDeclaration clazz,
      String methodName) async {
    final methods = await builder.constructorsOf(clazz);
    final method = methods.firstWhereOrNull((c) => c.identifier.name == methodName);
    if (method != null) {
      builder.report(Diagnostic(
          DiagnosticMessage(
              'Cannot generate a $methodName method due to this existing one.',
              target: method.asDiagnosticTarget),
          Severity.error));
      return false;
    }
    return true;
  }

  Future<void> _declareGet(
      ClassDeclaration clazz,
      MemberDeclarationBuilder builder,
      Identifier obj,
      Identifier str) async {
    if (!(await _checkMethodNotPresent(builder, clazz, 'get'))) return;

    builder.declareInType(DeclarationCode.fromParts([
      '  external ',
      NamedTypeAnnotationCode(name: obj).asNullable,
      ' get<T>(',
      NamedTypeAnnotationCode(name: str).asNonNullable,
      ' field);',
    ]));
  }

  Future<void> _declareSet(
      ClassDeclaration clazz,
      MemberDeclarationBuilder builder,
      Identifier obj,
      Identifier str) async {
    if (!(await _checkMethodNotPresent(builder, clazz, 'set'))) return;
    builder.declareInType(DeclarationCode.fromParts([
      '  external set(',
      NamedTypeAnnotationCode(name: str).asNonNullable,
      ' field, ',
      NamedTypeAnnotationCode(name: obj).asNullable,
      ' value);',
    ]));
  }

  Future<void> _defineGet(
      TypeDefinitionBuilder builder,
      _SharedIntrospectionData introspectionData,
      List<MethodDeclaration> methods) async {
    final get =
        methods.firstWhereOrNull((c) => c.identifier.name == 'get');

    if (get == null) return;

    final methodBuilder = await builder.buildMethod(get.identifier);

    final parts = <Object>[
      '{\n    final fieldMap = {\n',
    ];

    Code addEntryForField(field) {
      return RawCode.fromParts([
        "      r'",
        field.identifier.name,
        "': ",
        field.identifier.name,
        ',\n',
      ]);
    }

    parts.addAll(introspectionData.fields.map(addEntryForField));
    parts.addAll(introspectionData.getters.map(addEntryForField));
    parts.addAll([
      '    };\n',
      '    return fieldMap[field];\n'
      '  }'
    ]);

    methodBuilder.augment(FunctionBodyCode.fromParts(parts));
  }

  Future<void> _defineSet(
      TypeDefinitionBuilder builder,
      _SharedIntrospectionData introspectionData,
      List<MethodDeclaration> methods) async {
    final set =
        methods.firstWhereOrNull((c) => c.identifier.name == 'set');

    if (set == null) return;

    final methodBuilder = await builder.buildMethod(set.identifier);
    final fields = introspectionData.fields.where((f) => !(f.hasFinal || f.hasConst)).toList();
    final parts = <Object>[
      '{\n    switch (field) {\n',
    ];

    Code addEntryForDeclaration(field) {
      final type = field is MethodDeclaration ?
        field.positionalParameters.first.type.code : field.type.code;
      return RawCode.fromParts([
        "      case r'",
        field.identifier.name,
        "':\n        ",
        field.identifier.name,
        ' = value as ',
        type,
        ';\n       ',
        ' break;\n'
      ]);
    }

    parts.addAll(fields.map(addEntryForDeclaration));
    parts.addAll(introspectionData.setters.map(addEntryForDeclaration));
    parts.addAll([
      '      default:\n',
      '        throw \'Field \$field not found!\';\n',
      '    };\n',
      '  }'
    ]);

    methodBuilder.augment(FunctionBodyCode.fromParts(parts));
  }
}

final _dartCore = Uri.parse('dart:core');

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) compare) {
    for (final item in this) {
      if (compare(item)) return item;
    }
    return null;
  }
}

final class _SharedIntrospectionData {
  /// The declaration of the class we are generating for.
  final ClassDeclaration clazz;

  /// All the fields on the [clazz].
  final List<FieldDeclaration> fields;

  /// All the getters on the [clazz].
  final List<MethodDeclaration> getters;

  /// All the setters on the [clazz].
  final List<MethodDeclaration> setters;

  /// The declaration of the superclass of [clazz], if it is not [Object].
  final ClassDeclaration? superclass;

  _SharedIntrospectionData({
    required this.clazz,
    required this.fields,
    required this.getters,
    required this.setters,
    required this.superclass,
  });

  static Future<_SharedIntrospectionData> build(
      DeclarationPhaseIntrospector builder, ClassDeclaration clazz) async {
    final superclass = clazz.superclass;
    final (fields, superclassDecl, methods) = await (
      builder.fieldsOf(clazz),
      superclass == null
          ? Future.value(null)
          : builder.typeDeclarationOf(superclass.identifier),
      builder.methodsOf(clazz)
    ).wait;
    final getters = methods.where((g) => g.isGetter).toList();
    final setters = methods.where((g) => g.isSetter).toList();

    return _SharedIntrospectionData(
      clazz: clazz,
      fields: fields,
      getters: getters,
      setters: setters,
      superclass: superclassDecl as ClassDeclaration?,
    );
  }
}
