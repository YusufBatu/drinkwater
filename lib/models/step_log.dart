class StepLog {
  final String dateKey; // 'yyyy-MM-dd'
  final int steps;
  final int target;
  final double distanceKm;
  final int calories;

  StepLog({
    required this.dateKey,
    required this.steps,
    required this.target,
    required this.distanceKm,
    required this.calories,
  });

  bool get isCompleted => steps >= target;

  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'steps': steps,
      'target': target,
      'distanceKm': distanceKm,
      'calories': calories,
    };
  }

  factory StepLog.fromJson(Map<String, dynamic> json) {
    return StepLog(
      dateKey: json['dateKey'] as String,
      steps: json['steps'] as int,
      target: json['target'] as int? ?? 8000,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      calories: json['calories'] as int? ?? 0,
    );
  }
}
