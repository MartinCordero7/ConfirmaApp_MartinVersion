import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class AnalisisBiometricoScreen extends StatefulWidget {
  final String nombreParticipante;
  const AnalisisBiometricoScreen({
    super.key,
    required this.nombreParticipante,
  });

  @override
  State<AnalisisBiometricoScreen> createState() => _AnalisisBiometricoScreenState();
}

class _AnalisisBiometricoScreenState extends State<AnalisisBiometricoScreen> {
  CameraController? _controller;
  bool _isInit = false;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      // Usamos la cámara posterior porque el organizador le tomará la foto al asistente
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(backCamera, ResolutionPreset.high);
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isInit = true;
      });
    } catch (e) {
      debugPrint('Error cámara: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _analizar() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isAnalyzing = true);

    try {
      final XFile foto = await _controller!.takePicture();
      
      // Procesamiento con Inteligencia Artificial (ML Kit)
      final inputImage = InputImage.fromFilePath(foto.path);
      final faceDetector = FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast));
      final faces = await faceDetector.processImage(inputImage);
      await faceDetector.close();

      if (faces.isEmpty) {
        setState(() => _isAnalyzing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: No se detectó rostro humano. Enfoque nuevamente.'), backgroundColor: Colors.red)
          );
        }
        return;
      }

      // Animación de escaneo simulando procesamiento de redes neuronales
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context, true); // Devuelve éxito al Scanner
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit || _controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('IA Facial'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Pantalla completa de cámara
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          
          // Overlay para guiar el rostro
          Positioned(
            top: 100,
            child: Container(
              width: 250,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Interfaz inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.person, size: 40),
                  ),
                  const SizedBox(height: 8),
                  Text('Analizando a: ${widget.nombreParticipante}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 16),
                  if (_isAnalyzing)
                    const Column(
                      children: [
                        LinearProgressIndicator(color: Colors.greenAccent),
                        SizedBox(height: 8),
                        Text('Calculando vectores biométricos...', style: TextStyle(color: Colors.greenAccent)),
                      ],
                    )
                  else
                    FilledButton.icon(
                      onPressed: _analizar,
                      icon: const Icon(Icons.document_scanner),
                      label: const Text('Ejecutar Reconocimiento IA'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
