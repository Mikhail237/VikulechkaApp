import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'onboarding_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:table_calendar/table_calendar.dart';
import 'package:device_calendar/device_calendar.dart';
import 'screens/recipe_details_screen.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Перечисление для категорий рецептов
enum RecipeCategory {
  breakfast('Завтраки'),
  soup('Супы'),
  mainDish('Основные блюда'),
  salad('Салаты'),
  dessert('Десерты');

  final String title;
  const RecipeCategory(this.title);
}

// Добавляем перечисление для времени приема пищи
enum MealTime {
  breakfast('Завтрак', Icons.wb_sunny),
  lunch('Обед', Icons.wb_cloudy),
  dinner('Ужин', Icons.nights_stay);

  final String title;
  final IconData icon;
  const MealTime(this.title, this.icon);
}

// Добавляем перечисление для категорий продуктов
enum ProductCategory {
  produceAndFruits('Овощи и фрукты', Icons.eco),
  dairy('Молочные продукты', Icons.egg),
  pantry('Бакалея', Icons.kitchen),
  meatAndFish('Мясо и рыба', Icons.set_meal),
  spices('Специи', Icons.spa);

  final String title;
  final IconData icon;
  const ProductCategory(this.title, this.icon);
}

// Обновляем класс рецепта с информацией о питательных веществах
class Recipe {
  final String name;
  final int timeMinutes;
  final int calories;
  final int points;
  final String imagePath;
  final RecipeCategory category;
  final String description;
  final List<String> ingredients;
  final int spicyLevel;
  final bool isFavorite;
  final Map<String, dynamic> nutrients;

  const Recipe({
    required this.name,
    required this.timeMinutes,
    required this.calories,
    required this.points,
    required this.category,
    required this.description,
    required this.ingredients,
    this.imagePath = 'assets/images/dish_placeholder.png',
    this.spicyLevel = 0,
    this.isFavorite = false,
    this.nutrients = const {
      'protein': 0.0,  // граммы
      'fat': 0.0,      // граммы
      'carbs': 0.0,    // граммы
      'vitamins': {
        'A': 0.0,      // мкг
        'C': 0.0,      // мг
        'D': 0.0,      // мкг
      },
      'minerals': {
        'iron': 0.0,     // мг
        'magnesium': 0.0 // мг
      }
    },
  });

  // Конструктор для ручного ввода
  Recipe.manual({
    required this.name,
    required this.timeMinutes,
    required this.calories,
    this.points = 0,
    this.category = RecipeCategory.mainDish,
    this.description = '',
    required this.ingredients,
    this.imagePath = 'assets/images/dish_placeholder.png',
    this.spicyLevel = 0,
    this.isFavorite = false,
  });

  @override
  String toString() => '$name: $timeMinutes минут, $calories ккал';
}

// Класс для управления уровнями
class Level {
  final String name;
  final int minPoints;
  final int maxPoints;

  const Level({
    required this.name,
    required this.minPoints,
    required this.maxPoints,
  });

  // Проверяем, соответствует ли количество очков данному уровню
  bool containsPoints(int points) => 
      points >= minPoints && (maxPoints == -1 || points <= maxPoints);
}

// Обновленный класс квеста с корректной типизацией
class DailyQuest {
  final String title;
  final String description;
  final int reward;
  final bool Function(Recipe?) checkCompletion;

  const DailyQuest({
    required this.title,
    required this.description,
    required this.reward,
    required this.checkCompletion,
  });

  // Проверяем выполнение квеста
  bool isCompleted(Recipe? recipe) => checkCompletion(recipe);
}

// Класс для хранения запланированного блюда
class Meal {
  final Recipe recipe;
  final DateTime date;
  final MealTime mealTime;

  const Meal({
    required this.recipe,
    required this.date,
    required this.mealTime,
  });
}

// Добавляем в начало файла, после импортов
class Achievement {
  final String name;
  final String description;
  final int points;

  const Achievement({
    required this.name,
    required this.description,
    required this.points,
  });
}

// Обновляем класс продукта
class ShoppingItem {
  final String name;
  final String quantity;
  final String unit;
  final ProductCategory category;
  final bool isPurchased;

  const ShoppingItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.isPurchased = false,
  });

  ShoppingItem copyWith({bool? isPurchased}) {
    return ShoppingItem(
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }
}

// Добавляем константы для цветовой схемы
const Color kPrimaryColor = Color(0xFF9C27B0);
const Color kLightPurple = Color(0xFFE6C7FF); 
const Color kMediumPurple = Color(0xFFD1B2FF);
const Color kGoldAccent = Color(0xFFFFD700);

// Создаем StatefulWidget, так как нам нужно хранить состояние выбранного пользователя
class HomeScreen extends StatefulWidget {
  final String? initialRecipe;

  const HomeScreen({
    super.key,
    this.initialRecipe,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Выносим RecipeCard в отдельный класс
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final bool favorite;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.favorite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(
                recipe.imagePath,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.image_not_supported);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${recipe.timeMinutes} мин',
                    style: TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${recipe.calories} ккал',
                    style: TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CookingTimer {
  final Recipe recipe;
  Timer? _timer;
  int _remainingSeconds;
  final Function(int) onTick;
  final VoidCallback onFinished;

  CookingTimer({
    required this.recipe,
    required this.onTick,
    required this.onFinished,
  }) : _remainingSeconds = recipe.timeMinutes * 60;

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        onTick(_remainingSeconds);
      } else {
        stop();
        onFinished();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late FlutterLocalNotificationsPlugin _notifications;
  final List<Recipe> _recipes = [];
  final List<Recipe> _favoriteRecipes = [];
  final List<Meal> _plannedMeals = [];
  final List<ShoppingItem> _shoppingList = [];

  // Добавляем константы для планирования питания
  static const double MIN_DAILY_CALORIES = 1800;
  static const double MAX_DAILY_CALORIES = 2200;
  static const double MIN_PROTEIN_RATIO = 0.15; // 15%
  static const double MAX_PROTEIN_RATIO = 0.20; // 20%
  static const double MIN_FAT_RATIO = 0.25;     // 25%
  static const double MAX_FAT_RATIO = 0.30;     // 30%
  static const double MIN_CARB_RATIO = 0.50;    // 50%
  static const double MAX_CARB_RATIO = 0.60;    // 60%

  // Рекомендуемые суточные нормы
  static const Map<String, double> DAILY_NUTRIENTS = {
    'protein': 90.0,   // г (среднее между 70-110)
    'fat': 57.5,       // г (среднее между 50-65)
    'carbs': 290.0,    // г (среднее между 250-330)
    'vitamins': {
      'A': 900.0,      // мкг
      'C': 90.0,       // мг
      'D': 15.0,       // мкг
    },
    'minerals': {
      'iron': 8.0,     // мг
      'magnesium': 400.0 // мг
    }
  };

  // Добавляем списки продуктов по категориям
  static const Map<ProductCategory, List<String>> PRODUCT_CATEGORIES = {
    ProductCategory.produceAndFruits: [
      'помидор', 'огурец', 'морковь', 'лук', 'капуста', 'картофель',
      'яблоко', 'банан', 'апельсин', 'лимон', 'свекла', 'перец',
      'зелень', 'салат', 'укроп', 'петрушка', 'авокадо', 'имбирь'
    ],
    ProductCategory.pantry: [
      'рис', 'гречка', 'макароны', 'мука', 'сахар', 'соль',
      'масло', 'соус', 'уксус', 'мед', 'орехи', 'семечки'
    ],
    ProductCategory.meatAndFish: [
      'курица', 'говядина', 'рыба', 'лосось', 'тунец', 'мясо',
      'фарш', 'индейка', 'телятина', 'креветки', 'кальмары'
    ],
    ProductCategory.spices: [
      'перец красный', 'перец черный', 'чили', 'паприка', 'карри',
      'куркума', 'базилик', 'орегано', 'тимьян', 'розмарин',
      'кориандр', 'зира', 'имбирь молотый', 'чеснок', 'васаби',
      'табаско', 'хрен', 'горчица'
    ]
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initNotifications();
    _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: kPrimaryColor,
          secondary: kMediumPurple,
          surface: kLightPurple,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getGreeting()),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Рецепты'),
              Tab(icon: Icon(Icons.favorite), text: 'Избранное'),
              Tab(icon: Icon(Icons.calendar_today), text: 'План'),
              Tab(icon: Icon(Icons.shopping_cart), text: 'Покупки'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRecipesTab(),
            _buildFavoritesTab(),
            _buildPlanTab(),
            _buildShoppingTab(),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Доброе утро, Викулечка! 🌅";
    if (hour < 17) return "Добрый день, солнышко! ☀️";
    if (hour < 22) return "Добрый вечер, звёздочка! 🌟";
    return "Сладких снов, Викулечка! 🌙";
  }

  Widget _buildFavoritesTab() {
    if (_favoriteRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: kMediumPurple),
            const SizedBox(height: 16),
            Text(
              'Нет избранных рецептов',
              style: TextStyle(
                fontSize: 18,
                color: kPrimaryColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return StaggeredGridView.countBuilder(
      padding: const EdgeInsets.all(8),
      crossAxisCount: 2,
      itemCount: _favoriteRecipes.length,
      itemBuilder: (context, index) => _buildRecipeCard(_favoriteRecipes[index]),
      staggeredTileBuilder: (index) => const StaggeredTile.fit(1),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ).animate().fadeIn(duration: 600.ms);
  }

  void _toggleFavorite(Recipe recipe) {
    setState(() {
      if (_favoriteRecipes.contains(recipe)) {
        _favoriteRecipes.remove(recipe);
      } else {
        _favoriteRecipes.add(recipe);
      }
      _saveFavorites();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = _favoriteRecipes.map((r) => r.name).toList();
    await prefs.setStringList('favorites', favorites);
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    setState(() {
      _favoriteRecipes.clear();
      _favoriteRecipes.addAll(
        _recipes.where((r) => favorites.contains(r.name))
      );
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _loadFavorites();
    } catch (error) {
      print('Ошибка загрузки данных: $error');
      if (mounted) {
        _showSnackBar(context, 'Ошибка загрузки данных: $error');
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kLightPurple,
              Colors.white.withOpacity(0.9),
              kLightPurple.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: Image.asset(
                    recipe.imagePath,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        kPrimaryColor.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      if (recipe.isFavorite)
                        const Text('✨', 
                          style: TextStyle(
                            fontSize: 24,
                            color: kGoldAccent,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        '🌶️' * recipe.spicyLevel,
                        style: const TextStyle(
                          fontSize: 20,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${recipe.calories} ккал • ${recipe.timeMinutes} мин',
                    style: TextStyle(
                      color: kPrimaryColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate()
      .fadeIn(duration: 600.ms)
      .slideY(begin: 0.2, end: 0)
      .then()
      .shimmer(duration: 1000.ms, color: kMediumPurple.withOpacity(0.3));
  }

  Widget _buildRecipesTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: 200,
              viewportFraction: 0.8,
              enlargeCenterPage: true,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 3),
            ),
            items: _recipes.map((recipe) {
              return Builder(
                builder: (BuildContext context) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kPrimaryColor.withOpacity(0.7),
                          kMediumPurple.withOpacity(0.9),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        children: [
                          Image.asset(
                            recipe.imagePath,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  kPrimaryColor.withOpacity(0.8),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recipe.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (recipe.isFavorite)
                                      const Text('✨',
                                        style: TextStyle(
                                          fontSize: 24,
                                          color: kGoldAccent,
                                        ),
                                      ),
                                    Text(
                                      '🌶️' * recipe.spicyLevel,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate()
                    .fadeIn(duration: 600.ms)
                    .scale(begin: const Offset(0.8, 0.8));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          StaggeredGridView.countBuilder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            itemCount: _recipes.length,
            itemBuilder: (context, index) => _buildRecipeCard(_recipes[index]),
            staggeredTileBuilder: (index) => const StaggeredTile.fit(1),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Сгенерировать меню на неделю'),
            onPressed: _generateWeeklyMenu,
          ),
        ),
        TableCalendar(
          firstDay: DateTime.now(),
          lastDay: DateTime.now().add(const Duration(days: 30)),
          focusedDay: DateTime.now(),
          calendarFormat: CalendarFormat.week,
          onDaySelected: (selectedDay, focusedDay) {
            _showMealPlanningDialog(selectedDay);
          },
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _plannedMeals.length,
            itemBuilder: (context, index) {
              final meal = _plannedMeals[index];
              return Card(
                child: ListTile(
                  leading: Icon(meal.mealTime.icon),
                  title: Text(meal.recipe.name),
                  subtitle: Text(
                    '${DateFormat('dd.MM.yyyy').format(meal.date)} • '
                    '${meal.recipe.calories} ккал'
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🌶️' * meal.recipe.spicyLevel),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removePlannedMeal(index),
                      ),
                    ],
                  ),
                ),
              ).animate()
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.2, end: 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShoppingTab() {
    if (_shoppingList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 64, color: kMediumPurple),
            const SizedBox(height: 16),
            Text(
              'Список покупок пуст',
              style: TextStyle(
                fontSize: 18,
                color: kPrimaryColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Сгенерировать список'),
              onPressed: _generateShoppingList,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: ProductCategory.values.length,
      itemBuilder: (context, categoryIndex) {
        final category = ProductCategory.values[categoryIndex];
        final categoryItems = _shoppingList
            .where((item) => item.category == category)
            .toList();

        if (categoryItems.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(category.icon, color: kPrimaryColor),
                  const SizedBox(width: 8),
                  Text(
                    category.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            ...categoryItems.map((item) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: CheckboxListTile(
                title: Text(
                  item.name,
                  style: TextStyle(
                    decoration: item.isPurchased ? 
                      TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text('${item.quantity} ${item.unit}'),
                value: item.isPurchased,
                onChanged: (value) {
                  setState(() {
                    final index = _shoppingList.indexOf(item);
                    _shoppingList[index] = item.copyWith(
                      isPurchased: value ?? false
                    );
                  });
                },
                activeColor: kPrimaryColor,
              ),
            )).toList(),
            const Divider(height: 32),
          ],
        );
      },
    );
  }

  Future<void> _initNotifications() async {
    tz.initializeTimeZones();
    final local = tz.getLocation('Europe/Moscow');
    tz.setLocalLocation(local);
    
    _notifications = FlutterLocalNotificationsPlugin();
    
    const initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const initializationSettings = 
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Обработка нажатия на уведомление
      },
    );
  }

  void _startCookingTimer(BuildContext context, Recipe recipe) async {
    final minutes = recipe.timeMinutes;
    final notificationTime = DateTime.now().add(Duration(minutes: minutes));
    final scheduledDate = tz.TZDateTime.from(notificationTime, tz.local);

    await _notifications.zonedSchedule(
      recipe.hashCode,
      'Готово! 🎉',
      '${recipe.name} готово к подаче!',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'cooking_channel',
          'Cooking Timer',
          channelDescription: 'Notifications for cooking timers',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('timer_finish'),
          playSound: true,
          enableVibration: true,
          icon: '@drawable/ic_timer',
          largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_recipe'),
        ),
      ),
      uiLocalNotificationDateInterpretation: 
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.timer, color: Colors.white),
            const SizedBox(width: 8),
            Text('Таймер запущен на $minutes минут для ${recipe.name}!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'Отмена',
          onPressed: () {
            _notifications.cancel(recipe.hashCode);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Таймер отменен')),
            );
          },
        ),
      ),
    );
  }

  void _generateMonthlyMenu() {
    final monthlyPlan = <DateTime, List<Meal>>{};
    final now = DateTime.now();
    
    // Генерируем меню на 4 недели
    for (var week = 0; week < 4; week++) {
      for (var day = 0; day < 7; day++) {
        final currentDate = now.add(Duration(days: week * 7 + day));
        final meals = <Meal>[];
        var dailyNutrients = _createEmptyNutrientsMap();
        
        // Завтрак (25% калорий)
        final breakfast = _selectMeal(
          category: RecipeCategory.breakfast,
          targetCalories: MIN_DAILY_CALORIES * 0.25,
          excludedRecipes: meals.map((m) => m.recipe).toList(),
          requiredNutrients: _calculateRequiredNutrients(dailyNutrients, 0.25),
        );
        if (breakfast != null) {
          meals.add(Meal(
            recipe: breakfast,
            date: currentDate,
            mealTime: MealTime.breakfast,
          ));
          _updateDailyNutrients(dailyNutrients, breakfast.nutrients);
        }
        
        // Обед (40% калорий)
        final lunch = _selectMeal(
          category: RecipeCategory.mainDish,
          targetCalories: MIN_DAILY_CALORIES * 0.40,
          excludedRecipes: meals.map((m) => m.recipe).toList(),
          requiredNutrients: _calculateRequiredNutrients(dailyNutrients, 0.40),
          preferSpicy: day % 2 == 0, // Чередуем острые и неострые блюда
        );
        if (lunch != null) {
          meals.add(Meal(
            recipe: lunch,
            date: currentDate,
            mealTime: MealTime.lunch,
          ));
          _updateDailyNutrients(dailyNutrients, lunch.nutrients);
        }
        
        // Ужин (35% калорий)
        final dinner = _selectMeal(
          category: RecipeCategory.mainDish,
          targetCalories: MIN_DAILY_CALORIES * 0.35,
          excludedRecipes: meals.map((m) => m.recipe).toList(),
          requiredNutrients: _calculateRequiredNutrients(dailyNutrients, 0.35),
          preferSpicy: true, // Викулечка любит острое на ужин
        );
        if (dinner != null) {
          meals.add(Meal(
            recipe: dinner,
            date: currentDate,
            mealTime: MealTime.dinner,
          ));
          _updateDailyNutrients(dailyNutrients, dinner.nutrients);
        }
        
        // Добавляем десерт, если нужны калории или питательные вещества
        if (_needsMoreNutrients(dailyNutrients)) {
          final dessert = _selectMeal(
            category: RecipeCategory.dessert,
            targetCalories: MAX_DAILY_CALORIES - _calculateTotalCalories(meals),
            excludedRecipes: meals.map((m) => m.recipe).toList(),
            requiredNutrients: _calculateRequiredNutrients(dailyNutrients, 0.1),
            preferFavorites: true,
          );
          if (dessert != null) {
            meals.add(Meal(
              recipe: dessert,
              date: currentDate,
              mealTime: MealTime.dinner,
            ));
          }
        }
        
        monthlyPlan[currentDate] = meals;
      }
    }
    
    setState(() {
      _plannedMeals.clear();
      monthlyPlan.forEach((day, meals) {
        _plannedMeals.addAll(meals);
      });
      _generateShoppingList(); // Обновляем список покупок
    });
  }

  Map<String, dynamic> _createEmptyNutrientsMap() {
    return {
      'protein': 0.0,
      'fat': 0.0,
      'carbs': 0.0,
      'vitamins': {'A': 0.0, 'C': 0.0, 'D': 0.0},
      'minerals': {'iron': 0.0, 'magnesium': 0.0}
    };
  }

  void _updateDailyNutrients(Map<String, dynamic> daily, Map<String, dynamic> meal) {
    daily['protein'] += meal['protein'];
    daily['fat'] += meal['fat'];
    daily['carbs'] += meal['carbs'];
    daily['vitamins']['A'] += meal['vitamins']['A'];
    daily['vitamins']['C'] += meal['vitamins']['C'];
    daily['vitamins']['D'] += meal['vitamins']['D'];
    daily['minerals']['iron'] += meal['minerals']['iron'];
    daily['minerals']['magnesium'] += meal['minerals']['magnesium'];
  }

  bool _needsMoreNutrients(Map<String, dynamic> daily) {
    return daily['protein'] < DAILY_NUTRIENTS['protein']! ||
           daily['carbs'] < DAILY_NUTRIENTS['carbs']! ||
           daily['vitamins']['C'] < DAILY_NUTRIENTS['vitamins']['C']!;
  }

  Widget _buildNutrientsInfo(DateTime date) {
    final meals = _plannedMeals.where((meal) => 
      meal.date.year == date.year && 
      meal.date.month == date.month && 
      meal.date.day == date.day
    ).toList();

    final dailyNutrients = _calculateDailyNutrients(meals);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Питательная ценность:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildNutrientProgress('Белки', 
              dailyNutrients['protein'], DAILY_NUTRIENTS['protein']!),
            _buildNutrientProgress('Жиры', 
              dailyNutrients['fat'], DAILY_NUTRIENTS['fat']!),
            _buildNutrientProgress('Углеводы', 
              dailyNutrients['carbs'], DAILY_NUTRIENTS['carbs']!),
            const SizedBox(height: 8),
            Text('Витамины и минералы:', 
              style: TextStyle(color: kPrimaryColor)),
            _buildVitaminInfo(dailyNutrients),
          ],
        ),
      ),
    );
  }

  // Обновляем метод определения категории продукта
  ProductCategory _determineProductCategory(String ingredient) {
    ingredient = ingredient.toLowerCase();
    
    for (var entry in PRODUCT_CATEGORIES.entries) {
      if (entry.value.any((item) => ingredient.contains(item.toLowerCase()))) {
        return entry.key;
      }
    }
    
    // По умолчанию - бакалея
    return ProductCategory.pantry;
  }

  // Обновляем метод генерации списка покупок
  void _generateShoppingList() {
    final Map<String, ShoppingItem> uniqueItems = {};
    
    // Добавляем продукты из запланированных блюд
    for (final meal in _plannedMeals) {
      for (final ingredient in meal.recipe.ingredients) {
        final category = _determineProductCategory(ingredient);
        
        // Определяем единицу измерения
        String unit = _getDefaultUnit(ingredient, category);
        String quantity = _getDefaultQuantity(ingredient, category);
        
        // Добавляем в уникальный список
        uniqueItems[ingredient] = ShoppingItem(
          name: ingredient,
          quantity: quantity,
          unit: unit,
          category: category,
        );
      }
    }
    
    // Добавляем базовые специи для Викулечки
    final spicySpices = [
      'Перец чили красный',
      'Паприка острая',
      'Куркума',
      'Васаби',
      'Табаско',
      'Хрен',
      'Горчица острая'
    ];
    
    for (var spice in spicySpices) {
      if (!uniqueItems.containsKey(spice)) {
        uniqueItems[spice] = ShoppingItem(
          name: spice,
          quantity: '1',
          unit: 'уп',
          category: ProductCategory.spices,
        );
      }
    }
    
    setState(() {
      _shoppingList = uniqueItems.values.toList()
        ..sort((a, b) {
          // Сначала сортируем по категориям
          var categoryCompare = a.category.index.compareTo(b.category.index);
          if (categoryCompare != 0) return categoryCompare;
          // Затем по алфавиту внутри категории
          return a.name.compareTo(b.name);
        });
    });
  }

  // Вспомогательный метод для определения единиц измерения
  String _getDefaultUnit(String ingredient, ProductCategory category) {
    switch (category) {
      case ProductCategory.produceAndFruits:
        return ingredient.toLowerCase().contains('зелень') ? 'пуч' : 'шт';
      case ProductCategory.meatAndFish:
        return 'г';
      case ProductCategory.spices:
        return ingredient.toLowerCase().contains('соус') ? 'бут' : 'уп';
      case ProductCategory.pantry:
        if (ingredient.toLowerCase().contains('масло')) return 'мл';
        if (ingredient.toLowerCase().contains('мука')) return 'кг';
        return 'шт';
      default:
        return 'шт';
    }
  }

  // Вспомогательный метод для определения количества
  String _getDefaultQuantity(String ingredient, ProductCategory category) {
    switch (category) {
      case ProductCategory.meatAndFish:
        return '500';
      case ProductCategory.spices:
        return '1';
      case ProductCategory.produceAndFruits:
        return ingredient.toLowerCase().contains('зелень') ? '1' : '2';
      default:
        return '1';
    }
  }
}