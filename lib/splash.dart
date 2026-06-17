import 'package:distract/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Splash screen ────────────────────────────────────────────────────────────
// Usage: set this as your initial route, then navigate to DashboardScreen
// after the animation completes (the onDone callback fires at ~2.4s).
//
// Example in MaterialApp:
//   home: SplashScreen(onDone: () {
//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(builder: (_) => const DashboardScreen()),
//     );
//   }),

class SplashScreen extends StatefulWidget {
  final VoidCallback? onDone;

  const SplashScreen({super.key, this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────────────────
  late final AnimationController _fadeController;
  late final AnimationController _loaderController;

  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;
  late final Animation<double> _loaderAnim;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    // Hide system UI for full immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Fade + slide in: 0 → 700ms
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    // Progress bar: 0 → 2000ms, starts after 300ms delay
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _loaderAnim = CurvedAnimation(
      parent: _loaderController,
      curve: Curves.easeInOut,
    );

    // Exit fade: last 300ms
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _loaderController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Step 1: fade + slide content in
    await Future.delayed(const Duration(milliseconds: 200));
    await _fadeController.forward();

    // Step 2: run progress bar
    await Future.delayed(const Duration(milliseconds: 100));
    _loaderController.forward();

    // Step 3: when loader finishes, restore system UI and call onDone
    _loaderController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        widget.onDone?.call();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  // ── Colors (mirrors dashboard palette) ────────────────────────────────
  bool get _isDark =>
      themeModeNotifier.value == ThemeMode.dark;

  Color get _bg =>
      _isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);

  Color get _surface =>
      _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F5);

  Color get _border =>
      _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

  Color get _textPrimary =>
      _isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A);

  Color get _textMuted =>
      _isDark ? const Color(0xFF5A5A5A) : const Color(0xFFA0A0A0);

  Color get _loaderTrack =>
      _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

  Color get _iconFg =>
      _isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A);

  Color get _iconLineFg =>
      _isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);

  Color get _activeGreen =>
      _isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);

  Color get _checkFg =>
      _isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: _bg,
          body: FadeTransition(
            opacity: _exitFade,
            child: Stack(
              children: [
                // ── Center content ─────────────────────────────────────
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: AnimatedBuilder(
                      animation: _slideAnim,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnim.value),
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLogoIcon(),
                          const SizedBox(height: 22),
                          Text(
                            'Mindful Scrolls',
                            style: GoogleFonts.dmSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'SCROLL WITH INTENTION',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.4,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Bottom loader + version ────────────────────────────
                Positioned(
                  bottom: 48,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        _buildLoader(),
                        const SizedBox(height: 14),
                        Text(
                          'v1.0.0',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: _loaderTrack,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Logo icon ────────────────────────────────────────────────────────
  Widget _buildLogoIcon() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(40, 40),
          painter: _LogoPainter(
            pageFill: _iconFg,
            lineColor: _iconLineFg,
            dotColor: _activeGreen,
            checkColor: _checkFg,
          ),
        ),
      ),
    );
  }

  // ── Progress loader ──────────────────────────────────────────────────
  Widget _buildLoader() {
    return Center(
      child: SizedBox(
        width: 48,
        height: 2,
        child: AnimatedBuilder(
          animation: _loaderAnim,
          builder: (context, _) {
            return Stack(
              children: [
                // Track
                Container(
                  decoration: BoxDecoration(
                    color: _loaderTrack,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Fill
                FractionallySizedBox(
                  widthFactor: _loaderAnim.value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _textPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Logo painter ─────────────────────────────────────────────────────────────
class _LogoPainter extends CustomPainter {
  final Color pageFill;
  final Color lineColor;
  final Color dotColor;
  final Color checkColor;

  const _LogoPainter({
    required this.pageFill,
    required this.lineColor,
    required this.dotColor,
    required this.checkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // ── Page / document body ──
    final pagePaint = Paint()..color = pageFill;
    final pageRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, 0, w * 0.8, h * 0.9),
      const Radius.circular(5),
    );
    canvas.drawRRect(pageRect, pagePaint);

    // ── Horizontal lines ──
    final linePaint = Paint()
      ..color = lineColor.withOpacity(0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w * 0.25, h * 0.28),
      Offset(w * 0.75, h * 0.28),
      linePaint,
    );

    linePaint.color = lineColor.withOpacity(0.5);
    canvas.drawLine(
      Offset(w * 0.25, h * 0.44),
      Offset(w * 0.62, h * 0.44),
      linePaint,
    );
    canvas.drawLine(
      Offset(w * 0.25, h * 0.58),
      Offset(w * 0.70, h * 0.58),
      linePaint,
    );

    // ── Green check circle (bottom-right) ──
    final circlePaint = Paint()..color = dotColor;
    canvas.drawCircle(Offset(w * 0.75, h * 0.80), w * 0.18, circlePaint);

    // ── Check mark ──
    final checkPaint = Paint()
      ..color = checkColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(w * 0.65, h * 0.80)
      ..lineTo(w * 0.73, h * 0.88)
      ..lineTo(w * 0.86, h * 0.72);

    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.pageFill != pageFill ||
      old.lineColor != lineColor ||
      old.dotColor != dotColor ||
      old.checkColor != checkColor;
}