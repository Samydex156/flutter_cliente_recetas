import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'ui/main_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(900, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Flutter Native Power',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setHasShadow(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const NativeApp());
}

class NativeApp extends StatelessWidget {
  const NativeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.cyanAccent,
        // Usar fuentes de sistema si estamos en Windows
        fontFamily: Platform.isWindows ? 'Segoe UI' : null,
      ),
      home: const MainWindow(),
    );
  }
}
