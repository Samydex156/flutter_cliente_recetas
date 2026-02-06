import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'tabs/file_scanner_tab.dart';
import 'tabs/terminal_tab.dart';
import 'tabs/network_tab.dart';
import 'tabs/system_info_tab.dart';
import 'tabs/file_explorer_tab.dart';
import 'tabs/secure_folder_tab.dart';
import 'widgets/custom_widgets.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.cyanAccent.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 25,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTitleBar(),

            TabBar(
              controller: _tabController,
              indicatorColor: Colors.cyanAccent,
              dividerColor: Colors.transparent,
              labelColor: Colors.cyanAccent,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.speed), text: "Fast I/O"),
                Tab(icon: Icon(Icons.folder_copy), text: "Explorer"),
                Tab(icon: Icon(Icons.security), text: "Secure"), // Nuevo Tab
                Tab(icon: Icon(Icons.terminal), text: "Shell"),
                Tab(icon: Icon(Icons.wifi), text: "Network"),
                Tab(icon: Icon(Icons.memory), text: "Monitor"),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  FileScannerTab(),
                  FileExplorerTab(),
                  SecureFolderTab(), // Nueva Vista
                  TerminalTab(),
                  NetworkTab(),
                  SystemInfoTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.bolt, size: 18, color: Colors.cyanAccent),
          const SizedBox(width: 8),
          const Text(
            "Flutter Native Core",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Expanded(
            child: DragToMoveArea(child: Container(color: Colors.transparent)),
          ),
          WindowButton(
            icon: Icons.minimize,
            onPressed: () => windowManager.minimize(),
          ),
          WindowButton(
            icon: Icons.crop_square,
            onPressed: () async => await windowManager.isMaximized()
                ? windowManager.restore()
                : windowManager.maximize(),
          ),
          WindowButton(
            icon: Icons.close,
            color: Colors.red.withValues(alpha: 0.8),
            onPressed: () => windowManager.close(),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
