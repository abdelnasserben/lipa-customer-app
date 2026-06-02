import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/enums.dart';
import '../../data/models/transaction.dart';
import '../../data/models/transfer_result.dart';
import '../widgets/status_pills.dart';
import 'formatters.dart';

/// Builds the share/PDF artefacts for a transaction receipt from a single
/// [CustomerTransaction]. Pure presentation logic so both the activity detail
/// and the send-receipt screens can reuse it.

/// PDF theme backed by a real TrueType font. The default PDF font (Helvetica)
/// lacks the Unicode minus sign U+2212 used in amounts (it renders as a missing
/// glyph / tofu box), so we load Open Sans — which covers it — via printing's
/// Google Fonts helper. The font bytes are cached after the first download.
Future<pw.ThemeData> _pdfTheme() async => pw.ThemeData.withFont(
      base: await PdfGoogleFonts.openSansRegular(),
      bold: await PdfGoogleFonts.openSansBold(),
    );

/// A plain-text recap suitable for the native share sheet.
String receiptShareText(CustomerTransaction t) {
  final sign = t.isIncoming ? '+' : '−';
  final lines = <String>[
    'Reçu Lipa',
    '',
    '${t.isIncoming ? 'Reçu de' : 'Envoyé à'} : ${t.counterparty ?? typeLabelFr(t.type)}',
    'Montant : $sign${fmtKmfNoUnit(t.requestedAmount)} KMF',
    'Type : ${typeLabelFr(t.type)}',
    'Statut : ${statusLabelFr(t.status)}',
    'Date : ${fmtDateTimeFr(t.createdAt)}',
    if (t.feeAmount > 0) 'Frais : ${fmtKmfNoUnit(t.feeAmount)} KMF',
    'Montant net : ${fmtKmfNoUnit(t.netAmountToDestination)} KMF',
    'Référence : ${t.id}',
  ];
  return lines.join('\n');
}

/// Renders the receipt as a printable/shareable PDF document.
Future<Uint8List> receiptPdfBytes(CustomerTransaction t) async {
  final doc = pw.Document(theme: await _pdfTheme());
  final sign = t.isIncoming ? '+' : '−';

  const ink = PdfColor.fromInt(0xFF171717);
  const inkMid = PdfColor.fromInt(0xFF5A5852);
  const inkLow = PdfColor.fromInt(0xFF8A8780);
  const brand = PdfColor.fromInt(0xFF386851);
  const line = PdfColor.fromInt(0xFFE6E3DC);

  pw.Widget row(String label, String value, {bool last = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10),
        decoration: last
            ? null
            : const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.8)),
              ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(color: inkMid, fontSize: 11)),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Text(
                value,
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(color: ink, fontSize: 11),
              ),
            ),
          ],
        ),
      );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 48),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Lipa',
              style: pw.TextStyle(
                  color: brand, fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Reçu de transaction',
              style: const pw.TextStyle(color: inkLow, fontSize: 12)),
          pw.SizedBox(height: 28),
          pw.Text(t.isIncoming ? 'Reçu de' : 'Envoyé à',
              style: const pw.TextStyle(color: inkMid, fontSize: 11)),
          pw.SizedBox(height: 2),
          pw.Text(t.counterparty ?? typeLabelFr(t.type),
              style: pw.TextStyle(
                  color: ink, fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 18),
          pw.Text('$sign${fmtKmfNoUnit(t.requestedAmount)} KMF',
              style: pw.TextStyle(
                  color: ink, fontSize: 30, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 28),
          row('Statut', statusLabelFr(t.status)),
          row('Date', fmtDateTimeFr(t.createdAt)),
          row('Type', typeLabelFr(t.type)),
          if (t.feeAmount > 0)
            row('Frais', '${fmtKmfNoUnit(t.feeAmount)} KMF'),
          row('Montant net', '${fmtKmfNoUnit(t.netAmountToDestination)} KMF'),
          row('Référence', t.id, last: true),
          pw.Spacer(),
          pw.Text(
            'Ce reçu est généré par l’application Lipa à titre informatif.',
            style: const pw.TextStyle(color: inkLow, fontSize: 9),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

/// Adapts a P2P transfer result (plus the screen's known recipient/amount) into
/// a [CustomerTransaction], so the send-receipt screen reuses the exact same
/// share/PDF rendering as the activity detail. The transfer is always outgoing
/// from the sender's point of view.
CustomerTransaction receiptFromP2p({
  required P2pTransferResult result,
  required Beneficiary recipient,
  required int amount,
  required int fee,
}) {
  final feeShown = result.feeAmount ?? fee;
  return CustomerTransaction(
    id: result.transactionId ?? '—',
    type: TransactionType.p2pTransfer,
    status: result.status ?? TransactionStatus.completed,
    requestedAmount: result.requestedAmount,
    feeAmount: feeShown,
    netAmountToDestination:
        result.netAmountToDestination ?? (amount - feeShown),
    createdAt: result.completedAt ?? DateTime.now(),
    completedAt: result.completedAt,
    isIncoming: false,
    counterparty: recipient.fullName,
  );
}

/// Renders a ledger statement (a date window's entries with running balance)
/// as a printable/shareable PDF. [from]/[to] are the chosen window, null = all.
Future<Uint8List> statementPdfBytes(
  List<StatementEntry> entries, {
  DateTime? from,
  DateTime? to,
}) async {
  final doc = pw.Document(theme: await _pdfTheme());

  const ink = PdfColor.fromInt(0xFF171717);
  const inkMid = PdfColor.fromInt(0xFF5A5852);
  const inkLow = PdfColor.fromInt(0xFF8A8780);
  const brand = PdfColor.fromInt(0xFF386851);
  const credit = PdfColor.fromInt(0xFF386851);
  const line = PdfColor.fromInt(0xFFE6E3DC);
  const headerBg = PdfColor.fromInt(0xFFF1EFE8);

  final period = (from == null && to == null)
      ? 'Toute la période'
      : '${from != null ? fmtDateTimeFr(from) : '…'} → '
          '${to != null ? fmtDateTimeFr(to) : '…'}';

  pw.Widget cell(String text,
          {pw.TextAlign align = pw.TextAlign.left,
          PdfColor color = ink,
          bool bold = false}) =>
      pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal));

  pw.TableRow headerRow() => pw.TableRow(
        decoration: const pw.BoxDecoration(color: headerBg),
        children: [
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: cell('Date', bold: true, color: inkMid)),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: cell('Description', bold: true, color: inkMid)),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: cell('Montant',
                  align: pw.TextAlign.right, bold: true, color: inkMid)),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: cell('Solde',
                  align: pw.TextAlign.right, bold: true, color: inkMid)),
        ],
      );

  pw.TableRow entryRow(StatementEntry e) => pw.TableRow(
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: line, width: 0.6)),
        ),
        children: [
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: cell(fmtDateTimeFr(e.postedAt), color: inkMid)),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: cell(e.displayDescription)),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: cell(
              '${e.isCredit ? '+' : '−'}${fmtKmfNoUnit(e.amount)}',
              align: pw.TextAlign.right,
              color: e.isCredit ? credit : ink,
            ),
          ),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: cell(fmtKmfNoUnit(e.runningBalance),
                  align: pw.TextAlign.right, color: inkMid)),
        ],
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 44, 36, 44),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text('Relevé Lipa',
                  style: const pw.TextStyle(color: inkLow, fontSize: 9)),
            ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(color: inkLow, fontSize: 9)),
      ),
      build: (context) => [
        pw.Text('Lipa',
            style: pw.TextStyle(
                color: brand, fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text('Relevé de compte',
            style: const pw.TextStyle(color: inkLow, fontSize: 12)),
        pw.SizedBox(height: 4),
        pw.Text('Période : $period',
            style: const pw.TextStyle(color: inkMid, fontSize: 10)),
        pw.SizedBox(height: 16),
        if (entries.isEmpty)
          pw.Text('Aucune écriture sur cette période.',
              style: const pw.TextStyle(color: inkLow, fontSize: 11))
        else
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(2.4),
              1: pw.FlexColumnWidth(3.2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              headerRow(),
              ...entries.map(entryRow),
            ],
          ),
      ],
    ),
  );

  return doc.save();
}
