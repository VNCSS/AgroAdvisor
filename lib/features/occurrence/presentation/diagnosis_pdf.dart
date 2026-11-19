import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/date_formatter.dart';
import '../domain/diagnosis_model.dart';

const diagnosisDisclaimer =
    'Diagnóstico informativo. Consulte um engenheiro agrônomo para avaliação definitiva.';

String diagnosisRiskLabel(String riskLevel) =>
    switch (riskLevel.toLowerCase()) {
      'alto' => 'Risco alto',
      'médio' || 'medio' => 'Risco médio',
      'baixo' => 'Risco baixo',
      _ => 'Risco desconhecido',
    };

Future<Uint8List> buildDiagnosisPdf(DiagnosisModel diagnosis) {
  final document = pw.Document(title: 'Relatório de diagnóstico — AgroAdvisor');
  final heading = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
  final confidence = (diagnosis.confidenceScore * 100).round();

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(42),
      header: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 16),
        child: pw.Text(
          'AgroAdvisor',
          style: pw.TextStyle(
            color: PdfColors.green900,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('${context.pageNumber} / ${context.pagesCount}'),
      ),
      build: (context) => [
        pw.Text(
          'Relatório de diagnóstico',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          diagnosis.pestName,
          style: heading,
          overflow: pw.TextOverflow.span,
        ),
        pw.Text(
          '${diagnosisRiskLabel(diagnosis.riskLevel)} | Confiança: $confidence%',
        ),
        pw.Text(
          'Análise realizada em ${DateFormatter.format(diagnosis.analyzedAt)}',
        ),
        if (diagnosis.detectedIssues.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Outras hipóteses', style: heading),
          for (final issue in diagnosis.detectedIssues)
            pw.Text('- $issue', overflow: pw.TextOverflow.span),
        ],
        pw.SizedBox(height: 16),
        pw.Text('Por que esse diagnóstico', style: heading),
        pw.Text(diagnosis.description, overflow: pw.TextOverflow.span),
        pw.SizedBox(height: 16),
        pw.Text('Recomendação de manejo', style: heading),
        pw.Text(diagnosis.recommendation, overflow: pw.TextOverflow.span),
        pw.SizedBox(height: 16),
        pw.Text(
          diagnosisDisclaimer,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
        ),
      ],
    ),
  );

  return document.save();
}
