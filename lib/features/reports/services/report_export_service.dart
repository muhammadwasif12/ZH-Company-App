import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/order_model.dart';
import '../../../models/staff_model.dart';

class ReportExportData {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final Map<String, String>? summary;

  ReportExportData({
    required this.title,
    required this.headers,
    required this.rows,
    this.summary,
  });
}

class ReportExportService {
  /// Generate Report Data structure based on active tab index & state
  static ReportExportData prepareReportData({
    required int tabIndex,
    required List<OrderModel> orders,
    required List<StaffModel> staffList,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();

    switch (tabIndex) {
      case 0: // Daily Report
        final todayOrders = orders.where((o) =>
          o.orderDate.year == now.year &&
          o.orderDate.month == now.month &&
          o.orderDate.day == now.day
        ).toList();
        final totalCod = todayOrders.fold<double>(0, (sum, o) => sum + o.codAmount);
        return ReportExportData(
          title: 'Daily Report (${dateFormat.format(now)})',
          headers: ['Order ID', 'Customer', 'City', 'Product', 'COD (Rs.)', 'Status', 'Date'],
          rows: todayOrders.map((o) => [
            o.displayId,
            o.customerName,
            o.city,
            o.productName,
            o.codAmount.toStringAsFixed(0),
            o.status.toUpperCase(),
            dateFormat.format(o.orderDate),
          ]).toList(),
          summary: {
            'Total Orders Today': '${todayOrders.length}',
            'Total COD Today': 'Rs. ${totalCod.toStringAsFixed(0)}',
          },
        );

      case 1: // Staff-wise Report
        final Map<String, List<OrderModel>> grouped = {};
        for (final o in orders) {
          grouped.putIfAbsent(o.staffName ?? o.staffId ?? 'Deleted staff', () => []).add(o);
        }
        return ReportExportData(
          title: 'Staff Performance Report',
          headers: ['Staff Name', 'Total Orders', 'Delivered', 'Returned', 'Total COD (Rs.)'],
          rows: grouped.entries.map((e) {
            final del = e.value.where((o) => o.status == 'delivered').length;
            final ret = e.value.where((o) => o.status == 'returned').length;
            final cod = e.value.fold<double>(0, (s, o) => s + o.codAmount);
            return [
              e.key,
              '${e.value.length}',
              '$del',
              '$ret',
              cod.toStringAsFixed(0),
            ];
          }).toList(),
          summary: {
            'Total Staff Members': '${grouped.length}',
            'Total Orders Managed': '${orders.length}',
          },
        );

      case 2: // Product-wise Report
        final Map<String, List<OrderModel>> grouped = {};
        for (final o in orders) {
          grouped.putIfAbsent(o.productName, () => []).add(o);
        }
        return ReportExportData(
          title: 'Product-wise Sales Report',
          headers: ['Product Name', 'Total Orders', 'Delivered', 'Total Revenue (Rs.)'],
          rows: grouped.entries.map((e) {
            final del = e.value.where((o) => o.status == 'delivered').length;
            final cod = e.value.fold<double>(0, (s, o) => s + o.codAmount);
            return [
              e.key,
              '${e.value.length}',
              '$del',
              cod.toStringAsFixed(0),
            ];
          }).toList(),
        );

      case 3: // City-wise Report
        final Map<String, List<OrderModel>> grouped = {};
        for (final o in orders) {
          grouped.putIfAbsent(o.city, () => []).add(o);
        }
        return ReportExportData(
          title: 'City-wise Logistics Report',
          headers: ['City Name', 'Total Orders', 'Delivered', 'Total COD (Rs.)'],
          rows: grouped.entries.map((e) {
            final del = e.value.where((o) => o.status == 'delivered').length;
            final cod = e.value.fold<double>(0, (s, o) => s + o.codAmount);
            return [
              e.key,
              '${e.value.length}',
              '$del',
              cod.toStringAsFixed(0),
            ];
          }).toList(),
        );

      case 4: // Delivered Report
        final filtered = orders.where((o) => o.status == 'delivered').toList();
        return ReportExportData(
          title: 'Delivered Orders Report',
          headers: ['Order ID', 'Customer', 'City', 'Product', 'COD (Rs.)', 'Date'],
          rows: filtered.map((o) => [
            o.displayId,
            o.customerName,
            o.city,
            o.productName,
            o.codAmount.toStringAsFixed(0),
            dateFormat.format(o.orderDate),
          ]).toList(),
          summary: {
            'Total Delivered Orders': '${filtered.length}',
            'Total Delivered Amount': 'Rs. ${filtered.fold<double>(0, (s, o) => s + o.codAmount).toStringAsFixed(0)}',
          },
        );

      case 5: // Return Report
        final filtered = orders.where((o) => o.status == 'returned').toList();
        return ReportExportData(
          title: 'Returned Orders Report',
          headers: ['Order ID', 'Customer', 'City', 'Product', 'COD (Rs.)', 'Date'],
          rows: filtered.map((o) => [
            o.displayId,
            o.customerName,
            o.city,
            o.productName,
            o.codAmount.toStringAsFixed(0),
            dateFormat.format(o.orderDate),
          ]).toList(),
          summary: {
            'Total Returned Orders': '${filtered.length}',
            'Total Return Value': 'Rs. ${filtered.fold<double>(0, (s, o) => s + o.codAmount).toStringAsFixed(0)}',
          },
        );

      case 6: // COD Report
        final totalCod = orders.fold<double>(0, (s, o) => s + o.codAmount);
        final delCod = orders.where((o) => o.status == 'delivered').fold<double>(0, (s, o) => s + o.codAmount);
        return ReportExportData(
          title: 'Cash On Delivery (COD) Report',
          headers: ['Order ID', 'Customer', 'City', 'Product', 'COD (Rs.)', 'Status', 'Date'],
          rows: orders.map((o) => [
            o.displayId,
            o.customerName,
            o.city,
            o.productName,
            o.codAmount.toStringAsFixed(0),
            o.status.toUpperCase(),
            dateFormat.format(o.orderDate),
          ]).toList(),
          summary: {
            'Total COD Amount': 'Rs. ${totalCod.toStringAsFixed(0)}',
            'Collected COD (Delivered)': 'Rs. ${delCod.toStringAsFixed(0)}',
            'Pending COD': 'Rs. ${(totalCod - delCod).toStringAsFixed(0)}',
          },
        );

      case 7: // Salary Report
        return ReportExportData(
          title: 'Staff Salary & Commission Report',
          headers: ['Staff Name', 'Delivered', 'Returns', 'Commission (Rs.)', 'Penalty (Rs.)', 'Net Salary (Rs.)'],
          rows: staffList.map((s) {
            final so = orders.where((o) => o.staffId == s.userId).toList();
            final del = so.where((o) => o.status == 'delivered').length;
            final ret = so.where((o) => o.status == 'returned').length;
            final double comm = s.commissionType == 'percentage'
                ? so.where((o) => o.status == 'delivered').fold<double>(0, (sum, o) => sum + o.codAmount) * s.commissionValue / 100
                : del * s.commissionValue;
            final double pen = ret * s.returnPenalty;
            final double net = comm - pen;
            return [
              s.name,
              '$del',
              '$ret',
              comm.toStringAsFixed(0),
              pen.toStringAsFixed(0),
              net.toStringAsFixed(0),
            ];
          }).toList(),
        );

      case 8: // Profit / Loss Report
      default:
        final totalRevenue = orders.where((o) => o.status == 'delivered').fold<double>(0, (s, o) => s + o.codAmount);
        final totalCharges = orders.where((o) => o.status == 'delivered').fold<double>(0, (s, o) => s + o.deliveryCharges);
        final totalDiscount = orders.where((o) => o.status == 'delivered').fold<double>(0, (s, o) => s + o.discount);
        final netProfit = totalRevenue - totalCharges - totalDiscount;

        return ReportExportData(
          title: 'Financial Profit & Loss Statement',
          headers: ['Metric Category', 'Amount (PKR)'],
          rows: [
            ['Gross Delivered Revenue', 'Rs. ${totalRevenue.toStringAsFixed(0)}'],
            ['Total Delivery Charges', 'Rs. ${totalCharges.toStringAsFixed(0)}'],
            ['Discounts Granted', 'Rs. ${totalDiscount.toStringAsFixed(0)}'],
            ['Net Profit / Loss', 'Rs. ${netProfit.toStringAsFixed(0)}'],
          ],
          summary: {
            'Net Profit Margin': 'Rs. ${netProfit.toStringAsFixed(0)}',
            'Statement Date': dateFormat.format(now),
          },
        );
    }
  }

  /// Export data to Excel file
  static Future<void> exportToExcel(ReportExportData data) async {
    final excel = Excel.createExcel();
    final sheetName = 'ZH Group Report';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    // Add Title
    sheet.appendRow([TextCellValue(data.title.toUpperCase())]);
    sheet.appendRow([TextCellValue('Generated: ${DateFormat('dd-MMM-yyyy HH:mm').format(DateTime.now())}')]);
    sheet.appendRow([TextCellValue('')]); // Blank line

    // Add Summary block if present
    if (data.summary != null) {
      data.summary!.forEach((key, val) {
        sheet.appendRow([TextCellValue(key), TextCellValue(val)]);
      });
      sheet.appendRow([TextCellValue('')]);
    }

    // Add Column Headers
    sheet.appendRow(data.headers.map((h) => TextCellValue(h)).toList());

    // Add Data Rows
    for (final row in data.rows) {
      sheet.appendRow(row.map((cell) => TextCellValue(cell)).toList());
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final sanitizedTitle = data.title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final filename = 'ZH_Group_${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      text: 'ZH Group of Companies: ${data.title}',
    );
  }

  /// Export or Print PDF document using Pdf & Printing libraries
  static Future<void> generateAndPrintPdf({
    required ReportExportData data,
    required bool isPrintMode,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ZH GROUP OF COMPANIES', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Confidential • Internal Business Report', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 10),
            pw.Text(
              data.title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 12),

            // Summary cards block
            if (data.summary != null && data.summary!.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: data.summary!.entries.map((e) {
                    return pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(e.key, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text(e.value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      ],
                    );
                  }).toList(),
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // Main Data Table
            pw.TableHelper.fromTextArray(
              headers: data.headers,
              data: data.rows.isEmpty ? [['No records found for this report period', ...List.filled(data.headers.length - 1, '')]] : data.rows,
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
              cellStyle: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final sanitizedTitle = data.title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final filename = 'ZH_Group_$sanitizedTitle.pdf';

    if (isPrintMode) {
      // Direct Native Printing
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: filename,
      );
    } else {
      // PDF Export & Share/Save
      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );
    }
  }
}
