import 'package:flutter/material.dart';
import '../home_screen.dart';

class RecipeDetailsScreen extends StatelessWidget {
  final Recipe recipe;
  final Function(Recipe) onStartTimer;

  const RecipeDetailsScreen({
    Key? key,
    required this.recipe,
    required this.onStartTimer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              recipe.imagePath,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 16),
            Text(
              'Ингредиенты:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ...recipe.ingredients.map((ingredient) => 
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Text('• $ingredient'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Описание:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Text(recipe.description),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => onStartTimer(recipe),
                icon: const Icon(Icons.timer),
                label: Text('Запустить таймер (${recipe.timeMinutes} мин)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                ).animate()
                  .scale(duration: 200.ms)
                  .then()
                  .shimmer(duration: 1000.ms),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 