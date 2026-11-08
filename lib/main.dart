
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030817),
        useMaterial3: true,
      ),
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

  bool initialized = false;
  bool busy = false;
  bool connecting = false;
  bool connected = false;

  int selectedTab = 0;
  String message = 'در حال آماده‌سازی موتور اتصال';

  static const Color blue = Color(0xFF087BFF);
  static const Color cyan = Color(0xFF00C8FF);
  static const Color green = Color(0xFF00E85D);
  static const Color background = Color(0xFF030817);

  @override
  void initState() {
    super.initState();

    v2ray = V2ray(
      onStatusChanged: (value) {
        if (!mounted) return;

        final state = value.state.toString().toLowerCase();

        setState(() {
          connected = state.contains('connected') &&
              !state.contains('disconnected');

          connecting = state.contains('connecting');

          if (connected) {
            message = 'اتصال برقرار است';
          } else if (connecting) {
            message = 'در حال اتصال...';
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

      setState(() {
        message = 'خطا در آماده‌سازی موتور VPN';
      });
    }
  }

  Future<void> connectVPN() async {
    final link = configController.text.trim();

    if (link.isEmpty) {
      await showConfigDialog();
      return;
    }

    if (!initialized || busy || connected || connecting) {
      return;
    }

    setState(() {
      busy = true;
      connecting = true;
      message = 'در حال بررسی سرور...';
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
          connecting = false;
          message = 'سرور پاسخ نمی‌دهد';
        });
        return;
      }

      setState(() {
        message = 'سرور آماده است؛ در حال اتصال...';
      });

      final permission = await v2ray.requestPermission();

      if (!permission) {
        if (!mounted) return;

        setState(() {
          connecting = false;
          message = 'اجازه اتصال VPN داده نشد';
        });
        return;
      }

      await v2ray.startV2Ray(
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
        connecting = false;
        connected = false;
        message = 'خطا در اتصال؛ کانفیگ را بررسی کن';
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
        connected = false;
        connecting = false;
        message = 'اتصال قطع شد';
      });
    } catch (e) {
      setState(() {
        message = 'خطا در قطع اتصال';
      });
    }
  }

  Future<void> showConfigDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101C36),
          title: const Text('افزودن کانفیگ سرور'),
          content: TextField(
            controller: configController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'لینک VLESS / VMess / Trojan / SS',
              hintStyle: const TextStyle(
                color: Colors.white54,
              ),
              filled: true,
              fillColor: const Color(0xFF071329),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() {
                  message = 'کانفیگ ذخیره شد';
                });
              },
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = connected ? green : cyan;

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WorldBackground(),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PAYAM VPN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        onPressed: showConfigDialog,
                        icon: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  height: 150,
                  alignment: Alignment.center,
                  child: const Text(
                    '🦉',
                    style: TextStyle(
                      fontSize: 112,
                      shadows: [
                        Shadow(
                          color: blue,
                          blurRadius: 35,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 25,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xCC07142C),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: accent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        connected
                            ? Icons.check_circle
                            : Icons.wifi,
                        color: accent,
                        size: 25,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          connected
                              ? 'CONNECTED'
                              : connecting
                                  ? 'CONNECTING'
                                  : 'NOT CONNECTED',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                GestureDetector(
                  onTap: connected
                      ? disconnectVPN
                      : connecting || busy
                          ? null
                          : connectVPN,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 205,
                    height: 205,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF06142D),
                      border: Border.all(
                        color: accent,
                        width: 5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.55),
                          blurRadius: 35,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: connecting || busy
                          ? const CircularProgressIndicator(
                              color: cyan,
                              strokeWidth: 5,
                            )
                          : Icon(
                              Icons.power_settings_new,
                              size: 90,
                              color: connected
                                  ? green
                                  : Colors.white,
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 17),

                Text(
                  connected
                      ? 'Tap to Disconnect'
                      : connecting
                          ? 'Please Wait...'
                          : 'Tap to Connect',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 25),

                InkWell(
                  onTap: showConfigDialog,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 25,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xCC07142C),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: blue,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.public,
                          color: cyan,
                          size: 42,
                        ),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Server Selection',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Add or change server config',
                                style: TextStyle(
                                  color: Colors.lightBlueAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: cyan,
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                Container(
                  margin: const EdgeInsets.fromLTRB(
                    15, 0, 15, 12,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xE9081730),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: blue,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                    children: [
                      navItem(Icons.bolt, 'Speed', 0),
                      navItem(
                        Icons.dns,
                        'Servers',
                        1,
                      ),
                      navItem(
                        Icons.history,
                        'History',
                        2,
                      ),
                      navItem(
                        Icons.star,
                        'Favorites',
                        3,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 5,
                    left: 12,
                    right: 12,
                  ),
                  child: Text(
                    initialized
                        ? message
                        : 'در انتظار آماده‌سازی موتور VPN',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget navItem(
    IconData icon,
    String label,
    int index,
  ) {
    final selected = selectedTab == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedTab = index;
        });

        if (index == 1) {
          showConfigDialog();
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 27,
              color: selected ? cyan : Colors.lightBlueAccent,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? cyan : Colors.lightBlueAccent,
                fontSize: 12,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorldBackground extends StatelessWidget {
  const WorldBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF020612),
                Color(0xFF06132B),
                Color(0xFF020612),
              ],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          top: 140,
          left: -80,
          right: -80,
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0755C9).withOpacity(0.30),
                  Colors.transparent,
                ],
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
                colors: [
                  const Color(0xFF006BFF).withOpacity(0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
