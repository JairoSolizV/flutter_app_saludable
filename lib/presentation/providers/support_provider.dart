import 'package:flutter/foundation.dart';
import 'package:flutter_app_saludable/core/auth/session_state_resetter.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/errors/error_mapper.dart';
import '../../../domain/entities/support_ticket.dart';
import '../../data/datasources/remote/support_remote_data_source.dart';

class SupportProvider extends ChangeNotifier implements SessionScopedState {
  final SupportRemoteDataSource _remoteDataSource;

  List<SupportTicket> _tickets = [];
  bool _isLoading = false;
  String? _error;

  List<SupportTicket> get tickets => _tickets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SupportProvider(this._remoteDataSource);

  @override
  Future<void> clearSessionState() async {
    _tickets = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> fetchMyTickets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tickets = await _remoteDataSource.getMyTickets();
      _tickets.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    } catch (e) {
      if (shouldPresentErrorToUser(e)) {
        _error = ErrorMapper.publicMessage(e);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTicket(
    String tipoSolicitud,
    String asunto,
    String mensaje,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _remoteDataSource.createTicket(
        tipoSolicitud: tipoSolicitud,
        asunto: asunto,
        mensaje: mensaje,
      );

      await fetchMyTickets();
      return true;
    } catch (e) {
      if (shouldPresentErrorToUser(e)) {
        _error = ErrorMapper.publicMessage(e);
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
