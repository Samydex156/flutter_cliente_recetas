import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/custom_widgets.dart';

class SystemInfoTab extends StatefulWidget {
  const SystemInfoTab({super.key});

  @override
  State<SystemInfoTab> createState() => _SystemInfoTabState();
}

class _SystemInfoTabState extends State<SystemInfoTab> {
  Timer? _timer;
  Map<String, dynamic>? _metrics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMetrics(); // Primer fetch inmediato
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _fetchMetrics(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMetrics() async {
    if (!mounted) return;

    const psScript = r'''
    $o = Get-CimInstance Win32_OperatingSystem
    $c = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
    $d = Get-CimInstance Win32_LogicalDisk | Where-Object DriveType -eq 3 | Select-Object DeviceID, FreeSpace, Size, VolumeName
    
    $data = @{
        cpu = $c.Average
        ram_free = $o.FreePhysicalMemory
        ram_total = $o.TotalVisibleMemorySize
        boot = $o.LastBootUpTime
        disks = $d
    }
    $data | ConvertTo-Json -Compress
    ''';

    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        psScript,
      ]);
      if (result.stdout.toString().isNotEmpty) {
        final data = jsonDecode(result.stdout.toString());
        if (mounted) {
          setState(() {
            _metrics = data;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Helpers de conversión
  // modificacion de prueba
  String _formatBytes(dynamic value) {
    if (value == null) return "0 GB";
    final num bytes = (value is int)
        ? value
        : int.tryParse(value.toString()) ?? 0;

    final gb = bytes / (1024 * 1024 * 1024);
    return "${gb.toStringAsFixed(1)} GB";
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    final cpuLoad = _metrics?['cpu'] ?? 0;

    final ramTotalKB = _metrics?['ram_total'] ?? 1;
    final ramFreeKB = _metrics?['ram_free'] ?? 0;
    final ramUsedKB = ramTotalKB - ramFreeKB;
    final ramPercent = ramUsedKB / ramTotalKB;

    // Boot Time Parsing
    String uptimeStr = "Active";
    if (_metrics?['boot'] != null) {
      final String rawBoot = _metrics!['boot'].toString();
      final match = RegExp(r'(\d+)').firstMatch(rawBoot);
      if (match != null) {
        final millis = int.parse(match.group(1)!);
        final bootTime = DateTime.fromMillisecondsSinceEpoch(millis);
        final uptime = DateTime.now().difference(bootTime);
        uptimeStr = "${uptime.inHours}h ${uptime.inMinutes % 60}m";
      }
    }

    // Disks
    List disks = [];
    if (_metrics?['disks'] is List) {
      disks = _metrics!['disks'];
    } else if (_metrics?['disks'] is Map) {
      disks = [_metrics!['disks']];
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "REAL-TIME MONITOR",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.purpleAccent,
          ),
        ),
        const SizedBox(height: 20),

        // ROW 1: CPU & RAM GAUGES
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCircularGauge(
              "CPU Load",
              cpuLoad / 100,
              "${cpuLoad.toStringAsFixed(1)}%",
              Colors.cyanAccent,
            ),
            _buildCircularGauge(
              "RAM Usage",
              ramPercent,
              "${(ramPercent * 100).toStringAsFixed(1)}%",
              Colors.purpleAccent,
            ),
          ],
        ),

        const SizedBox(height: 20),
        StatCardSimple(Icons.timer, "System Uptime", uptimeStr),
        StatCardSimple(
          Icons.memory,
          "Available RAM",
          "${(ramFreeKB / 1024 / 1024).toStringAsFixed(2)} GB / ${(ramTotalKB / 1024 / 1024).toStringAsFixed(2)} GB",
        ),

        const SizedBox(height: 30),
        const Text(
          "STORAGE DRIVES",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const Divider(color: Colors.white24),

        ...disks.map((d) {
          final size = d['Size'] ?? 1;
          final free = d['FreeSpace'] ?? 0;
          final used = size - free;
          final percent = used / size;

          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.storage,
                          color: Colors.white54,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${d['DeviceID']}  ${d['VolumeName'] ?? ''}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      "${(free / 1024 / 1024 / 1024).toStringAsFixed(1)} GB Free",
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(
                      percent > 0.9 ? Colors.redAccent : Colors.blueAccent,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildCircularGauge(
    String label,
    double value,
    String textValue,
    Color color,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Center(
                child: Text(
                  textValue,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
