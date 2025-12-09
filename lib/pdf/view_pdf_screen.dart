import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class ViewPDFScreen extends StatelessWidget {
  final File pdfFile;

  const ViewPDFScreen({required this.pdfFile, super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PdfController(
      document: PdfDocument.openFile(pdfFile.path),
    );

    return Scaffold(
      appBar: AppBar(title: Text("Monthly Report")),
      body: PdfView(
        controller: controller,
      ),
    );
  }
}
