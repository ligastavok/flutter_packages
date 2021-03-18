import 'dart:async';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:built_collection/built_collection.dart';
import 'package:dioc/dioc.dart';
import 'package:source_gen/source_gen.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

class BootstrapperGenerator extends Generator {
  const BootstrapperGenerator({
    this.forClasses: true,
    this.forLibrary: false,
  });

  final bool forClasses;
  final bool forLibrary;

  String _capitalize(String str) {
    return '${str[0].toUpperCase()}${str.substring(1)}';
  }

  @override
  Future<String> generate(LibraryReader library, BuildStep builtStep) async {
    StringBuffer output = StringBuffer();

    final Iterable<AnnotatedElement> bootstrappers = library.annotatedWith(const TypeChecker.fromRuntime(Bootstrapper));

    final List<Class> classes = <Class>[];

    bootstrappers.forEach((AnnotatedElement bootstrapper) {
      final Element element = bootstrapper.element;

      if (element is ClassElement) {
        print('bootstr name = ${element.name}');
        final ClassBuilder bootstrapperClassBuilder = ClassBuilder()
          ..name = '_${element.name}'
          ..extend = refer(
            element.name,
            element.librarySource.uri.toString(),
          );

        // Default environment
        final List<AnnotatedElement> defaultProviders = _findAnnotation(element, Provide);

        bootstrapperClassBuilder.methods.add(_generateEnvironmentMethod('base', true, defaultProviders));

        // annotated part fields
        final Iterable<FieldElement> annotatedPartFields = element.fields.where((FieldElement field) {
          return TypeChecker.fromRuntime(PartProvider).hasAnnotationOfExact(field);
        });

        // environments
        element.methods.forEach((MethodElement method) {
          if (method.returnType.getDisplayString(withNullability: false) != 'Container') {
            throw ('A bootstrapper must have only method with a Container returnType');
          }

          // generate part methods
          Iterable<Method> partMethodList = _generatePartMethod(annotatedPartFields, method);
          partMethodList.forEach((Method partMethod) {
            bootstrapperClassBuilder.methods.add(partMethod);
          });

          final List<AnnotatedElement> methodProviders = _findAnnotation(method, Provide);
          bootstrapperClassBuilder.methods.add(_generateEnvironmentMethod(
            method.name,
            false,
            methodProviders,
            partMethodList: partMethodList,
          ));
        });

        classes.add(bootstrapperClassBuilder.build());

        // Builder class
        final ClassBuilder bootstrapperBuilderClassBuilder = ClassBuilder()..name = '${element.name}Builder';

        bootstrapperBuilderClassBuilder.fields.add(
          Field((b) => b
            ..name = 'instance'
            ..static = true
            ..modifier = FieldModifier.final$
            ..type = refer('_${element.name}')
            ..assignment = Code('build()')),
        );

        bootstrapperBuilderClassBuilder.methods.add(
          Method((b) => b
            ..name = 'build'
            ..static = true
            ..returns = refer('_${element.name}')
            ..body = new Code('return new _${element.name}();')),
        );

        classes.add(bootstrapperBuilderClassBuilder.build());
      }
    });

    // outputs code for each method
    final DartEmitter emitter = DartEmitter();
    classes.forEach((Class c) {
      output.writeln(DartFormatter(pageWidth: 120).format('${c.accept(emitter)}'));
    });
    return '$output';
  }

  Iterable<Method> _generatePartMethod(Iterable<FieldElement> annotatedPartFields, MethodElement method) {
    return annotatedPartFields.where((FieldElement field) {
      // part annotation
      final DartObject ann = TypeChecker.fromRuntime(PartProvider).firstAnnotationOfExact(field);

      // container name
      final String annContainerName = ann.getField('containerName')?.toStringValue();
      if (annContainerName == null) {
        return false;
      }

      return annContainerName == method.name;
    }).map((FieldElement annotatedPartField) {
      // field return type
      DartType fieldPartType = annotatedPartField.type;
      // field class name
      final String fieldPartClassName = fieldPartType.getDisplayString(withNullability: false);
      // field name
      final String fieldPartName = annotatedPartField.name;

      // scanning constructor
      final ClassElement partClass = fieldPartType.element.library.getType(fieldPartClassName);

      final List<AnnotatedElement> partClassProvides = _findAnnotation(partClass, Provide);

      // register part container method
      BlockBuilder code = BlockBuilder();

      partClassProvides.forEach((AnnotatedElement provide) {
        Code statement = _generateRegistration(provide, 0);
        code.statements.add(statement);
      });

      // method params
      ListBuilder<Parameter> partParamList = ListBuilder<Parameter>([
        Parameter(
          (b) => b
            ..name = 'container'
            ..type = refer('Container', 'package:dioc/dioc.dart'),
        ),
      ]);

      // create method
      final String capitalizedFieldPartName = _capitalize(fieldPartName);
      final String partMethodName = '_' + method.name + capitalizedFieldPartName;
      MethodBuilder partMethodBuilder = MethodBuilder()
        ..name = partMethodName
        ..returns = refer('void')
        ..requiredParameters = partParamList
        ..body = code.build();

      final Method partMethod = partMethodBuilder.build();
      return partMethod;
    });
  }

  Method _generateEnvironmentMethod(
    String name,
    bool createContainer,
    List<AnnotatedElement> providers, {
    Iterable<Method> partMethodList = const <Method>[],
  }) {
    BlockBuilder code = BlockBuilder();

    code.statements.add(Code('final container = ${createContainer ? "Container()" : "this.base()"};'));
    for (int i = 0; i < providers.length; i++) {
      final AnnotatedElement provide = providers[i];
      Code statement = _generateRegistration(provide, i);
      code.statements.add(statement);
    }

    partMethodList.forEach((Method method) {
      final String methodName = method.name;

      code.statements.add(Code('$methodName(container);'));
    });

    code.statements.add(Code('return container;'));

    MethodBuilder method = MethodBuilder()
      ..name = name ?? 'base'
      ..returns = refer('Container', 'package:dioc/dioc.dart')
      ..body = code.build();

    return method.build();
  }

  Code _generateRegistration(AnnotatedElement provide, int index) {
    final DartObject annotation = provide.annotation.objectValue;
    String name = annotation.getField('name').toStringValue();
    name = name != null ? ", name: '$name'" : '';

    DartType abstraction = annotation.getField('abstraction').toTypeValue();
    DartType implementation = annotation.getField('implementation').toTypeValue();

    if (implementation == null) {
      print('annotation = $annotation');
      return Code(
          '// TODO: Not found implementation of ${name ?? abstraction?.getDisplayString(withNullability: false)}, index of providers = $index');
    }

    // Scanning constructor
    final implementationClass =
        implementation.element.library.getType(implementation.getDisplayString(withNullability: false));
    final parameters = implementationClass.unnamedConstructor.parameters
        .map((c) => _generateParameter(implementationClass, c))
        .join(', ');

    int modeIndex = annotation?.getField('defaultMode')?.getField('index')?.toIntValue() ?? 0;
    String defaultMode = InjectMode.values[modeIndex].toString().substring(11);

    String reg = '''
      container.register<${abstraction.getDisplayString(withNullability: false)}>
      ((c) => ${implementation.getDisplayString(withNullability: false)}($parameters)$name,
      defaultMode: InjectMode.$defaultMode);
    ''';

    return Code(reg);
  }

  String _generateParameter(ClassElement implementationClass, ParameterElement c) {
    FieldElement field = implementationClass.getField(c.name);
    final injectAnnotation = const TypeChecker.fromRuntime(Inject).firstAnnotationOf(field);

    String name = injectAnnotation?.getField('name')?.toStringValue();
    name = name != null ? "name: '$name'" : '';

    String creator = injectAnnotation?.getField('creator')?.toStringValue();
    creator = creator != null ? (name != '' ? ', ' : '') + "creator: '$creator'" : '';

    int modeIndex = injectAnnotation?.getField('mode')?.getField('index')?.toIntValue() ?? 0;
    String mode = modeIndex == 0 ? 'get' : InjectMode.values[modeIndex].toString().substring(11);

    return (c.isOptionalNamed ? c.name + ': ' : '') +
        'c.$mode<${c.type.getDisplayString(withNullability: false)}>($name$creator)';
  }

  List<AnnotatedElement> _findAnnotation(Element element, Type annotation) {
    return TypeChecker.fromRuntime(annotation)
        .annotationsOf(element)
        .map((DartObject c) => AnnotatedElement(ConstantReader(c), element))
        .toList();
  }

  @override
  String toString() => 'BootstrapperGenerator';
}
