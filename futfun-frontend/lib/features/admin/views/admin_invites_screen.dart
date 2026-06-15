// lib/features/admin/views/admin_invites_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/admin_invites_viewmodel.dart';
import '../data/models/invite_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_bar_actions.dart';

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year;
  final hour = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$min';
}

class AdminInvitesScreen extends ConsumerStatefulWidget {
  const AdminInvitesScreen({super.key});

  @override
  ConsumerState<AdminInvitesScreen> createState() => _AdminInvitesScreenState();
}

class _AdminInvitesScreenState extends ConsumerState<AdminInvitesScreen> {
  final _emailController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _sending = true);
    try {
      final result = await ref.read(adminInvitesViewModelProvider.notifier).sendInvite(email);
      _emailController.clear();
      if (mounted) {
        _showInviteLinkDialog(email, result.inviteUrl, result.emailSent);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showInviteLinkDialog(String email, String inviteUrl, bool emailSent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              emailSent ? Icons.check_circle : Icons.link,
              color: emailSent ? AppColors.success : AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(emailSent ? 'Convite enviado!' : 'Link do convite'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!emailSent)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  'E-mail não pôde ser enviado automaticamente. Copie o link abaixo e envie manualmente.',
                  style: TextStyle(fontSize: 13, color: Colors.orange),
                ),
              ),
            Text('Para: $email', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      inviteUrl,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copiar link',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteUrl));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copiado!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invitesAsync = ref.watch(adminInvitesViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Convites'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: buildLeadingWidget(context, ref),
        actions: buildAppBarActions(context, ref),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email do convidado',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _sending ? null : _sendInvite,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enviar'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: invitesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erro: $err')),
              data: (invites) {
                if (invites.isEmpty) {
                  return const Center(child: Text('Nenhum convite enviado ainda'));
                }
                return ListView.builder(
                  itemCount: invites.length,
                  itemBuilder: (context, index) {
                    final invite = invites[index];
                    return _InviteTile(
                      invite: invite,
                      onCancel: invite.status == InviteStatus.pending
                          ? () => ref
                              .read(adminInvitesViewModelProvider.notifier)
                              .cancelInvite(invite.id)
                          : null,
                      onResend: invite.status != InviteStatus.used
                          ? () async {
                              try {
                                final result = await ref
                                    .read(adminInvitesViewModelProvider.notifier)
                                    .resendInvite(invite.id);
                                if (context.mounted) {
                                  _showInviteLinkDialog(invite.email, result.inviteUrl, result.emailSent);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            }
                          : null,
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

class _InviteTile extends StatelessWidget {
  final InviteModel invite;
  final VoidCallback? onCancel;
  final VoidCallback? onResend;

  const _InviteTile({required this.invite, this.onCancel, this.onResend});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;

    switch (invite.status) {
      case InviteStatus.pending:
        statusColor = Colors.orange;
        statusLabel = 'Pendente';
      case InviteStatus.used:
        statusColor = Colors.green;
        statusLabel = 'Usado';
      case InviteStatus.expired:
        statusColor = Colors.grey;
        statusLabel = 'Expirado';
    }

    return ListTile(
      leading: Icon(Icons.email_outlined, color: statusColor),
      title: Text(invite.email),
      subtitle: Text(
        'Enviado: ${_formatDate(invite.createdAt)} • Expira: ${_formatDate(invite.expiresAt)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
          ),
          if (onResend != null)
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              tooltip: 'Reenviar convite',
              onPressed: onResend,
            ),
          if (onCancel != null)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              tooltip: 'Cancelar convite',
              onPressed: onCancel,
            ),
        ],
      ),
    );
  }
}
