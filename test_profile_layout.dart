import 'package:flutter/material.dart';

void main() => runApp(const TestApp());

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Симуляция ProfileTile
                  for (int i = 0; i < 7; i++) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.settings),
                        title: Text('Пункт меню ${i + 1}'),
                        subtitle: Text('Подзаголовок ${i + 1}'),
                        trailing: const Icon(Icons.chevron_right),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    if (i < 6) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
