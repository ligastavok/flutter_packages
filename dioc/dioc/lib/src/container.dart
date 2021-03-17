const String _kEmptyCreator = '';
const String _kEmptyName = '';

/// An instance factory of a given type.
typedef T Creator<T>(Container container);

// Describes how instances can be injected.
enum InjectMode {
  unspecified,
  singleton,
  create,
}

/// A dependency container responsible for instantiating objects.
class Container {
  /// All registered factories.
  Map<Type, Factory> _factories = Map<Type, Factory>();

  /// Registers a [creator] that describes how to build an instance of a
  /// given [type] and optional [name]. The [defaultMode] describe the default
  /// behaviour when accessing an instance with get method.
  void register<T>(Creator<T> creator, {String name = _kEmptyName, InjectMode defaultMode = InjectMode.unspecified}) {
    final factory = _getOrCreateFactory<T>(defaultMode);
    factory.register(name, creator);
  }

  /// Unregisters the factory for [type] and optional [name].
  void unregister<T>({String name = _kEmptyName}) {
    final map = _factories[T];
    map?.unregister(name);
  }

  /// Unregisters all [factories].
  void reset() {
    _factories = Map<Type, Factory>();
  }

  /// Gets the global instance of [type] with an optional [name]. It creates an instance
  /// at first call and then returns it each time it is requested.
  /// A [creator] name could be precised to use specific registered factory for first
  /// instantiation.
  T singleton<T>({String name = _kEmptyName, String creator = _kEmptyCreator}) {
    final result = this._getFactory<T>();
    return result!.singleton(name: name, creator: creator);
  }

  /// Creates a new instance of [type] through the registered factory. A [creator] name could be precised
  /// to use specific registered creator.
  T create<T>({String creator = _kEmptyCreator}) {
    final result = this._getFactory<T>();
    return result!.create(creator: creator);
  }

  /// Creates a new instance of [type] through the registered factory. A [creator] name could be precised
  /// to use specific registered creator. A [mode] can be precised, if not the default registered mode is
  /// used.
  T get<T>({String name = _kEmptyName, String creator = _kEmptyCreator, InjectMode mode = InjectMode.unspecified}) {
    final result = this._getFactory<T>();

    return result!.get(name: name, creator: creator, mode: mode);
  }

  T? safeGet<T>({String name = _kEmptyName, String creator = _kEmptyCreator, InjectMode mode = InjectMode.unspecified}) {
    final result = this._getFactory<T>(safeGet: true);

    return result?.get(name: name, creator: creator, mode: mode);
  }

  /// A shortcut for get<T> method
  T call<T>({String name = _kEmptyName, String creator = _kEmptyCreator, InjectMode mode = InjectMode.unspecified}) {
    return get<T>(name: name, creator: creator, mode: mode);
  }

  /// Indicates whether this container has a factory for [type] with the given [creator] name.
  bool has<T>({String creator = _kEmptyCreator}) {
    final map = _factories[T];
    return (map != null) && map.has(creator: creator);
  }

  bool hasAll(List<Type> types, {String creator = _kEmptyCreator}) {
    return types.every((t) {
      final map = _factories[t];

      return (map != null) && map.has(creator: creator);
    });
  }

  Factory<T> _getOrCreateFactory<T>(InjectMode defaultMode) {
    return this._factories.putIfAbsent(T, () => Factory<T>(this, defaultMode: defaultMode)) as Factory<T>;
  }

  Factory<T>? _getFactory<T>({bool safeGet = false}) {
    Factory<T>? factory = this._factories[T] as Factory<T>?;

    if (factory == null) {
      if (safeGet) return null;

      throw ("No registered type '$T'");
    }

    return factory;
  }
}

class Factory<T> {
  InjectMode defaultMode;
  Container _container;
  Map<String, Creator> _creators = {};
  Map<String, dynamic> _singletons = {};

  Factory(this._container, {this.defaultMode = InjectMode.unspecified});

  void register(String name, Creator<T> creator) {
    this._creators[name] = creator;
  }

  void unregister(String name) {
    this._creators.remove(name);
  }

  T call({String name = _kEmptyName, String creator = _kEmptyCreator, InjectMode mode = InjectMode.unspecified}) {
    return this.get(name: name, creator: creator, mode: mode);
  }

  T get({String name = _kEmptyName, String creator = _kEmptyCreator, InjectMode mode = InjectMode.unspecified}) {
    if (mode == InjectMode.unspecified) {
      mode = this.defaultMode;
    }

    if (mode == InjectMode.create) {
      return this.create(creator: creator);
    }

    return this.singleton(creator: creator, name: name);
  }

  T singleton({String name = _kEmptyName, String creator = _kEmptyCreator}) {
    return _singletons.putIfAbsent(name, () => this.create(creator: creator));
  }

  /// Creates a new instance with the given [creator].
  T create({String creator = _kEmptyCreator}) {
    final builder = _creators[creator];

    if (builder == null) throw ("No creator with name '$creator' found for type '$T'");

    return builder(this._container);
  }

  bool has({String creator = _kEmptyCreator}) {
    return _creators.containsKey(creator);
  }
}
