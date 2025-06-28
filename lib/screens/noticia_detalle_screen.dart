import 'package:flutter/material.dart';
import '../models/noticia_model.dart';
import 'package:url_launcher/url_launcher.dart';

class NoticiaDetalleScreen extends StatelessWidget {
  final Noticia noticia;

  const NoticiaDetalleScreen({super.key, required this.noticia});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'No se pudo lanzar $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(noticia.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.indigo[700],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              noticia.imagenUrl,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 250,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      Chip(
                        avatar: Icon(Icons.category_outlined, color: Colors.indigo[800]),
                        label: Text(noticia.tipo, style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.indigo[100],
                      ),
                      Chip(
                        avatar: Icon(Icons.priority_high, color: Colors.orange[800]),
                        label: Text('Nivel: ${noticia.nivel}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.orange[100],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    noticia.titulo,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.access_time_outlined, '${noticia.fecha} - ${noticia.hora}'),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.location_on_outlined, noticia.lugar),
                  const Divider(height: 32, thickness: 1),
                  const Text(
                    'Resumen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    noticia.resumen,
                    style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Contenido Completo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    noticia.contenido,
                    textAlign: TextAlign.justify,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const Divider(height: 32, thickness: 1),
                  ListTile(
                    leading: const Icon(Icons.link, color: Colors.blue),
                    title: const Text(
                      'Ver fuente original',
                      style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                    onTap: () {
                      _launchURL(noticia.enlace);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, color: Colors.grey[900]),
          ),
        ),
      ],
    );
  }
}