import 'package:flutter/foundation.dart';
import '../../../domain/entities/support_ticket.dart';
import '../../data/datasources/remote/support_remote_data_source.dart';
import '../../data/repositories/local_user_repository.dart';

class SupportProvider extends ChangeNotifier {
  final SupportRemoteDataSource _remoteDataSource;
  final LocalUserRepository _localUserRepository;

  List<SupportTicket> _tickets = [];
  bool _isLoading = false;
  String? _error;

  List<SupportTicket> get tickets => _tickets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SupportProvider(this._remoteDataSource, this._localUserRepository);

  Future<void> fetchMyTickets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _localUserRepository.getCurrentUser();
      
      if (user != null) {
        _tickets = await _remoteDataSource.getTicketsByUser(int.parse(user.id));
        // Ordenar del más reciente al más antiguo
        _tickets.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
      } else {
        _error = 'No hay usuario autenticado logueado actualmente.';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTicket(String tipoSolicitud, String asunto, String mensaje) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _remoteDataSource.createTicket(
        tipoSolicitud: tipoSolicitud,
        asunto: asunto,
        mensaje: mensaje,
      );
      
      // Regargar después de crear
      await fetchMyTickets();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
