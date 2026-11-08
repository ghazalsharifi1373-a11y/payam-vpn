import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PayamApp());
}

const String defaultServerFeedUrl =
    'https://raw.githubusercontent.com/ghazalsharifi1373-a11y/payam-vpn/main/servers.json';

class ServerEntry {
  String name;
  String country;
  String link;
  bool favorite;
  int delay;

  ServerEntry({
    required this.name,
    required this.country,
    required this.link,
    this.favorite = false,
    this.delay = -1,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'link': link,
        'favorite': favorite,
        'delay': delay,
      };

  factory ServerEntry.fromJson(Map<String, dynamic> json) {
    return ServerEntry(
      name: (json['name'] ?? 'Server').toString(),
      country: (json['country'] ?? 'Unknown').toString(),
      link: (json['link'] ?? '').toString(),
      favorite: json['favorite'] == true,
      delay: (json['delay'] as num?)?.toInt() ?? -1,
    );
  }
}

class PayamApp extends StatelessWidget {
  const PayamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Payam VPN',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07111F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00B8FF),
          secondary: Color(0xFF00D5FF),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF07111F),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final V2ray v2ray;

  List<ServerEntry> servers = [];
  List<String> history = [];

  int selectedTab = 0;
  int selectedServer = -1;

  bool initialized = false;
  bool busy = false;
  bool connected = false;
  bool speedSortEnabled = false;
  bool speedSortRunning = false;

  Timer? speedSortTimer;

  String statusText = 'Disconnected';
  String feedUrl = defaultServerFeedUrl;

  int downloadSpeed = 0;
  int uploadSpeed = 0;
  int totalDownloaded = 0;
  int totalUploaded = 0;

  @override
  void initState() {
    super.initState();

    v2ray = V2ray(
      onStatusChanged: (status) {
        if (!mounted) return;

        final state = status.state.toString().toLowerCase().trim();
        final stateName = state.split('.').last;

        setState(() {
          downloadSpeed = status.downloadSpeed;
          uploadSpeed = status.uploadSpeed;
          totalDownloaded = status.download;
          totalUploaded = status.upload;

          if (stateName == 'connected') {
            connected = true;
            statusText = 'Connected';
          } else if (stateName == 'disconnected') {
            connected = false;
            statusText = 'Disconnected';
          } else if (stateName == 'connecting') {
            connected = false;
            statusText = 'Connecting...';
          } else {
            statusText = status.state.toString();
          }
        });
      },
    );

    initializeApp();
  }

  Future<void> initializeApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedServers = prefs.getString('servers') ?? '[]';
      final savedHistory = prefs.getStringList('history') ?? [];

      final decoded = jsonDecode(savedServers) as List;

      servers = decoded
          .map((item) => ServerEntry.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((server) => server.link.isNotEmpty)
          .toList();

      history = savedHistory;
      feedUrl = prefs.getString('feedUrl') ?? defaultServerFeedUrl;

      await v2ray.initialize(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
      );

      if (!mounted) return;

      setState(() {
        initialized = true;
      });

      // Fetch the latest public server list automatically on app startup.
      unawaited(updateServers());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        initialized = true;
      });
      showMessage('Initialization error: $e');
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'servers',
      jsonEncode(servers.map((server) => server.toJson()).toList()),
    );
    await prefs.setStringList('history', history);
    await prefs.setString('feedUrl', feedUrl);
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF12334A),
      ),
    );
  }

  String formatRate(int value) {
    if (value < 1024) return '$value B/s';
    if (value < 1024 * 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(value / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  String formatData(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    if (value < 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget trafficPanel() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      color: const Color(0xFF102238),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'LIVE TRAFFIC',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.arrow_downward,
                          color: Color(0xFF00D5FF)),
                      const SizedBox(height: 5),
                      const Text('DOWNLOAD',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        connected ? formatRate(downloadSpeed) : '--',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D5FF),
                        ),
                      ),
                      Text(
                        'Total: ${formatData(totalDownloaded)}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 75, color: Colors.white24),
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.arrow_upward,
                          color: Color(0xFF48D6A5)),
                      const SizedBox(height: 5),
                      const Text('UPLOAD',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        connected ? formatRate(uploadSpeed) : '--',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF48D6A5),
                        ),
                      ),
                      Text(
                        'Total: ${formatData(totalUploaded)}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!connected)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Connect to see live speed',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> updateServers() async {
    if (busy) return;

    if (feedUrl.trim().isEmpty) {
      feedUrl = defaultServerFeedUrl;
    }

    if (!feedUrl.startsWith('https://')) {
      showMessage('Feed address must use HTTPS');
      return;
    }

    try {
      if (mounted) setState(() => busy = true);

      final response = await http
          .get(
            Uri.parse(feedUrl),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! List) {
        throw Exception('Invalid JSON format: expected a list');
      }

      int added = 0;
      int updated = 0;

      for (final item in data) {
        if (item is! Map) continue;

        final link = (item['link'] ?? '').toString().trim();
        final valid = link.startsWith('vless://') ||
            link.startsWith('vmess://') ||
            link.startsWith('trojan://') ||
            link.startsWith('ss://');

        if (!valid) continue;

        final name = (item['name'] ?? 'Online server').toString();
        final country = (item['country'] ?? 'Unknown').toString();

        final existingIndex =
            servers.indexWhere((server) => server.link == link);

        if (existingIndex >= 0) {
          servers[existingIndex].name = name;
          servers[existingIndex].country = country;
          updated++;
        } else {
          servers.add(
            ServerEntry(
              name: name,
              country: country,
              link: link,
            ),
          );
          added++;
        }
      }

      await saveData();

      if (mounted) setState(() {});
      showMessage('Server list updated: $added added, $updated refreshed');
    } catch (e) {
      showMessage('Update failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> configureFeed() async {
    final controller = TextEditingController(text: feedUrl);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF102238),
        title: const Text('Server feed URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/servers.json',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      feedUrl = result;
      await saveData();
      if (mounted) setState(() {});
      showMessage('Feed address saved');
    }

    controller.dispose();
  }

  Future<int> testServer(ServerEntry server) async {
    try {
      final parsed = V2ray.parseFromURL(server.link);
      return await v2ray
          .getServerDelay(config: parsed.getFullConfiguration())
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return -1;
    }
  }

  Future<void> chooseFastest() async {
    if (busy || servers.isEmpty) {
      showMessage('No servers available. Update the server list first.');
      return;
    }

    setState(() {
      busy = true;
      statusText = 'Testing servers...';
    });

    int bestIndex = -1;
    int bestDelay = 999999999;

    try {
      for (int i = 0; i < servers.length; i++) {
        final delay = await testServer(servers[i]);
        servers[i].delay = delay;

        if (delay > 0 && delay < bestDelay) {
          bestDelay = delay;
          bestIndex = i;
        }

        if (mounted) setState(() {});
      }

      await saveData();

      if (bestIndex == -1) {
        showMessage('No responding server found');
        if (mounted) {
          setState(() => statusText = 'No working server');
        }
        return;
      }

      if (mounted) setState(() => busy = false);
      await connectToServer(bestIndex);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> connectToServer(int index) async {
    if (!initialized ||
        busy ||
        index < 0 ||
        index >= servers.length) {
      return;
    }

    setState(() {
      busy = true;
      connected = false;
      statusText = 'Connecting...';
      downloadSpeed = 0;
      uploadSpeed = 0;
      totalDownloaded = 0;
      totalUploaded = 0;
    });

    try {
      final server = servers[index];
      final parsed = V2ray.parseFromURL(server.link);

      final permission = await v2ray.requestPermission();
      if (!permission) {
        throw Exception('VPN permission was not granted');
      }

      await v2ray.startV2Ray(
        remark: parsed.remark,
        config: parsed.getFullConfiguration(),
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );

      selectedServer = index;

      history.insert(0, server.name);
      if (history.length > 30) {
        history = history.take(30).toList();
      }

      await saveData();

      if (mounted) {
        setState(() {
          statusText = connected ? 'Connected' : 'Connecting...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          connected = false;
          statusText = 'Connection failed';
        });
      }
      showMessage('Connection error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> disconnect() async {
    try {
      await v2ray.stopV2Ray();
      if (!mounted) return;

      setState(() {
        connected = false;
        downloadSpeed = 0;
        uploadSpeed = 0;
        statusText = 'Disconnected';
      });
    } catch (e) {
      showMessage('Disconnect error: $e');
    }
  }

  Future<void> addServer() async {
    final nameController = TextEditingController();
    final countryController = TextEditingController();
    final linkController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF102238),
        title: const Text('Add server'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: 'Server name'),
              ),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(labelText: 'Country'),
              ),
              TextField(
                controller: linkController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'V2Ray link',
                  hintText: 'vless:// or vmess:// or trojan:// or ss://',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final link = linkController.text.trim();
      final valid = link.startsWith('vless://') ||
          link.startsWith('vmess://') ||
          link.startsWith('trojan://') ||
          link.startsWith('ss://');

      if (valid) {
        servers.add(
          ServerEntry(
            name: nameController.text.trim().isEmpty
                ? 'New server'
                : nameController.text.trim(),
            country: countryController.text.trim().isEmpty
                ? 'Unknown'
                : countryController.text.trim(),
            link: link,
          ),
        );
        await saveData();
        if (mounted) setState(() {});
        showMessage('Server saved');
      } else {
        showMessage('Invalid server link');
      }
    }

    nameController.dispose();
    countryController.dispose();
    linkController.dispose();
  }

  Future<void> toggleFavorite(int index) async {
    servers[index].favorite = !servers[index].favorite;
    await saveData();
    if (mounted) setState(() {});
  }

  Future<void> removeServer(int index) async {
    servers.removeAt(index);

    if (selectedServer == index) selectedServer = -1;
    if (selectedServer > index) selectedServer--;

    await saveData();
    if (mounted) setState(() {});
  }

  Future<void> refreshSpeedOrder() async {
    if (!mounted ||
        !speedSortEnabled ||
        speedSortRunning ||
        busy ||
        servers.isEmpty) {
      return;
    }

    speedSortRunning = true;
    final selectedLink =
        selectedServer >= 0 && selectedServer < servers.length
            ? servers[selectedServer].link
            : null;

    setState(() => busy = true);

    try {
      final currentServers = List<ServerEntry>.from(servers);

      for (final server in currentServers) {
        if (!mounted || !speedSortEnabled) break;
        server.delay = await testServer(server);
        if (mounted) setState(() {});
      }

      if (!mounted || !speedSortEnabled) return;

      servers.sort((a, b) {
        final aDelay = a.delay > 0 ? a.delay : 999999999;
        final bDelay = b.delay > 0 ? b.delay : 999999999;
        return aDelay.compareTo(bDelay);
      });

      if (selectedLink != null) {
        selectedServer =
            servers.indexWhere((server) => server.link == selectedLink);
      }

      await saveData();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showMessage('Speed test error: $e');
    } finally {
      speedSortRunning = false;
      if (mounted) setState(() => busy = false);
    }
  }

  void toggleSpeedSort(bool enabled) {
    setState(() => speedSortEnabled = enabled);

    speedSortTimer?.cancel();
    speedSortTimer = null;

    if (enabled) {
      refreshSpeedOrder();
      speedSortTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) {
          if (speedSortEnabled && mounted) {
            refreshSpeedOrder();
          }
        },
      );
    } else {
      showMessage('Automatic speed sorting disabled');
    }
  }

  Widget serverTile(int index) {
    final server = servers[index];

    return Card(
      color: const Color(0xFF102238),
      child: ListTile(
        leading: const Icon(Icons.public, color: Color(0xFF00B8FF)),
        title: Text(server.name),
        subtitle: Text(
          '${server.country} • '
          '${server.delay > 0 ? '${server.delay} ms' : 'Not tested'}',
        ),
        onTap: busy ? null : () => connectToServer(index),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'favorite') toggleFavorite(index);
            if (value == 'delete') removeServer(index);
            if (value == 'connect') connectToServer(index);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
                value: 'connect', child: Text('Connect')),
            const PopupMenuItem(
                value: 'favorite', child: Text('Favorite')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          child: Icon(
            server.favorite ? Icons.favorite : Icons.more_vert,
            color: server.favorite ? Colors.redAccent : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget homeView() {
    final selectedName =
        selectedServer >= 0 && selectedServer < servers.length
            ? servers[selectedServer].name
            : 'Automatic server selection';

    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 25),
            const Icon(
              Icons.travel_explore,
              size: 100,
              color: Color(0xFF00B8FF),
            ),
            const SizedBox(height: 15),
            const Text(
              'PAYAM VPN',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              statusText,
              style: const TextStyle(
                color: Color(0xFF00D5FF),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: busy
                  ? null
                  : connected
                      ? disconnect
                      : chooseFastest,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF102C46),
                  border: Border.all(
                    color: const Color(0xFF00B8FF),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x6600B8FF),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  busy
                      ? Icons.hourglass_top
                      : Icons.power_settings_new,
                  size: 75,
                  color: const Color(0xFF00D5FF),
                ),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              connected ? 'CONNECTED' : 'TAP TO CONNECT',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Text(selectedName,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            trafficPanel(),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : updateServers,
              icon: const Icon(Icons.sync),
              label: const Text('Update servers'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget currentView() {
    if (selectedTab == 0) return homeView();

    if (selectedTab == 1) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'SERVERS',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : addServer,
                  icon: const Icon(Icons.add_circle),
                ),
                IconButton(
                  onPressed: busy ? null : updateServers,
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
          ),
          SwitchListTile(
            secondary:
                const Icon(Icons.speed, color: Color(0xFF00D5FF)),
            title: const Text(
              'Sort by speed / به ترتیب سرعت',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Automatic speed test every 30 seconds',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
            value: speedSortEnabled,
            activeColor: const Color(0xFF00D5FF),
            onChanged: toggleSpeedSort,
          ),
          Expanded(
            child: servers.isEmpty
                ? const Center(child: Text('No servers added yet'))
                : ListView.builder(
                    itemCount: servers.length,
                    itemBuilder: (context, index) => serverTile(index),
                  ),
          ),
        ],
      );
    }

    if (selectedTab == 2) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'HISTORY',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          if (history.isEmpty)
            const Center(child: Text('No connection history')),
          ...history.map(
            (item) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(item),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'FAVORITES',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        ...servers.asMap().entries
            .where((entry) => entry.value.favorite)
            .map((entry) => serverTile(entry.key)),
      ],
    );
  }

  @override
  void dispose() {
    speedSortTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payam VPN'),
        actions: [
          IconButton(
            onPressed: configureFeed,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: !initialized
          ? const Center(child: CircularProgressIndicator())
          : currentView(),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF102238),
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.dns_outlined),
            selectedIcon: Icon(Icons.dns),
            label: 'Servers',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }
}
