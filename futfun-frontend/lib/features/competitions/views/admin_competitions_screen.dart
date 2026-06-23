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
  String? _rescoring;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmRescoreRanking(String code, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recalcular ranking'),
        content: Text(
          'Isso vai zerar e recalcular do zero os pontos de "$name".\n\n'
          'Os palpites são desmarcados e repontuados com base nos placares '
          'já registrados no banco. Use quando o ranking estiver inconsistente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Recalcular'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _rescoring = code);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminCompetitionsViewModelProvider.notifier)
          .rescoreRanking(code);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Ranking de "$name" sendo recalculado — aguarde alguns segundos')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao recalcular: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _rescoring = null);
    }
  }

  Future<void> _confirmResetRanking(String code, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar ranking'),
        content: Text(
          'Isso vai zerar todos os pontos e histórico de "$name".\n\n'
          'Os palpites e placares já registrados não são apagados — '
          'só o ranking acumulado é reiniciado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminCompetitionsViewModelProvider.notifier)
          .resetRanking(code);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Ranking de "$name" reiniciado')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao reiniciar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
                    return ListTile(
                      leading: Icon(
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
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_rescoring == comp.code)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.calculate_outlined),
                              tooltip: 'Recalcular ranking',
                              color: AppColors.primary,
                              onPressed: () => _confirmRescoreRanking(comp.code, comp.name),
                            ),
                          IconButton(
                            icon: const Icon(Icons.restart_alt),
                            tooltip: 'Reiniciar ranking (só apaga)',
                            color: AppColors.textSecondary,
                            onPressed: () => _confirmResetRanking(comp.code, comp.name),
                          ),
                          Switch(
                            value: comp.enabled,
                            onChanged: (_) => ref
                                .read(adminCompetitionsViewModelProvider.notifier)
                                .toggleGlobal(comp.code),
                          ),
                        ],
                      ),
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
