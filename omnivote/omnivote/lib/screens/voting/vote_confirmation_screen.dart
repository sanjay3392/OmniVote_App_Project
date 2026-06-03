import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_flutter/qr_flutter.dart';

// PDF generation
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../services/blockchain_service.dart';
import '../../services/storage_service.dart';

class VoteConfirmationScreen extends StatefulWidget {
  final Vote vote;
  final Election election;
  final Candidate candidate;

  const VoteConfirmationScreen({
    super.key,
    required this.vote,
    required this.election,
    required this.candidate,
  });

  @override
  State<VoteConfirmationScreen> createState() => _VoteConfirmationScreenState();
}

class _VoteConfirmationScreenState extends State<VoteConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _confirmationBlocks = 0;
  bool _isVerifying = true;
  bool _isGeneratingPdf = false;

  final BlockchainService _blockchainService = BlockchainService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _verifyTransaction();
    _saveVoteToHistory();
  }

  Future<void> _verifyTransaction() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final confirmations = await _blockchainService.getConfirmationBlocks(
      widget.vote.transactionHash,
    );
    setState(() {
      _confirmationBlocks = confirmations;
      _isVerifying = false;
    });
  }

  Future<void> _saveVoteToHistory() async {
    final storageService = await StorageService.init();
    await storageService.addToVoteHistory(widget.vote.id);
  }

  void _copyTransactionHash() {
    Clipboard.setData(ClipboardData(text: widget.vote.transactionHash));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Transaction hash copied'),
      ]),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─────────────────────────────────────────────────────────
  // PDF GENERATION
  // Uses the `pdf` package to build a receipt document,
  // then `printing` to share/download it on any platform:
  //   Android → Share sheet (WhatsApp, Drive, etc.) or Save to Downloads
  //   iOS     → Share sheet or Save to Files
  //   Web     → Opens print dialog / browser PDF download
  // ─────────────────────────────────────────────────────────
  Future<void> _downloadPdfReceipt() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await _buildPdf();

      // `Printing.sharePdf` works on Android, iOS and Web:
      //   • Android/iOS → native share sheet (save, share, print)
      //   • Web         → opens browser's print/download dialog
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
        'OmniVote_Receipt_${widget.vote.id.substring(0, 8)}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to generate PDF: ${e.toString()}'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document(
      title: 'OmniVote Vote Receipt',
      author: 'OmniVote',
      subject: 'Blockchain Vote Receipt',
    );

    // ── colours ──
    const primary   = PdfColor.fromInt(0xFF6C63FF);
    const success   = PdfColor.fromInt(0xFF00D4AA);
    const bgLight   = PdfColor.fromInt(0xFFF1F3FA);
    const bgCard    = PdfColor.fromInt(0xFFFFFFFF);
    const textDark  = PdfColor.fromInt(0xFF1A1A3E);
    const textGrey  = PdfColor.fromInt(0xFF8890B0);
    const border    = PdfColor.fromInt(0xFFE0E3F0);
    const divider   = PdfColor.fromInt(0xFFEEF0FA);

    // ── QR code image from qr_flutter ──
    final qrImage = await _generateQrImage(widget.vote.transactionHash);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (pw.Context ctx) {
        return pw.Stack(children: [

          // background
          pw.Container(
            width: double.infinity,
            height: double.infinity,
            color: bgLight,
          ),

          // ── header banner ──────────────────────────────
          pw.Positioned(
            top: 0, left: 0, right: 0,
            child: pw.Container(
              height: 110,
              decoration: const pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [
                    PdfColor.fromInt(0xFF3F3BC2),
                    PdfColor.fromInt(0xFF6C63FF),
                    PdfColor.fromInt(0xFF9188FF),
                  ],
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                ),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(36, 22, 36, 0),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // icon circle
                    pw.Container(
                      width: 44, height: 44,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white.shade(0.2),
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(
                            color: PdfColors.white, width: 1.5),
                      ),
                      child: pw.Center(
                        child: pw.Text('✓',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                            )),
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text('OmniVote',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.5,
                            )),
                        pw.SizedBox(height: 3),
                        pw.Text('Official Vote Receipt',
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 11,
                            )),
                      ],
                    ),
                    pw.Spacer(),
                    // receipt number
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text('RECEIPT',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.5,
                            )),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          '#${widget.vote.id.substring(0, 8).toUpperCase()}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            font: pw.Font.courier(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── main content ───────────────────────────────
          pw.Positioned(
            top: 120,
            left: 24,
            right: 24,
            bottom: 24,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                // ── confirmed badge ──
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: success.shade(0.12),
                      borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(99)),
                      border: pw.Border.all(color: success, width: 1),
                    ),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 8, height: 8,
                          decoration: const pw.BoxDecoration(
                            color: success,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text('Vote Successfully Recorded on Blockchain',
                            style: pw.TextStyle(
                              color: success,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            )),
                      ],
                    ),
                  ),
                ),

                pw.SizedBox(height: 16),

                // ── two-column layout ──
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [

                    // LEFT COLUMN
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [

                          // Vote Details card
                          _pdfCard(
                            title: 'Vote Details',
                            borderColor: primary,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _pdfRow('Election',
                                    widget.election.title, textDark, textGrey),
                                _pdfDivider(),
                                _pdfRow('Organisation',
                                    widget.election.organizationName,
                                    textDark, textGrey),
                                _pdfDivider(),
                                _pdfRow('Voted On',
                                    _formatDate(widget.vote.timestamp),
                                    textDark, textGrey),
                                _pdfDivider(),
                                _pdfRow('Status', 'Confirmed ✓',
                                    success, textGrey),
                                _pdfDivider(),
                                // All candidates (vote secrecy — no voted candidate shown)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
                                  child: pw.Text('Candidates',
                                      style: pw.TextStyle(fontSize: 8, color: textGrey,
                                          fontWeight: pw.FontWeight.bold)),
                                ),
                                ...widget.election.candidates.map((c) =>
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                      child: pw.Row(
                                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text(c.name,
                                              style: pw.TextStyle(fontSize: 9, color: textDark,
                                                  fontWeight: pw.FontWeight.bold)),
                                          if (c.party != null)
                                            pw.Text(c.party!,
                                                style: pw.TextStyle(fontSize: 9, color: textGrey)),
                                        ],
                                      ),
                                    ),
                                ).toList(),
                              ],
                            ),
                          ),

                          pw.SizedBox(height: 12),

                          // Blockchain Receipt card
                          _pdfCard(
                            title: 'Blockchain Receipt',
                            borderColor: const PdfColor.fromInt(0xFF3498DB),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _pdfRow('Network', 'Solana Mainnet',
                                    textDark, textGrey),
                                _pdfDivider(),
                                _pdfRow('Confirmations',
                                    '$_confirmationBlocks blocks',
                                    textDark, textGrey),
                                _pdfDivider(),
                                pw.Column(
                                  crossAxisAlignment:
                                  pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Transaction Hash',
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          color: textGrey,
                                          fontWeight: pw.FontWeight.bold,
                                        )),
                                    pw.SizedBox(height: 4),
                                    pw.Container(
                                      width: double.infinity,
                                      padding: const pw.EdgeInsets.all(7),
                                      decoration: pw.BoxDecoration(
                                        color: const PdfColor.fromInt(
                                            0xFFF0F2FF),
                                        borderRadius:
                                        const pw.BorderRadius.all(
                                            pw.Radius.circular(5)),
                                        border: pw.Border.all(
                                            color: primary.shade(0.3),
                                            width: 0.5),
                                      ),
                                      child: pw.Text(
                                        widget.vote.transactionHash,
                                        style: pw.TextStyle(
                                          font: pw.Font.courier(),
                                          fontSize: 7,
                                          color: primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(width: 12),

                    // RIGHT COLUMN — QR code
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(children: [
                        _pdfCard(
                          title: 'Scan to Verify',
                          borderColor:
                          const PdfColor.fromInt(0xFF00D4AA),
                          child: pw.Column(
                            children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                decoration: const pw.BoxDecoration(
                                  color: PdfColors.white,
                                ),
                                child: pw.Image(
                                  pw.MemoryImage(qrImage),
                                  width: 130,
                                  height: 130,
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text(
                                'Scan this QR code to\nverify your vote on\nthe blockchain',
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: textGrey,
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: success.shade(0.10),
                                  borderRadius: const pw.BorderRadius.all(
                                      pw.Radius.circular(4)),
                                ),
                                child: pw.Text('Blockchain Verified',
                                    style: pw.TextStyle(
                                      fontSize: 8,
                                      color: success,
                                      fontWeight: pw.FontWeight.bold,
                                    )),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),

                pw.Spacer(),

                // ── footer ──────────────────────────────
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFF1A1A3E),
                    borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'OmniVote — Secure, Transparent Democracy',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8,
                        ),
                      ),
                      pw.Text(
                        'Generated: ${_formatDate(DateTime.now())}',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]);
      },
    ));

    return doc.save();
  }

  // ── build QR code as PNG bytes using qr_flutter ──────────
  Future<Uint8List> _generateQrImage(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      color: const Color(0xFF1A1A3E),
      emptyColor: Colors.white,
    );
    final image = await qrPainter.toImageData(300);
    return image!.buffer.asUint8List();
  }

  // ── PDF helper widgets ────────────────────────────────────
  pw.Widget _pdfCard({
    required String title,
    required PdfColor borderColor,
    required pw.Widget child,
  }) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        // borderRadius cannot be combined with non-uniform Border in pdf package
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE0E3F0)),
      ),
      // Simulate left accent by placing a colored strip inside
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 0, top: 0, bottom: 0,
            child: pw.Container(width: 3, color: borderColor),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.only(left: 3),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // card header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: pw.BoxDecoration(
                    color: borderColor.shade(0.07),
                  ),
                  child: pw.Text(title,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: borderColor,
                      )),
                ),
                // card body
                pw.Padding(
                  padding: const pw.EdgeInsets.all(10),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfRow(
      String label, String value, PdfColor valueColor, PdfColor labelColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(label,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: labelColor,
                  fontWeight: pw.FontWeight.bold,
                )),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: valueColor,
                  fontWeight: pw.FontWeight.bold,
                )),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfDivider() => pw.Container(
    height: 0.5,
    color: const PdfColor.fromInt(0xFFEEF0FA),
    margin: const pw.EdgeInsets.symmetric(vertical: 2),
  );

  String _formatDate(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  '
        '${dt.hour.toString().padLeft(2,'0')}:'
        '${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // UI BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3FA),
      appBar: AppBar(
        backgroundColor: AppColors.success,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: const Text('Vote Confirmed',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          FadeInDown(child: _buildSuccessAnimation()),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: Text(AppStrings.voteSuccess,
                style: AppTextStyles.h2, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: Text(
              'Your vote has been securely recorded on the blockchain',
              style: AppTextStyles.bodyLarge
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          FadeInUp(
            delay: const Duration(milliseconds: 700),
            child: _buildVoteDetails(),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 900),
            child: _buildTransactionDetails(),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 1100),
            child: _buildQRCode(),
          ),
          const SizedBox(height: 28),
          FadeInUp(
            delay: const Duration(milliseconds: 1300),
            child: _buildActionButtons(),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return Container(
      width: 110, height: 110,
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ScaleTransition(
        scale: CurvedAnimation(
            parent: _controller, curve: Curves.elasticOut),
        child: const Icon(Icons.check_circle_rounded,
            size: 72, color: Colors.white),
      ),
    );
  }

  Widget _buildVoteDetails() {
    return _Card(
      icon: Icons.how_to_vote_rounded,
      title: 'Vote Details',
      child: Column(children: [
        _DetailRow(label: 'Election', value: widget.election.title),
        const SizedBox(height: 12),
        _DetailRow(
            label: 'Voted at',
            value: widget.vote.timestamp.toString().split('.')[0]),
        const SizedBox(height: 16),
        // All candidates — vote secrecy preserved
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Candidates',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        ...widget.election.candidates.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(c.name,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              if (c.party != null)
                Text(c.party!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        )).toList(),
      ]),
    );
  }

  Widget _buildTransactionDetails() {
    return _Card(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Blockchain Receipt',
      child: Column(children: [
        _DetailRow(label: 'Network', value: 'Solana Mainnet'),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _copyTransactionHash,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border:
              Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transaction Hash',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.vote.transactionHash.substring(0, 24)}...',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
              ),
              const Icon(Icons.copy_rounded,
                  size: 16, color: AppColors.primary),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _DetailRow(
              label: 'Status',
              value: _isVerifying ? 'Verifying…' : 'Confirmed',
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isVerifying
                  ? AppColors.warning.withOpacity(0.10)
                  : AppColors.success.withOpacity(0.10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _isVerifying
                    ? Icons.hourglass_empty_rounded
                    : Icons.verified_rounded,
                size: 13,
                color: _isVerifying
                    ? AppColors.warning
                    : AppColors.success,
              ),
              const SizedBox(width: 4),
              Text(
                _isVerifying
                    ? 'Pending'
                    : '$_confirmationBlocks blocks',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _isVerifying
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _buildQRCode() {
    return _Card(
      icon: Icons.qr_code_rounded,
      title: 'Verification QR Code',
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: QrImageView(
            data: widget.vote.transactionHash,
            version: QrVersions.auto,
            size: 180,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text('Scan to verify your vote on the blockchain',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildActionButtons() {
    return Column(children: [
      // Return home
      SizedBox(
        width: double.infinity,
        height: AppDimensions.buttonHeightM,
        child: ElevatedButton.icon(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.home_rounded, color: Colors.white),
          label: const Text('Return to Home',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
        ),
      ),
      const SizedBox(height: 12),

      // Download PDF receipt
      SizedBox(
        width: double.infinity,
        height: AppDimensions.buttonHeightM,
        child: ElevatedButton.icon(
          onPressed: _isGeneratingPdf ? null : _downloadPdfReceipt,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A3E),
            disabledBackgroundColor: Colors.grey.shade300,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isGeneratingPdf
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf_rounded,
              color: Colors.white),
          label: Text(
            _isGeneratingPdf ? 'Generating PDF…' : 'Download PDF Receipt',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        kIsWeb
            ? 'PDF will open in your browser for download'
            : 'PDF will open for saving or sharing',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        textAlign: TextAlign.center,
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════
// REUSABLE UI WIDGETS
// ═══════════════════════════════════════════════
class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Card(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.055),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Text(title, style: AppTextStyles.h4.copyWith(fontSize: 15)),
        ]),
        const SizedBox(height: 14),
        Divider(color: Colors.grey.shade100, height: 1),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 90,
        child: Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
      ),
      Expanded(
        child: Text(value,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}