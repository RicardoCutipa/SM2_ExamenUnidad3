import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ReportPoint {
  final LatLng position;
  ReportPoint(this.position);
}

class CustomHeatmapTileProvider implements TileProvider {
  final List<ReportPoint> allReportPoints;
  final int tileSize;
  final int radiusPixels;
  final List<Color> gradientColors;
  final List<double> gradientStops;
  final Map<String, Uint8List> _tileCache = {};
  static const int _tileEdgeBuffer = 20;

  CustomHeatmapTileProvider({
    required this.allReportPoints,
    this.tileSize = 256,
    this.radiusPixels = 80,
    this.gradientColors = const [
      Color.fromARGB(0, 0, 255, 0),
      Color.fromARGB(150, 0, 255, 0),
      Color.fromARGB(180, 255, 255, 0),
      Color.fromARGB(200, 255, 165, 0),
      Color.fromARGB(220, 255, 0, 0),
    ],
    this.gradientStops = const [0.0, 0.3, 0.6, 0.8, 1.0],
  }) : assert(gradientColors.length == gradientStops.length);

  final int _downscaleFactor = 2;

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null) {
      return TileProvider.noTile;
    }

    final String cacheKey = '$x-$y-$zoom';

    if (_tileCache.containsKey(cacheKey)) {
      return Tile(tileSize, tileSize, _tileCache[cacheKey]!);
    }

    final LatLngBounds tileBounds = _getTileBounds(x, y, zoom);
    final LatLngBounds expandedBounds = _getExpandedBounds(tileBounds);

    final List<ReportPoint> pointsInTile = allReportPoints.where((point) {
      return expandedBounds.contains(point.position);
    }).toList();

    if (pointsInTile.isEmpty) {
      final Uint8List emptyTileBytes = await _createTransparentTileBytes(tileSize, tileSize);
      _tileCache[cacheKey] = emptyTileBytes;
      return Tile(tileSize, tileSize, emptyTileBytes);
    }

    final int calculationSize = tileSize ~/ _downscaleFactor;

    final List<List<double>> intensityGrid = List.generate(
      calculationSize + _tileEdgeBuffer * 2 ~/ _downscaleFactor,
      (_) => List.filled(calculationSize + _tileEdgeBuffer * 2 ~/ _downscaleFactor, 0.0),
    );

    for (final reportPoint in pointsInTile) {
      final Offset pixelOffset = _latLngToPixelOffset(
        reportPoint.position,
        tileBounds,
        tileSize.toDouble(),
        zoom,
      );

      final int baseX = (pixelOffset.dx / _downscaleFactor).round() + _tileEdgeBuffer ~/ _downscaleFactor;
      final int baseY = (pixelOffset.dy / _downscaleFactor).round() + _tileEdgeBuffer ~/ _downscaleFactor;

      final int reducedRadius = (radiusPixels / _downscaleFactor).ceil();
      final int radiusSq = reducedRadius * reducedRadius;

      for (int dx = -reducedRadius; dx <= reducedRadius; dx++) {
        final int dxSq = dx * dx;

        for (int dy = -reducedRadius; dy <= reducedRadius; dy++) {
          final int distSq = dxSq + dy * dy;
          if (distSq > radiusSq) continue;

          final int gridX = baseX + dx;
          final int gridY = baseY + dy;

          if (gridX >= 0 &&
              gridX < intensityGrid.length &&
              gridY >= 0 &&
              gridY < intensityGrid[0].length) {
            final double distance = math.sqrt(distSq.toDouble());
            final double intensity =
                math.exp(-(distance * distance) / (2 * reducedRadius * reducedRadius / 4));
            intensityGrid[gridX][gridY] += intensity;
          }
        }
      }
    }

    double maxIntensity = 0.0;
    for (final row in intensityGrid) {
      for (final intensity in row) {
        if (intensity > maxIntensity) {
          maxIntensity = intensity;
        }
      }
    }

    final double intensityThreshold =
        pointsInTile.length > 5 ? maxIntensity : maxIntensity * 1.5;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint();

    for (int x = 0; x < tileSize; x++) {
      for (int y = 0; y < tileSize; y++) {
        final int gridX = (x / _downscaleFactor).round() + _tileEdgeBuffer ~/ _downscaleFactor;
        final int gridY = (y / _downscaleFactor).round() + _tileEdgeBuffer ~/ _downscaleFactor;

        if (gridX >= 0 &&
            gridX < intensityGrid.length &&
            gridY >= 0 &&
            gridY < intensityGrid[0].length) {
          final double intensity = intensityGrid[gridX][gridY];

          if (intensity > 0) {
            double normalizedIntensity = intensity / intensityThreshold;
            normalizedIntensity = math.min(normalizedIntensity, 1.0);

            final Color color = _getColorForIntensity(normalizedIntensity);

            if (((color.opacity * 255.0).round() & 0xff) > 0) {
              paint.color = color;
              canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
            }
          }
        }
      }
    }

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(tileSize, tileSize);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();

    if (byteData != null) {
      final Uint8List tileBytes = byteData.buffer.asUint8List();
      _tileCache[cacheKey] = tileBytes;
      return Tile(tileSize, tileSize, tileBytes);
    } else {
      return TileProvider.noTile;
    }
  }

  LatLngBounds _getExpandedBounds(LatLngBounds bounds) {
    final double latExpansion =
        (bounds.northeast.latitude - bounds.southwest.latitude) * _tileEdgeBuffer / tileSize;
    final double lngExpansion =
        (bounds.northeast.longitude - bounds.southwest.longitude) * _tileEdgeBuffer / tileSize;

    return LatLngBounds(
      southwest: LatLng(bounds.southwest.latitude - latExpansion,
          bounds.southwest.longitude - lngExpansion),
      northeast: LatLng(bounds.northeast.latitude + latExpansion,
          bounds.northeast.longitude + lngExpansion),
    );
  }

  Color _getColorForIntensity(double intensity) {
    for (int i = 0; i < gradientStops.length - 1; i++) {
      if (intensity >= gradientStops[i] && intensity <= gradientStops[i + 1]) {
        final double t =
            (intensity - gradientStops[i]) / (gradientStops[i + 1] - gradientStops[i]);
        return Color.lerp(gradientColors[i], gradientColors[i + 1], t)!;
      }
    }
    return gradientColors.last;
  }

  Future<Uint8List> _createTransparentTileBytes(int width, int height) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    // Aunque no se dibuje nada, hay que crear el canvas para que endRecording funcione bien.
    final Canvas _ = Canvas(recorder);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width, height);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List() ?? Uint8List(0);
  }

  LatLngBounds _getTileBounds(int x, int y, int zoom) {
    final int numTiles = 1 << zoom;
    final double longitudeStart = (x / numTiles) * 360.0 - 180.0;
    final double longitudeEnd = ((x + 1) / numTiles) * 360.0 - 180.0;
    final double n1 = math.pi - (2.0 * math.pi * y) / numTiles;
    final double n2 = math.pi - (2.0 * math.pi * (y + 1)) / numTiles;
    final double latitudeStart =
        (180.0 / math.pi) * math.atan(0.5 * (math.exp(n1) - math.exp(-n1)));
    final double latitudeEnd =
        (180.0 / math.pi) * math.atan(0.5 * (math.exp(n2) - math.exp(-n2)));

    return LatLngBounds(
      southwest: LatLng(math.min(latitudeStart, latitudeEnd), longitudeStart),
      northeast: LatLng(math.max(latitudeStart, latitudeEnd), longitudeEnd),
    );
  }

  Offset _latLngToPixelOffset(
      LatLng point, LatLngBounds tileBounds, double tileSize, int zoom) {
    final int numTiles = 1 << zoom;
    final double worldTileSize = tileSize * numTiles;

    final double x = (point.longitude + 180.0) / 360.0 * worldTileSize;
    final double sinLatitude = math.sin(point.latitude * math.pi / 180.0);
    final double y = (0.5 -
            math.log((1.0 + sinLatitude) / (1.0 - sinLatitude)) / (4.0 * math.pi)) *
        worldTileSize;

    final double tileOriginX =
        (tileBounds.southwest.longitude + 180.0) / 360.0 * worldTileSize;
    final double tileOriginY = (0.5 -
            math.log((1.0 +
                    math.sin(tileBounds.northeast.latitude * math.pi / 180.0)) /
                (1.0 - math.sin(tileBounds.northeast.latitude * math.pi / 180.0))) /
            (4.0 * math.pi)) *
        worldTileSize;

    return Offset(x - tileOriginX, y - tileOriginY);
  }

  void clearCache() {
    _tileCache.clear();
  }
}
