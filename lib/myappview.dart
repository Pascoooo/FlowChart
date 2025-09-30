import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'blocs/auth_bloc/authentication_bloc.dart';
import 'config/constants/theme_switch.dart';
import 'config/router/app_router.dart';

class MyAppView extends StatefulWidget {
  const MyAppView({super.key});

  @override
  State<MyAppView> createState() => _MyAppViewState();
}

class _MyAppViewState extends State<MyAppView> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authBloc = context.read<AuthenticationBloc>();
    _router = AppRouter.getRouter(authBloc);
  }

  @override
  Widget build(BuildContext context) {
    return FluentApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).themeData,
      title: 'Flowchart Thesis',
      color: Colors.blue,
    );
  }
}
