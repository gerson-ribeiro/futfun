import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/prediction_entry.dart';
import 'countdown_timer.dart';

class PredictionInput extends StatefulWidget {
  final String matchId;
  final DateTime kickoffTime;
  final PredictionEntry? existing;
  final bool isSubmitting;
  final void Function(int home, int away) onSubmit;

  const PredictionInput({
    super.key,
    required this.matchId,
    required this.kickoffTime,
    required this.onSubmit,
    this.existing,
    this.isSubmitting = false,
  });

  @override
  State<PredictionInput> createState() => _PredictionInputState();
}

class _PredictionInputState extends State<PredictionInput> {
  late final TextEditingController _homeCtrl;
  late final TextEditingController _awayCtrl;

  bool get _isLocked => DateTime.now().isAfter(widget.kickoffTime);

  @override
  void initState() {
    super.initState();
    _homeCtrl = TextEditingController(
      text: widget.existing?.predictedHome.toString() ?? '',
    );
    _awayCtrl = TextEditingController(
      text: widget.existing?.predictedAway.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final home = _homeCtrl.text.isEmpty ? 0 : int.tryParse(_homeCtrl.text);
    final away = _awayCtrl.text.isEmpty ? 0 : int.tryParse(_awayCtrl.text);
    if (home == null || away == null) return;
    widget.onSubmit(home, away);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _ScoreField(
                controller: _homeCtrl,
                enabled: !_isLocked && !widget.isSubmitting,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('x', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: _ScoreField(
                controller: _awayCtrl,
                enabled: !_isLocked && !widget.isSubmitting,
              ),
            ),
            const SizedBox(width: 8),
            if (_isLocked)
              CountdownTimer(kickoffTime: widget.kickoffTime)
            else
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: widget.isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: widget.isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.existing != null ? 'Atualizar' : 'Palpitar',
                          style: const TextStyle(fontSize: 12),
                        ),
                ),
              ),
          ],
        ),
        if (!_isLocked) ...[
          const SizedBox(height: 4),
          CountdownTimer(kickoffTime: widget.kickoffTime),
        ],
      ],
    );
  }
}

class _ScoreField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const _ScoreField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.textSecondary),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: !enabled,
        fillColor: Colors.grey.shade100,
      ),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}
