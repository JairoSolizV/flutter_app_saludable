import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/datasources/remote/club_remote_data_source.dart';
import '../../providers/user_provider.dart';
import '../../widgets/club_card.dart';
import 'package:go_router/go_router.dart';

class ClubSelectorScreen extends StatefulWidget {
  const ClubSelectorScreen({super.key});

  @override
  State<ClubSelectorScreen> createState() => _ClubSelectorScreenState();
}

class _ClubSelectorScreenState extends State<ClubSelectorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Club> _clubs = [];
  bool _loading = true;
  String? _error;
  Position? _userPosition;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClubs();
    _getUserLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _userPosition = position);
    } catch (e) {
      // Silently fail - location is optional
    }
  }

  Future<void> _loadClubs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;

      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Get user's membership to find hubId
      final clubDataSource = Provider.of<ClubRemoteDataSource>(context, listen: false);
      
      // For now, we'll use hubId = 1 (Santa Cruz). In production, get from user's membership
      final int hubId = 1; // TODO: Get from user's membership
      
      final clubs = await clubDataSource.getClubesByHub(hubId);
      
      setState(() {
        _clubs = clubs.where((c) => c.estado == 'ACTIVO').toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, LatLng(lat1, lon1), LatLng(lat2, lon2));
  }

  void _navigateToProducts(Club club) {
    // Navigate to products screen with clubId and clubNombre
    context.push('/member-orders/new/club-products', extra: {
      'clubId': club.id,
      'clubNombre': club.nombreClub,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Seleccionar Club', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7AC142),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(LucideIcons.map), text: 'Mapa'),
            Tab(icon: Icon(LucideIcons.list), text: 'Lista'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7AC142)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.alertCircle, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadClubs,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7AC142)),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _clubs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.store, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No hay clubes disponibles', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMapView(),
                        _buildListView(),
                      ],
                    ),
    );
  }

  Widget _buildMapView() {
    // Calculate center of all clubs or use user location
    LatLng center;
    if (_userPosition != null) {
      center = LatLng(_userPosition!.latitude, _userPosition!.longitude);
    } else if (_clubs.isNotEmpty) {
      center = LatLng(_clubs.first.lat, _clubs.first.lng);
    } else {
      center = const LatLng(-17.783327, -63.182140); // Santa Cruz default
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.flutter_app_saludable',
        ),
        MarkerLayer(
          markers: [
            // User location marker
            if (_userPosition != null)
              Marker(
                point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                width: 40,
                height: 40,
                child: const Icon(Icons.my_location, size: 40, color: Colors.blue),
              ),
            // Club markers
            ..._clubs.map((club) {
              return Marker(
                point: LatLng(club.lat, club.lng),
                width: 80,
                height: 80,
                child: GestureDetector(
                  onTap: () => _navigateToProducts(club),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Text(
                          club.nombreClub,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.location_pin, size: 40, color: Color(0xFFFF6B00)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildListView() {
    // Sort clubs by distance if user location is available
    List<Club> sortedClubs = List.from(_clubs);
    if (_userPosition != null) {
      sortedClubs.sort((a, b) {
        final distA = _calculateDistance(_userPosition!.latitude, _userPosition!.longitude, a.lat, a.lng);
        final distB = _calculateDistance(_userPosition!.latitude, _userPosition!.longitude, b.lat, b.lng);
        return distA.compareTo(distB);
      });
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: sortedClubs.length,
      itemBuilder: (context, index) {
        final club = sortedClubs[index];
        double? distance;
        if (_userPosition != null) {
          distance = _calculateDistance(
            _userPosition!.latitude,
            _userPosition!.longitude,
            club.lat,
            club.lng,
          );
        }

        return ClubCard(
          club: club,
          onTap: () => _navigateToProducts(club),
          distance: distance,
        );
      },
    );
  }
}
