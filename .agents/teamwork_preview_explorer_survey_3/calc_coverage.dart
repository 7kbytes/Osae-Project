import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('lcov.info not found');
    return;
  }
  final lines = file.readAsLinesSync();
  String currentFile = '';
  int totalLF = 0;
  int totalLH = 0;
  final results = <Map<String, dynamic>>[];

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
    } else if (line.startsWith('LF:')) {
      final lf = int.parse(line.substring(3));
      results.add({'file': currentFile, 'lf': lf});
      totalLF += lf;
    } else if (line.startsWith('LH:')) {
      final lh = int.parse(line.substring(3));
      results.last['lh'] = lh;
      totalLH += lh;
    }
  }

  print('FILE BREAKDOWN:');
  print('--------------------------------------------------------------------------------');
  for (final r in results) {
    final lf = r['lf'] as int;
    final lh = r['lh'] as int;
    final pct = lf > 0 ? (lh / lf * 100).toStringAsFixed(1) : '0.0';
    print('${r['file'].toString().padRight(55)} | ${lh.toString().padLeft(4)}/${lf.toString().padLeft(4)} | $pct%');
  }
  print('--------------------------------------------------------------------------------');
  final overallPct = totalLF > 0 ? (totalLH / totalLF * 100).toStringAsFixed(2) : '0.0';
  print('TOTAL: $totalLH / $totalLF ($overallPct%)');
}
