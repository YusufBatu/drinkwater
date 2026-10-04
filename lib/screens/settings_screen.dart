import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../providers/step_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final waterProvider = Provider.of<WaterProvider>(context);
    final stepProvider = Provider.of<StepProvider>(context);
    final theme = Theme.of(context);

    final String wakeTimeStr =
        '${waterProvider.wakeUpHour.toString().padLeft(2, '0')}:${waterProvider.wakeUpMinute.toString().padLeft(2, '0')}';
    final String bedTimeStr =
        '${waterProvider.bedTimeHour.toString().padLeft(2, '0')}:${waterProvider.bedTimeMinute.toString().padLeft(2, '0')}';
    final String intervalLabel = _getIntervalLabel(waterProvider.reminderIntervalMinutes);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ayarlar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // --- 1. Hedef ve Profil Bölümü ---
          _buildSectionHeader(context, 'HEDEF & PROFİL'),
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                // Günlük Su Hedefi
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.water_drop, color: Colors.blue),
                  ),
                  title: const Text('Günlük Su Hedefi'),
                  subtitle: Text('${waterProvider.dailyTarget} ml / gün'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showEditTargetDialog(context, waterProvider),
                ),
                const Divider(height: 1, indent: 64),
                // Günlük Adım Hedefi
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Icon(Icons.directions_walk, color: Colors.green),
                  ),
                  title: const Text('Günlük Adım Hedefi'),
                  subtitle: Text('${stepProvider.stepTarget} adım / gün'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showEditStepTargetDialog(context, stepProvider),
                ),
                const Divider(height: 1, indent: 64),
                // Kilo ile Su Hedefi Hesaplayıcı
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.monitor_weight_outlined, color: Colors.blue),
                  ),
                  title: const Text('Kilo ile Su Hedefi Hesapla'),
                  subtitle: Text(
                    waterProvider.userWeight != null
                        ? '${waterProvider.userWeight!.toInt()} kg (Önerilen: ${(waterProvider.userWeight! * 35).round()} ml)'
                        : 'Kilonuzu girerek ideal su hedefini bulun',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showWeightCalculatorDialog(context, waterProvider),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- 2. Akıllı Bildirim & Hatırlatıcı Bölümü ---
          _buildSectionHeader(context, 'BİLDİRİM & HATIRLATICI'),
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                // Bildirim Açık/Kapalı
                SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: const Color(0xFFFEF3C7),
                    child: Icon(
                      waterProvider.notificationsEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off_outlined,
                      color: Colors.amber[800],
                    ),
                  ),
                  title: const Text('Su İçme Hatırlatıcıları'),
                  subtitle: Text(
                    waterProvider.notificationsEnabled
                        ? 'Düzenli aralıklarla bildirim gönderiliyor'
                        : 'Bildirimler kapalı',
                  ),
                  value: waterProvider.notificationsEnabled,
                  onChanged: (val) async {
                    await waterProvider.toggleNotifications(val);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Bildirimler açıldı 🔔' : 'Bildirimler kapatıldı 🔕'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                if (waterProvider.notificationsEnabled) ...[
                  const Divider(height: 1, indent: 64),
                  // Hatırlatma Sıklığı
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(Icons.timer_outlined, color: Colors.amber),
                    ),
                    title: const Text('Hatırlatma Sıklığı'),
                    subtitle: Text(intervalLabel),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showIntervalPicker(context, waterProvider),
                  ),
                  const Divider(height: 1, indent: 64),
                  // Sessiz Saatler: Uyanma Saati
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(Icons.wb_sunny_outlined, color: Colors.amber),
                    ),
                    title: const Text('Uyanma Saati'),
                    subtitle: Text('Bildirim başlangıcı: $wakeTimeStr'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickWakeTime(context, waterProvider),
                  ),
                  const Divider(height: 1, indent: 64),
                  // Sessiz Saatler: Uyku Saati
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(Icons.bedtime_outlined, color: Colors.amber),
                    ),
                    title: const Text('Uyku Saati'),
                    subtitle: Text('Bildirim bitişi: $bedTimeStr (Sessiz mod)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickBedTime(context, waterProvider),
                  ),
                  const Divider(height: 1, indent: 64),
                  // Anında Test Bildirimi Butonu
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Icon(Icons.send_outlined, color: Colors.green),
                    ),
                    title: const Text(
                      'Test Bildirimi Gönder',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                    subtitle: const Text('Sistemin çalıştığını hemen test et'),
                    onTap: () async {
                      await waterProvider.sendTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test bildirimi telefonunuza gönderildi! 📱'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- 3. Veri Yönetimi ---
          _buildSectionHeader(context, 'VERİ & DEPOLAMA'),
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.withValues(alpha: 0.15),
                child: const Icon(Icons.delete_forever, color: Colors.redAccent),
              ),
              title: const Text(
                'Tüm Kayıtları Sıfırla',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Bugünkü ve geçmiş tüm su ve adım verilerini siler'),
              onTap: () => _showResetConfirmationDialog(context, waterProvider),
            ),
          ),

          const SizedBox(height: 24),

          // --- 4. Uygulama Bilgisi ---
          Center(
            child: Column(
              children: [
                Icon(Icons.health_and_safety_outlined, size: 36, color: Colors.blue.withValues(alpha: 0.4)),
                const SizedBox(height: 6),
                const Text(
                  'LifeTrack / DrinkWater v1.1.0',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Sağlıklı su ve aktif adım takibi asistanı.',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.outline,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  String _getIntervalLabel(int minutes) {
    if (minutes == 30) return 'Her 30 dakikada bir';
    if (minutes == 45) return 'Her 45 dakikada bir';
    if (minutes == 60) return 'Her 1 saatte bir';
    if (minutes == 90) return 'Her 1.5 saatte bir';
    if (minutes == 120) return 'Her 2 saatte bir';
    if (minutes == 180) return 'Her 3 saatte bir';
    return 'Her $minutes dakikada bir';
  }

  // Hatırlatma Sıklığı Seçici BottomSheet
  void _showIntervalPicker(BuildContext context, WaterProvider provider) {
    final intervals = [
      {'label': 'Her 30 dakikada bir', 'min': 30},
      {'label': 'Her 45 dakikada bir', 'min': 45},
      {'label': 'Her 1 saatte bir (Önerilen)', 'min': 60},
      {'label': 'Her 1.5 saatte bir', 'min': 90},
      {'label': 'Her 2 saatte bir', 'min': 120},
      {'label': 'Her 3 saatte bir', 'min': 180},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Hatırlatma Sıklığı Seçin',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ...intervals.map((item) {
                final int m = item['min'] as int;
                final bool isSelected = provider.reminderIntervalMinutes == m;
                return ListTile(
                  title: Text(item['label'] as String),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    provider.setReminderInterval(m);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // Uyanma Saati Seçici
  Future<void> _pickWakeTime(BuildContext context, WaterProvider provider) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: provider.wakeUpHour, minute: provider.wakeUpMinute),
      helpText: 'UYANMA SAATİ SEÇİN',
    );
    if (picked != null) {
      await provider.setWakeTime(picked.hour, picked.minute);
    }
  }

  // Uyku Saati Seçici
  Future<void> _pickBedTime(BuildContext context, WaterProvider provider) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: provider.bedTimeHour, minute: provider.bedTimeMinute),
      helpText: 'UYKU SAATİ SEÇİN',
    );
    if (picked != null) {
      await provider.setBedTime(picked.hour, picked.minute);
    }
  }

  // Manuel Su Hedefi Düzenleme Dialog'u
  void _showEditTargetDialog(BuildContext context, WaterProvider provider) {
    final controller = TextEditingController(text: provider.dailyTarget.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Günlük Su Hedefi'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Hedef Miktar (ml)',
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
                final target = int.tryParse(controller.text.trim());
                if (target != null && target >= 500) {
                  provider.setDailyTarget(target);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Yeni su hedefi: $target ml')),
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

  // Manuel Adım Hedefi Düzenleme Dialog'u
  void _showEditStepTargetDialog(BuildContext context, StepProvider provider) {
    final controller = TextEditingController(text: provider.stepTarget.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Günlük Adım Hedefi'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Adım Hedefi',
              suffixText: 'adım',
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
                final target = int.tryParse(controller.text.trim());
                if (target != null && target >= 1000) {
                  provider.setStepTarget(target);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Yeni adım hedefi: $target adım')),
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

  // Kilo Bazlı Otomatik Hesaplama Dialog'u
  void _showWeightCalculatorDialog(BuildContext context, WaterProvider provider) {
    final controller = TextEditingController(
      text: provider.userWeight != null ? provider.userWeight!.toInt().toString() : '',
    );
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('İdeal Hedef Hesaplayıcı'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Günlük su ihtiyacı formülü: Kilonuz × 35 ml',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Kilonuz (kg)',
                  hintText: 'Örn: 70',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                final weight = double.tryParse(controller.text.trim());
                if (weight != null && weight > 20 && weight < 300) {
                  provider.calculateAndSetTargetFromWeight(weight);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$weight kg için hedef ${provider.dailyTarget} ml olarak ayarlandı!'),
                    ),
                  );
                }
              },
              child: const Text('Hesapla & Ayarla'),
            ),
          ],
        );
      },
    );
  }

  // Veri Sıfırlama Onay Dialog'u
  void _showResetConfirmationDialog(BuildContext context, WaterProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Tüm Verileri Sıfırla?'),
          content: const Text(
            'Bu işlem bugün içtiğiniz suları ve geçmişteki tüm kayıtları kalıcı olarak silecektir. Bu işlem geri alınamaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final allIds = provider.logs.map((l) => l.id).toList();
                for (var id in allIds) {
                  await provider.removeLog(id);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tüm kayıtlar başarıyla sıfırlandı.')),
                  );
                }
              },
              child: const Text('Evet, Sıfırla'),
            ),
          ],
        );
      },
    );
  }
}
