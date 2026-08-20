class Command {
  final String id;
  final String deviceId;
  final String action;
  final String source;
  final String status;
  final String owner;
  final DateTime requestedAt;
  final DateTime? acknowledgedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? expiresAt;
  final String? requestedBy;
  final String? reason;
  final int? durationSeconds;

  const Command({
    required this.id,
    required this.deviceId,
    required this.action,
    this.source = 'manual',
    this.status = 'pending',
    required this.owner,
    required this.requestedAt,
    this.acknowledgedAt,
    this.startedAt,
    this.endedAt,
    this.expiresAt,
    this.requestedBy,
    this.reason,
    this.durationSeconds,
  });

  factory Command.fromMap(String id, Map<String, dynamic> data) {
    return Command(
      id: id,
      deviceId: data['deviceId'] as String? ?? '',
      action: data['action'] as String? ?? 'unknown',
      source: data['source'] as String? ?? 'manual',
      status: data['status'] as String? ?? 'pending',
      owner: data['owner'] as String? ?? '',
      requestedAt: data['requestedAt'] != null
          ? DateTime.tryParse(data['requestedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      acknowledgedAt: data['acknowledgedAt'] != null
          ? DateTime.tryParse(data['acknowledgedAt'] as String)
          : null,
      startedAt: data['startedAt'] != null
          ? DateTime.tryParse(data['startedAt'] as String)
          : null,
      endedAt: data['endedAt'] != null
          ? DateTime.tryParse(data['endedAt'] as String)
          : null,
      expiresAt: data['expiresAt'] != null
          ? DateTime.tryParse(data['expiresAt'] as String)
          : null,
      requestedBy: data['requestedBy'] as String?,
      reason: data['reason'] as String?,
      durationSeconds: (data['durationSeconds'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'deviceId': deviceId,
        'action': action,
        'source': source,
        'status': status,
        'owner': owner,
        'requestedAt': requestedAt.toIso8601String(),
        if (acknowledgedAt != null)
          'acknowledgedAt': acknowledgedAt!.toIso8601String(),
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (requestedBy != null) 'requestedBy': requestedBy,
        if (reason != null) 'reason': reason,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      };
}
