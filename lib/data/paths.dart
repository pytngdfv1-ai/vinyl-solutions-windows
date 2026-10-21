import 'package:path/path.dart' as p;

/// Rutas independientes del sistema (Windows usa '\').
class Paths {
  static String base(String path) => p.basename(path);

  /// Nombres de carpetas de [dir] relativos a [root] (sin vacíos).
  static List<String> relNames(String root, String dir) {
    if (p.equals(root, dir)) return const [];
    return p.split(p.relative(dir, from: root)).where((s) => s.isNotEmpty && s != '.').toList();
  }

  /// ¿[child] es hija directa de [dir]?
  static bool isDirectChild(String dir, String child) => p.equals(p.dirname(child), dir);

  static bool within(String dir, String child) => p.isWithin(dir, child);
}
