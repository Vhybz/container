import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/sale_model.dart';
import '../models/user_model.dart';
import '../models/salary_model.dart';
import '../models/shift_model.dart';
import '../core/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class ReceiptService {
  static Future<Map<String, pw.Font>> _loadFonts() async {
    pw.Font font;
    pw.Font boldFont;
    try {
      font = await PdfGoogleFonts.notoSansRegular().timeout(const Duration(seconds: 2));
      boldFont = await PdfGoogleFonts.notoSansBold().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Font loading failed or timed out, falling back to standard fonts: $e');
      font = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }
    return {'font': font, 'boldFont': boldFont};
  }

  static Future<pw.Document> generateReceiptDocument(SaleRecord sale) async {
    final doc = pw.Document();
    
    final fonts = await _loadFonts();
    final font = fonts['font']!;
    final boldFont = fonts['boldFont']!;

    final isPharmacySale = sale.items.any((i) => 
      i.product.requiresPrescription || 
      i.product.category.toUpperCase().contains('PHARM') || 
      i.product.category.toUpperCase().contains('DRUG') || 
      i.product.category.toUpperCase().contains('MED') ||
      i.product.category.toUpperCase().contains('ANTIBIOTIC') ||
      i.product.category.toUpperCase().contains('SUPPLEMENT') ||
      i.product.category.toUpperCase().contains('ANALGESIC') ||
      i.product.category.toUpperCase().contains('NSAID')
    );

    final String storeTitle = isPharmacySale ? 'EMMANUEL CHEMIST' : 'CONTAINER STORES';
    final String storeSubtitle = isPharmacySale ? 'Pharmacy & Dispensing Services' : 'Multi-Business Store';
    final String storeLocation = isPharmacySale 
        ? 'Location: Opposite Kaabere Main Clinic' 
        : 'Location: New Town, Road linking From Water works Ltd. to Atronie Road';
    final String storeContact = isPharmacySale 
        ? 'GPS: BJ 0003-5661 | Email: ea0005917@gmail.com' 
        : 'GPS: BS-0006-1566 | Tel: 0209276200';
    final String thankYouMsg = isPharmacySale 
        ? 'Thank you for trusting Emmanuel Chemist!\nKeep all medications out of reach of children.' 
        : 'Thank you for shopping with Container Stores!';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(storeTitle, style: pw.TextStyle(font: boldFont, fontSize: 16)),
                    pw.Text(storeSubtitle, style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text(storeLocation, style: pw.TextStyle(font: font, fontSize: 7), textAlign: pw.TextAlign.center),
                    pw.Text(storeContact, style: pw.TextStyle(font: font, fontSize: 7), textAlign: pw.TextAlign.center),
                    pw.SizedBox(height: 8),
                  ],
                ),
              ),
              pw.Text('Invoice: ${sale.id}', style: pw.TextStyle(font: font, fontSize: 9)),
              pw.Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(sale.timestamp)}', style: pw.TextStyle(font: font, fontSize: 9)),
              pw.Text('Cashier: ${sale.cashierName}', style: pw.TextStyle(font: font, fontSize: 9)),
              if (sale.customerName != null)
                pw.Text('Customer: ${sale.customerName} ${sale.customerPhone != null ? "(${sale.customerPhone})" : ""}', 
                  style: pw.TextStyle(font: font, fontSize: 9)),

              if (sale.prescription != null && sale.prescription!.trim().isNotEmpty && sale.includePrescriptionOnReceipt)
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.teal700, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('PRESCRIPTION & DOSAGE (Rx)', 
                            style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: PdfColors.teal900)),
                          if (sale.rxNumber != null && sale.rxNumber!.isNotEmpty)
                            pw.Text('Rx: ${sale.rxNumber}', 
                              style: pw.TextStyle(font: boldFont, fontSize: 7.5, color: PdfColors.teal900)),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      if (sale.patientName != null && sale.patientName!.isNotEmpty)
                        pw.Text('Patient: ${sale.patientName}', 
                          style: pw.TextStyle(font: boldFont, fontSize: 7.5, color: PdfColors.grey800)),
                      if (sale.doctorName != null && sale.doctorName!.isNotEmpty)
                        pw.Text('Prescriber: ${sale.doctorName}', 
                          style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey800)),
                      pw.SizedBox(height: 2),
                      pw.Text(sale.prescription!.trim(), 
                        style: pw.TextStyle(font: font, fontSize: 8)),
                      pw.SizedBox(height: 2),
                      pw.Text('*Adhere strictly to prescribed dosage and instructions.', 
                        style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),

              if (sale.balance > 0.01 && sale.status != SaleStatus.awaitingDeposit)
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  padding: const pw.EdgeInsets.all(4),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.orange50,
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.orange, width: 1),
                      bottom: pw.BorderSide(color: PdfColors.orange, width: 1),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Text('*** CREDIT / DEBT SALE ***', 
                      style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.orange900)),
                  ),
                ),
              
              if (sale.status == SaleStatus.awaitingDeposit)
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.symmetric(vertical: 8),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.red, width: 2),
                    color: PdfColors.red50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('*** AWAITING BANK DEPOSIT ***', style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.red)),
                      pw.Divider(color: PdfColors.red, thickness: 0.5),
                      pw.SizedBox(height: 5),
                      pw.Text('Please pay into the account below:', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.red)),
                      pw.SizedBox(height: 4),
                      pw.Text('Bank: UMB (Universal Merchant Bank)', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                      pw.Text('Branch: Sunyani', style: pw.TextStyle(font: font, fontSize: 8)),
                      pw.Text('Account Name: Mi-Corazon Enterprise', style: pw.TextStyle(font: font, fontSize: 8)),
                      pw.Text('Account Number: 1111069263015', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                      pw.SizedBox(height: 5),
                      pw.Text('VALID ONLY AFTER BANK VERIFICATION', style: pw.TextStyle(font: boldFont, fontSize: 7, color: PdfColors.red)),
                    ],
                  ),
                ),
              
              if (sale.isVerified && sale.bankReceiptUrl != null)
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.symmetric(vertical: 8),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.green, width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text('PAYMENT VERIFIED', style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.green)),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      if (sale.bankReceiptId != null)
                        pw.Text('Bank Ref: ${sale.bankReceiptId}', style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.green)),
                      pw.Text('Receipt Uploaded & Confirmed', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.green700)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
              
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Item', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                  pw.Text('Total', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 5),
              ...sale.items.map((item) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text('[${item.product.category.toUpperCase()}] ${item.product.name} (${WeightConverter.formatShort(item.quantity, unit: item.product.unit, productName: item.product.name, category: item.product.category)})', 
                            style: pw.TextStyle(font: font, fontSize: 8)),
                        ),
                        pw.Text(item.total.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 8)),
                      ],
                    ),
                  ],
                )),
              pw.Divider(thickness: 0.5),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _receiptRow('Sub Total', sale.totalAmount, font),
                      _receiptRow('Net Invoice Value', sale.netInvoiceValue, font, isBold: true),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),

              pw.Text('PAYMENT BREAKDOWN', style: pw.TextStyle(font: boldFont, fontSize: 8)),
              pw.SizedBox(height: 4),

              ...sale.payments.map((p) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('METHOD: ${_formatMethod(p)}', style: pw.TextStyle(font: font, fontSize: 8)),
                      pw.Text('₵ ${p.amount.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                    ],
                  )),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Paid Amount', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                  pw.Text(sale.amountPaid.toStringAsFixed(2), style: pw.TextStyle(font: boldFont, fontSize: 8)),
                ],
              ),
              
              if (sale.amountTendered != null && sale.amountTendered! > sale.amountPaid)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cash Tendered', style: pw.TextStyle(font: font, fontSize: 8)),
                    pw.Text('₵ ${sale.amountTendered!.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 8)),
                  ],
                ),

              if (sale.effectiveChange > 0.01)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CHANGE RETURNED', style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.green800)),
                    pw.Text('₵ ${sale.effectiveChange.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.green800)),
                  ],
                ),
              
              if (sale.balance > 0.01)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('BALANCE DUE (DEBT)', style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.red)),
                    pw.Text(sale.balance.toStringAsFixed(2), style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.red)),
                  ],
                ),

              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: _generateQRData(sale),
                  width: 40,
                  height: 40,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(thankYouMsg, style: pw.TextStyle(font: boldFont, fontSize: 7), textAlign: pw.TextAlign.center),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  static Future<bool> printReceipt(SaleRecord sale, {BuildContext? context}) async {
    try {
      final doc = await generateReceiptDocument(sale);
      final result = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Receipt_${sale.id}',
      );
      return result;
    } catch (e) {
      debugPrint('Printing Error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Printing failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  static Future<void> printInvoices(List<SaleRecord> sales, {BuildContext? context}) async {
    try {
      for (var sale in sales) {
        await printReceipt(sale, context: context);
      }
    } catch (e) {
      debugPrint('Batch Printing Error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch printing error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> shareReceipt(SaleRecord sale, {BuildContext? context}) async {
    try {
      final doc = await generateReceiptDocument(sale);
      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Receipt_${sale.id}.pdf',
      );
    } catch (e) {
      debugPrint('Sharing Error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt sharing failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> shareReceiptViaWhatsApp(
    SaleRecord sale, {
    BuildContext? context,
    String? overridePhone,
    String? customerPhone,
  }) async {
    try {
      final doc = await generateReceiptDocument(sale);
      final bytes = await doc.save();

      // 1. Upload to Supabase public receipts storage bucket
      String? publicPdfUrl;
      try {
        final String path = 'Receipt_${sale.id}.pdf';
        await SupabaseConfig.client.storage.from('receipts').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'application/pdf'),
        );
        publicPdfUrl = SupabaseConfig.client.storage.from('receipts').getPublicUrl(path);
      } catch (uploadError) {
        debugPrint('Receipt Supabase upload notice: $uploadError');
      }

      // 2. Format WhatsApp message
      final String clientName = sale.customerName?.trim().isNotEmpty == true ? sale.customerName!.trim() : 'Valued Customer';
      final String targetPhone = customerPhone ?? overridePhone ?? (sale.customerPhone ?? '');
      
      final String changeInfo = sale.effectiveChange > 0.01 
          ? '\n💵 *Change Returned:* GHS ${sale.effectiveChange.toStringAsFixed(2)}' 
          : '';
      final String linkText = publicPdfUrl != null ? '\n\n📄 Download Official PDF Receipt:\n$publicPdfUrl' : '';
      final String message = '''
*CONTAINER STORE RECEIPT*
Hello $clientName, thank you for your purchase!

🧾 *Invoice #:* ${sale.id}
📅 *Date:* ${DateFormat('dd MMM yyyy, hh:mm a').format(sale.timestamp)}
💰 *Total Paid:* GHS ${sale.totalAmount.toStringAsFixed(2)}$changeInfo$linkText

_Thank you for choosing Container Stores! Have a wonderful day._
'''.trim();

      if (targetPhone.trim().isNotEmpty) {
        String cleanPhone = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanPhone.startsWith('0')) cleanPhone = '233${cleanPhone.substring(1)}';
        final Uri url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: 'Receipt_${sale.id}.pdf');
      }
    } catch (e) {
      debugPrint('WhatsApp share error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share via WhatsApp: $e')),
        );
      }
    }
  }
static String _generateQRData(SaleRecord sale) {
    final buffer = StringBuffer();
    buffer.writeln('MULTI-BUSINESS MANAGER');
    buffer.writeln('Invoice: ${sale.id}');
    buffer.writeln('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(sale.timestamp)}');
    buffer.writeln('Cashier: ${sale.cashierName}');
    if (sale.customerName != null) {
      buffer.writeln('Customer: ${sale.customerName}');
    }
    buffer.writeln('Items:');
    for (var item in sale.items) {
      buffer.writeln('- [${item.product.category.toUpperCase()}] ${item.product.name} (${WeightConverter.formatShort(item.quantity, unit: item.product.unit, productName: item.product.name, category: item.product.category)}): ₵${item.total.toStringAsFixed(2)}');
    }
    buffer.writeln('Total: ₵${sale.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('Paid: ₵${sale.amountPaid.toStringAsFixed(2)}');
    if (sale.effectiveChange > 0.01) {
      buffer.writeln('Change: ₵${sale.effectiveChange.toStringAsFixed(2)}');
    }
    if (sale.balance > 0.01) {
      buffer.writeln('Balance: ₵${sale.balance.toStringAsFixed(2)}');
    }
    return buffer.toString();
  }

  static String _formatMethod(PaymentDetail p) {
    switch (p.method) {
      case PaymentMethod.cash: return 'CASH';
      case PaymentMethod.mobileMoney: return p.isPaystack ? 'MOMO (PAYSTACK)' : 'MOMO';
      case PaymentMethod.bankDeposit: return 'BANK';
    }
  }

  static pw.Widget _receiptRow(String label, double value, pw.Font font, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static Future<void> printSalesReport(List<SaleRecord> sales, {String title = 'Sales Report', double totalExpenses = 0.0}) async {
    try {
      final doc = pw.Document();
      final totalRevenue = sales.where((s) => s.isActive).fold(0.0, (sum, s) => sum + s.totalAmount);
      final netProfit = totalRevenue - totalExpenses;
      
      final fonts = await _loadFonts();
      final font = fonts['font']!;
      final boldFont = fonts['boldFont']!;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MULTI-BUSINESS MANAGER', style: pw.TextStyle(font: boldFont)),
                    pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()), style: pw.TextStyle(font: font)),
                  ],
                ),
              ),
              pw.Text(title, style: pw.TextStyle(fontSize: 18, font: boldFont)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Invoice ID', 'Date', 'Cashier', 'Total', 'Paid', 'Status'],
                data: sales.map((s) => [
                  s.id,
                  DateFormat('MMM dd, HH:mm').format(s.timestamp),
                  s.cashierName,
                  s.totalAmount.toStringAsFixed(2),
                  s.amountPaid.toStringAsFixed(2),
                  s.status.name.toUpperCase(),
                ]).toList(),
                headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF6B1111)),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('Total Revenue: ', style: pw.TextStyle(font: boldFont)),
                          pw.Text('₵ ${totalRevenue.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont)),
                        ],
                      ),
                      if (totalExpenses > 0)
                        pw.Row(
                          children: [
                            pw.Text('Total Expenses: ', style: pw.TextStyle(font: boldFont, color: PdfColors.red)),
                            pw.Text('₵ ${totalExpenses.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, color: PdfColors.red)),
                          ],
                        ),
                      pw.SizedBox(width: 150, child: pw.Divider()),
                      pw.Row(
                        children: [
                          pw.Text('Estimated Profit: ', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColors.green)),
                          pw.Text('₵ ${netProfit.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColors.green)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Sales_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      debugPrint('Sales Report Printing Error: $e');
    }
  }

  static Future<void> printDebtReport(List<SaleRecord> sales) async {
    try {
      final doc = pw.Document();
      final totalDebt = sales.fold(0.0, (sum, s) => sum + s.balance);
      
      // Calculate max debt to determine thresholds
      double maxDebt = 0;
      for (var s in sales) {
        if (s.balance > maxDebt) maxDebt = s.balance;
      }

      final fonts = await _loadFonts();
      final font = fonts['font']!;
      final boldFont = fonts['boldFont']!;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MULTI-BUSINESS MANAGER', style: pw.TextStyle(font: boldFont)),
                    pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()), style: pw.TextStyle(font: font)),
                  ],
                ),
              ),
              pw.Text('OUTSTANDING DEBT REPORT', style: pw.TextStyle(fontSize: 18, font: boldFont)),
              pw.SizedBox(height: 20),
              
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF6B1111)),
                    children: [
                      _tableHeader('Customer', boldFont),
                      _tableHeader('Phone', boldFont),
                      _tableHeader('Invoice ID', boldFont),
                      _tableHeader('Date', boldFont),
                      _tableHeader('Total', boldFont),
                      _tableHeader('Balance', boldFont),
                    ],
                  ),
                  // Data Rows with conditional coloring
                  ...sales.map((s) {
                    PdfColor bgColor = PdfColors.white;
                    PdfColor statusColor = PdfColors.black;

                    if (maxDebt > 0) {
                      if (s.balance >= maxDebt * 0.7 || s.balance >= 500) {
                        bgColor = PdfColors.red50;
                        statusColor = PdfColors.red;
                      } else if (s.balance >= maxDebt * 0.3 || s.balance >= 100) {
                        bgColor = PdfColors.orange50;
                        statusColor = PdfColors.orange;
                      } else {
                        bgColor = PdfColors.green50;
                        statusColor = PdfColors.green;
                      }
                    }

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: bgColor),
                      children: [
                        _tableCell(s.customerName ?? 'Walk-in', font),
                        _tableCell(s.customerPhone ?? 'N/A', font),
                        _tableCell(s.id.substring(s.id.length - 8).toUpperCase(), font),
                        _tableCell(DateFormat('MMM dd, yyyy').format(s.timestamp), font),
                        _tableCell('₵${s.totalAmount.toStringAsFixed(2)}', font),
                        _tableCell('₵${s.balance.toStringAsFixed(2)}', boldFont, color: statusColor),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('TOTAL OUTSTANDING DEBT: ', style: pw.TextStyle(font: boldFont)),
                  pw.Text('₵${totalDebt.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColors.red)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(width: 8, height: 8, color: PdfColors.red),
                  pw.SizedBox(width: 4),
                  pw.Text('High (>₵500)', style: pw.TextStyle(fontSize: 7, font: font)),
                  pw.SizedBox(width: 12),
                  pw.Container(width: 8, height: 8, color: PdfColors.orange),
                  pw.SizedBox(width: 4),
                  pw.Text('Medium (₵100-500)', style: pw.TextStyle(fontSize: 7, font: font)),
                  pw.SizedBox(width: 12),
                  pw.Container(width: 8, height: 8, color: PdfColors.green),
                  pw.SizedBox(width: 4),
                  pw.Text('Low (<₵100)', style: pw.TextStyle(fontSize: 7, font: font)),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Center(
                child: pw.Text('Report Generated by Multi-Business Management System', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Debt_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      debugPrint('Debt Report Printing Error: $e');
    }
  }

  static pw.Widget _tableHeader(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(font: font, color: PdfColors.white, fontSize: 9)),
    );
  }

  static pw.Widget _tableCell(String text, pw.Font font, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 8, color: color)),
    );
  }

  static Future<void> printPaidInvoicesReport(List<SaleRecord> sales) async {
    try {
      final doc = pw.Document();
      final totalPaid = sales.fold(0.0, (sum, s) => sum + s.amountPaid);
      
      // Calculate max paid to determine thresholds
      double maxPaid = 0;
      for (var s in sales) {
        if (s.amountPaid > maxPaid) maxPaid = s.amountPaid;
      }

      final fonts = await _loadFonts();
      final font = fonts['font']!;
      final boldFont = fonts['boldFont']!;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MULTI-BUSINESS MANAGER', style: pw.TextStyle(font: boldFont)),
                    pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()), style: pw.TextStyle(font: font)),
                  ],
                ),
              ),
              pw.Text('FULLY PAID INVOICES REPORT', style: pw.TextStyle(fontSize: 18, font: boldFont)),
              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF28A745)), // Green header
                    children: [
                      _tableHeader('Customer', boldFont),
                      _tableHeader('Invoice ID', boldFont),
                      _tableHeader('Date', boldFont),
                      _tableHeader('Cashier', boldFont),
                      _tableHeader('Total Amount', boldFont),
                    ],
                  ),
                  // Data Rows with conditional coloring
                  ...sales.map((s) {
                    PdfColor bgColor = PdfColors.white;
                    PdfColor textColor = PdfColors.black;

                    if (maxPaid > 0) {
                      if (s.amountPaid >= maxPaid * 0.7) {
                        bgColor = PdfColor.fromInt(0xFFFFEBEE); // Light Red for Highest
                        textColor = PdfColor.fromInt(0xFFB71C1C);
                      } else if (s.amountPaid >= maxPaid * 0.3) {
                        bgColor = PdfColor.fromInt(0xFFFFFDE7); // Light Yellow for Mid
                        textColor = PdfColor.fromInt(0xFFF57F17);
                      } else {
                        bgColor = PdfColor.fromInt(0xFFE8F5E9); // Light Green for Least
                        textColor = PdfColor.fromInt(0xFF1B5E20);
                      }
                    }

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: bgColor),
                      children: [
                        _tableCell(s.customerName ?? 'Walk-in', font, color: textColor),
                        _tableCell(s.id, font, color: textColor),
                        _tableCell(DateFormat('MMM dd, yyyy').format(s.timestamp), font, color: textColor),
                        _tableCell(s.cashierName.split(' ')[0], font, color: textColor),
                        _tableCell('₵${s.totalAmount.toStringAsFixed(2)}', boldFont, color: textColor),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('TOTAL PAID REVENUE: ', style: pw.TextStyle(font: boldFont)),
                  pw.Text('₵${totalPaid.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColors.green)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(width: 10, height: 10, color: const PdfColor.fromInt(0xFFFFEBEE)),
                  pw.SizedBox(width: 4),
                  pw.Text('High Value (>70%)', style: pw.TextStyle(fontSize: 8, font: font)),
                  pw.SizedBox(width: 12),
                  pw.Container(width: 10, height: 10, color: const PdfColor.fromInt(0xFFFFFDE7)),
                  pw.SizedBox(width: 4),
                  pw.Text('Mid Value (30-70%)', style: pw.TextStyle(fontSize: 8, font: font)),
                  pw.SizedBox(width: 12),
                  pw.Container(width: 10, height: 10, color: const PdfColor.fromInt(0xFFE8F5E9)),
                  pw.SizedBox(width: 4),
                  pw.Text('Standard (<30%)', style: pw.TextStyle(fontSize: 8, font: font)),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Center(
                child: pw.Text('Report Generated by Multi-Business Management System', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Paid_Invoices_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      debugPrint('Paid Invoices Report Printing Error: $e');
    }
  }

  static Future<void> printSalaryReport(List<UserAccount> users, {Map<String, bool>? advanceStatus}) async {
    try {
      final doc = pw.Document();
      final totalPayroll = users.fold(0.0, (sum, u) => sum + (u.salaryAmount ?? 0.0));
      
      final fonts = await _loadFonts();
      final font = fonts['font']!;
      final boldFont = fonts['boldFont']!;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MULTI-BUSINESS MANAGER', style: pw.TextStyle(font: boldFont)),
                    pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()), style: pw.TextStyle(font: font)),
                  ],
                ),
              ),
              pw.Text('STAFF PAYROLL & SALARY REPORT', style: pw.TextStyle(fontSize: 18, font: boldFont)),
              pw.SizedBox(height: 20),
              
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF6B1111)),
                    children: [
                      _tableHeader('Staff Name', boldFont),
                      _tableHeader('Role', boldFont),
                      _tableHeader('Due Day', boldFont),
                      _tableHeader('Type', boldFont),
                      _tableHeader('Amount (GHS)', boldFont),
                    ],
                  ),
                  ...users.where((u) => u.salaryAmount != null).map((u) {
                    final isAdvance = u.lastPaymentWasAdvance;
                    return pw.TableRow(
                      children: [
                        _tableCell(u.name, font),
                        _tableCell(u.role.name.toUpperCase(), font),
                        _tableCell('Day ${u.salaryDay ?? "--"}', font),
                        _tableCell(
                          isAdvance ? 'ADVANCE' : 'FULL', 
                          boldFont, 
                          color: isAdvance ? PdfColors.red : PdfColors.black
                        ),
                        _tableCell(
                          u.salaryAmount?.toStringAsFixed(2) ?? '0.00', 
                          boldFont,
                          color: isAdvance ? PdfColors.red : PdfColors.black
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('Total Monthly Payroll: ', style: pw.TextStyle(font: boldFont, fontSize: 14)),
                          pw.Text('₵ ${totalPayroll.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.green)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Center(
                child: pw.Text('Authorized by Administrator', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Salary_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      debugPrint('Salary Report Printing Error: $e');
    }
  }

  static Future<void> printDetailedHistoryReport(List<SaleRecord> sales, {required String period}) async {
    try {
      final doc = pw.Document();
      final activeSales = sales.where((s) => s.isActive).toList();
      final totalRevenue = activeSales.fold(0.0, (sum, s) => sum + s.totalAmount);
      final totalCost = activeSales.fold(0.0, (sum, s) => sum + s.totalCost);
      final netProfit = totalRevenue - totalCost;

      // Product breakdown
      final Map<String, double> productQtyMap = {};
      for (var sale in activeSales) {
        for (var item in sale.items) {
          productQtyMap[item.product.name] = (productQtyMap[item.product.name] ?? 0) + item.quantity;
        }
      }
      final sortedProducts = productQtyMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      final fonts = await _loadFonts();
      final font = fonts['font']!;
      final boldFont = fonts['boldFont']!;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MULTI-BUSINESS MANAGER', style: pw.TextStyle(font: boldFont)),
                    pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()), style: pw.TextStyle(font: font)),
                  ],
                ),
              ),
              pw.Text('DETAILED SALES & PROFIT REPORT', style: pw.TextStyle(fontSize: 18, font: boldFont)),
              pw.Text('Period: $period', style: pw.TextStyle(fontSize: 12, font: font, color: PdfColors.grey700)),
              pw.SizedBox(height: 20),

              // Financial Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _statBox('TOTAL SALES', '₵${totalRevenue.toStringAsFixed(2)}', PdfColors.blue900, boldFont, font),
                  _statBox('TOTAL COST', '₵${totalCost.toStringAsFixed(2)}', PdfColors.red900, boldFont, font),
                  _statBox('NET PROFIT', '₵${netProfit.toStringAsFixed(2)}', PdfColors.green900, boldFont, font),
                ],
              ),
              pw.SizedBox(height: 30),

              // Product Breakdown
              pw.Text('PRODUCT SALES BREAKDOWN', style: pw.TextStyle(fontSize: 14, font: boldFont)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Product Name', 'Total Quantity Sold'],
                data: sortedProducts.map((e) => [e.key, WeightConverter.formatShort(e.value, unit: 'kg')]).toList(),
                headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10),
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF6B1111)),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 30),

              // Transaction Log
              pw.Text('TRANSACTION LOG', style: pw.TextStyle(fontSize: 14, font: boldFont)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['ID', 'Time', 'Customer', 'Items', 'Total'],
                data: activeSales.map((s) => [
                  s.id.substring(s.id.length - 8).toUpperCase(),
                  DateFormat('MMM dd, HH:mm').format(s.timestamp),
                  s.customerName ?? 'Walk-in',
                  s.items.length.toString(),
                  '₵${s.totalAmount.toStringAsFixed(2)}',
                ]).toList(),
                headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10),
                cellStyle: pw.TextStyle(font: font, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Detailed_Sales_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      debugPrint('Detailed Report Printing Error: $e');
    }
  }

  static pw.Widget _statBox(String label, String value, PdfColor color, pw.Font boldFont, pw.Font font) {
    return pw.Container(
      width: 170,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  static Future<void> printSalaryHistory(UserAccount user, List<SalaryRecord> history, {required String period}) async {
    try {
      final doc = pw.Document();
      final totalPaid = history.fold(0.0, (sum, r) => sum + r.amount);

      final fonts = await _loadFonts();
      final font = fonts['font']!;
      final boldFont = fonts['boldFont']!;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MULTI-BUSINESS MANAGER', style: pw.TextStyle(font: boldFont)),
                    pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()), style: pw.TextStyle(font: font)),
                  ],
                ),
              ),
              pw.Text('WORKER PAYMENT STATEMENT', style: pw.TextStyle(fontSize: 18, font: boldFont)),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Employee: ${user.name}', style: pw.TextStyle(font: boldFont)),
                      pw.Text('Role: ${user.role.name.toUpperCase()}', style: pw.TextStyle(font: font, fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Period: $period', style: pw.TextStyle(font: boldFont)),
                      pw.Text('Base Salary: GHS ${user.salaryAmount?.toStringAsFixed(2) ?? "0.00"}', style: pw.TextStyle(font: font, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF6B1111)),
                    children: [
                      _tableHeader('Date', boldFont),
                      _tableHeader('For Month', boldFont),
                      _tableHeader('Type', boldFont),
                      _tableHeader('Note', boldFont),
                      _tableHeader('Amount', boldFont),
                    ],
                  ),
                  ...history.map((r) {
                    final color = r.isAdvance ? PdfColors.red : PdfColors.black;
                    return pw.TableRow(
                      children: [
                        _tableCell(DateFormat('yyyy-MM-dd').format(r.date), font, color: color),
                        _tableCell(DateFormat('MMMM yyyy').format(r.targetMonth), font, color: color),
                        _tableCell(r.isAdvance ? 'ADVANCE' : 'FULL', boldFont, color: color),
                        _tableCell(r.displayNote ?? '--', font, color: color),
                        _tableCell(r.amount.toStringAsFixed(2), boldFont, color: color),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Paid in Period: ', style: pw.TextStyle(font: boldFont)),
                      pw.Text('GHS ${totalPaid.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColors.green)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Center(
                child: pw.Text('Verified by Multi-Business Management System', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Salary_History_${user.firstName}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      debugPrint('History Report Printing Error: $e');
    }
  }

  static Future<void> printPayslip(UserAccount user, double amount, bool isAdvance, {String? note, DateTime? targetMonth}) async {
    try {
      final isExternal = user.id == 'EXTERNAL';
      final doc = pw.Document();
      
      final fonts = await _loadFonts();
      final font = fonts['font']!;
      final boldFont = fonts['boldFont']!;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('MULTI-BUSINESS MANAGER', style: pw.TextStyle(font: boldFont, fontSize: 14)),
                      pw.Text(isExternal ? 'EXTERNAL PAYSLIP' : 'STAFF PAYSLIP', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Divider(),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                _payslipRow(isExternal ? 'Worker Name:' : 'Staff Name:', user.name, font, boldFont),
                if (!isExternal)
                  _payslipRow('Staff ID:', user.id.substring(user.id.length - 8).toUpperCase(), font, boldFont),
                if (isExternal && user.phone != null)
                  _payslipRow('Phone:', user.phone!, font, boldFont),
                if (isExternal && user.email.isNotEmpty)
                  _payslipRow('Email:', user.email, font, boldFont),
                _payslipRow('Role:', isExternal ? 'EXTERNAL WORKER' : user.role.name.toUpperCase(), font, boldFont),
                _payslipRow('Date Paid:', DateFormat('yyyy-MM-dd').format(DateTime.now()), font, boldFont),
                if (targetMonth != null)
                  _payslipRow('For Month:', DateFormat('MMMM yyyy').format(targetMonth), font, boldFont),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PAYMENT TYPE:', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text(
                      isAdvance ? 'ADVANCE' : (isExternal ? 'WORK PAYMENT' : 'FULL SALARY'), 
                      style: pw.TextStyle(font: boldFont, fontSize: 9, color: isAdvance ? PdfColors.red : PdfColors.black)
                    ),
                  ],
                ),
                if (note != null && note.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text('NOTE:', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                  pw.Text(note, style: pw.TextStyle(font: font, fontSize: 8)),
                ],
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('AMOUNT PAID:', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                    pw.Text(
                      'GHS ${amount.toStringAsFixed(2)}', 
                      style: pw.TextStyle(font: boldFont, fontSize: 12, color: isAdvance ? PdfColors.red : PdfColors.green)
                    ),
                  ],
                ),
                if (!isAdvance && !isExternal && user.salaryAmount != null)
                   _payslipRow('Base Salary:', 'GHS ${user.salaryAmount!.toStringAsFixed(2)}', font, boldFont, fontSize: 8),
                
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('Verified by System', style: pw.TextStyle(font: font, fontSize: 7, fontStyle: pw.FontStyle.italic)),
                      pw.SizedBox(height: 5),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'PAYSLIP:\nEmployee: ${user.name}\nID: ${user.id}\nAmount: GHS ${amount.toStringAsFixed(2)}\nType: ${isAdvance ? "ADVANCE" : "FULL"}\nDate: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                        width: 40,
                        height: 40,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Payslip_${user.firstName}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      debugPrint('Payslip Printing Error: $e');
    }
  }

  static pw.Widget _payslipRow(String label, String value, pw.Font font, pw.Font boldFont, {double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: fontSize)),
          pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: fontSize)),
        ],
      ),
    );
  }

  /// Generate printable 80mm thermal shift handover slip / Z-Report
  static Future<pw.Document> generateShiftHandoverDocument(ShiftRecord shift) async {
    final doc = pw.Document();
    final fonts = await _loadFonts();
    final font = fonts['font']!;
    final boldFont = fonts['boldFont']!;

    final double expectedCash = shift.openingFloat + shift.expectedCashSales;
    final double actualCash = shift.actualCashCounted ?? 0.0;
    final double variance = shift.cashVariance ?? (actualCash - expectedCash);

    PdfColor varianceBgColor = PdfColors.green50;
    PdfColor varianceTextColor = PdfColors.green900;
    String varianceTitle = 'BALANCED (₵0.00)';

    if (variance > 0.01) {
      varianceBgColor = PdfColors.blue50;
      varianceTextColor = PdfColors.blue900;
      varianceTitle = 'CASH SURPLUS (+₵${variance.toStringAsFixed(2)})';
    } else if (variance < -0.01) {
      varianceBgColor = PdfColors.red50;
      varianceTextColor = PdfColors.red900;
      varianceTitle = 'CASH SHORTAGE (-₵${variance.abs().toStringAsFixed(2)})';
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('CONTAINER STORES', style: pw.TextStyle(font: boldFont, fontSize: 15)),
                    pw.Text('SHIFT HANDOVER & TILL REPORT', style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.grey700)),
                    pw.Text('END-OF-DAY RECONCILIATION', style: pw.TextStyle(font: font, fontSize: 7)),
                    pw.SizedBox(height: 6),
                  ],
                ),
              ),
              pw.Divider(thickness: 0.5),
              _summaryRow('Shift Ref:', shift.id, font, boldFont),
              _summaryRow('Branch:', shift.branchCode, font, boldFont),
              _summaryRow('Cashier:', shift.cashierName, font, boldFont),
              _summaryRow('Started:', DateFormat('dd-MM-yyyy HH:mm').format(shift.startTime), font, boldFont),
              if (shift.endTime != null)
                _summaryRow('Ended:', DateFormat('dd-MM-yyyy HH:mm').format(shift.endTime!), font, boldFont),
              pw.Divider(thickness: 0.5),

              pw.Text('SALES REVENUE SUMMARY', style: pw.TextStyle(font: boldFont, fontSize: 8)),
              pw.SizedBox(height: 3),
              _summaryRow('Opening Float:', '₵ ${shift.openingFloat.toStringAsFixed(2)}', font, font),
              _summaryRow('Cash Sales Taken:', '₵ ${shift.expectedCashSales.toStringAsFixed(2)}', font, font),
              _summaryRow('MoMo Sales Taken:', '₵ ${shift.momoSales.toStringAsFixed(2)}', font, font),
              _summaryRow('Card / Bank Sales:', '₵ ${shift.cardSales.toStringAsFixed(2)}', font, font),
              pw.Divider(thickness: 0.5),
              _summaryRow('TOTAL TURNOVER:', '₵ ${shift.totalSales.toStringAsFixed(2)}', font, boldFont, isLarge: true),
              pw.Divider(thickness: 0.5),

              pw.Text('DRAWER CASH RECONCILIATION', style: pw.TextStyle(font: boldFont, fontSize: 8)),
              pw.SizedBox(height: 3),
              _summaryRow('Expected Cash in Till:', '₵ ${expectedCash.toStringAsFixed(2)}', font, boldFont),
              _summaryRow('Actual Cash Counted:', '₵ ${actualCash.toStringAsFixed(2)}', font, boldFont),
              pw.SizedBox(height: 4),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: pw.BoxDecoration(
                  color: varianceBgColor,
                  border: pw.Border.all(color: varianceTextColor, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'VARIANCE: $varianceTitle',
                    style: pw.TextStyle(font: boldFont, fontSize: 8, color: varianceTextColor),
                  ),
                ),
              ),

              if (shift.notes != null && shift.notes!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text('Notes / Discrepancy Reason:', style: pw.TextStyle(font: boldFont, fontSize: 7)),
                pw.Text(shift.notes!.trim(), style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey800)),
              ],

              pw.SizedBox(height: 14),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('__________________', style: pw.TextStyle(font: font, fontSize: 7)),
                      pw.Text('Cashier Signature', style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('__________________', style: pw.TextStyle(font: font, fontSize: 7)),
                      pw.Text('Manager / Auditor', style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'SHIFT:${shift.id}|Cashier:${shift.cashierName}|Actual:${actualCash.toStringAsFixed(2)}|Expected:${expectedCash.toStringAsFixed(2)}|Variance:${variance.toStringAsFixed(2)}',
                  width: 36,
                  height: 36,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('Verified by Multi-Business POS System', style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  static pw.Widget _summaryRow(String label, String value, pw.Font font, pw.Font boldFont, {bool isLarge = false}) {
    final double size = isLarge ? 8.5 : 7.5;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: size)),
          pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: size)),
        ],
      ),
    );
  }

  /// Print Shift Handover Z-Report to thermal printer or system dialog
  static Future<bool> printShiftHandoverReport(ShiftRecord shift, {BuildContext? context}) async {
    try {
      final doc = await generateShiftHandoverDocument(shift);
      final result = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Shift_Handover_${shift.id}',
      );
      return result;
    } catch (e) {
      debugPrint('Shift Handover Printing Error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Printing shift slip failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Share Shift Handover Report to Manager / Admin via WhatsApp
  static Future<void> shareShiftHandoverViaWhatsApp(
    ShiftRecord shift, {
    BuildContext? context,
    String? overridePhone,
  }) async {
    try {
      final double expectedCash = shift.openingFloat + shift.expectedCashSales;
      final double actualCash = shift.actualCashCounted ?? 0.0;
      final double variance = shift.cashVariance ?? (actualCash - expectedCash);

      String varianceEmoji = '✅';
      String varianceText = 'Balanced (GHS 0.00)';
      if (variance > 0.01) {
        varianceEmoji = '📈';
        varianceText = 'Surplus (+GHS ${variance.toStringAsFixed(2)})';
      } else if (variance < -0.01) {
        varianceEmoji = '⚠️';
        varianceText = 'SHORTAGE (-GHS ${variance.abs().toStringAsFixed(2)})';
      }

      final String notesText = (shift.notes != null && shift.notes!.trim().isNotEmpty)
          ? '\n📝 *Notes:* ${shift.notes!.trim()}\n'
          : '';

      final String message = '''
*SHIFT HANDOVER & TILL REPORT*
🏢 *Container Stores* (Branch: ${shift.branchCode})
👤 *Cashier:* ${shift.cashierName}
🆔 *Shift:* ${shift.id}
⏱️ *Time:* ${DateFormat('dd MMM, hh:mm a').format(shift.startTime)} – ${shift.endTime != null ? DateFormat('hh:mm a').format(shift.endTime!) : 'Now'}

💵 *Opening Float:* GHS ${shift.openingFloat.toStringAsFixed(2)}
🛒 *Cash Sales:* GHS ${shift.expectedCashSales.toStringAsFixed(2)}
📲 *MoMo Sales:* GHS ${shift.momoSales.toStringAsFixed(2)}
💳 *Card/Bank:* GHS ${shift.cardSales.toStringAsFixed(2)}
📊 *Total Sales:* GHS ${shift.totalSales.toStringAsFixed(2)}

--------------------------------
💰 *Expected Till Cash:* GHS ${expectedCash.toStringAsFixed(2)}
🪙 *Actual Cash Counted:* GHS ${actualCash.toStringAsFixed(2)}
$varianceEmoji *Variance:* $varianceText
--------------------------------$notesText
_Official Handover Audit Record_
'''.trim();

      final String targetPhone = overridePhone ?? '0209276200';
      String cleanPhone = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.startsWith('0')) cleanPhone = '233${cleanPhone.substring(1)}';
      final Uri url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('WhatsApp share shift error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share via WhatsApp: $e')),
        );
      }
    }
  }

  /// Generate printable 80mm thermal Barber Commission Pay Slip
  static Future<pw.Document> generateBarberCommissionDocument({
    required String barberName,
    String? barberPhone,
    required String period,
    required int totalServices,
    required double grossSales,
    required double commissionEarned,
    required double tips,
    required double deductions,
    required double netPayout,
    required String paymentMethod,
    String? notes,
  }) async {
    final doc = pw.Document();
    final fonts = await _loadFonts();
    final font = fonts['font']!;
    final boldFont = fonts['boldFont']!;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('CONTAINER BARBERSHOP', style: pw.TextStyle(font: boldFont, fontSize: 14)),
                    pw.Text('STYLIST COMMISSION PAY SLIP', style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.grey700)),
                    pw.Text('Executive Grooming & Styling Services', style: pw.TextStyle(font: font, fontSize: 7)),
                    pw.SizedBox(height: 6),
                  ],
                ),
              ),
              pw.Divider(thickness: 0.5),
              _summaryRow('Stylist Name:', barberName, font, boldFont),
              if (barberPhone != null && barberPhone.isNotEmpty)
                _summaryRow('Phone:', barberPhone, font, font),
              _summaryRow('Settlement Date:', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()), font, font),
              _summaryRow('Period:', period, font, boldFont),
              pw.Divider(thickness: 0.5),

              pw.Text('SERVICE PERFORMANCE BREAKDOWN', style: pw.TextStyle(font: boldFont, fontSize: 8)),
              pw.SizedBox(height: 3),
              _summaryRow('Completed Services:', '$totalServices Cuts/Services', font, boldFont),
              _summaryRow('Gross Billed Value:', '₵ ${grossSales.toStringAsFixed(2)}', font, font),
              _summaryRow('Commission Accrued:', '₵ ${commissionEarned.toStringAsFixed(2)}', font, boldFont),
              if (tips > 0)
                _summaryRow('Tips Collected:', '₵ ${tips.toStringAsFixed(2)}', font, boldFont),
              if (deductions > 0)
                _summaryRow('Deductions / Advances:', '-₵ ${deductions.toStringAsFixed(2)}', font, boldFont),
              pw.Divider(thickness: 0.5),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green800, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NET COMMISSION PAYOUT:', style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: PdfColors.green900)),
                    pw.Text('GHS ${netPayout.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 9.5, color: PdfColors.green900)),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),
              _summaryRow('Payment Mode:', paymentMethod.toUpperCase(), font, boldFont),

              if (notes != null && notes.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text('Notes:', style: pw.TextStyle(font: boldFont, fontSize: 7)),
                pw.Text(notes.trim(), style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey800)),
              ],

              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('__________________', style: pw.TextStyle(font: font, fontSize: 7)),
                      pw.Text('Stylist Signature', style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('__________________', style: pw.TextStyle(font: font, fontSize: 7)),
                      pw.Text('Manager Signature', style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'BARBER_PAYSLIP:$barberName|Net:${netPayout.toStringAsFixed(2)}|Date:${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                  width: 36,
                  height: 36,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('Verified by Multi-Business Barbershop System', style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  /// Print official Barber Commission Pay Slip
  static Future<bool> printBarberCommissionPaySlip({
    required String barberName,
    String? barberPhone,
    required String period,
    required int totalServices,
    required double grossSales,
    required double commissionEarned,
    required double tips,
    required double deductions,
    required double netPayout,
    required String paymentMethod,
    String? notes,
    BuildContext? context,
  }) async {
    try {
      final doc = await generateBarberCommissionDocument(
        barberName: barberName,
        barberPhone: barberPhone,
        period: period,
        totalServices: totalServices,
        grossSales: grossSales,
        commissionEarned: commissionEarned,
        tips: tips,
        deductions: deductions,
        netPayout: netPayout,
        paymentMethod: paymentMethod,
        notes: notes,
      );
      final result = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Barber_PaySlip_${barberName}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
      return result;
    } catch (e) {
      debugPrint('Barber Payslip Printing Error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Printing barber payslip failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Share official Barber Commission Pay Slip via WhatsApp
  static Future<void> shareBarberCommissionSlipViaWhatsApp({
    required String barberName,
    required String barberPhone,
    required String period,
    required int totalServices,
    required double grossSales,
    required double commissionEarned,
    required double tips,
    required double deductions,
    required double netPayout,
    required String paymentMethod,
    String? notes,
    BuildContext? context,
  }) async {
    try {
      final String tipsText = tips > 0 ? '\n🎁 *Tips Added:* GHS ${tips.toStringAsFixed(2)}' : '';
      final String deductionsText = deductions > 0 ? '\n🔻 *Deductions / Advance:* -GHS ${deductions.toStringAsFixed(2)}' : '';
      final String notesText = (notes != null && notes.trim().isNotEmpty) ? '\n📝 *Notes:* ${notes.trim()}\n' : '';

      final String message = '''
*BARBER COMMISSION PAY SLIP*
💈 *Container Barbershop*
👤 *Stylist:* $barberName
📅 *Settlement Date:* ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}
⏱️ *Period:* $period

✂️ *Services Completed:* $totalServices
💵 *Gross Sales Generated:* GHS ${grossSales.toStringAsFixed(2)}
💰 *Commission Earned:* GHS ${commissionEarned.toStringAsFixed(2)}$tipsText$deductionsText

================================
✅ *NET PAYOUT:* GHS ${netPayout.toStringAsFixed(2)}
💳 *Payment Mode:* ${paymentMethod.toUpperCase()}
================================$notesText
_Thank you for your hard work and excellence at Container Barbershop!_
'''.trim();

      if (barberPhone.trim().isEmpty) {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No phone number provided for WhatsApp share.')),
          );
        }
        return;
      }

      String cleanPhone = barberPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.startsWith('0')) cleanPhone = '233${cleanPhone.substring(1)}';
      final Uri url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('WhatsApp share barber payslip error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share via WhatsApp: $e')),
        );
      }
    }
  }
}


