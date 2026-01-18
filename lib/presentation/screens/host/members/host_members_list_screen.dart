import 'package:flutter/material.dart';

class HostMembersListScreen extends StatelessWidget {
  const HostMembersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Socios del Club'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay socios registrados aún.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Registrar socio manualmente
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Función de registro manual próximamente')));
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
