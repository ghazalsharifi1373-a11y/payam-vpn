
import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const VPNHome(),
    );
  }
}

class VPNHome extends StatefulWidget {
  const VPNHome({super.key});

  @override
  State<VPNHome> createState() => _VPNHomeState();
}

class _VPNHomeState extends State<VPNHome> {
  late final V2ray v2ray;

  final TextEditingController configController =
      TextEditingController();

  String status = 'قطع';
  String message = 'برای اتصال، کانفیگ VLESS یا لینک پشتیبانی‌شده را وارد کن';
  bool initialized = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();

    v2ray = V2ray(
      onStatusChanged: (value) {
        if (!mounted) return;
        setState(() {
          status = value.state.toString();
        });
      },
    );

    initializeVPN();
  }

  Future<void> initializeVPN() async {
    try {
      await v2ray.initialize(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
      );

      if (!mounted) return;
      setState(() {
        initialized = true;
        message = 'موتور VPN آماده است؛ کانفیگ را وارد کن';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'خطا در راه‌اندازی موتور: $e';
      });
    }
  }

  Future<void> connectVPN() async {
    final link = configController.text.trim();

    if (link.isEmpty) {
      setState(() {
        message = 'ابتدا لینک کانفیگ را وارد کن';
      });
      return;
    }

    if (!initialized || busy) return;

    setState(() {
      busy = true;
      message = 'در حال بررسی کانفیگ...';
    });

    try {
      final parsed = V2ray.parseFromURL(link);

      final config = parsed.getFullConfiguration();

      final delay = await v2ray.getServerDelay(
        config: config,
      );

      if (!mounted) return;

      if (delay <= 0) {
        setState(() {
          message = 'سرور پاسخ نداد یا قابل دسترسی نیست';
          busy = false;
        });
        return;
      }

      setState(() {
        message = 'سرور پاسخ داد؛ زمان تأخیر: ${delay}ms';
      });

      final permission = await v2ray.requestPermission();

      if (!permission) {
        setState(() {
          message = 'اجازه اتصال VPN داده نشد';
          busy = false;
        });
        return;
      }

      v2ray.startV2Ray(
        remark: parsed.remark,
        config: config,
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );

      if (!mounted) return;
      setState(() {
        message = 'درخواست اتصال ارسال شد';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'خطای اتصال: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  void disconnectVPN() {
    try {
      v2ray.stopV2Ray();
      setState(() {
        status = 'قطع';
        message = 'اتصال قطع شد';
      });
    } catch (e) {
      setState(() {
        message = 'خطا در قطع اتصال: $e';
      });
    }
  }

  @override
  void dispose() {
    configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = status.toLowerCase().contains('connected');

    return Scaffold(
      backgroundColor: const Color(0xFF10131B),
      appBar: AppBar(
        title: const Text('PAYAM VPN'),
        centerTitle: true,
        backgroundColor: const Color(0xFF10131B),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 25),
            Icon(
              Icons.public,
              size: 105,
              color: connected ? Colors.greenAccent : Colors.white70,
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'پیام وی‌پی‌ان',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'وضعیت: $status',
                style: TextStyle(
                  fontSize: 18,
                  color: connected ? Colors.greenAccent : Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: configController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'لینک کانفیگ VLESS / VMess / Trojan / SS',
                filled: true,
                fillColor: const Color(0xFF202635),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: initialized && !busy ? connectVPN : null,
              icon: const Icon(Icons.power_settings_new),
              label: Text(busy ? 'لطفاً صبر کن...' : 'اتصال'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(55),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: disconnectVPN,
              child: const Text('قطع اتصال'),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
