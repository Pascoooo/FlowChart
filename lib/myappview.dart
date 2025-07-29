import 'package:flowchart_thesis/config/router/app_router.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyAppView extends StatelessWidget {
  const MyAppView({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
      title: 'Flowchart Thesis',
      theme: context.watch<ThemeProvider>().themeData,
    );
  }
}