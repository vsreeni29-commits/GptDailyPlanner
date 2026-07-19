export 'alarm_service_stub.dart'
    if (dart.library.io) 'alarm_service_mobile.dart'
    if (dart.library.js_interop) 'alarm_service_web.dart';
