import 'dart:io';
import 'package:flutter/material.dart';

class NetworkTab extends StatefulWidget {
  const NetworkTab({super.key});

  @override
  State<NetworkTab> createState() => _NetworkTabState();
}

class _DiscoveryResult {
  final String ip;
  String name;
  String mac;
  String vendor;
  bool isWebOpen;

  _DiscoveryResult(
    this.ip, {
    this.name = "Unknown",
    this.mac = "--",
    this.vendor = "",
    this.isWebOpen = false,
  });
}

class _NetworkTabState extends State<NetworkTab> {
  String _myIp = "Detectando...";
  String _subnet = "...";
  bool _scanning = false;
  final List<_DiscoveryResult> _devices = [];
  double _progress = 0.0;
  String _statusMsg = "";

  @override
  void initState() {
    super.initState();
    _getMyIp();
  }

  Future<void> _getMyIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      if (interfaces.isNotEmpty) {
        final address = interfaces.first.addresses.first;
        if (mounted) {
          setState(() {
            _myIp = address.address;
            final parts = _myIp.split('.');
            parts.removeLast();
            _subnet = "${parts.join('.')}.";
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _myIp = "Error: $e");
    }
  }

  Future<void> _scanNetwork() async {
    if (_subnet == "..." || _scanning) return;

    setState(() {
      _scanning = true;
      _devices.clear();
      _progress = 0;
      _statusMsg = "Iniciando Ping Sweep...";
    });

    final int totalHosts = 254;
    int processed = 0;
    List<String> activeIps = [];

    // Ping Sweep
    for (int i = 1; i <= totalHosts; i += 25) {
      final List<Future<String?>> batch = [];
      for (int j = i; j < i + 25 && j <= totalHosts; j++) {
        final ip = "$_subnet$j";
        if (ip == _myIp) continue;
        batch.add(_checkPing(ip));
      }

      final results = await Future.wait(batch);
      activeIps.addAll(results.whereType<String>());

      if (!mounted) return;
      setState(() {
        processed += batch.length;
        _progress = processed / totalHosts * 0.8;
      });
    }

    setState(() => _statusMsg = "Resolviendo Nombres y MACs...");

    Map<String, String> arpTable = await _getArpTable();

    for (var ip in activeIps) {
      if (!mounted) return;

      String hostname = "";
      try {
        final host = await InternetAddress(ip).reverse();
        hostname = host.host;
      } catch (e) {
        hostname = "Generic Device";
      }

      bool hasWeb = false;
      try {
        final socket = await Socket.connect(
          ip,
          80,
          timeout: const Duration(milliseconds: 200),
        );
        hasWeb = true;
        socket.destroy();
      } catch (e) {
        // Puerto cerrado
      }

      setState(() {
        _devices.add(
          _DiscoveryResult(
            ip,
            name: hostname,
            mac: arpTable[ip] ?? "Desconocido (Bloqueado)",
            isWebOpen: hasWeb,
            vendor: hasWeb ? "Web Device" : "",
          ),
        );
      });
    }

    if (mounted) {
      setState(() {
        _scanning = false;
        _progress = 1.0;
        _statusMsg =
            "Escaneo completado. ${_devices.length} dispositivos encontrados.";
      });
    }
  }

  Future<String?> _checkPing(String ip) async {
    try {
      final result = await Process.run('ping', ['-n', '1', '-w', '200', ip]);
      if (result.stdout.toString().contains("TTL=")) {
        return ip;
      }
    } catch (e) {
      /* */
    }
    return null;
  }

  Future<Map<String, String>> _getArpTable() async {
    Map<String, String> table = {};
    try {
      final result = await Process.run('arp', ['-a']);
      final lines = result.stdout.toString().split('\n');
      for (var line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          final ip = parts[0];
          final mac = parts[1];
          if (ip.startsWith("192") ||
              ip.startsWith("10") ||
              ip.startsWith("172")) {
            table[ip] = mac.toUpperCase();
          }
        }
      }
    } catch (e) {
      /* */
    }
    return table;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "NETWORK DISCOVERY PRO",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                ),
              ),
              if (_scanning)
                Text(
                  _statusMsg,
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
            ],
          ),
          const SizedBox(height: 10),

          _buildMyIpCard(),

          const SizedBox(height: 10),
          if (_scanning) ...[
            LinearProgressIndicator(
              value: _progress,
              color: Colors.orangeAccent,
              backgroundColor: Colors.white10,
            ),
            const SizedBox(height: 10),
          ],

          Expanded(
            child: _devices.isEmpty && !_scanning
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_find, size: 60, color: Colors.white10),
                        SizedBox(height: 10),
                        Text(
                          "Listo para escanear red local",
                          style: TextStyle(color: Colors.white24),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final dev = _devices[index];
                      return Card(
                        color: Colors.white.withValues(alpha: 0.05),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: dev.isWebOpen
                                ? Colors.blueAccent.withValues(alpha: 0.2)
                                : Colors.white10,
                            child: Icon(
                              dev.isWebOpen ? Icons.language : Icons.computer,
                              color: dev.isWebOpen
                                  ? Colors.blueAccent
                                  : Colors.grey,
                            ),
                          ),
                          title: Text(
                            dev.ip,
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dev.name,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "MAC: ${dev.mac}",
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 11,
                                  fontFamily: 'Consolas',
                                ),
                              ),
                            ],
                          ),
                          trailing: dev.isWebOpen
                              ? Tooltip(
                                  message: "Servidor Web Detectado",
                                  child: Chip(
                                    label: const Text(
                                      "HTTP",
                                      style: TextStyle(fontSize: 10),
                                    ),
                                    backgroundColor: Colors.blue.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyIpCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub, size: 30, color: Colors.orangeAccent),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "HOST: $_myIp",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Consolas',
                ),
              ),
              Text(
                "Subnet: ${_subnet}0/24",
                style: const TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _scanning ? null : _scanNetwork,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
            ),
            icon: _scanning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.radar, size: 18),
            label: Text(_scanning ? "Escaneando..." : "Start Scan"),
          ),
        ],
      ),
    );
  }
}
