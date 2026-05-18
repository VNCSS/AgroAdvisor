import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../domain/diagnosis_model.dart';

/// Exibe o relatório completo do diagnóstico de IA.
class DiagnosisScreen extends StatelessWidget {
  final DiagnosisModel diagnosis;

  const DiagnosisScreen({super.key, required this.diagnosis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico IA'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RiskBanner(riskLevel: diagnosis.riskLevel),
            const SizedBox(height: 16),
            _InfoCard(
              icon: Icons.bug_report_outlined,
              title: 'Problema Identificado',
              content: diagnosis.pestName,
            ),
            const SizedBox(height: 12),
            _ConfidenceBar(score: diagnosis.confidenceScore),
            const SizedBox(height: 16),
            if (diagnosis.detectedIssues.isNotEmpty) ...[
              _DetectedIssuesList(issues: diagnosis.detectedIssues),
              const SizedBox(height: 16),
            ],
            _InfoCard(
              icon: Icons.description_outlined,
              title: 'Descrição Técnica',
              content: diagnosis.description,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.tips_and_updates_outlined,
              title: 'Recomendação de Manejo',
              content: diagnosis.recommendation,
              highlighted: true,
            ),
            const SizedBox(height: 20),
            Text(
              'Análise realizada em ${DateFormatter.format(diagnosis.analyzedAt)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este diagnóstico é informativo. Consulte um engenheiro agrônomo para avaliação definitiva.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets internos ─────────────────────────────────────────────────────────

class _RiskBanner extends StatelessWidget {
  final String riskLevel;
  const _RiskBanner({required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (riskLevel.toLowerCase()) {
      'alto' => (Colors.red, 'RISCO ALTO', Icons.warning_rounded),
      'médio' || 'medio' => (
          Colors.orange,
          'RISCO MÉDIO',
          Icons.warning_amber_rounded
        ),
      'baixo' => (Colors.green, 'RISCO BAIXO', Icons.check_circle_outline),
      _ => (Colors.grey, 'RISCO DESCONHECIDO', Icons.help_outline),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final double score;
  const _ConfidenceBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final percent = (score * 100).toStringAsFixed(0);
    final color =
        score >= 0.7 ? Colors.green : score >= 0.4 ? Colors.orange : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Confiança da IA',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

class _DetectedIssuesList extends StatelessWidget {
  final List<String> issues;
  const _DetectedIssuesList({required this.issues});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Problemas Detectados',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ...issues.map(
          (issue) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 8, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(child: Text(issue, style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final bool highlighted;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? primary.withAlpha(18) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? primary.withAlpha(80) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: primary),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
