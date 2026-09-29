import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PesoScanApp());
}

class PesoScanApp extends StatelessWidget {
  const PesoScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PesoScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color.fromARGB(255, 242, 3, 3),
        colorScheme: const ColorScheme.dark(
          primary: Color.fromARGB(255, 179, 0, 255),
          surface: Color(0xFF162232),
        ),
        useMaterial3: true,
      ),
      home: const TestDashboardScreen(),
    );
  }
}

class TestDashboardScreen extends StatefulWidget {
  const TestDashboardScreen({super.key});

  @override
  State<TestDashboardScreen> createState() => _TestDashboardScreenState();
}

class _TestDashboardScreenState extends State<TestDashboardScreen> {
  double _mockTotal = 0.00;
  int _coinCount = 0;

  void _addMockCoin(double value) {
    setState(() {
      _mockTotal += value;
      _coinCount++;
    });
  }

  void _reset() {
    setState(() {
      _mockTotal = 0.00;
      _coinCount = 0;
    });
  }

  void _showResultSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF162232),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan Breakdown Preview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Detected Coins: $_coinCount',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Calculated Total: ₱${_mockTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF5A623),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5A623),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF162232),
        title: const Text(
          'PesoScan Prototype Test',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Floating Total Card preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF162232),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'TOTAL DETECTED VVasaaALUE',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₱${_mockTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF5A623),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Items: $_coinCount coins',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Tap to simulate real-time coin detection:',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 16),

            // Coin simulation buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(
                    Icons.circle,
                    size: 16,
                    color: Color(0xFFF5A623),
                  ),
                  label: const Text('+ ₱10 BSP'),
                  onPressed: () => _addMockCoin(10.0),
                ),
                ActionChip(
                  avatar: const Icon(
                    Icons.circle,
                    size: 16,
                    color: Color(0xFFF5A623),
                  ),
                  label: const Text('+ ₱5 NGC'),
                  onPressed: () => _addMockCoin(5.0),
                ),
                ActionChip(
                  avatar: const Icon(
                    Icons.circle,
                    size: 16,
                    color: Color(0xFFF5A623),
                  ),
                  label: const Text('+ ₱1 NGC'),
                  onPressed: () => _addMockCoin(1.0),
                ),
                ActionChip(
                  avatar: const Icon(
                    Icons.circle,
                    size: 16,
                    color: Color(0xFFF5A623),
                  ),
                  label: const Text('+ ₱0.25'),
                  onPressed: () => _addMockCoin(0.25),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Freeze & Breakdown Trigger
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5A623),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _coinCount > 0 ? _showResultSheet : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'Freeze & View Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
