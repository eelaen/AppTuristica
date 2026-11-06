import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/tema.dart';

/// Mapa con un pin fijo en el centro: la persona mueve el mapa hasta su lugar
/// y confirma. Al cerrarse devuelve un LatLng (o null si canceló).
class ElegirUbicacionPantalla extends StatefulWidget {
  final LatLng? inicial;

  const ElegirUbicacionPantalla({super.key, this.inicial});

  @override
  State<ElegirUbicacionPantalla> createState() =>
      _ElegirUbicacionPantallaState();
}

class _ElegirUbicacionPantallaState extends State<ElegirUbicacionPantalla> {
  static const _centroLaCeiba = LatLng(15.7597, -86.7822);

  late LatLng _centro = widget.inicial ?? _centroLaCeiba;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación de tu lugar')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _centro,
              initialZoom: widget.inicial == null ? 12 : 16,
              onPositionChanged: (camara, _) => _centro = camara.center,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app_turistica',
              ),
              const SimpleAttributionWidget(source: Text('OpenStreetMap')),
            ],
          ),

          // Pin fijo: la punta queda justo en el centro del mapa
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Icon(Icons.location_on, size: 48, color: Tema.coral),
              ),
            ),
          ),

          // Instrucción
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Material(
              color: Tema.superficie(context),
              elevation: 3,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Mueve y acerca el mapa hasta que el pin quede sobre tu lugar.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Confirmar
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_centro),
                child: const Text('Confirmar ubicación'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}