import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// An order's invoice, in the app (owner, 29 Sep 2026: it used to open the
/// website in the browser). The PDF is the website's own -- fetched from its
/// signed link, which needs no session -- shown here to pinch and scroll,
/// with Download to save it where the customer chooses (Downloads, Drive...)
/// through the phone's own save dialog, so no storage permission is asked.
class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key, required this.number});
  final String number;

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  String? _path;
  PdfControllerPinch? _pdf;
  Object? _error;
  bool _saving = false;

  String get _fileName => 'Invoice-${widget.number}.pdf';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final url = await ref.read(apiProvider).invoiceUrl(widget.number);
      final file = File('${(await getTemporaryDirectory()).path}/$_fileName');
      await Dio().download(url, file.path, options: Options(receiveTimeout: const Duration(seconds: 60)));
      if (!mounted) return;
      setState(() {
        _path = file.path;
        _pdf = PdfControllerPinch(document: PdfDocument.openFile(file.path));
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _download() async {
    if (_path == null || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(sourceFilePath: _path, fileName: _fileName, mimeTypesFilter: const ['application/pdf']),
      );
      if (saved != null && mounted) showMessage(context, 'Invoice saved.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Invoice ${widget.number}'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Brand.blue, minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: _path == null || _saving ? null : _download,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 20),
                label: const Text('Download'),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE5E7EB),
        body: _error != null
            ? ErrorView(error: _error!, onRetry: _load)
            : _pdf == null
                ? const LoadingView()
                : PdfViewPinch(
                    controller: _pdf!,
                    builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                      options: const DefaultBuilderOptions(),
                      documentLoaderBuilder: (_) => const LoadingView(),
                      pageLoaderBuilder: (_) => const LoadingView(),
                      errorBuilder: (_, e) => ErrorView(error: e, onRetry: _load),
                    ),
                  ),
      );
}
