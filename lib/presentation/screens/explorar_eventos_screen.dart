import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/event_repository.dart';
import '../../domain/repositories/enrollment_repository.dart';
import '../../domain/entities/evento.dart';
import '../viewmodels/login_viewmodel.dart';

class ExplorarEventosScreen extends StatefulWidget {
  const ExplorarEventosScreen({super.key});

  @override
  State<ExplorarEventosScreen> createState() => _ExplorarEventosScreenState();
}

class _ExplorarEventosScreenState extends State<ExplorarEventosScreen> {
  List<Evento> _eventos = [];
  Map<String, bool> _inscripcionesStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEventos();
  }

  Future<void> _loadEventos() async {
    final user = context.read<LoginViewModel>().currentUser;
    if (user == null) return;

    try {
      final eventos = await context.read<EventRepository>().getEventos();
      final enrollmentRepo = context.read<EnrollmentRepository>();
      
      Map<String, bool> statusMap = {};
      for (var e in eventos) {
        statusMap[e.id] = await enrollmentRepo.estaInscrito(e.id, user.id);
      }

      if (mounted) {
        setState(() {
          _eventos = eventos;
          _inscripcionesStatus = statusMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _inscribirse(Evento evento) async {
    try {
      final user = context.read<LoginViewModel>().currentUser;
      if (user == null) return;
      
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      
      await context.read<EnrollmentRepository>().inscribirParticipante(evento.id, user.id);
      
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      setState(() => _inscripcionesStatus[evento.id] = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Inscripción exitosa!'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explorar Eventos')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _eventos.length,
              itemBuilder: (context, index) {
                final evento = _eventos[index];
                final isEnrolled = _inscripcionesStatus[evento.id] ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(evento.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(evento.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '📍 ${evento.lugar}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '📅 ${evento.fecha.toString().substring(0, 10)} - ${evento.hora}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: isEnrolled ? null : () => _inscribirse(evento),
                              style: isEnrolled ? FilledButton.styleFrom(backgroundColor: Colors.grey) : null,
                              child: Text(isEnrolled ? 'Ya estás inscrito' : 'Inscribirse'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
