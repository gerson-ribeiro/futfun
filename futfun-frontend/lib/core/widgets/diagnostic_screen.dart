import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/app_logger.dart';
import '../storage/app_storage.dart';
import '../../features/auth/viewmodels/auth_viewmodel.dart';

class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  String? _tokenPreview;
  String? _refreshPreview;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadStorage();
  }

  Future<void> _loadStorage() async {
    final jwt = await appStorage.read(key: 'jwt_token');
    final refresh = await appStorage.read(key: 'refresh_token');
    final role = await appStorage.read(key: 'user_role');
    if (!mounted) return;
    setState(() {
      _tokenPreview = jwt == null ? 'null' : '${jwt.substring(0, jwt.length.clamp(0, 20))}…';
      _refreshPreview = refresh == null ? 'null' : '${refresh.substring(0, refresh.length.clamp(0, 20))}…';
      _role = role ?? 'null';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authViewModelProvider);
    final authStage = authAsync.valueOrNull?.stage.name ?? authAsync.toString();
    final logs = AppLogger.entries.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copiar logs',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: AppLogger.dump));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copiados para a área de transferência')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Limpar logs',
            onPressed: () {
              AppLogger.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('Auth State', authStage),
          _section('JWT Token', _tokenPreview ?? '…'),
          _section('Refresh Token', _refreshPreview ?? '…'),
          _section('Role (storage)', _role ?? '…'),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('Últimos ${logs.length} logs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Expanded(
            child: logs.isEmpty
                ? const Center(child: Text('Nenhum log ainda'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: logs.length,
                    itemBuilder: (_, i) => Text(
                      logs[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: logs[i].contains('✗') ? Colors.red[300] : null,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          ],
        ),
      );
}
