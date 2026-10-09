import 'package:flutter/material.dart';

import 'storage/app_store.dart';
import 'ui/history_screen.dart';
import 'ui/order_screen.dart';
import 'ui/quote_screen.dart';
import 'ui/setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.instance.load();
  runApp(const MenchuangApp());
}

class MenchuangApp extends StatelessWidget {
  const MenchuangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '门窗计价',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B6B4A),
      ),
      home: AnimatedBuilder(
        animation: AppStore.instance,
        builder: (context, _) {
          // 价格表没设置好 → 直接进设置页(第一次打开就是这里)
          if (!AppStore.instance.priceTable.isReady) {
            return const SetupScreen(firstRun: true);
          }
          return const HomeShell();
        },
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final draftCount = AppStore.instance.draft.items.length;
        return Scaffold(
          appBar: AppBar(
            title: const Text('门窗计价'),
            actions: [
              IconButton(
                tooltip: '价格表设置',
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const SetupScreen()),
                ),
              ),
            ],
          ),
          body: IndexedStack(
            index: _index,
            children: [
              QuoteScreen(onAdded: () => setState(() => _index = 1)),
              OrderScreen(onAddItem: () => setState(() => _index = 0)),
              const HistoryScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.calculate_outlined),
                  selectedIcon: Icon(Icons.calculate),
                  label: '计价'),
              NavigationDestination(
                  icon: Badge(
                    isLabelVisible: draftCount > 0,
                    label: Text('$draftCount'),
                    child: const Icon(Icons.receipt_long_outlined),
                  ),
                  selectedIcon: const Icon(Icons.receipt_long),
                  label: '订单'),
              const NavigationDestination(
                  icon: Icon(Icons.history), label: '历史'),
            ],
          ),
        );
      },
    );
  }
}
