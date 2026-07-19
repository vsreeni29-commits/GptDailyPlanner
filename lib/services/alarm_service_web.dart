import 'alarm_service_contract.dart';

AlarmScheduler createAlarmScheduler() => WebAlarmScheduler();

class WebAlarmScheduler implements AlarmScheduler {
  static const _result = AlarmResult(
    isSupported: false,
    isReady: false,
    message:
        'Web mode: OS alarms are skipped. Live countdowns and planning still work.',
  );

  @override
  Future<AlarmResult> initializeAndRequestPermissions() async => _result;

  @override
  Future<AlarmResult> replaceAll(List<AlarmEntry> entries) async => _result;
}
