import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VerifyScreen extends StatelessWidget {
  const VerifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kimlik Doğrulama'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, size: 64),
            SizedBox(height: 16),
            Text('Kimlik doğrulama sayfası'),
            Text('Bu özellik geliştirilme aşamasında...'),
          ],
        ),
      ),
    );
  }
}
