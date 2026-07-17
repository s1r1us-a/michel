import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Spielzustände.
enum GameState { ready, playing, gameOver }

/// Ein Rohrpaar mit einer Lücke, durch die der Vogel fliegen muss.
class PipePair {
  PipePair({required this.x, required this.gapCenter});

  /// Horizontale Position in logischen Einheiten (0 = linker Rand).
  double x;

  /// Vertikale Mitte der Lücke als Anteil der Spielfeldhöhe (0..1).
  final double gapCenter;

  bool scored = false;
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  // Physik und Abmessungen, alles relativ zur Spielfeldhöhe (1.0 = volle Höhe).
  static const double _gravity = 2.4; // Beschleunigung pro Sekunde²
  static const double _jumpVelocity = -0.78; // Sprungimpuls
  static const double _pipeSpeed = 0.42; // horizontale Geschwindigkeit
  static const double _pipeSpacing = 0.62; // Abstand zwischen Rohrpaaren
  static const double _pipeWidth = 0.16;
  static const double _gapHeight = 0.30;
  static const double _birdX = 0.28; // feste x-Position des Vogels
  static const double _birdRadius = 0.036;
  static const double _groundHeight = 0.12;

  final Random _random = Random();

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  GameState _state = GameState.ready;
  double _birdY = 0.45; // Anteil der Spielfeldhöhe
  double _birdVelocity = 0;
  double _idleTime = 0; // für das Auf-und-ab-Schweben im Ready-Zustand
  final List<PipePair> _pipes = [];
  int _score = 0;
  int _bestScore = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final double dt =
        min((elapsed - _lastTick).inMicroseconds / 1e6, 1 / 30);
    _lastTick = elapsed;

    setState(() {
      switch (_state) {
        case GameState.ready:
          _idleTime += dt;
          _birdY = 0.45 + 0.015 * sin(_idleTime * 4);
        case GameState.playing:
          _updatePlaying(dt);
        case GameState.gameOver:
          // Der Vogel fällt nach dem Aufprall noch zu Boden.
          if (_birdY < 1 - _groundHeight - _birdRadius) {
            _birdVelocity += _gravity * dt;
            _birdY = min(
                _birdY + _birdVelocity * dt, 1 - _groundHeight - _birdRadius);
          }
      }
    });
  }

  void _updatePlaying(double dt) {
    _birdVelocity += _gravity * dt;
    _birdY += _birdVelocity * dt;

    for (final pipe in _pipes) {
      pipe.x -= _pipeSpeed * dt;
      if (!pipe.scored && pipe.x + _pipeWidth < _birdX) {
        pipe.scored = true;
        _score++;
        HapticFeedback.lightImpact();
      }
    }
    _pipes.removeWhere((p) => p.x + _pipeWidth < -0.1);

    if (_pipes.isEmpty || _pipes.last.x < 1.2 - _pipeSpacing) {
      _spawnPipe();
    }

    if (_checkCollision()) {
      _gameOver();
    }
  }

  void _spawnPipe() {
    final double margin = _gapHeight / 2 + 0.06;
    final double gapCenter = margin +
        _random.nextDouble() * (1 - _groundHeight - 2 * margin);
    _pipes.add(PipePair(x: 1.2, gapCenter: gapCenter));
  }

  bool _checkCollision() {
    // Boden und Decke
    if (_birdY + _birdRadius >= 1 - _groundHeight) return true;
    if (_birdY - _birdRadius <= 0) return true;

    for (final pipe in _pipes) {
      final bool overlapsX = _birdX + _birdRadius > pipe.x &&
          _birdX - _birdRadius < pipe.x + _pipeWidth;
      if (!overlapsX) continue;
      final double gapTop = pipe.gapCenter - _gapHeight / 2;
      final double gapBottom = pipe.gapCenter + _gapHeight / 2;
      if (_birdY - _birdRadius < gapTop || _birdY + _birdRadius > gapBottom) {
        return true;
      }
    }
    return false;
  }

  void _gameOver() {
    _state = GameState.gameOver;
    _bestScore = max(_bestScore, _score);
    HapticFeedback.heavyImpact();
  }

  void _onTap() {
    setState(() {
      switch (_state) {
        case GameState.ready:
          _state = GameState.playing;
          _birdVelocity = _jumpVelocity;
        case GameState.playing:
          _birdVelocity = _jumpVelocity;
        case GameState.gameOver:
          _reset();
      }
    });
  }

  void _reset() {
    _state = GameState.ready;
    _birdY = 0.45;
    _birdVelocity = 0;
    _idleTime = 0;
    _pipes.clear();
    _score = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: GamePainter(
                birdY: _birdY,
                birdVelocity: _birdVelocity,
                birdX: _birdX,
                birdRadius: _birdRadius,
                pipes: _pipes,
                pipeWidth: _pipeWidth,
                gapHeight: _gapHeight,
                groundHeight: _groundHeight,
                scrollOffset: _lastTick.inMicroseconds / 1e6,
                isScrolling: _state != GameState.gameOver,
              ),
            ),
            _buildOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final TextStyle scoreStyle = TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      shadows: [
        Shadow(offset: const Offset(2, 3), color: Colors.black.withOpacity(0.4)),
      ],
    );

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 24),
          if (_state != GameState.ready)
            Text('$_score', style: scoreStyle),
          const Spacer(),
          if (_state == GameState.ready)
            const _InfoCard(
              title: 'Flappy Bird',
              subtitle: 'Tippen zum Starten',
            ),
          if (_state == GameState.gameOver)
            _InfoCard(
              title: 'Game Over',
              subtitle:
                  'Punkte: $_score   ·   Rekord: $_bestScore\nTippen für neue Runde',
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zeichnet Himmel, Wolken, Rohre, Boden und den Vogel.
class GamePainter extends CustomPainter {
  GamePainter({
    required this.birdY,
    required this.birdVelocity,
    required this.birdX,
    required this.birdRadius,
    required this.pipes,
    required this.pipeWidth,
    required this.gapHeight,
    required this.groundHeight,
    required this.scrollOffset,
    required this.isScrolling,
  });

  final double birdY;
  final double birdVelocity;
  final double birdX;
  final double birdRadius;
  final List<PipePair> pipes;
  final double pipeWidth;
  final double gapHeight;
  final double groundHeight;
  final double scrollOffset;
  final bool isScrolling;

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.height;
    final double w = size.width;

    // Himmel
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4EC0CA), Color(0xFF8ED6DC)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    _paintClouds(canvas, w, h);
    for (final pipe in pipes) {
      _paintPipe(canvas, pipe, w, h);
    }
    _paintGround(canvas, w, h);
    _paintBird(canvas, w, h);
  }

  void _paintClouds(Canvas canvas, double w, double h) {
    final Paint paint = Paint()..color = Colors.white.withOpacity(0.7);
    final double drift = isScrolling ? scrollOffset * 0.02 : 0;
    for (int i = 0; i < 4; i++) {
      final double cx = ((i * 0.31 + 0.1 - drift) % 1.2 - 0.1) * w;
      final double cy = (0.12 + 0.13 * ((i * 7) % 3)) * h;
      final double r = h * (0.025 + 0.008 * (i % 2));
      canvas.drawCircle(Offset(cx, cy), r * 1.6, paint);
      canvas.drawCircle(Offset(cx - r * 1.4, cy + r * 0.4), r, paint);
      canvas.drawCircle(Offset(cx + r * 1.5, cy + r * 0.3), r * 1.1, paint);
    }
  }

  void _paintPipe(Canvas canvas, PipePair pipe, double w, double h) {
    final Paint body = Paint()..color = const Color(0xFF5EBB4C);
    final Paint edge = Paint()..color = const Color(0xFF3E8A32);

    final double x = pipe.x * w;
    final double pw = pipeWidth * w;
    final double gapTop = (pipe.gapCenter - gapHeight / 2) * h;
    final double gapBottom = (pipe.gapCenter + gapHeight / 2) * h;
    final double groundY = (1 - groundHeight) * h;
    final double lipHeight = h * 0.035;
    final double lipOverhang = pw * 0.08;

    // Oberes Rohr
    canvas.drawRect(Rect.fromLTRB(x, 0, x + pw, gapTop - lipHeight), body);
    canvas.drawRect(
      Rect.fromLTRB(
          x - lipOverhang, gapTop - lipHeight, x + pw + lipOverhang, gapTop),
      edge,
    );

    // Unteres Rohr
    canvas.drawRect(
        Rect.fromLTRB(x, gapBottom + lipHeight, x + pw, groundY), body);
    canvas.drawRect(
      Rect.fromLTRB(x - lipOverhang, gapBottom, x + pw + lipOverhang,
          gapBottom + lipHeight),
      edge,
    );

    // Glanzstreifen
    final Paint highlight = Paint()..color = Colors.white.withOpacity(0.25);
    canvas.drawRect(
        Rect.fromLTRB(x + pw * 0.12, 0, x + pw * 0.28, gapTop - lipHeight),
        highlight);
    canvas.drawRect(
        Rect.fromLTRB(
            x + pw * 0.12, gapBottom + lipHeight, x + pw * 0.28, groundY),
        highlight);
  }

  void _paintGround(Canvas canvas, double w, double h) {
    final double groundY = (1 - groundHeight) * h;
    canvas.drawRect(
      Rect.fromLTRB(0, groundY, w, h),
      Paint()..color = const Color(0xFFDED895),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, groundY, w, groundY + h * 0.012),
      Paint()..color = const Color(0xFF7BC15E),
    );

    // Gestreiftes Bodenmuster, das nach links scrollt.
    final Paint stripe = Paint()..color = const Color(0xFFC9C173);
    final double stripeWidth = w * 0.06;
    final double shift =
        isScrolling ? (scrollOffset * 0.42 * w) % (stripeWidth * 2) : 0;
    for (double sx = -stripeWidth * 2 - shift; sx < w; sx += stripeWidth * 2) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, groundY + h * 0.012, w, h));
      final Path p = Path()
        ..moveTo(sx, groundY + h * 0.012)
        ..lineTo(sx + stripeWidth, groundY + h * 0.012)
        ..lineTo(sx + stripeWidth * 1.6, h)
        ..lineTo(sx + stripeWidth * 0.6, h)
        ..close();
      canvas.drawPath(p, stripe);
      canvas.restore();
    }
  }

  void _paintBird(Canvas canvas, double w, double h) {
    final double cx = birdX * w;
    final double cy = birdY * h;
    final double r = birdRadius * h;

    // Neigung je nach Fluggeschwindigkeit
    final double angle = (birdVelocity * 0.6).clamp(-0.5, 0.9);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    // Körper
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2.3, height: r * 2),
      Paint()..color = const Color(0xFFF7C531),
    );
    // Flügel
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(-r * 0.35, r * 0.15), width: r * 1.1, height: r * 0.8),
      Paint()..color = const Color(0xFFE8A427),
    );
    // Auge
    canvas.drawCircle(
        Offset(r * 0.45, -r * 0.35), r * 0.42, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(r * 0.58, -r * 0.35), r * 0.18,
        Paint()..color = Colors.black87);
    // Schnabel
    final Path beak = Path()
      ..moveTo(r * 0.8, 0)
      ..lineTo(r * 1.5, r * 0.12)
      ..lineTo(r * 0.8, r * 0.45)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFE0662F));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
