import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class ViewPDFScreen2 extends StatefulWidget {
  final File pdfFile;

  const ViewPDFScreen2({required this.pdfFile, super.key});

  @override
  State<ViewPDFScreen2> createState() => ViewPDFScreen2State();
}

class ViewPDFScreen2State extends State<ViewPDFScreen2> {
  late PdfControllerPinch _pdfController;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.pdfFile.path),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report")),
      body: PdfViewPinch(
        controller: _pdfController,
      ),
    );
  }
}
