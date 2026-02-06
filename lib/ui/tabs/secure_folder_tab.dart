import 'dart:io';
import 'package:flutter/material.dart';

class SecureFolderTab extends StatefulWidget {
  const SecureFolderTab({super.key});

  @override
  State<SecureFolderTab> createState() => _SecureFolderTabState();
}

class _SecureFolderTabState extends State<SecureFolderTab> {
  final TextEditingController _pathController = TextEditingController();
  bool _isLocked = false;
  bool _isLoading = false;
  String _statusMessage = "";

  // Verifica si la carpeta tiene atributos de sistema/oculto
  Future<void> _checkFolderStatus() async {
    final path = _pathController.text;
    if (path.isEmpty) return;

    final dir = Directory(path);
    if (!await dir.exists()) {
      setState(() => _statusMessage = "La carpeta no existe.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Usamos 'attrib' para ver los atributos actuales
      final result = await Process.run('attrib', [path]);
      final output = result.stdout
          .toString(); // Ej: "SHR  C:\Users\User\Folder"

      // Si tiene S (System) y H (Hidden), asumimos que está protegida por nosotros
      bool isHidden = output.contains("H");
      bool isSystem = output.contains("S");

      setState(() {
        _isLocked = isHidden && isSystem;
        _statusMessage = _isLocked
            ? "Carpeta protegida y oculta."
            : "Carpeta visible y accesible.";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error al verificar: $e";
      });
    }
  }

  Future<void> _toggleProtection() async {
    final path = _pathController.text;
    if (path.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = _isLocked
          ? "Desbloqueando y restaurando permisos..."
          : "Aplicando BLINDAJE TOTAL (SID Universal)...";
    });

    try {
      if (_isLocked) {
        // DESBLOQUEAR (UNLOCK)

        // 1. Restaurar permisos usando SID Universal (*S-1-1-0)
        // Eliminamos explícitamente la regla de denegación
        final resultAcl = await Process.run('icacls', [
          path,
          '/remove:d',
          '*S-1-1-0',
        ]);
        if (resultAcl.exitCode != 0) throw "Error ACL: ${resultAcl.stderr}";

        // 2. Quitar atributos de sistema y oculto
        final resultAttrib = await Process.run('attrib', [
          '-s',
          '-h',
          '-r',
          path,
        ]);
        if (resultAttrib.exitCode != 0)
          throw "Error Attrib: ${resultAttrib.stderr}";

        setState(() {
          _isLocked = false;
          _statusMessage = "Carpeta accesible nuevamente.";
        });
      } else {
        // BLOQUEAR (LOCK)

        // 1. Aplicar atributos (+s sistema, +h oculto, +r solo lectura)
        final resultAttrib = await Process.run('attrib', [
          '+s',
          '+h',
          '+r',
          path,
        ]);
        if (resultAttrib.exitCode != 0)
          throw "Error Attrib: ${resultAttrib.stderr}";

        // 2. BLINDAJE DE PERMISOS (SID *S-1-1-0 = Todos/Everyone)
        // /deny *S-1-1-0:(OI)(CI)F
        // (OI)(CI) = Herencia a todos los archivos y subcarpetas dentro
        // F = FULL CONTROL (Denegar TODO: Lectura, Escritura, Borrado)
        final resultAcl = await Process.run('icacls', [
          path,
          '/deny',
          '*S-1-1-0:(OI)(CI)F',
        ]);

        if (resultAcl.exitCode != 0) {
          // Si falla el bloqueo, intentamos revertir el atributo de oculto para no dejarlo a medias
          await Process.run('attrib', ['-s', '-h', '-r', path]);
          throw "Error ACL (¿Faltan permisos de Admin?): ${resultAcl.stderr}";
        }

        setState(() {
          _isLocked = true;
          _statusMessage = "BLOQUEO EXITOSO. Acceso denegado a nivel NTFS.";
        });
      }
    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, size: 28, color: Colors.redAccent),
              const SizedBox(width: 10),
              const Text(
                "SECURE FOLDER VAULT",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const Text(
            "Oculta capetas a nivel de sistema y bloquea permisos de escritura/borrado.",
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 40),

          // Input de Ruta
          TextField(
            controller: _pathController,
            style: const TextStyle(fontFamily: 'Consolas', color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Ruta de la Carpeta a Proteger',
              hintText: r'Ej: C:\Users\TuUsuario\Desktop\Secreto',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.folder_shared),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _checkFolderStatus,
                tooltip: "Verificar Estado",
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Estado Visual
          Center(
            child: Column(
              children: [
                Icon(
                  _isLocked ? Icons.lock : Icons.lock_open,
                  size: 80,
                  color: _isLocked ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 10),
                Text(
                  _isLocked ? "LOCKED (Protegido)" : "UNLOCKED (Vulnerable)",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isLocked ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Botón de Acción
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _toggleProtection,
              style: FilledButton.styleFrom(
                backgroundColor: _isLocked ? Colors.green : Colors.redAccent,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(_isLocked ? Icons.lock_open : Icons.lock),
              label: Text(
                _isLocked
                    ? "DESBLOQUEAR Y MOSTRAR"
                    : "BLOQUEAR, OCULTAR Y PROTEGER",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
