import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/colors.dart';

class DoodleScreen extends StatefulWidget {
  final String chatId;

  const DoodleScreen({super.key, required this.chatId});

  @override
  State<DoodleScreen> createState() => _DoodleScreenState();
}

class _DoodleScreenState extends State<DoodleScreen> {
  Color _selectedColor = WAColors.primary;
  double _strokeWidth = 4.0;
  
  // Local list of active points while drawing
  List<Offset> _activePoints = [];

  final List<Color> _colors = [
    WAColors.primary,
    WAColors.accent,
    Colors.purpleAccent,
    Colors.tealAccent.shade700,
    Colors.amber,
    Colors.black,
    Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        title: const Text(
          "Shared Doodle Board 🎨",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, size: 22),
            tooltip: "Clear Board",
            onPressed: _clearBoard,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Canvas Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

                return GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      // Add normalized point (0.0 to 1.0)
                      _activePoints = [
                        Offset(
                          details.localPosition.dx / canvasSize.width,
                          details.localPosition.dy / canvasSize.height,
                        )
                      ];
                    });
                    HapticFeedback.lightImpact();
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _activePoints.add(
                        Offset(
                          details.localPosition.dx / canvasSize.width,
                          details.localPosition.dy / canvasSize.height,
                        ),
                      );
                    });
                  },
                  onPanEnd: (details) async {
                    if (_activePoints.isNotEmpty) {
                      final stroke = Stroke(
                        points: List.from(_activePoints),
                        color: _selectedColor,
                        strokeWidth: _strokeWidth,
                      );
                      
                      // Save finished stroke to Firestore
                      await FirebaseFirestore.instance
                          .collection("chats")
                          .doc(widget.chatId)
                          .collection("doodles")
                          .add(stroke.toMap());

                      setState(() {
                        _activePoints = [];
                      });
                    }
                  },
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("chats")
                        .doc(widget.chatId)
                        .collection("doodles")
                        .orderBy("timestamp")
                        .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      List<Stroke> strokes = docs.map((doc) {
                        return Stroke.fromMap(doc.data() as Map<String, dynamic>);
                      }).toList();

                      // If drawing locally, show the active stroke in real-time
                      if (_activePoints.isNotEmpty) {
                        strokes.add(Stroke(
                          points: _activePoints,
                          color: _selectedColor,
                          strokeWidth: _strokeWidth,
                        ));
                      }

                      return Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.transparent,
                        child: CustomPaint(
                          painter: DoodlePainter(strokes: strokes),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Bottom Paint Controls Dashboard
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Color Selection List
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colors.length,
                      itemBuilder: (context, index) {
                        final color = _colors[index];
                        final isSelected = color == _selectedColor;
                        
                        // Handle White visibility in light mode and Black in dark mode
                        Color displayBorder = Colors.transparent;
                        if (color == Colors.white && !isDark) {
                          displayBorder = Colors.grey.shade300;
                        }
                        if (color == Colors.black && isDark) {
                          displayBorder = Colors.grey.shade700;
                        }

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected 
                                    ? WAColors.primary 
                                    : displayBorder,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Stroke Width Selector Slider
                  Row(
                    children: [
                      Icon(Icons.brush_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                            activeTrackColor: WAColors.primary,
                            inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
                            thumbColor: WAColors.primary,
                          ),
                          child: Slider(
                            min: 2.0,
                            max: 12.0,
                            value: _strokeWidth,
                            onChanged: (val) {
                              setState(() {
                                _strokeWidth = val;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${_strokeWidth.toInt()}px",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      )
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _clearBoard() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("chats")
          .doc(widget.chatId)
          .collection("doodles")
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Canvas cleared!")),
        );
      }
    } catch (e) {
      print("Clear failed: $e");
    }
  }
}

class Stroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  Stroke({required this.points, required this.color, required this.strokeWidth});

  Map<String, dynamic> toMap() {
    return {
      "points": points.map((p) => {"x": p.dx, "y": p.dy}).toList(),
      "color": color.value,
      "strokeWidth": strokeWidth,
      "timestamp": FieldValue.serverTimestamp(),
    };
  }

  factory Stroke.fromMap(Map<String, dynamic> map) {
    final pointsList = map["points"] as List<dynamic>? ?? [];
    final offsets = pointsList
        .map((p) => Offset((p["x"] as num).toDouble(), (p["y"] as num).toDouble()))
        .toList();
    return Stroke(
      points: offsets,
      color: Color(map["color"] as int),
      strokeWidth: (map["strokeWidth"] as num).toDouble(),
    );
  }
}

class DoodlePainter extends CustomPainter {
  final List<Stroke> strokes;

  DoodlePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke;

      if (stroke.points.isEmpty) continue;

      final path = Path();
      // Un-normalize points back to current device constraints
      final firstPoint = stroke.points[0];
      path.moveTo(firstPoint.dx * size.width, firstPoint.dy * size.height);

      for (int i = 1; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DoodlePainter oldDelegate) => true;
}
