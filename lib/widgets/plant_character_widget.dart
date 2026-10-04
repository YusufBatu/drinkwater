import 'package:flutter/material.dart';

class PlantCharacterWidget extends StatefulWidget {
  final double progress; // 0.0 ile 1.0 arası veya üstü
  final int todayTotal;
  final int target;

  const PlantCharacterWidget({
    super.key,
    required this.progress,
    required this.todayTotal,
    required this.target,
  });

  @override
  State<PlantCharacterWidget> createState() => _PlantCharacterWidgetState();
}

class _PlantCharacterWidgetState extends State<PlantCharacterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;
  bool _showBubble = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _onTapPlant() {
    _bounceController.forward().then((_) => _bounceController.reverse());
    setState(() {
      _showBubble = !_showBubble;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plantState = _getPlantState(widget.progress);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: plantState.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plantState.borderColor,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Tıklanabilir & Animasyonlu Bitki Karakteri
          GestureDetector(
            onTap: _onTapPlant,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: plantState.borderColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    plantState.emoji,
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Bitki Durum Bilgisi & Konuşma Balonu
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plantState.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: plantState.textColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: plantState.badgeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        plantState.stageLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: plantState.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  plantState.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                // Bitkinin büyüme seviye çubuğu
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: widget.progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.black.withValues(alpha: 0.06),
                    color: plantState.progressColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Yüzdeye göre bitki durumunu hesapla
  _PlantState _getPlantState(double progress) {
    if (progress >= 1.0) {
      return _PlantState(
        emoji: '🌺',
        stageLabel: '5. Aşama',
        title: 'Çiçek Açtı! 🌸',
        message: 'Tebrikler! Bugün yeterince su içtin, çiçeğin mutlulukla açtı!',
        backgroundColor: const Color(0xFFF0FDF4),
        borderColor: const Color(0xFF86EFAC),
        textColor: const Color(0xFF15803D),
        badgeColor: const Color(0xFFDCFCE7),
        progressColor: const Color(0xFF22C55E),
      );
    } else if (progress >= 0.75) {
      return _PlantState(
        emoji: '🪴',
        stageLabel: '4. Aşama',
        title: 'Tomurcuklandı! 🌿',
        message: 'Harika gidiyorsun! Çiçek açmasına çok az kaldı.',
        backgroundColor: const Color(0xFFF0FDF4),
        borderColor: const Color(0xFFBBF7D0),
        textColor: const Color(0xFF166534),
        badgeColor: const Color(0xFFDCFCE7),
        progressColor: const Color(0xFF16A34A),
      );
    } else if (progress >= 0.50) {
      return _PlantState(
        emoji: '🌿',
        stageLabel: '3. Aşama',
        title: 'Genç Fidan 🍃',
        message: 'Günün yarısını tamamladın! Bitkin güçleniyor ve büyüyor.',
        backgroundColor: const Color(0xFFF0F9FF),
        borderColor: const Color(0xFFBAE6FD),
        textColor: const Color(0xFF0369A1),
        badgeColor: const Color(0xFFE0F2FE),
        progressColor: const Color(0xFF0EA5E9),
      );
    } else if (progress >= 0.25) {
      return _PlantState(
        emoji: '🌱',
        stageLabel: '2. Aşama',
        title: 'Küçük Filiz 💧',
        message: 'Bitkin ilk suyunu aldı ve topraktan filizlendi.',
        backgroundColor: const Color(0xFFF8FAFC),
        borderColor: const Color(0xFFCBD5E1),
        textColor: const Color(0xFF334155),
        badgeColor: const Color(0xFFF1F5F9),
        progressColor: const Color(0xFF64748B),
      );
    } else {
      return _PlantState(
        emoji: '🥀',
        stageLabel: '1. Aşama',
        title: 'Susuz Kaldı 😢',
        message: 'Bitkin kurumak üzere! Kendin ve onun için bir bardak su iç.',
        backgroundColor: const Color(0xFFFFFBEB),
        borderColor: const Color(0xFFFDE68A),
        textColor: const Color(0xFFB45309),
        badgeColor: const Color(0xFFFEF3C7),
        progressColor: const Color(0xFFF59E0B),
      );
    }
  }
}

class _PlantState {
  final String emoji;
  final String stageLabel;
  final String title;
  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color badgeColor;
  final Color progressColor;

  _PlantState({
    required this.emoji,
    required this.stageLabel,
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.badgeColor,
    required this.progressColor,
  });
}
