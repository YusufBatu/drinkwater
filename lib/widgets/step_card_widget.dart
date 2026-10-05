import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/step_provider.dart';

class StepCardWidget extends StatelessWidget {
  const StepCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final stepProvider = Provider.of<StepProvider>(context);
    final theme = Theme.of(context);

    final int steps = stepProvider.todaySteps;
    final int target = stepProvider.stepTarget;
    final double progress = stepProvider.progressRatio.clamp(0.0, 1.0);
    final int percent = (stepProvider.progressRatio * 100).toInt();
    final bool isCompleted = stepProvider.isTargetReached;

    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : (isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? (isCompleted ? Colors.green.withValues(alpha: 0.5) : Colors.white12)
              : (isCompleted ? const Color(0xFF86EFAC) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Başlık & Yürüme Durumu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isDark ? Colors.green.withValues(alpha: 0.25) : const Color(0xFFDCFCE7),
                    child: Icon(Icons.directions_walk, size: 20, color: isDark ? Colors.greenAccent : Colors.green[700]),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Günlük Adım',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Row(
                        children: [
                          Icon(
                            stepProvider.isHealthConnectEnabled ? Icons.favorite : Icons.sensors,
                            size: 11,
                            color: stepProvider.isHealthConnectEnabled ? Colors.redAccent : Colors.blueGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stepProvider.isHealthConnectEnabled ? 'Health Connect' : 'Cihaz Sensörü',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  if (stepProvider.isHealthConnectEnabled) ...[
                    IconButton(
                      icon: stepProvider.isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, size: 18),
                      tooltip: 'Senkronize Et',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: stepProvider.isSyncing ? null : () => stepProvider.sync(),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? (isCompleted ? Colors.green.withValues(alpha: 0.2) : Colors.white10)
                          : (isCompleted ? const Color(0xFFDCFCE7) : Colors.blueGrey.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      !stepProvider.isSensorAvailable
                          ? 'İzin Gerekli ⚠️'
                          : isCompleted
                              ? '🎉 Hedef Tamamlandı!'
                              : (stepProvider.isHealthConnectEnabled ? 'Senkronize 🔄' : stepProvider.pedestrianStatus),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: !stepProvider.isSensorAvailable
                            ? Colors.orangeAccent
                            : isCompleted
                                ? (isDark ? Colors.greenAccent : Colors.green[800])
                                : (isDark ? Colors.white70 : Colors.blueGrey[700]),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Adım Sayısı & Yüzde
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$steps',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    ' / $target adım',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              Text(
                '%$percent',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green[700] : const Color(0xFF16A34A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // İlerleme Çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.green.withValues(alpha: 0.12),
              color: const Color(0xFF22C55E),
            ),
          ),

          const SizedBox(height: 14),

          // Alt Metrikler: Mesafe (km) ve Kalori (kcal)
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.place_outlined,
                  iconColor: Colors.blue,
                  title: 'Mesafe',
                  value: '${stepProvider.distanceKm.toStringAsFixed(2)} km',
                  theme: theme,
                ),
              ),
              Container(height: 24, width: 1, color: Colors.grey.withValues(alpha: 0.2)),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.local_fire_department_outlined,
                  iconColor: Colors.orange,
                  title: 'Yakılan',
                  value: '${stepProvider.caloriesBurned} kcal',
                  theme: theme,
                ),
              ),
              Container(height: 24, width: 1, color: Colors.grey.withValues(alpha: 0.2)),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.flag_outlined,
                  iconColor: Colors.purple,
                  title: 'Kalan',
                  value: '${stepProvider.remainingSteps} adım',
                  theme: theme,
                ),
              ),
            ],
          ),

          // Sensör veya İzin Kapalıysa Kullanıcıyı Bilgilendiren Kart
          if (!stepProvider.isSensorAvailable) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Adım sayımı için fiziksel aktivite izni gereklidir.',
                      style: TextStyle(fontSize: 11, color: Colors.amber[900], fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => stepProvider.retryPermissionAndInit(),
                    child: const Text('İzin Ver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }
}
