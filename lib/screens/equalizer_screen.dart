import 'package:flutter/material.dart';

import '../data/equalizer.dart';

/// Ecualizador funcional con panel plateado: interruptor, 5 bandas con fader y LED, presets.
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  late final Future<bool> _ready = Eq.apply();

  String _hz(double f) => f >= 1000 ? '${(f / 1000).toStringAsFixed(f >= 10000 ? 0 : 1)} kHz' : '${f.round()} Hz';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1116),
      appBar: AppBar(backgroundColor: const Color(0xFF0F1116), title: const Text('Ecualizador')),
      body: FutureBuilder<bool>(
        future: _ready,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final pr = Eq.params;
          if (snap.data != true || pr == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Reproduce algo y vuelve a abrir el ecualizador.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              ),
            );
          }
          return ValueListenableBuilder<bool>(
            valueListenable: Eq.enabled,
            builder: (context, on, _) {
              final n = pr.bands.length;
              double g(int i) => (i < Eq.gains.length ? Eq.gains[i] : 0.0).clamp(pr.minDecibels, pr.maxDecibels).toDouble();
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                child: Column(
                  children: [
                    if (!Eq.effectActive)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'En Windows los ajustes se guardan, pero aún no modifican el sonido.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                        ),
                      ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFD9DBE0), Color(0xFFA9ACB3), Color(0xFFC8CAD0)],
                          ),
                          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))],
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Eq.setEnabled(!on),
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: on ? const Color(0xFF45E08A) : const Color(0xFF3A3D44),
                                      boxShadow: on ? const [BoxShadow(color: Color(0xAA45E08A), blurRadius: 10)] : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(on ? 'ON' : 'OFF',
                                    style: const TextStyle(color: Color(0xFF22252B), fontWeight: FontWeight.w700, fontSize: 12)),
                                const Spacer(),
                                _Meter(level: on ? (g(0).abs() + g(n - 1).abs()) / (2 * pr.maxDecibels) : 0),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: Opacity(
                                opacity: on ? 1 : .55,
                                child: IgnorePointer(
                                  ignoring: !on,
                                  child: Row(
                                    children: [
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          for (final t in ['+12', '0', '−12'])
                                            Text(t, style: const TextStyle(fontSize: 10, color: Color(0xFF3A3D44))),
                                        ],
                                      ),
                                      for (var i = 0; i < n; i++)
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: RotatedBox(
                                                  quarterTurns: 3,
                                                  child: SliderTheme(
                                                    data: SliderTheme.of(context).copyWith(
                                                      trackHeight: 5,
                                                      activeTrackColor: const Color(0xFF101116),
                                                      inactiveTrackColor: const Color(0xFF101116),
                                                      thumbColor: const Color(0xFFF2F3F5),
                                                      overlayColor: Colors.black12,
                                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11, elevation: 4),
                                                    ),
                                                    child: Slider(
                                                      min: pr.minDecibels,
                                                      max: pr.maxDecibels,
                                                      value: g(i),
                                                      onChanged: (v) {
                                                        Eq.setGain(i, v);
                                                        setState(() {});
                                                      },
                                                      onChangeEnd: (_) => Eq.commit(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: on && g(i).abs() > .3 ? const Color(0xFF45E08A) : const Color(0xFF4A4D55),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(_hz(pr.bands[i].centerFrequency),
                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF22252B), fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final p in Eq.presets.keys)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(p),
                                onPressed: () async {
                                  if (!Eq.enabled.value) await Eq.setEnabled(true);
                                  await Eq.preset(p);
                                  if (mounted) setState(() {});
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.level});
  final double level;

  @override
  Widget build(BuildContext context) {
    final lit = (level.clamp(0.0, 1.0) * 10).round();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF14161C), borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          for (var i = 0; i < 10; i++)
            Container(
              width: 6,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              color: i < lit
                  ? (i < 6 ? const Color(0xFF45E08A) : (i < 8 ? const Color(0xFFE6C34A) : const Color(0xFFE0453A)))
                  : const Color(0xFF2A2D34),
            ),
        ],
      ),
    );
  }
}
