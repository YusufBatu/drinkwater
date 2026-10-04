import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../widgets/plant_character_widget.dart';
import '../widgets/step_card_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final waterProvider = Provider.of<WaterProvider>(context);

    if (waterProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final todayLogs = waterProvider.todayLogs;
    final int todayTotal = waterProvider.todayIntake;
    final int target = waterProvider.dailyTarget;
    final double progress = (waterProvider.progressRatio).clamp(0.0, 1.0);
    final int percentage = (waterProvider.progressRatio * 100).toInt();
    final String formattedDate = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DrinkWater',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              formattedDate,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Su Hedefini Düzenle',
            onPressed: () => _showEditTargetDialog(context, waterProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 12),

            // --- 1. Büyüyen Bitki Karakteri ---
            PlantCharacterWidget(
              progress: waterProvider.progressRatio,
              todayTotal: todayTotal,
              target: target,
            ),

            const SizedBox(height: 12),

            // --- 2. Günlük Adımsayar Kartı ---
            const StepCardWidget(),

            const SizedBox(height: 12),

            // --- 3. Dairesel Su İlerleme Göstergesi ---
            _buildProgressCard(context, todayTotal, target, percentage, progress, waterProvider),

            const SizedBox(height: 14),

            // --- 4. Hızlı Su Ekleme Butonları ---
            _buildQuickAddSection(context, waterProvider),

            const SizedBox(height: 16),

            // --- 5. Bugünün Kayıt Listesi Başlığı & Geri Al Butonu ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bugünkü Su Kayıtları (${todayLogs.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (todayLogs.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final removed = await waterProvider.undoLastLog();
                        if (removed != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${removed.amount} ml geri alındı.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Geri Al'),
                    ),
                ],
              ),
            ),

            const Divider(height: 1, indent: 20, endIndent: 20),
            const SizedBox(height: 8),

            // --- 6. Bugünün Kayıt Listesi ---
            if (todayLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop_outlined, size: 48, color: Colors.blue.withValues(alpha: 0.3)),
                      const SizedBox(height: 6),
                      Text(
                        'Bugün henüz su kaydı eklemedin.',
                        style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...todayLogs.map((log) {
                final timeStr = DateFormat('HH:mm').format(log.timestamp);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: Card(
                    elevation: 0.5,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withValues(alpha: 0.15),
                        child: const Icon(Icons.water_drop, color: Colors.blue),
                      ),
                      title: Text(
                        '${log.amount} ml',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Saat: $timeStr'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Sil',
                        onPressed: () => waterProvider.removeLog(log.id),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // Dairesel Su Gösterge Kartı
  Widget _buildProgressCard(
    BuildContext context,
    int todayTotal,
    int target,
    int percentage,
    double progress,
    WaterProvider provider,
  ) {
    final theme = Theme.of(context);
    final bool isCompleted = provider.isTargetReached;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Dairesel Progress
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 86,
                height: 86,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.blue.withValues(alpha: 0.15),
                  color: isCompleted ? Colors.green : Colors.blue,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '%$percentage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green : Colors.blue,
                    ),
                  ),
                  if (isCompleted)
                    const Icon(Icons.check_circle, color: Colors.green, size: 15),
                ],
              ),
            ],
          ),

          // Bilgi Metinleri
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Günlük Su Tüketimi',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$todayTotal',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' / $target ml',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isCompleted
                      ? '🎉 Su Hedefi Tamamlandı!'
                      : 'Kalan: ${provider.remainingIntake} ml',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.green[800] : Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Hızlı Ekleme Butonları
  Widget _buildQuickAddSection(BuildContext context, WaterProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Hızlı Su Ekle',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Row(
            children: [
              _buildAddButton(context, provider, amount: 200, label: 'Bardak', icon: Icons.local_drink),
              const SizedBox(width: 8),
              _buildAddButton(context, provider, amount: 300, label: 'Kupa', icon: Icons.coffee),
              const SizedBox(width: 8),
              _buildAddButton(context, provider, amount: 500, label: 'Şişe', icon: Icons.sports_bar_outlined),
              const SizedBox(width: 8),
              _buildCustomAddButton(context, provider),
            ],
          ),
        ],
      ),
    );
  }

  // Tekil Hızlı Ekle Butonu
  Widget _buildAddButton(
    BuildContext context,
    WaterProvider provider, {
    required int amount,
    required String label,
    required IconData icon,
  }) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1,
        ),
        onPressed: () {
          provider.addWater(amount);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('+$amount ml su eklendi 💧'),
              duration: const Duration(milliseconds: 1200),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.blue),
            const SizedBox(height: 3),
            Text(
              '+$amount ml',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  // Özel Miktar Giriş Butonu
  Widget _buildCustomAddButton(BuildContext context, WaterProvider provider) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => _showCustomAmountDialog(context, provider),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 20, color: Colors.blue),
            SizedBox(height: 3),
            Text(
              'Özel',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Text(
              'Miktar',
              style: TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  // Özel Miktar Dialog'u
  void _showCustomAmountDialog(BuildContext context, WaterProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Özel Miktar Ekle'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Miktar (ml)',
              hintText: 'Örn: 250',
              suffixText: 'ml',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val != null && val > 0) {
                  provider.addWater(val);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('+$val ml eklendi 💧')),
                  );
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  // Hedef Düzenleme Dialog'u
  void _showEditTargetDialog(BuildContext context, WaterProvider provider) {
    final targetController = TextEditingController(text: provider.dailyTarget.toString());
    final weightController = TextEditingController(
      text: provider.userWeight != null ? provider.userWeight!.toInt().toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Günlük Su Hedefi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manuel Hedef Belirle:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Günlük Hedef (ml)',
                    suffixText: 'ml',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Veya Kiloya Göre Otomatik Hesapla:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bilimsel formül: Kilo × 35 ml',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kilonuz (kg)',
                          suffixText: 'kg',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () {
                        final w = double.tryParse(weightController.text.trim());
                        if (w != null && w > 0) {
                          provider.calculateAndSetTargetFromWeight(w);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Kilonuza göre hedef ${provider.dailyTarget} ml yapıldı.')),
                          );
                        }
                      },
                      child: const Text('Hesapla'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                final target = int.tryParse(targetController.text.trim());
                if (target != null && target >= 500) {
                  provider.setDailyTarget(target);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hedef $target ml olarak güncellendi.')),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }
}
