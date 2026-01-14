import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart'; // Import DataSource
import '../../../main.dart'; // Acceso a global clubRemoteDataSource (temporal, idealmente Provider)


class GuestMapScreen extends StatefulWidget {
  const GuestMapScreen({super.key});

  @override
  State<GuestMapScreen> createState() => _GuestMapScreenState();
}

class _GuestMapScreenState extends State<GuestMapScreen> {
  // Centro inicial ajustado a uno de los clubes (Santa Cruz)
  final LatLng _initialCenter = const LatLng(-17.78122028, -63.17921747); 
  List<Club> _clubs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    try {
      final clubs = await clubRemoteDataSource.getClubes();
      if (mounted) {
        setState(() {
          _clubs = clubs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al cargar clubes: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubes Cercanos'),
        backgroundColor: const Color(0xFF7AC142),
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _initialCenter,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.flutter_app_saludable',
          ),
          MarkerLayer(
            markers: _clubs.map((club) {
              return Marker(
                point: LatLng(club.lat, club.lng),
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () {
                    _showClubInfo(context, club);
                  },
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFF7AC142), // Usar color de marca
                    size: 45,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showClubInfo(BuildContext context, Club club) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 250, // Un poco mas alto para la info extra
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                club.nombreClub,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 4),
              Text(
                "Anfitrión: ${club.anfitrionNombre}",
                style: const TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                   const Icon(LucideIcons.mapPin, color: Color(0xFF7AC142), size: 18),
                   const SizedBox(width: 8),
                   Expanded(child: Text(club.direccion, style: const TextStyle(color: Colors.black87))),
                ],
              ),
              const SizedBox(height: 8),
               Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Icon(LucideIcons.clock, color: Colors.grey, size: 18),
                   const SizedBox(width: 8),
                   Expanded(child: Text(club.horario, style: const TextStyle(color: Colors.grey, fontSize: 12))),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Futuro: Ir a detalle del club
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7AC142),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ver Detalles'),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
