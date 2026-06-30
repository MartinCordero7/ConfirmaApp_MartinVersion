import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/evento.dart';
import '../../domain/entities/asistencia.dart';
import '../../domain/repositories/attendance_repository.dart';
import 'analisis_biometrico_screen.dart';
import 'face_validation_screen.dart';

class ScannerScreen extends StatefulWidget {
  final Evento evento;
  const ScannerScreen({super.key, required this.evento});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  Future<bool> _checkGPSRange() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      Position position = await Geolocator.getCurrentPosition();
      const Distance distance = Distance();
      double meters = distance.as(LengthUnit.Meter, LatLng(widget.evento.latitud, widget.evento.longitud), LatLng(position.latitude, position.longitude));
      return meters <= widget.evento.radioToleranciaMetros;
    } catch (e) {
      return false;
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final String? barcodeData = capture.barcodes.first.rawValue;
    if (barcodeData == null) {
      _isProcessing = false;
      return;
    }

    final userId = barcodeData;

    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(userId).get();
      if (!doc.exists) {
        _mostrarError('El código QR es inválido o el usuario no existe.');
        return;
      }
      
      final data = doc.data()!;
      final nombre = data['nombre'] ?? 'Desconocido';

      final inRange = await _checkGPSRange();
      if (!inRange) {
        _mostrarError('Fuera de rango: El participante debe estar a menos de 50 metros del evento.');
        return;
      }

      // 3. IA Facial (Prueba de Vida)
      if (mounted) {
        cameraController.stop(); // Pausar escáner de QR
        final validacionExitosa = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AnalisisBiometricoScreen(
            nombreParticipante: nombre,
          )),
        );

        if (validacionExitosa != true) {
          cameraController.start();
          _mostrarError('Cancelado: No se pudo verificar la identidad por IA.');
          return;
        }
        
        // 4. Verificación Visual Automática (Rostro detectado)
        _marcarAsistencia(userId);
        cameraController.start();
      }
    } catch (e) {
      _mostrarError('Error al procesar: $e');
    }
  }

  void _mostrarError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isProcessing = false);
      });
    }
  }

  Future<void> _marcarAsistencia(String userId) async {
    final repo = context.read<AttendanceRepository>();
    final asistencia = Asistencia(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventoId: widget.evento.id,
      participanteId: userId,
      fechaHora: DateTime.now(),
      ubicacionValida: true,
    );

    await repo.registrarAsistencia(asistencia);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Asistencia registrada exitosamente')));
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.evento.nombre)),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              _onDetect(capture);
            },
          ),
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(16)),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Validando Asistencia...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
