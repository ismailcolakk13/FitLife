import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_application_6/services/streak_service.dart';
import 'calorie_camera_screen.dart';
import 'package:health/health.dart';
import 'activity_detail_screen.dart';
import 'sleep_tracker_screen.dart';
import 'profile_screen.dart';
import 'water_screen.dart';
import "dart:io";

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _stepCount = 0;
  int _streakCount = 5;
  double _sleepHours = 7.5; // Varsayılan uyku saati
  int _dailyCalorieGoal = 2000; //Firebaseden gelmeli
  final Health health = Health();

  late final List<Widget> _screens = [
    _buildDashboard(context),
    SleepTrackerScreen(),
    ActivityDetailScreen(),
    WaterScreen(),
    FoodAnalysisScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndFetchData();
    _checkStreak();
    _fetchUserData();
  }

  // Firebase'den günlük kalori hedefini çeken fonksiyon
  Future<void> _fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          // 'dailyCalorieGoal' alanını int olarak alıyoruz
          _dailyCalorieGoal = (doc.get('dailyCalorieGoal') as num).toInt();
        });
      }
    } catch (e) {
      print("Kullanıcı verisi çekme hatası: $e");
    }
  }

  // Hangi uyku verisini kullanacağımızı dinamik belirliyoruz
  HealthDataType get _sleepType => Platform.isAndroid
      ? HealthDataType
            .SLEEP_ASLEEP // Android için
      : HealthDataType.SLEEP_IN_BED; // iOS için

  Future<void> _requestPermissionsAndFetchData() async {
    try {
      // Platforma göre doğru listeyi oluşturuyoruz
      final types = [
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        _sleepType, // <--- Dinamik tip burada kullanılıyor
      ];

      final permissions = [
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
      ];

      // İzin iste
      bool requested = await health.requestAuthorization(
        types,
        permissions: permissions,
      );

      if (requested) {
        await _fetchHealthData();
      }
    } catch (e) {
      print('İzin Hatası: $e');
    }
  }

  Future<void> _fetchHealthData() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfYesterday = DateTime(now.year, now.month, now.day - 1);

      // Adım ve Kalori verilerini çek
      List<HealthDataPoint> stepsData = await health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: now,
        types: [HealthDataType.STEPS],
      );

      List<HealthDataPoint> caloriesData = await health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: now,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      // Uyku verisini platforma uygun tiple çek
      List<HealthDataPoint> sleepData = await health.getHealthDataFromTypes(
        startTime: startOfYesterday,
        endTime: startOfDay,
        types: [_sleepType], // <--- Burada da dinamik tipi kullanıyoruz
      );

      // --- HESAPLAMA KISMI ---
      int totalSteps = 0;
      double totalSleepMinutes = 0;

      // Güvenli dönüşüm (crash olmaması için)
      for (var data in stepsData) {
        if (data.value is NumericHealthValue) {
          totalSteps += (data.value as NumericHealthValue).numericValue.toInt();
        }
      }

      for (var data in sleepData) {
        if (data.value is NumericHealthValue) {
          totalSleepMinutes += (data.value as NumericHealthValue).numericValue
              .toDouble();
        }
      }

      double sleepHours = totalSleepMinutes / 60;

      setState(() {
        _stepCount = totalSteps;
        if (sleepHours > 0) {
          _sleepHours = sleepHours;
        }
      });
    } catch (e) {
      print('Veri çekme hatası: $e');
      // Hata durumunda varsayılan değerler
      setState(() {
        _stepCount = 0;
        _sleepHours = 0.0;
      });
    }
  }

  StreakService _streakService = StreakService();
  Future<void> _checkStreak() async {
    try {
      // 1. Servisi çağır ve sonucu bekle
      Map<String, dynamic> result = await _streakService.checkAndUpdateStreak();

      int newStreak = result['streak'];
      bool isIncreased = result['increased'];

      // 2. Ekrandaki sayacı güncelle
      setState(() {
        _streakCount = newStreak;
      });

      // 3. Eğer seri arttıysa KUTLAMA yap (Context burada var!)
      if (isIncreased && mounted) {
        // mounted kontrolü ekranın hala açık olduğundan emin olur
        // Biraz gecikmeli göster ki kullanıcı önce ana ekranı görsün
        Future.delayed(const Duration(seconds: 1), () {
          _showStreakCelebration(context, newStreak);
        });
      }
    } catch (e) {
      print("Streak hatası: $e");
    }
  }

  Widget _buildDashboard(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Row(
                // Column yerine Row kullanarak selamlama ve streak'i yan yana alıyoruz
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Günaydın, Ayşe ☀️',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '8 Kasım 2025, Cumartesi',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // STREAK (SERİ) GÖSTERGESİ
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.orange,
                              size: 24,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_streakCount',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed('/profile');
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.green[50],
                          child: Icon(Icons.person, color: color),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: _stepCount / 10000, // 10000 adım hedefi
                          strokeWidth: 12,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_stepCount',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Adım',
                        style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 2.2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _StatCard(
                          title: 'Kalori',
                          value: '1,840 kcal',
                          icon: Icons.local_fire_department,
                          color: Colors.orange,
                        ),
                        _StatCard(
                          title: 'Su',
                          value: '6/8 bardak',
                          icon: Icons.water_drop,
                          color: Colors.blue,
                          onTap: () {
                            setState(() {
                              _selectedIndex = 3;
                            });
                          },
                        ),
                        _StatCard(
                          title: 'Uyku',
                          value: '${_sleepHours.toStringAsFixed(1)} sa',
                          icon: Icons.bedtime,
                          color: Colors.purple,
                          onTap: () {
                            setState(() {
                              _selectedIndex = 1;
                            });
                          },
                        ),
                        _StatCard(
                          title: 'Aktivite',
                          value: '45 dk koşu',
                          icon: Icons.directions_run,
                          color: Colors.green,
                          onTap: () {
                            setState(() {
                              _selectedIndex = 2;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu Haftanın Kalori İstatistiği',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                barTouchData: barTouchData,
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: getTitles,
                                      reservedSize: 38,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: _dailyCalorieGoal
                                          .toDouble(), // Hedef değeri
                                      color: Colors.green.withValues(
                                        alpha: 0.6,
                                      ), // Çizgi rengi (Yeşil veya Kırmızı yapabilirsiniz)
                                      strokeWidth: 2, // Çizgi kalınlığı
                                      dashArray: [
                                        10,
                                        5,
                                      ], // Kesikli çizgi (10 dolu, 5 boş)
                                      label: HorizontalLineLabel(
                                        show: true,
                                        alignment: Alignment.topRight,
                                        padding: const EdgeInsets.only(
                                          right: 5,
                                          bottom: 5,
                                        ),
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                        labelResolver: (line) =>
                                            'Hedef: $_dailyCalorieGoal',
                                      ),
                                    ),
                                  ],
                                ),
                                barGroups: _getWeeklyCalorieData(),
                                gridData: FlGridData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey[400],
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bedtime_outlined),
              activeIcon: Icon(Icons.bedtime),
              label: 'Uyku',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_run_outlined),
              activeIcon: Icon(Icons.directions_run),
              label: 'Aktivite',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.water_drop_outlined),
              activeIcon: Icon(Icons.water_drop),
              label: 'Su',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.food_bank_outlined),
              activeIcon: Icon(Icons.food_bank),
              label: 'Yemek',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  BarTouchData get barTouchData => BarTouchData(
    enabled: true,
    touchTooltipData: BarTouchTooltipData(
      tooltipPadding: const EdgeInsets.all(8),
      tooltipMargin: 8,
      getTooltipColor: (BarChartGroupData group) {
        return Colors.orange.withValues(alpha: 0.9);
      },
      getTooltipItem: (group, groupIndex, rod, rodIndex) {
        return BarTooltipItem(
          '${rod.toY.toInt()} kcal',
          const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        );
      },
    ),
  );

  Widget getTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.grey,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return SideTitleWidget(
      meta: meta,
      child: Text(days[value.toInt()], style: style),
    );
  }

  List<BarChartGroupData> _getWeeklyCalorieData() {
    // Haftalık örnek kalori verisi
    final weeklyData = [1600, 1800, 1550, 1900, 1840, 1700, 2000];

    return List.generate(7, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: weeklyData[index].toDouble(),
            color: Colors.orange.withValues(alpha: 0.8),
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap; // 👈 yeni eklendi

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.15), width: 1),
        ),
        elevation: 4,
        shadowColor: color.withValues(alpha: 0.2),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showStreakCelebration(BuildContext context, int days) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animasyonlu Ateş İkonu (Veya Lottie animasyonu)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department,
                  size: 60,
                  color: Colors.orange,
                ),
              ),
              SizedBox(height: 20),
              Text(
                "$days Günlük Seri! 🔥",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "İnanılmaz gidiyorsun! Disiplinini koruduğun için tebrikler.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Devam Et",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
