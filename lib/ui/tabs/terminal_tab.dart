import 'dart:io';
import 'package:flutter/material.dart';

class TerminalTab extends StatefulWidget {
  const TerminalTab({super.key});

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  final TextEditingController _cmdController = TextEditingController();
  final List<String> _output = [];
  final ScrollController _scrollController = ScrollController();

  Future<void> _runCommand(String command) async {
    if (command.isEmpty) return;

    setState(() {
      _output.add("> $command");
      _cmdController.clear();
    });

    try {
      final result = await Process.run('powershell', ['/c', command]);

      if (mounted) {
        setState(() {
          if (result.stdout.toString().isNotEmpty) {
            _output.add(result.stdout.toString().trim());
          }
          if (result.stderr.toString().isNotEmpty) {
            _output.add("Error: ${result.stderr.toString().trim()}");
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _output.add("Error de ejecución: $e"));
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "NATIVE SHELL INTERFACE",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
          const Text(
            "Ejecuta comandos de PowerShell desde Flutter:",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _output.length,
                itemBuilder: (context, index) {
                  final line = _output[index];
                  final isCommand = line.startsWith(">");
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      line,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        color: isCommand ? Colors.yellow : Colors.greenAccent,
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cmdController,
            style: const TextStyle(fontFamily: 'Consolas', color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Escribe un comando (ej: dir, ipconfig, whoami)...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.terminal, color: Colors.white54),
            ),
            onSubmitted: _runCommand,
          ),
        ],
      ),
    );
  }
}
