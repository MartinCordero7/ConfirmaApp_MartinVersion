import '../../domain/entities/evento.dart';
import '../../domain/repositories/event_repository.dart';

class MockEventRepository implements EventRepository {
  final List<Evento> _eventos = [
    Evento(
      id: 'evt_1',
      nombre: 'Congreso Internacional de Flutter',
      descripcion: 'El congreso anual para desarrolladores móviles con expertos mundiales.',
      hora: '09:00 AM',
      lugar: 'Auditorio Principal TEC',
      cupos: 200,
      latitud: -0.180653,
      longitud: -78.467834,
      radioToleranciaMetros: 100,
      fecha: DateTime.now().add(const Duration(days: 1)),
      nivelControl: NivelControl.estricto,
      organizadorId: 'org_1',
    ),
  ];

  @override
  Future<List<Evento>> getEventos() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _eventos;
  }

  @override
  Future<Evento?> getEventoById(String id) async {
    return _eventos.cast<Evento?>().firstWhere((e) => e?.id == id, orElse: () => null);
  }

  @override
  Future<void> crearEvento(Evento evento) async {
    _eventos.add(evento);
  }

  @override
  Future<void> editarEvento(Evento evento) async {
    final idx = _eventos.indexWhere((e) => e.id == evento.id);
    if (idx != -1) {
      _eventos[idx] = evento;
    }
  }

  @override
  Future<void> eliminarEvento(String id) async {
    _eventos.removeWhere((e) => e.id == id);
  }
}
