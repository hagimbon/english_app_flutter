import 'package:flutter/material.dart';

class MainTab extends StatefulWidget {
  final bool isOnline;

  const MainTab({super.key, required this.isOnline});

  @override
  State<MainTab> createState() => MainTabState();
}

class MainTabState extends State<MainTab> {
  // Ví dụ tạm: để con biết trạng thái kết nối
  bool get isOnline => widget.isOnline;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Main Tab')),
      body: Center(
        child: Text(
          widget.isOnline ? '🟢 Online' : '🔴 Offline',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
