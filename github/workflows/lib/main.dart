import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:super_clipboard/super_clipboard.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const CalligraphyClipboardApp());
}

class CalligraphyClipboardApp extends StatelessWidget {
  const CalligraphyClipboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'خطاطی کلپ بورڈ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const CalligraphyHomeScreen(),
    );
  }
}

class CalligraphyHomeScreen extends StatefulWidget {
  const CalligraphyHomeScreen({super.key});

  @override
  State<CalligraphyHomeScreen> createState() => _CalligraphyHomeScreenState();
}

class _CalligraphyHomeScreenState extends State<CalligraphyHomeScreen> {
  final TextEditingController _textController = TextEditingController(
    text: 'رکن الدین بیبرس',
  );
  final GlobalKey _textCaptureKey = GlobalKey();

  double _fontSize = 48.0;
  Uint8List? _processedImageBytes;
  bool _isProcessing = false;

  // گیلری سے تصویر لے کر اس کا سفید بیک گراؤنڈ شفاف (Transparent) بنانا
  Future<void> _pickAndRemoveWhiteBg() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final rawBytes = await pickedFile.readAsBytes();
      img.Image? decoded = img.decodeImage(rawBytes);

      if (decoded != null) {
        decoded = img.Image.from(decoded, numChannels: 4);

        for (int y = 0; y < decoded.height; y++) {
          for (int x = 0; x < decoded.width; x++) {
            final pixel = decoded.getPixel(x, y);
            final r = pixel.r;
            final g = pixel.g;
            final b = pixel.b;

            if (r > 235 && g > 235 && b > 235) {
              decoded.setPixelRgba(x, y, r, g, b, 0);
            }
          }
        }

        final pngBytes = Uint8List.fromList(img.encodePng(decoded));
        setState(() {
          _processedImageBytes = pngBytes;
        });
        _showMessage('تصویر کا بیک گراؤنڈ شفاف کر دیا گیا ہے');
      }
    } catch (e) {
      _showMessage('تصویر پروسیس کرنے میں مسئلہ آیا: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ٹیکسٹ کو شفاف PNG تصویر میں بدلنا
  Future<Uint8List?> _captureTextAsPng() async {
    try {
      final boundary =
          _textCaptureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      _showMessage('ٹیکسٹ کو تصویر میں بدلنے میں مسئلہ آیا: $e');
      return null;
    }
  }

  // تصویر کو اصل سائز (PNG) میں کلپ بورڈ پر کاپی کرنا
  Future<void> _copyImageToClipboard() async {
    setState(() => _isProcessing = true);
    try {
      Uint8List? bytes = _processedImageBytes;
      bytes ??= await _captureTextAsPng();

      if (bytes == null) {
        _showMessage('کاپی کرنے کے لیے کوئی تصویر یا متن موجود نہیں ہے');
        return;
      }

      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        _showMessage('اس ڈیوائس پر کلپ بورڈ دستیاب نہیں ہے');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/calligraphy_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      final item = DataWriterItem();
      item.add(Formats.png(bytes));

      await clipboard.write([item]);
      _showMessage('تصویر اصل سائز میں کلپ بورڈ پر کاپی ہو گئی ہے! اب پیسٹ کریں');
    } catch (e) {
      _showMessage('کاپی کرتے وقت مسئلہ آیا: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textDirection: TextDirection.rtl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        appBar: AppBar(
          title: const Text('خطاطی و تصویر کلپ بورڈ'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _textController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'یہاں عربی یا اردو متن لکھیں',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Text('سائز: '),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 24,
                      max: 110,
                      onChanged: (val) => setState(() => _fontSize = val),
                    ),
                  ),
                  Text(_fontSize.toInt().toString()),
                ],
              ),

              const SizedBox(height: 10),

              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : _processedImageBytes != null
                        ? Image.memory(
                            _processedImageBytes!,
                            fit: BoxFit.contain,
                          )
                        : RepaintBoundary(
                            key: _textCaptureKey,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _textController.text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: _fontSize,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _pickAndRemoveWhiteBg,
                icon: const Icon(Icons.image),
                label: const Text('گیلری سے تصویر لیں (سفید بیک گراؤنڈ ہٹائیں)'),
              ),

              const SizedBox(height: 10),

              if (_processedImageBytes != null)
                TextButton(
                  onPressed: () => setState(() => _processedImageBytes = null),
                  child: const Text('ٹیکسٹ موڈ پر واپس جائیں'),
                ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isProcessing ? null : _copyImageToClipboard,
                icon: const Icon(Icons.copy),
                label: const Text('تصویر اصل سائز میں کلپ بورڈ پر کاپی کریں'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
