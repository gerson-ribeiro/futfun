// lib/features/competitions/views/admin_competitions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/admin_competitions_viewmodel.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_bar_actions.dart';

class AdminCompetitionsScreen extends ConsumerStatefulWidget {
  const AdminCompetitionsScreen({super.key});

  @override
  ConsumerState<AdminCompetitionsScreen> createState() =>
      _AdminCompetitionsScreenState();
}

class _AdminCompetitionsScreenState
    extends ConsumerState<AdminCompetitionsScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _adding = false;
  bool _syncing = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerSync() async {
    setState(() => _syncing = true);
    try {
      await DioClient().dio.post('/api/admin/sync');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sincronização iniciada — aguarde alguns segundos e atualize os jogos')),
        );
        // Refresh competition list to pick up newly discovered competitions.
        ref.invalidate(adminCompetitionsViewModelProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao sincronizar: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _addCompetition() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty || name.isEmpty) return;

    setState(() => _adding = true);
    try {
      await ref
          .read(adminCompetitionsViewModelProvider.notifier)
          .addCompetition(code, name);
      _codeCtrl.clear();
      _nameCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campeonato "$name" adicionado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final competitionsAsync = ref.watch(adminCompetitionsViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campeonatos'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: buildLeadingWidget(context, ref),
        actions: [
          TextButton.icon(
            onPressed: _syncing ? null : _triggerSync,
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync, color: Colors.white),
            label: const Text('Sincronizar', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
          ...buildAppBarActions(context, ref),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _adding ? null : _addCompetition,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                  ),
                  child: _adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Adicionar'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: competitionsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Erro: $err',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              data: (competitions) {
                if (competitions.isEmpty) {
                  return const Center(
                    child: Text('Nenhum campeonato cadastrado'),
                  );
                }
                return ListView.builder(
                  itemCount: competitions.length,
                  itemBuilder: (context, index) {
                    final comp = competitions[index];
                    return SwitchListTile(
                      secondary: Icon(
                        comp.enabled
                            ? Icons.check_circle
                            : Icons.cancel_outlined,
                        color: comp.enabled
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      title: Text(comp.name),
                      subtitle: Text(
                        comp.code,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: comp.enabled,
                      onChanged: (_) => ref
                          .read(adminCompetitionsViewModelProvider.notifier)
                          .toggleGlobal(comp.code),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
