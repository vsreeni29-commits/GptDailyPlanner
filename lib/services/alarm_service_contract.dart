class AlarmEntry {
  const AlarmEntry({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final String payload;
}

class AlarmResult {
  const AlarmResult({
    required this.isSupported,
    required this.isReady,
    this.message,
  });

  final bool isSupported;
  final bool isReady;
  final String? message;
}

abstract interface class AlarmScheduler {
  Future<AlarmResult> initializeAndRequestPermissions();
  Future<AlarmResult> replaceAll(List<AlarmEntry> entries);
}
