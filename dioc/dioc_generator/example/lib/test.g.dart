// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test.dart';

// **************************************************************************
// BootstrapperGenerator
// **************************************************************************

class _Test extends Test {
  Container base() {
    final container = Container();
    return container;
  }

  Container production() {
    final container = this.base();
    container.register<Instance>((c) => InstanceImpl(),
        defaultMode: InjectMode.unspecified);

    return container;
  }
}

class TestBuilder {
  static final _Test instance = build();

  static _Test build() {
    return new _Test();
  }
}
