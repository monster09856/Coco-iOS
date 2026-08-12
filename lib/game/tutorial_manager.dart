/// Each step of the on-boarding & obstacle guide.
/// Steps are non-blocking — the overlay sits at the top of the screen,
/// the board stays fully interactive, and a single tap dismisses/advances.
enum TutorialStep {
  welcome(
    level: 1,
    title: 'Hoş Geldin!',
    message: 'Coco dünyasına hoş geldin. Aynı renkten 3 kuşu yan yana getir!',
  ),
  teachSwap(
    level: 1,
    title: 'Kaydır',
    message: 'İki bitişik kuşu kaydır. 3 veya daha fazla aynı renk → patlar.',
  ),
  teachGoals(
    level: 1,
    title: 'Hedefler',
    message: 'Üst paneldeki hedeflere dikkat — hamlen bitmeden topla!',
  ),
  teachSpecial4(
    level: 2,
    title: '🚀 Roket Gücü',
    message: '4 kuşu sıralarsan ROKET oluşur! Tüm satırı veya sütunu siler.',
  ),
  teachCombo(
    level: 2,
    title: '✨ Süper Kombo',
    message: 'Zincirleme eşleşmeler ekstra puan ve patlama gücü getirir!',
  ),
  teachSpecialBomb(
    level: 3,
    title: '💣 Bomba',
    message: 'T veya L şeklinde 5 kuşu eşleştir → BOMBA! Geniş alanı patlatır.',
  ),
  teachBooster(
    level: 4,
    title: '⚡ Güçlendiriciler',
    message: 'Zorlandığında alttaki Çekiç, Renk Bombası ve +3 Hamleyi kullan!',
  ),
  // ─── Obstacle Introductions ─────────────────────────────────────────
  teachIce1(
    level: 9,
    title: '🧊 Yeni Engel: Buz!',
    message: 'Buzlu taşların yanında eşleşme yaparak buzları kır!',
  ),
  teachIce2(
    level: 10,
    title: '❄️ Çift Kat Buz!',
    message: 'Bu sert buzları tamamen kırmak için yanında 2 kez eşleşme yapmalısın!',
  ),
  teachBox(
    level: 14,
    title: '📦 Yeni Engel: Tahta Sandık!',
    message: 'Sandıkların yanındaki taşları patlatarak sandıkları parçala!',
  ),
  teachChain1(
    level: 24,
    title: '⛓️ Yeni Engel: Çelik Zincir!',
    message: 'Zincirli taşlar kilitlidir. Yanında eşleşme yaparak kilidi aç!',
  ),
  teachFog(
    level: 34,
    title: '🌫️ Yeni Engel: Tropikal Sis!',
    message: 'Sisin altındaki taşları görmek ve temizlemek için yakınında patlatma yap!',
  ),
  teachHoney(
    level: 58,
    title: '🍯 Yeni Engel: Yapışkan Bal!',
    message: 'Bal diğer taşlara yayılabilir! Hemen yanında eşleşme yapıp temizle!',
  ),
  teachChocolate(
    level: 72,
    title: '🍫 Yeni Engel: Çikolata!',
    message: 'Çikolatayı her hamlede temizlemezsen yayılır! Yanında eşleşme yaparak yok et!',
  );

  final int level;
  final String title;
  final String message;

  const TutorialStep({
    required this.level,
    required this.title,
    required this.message,
  });
}

/// Manages interactive level tutorials and new obstacle announcements.
class TutorialManager {
  final Set<int> _completedLevels = {};
  TutorialStep? _currentActiveStep;

  TutorialManager({bool startCompleted = false}) {
    if (startCompleted) {
      _completedLevels.addAll(TutorialStep.values.map((s) => s.level));
    }
  }

  bool isVisible(int level) {
    if (_completedLevels.contains(level)) return false;
    return getStepForLevel(level) != null;
  }

  TutorialStep? get currentStep => _currentActiveStep;

  TutorialStep? getStepForLevel(int level) {
    if (_completedLevels.contains(level)) return null;
    try {
      return TutorialStep.values.firstWhere((s) => s.level == level);
    } catch (_) {
      return null;
    }
  }

  bool shouldShowForLevel(int level) {
    if (_completedLevels.contains(level)) return false;
    final step = getStepForLevel(level);
    if (step != null) {
      _currentActiveStep = step;
      return true;
    }
    return false;
  }

  void advance(int level) {
    _completedLevels.add(level);
    _currentActiveStep = null;
  }

  void skip(int level) {
    _completedLevels.add(level);
    _currentActiveStep = null;
  }
}
