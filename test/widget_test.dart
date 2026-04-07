import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:order_tracker/main.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/language_provider.dart';
import 'package:order_tracker/providers/theme_provider.dart';

void main() {
  testWidgets('MyApp renders loading while auth initializes', (tester) async {
    final authProvider = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => authProvider),
          ChangeNotifierProxyProvider<AuthProvider, LanguageProvider>(
            create: (_) => LanguageProvider(),
            update: (_, auth, languageProvider) {
              languageProvider ??= LanguageProvider();
              languageProvider.updateDefaultForRole(auth.user?.role);
              return languageProvider;
            },
          ),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
