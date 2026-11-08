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
      title: 'VPN',
      theme: ThemeData.dark(useMaterial3: true),
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
  final TextEditingController configController = TextEditingController();

  bool initialized = false;
  bool busy = false;
  bool connecting = false;
  bool connected = false;
  int selectedTab = 0;
  String message = 'موتور VPN در حال آماده‌سازی است';

  static const Color navy = Color(0xFF030817);
  static const Color blue = Color(0xFF087BFF);
  static const Color cyan = Color(0xFF00C8FF);
  static const Color green = Color(0xFF00E85D);

  @override
  void initState() {
    super.initState();
    v2ray = V2ray(
      onStatusChanged: (value) {
        if (!mounted) return;
        final state = value.state.toString().toLowerCase();
        final nowConnected =
            state.contains('connected') && !state.contains('disconnected');
        final nowConnecting = state.contains('connecting');
        setState(() {
          connected = nowConnected;
          connecting = nowConnecting;
          if (nowConnected) {
            message = 'اتصال با موفقیت برقرار شد';
          } else if (nowConnecting) {
            message = 'در حال برقراری اتصال...';
          } else if (state.contains('disconnect')) {
            message = 'اتصال قطع است';
          }
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
        message = 'آماده اتصال';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'خطا در راه‌اندازی موتور VPN: $e');
    }
  }

  Future<void> connectVPN() async {
    final link = configController.text.trim();
    if (link.isEmpty) {
      await showConfigDialog();
      return;
    }
    if (!initialized || busy || connected) return;

    setState(() {
      busy = true;
      connecting = true;
      message = 'در حال بررسی سرور...';
    });

    try {
      final parsed = V2ray.parseFromURL(link);
      final config = parsed.getFullConfiguration();
      final delay = await v2ray.getServerDelay(config: config);

      if (!mounted) return;
      if (delay <= 0) {
        setState(() {
          connecting = false;
          message = 'سرور پاسخ نداد؛ سرور دیگری را امتحان کن';
        });
        return;
      }

      setState(() => message = 'سرور آماده است؛ در حال اتصال...');
      final permission = await v2ray.requestPermission();

      if (!permission) {
        if (!mounted) return;
        setState(() {
          connecting = false;
          message = 'اجازه اتصال VPN داده نشد';
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
        connecting = true;
        message = 'در حال برقراری اتصال...';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        connecting = false;
        message = 'خطای اتصال: $e';
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void disconnectVPN() {
    try {
      v2ray.stopV2Ray();
      setState(() {
        connected = false;
        connecting = false;
        message = 'اتصال قطع شد';
      });
    } catch (e) {
      setState(() => message = 'خطا در قطع اتصال: $e');
    }
  }

  Future<void> showConfigDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101C36),
        title: const Text('تنظیم کانفیگ سرور'),
        content: TextField(
          controller: configController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'لینک VLESS / VMess / Trojan / SS',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF071329),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('بستن'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = connected || connecting;
    final accent = connected ? green : cyan;
    final statusText =
        connected ? 'Connected' : connecting ? 'Connecting...' : 'Not Connected';

    return Scaffold(
      backgroundColor: navy,
      body: Stack(
        children: [
          const Positioned.fill(child: _WorldGlowBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: showConfigDialog,
                        icon: const Icon(Icons.settings, color: Colors.white, size: 29),
                        tooltip: 'تنظیمات کانفیگ',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // موقت: پس از دریافت فایل دقیق لوگوی شماره ۱۸، این جغد جایگزین می‌شود.
                SizedBox(
                  height: 190,
                  child: Center(
                    child: Text(
                      '🦉',
                      style: TextStyle(
                        fontSize: 126,
                        shadows: [
                          Shadow(color: blue.withOpacity(.9), blurRadius: 34),
                          Shadow(color: cyan.withOpacity(.7), blurRadius: 55),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 26),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xCC07142C),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: accent, width: 1.6),
                    boxShadow: [
                      BoxShadow(color: accent.withOpacity(.22), blurRadius: 18),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        connected
                            ? Icons.circle
                            : connecting
                                ? Icons.sync
                                : Icons.signal_cellular_alt,
                        color: connected ? green : cyan,
                        size: 25,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          statusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.lightBlueAccent, size: 30),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: connected ? disconnectVPN : (connecting ? null : connectVPN),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 206,
                    height: 206,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF06142D),
                      border: Border.all(color: connected ? green : cyan, width: 5),
                      boxShadow: [
                        BoxShadow(
                          color: (connected ? green : blue).withOpacity(.72),
                          blurRadius: connected ? 38 : 27,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: cyan.withOpacity(.24),
                          blurRadius: 58,
                          spreadRadius: 9,
                        ),
                      ],
                    ),
                    child: Center(
                      child: connecting
                          ? SizedBox(
                              width: 88,
                              height: 88,
                              child: CircularProgressIndicator(
                                strokeWidth: 5,
                                valueColor: AlwaysStoppedAnimation<Color>(cyan),
                              ),
                            )
                          : Icon(
                              Icons.power_settings_new,
                              size: 92,
                              color: connected ? green : Colors.white,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  connected
                      ? 'Tap to Disconnect'
                      : connecting
                          ? 'Please Wait...'
                          : 'Tap to Connect',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 26),
                InkWell(
                  onTap: showConfigDialog,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 26),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xCC07142C),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: blue, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.language, color: cyan, size: 48),
                        const SizedBox(width: 18),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Auto Select',
                                  style: TextStyle(color: Colors.white, fontSize: 21)),
                              SizedBox(height: 2),
                              Text('Fastest Server',
                                  style: TextStyle(color: Colors.lightBlueAccent, fontSize: 15)),
                            ],
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down,
                            color: Colors.lightBlueAccent, size: 32),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xE9081730),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: blue, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: blue.withOpacity(.22), blurRadius: 20),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _navItem(Icons.bolt, 'Speed', 0),
                        _navItem(Icons.signal_cellular_alt, 'Servers', 1),
                        _navItem(Icons.history, 'History', 2),
                        _navItem(Icons.star, 'Favorites', 3),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: isActive ? accent : Colors.white54, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = selectedTab == index;
    return InkWell(
      onTap: () => setState(() => selectedTab = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: selected ? cyan : Colors.lightBlueAccent),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? cyan : Colors.lightBlueAccent,
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldGlowBackground extends StatelessWidget {
  const _WorldGlowBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF020612), Color(0xFF06132B), Color(0xFF020612)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          top: 150,
          left: -80,
          right: -80,
          child: Container(
            height: 330,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [const Color(0xFF0755C9).withOpacity(.32), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: -60,
          right: -60,
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [const Color(0xFF006BFF).withOpacity(.24), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
