import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/custom_widgets.dart'; // Importamos los widgets comunes

class FileScannerTab extends StatefulWidget {
  const FileScannerTab({super.key});

  @override
  State<FileScannerTab> createState() => _FileScannerTabState();
}

class _FileScannerTabState extends State<FileScannerTab> {
  int _filesCount = 0;
  int _totalSize = 0;
  bool _scanning = false;
  String _currentFile = "";
  final List<String> _log = [];

  // Directorios comunes para probar
  final Map<String, String> _commonPaths = {
    'Documentos': Platform.environment['USERPROFILE']! + '\\Documents',
    'Descargas': Platform.environment['USERPROFILE']! + '\\Downloads',
    'Windows': 'C:\\Windows',
    'Archivos de Programa': 'C:\\Program Files',
  };

  Future<void> _startScan(String path) async {
    setState(() {
      _scanning = true;
      _filesCount = 0;
      _totalSize = 0;
      _log.clear();
    });

    final dir = Directory(path);
    if (!await dir.exists()) {
      setState(() => _log.add("Error: Directorio no existe ($path)"));
      _scanning = false;
      return;
    }

    Stopwatch stopwatch = Stopwatch()..start();

    // Usamos un Stream para procesar archivos de forma asíncrona pero masiva
    try {
      dir
          .list(recursive: true, followLinks: false)
          .listen(
            (FileSystemEntity entity) {
              if (entity is File) {
                _filesCount++;
                try {
                  _totalSize += entity.lengthSync();
                } catch (e) {
                  // Archivos bloqueados por el sistema, ignorar
                }

                // Actualizar UI solo cada 50 archivos para no ahogar el thread UI
                if (_filesCount % 50 == 0) {
                  setState(() {
                    _currentFile = entity.path
                        .split(Platform.pathSeparator)
                        .last;
                  });
                }
              }
            },
            onError: (e) {
              // Permisos denegados, etc.
            },
            onDone: () {
              stopwatch.stop();
              if (mounted) {
                setState(() {
                  _scanning = false;
                  _currentFile =
                      "Escaneo completado en ${stopwatch.elapsed.inMilliseconds}ms";
                });
              }
            },
          );
    } catch (e) {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "PRUEBA DE I/O",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent,
            ),
          ),
          const Text(
            "Dart accede al disco directamente. Selecciona una carpeta:",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            children: _commonPaths.entries.map((entry) {
              return ActionChip(
                label: Text(entry.key),
                avatar: const Icon(Icons.folder_open, size: 16),
                onPressed: _scanning ? null : () => _startScan(entry.value),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatCard("Archivos", "$_filesCount", Icons.description),
              StatCard(
                "Tamaño Total",
                "${(_totalSize / 1024 / 1024).toStringAsFixed(1)} MB",
                Icons.storage,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_scanning) const LinearProgressIndicator(),
          const SizedBox(height: 10),
          Text(
            _currentFile,
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 12,
              color: Colors.white70,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
