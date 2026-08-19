import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../models/order_model.dart';
import '../../models/staff_model.dart';
import 'supabase_service.dart';

class ExportService {
  ExportService._();

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  static Future<dynamic> _selectOptional(String table) async {
    try {
      return await SupabaseService.client.from(table).select();
    } catch (_) {
      return <dynamic>[];
    }
  }

  /// 1. Export All Orders to Excel (.xlsx)
  static Future<String?> exportOrdersToExcel(List<OrderModel> orders) async {
    try {
      final excel = Excel.createExcel();
      final Sheet sheet = excel['Orders'];
      excel.setDefaultSheet('Orders');

      // Headers
      final headers = [
        'Order ID', 'Customer Name', 'Mobile', 'WhatsApp', 'Address', 'City',
        'Product Name', 'Quantity', 'COD Amount', 'Delivery Charges', 'Discount',
        'Net Amount', 'Courier', 'Tracking Number', 'Status', 'Order Date', 'Staff Name'
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Rows
      for (final o in orders) {
        sheet.appendRow([
          TextCellValue(o.displayId),
          TextCellValue(o.customerName),
          TextCellValue(o.customerMobile),
          TextCellValue(o.customerWhatsapp ?? ''),
          TextCellValue(o.address),
          TextCellValue(o.city),
          TextCellValue(o.productName),
          IntCellValue(o.quantity),
          DoubleCellValue(o.codAmount),
          DoubleCellValue(o.deliveryCharges),
          DoubleCellValue(o.discount),
          DoubleCellValue(o.netCod),
          TextCellValue(o.courierCompany ?? ''),
          TextCellValue(o.trackingNumber ?? ''),
          TextCellValue(o.status.toUpperCase()),
          TextCellValue('${o.orderDate.day}/${o.orderDate.month}/${o.orderDate.year}'),
          TextCellValue(o.staffName ?? ''),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) return null;

      final fileName = 'zh_group_orders_${_timestamp()}.xlsx';

      String? outputFile;
      try {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Excel File',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );
      } catch (_) {}

      if (outputFile == null) {
        // Fallback to Downloads directory
        final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        outputFile = '${directory.path}/$fileName';
      }

      final file = File(outputFile);
      await file.writeAsBytes(fileBytes);
      try {
        await Share.shareXFiles([XFile(outputFile)], text: 'ZH Group of Companies - Orders Export');
      } catch (_) {}
      return outputFile;
    } catch (e) {
      return null;
    }
  }

  /// 2. Export All System Data to JSON (.json)
  static Future<String?> exportAllDataToJson() async {
    try {
      final client = SupabaseService.client;
      final orders = await client.from('orders').select();
      final products = await client.from('products').select();
      final staff = await client.from('staff').select();
      final deliveryCharges = await client.from('delivery_charges').select();
      final couriers = await client.from('couriers').select();
      final settings = await client.from('settings').select();
      final profiles = await client.from('profiles').select();
      final orderLogs = await _selectOptional('order_logs');
      final codLedger = await _selectOptional('cod_ledger');
      final salaryRecords = await _selectOptional('salary_records');

      final backupData = {
        'export_date': DateTime.now().toIso8601String(),
        'system': 'ZH Group of Companies',
        'version': '1.0.0',
        'data': {
          'orders': orders,
          'products': products,
          'staff': staff,
          'delivery_charges': deliveryCharges,
          'couriers': couriers,
          'settings': settings,
          'profiles': profiles,
          'order_logs': orderLogs,
          'cod_ledger': codLedger,
          'salary_records': salaryRecords,
        }
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);
      final fileName = 'zh_group_full_backup_${_timestamp()}.json';

      String? outputFile;
      try {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Full Backup JSON',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
      } catch (_) {}

      if (outputFile == null) {
        final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        outputFile = '${directory.path}/$fileName';
      }

      final file = File(outputFile);
      await file.writeAsString(jsonStr);
      try {
        await Share.shareXFiles([XFile(outputFile)], text: 'ZH Group of Companies - Full System Backup');
      } catch (_) {}
      return outputFile;
    } catch (e) {
      return null;
    }
  }

  /// 3. Export Business Reports to PDF (.pdf)
  static Future<String?> exportReportsToPdf(List<OrderModel> orders, List<StaffModel> staffList) async {
    try {
      final pdf = pw.Document();

      final totalOrders = orders.length;
      final deliveredOrders = orders.where((o) => o.status == 'delivered').toList();
      final returnedOrders = orders.where((o) => o.status == 'returned').toList();
      final totalRevenue = deliveredOrders.fold<double>(0, (s, o) => s + o.codAmount);
      final totalCharges = deliveredOrders.fold<double>(0, (s, o) => s + o.deliveryCharges);
      final totalDiscount = deliveredOrders.fold<double>(0, (s, o) => s + o.discount);
      final netProfit = totalRevenue - totalCharges - totalDiscount;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ZH GROUP OF COMPANIES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple900)),
                  pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            pw.Text('Executive Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                ['Total Orders Processed', '$totalOrders'],
                ['Delivered Orders', '${deliveredOrders.length}'],
                ['Returned Orders', '${returnedOrders.length}'],
                ['Total Gross Revenue (COD)', 'Rs. ${totalRevenue.toStringAsFixed(0)}'],
                ['Total Shipping & Delivery Charges', 'Rs. ${totalCharges.toStringAsFixed(0)}'],
                ['Total Discounts Granted', 'Rs. ${totalDiscount.toStringAsFixed(0)}'],
                ['Net Profit', 'Rs. ${netProfit.toStringAsFixed(0)}'],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple800),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
            ),
            pw.SizedBox(height: 20),

            pw.Text('Staff Performance Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Staff Name', 'Staff Code', 'Delivered', 'Returns', 'Commission (Rs)', 'Final Salary (Rs)'],
              data: staffList.map((s) {
                final so = orders.where((o) => o.staffId == s.userId).toList();
                final del = so.where((o) => o.status == 'delivered').length;
                final ret = so.where((o) => o.status == 'returned').length;
                final comm = s.commissionType == 'percentage'
                    ? so.where((o) => o.status == 'delivered').fold<double>(0, (sum, o) => sum + o.codAmount) * s.commissionValue / 100
                    : del * s.commissionValue;
                final pen = ret * s.returnPenalty;
                return [
                  s.name,
                  s.staffCode,
                  '$del',
                  '$ret',
                  comm.toStringAsFixed(0),
                  (comm - pen).toStringAsFixed(0),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.purple800),
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = 'zh_group_business_report_${_timestamp()}.pdf';

      String? outputFile;
      try {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save PDF Report',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
      } catch (_) {}

      if (outputFile == null) {
        final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        outputFile = '${directory.path}/$fileName';
      }

      final file = File(outputFile);
      await file.writeAsBytes(pdfBytes);
      try {
        await Share.shareXFiles([XFile(outputFile)], text: 'ZH Group of Companies Business Report');
      } catch (_) {}
      return outputFile;
    } catch (e) {
      return null;
    }
  }

  /// Creates a single order invoice without internal staff data.
  static Future<String?> exportOrderInvoiceToPdf(OrderModel order) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('ZH GROUP OF COMPANIES', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple900)),
            pw.SizedBox(height: 6),
            pw.Text('ORDER INVOICE', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 14),
            pw.Text('Invoice / Order: ${order.displayId}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Order date: ${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year}'),
            pw.SizedBox(height: 18),
            pw.Text('Customer details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(order.customerName),
            pw.Text(order.customerMobile),
            pw.Text('${order.address}, ${order.city}'),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: ['Product', 'Qty', 'COD', 'Delivery', 'Discount'],
              data: [[order.productName, '${order.quantity}', 'Rs. ${order.codAmount.toStringAsFixed(0)}', 'Rs. ${order.deliveryCharges.toStringAsFixed(0)}', 'Rs. ${order.discount.toStringAsFixed(0)}']],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple800),
            ),
            pw.SizedBox(height: 16),
            pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Net COD: Rs. ${order.netCod.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 12),
            pw.Text('Status: ${order.status.replaceAll('_', ' ').toUpperCase()}'),
            if ((order.courierCompany ?? '').isNotEmpty) pw.Text('Courier: ${order.courierCompany}'),
            if ((order.trackingNumber ?? '').isNotEmpty) pw.Text('Tracking: ${order.trackingNumber}'),
          ]),
        ),
      ));
      final bytes = await pdf.save();
      final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final outputFile = '${directory.path}/invoice_${order.displayId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf';
      await File(outputFile).writeAsBytes(bytes);
      try {
        await Share.shareXFiles([XFile(outputFile)], text: 'Invoice ${order.displayId}');
      } catch (_) {}
      return outputFile;
    } catch (_) {
      return null;
    }
  }
}
