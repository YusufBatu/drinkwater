import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../providers/step_provider.dart';
import '../services/health_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final waterProvider = Provider.of<WaterProvider>(context);
    final stepProvider = Provider.of<StepProvider>(context);
    final theme = Theme.of(context);

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

          // --- 2. Günlük Hatırlatıcı Bölümü ---
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
                        ? 'Her gün 12:00 ve 21:00 saatlerinde hatırlatma gönderilir'
                        : 'Bildirimler kapalı',
                  ),
                  value: waterProvider.notificationsEnabled,
                  onChanged: (val) async {
                    await waterProvider.toggleNotifications(val);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val
                              ? 'Hatırlatıcılar açıldı (12:00 & 21:00) 🔔'
                              : 'Hatırlatıcılar kapatıldı 🔕'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                if (waterProvider.notificationsEnabled) ...[
                  const Divider(height: 1, indent: 64),
                  // Hatırlatma Saatleri Bilgisi
                  const ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(Icons.schedule, color: Colors.amber),
                    ),
                    title: Text('Hatırlatma Saatleri'),
                    subtitle: Text('12:00 (Öğle Molası) • 21:00 (Akşam Özeti)'),
                  ),
                  const Divider(height: 1, indent: 64),
                  // Anında Test Bildirimi Butonu
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Icon(Icons.send_outlined, color: Colors.green),
                    ),
                    title: const Text(
                      'Anında Test Bildirimi',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                    subtitle: const Text('Bildirim ses ve görünümünü hemen dene'),
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

          // --- 3. Adım Takibi & Health Connect ---
          _buildSectionHeader(context, 'ADIM TAKİBİ & HEALTH CONNECT'),
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: const Color(0xFFFEE2E2),
                    child: Icon(Icons.favorite, color: Colors.red[600]),
                  ),
                  title: const Text('Google Health Connect'),
                  subtitle: Text(
                    stepProvider.isHealthConnectEnabled
                        ? 'Aktif (Google Fit ve akıllı saat ile arka planda kesintisiz adım senkronizasyonu)'
                        : 'Kapalı (Yalnızca telefonun yerel adımsayar sensörü kullanılır)',
                  ),
                  value: stepProvider.isHealthConnectEnabled,
                  onChanged: (val) async {
                    if (val) {
                      final success = await stepProvider.enableHealthConnect();
                      if (context.mounted) {
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Google Health Connect bağlandı! Adımlar otomatik senkronize edilecek. 🏃‍♂️'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        } else {
                          final status = await HealthService().checkStatus();
                          if (!context.mounted) return;
                          if (status == HealthServiceStatus.notInstalled) {
                            _showHealthConnectInstallDialog(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Health Connect adım okuma izni verilmedi.'),
                                action: SnackBarAction(
                                  label: 'İzinleri Aç',
                                  onPressed: () => HealthService().openHealthConnectSettings(),
                                ),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        }
                      }
                    } else {
                      await stepProvider.disableHealthConnect();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Health Connect kapatıldı, yerel sensöre dönüldü.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1, indent: 64),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.15),
                    child: const Icon(Icons.tune, color: Colors.blue),
                  ),
                  title: const Text('Health Connect İzinleri'),
                  subtitle: const Text('Sistem izinlerini görüntüle veya aç'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => HealthService().openHealthConnectSettings(),
                ),
                if (stepProvider.isHealthConnectEnabled) ...[
                  const Divider(height: 1, indent: 64),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Icon(Icons.sync, color: Colors.green),
                    ),
                    title: const Text('Şimdi Senkronize Et'),
                    subtitle: Text(
                      stepProvider.lastSyncTime != null
                          ? 'Son güncelleme: ${DateFormat('HH:mm').format(stepProvider.lastSyncTime!)} (${stepProvider.todaySteps} adım)'
                          : 'Henüz senkronize edilmedi',
                    ),
                    trailing: stepProvider.isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    onTap: stepProvider.isSyncing
                        ? null
                        : () async {
                            await stepProvider.sync();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Adımlar senkronize edildi: ${stepProvider.todaySteps} adım 👟'),
                                  duration: const Duration(seconds: 2),
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

          // --- 4. Veri Yönetimi ---
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
              onTap: () => _showResetConfirmationDialog(context, waterProvider, stepProvider),
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
                  'DrinkWater',
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
              onPressed: () async {
                final weight = double.tryParse(controller.text.trim());
                if (weight != null && weight > 20 && weight < 300) {
                  final newTarget = (weight * 35).round();
                  await provider.calculateAndSetTargetFromWeight(weight);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$weight kg için hedef $newTarget ml olarak ayarlandı!'),
                      ),
                    );
                  }
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
  void _showResetConfirmationDialog(
    BuildContext context,
    WaterProvider waterProvider,
    StepProvider stepProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Tüm Verileri Sıfırla?'),
          content: const Text(
            'Bu işlem bugünkü ve geçmişteki tüm su ve adım kayıtlarını kalıcı olarak silecektir. Bu işlem geri alınamaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await waterProvider.clearAllLogs();
                await stepProvider.resetAllStepData();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tüm su ve adım kayıtları başarıyla sıfırlandı.')),
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

  // Health Connect Yükleme Dialog'u
  void _showHealthConnectInstallDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Health Connect Gerekli'),
          ],
        ),
        content: const Text(
          'Arka planda kesintisiz adım sayımı için cihazınızda Google Health Connect yüklü olmalıdır.\n\nPlay Store üzerinden ücretsiz olarak yükleyebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Play Store\'dan Yükle'),
            onPressed: () async {
              Navigator.pop(ctx);
              await HealthService().installHealthConnect();
            },
          ),
        ],
      ),
    );
  }
}
