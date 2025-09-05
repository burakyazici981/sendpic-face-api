import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  final String friendId;

  const ChatScreen({
    super.key,
    required this.friendId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sohbet - $friendId'),
      ),
      body: const Center(
        child: Text('Sohbet ekranı geliştirilme aşamasında...'),
      ),
    );
  }
}
