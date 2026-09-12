import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/nova_theme.dart';
import 'providers/nova_provider.dart';
import 'ui/screens/home_screen.dart';

class NovaApp extends StatelessWidget {
  const NovaApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NovaProvider(prefs: prefs),
      child: MaterialApp(
        title: 'Nova',
        debugShowCheckedModeBanner: false,
        theme: NovaTheme.nova(),
        home: const HomeScreen(),
      ),
    );
  }
}
