import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/project_model.dart';
import '../models/task_model.dart';

const _violet = PdfColor.fromInt(0xFF7C5CFF);
const _midnight = PdfColor.fromInt(0xFF0A0E27);
const _grey = PdfColor.fromInt(0xFF6B7280);
const _border = PdfColor.fromInt(0xFFE2E8F0);

class ProjectPdfService {
  static Future<void> shareProjectReport({
    required ProjectModel project,
    required List<TaskModel> tasks,
  }) async {
    final doc = pw.Document();
    final percent = (project.progress * 100).round();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'deskly',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: _violet,
                    ),
                  ),
                  pw.Text(
                    'Rapport de projet',
                    style: const pw.TextStyle(fontSize: 11, color: _grey),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                project.title,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _midnight,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${project.clientName} · ${project.type}',
                style: const pw.TextStyle(fontSize: 12, color: _grey),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: _violet,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfStat('Statut', project.status),
                    _pdfStat('Budget', project.budget),
                    _pdfStat('Deadline', project.deadline),
                    _pdfStat('Avancement', '$percent%'),
                  ],
                ),
              ),
              pw.SizedBox(height: 28),
              pw.Text(
                'Tâches associées',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _midnight,
                ),
              ),
              pw.SizedBox(height: 10),
              if (tasks.isEmpty)
                pw.Text(
                  'Aucune tâche associée à ce projet.',
                  style: const pw.TextStyle(fontSize: 11, color: _grey),
                )
              else
                pw.Table(
                  border: pw.TableBorder.all(color: _border, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(3),
                    1: pw.FlexColumnWidth(1.4),
                    2: pw.FlexColumnWidth(1.4),
                    3: pw.FlexColumnWidth(1.6),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
                      children: [
                        _pdfHeaderCell('Tâche'),
                        _pdfHeaderCell('Statut'),
                        _pdfHeaderCell('Priorité'),
                        _pdfHeaderCell('Deadline'),
                      ],
                    ),
                    ...tasks.map(
                      (task) => pw.TableRow(
                        children: [
                          _pdfCell(task.title),
                          _pdfCell(task.status),
                          _pdfCell(task.priority),
                          _pdfCell(task.deadline),
                        ],
                      ),
                    ),
                  ],
                ),
              pw.Spacer(),
              pw.Divider(color: _border),
              pw.Text(
                'Généré avec Deskly le ${_formatDate(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: _grey),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${_slug(project.title)}-rapport.pdf',
    );
  }

  static pw.Widget _pdfStat(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        ),
      ],
    );
  }

  static pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _midnight),
      ),
    );
  }

  static pw.Widget _pdfCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10, color: _midnight)),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _slug(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
