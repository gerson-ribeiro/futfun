// lib/features/competitions/views/competition_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/competition_settings_viewmodel.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_bar_actions.dart';

class CompetitionSettingsScreen extends ConsumerWidget {
  const CompetitionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionsAsync = ref.watch(competitionSettingsViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campeonatos'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: buildLeadingWidget(context, ref),
        actions: buildAppBarActions(context, ref),
      ),
      body: competitionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Erro: $err',
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(competitionSettingsViewModelProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (competitions) {
          final enabled = competitions.where((c) => c.enabled).toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppColors.primary.withOpacity(0.08),
                child: const Text(
                  'Habilite ou desabilite os campeonatos que quer ver',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: enabled.isEmpty
                    ? const Center(
                        child: Text('Nenhum campeonato disponível'),
                      )
                    : ListView.builder(
                        itemCount: enabled.length,
                        itemBuilder: (context, index) {
                          final comp = enabled[index];
                          return SwitchListTile(
                            title: Text(comp.name),
                            subtitle: Text(
                              comp.code,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            value: !comp.hidden,
                            onChanged: (_) => ref
                                .read(competitionSettingsViewModelProvider
                                    .notifier)
                                .toggleHidden(comp.code),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
