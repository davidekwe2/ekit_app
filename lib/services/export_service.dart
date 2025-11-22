import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../models/note.dart';
import '../features/storage/store.dart';

class ExportService {
  /// Export note to PDF
  static Future<void> exportToPDF(Note note) async {
    try {
      final pdf = pw.Document();
      
      // Build PDF content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Title
              pw.Header(
                level: 0,
                child: pw.Text(
                  note.title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Subject and date
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (note.subject != null)
                    pw.Text(
                      'Subject: ${_getSubjectName(note.subject!)}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  pw.Text(
                    'Date: ${_formatDate(note.createdAt)}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              
              // Transcript
              pw.Text(
                'Transcript',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                note.transcript,
                style: const pw.TextStyle(fontSize: 12),
              ),
              
              // AI Summary if available
              if (note.aiSummary != null && note.aiSummary!.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  note.aiSummary!,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
              
              // Key Points if available
              if (note.importantPoints != null && note.importantPoints!.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Key Points',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                ...note.importantPoints!.map((point) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 20, bottom: 5),
                  child: pw.Text(
                    '• $point',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                )),
              ],
              
              // Translation of Summary if available
              if (note.aiSummaryTranslation != null && note.aiSummaryTranslation!.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Summary (Translation)',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  note.aiSummaryTranslation!,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
              
              // Translation of Key Points if available
              if (note.importantPointsTranslation != null && note.importantPointsTranslation!.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Key Points (Translation)',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                ...note.importantPointsTranslation!.map((point) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 20, bottom: 5),
                  child: pw.Text(
                    '• $point',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                )),
              ],
              
              // AI Translation if available
              if (note.aiTranslation != null && note.aiTranslation!.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Translation',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  note.aiTranslation!,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
              
              // Comments if available
              if (note.comments != null && note.comments!.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Comments',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  note.comments!,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ];
          },
        ),
      );
      
      // Save and share PDF using Printing (more reliable)
      final bytes = await pdf.save();
      
      // Use Printing's share functionality which handles platform channels properly
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${note.title.replaceAll(RegExp(r'[^\w\s-]'), '_')}.pdf',
      );
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  /// Export note to Word (as plain text file for now, can be enhanced with docx package)
  static Future<void> exportToWord(Note note) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${note.title.replaceAll(RegExp(r'[^\w\s-]'), '_')}.txt');
      
      // Build document content
      final content = StringBuffer();
      content.writeln(note.title);
      content.writeln('=' * note.title.length);
      content.writeln();
      
      if (note.subject != null) {
        content.writeln('Subject: ${_getSubjectName(note.subject!)}');
      }
      content.writeln('Date: ${_formatDate(note.createdAt)}');
      content.writeln();
      content.writeln('--- Transcript ---');
      content.writeln(note.transcript);
      content.writeln();
      
      if (note.aiSummary != null && note.aiSummary!.isNotEmpty) {
        content.writeln('--- Summary ---');
        content.writeln(note.aiSummary!);
        content.writeln();
      }
      
      if (note.importantPoints != null && note.importantPoints!.isNotEmpty) {
        content.writeln('--- Key Points ---');
        for (final point in note.importantPoints!) {
          content.writeln('• $point');
        }
        content.writeln();
      }
      
      // Translation of Summary if available
      if (note.aiSummaryTranslation != null && note.aiSummaryTranslation!.isNotEmpty) {
        content.writeln('--- Summary (Translation) ---');
        content.writeln(note.aiSummaryTranslation!);
        content.writeln();
      }
      
      // Translation of Key Points if available
      if (note.importantPointsTranslation != null && note.importantPointsTranslation!.isNotEmpty) {
        content.writeln('--- Key Points (Translation) ---');
        for (final point in note.importantPointsTranslation!) {
          content.writeln('• $point');
        }
        content.writeln();
      }
      
      // AI Translation if available
      if (note.aiTranslation != null && note.aiTranslation!.isNotEmpty) {
        content.writeln('--- Translation ---');
        content.writeln(note.aiTranslation!);
        content.writeln();
      }
      
      if (note.comments != null && note.comments!.isNotEmpty) {
        content.writeln('--- Comments ---');
        content.writeln(note.comments!);
      }
      
      await file.writeAsString(content.toString());
      
      // Use share_plus with proper error handling
      try {
        final xFile = XFile(file.path);
        await Share.shareXFiles(
          [xFile],
          text: 'Exported note: ${note.title}',
        );
      } catch (e) {
        // Fallback: Share as text if file sharing fails
        await Share.share(
          content.toString(),
          subject: 'Exported note: ${note.title}',
        );
      }
    } catch (e) {
      throw Exception('Failed to export Word document: $e');
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _getSubjectName(String subjectId) {
    try {
      final subject = AppStore.subjects.firstWhere(
        (s) => s.id == subjectId,
        orElse: () => AppStore.subjects.first,
      );
      return subject.name;
    } catch (e) {
      return subjectId;
    }
  }
}

