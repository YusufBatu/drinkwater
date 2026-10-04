class WaterLog {
  final String id;
  final int amount; // ml cinsinden
  final DateTime timestamp;

  WaterLog({
    required this.id,
    required this.amount,
    required this.timestamp,
  });

  // JSON dönüşümleri (Telefonda saklamak için)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WaterLog.fromJson(Map<String, dynamic> json) {
    return WaterLog(
      id: json['id'] as String,
      amount: json['amount'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
