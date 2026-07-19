import 'alarm_service_contract.dart';

AlarmScheduler createAlarmScheduler() => UnsupportedAlarmScheduler();

class UnsupportedAlarmScheduler implements AlarmScheduler {
  @override
  Future<AlarmResult> initializeAndRequestPermissions() async =>
      const AlarmResult(
        isSupported: false,
        isReady: false,
        message: 'Alarms are not supported on this platform.',
      );

  @override
  Future<AlarmResult> replaceAll(List<AlarmEntry> entries) =>
      initializeAndRequestPermissions();
}
