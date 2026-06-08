import 'package:flutter/foundation.dart';

void logD(Object? msg) {
  if (kDebugMode) debugPrint('$msg');
}
