import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:distract/statsScreen.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.light,
);

class DistractApp extends StatelessWidget {
  const DistractApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Mindful Scrolls',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: const DashboardScreen(),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textTheme = GoogleFonts.dmSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    return ThemeData(
      brightness: brightness,
      textTheme: textTheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF111111)
          : const Color(0xFFFFFFFF),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A),
        onPrimary: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
        secondary: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F5),
        onSecondary: isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A),
        surface: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF),
        onSurface: isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A),
        error: const Color(0xFFE24B4A),
        onError: const Color(0xFFFFFFFF),
      ),
      useMaterial3: true,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  static const _platform = MethodChannel('com.example.distract/channel');

  int _instaCount = 0;
  int _ytCount = 0;
  int get _totalCount => _instaCount + _ytCount;

  bool _isAccessibilityEnabled = false;
  bool _isOverlayEnabled = false;
  int _selectedNav = 0;
  bool _hasPromptedPermissions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();

    _platform.setMethodCallHandler((call) async {
      if (call.method == 'onScrollUpdated') {
        try {
          if (call.arguments is Map) {
            final args = call.arguments as Map;
            setState(() {
              _instaCount = (args['insta'] as int?) ?? 0;
              _ytCount = (args['yt'] as int?) ?? 0;
            });
          }
        } catch (e) {
          debugPrint('Update error: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeData();
    }
  }

  Future<void> _initializeData() async {
    bool acc = false;
    bool overlay = false;
    int insta = 0;
    int yt = 0;

    try {
      acc = await _platform.invokeMethod('isAccessibilityEnabled') ?? false;
    } catch (_) {}
    try {
      overlay = await _platform.invokeMethod('isOverlayEnabled') ?? false;
    } catch (_) {}
    try {
      final dynamic data = await _platform.invokeMethod('getInitialCount');
      if (data is Map) {
        insta = (data['insta'] as int?) ?? 0;
        yt = (data['yt'] as int?) ?? 0;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isAccessibilityEnabled = acc;
        _isOverlayEnabled = overlay;
        _instaCount = insta;
        _ytCount = yt;
      });

      // Show auto-prompt on first open if permissions are missing
      if (!_hasPromptedPermissions && (!acc || !overlay)) {
        _hasPromptedPermissions = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPermissionOnboardingDialog();
        });
      }
    }
  }

  void _showPermissionOnboardingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: _textPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Permissions needed',
                style: GoogleFonts.dmSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mindful Scrolls needs two permissions to track your scrolling in the background.',
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  height: 1.45,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _buildDialogPermissionRow(
                icon: Icons.track_changes_rounded,
                label: 'Accessibility access',
              ),
              const SizedBox(height: 10),
              _buildDialogPermissionRow(
                icon: Icons.layers_rounded,
                label: 'Display over other apps',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Not now',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _textPrimary,
                        foregroundColor: _bg,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        if (!_isAccessibilityEnabled) {
                          _platform.invokeMethod('openAccessibilitySettings');
                        } else if (!_isOverlayEnabled) {
                          _platform.invokeMethod('openOverlaySettings');
                        }
                      },
                      child: Text(
                        'Continue',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogPermissionRow({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Colors ──────────────────────────────────────────────────────────────
  Color get _bg => themeModeNotifier.value == ThemeMode.dark
      ? const Color(0xFF111111)
      : const Color(0xFFFFFFFF);
  Color get _surface => themeModeNotifier.value == ThemeMode.dark
      ? const Color(0xFF1A1A1A)
      : const Color(0xFFF7F7F5);
  Color get _card => themeModeNotifier.value == ThemeMode.dark
      ? const Color(0xFF1E1E1E)
      : const Color(0xFFFFFFFF);
  Color get _textPrimary => themeModeNotifier.value == ThemeMode.dark
      ? const Color(0xFFF2F2F2)
      : const Color(0xFF1A1A1A);
  Color get _textSecondary => themeModeNotifier.value == ThemeMode.dark
      ? const Color(0xFF9A9A9A)
      : const Color(0xFF6B6B6B);
  Color get _textMuted => themeModeNotifier.value == ThemeMode.dark
      ? const Color(0xFF5A5A5A)
      : const Color(0xFFA0A0A0);
  Color get _border => themeModeNotifier.value == ThemeMode.dark
      ? const Color(0xFF2A2A2A)
      : const Color(0xFFEEEEEE);
  Color get _activeGreen => themeModeNotifier.value == ThemeMode.dark
      ? const Color(0xFF4ADE80)
      : const Color(0xFF16A34A);
  Color get _activeGreenBg => themeModeNotifier.value == ThemeMode.dark
      ? const Color(0xFF4ADE80).withOpacity(0.08)
      : const Color(0xFF16A34A).withOpacity(0.07);
  Color get _activeGreenBorder => themeModeNotifier.value == ThemeMode.dark
      ? const Color(0xFF4ADE80).withOpacity(0.2)
      : const Color(0xFF16A34A).withOpacity(0.25);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCounterCard(),
                        const SizedBox(height: 16),
                        _buildMiniStats(),
                        const SizedBox(height: 28),
                        _buildSectionLabel('Platform Breakdown'),
                        const SizedBox(height: 12),
                        _buildPlatformStatRow(
                          title: 'Instagram Reels',
                          icon: Icons.camera_alt_rounded,
                          count: _instaCount,
                        ),
                        const SizedBox(height: 10),
                        _buildPlatformStatRow(
                          title: 'YouTube Shorts',
                          icon: Icons.play_circle_fill_rounded,
                          count: _ytCount,
                        ),
                        const SizedBox(height: 28),
                        _buildSectionLabel('Permissions'),
                        const SizedBox(height: 12),
                        _buildPermissionCard(
                          title: 'Background tracker',
                          subtitle: _isAccessibilityEnabled
                              ? 'Active'
                              : 'Needs accessibility permission',
                          icon: Icons.track_changes_rounded,
                          isEnabled: _isAccessibilityEnabled,
                          onTap: () => _platform.invokeMethod(
                            'openAccessibilitySettings',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildPermissionCard(
                          title: 'Floating overlay',
                          subtitle: _isOverlayEnabled
                              ? 'Active'
                              : 'Needs display over other apps',
                          icon: Icons.layers_rounded,
                          isEnabled: _isOverlayEnabled,
                          onTap: () =>
                              _platform.invokeMethod('openOverlaySettings'),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TODAY',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Mindful Scrolls',
                style: GoogleFonts.dmSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => themeModeNotifier.value = isDark
                ? ThemeMode.light
                : ThemeMode.dark,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: _textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Text(
            'TOTAL SWIPES',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.1,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$_totalCount',
            style: GoogleFonts.dmSans(
              fontSize: 80,
              fontWeight: FontWeight.w700,
              letterSpacing: -4,
              color: _textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'combined across platforms',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: _textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStats() {
    return Row(
      children: [
        _buildMiniStatCard('12m', 'Time saved'),
        const SizedBox(width: 10),
        _buildMiniStatCard('3', 'Day streak'),
        const SizedBox(width: 10),
        _buildMiniStatCard('↑14%', 'vs yesterday'),
      ],
    );
  }

  Widget _buildMiniStatCard(String value, String label) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: _textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.1,
        color: _textMuted,
      ),
    );
  }

  Widget _buildPlatformStatRow({
    required String title,
    required IconData icon,
    required int count,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Icon(icon, color: _textSecondary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isEnabled ? _activeGreenBg : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isEnabled ? _activeGreenBorder : _border),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isEnabled ? _activeGreenBg : _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEnabled ? _activeGreenBorder : _border,
                ),
              ),
              child: Icon(
                icon,
                color: isEnabled ? _activeGreen : _textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: isEnabled ? _activeGreen : _textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            _buildToggle(isEnabled),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(bool isOn) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 27,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isOn ? _activeGreen : _border,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 21,
                height: 21,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.bar_chart_rounded, 'Stats'),
      (Icons.settings_rounded, 'Settings'),
    ];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final selected = _selectedNav == i;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedNav = i);
              if (i == 1) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        StatsScreen(themeNotifier: themeModeNotifier),
                  ),
                );
              }
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _surface : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    items[i].$1,
                    size: 20,
                    color: selected ? _textPrimary : _textMuted,
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Text(
                      items[i].$2,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
