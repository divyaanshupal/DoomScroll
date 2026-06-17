import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class StatsScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeNotifier;
  
  const StatsScreen({super.key, required this.themeNotifier});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with WidgetsBindingObserver {
  static const _usageChannel = MethodChannel('com.example.distract/usage');
  
  bool _hasPermission = false;
  List<Map<dynamic, dynamic>> _appUsageList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUsageData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUsageData();
    }
  }

  Future<void> _loadUsageData() async {
    setState(() => _isLoading = true);
    try {
      final bool hasPerm = await _usageChannel.invokeMethod('hasUsagePermission');
      if (hasPerm) {
        final List<dynamic> data = await _usageChannel.invokeMethod('getDailyUsage');
        setState(() {
          _appUsageList = data.cast<Map<dynamic, dynamic>>();
        });
      }
      setState(() {
        _hasPermission = hasPerm;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Usage stats error: $e');
      setState(() => _isLoading = false);
    }
  }

  // Helper colors based on theme
  Color get _bg => widget.themeNotifier.value == ThemeMode.dark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
  Color get _surface => widget.themeNotifier.value == ThemeMode.dark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F5);
  Color get _textPrimary => widget.themeNotifier.value == ThemeMode.dark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A);
  Color get _textSecondary => widget.themeNotifier.value == ThemeMode.dark ? const Color(0xFF9A9A9A) : const Color(0xFF6B6B6B);
  Color get _accent => const Color(0xFFE91E63);

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Screen Time Stats', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: _textPrimary)),
        iconTheme: IconThemeData(color: _textPrimary),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: _accent))
          : !_hasPermission 
              ? _buildPermissionRequest() 
              : _buildStatsList(),
    );
  }

  Widget _buildPermissionRequest() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_rounded, size: 80, color: _surface),
          const SizedBox(height: 24),
          Text(
            'Unlock Usage Stats',
            style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            'To see exactly how much time you spend on each app, Android requires you to grant Usage Access.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 14, color: _textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _usageChannel.invokeMethod('openUsageSettings'),
            child: Text('Grant Permission', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsList() {
    if (_appUsageList.isEmpty) {
      return Center(child: Text('No app usage recorded today yet.', style: TextStyle(color: _textSecondary)));
    }

    final int maxMinutes = _appUsageList.isNotEmpty ? _appUsageList.first['minutes'] as int : 1;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: _appUsageList.length,
      itemBuilder: (context, index) {
        final app = _appUsageList[index];
        final String name = app['appName'] as String;
        final int mins = app['minutes'] as int;
        final double percentage = (mins / maxMinutes).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16, color: _textPrimary)),
                  Text(_formatTime(mins), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16, color: _accent)),
                ],
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  Container(height: 8, decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(4))),
                  FractionallySizedBox(
                    widthFactor: percentage,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}