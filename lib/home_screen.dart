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

  // Обновляем конструктор manual
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
    Map<String, dynamic>? nutrients,
  }) : nutrients = nutrients ?? const {
    'protein': 0.0,
    'fat': 0.0,
    'carbs': 0.0,
    'vitamins': {
      'A': 0.0,
      'C': 0.0,
      'D': 0.0,
    },
    'minerals': {
      'iron': 0.0,
      'magnesium': 0.0
    }
  };

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
  static const Map<String, double> DAILY_NUTRIENTS = {
    'calories': {
      'min': 1800,
      'max': 2200,
    },
    'protein': {
      'min': 70,  // г
      'max': 110, // г
      'ratio': {'min': 0.15, 'max': 0.20},
    },
    'fat': {
      'min': 50,  // г
      'max': 65,  // г
      'ratio': {'min': 0.25, 'max': 0.30},
    },
    'carbs': {
      'min': 250, // г
      'max': 330, // г
      'ratio': {'min': 0.50, 'max': 0.60},
    },
    'vitamins': {
      'A': 900.0, // мкг
      'C': 90.0,  // мг
      'D': 15.0,  // мкг
    },
    'minerals': {
      'iron': 8.0,      // мг
      'magnesium': 400.0 // мг
    }
  };

  // Списки предпочтений
  static const List<String> FAVORITE_CUISINES = [
    'азиатская', 'японская', 'китайская', 'тайская', 'вьетнамская'
  ];

  static const List<String> FAVORITE_DESSERTS = [
    'тирамису', 'эклеры', 'баклава', 'творожный торт'
  ];

  static const List<String> EXCLUDED_INGREDIENTS = [
    'молоко', 'кефир', 'колбаса', 'сосиски', 'свинина',
    'вареное мясо', 'молочные продукты'
  ];

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

  // Добавляем контроллер для анимации
  late AnimationController _timerAnimationController;
  Timer? _activeTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initNotifications();
    _loadInitialData();
    _timerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _timerAnimationController.dispose();
    _activeTimer?.cancel();
    super.dispose();
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
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimaryColor,
          elevation: 0,
        ),
        tabBarTheme: TabBarTheme(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicator: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: kGoldAccent, width: 3),
            ),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getGreeting())
            .animate()
            .fadeIn(duration: 600.ms)
            .slideX(begin: -0.2, end: 0),
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

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: StaggeredGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: _favoriteRecipes.map((recipe) {
          return StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: _buildRecipeCard(recipe),
          );
        }).toList(),
      ).animate().fadeIn(duration: 600.ms),
    );
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
        child: InkWell(
          onTap: () => _showRecipeDetails(context, recipe),
          borderRadius: BorderRadius.circular(15),
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
                    Row(
                      children: [
                        Icon(Icons.timer, size: 16, color: kPrimaryColor.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.timeMinutes} мин',
                          style: TextStyle(color: kPrimaryColor.withOpacity(0.7)),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.local_fire_department, size: 16, color: kPrimaryColor.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.calories} ккал',
                          style: TextStyle(color: kPrimaryColor.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              enlargeStrategy: CenterPageEnlargeStrategy.height,
            ),
            items: _recipes.map((recipe) => _buildCarouselItem(recipe)).toList(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: StaggeredGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: _recipes.map((recipe) {
                return StaggeredGridTile.fit(
                  crossAxisCellCount: 1,
                  child: _buildRecipeCard(recipe),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(Recipe recipe) {
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
          fit: StackFit.expand,
          children: [
            Image.asset(
              recipe.imagePath,
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

    // Настраиваем уведомление
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
          sound: const RawResourceAndroidNotificationSound('timer_finish'),
          playSound: true,
          enableVibration: true,
          icon: '@drawable/ic_timer',
          largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_recipe'),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
    ),
    uiLocalNotificationDateInterpretation: 
        UILocalNotificationDateInterpretation.absoluteTime,
  );

  // Показываем анимированный Snackbar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.timer, color: Colors.white)
            .animate(controller: _timerAnimationController)
            .shake(duration: 500.ms)
            .then()
            .shimmer(duration: 1000.ms),
          const SizedBox(width: 8),
          Text('Таймер запущен на $minutes минут для ${recipe.name}!')
            .animate()
            .fadeIn(duration: 300.ms)
            .slideX(begin: 0.2, end: 0),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: kPrimaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      action: SnackBarAction(
        label: 'Отмена',
        textColor: Colors.white,
        onPressed: () {
          _notifications.cancel(recipe.hashCode);
          _activeTimer?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Таймер отменен')
                .animate()
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.2, end: 0),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
      duration: const Duration(seconds: 4),
    ),
  );

  // Запускаем анимацию
  _timerAnimationController
    ..reset()
    ..repeat(period: const Duration(seconds: 2));

  // Сохраняем активный таймер
  _activeTimer = Timer(Duration(minutes: minutes), () {
    _timerAnimationController.stop();
  });
}

  // Добавляем метод расчета требуемых нутриентов
  Map<String, dynamic> _calculateRequiredNutrients(Map<String, dynamic> current, double ratio) {
    return {
      'protein': DAILY_NUTRIENTS['protein']['min']! * ratio - (current['protein'] ?? 0.0),
      'fat': DAILY_NUTRIENTS['fat']['min']! * ratio - (current['fat'] ?? 0.0),
      'carbs': DAILY_NUTRIENTS['carbs']['min']! * ratio - (current['carbs'] ?? 0.0),
      'vitamins': {
        'A': DAILY_NUTRIENTS['vitamins']['A']! * ratio - ((current['vitamins'] ?? {})['A'] ?? 0.0),
        'C': DAILY_NUTRIENTS['vitamins']['C']! * ratio - ((current['vitamins'] ?? {})['C'] ?? 0.0),
        'D': DAILY_NUTRIENTS['vitamins']['D']! * ratio - ((current['vitamins'] ?? {})['D'] ?? 0.0),
      },
      'minerals': {
        'iron': DAILY_NUTRIENTS['minerals']['iron']! * ratio - ((current['minerals'] ?? {})['iron'] ?? 0.0),
        'magnesium': DAILY_NUTRIENTS['minerals']['magnesium']! * ratio - ((current['minerals'] ?? {})['magnesium'] ?? 0.0),
      }
    };
  }

  // Обновляем метод генерации меню для использования требуемых нутриентов
  void _generateMonthlyMenu() {
    final monthlyPlan = <DateTime, List<Meal>>{};
    final now = DateTime.now();
    
    for (var week = 0; week < 4; week++) {
      for (var day = 0; day < 7; day++) {
        final currentDate = now.add(Duration(days: week * 7 + day));
        final meals = <Meal>[];
        var dailyNutrients = _createEmptyNutrientsMap();
        var attempts = 0;
        const maxAttempts = 10;

        while (attempts < maxAttempts && !_checkNutritionalBalance(meals.map((m) => m.recipe).toList())) {
          meals.clear();
          dailyNutrients = _createEmptyNutrientsMap();
          
          // Завтрак (25% калорий)
          var breakfast = _selectMeal(
            category: RecipeCategory.breakfast,
            targetCalories: DAILY_NUTRIENTS['calories']['min'] * 0.25,
            excludedRecipes: meals.map((m) => m.recipe).toList(),
            requiredNutrients: _calculateRequiredNutrients(dailyNutrients, 0.25),
            checkPreferences: true,
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
          var lunch = _selectMeal(
            category: RecipeCategory.mainDish,
            targetCalories: DAILY_NUTRIENTS['calories']['min'] * 0.40,
            excludedRecipes: meals.map((m) => m.recipe).toList(),
            preferSpicy: day % 2 == 0,
            checkPreferences: true,
          );
          
          if (lunch != null) {
            meals.add(Meal(
              recipe: lunch,
              date: currentDate,
              mealTime: MealTime.lunch,
            ));
          }

          // Ужин (35% калорий)
          var dinner = _selectMeal(
            category: RecipeCategory.mainDish,
            targetCalories: DAILY_NUTRIENTS['calories']['min'] * 0.35,
            excludedRecipes: meals.map((m) => m.recipe).toList(),
            preferSpicy: true,
            checkPreferences: true,
          );
          
          if (dinner != null) {
            meals.add(Meal(
              recipe: dinner,
              date: currentDate,
              mealTime: MealTime.dinner,
            ));
          }

          attempts++;
        }

        // Добавляем любимый десерт (если есть место по калориям)
        if (_calculateTotalCalories(meals) < DAILY_NUTRIENTS['calories']['max']) {
          var dessert = _selectMeal(
            category: RecipeCategory.dessert,
            targetCalories: DAILY_NUTRIENTS['calories']['max'] - _calculateTotalCalories(meals),
            excludedRecipes: meals.map((m) => m.recipe).toList(),
            preferFavorites: true,
            checkPreferences: true,
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
      _generateShoppingList();
    });
  }

  Recipe? _selectMeal({
    required RecipeCategory category,
    required double targetCalories,
    List<Recipe> excludedRecipes = const [],
    bool preferSpicy = false,
    bool preferFavorites = false,
    bool checkPreferences = false,
    Map<String, dynamic>? requiredNutrients,
  }) {
    var availableRecipes = _recipes.where((recipe) {
      if (recipe.category != category) return false;
      if (excludedRecipes.contains(recipe)) return false;
      
      final minCal = targetCalories * 0.8;
      final maxCal = targetCalories * 1.2;
      if (recipe.calories < minCal || recipe.calories > maxCal) return false;
      
      if (checkPreferences && !_matchesPreferences(recipe)) return false;
      
      return true;
    }).toList();
    
    if (availableRecipes.isEmpty) return null;
    
    availableRecipes.sort((a, b) {
      var comparison = 0;
      
      if (preferSpicy) {
        comparison = b.spicyLevel.compareTo(a.spicyLevel);
      }
      
      if (comparison == 0 && preferFavorites) {
        if (FAVORITE_DESSERTS.any((d) => b.name.toLowerCase().contains(d.toLowerCase()))) {
          return -1;
        }
        if (FAVORITE_DESSERTS.any((d) => a.name.toLowerCase().contains(d.toLowerCase()))) {
          return 1;
        }
      }
      
      return comparison;
    });
    
    return availableRecipes.first;
  }

  bool _matchesPreferences(Recipe recipe) {
    // Проверяем исключенные ингредиенты
    if (recipe.ingredients.any((i) => 
      EXCLUDED_INGREDIENTS.any((e) => i.toLowerCase().contains(e.toLowerCase())))) {
      return false;
    }

    // Для десертов проверяем список любимых
    if (recipe.category == RecipeCategory.dessert) {
      return FAVORITE_DESSERTS.any((d) => 
        recipe.name.toLowerCase().contains(d.toLowerCase()));
    }

    // Проверяем азиатскую кухню
    if (FAVORITE_CUISINES.any((c) => 
      recipe.description.toLowerCase().contains(c.toLowerCase()))) {
      return true;
    }

    return true;
  }

  bool _checkNutritionalBalance(List<Recipe> dayMenu) {
    var totalNutrients = _calculateTotalNutrients(dayMenu);
    
    // Проверяем калории
    if (totalNutrients['calories'] < DAILY_NUTRIENTS['calories']['min'] ||
        totalNutrients['calories'] > DAILY_NUTRIENTS['calories']['max']) {
      return false;
    }

    // Проверяем БЖУ
    for (var nutrient in ['protein', 'fat', 'carbs']) {
      var ratio = totalNutrients[nutrient] / totalNutrients['calories'];
      if (ratio < DAILY_NUTRIENTS[nutrient]['ratio']['min'] ||
          ratio > DAILY_NUTRIENTS[nutrient]['ratio']['max']) {
        return false;
      }
    }

    // Проверяем витамины и минералы
    for (var vitamin in ['A', 'C', 'D']) {
      if (totalNutrients['vitamins'][vitamin] < DAILY_NUTRIENTS['vitamins'][vitamin]) {
        return false;
      }
    }

    return true;
  }

  Map<String, dynamic> _calculateTotalNutrients(List<Recipe> dayMenu) {
    Map<String, dynamic> totalNutrients = {};
    
    for (var recipe in dayMenu) {
      totalNutrients['calories'] = (totalNutrients['calories'] ?? 0) + recipe.calories;
      totalNutrients['protein'] = (totalNutrients['protein'] ?? 0) + recipe.nutrients['protein'];
      totalNutrients['fat'] = (totalNutrients['fat'] ?? 0) + recipe.nutrients['fat'];
      totalNutrients['carbs'] = (totalNutrients['carbs'] ?? 0) + recipe.nutrients['carbs'];
      totalNutrients['vitamins'] = {
        ...totalNutrients['vitamins'] ?? {},
        ...recipe.nutrients['vitamins']
      };
      totalNutrients['minerals'] = {
        ...totalNutrients['minerals'] ?? {},
        ...recipe.nutrients['minerals']
      };
    }
    
    return totalNutrients;
  }

  int _calculateTotalCalories(List<Meal> dayMenu) {
    return dayMenu.fold(0, (sum, meal) => sum + meal.recipe.calories);
  }

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

  // Обновляем метод определения единиц измерения
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

  void _generateWeeklyMenu() {
    final weeklyPlan = <DateTime, List<Meal>>{};
    final now = DateTime.now();
    
    for (var i = 0; i < 7; i++) {
      final day = now.add(Duration(days: i));
      final meals = <Meal>[];
      var dailyNutrients = _createEmptyNutrientsMap();

      // Завтрак (25% калорий)
      final breakfast = _selectMeal(
        category: RecipeCategory.breakfast,
        targetCalories: DAILY_NUTRIENTS['calories']['min'] * 0.25,
        excludedRecipes: meals.map((m) => m.recipe).toList(),
        requiredNutrients: _calculateRequiredNutrients(dailyNutrients, 0.25),
      );
      
      if (breakfast != null) {
        meals.add(Meal(
          recipe: breakfast,
          date: day,
          mealTime: MealTime.breakfast,
        ));
        _updateDailyNutrients(dailyNutrients, breakfast.nutrients);
      }

      // Обед (40% калорий)
      final lunch = _selectMeal(
        category: RecipeCategory.mainDish,
        targetCalories: DAILY_NUTRIENTS['calories']['min'] * 0.40,
        excludedRecipes: meals.map((m) => m.recipe).toList(),
        preferSpicy: i % 2 == 0,
        requiredNutrients: _calculateRequiredNutrients(dailyNutrients, 0.40),
      );
      
      if (lunch != null) {
        meals.add(Meal(
          recipe: lunch,
          date: day,
          mealTime: MealTime.lunch,
        ));
        _updateDailyNutrients(dailyNutrients, lunch.nutrients);
      }

      // Ужин (35% калорий)
      final dinner = _selectMeal(
        category: RecipeCategory.mainDish,
        targetCalories: DAILY_NUTRIENTS['calories']['min'] * 0.35,
        excludedRecipes: meals.map((m) => m.recipe).toList(),
        preferSpicy: true,
        requiredNutrients: _calculateRequiredNutrients(dailyNutrients, 0.35),
      );
      
      if (dinner != null) {
        meals.add(Meal(
          recipe: dinner,
          date: day,
          mealTime: MealTime.dinner,
        ));
        _updateDailyNutrients(dailyNutrients, dinner.nutrients);
      }

      weeklyPlan[day] = meals;
    }

    setState(() {
      _plannedMeals.clear();
      _plannedMeals.addAll(weeklyPlan.values.expand((e) => e).toList());
      _generateShoppingList();
    });
  }

  void _showMealPlanningDialog(DateTime selectedDay) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Планирование на ${DateFormat('dd.MM.yyyy').format(selectedDay)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mealTime in MealTime.values)
                ListTile(
                  leading: Icon(mealTime.icon),
                  title: Text(mealTime.title),
                  subtitle: Text(_getMealForDateTime(selectedDay, mealTime)?.recipe.name ?? 'Не запланировано'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showRecipeSelectionDialog(selectedDay, mealTime),
                  ),
                ),
              const SizedBox(height: 16),
              _buildNutrientsInfo(selectedDay),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _removePlannedMeal(int index) {
    setState(() {
      _plannedMeals.removeAt(index);
      _generateShoppingList();
    });
  }

  Recipe? _selectMeal({
    required RecipeCategory category,
    required double targetCalories,
    List<Recipe> excludedRecipes = const [],
    bool preferSpicy = false,
    Map<String, dynamic>? requiredNutrients,
  }) {
    final availableRecipes = _recipes.where((recipe) {
      if (recipe.category != category) return false;
      if (excludedRecipes.contains(recipe)) return false;
      
      final minCal = targetCalories * 0.8;
      final maxCal = targetCalories * 1.2;
      if (recipe.calories < minCal || recipe.calories > maxCal) return false;
      
      if (requiredNutrients != null) {
        // Проверяем соответствие требуемым питательным веществам
        if (recipe.nutrients['protein'] < requiredNutrients['protein']) return false;
        if (recipe.nutrients['fat'] < requiredNutrients['fat']) return false;
        if (recipe.nutrients['carbs'] < requiredNutrients['carbs']) return false;
      }
      
      return true;
    }).toList();

    if (availableRecipes.isEmpty) return null;

    availableRecipes.sort((a, b) {
      if (preferSpicy) {
        return b.spicyLevel.compareTo(a.spicyLevel);
      }
      return 0;
    });

    return availableRecipes.first;
  }

  Map<String, dynamic> _calculateRequiredNutrients(Map<String, dynamic> current, double ratio) {
    return {
      'protein': DAILY_NUTRIENTS['protein']['min']! * ratio - (current['protein'] ?? 0.0),
      'fat': DAILY_NUTRIENTS['fat']['min']! * ratio - (current['fat'] ?? 0.0),
      'carbs': DAILY_NUTRIENTS['carbs']['min']! * ratio - (current['carbs'] ?? 0.0),
      'vitamins': {
        'A': DAILY_NUTRIENTS['vitamins']['A']! * ratio - ((current['vitamins'] ?? {})['A'] ?? 0.0),
        'C': DAILY_NUTRIENTS['vitamins']['C']! * ratio - ((current['vitamins'] ?? {})['C'] ?? 0.0),
        'D': DAILY_NUTRIENTS['vitamins']['D']! * ratio - ((current['vitamins'] ?? {})['D'] ?? 0.0),
      },
      'minerals': {
        'iron': DAILY_NUTRIENTS['minerals']['iron']! * ratio - ((current['minerals'] ?? {})['iron'] ?? 0.0),
        'magnesium': DAILY_NUTRIENTS['minerals']['magnesium']! * ratio - ((current['minerals'] ?? {})['magnesium'] ?? 0.0),
      }
    };
  }

  double _calculateTotalCalories(List<Meal> meals) {
    return meals.fold(0.0, (sum, meal) => sum + meal.recipe.calories);
  }

  Map<String, dynamic> _calculateDailyNutrients(List<Meal> meals) {
    final nutrients = _createEmptyNutrientsMap();
    for (final meal in meals) {
      _updateDailyNutrients(nutrients, meal.recipe.nutrients);
    }
    return nutrients;
  }

  Widget _buildNutrientProgress(String name, double value, double target) {
    final progress = value / target;
    final color = progress < 0.8 ? Colors.red :
                 progress > 1.2 ? Colors.orange :
                 kPrimaryColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$name: ${value.toStringAsFixed(1)} / ${target.toStringAsFixed(1)}'),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.5),
            backgroundColor: Colors.grey[300],
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _buildVitaminInfo(Map<String, dynamic> nutrients) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Витамины и минералы:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildNutrientProgress(
              'Витамин A (мкг)',
              nutrients['vitamins']['A'],
              DAILY_NUTRIENTS['vitamins']['A']!,
            ),
            _buildNutrientProgress(
              'Витамин C (мг)',
              nutrients['vitamins']['C'],
              DAILY_NUTRIENTS['vitamins']['C']!,
            ),
            _buildNutrientProgress(
              'Витамин D (мкг)',
              nutrients['vitamins']['D'],
              DAILY_NUTRIENTS['vitamins']['D']!,
            ),
            _buildNutrientProgress(
              'Железо (мг)',
              nutrients['minerals']['iron'],
              DAILY_NUTRIENTS['minerals']['iron']!,
            ),
            _buildNutrientProgress(
              'Магний (мг)',
              nutrients['minerals']['magnesium'],
              DAILY_NUTRIENTS['minerals']['magnesium']!,
            ),
          ],
        ),
      ),
    );
  }
}