import 'dart:io';
import 'package:flutter/material.dart';

class FileExplorerTab extends StatefulWidget {
  const FileExplorerTab({super.key});

  @override
  State<FileExplorerTab> createState() => _FileExplorerTabState();
}

class _FileExplorerTabState extends State<FileExplorerTab> {
  // Empezamos en la carpeta de usuario o C:\
  Directory _currentDir = Directory(
    Platform.environment['USERPROFILE'] ?? 'C:\\',
  );
  List<FileSystemEntity> _files = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadFiles(_currentDir);
  }

  Future<void> _loadFiles(Directory dir) async {
    setState(() => _loading = true);

    try {
      final List<FileSystemEntity> entities = dir.listSync();

      entities.sort((a, b) {
        // Ordenar: Carpetas primero, luego archivos
        bool isADir = a is Directory;
        bool isBDir = b is Directory;
        if (isADir && !isBDir) return -1;
        if (!isADir && isBDir) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      if (!mounted) return;

      setState(() {
        _currentDir = dir;
        _files = entities;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Acceso Denegado: ${e.toString().split(':')[0]}"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _loading = false);
    }
  }

  void _navigateUp() {
    final parent = _currentDir.parent;
    if (parent.path != _currentDir.path) {
      _loadFiles(parent);
    }
  }

  Future<void> _openEntity(FileSystemEntity entity) async {
    if (entity is Directory) {
      _loadFiles(entity);
    } else {
      // Abrir archivo con explorer
      try {
        await Process.run('explorer', [entity.path]);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo abrir el archivo")),
        );
      }
    }
  }

  String _getFileSize(FileSystemEntity entity) {
    if (entity is Directory) return "<DIR>";
    if (entity is File) {
      try {
        final bytes = entity.lengthSync();
        if (bytes < 1024) return "$bytes B";
        if (bytes < 1024 * 1024)
          return "${(bytes / 1024).toStringAsFixed(1)} KB";
        return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
      } catch (e) {
        return "?";
      }
    }
    return "";
  }

  // Iconos por extensión
  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image;
      case 'mp4':
      case 'mkv':
        return Icons.movie;
      case 'mp3':
        return Icons.music_note;
      case 'zip':
      case 'rar':
        return Icons.archive;
      case 'exe':
      case 'msi':
        return Icons.settings_applications;
      case 'txt':
      case 'md':
      case 'dart':
      case 'json':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _showInfoDialog(FileSystemEntity entity) async {
    try {
      FileStat stat = await entity.stat();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(entity.path.split(Platform.pathSeparator).last),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Type: ${entity is Directory ? 'Directory' : 'File'}"),
              Text("Size: ${_getFileSize(entity)}"),
              const Divider(),
              Text("Created: ${stat.changed}"),
              Text("Modified: ${stat.modified}"),
              Text("Accessed: ${stat.accessed}"),
              Text("Mode: ${stat.mode}"), // Mode raw int
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      // Error reading stats
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. BARRA DE NAVEGACIÓN
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.black26,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.cyanAccent),
                onPressed: _navigateUp,
                tooltip: "Subir nivel",
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentDir.path,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadFiles(_currentDir),
              ),
            ],
          ),
        ),

        // 2. LISTA DE ARCHIVOS
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                )
              : _files.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final entity = _files[index];
                    final isDir = entity is Directory;
                    final name = entity.path.split(Platform.pathSeparator).last;

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isDir ? Icons.folder : _getFileIcon(name),
                        color: isDir ? Colors.amber : Colors.white70,
                        size: 28,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: isDir ? Colors.white : Colors.white70,
                        ),
                      ),
                      subtitle: Text(
                        _getFileSize(entity),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white24,
                          fontFamily: 'Consolas',
                        ),
                      ),
                      onTap: () => _openEntity(entity),
                      // onDoubleTap: () => _openEntity(entity),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 18,
                          color: Colors.white30,
                        ),
                        onSelected: (value) {
                          if (value == 'open') _openEntity(entity);
                          if (value == 'info') _showInfoDialog(entity);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'open',
                            child: Text('Open'),
                          ),
                          const PopupMenuItem(
                            value: 'info',
                            child: Text('Properties'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // 3. BARRA DE ESTADO
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.black45,
          child: Row(
            children: [
              Text(
                "${_files.length} items",
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const Spacer(),
              const Text(
                "Double-click to open",
                style: TextStyle(fontSize: 12, color: Colors.white24),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 60, color: Colors.white10),
          SizedBox(height: 10),
          Text("Carpeta vacía", style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }
}
