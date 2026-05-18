import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../services/diagnosis_service.dart';
import '../../domain/occurrence_model.dart';
import '../screens/diagnosis_screen.dart';

/// Card de uma ocorrência no feed do Radar Colaborativo.
///
/// Extraído de occurrence_screen.dart para que o arquivo principal
/// permaneça focado na orquestração da tela.
class OccurrenceCard extends StatefulWidget {
  final OccurrenceModel occurrence;

  /// true enquanto a análise automática (disparada ao registrar) estiver rodando.
  final bool isAnalyzingBySystem;

  const OccurrenceCard({
    super.key,
    required this.occurrence,
    this.isAnalyzingBySystem = false,
  });

  @override
  State<OccurrenceCard> createState() => _OccurrenceCardState();
}

class _OccurrenceCardState extends State<OccurrenceCard> {
  bool _isAnalyzingManually = false;

  Future<void> _analyzeManually() async {
    setState(() => _isAnalyzingManually = true);
    String? errorMessage;
    try {
      final result = await context.read<DiagnosisService>().analyzeAndSave(
            widget.occurrence.id,
            widget.occurrence.imageBase64,
            onError: (e) => errorMessage = e,
          );
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Erro desconhecido na análise.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      } else {
        dev.log('[OccurrenceCard] análise manual concluída: ${result.pestName}');
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingManually = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final occurrence = widget.occurrence;
    final isAnalyzing = widget.isAnalyzingBySystem || _isAnalyzingManually;
    final hasDiagnosis = occurrence.diagnosis != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasDiagnosis
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DiagnosisScreen(diagnosis: occurrence.diagnosis!),
                  ),
                )
            : null,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Image.memory(
                base64Decode(occurrence.imageBase64),
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 90,
                  height: 90,
                  child: Icon(Icons.broken_image, size: 40),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📍 ${occurrence.latitude.toStringAsFixed(4)}, '
                      '${occurrence.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🕐 ${DateFormatter.format(occurrence.timestamp)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    _DiagnosisBadge(
                      isAnalyzing: isAnalyzing,
                      occurrence: occurrence,
                      onAnalyzeTap: _analyzeManually,
                    ),
                  ],
                ),
              ),
            ),
            if (hasDiagnosis)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Badge de diagnóstico ──────────────────────────────────────────────────────

class _DiagnosisBadge extends StatelessWidget {
  final bool isAnalyzing;
  final OccurrenceModel occurrence;
  final VoidCallback onAnalyzeTap;

  const _DiagnosisBadge({
    required this.isAnalyzing,
    required this.occurrence,
    required this.onAnalyzeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isAnalyzing) {
      return const Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 6),
          Text('Analisando...', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
    }

    final diagnosis = occurrence.diagnosis;

    if (diagnosis != null) {
      final color = _riskColor(diagnosis.riskLevel);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                diagnosis.pestName,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onAnalyzeTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_fix_high, size: 13, color: Colors.grey),
            SizedBox(width: 4),
            Text('Analisar com IA', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Color _riskColor(String riskLevel) => switch (riskLevel.toLowerCase()) {
        'alto' => Colors.red,
        'médio' || 'medio' => Colors.orange,
        'baixo' => Colors.green,
        _ => Colors.grey,
      };
}
