import 'package:dioc/dioc.dart';

class PartProvider {
  const PartProvider(this.containerName);

  final String containerName;
}

class Inject {
  const Inject({
    this.name,
    this.creator,
    this.mode = InjectMode.singleton,
  });

  final String name;
  final String creator;
  final InjectMode mode;
}

class Provide {
  const Provide.implemented(
    this.abstraction, {
    this.name,
    this.creator,
    this.defaultMode = InjectMode.unspecified,
  }) : implementation = abstraction;

  const Provide(
    this.abstraction,
    this.implementation, {
    this.name,
    this.creator,
    this.defaultMode = InjectMode.unspecified,
  });

  final String name;
  final String creator;
  final Type abstraction;
  final Type implementation;
  final InjectMode defaultMode;
}

class Bootstrapper {
  const Bootstrapper();
}

const inject = const Inject();

const singleton = const Inject(mode: InjectMode.singleton);

const bootstrapper = const Bootstrapper();
