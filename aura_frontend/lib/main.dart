import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/core/router.dart';
import 'package:aura_frontend/services/local_storage.dart';
import 'package:aura_frontend/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local database cache (Hive)
  await LocalStorageService.init();
  
  // Start background sync listener
  SyncService().startListening();

  runApp(
    const ProviderScope(
      child: AuraApp(),
    ),
  );
}

class AuraApp extends ConsumerWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'AURA AI Academic OS',
      theme: AuraTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
