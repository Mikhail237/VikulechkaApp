import 'package:flutter_test/flutter_test.dart';
import 'package:vikulechka_app/home_screen.dart';

void main() {
  test('Recipe initialization', () {
    final recipe = Recipe(
      name: 'Тестовый рецепт',
      timeMinutes: 30,
      calories: 200,
      points: 20,
      category: RecipeCategory.mainDish,
      description: 'Тестовое описание',
      ingredients: ['Ингредиент 1', 'Ингредиент 2'],
    );
    expect(recipe.name, 'Тестовый рецепт');
    expect(recipe.timeMinutes, 30);
    expect(recipe.calories, 200);
  });

  test('Achievement checking', () {
    final achievements = [
      Achievement(
        name: 'Новичок в кухне',
        description: 'Добавь первый рецепт',
        points: 50,
      ),
    ];
    expect(achievements[0].points, 50);
  });
} 