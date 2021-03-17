import 'package:dioc/dioc.dart';

import 'instance.dart';

part 'test.g.dart';

@bootstrapper
abstract class Test extends Bootstrapper {
  @Provide(Instance, InstanceImpl)
  Container production();
}
