import 'package:flutter/material.dart';

void main() {
  runApp(const PayamVPN());
}

class PayamVPN extends StatelessWidget {
  const PayamVPN({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Payam VPN',
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: const Text('PAYAM VPN'),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shield,
              size: 100,
              color: Colors.red,
            ),
            const SizedBox(height: 25),
            const Text(
              'پیام وی‌پی‌ان',
              style: TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {},
              child: const Text('اتصال'),
            ),
            const SizedBox(height: 20),
            const Text('انتخاب کشور'),
            const SizedBox(height: 10),
            const Text('وضعیت: قطع'),
          ],
        ),
      ),
    );
  }
}
