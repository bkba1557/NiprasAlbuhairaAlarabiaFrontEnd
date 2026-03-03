// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/app_navigation.dart';

class FrontPage extends StatefulWidget {
  final VoidCallback onEmployeeLogin;

  const FrontPage({super.key, required this.onEmployeeLogin});

  @override
  State<FrontPage> createState() => _FrontPageState();
}

class _FrontPageState extends State<FrontPage> {
  static bool _viewFactoryRegistered = false;

  html.EventListener? _messageListener;

  /// 🛑 منع تنفيذ تسجيل الدخول أكثر من مرة
  bool _loginTriggered = false;

  @override
  void initState() {
    super.initState();
    _registerViewFactory();
    _listenToMessages();
  }

  @override
  void dispose() {
    if (_messageListener != null) {
      html.window.removeEventListener('message', _messageListener!);
    }
    super.dispose();
  }

  // ===============================
  // 🖼️ Register HTML View
  // ===============================
  void _registerViewFactory() {
    if (_viewFactoryRegistered) return;

    ui.platformViewRegistry.registerViewFactory('nibras-html', (int viewId) {
      return html.IFrameElement()
        ..src = 'assets/assets/nibras_page.html'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block';
    });

    _viewFactoryRegistered = true;
  }

  // ===============================
  // 📩 Listen to postMessage
  // ===============================
  void _listenToMessages() {
    _messageListener = (event) {
      if (event is! html.MessageEvent) return;
      if (event.data != 'employee_login') return;
      final rawFragment = Uri.base.fragment;
      final currentPath = rawFragment.isNotEmpty
          ? (rawFragment.startsWith('/') ? rawFragment : '/$rawFragment')
          : Uri.base.path;
      if (currentPath != AppRoutes.front && currentPath != '/') {
        debugPrint('employee_login ignored (current route: $currentPath)');
        return;
      }

      if (_loginTriggered) {
        debugPrint('⚠️ employee_login ignored (already triggered)');
        return;
      }

      _loginTriggered = true;

      debugPrint('🚀 employee_login received → navigate immediately');

      // ✅ تنقل فوري بدون context وبدون frame انتظار
      appNavigatorKey.currentState?.pushReplacementNamed('/login');
    };

    html.window.addEventListener('message', _messageListener!);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: HtmlElementView(viewType: 'nibras-html'));
  }
}
