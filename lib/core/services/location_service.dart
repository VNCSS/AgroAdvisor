import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Encapsula toda a lógica de permissão e captura de GPS.
///
/// Antes desta classe, o mesmo bloco de código aparecia 3 vezes:
///   PropertyFormScreen, OccurrenceScreen e OccurrenceRadarScreen.
/// Agora existe um único ponto de manutenção.
class LocationService {
  /// Solicita permissão (se necessário) e retorna a posição atual.
  ///
  /// Retorna [null] e preenche [errorMessage] em caso de falha.
  /// Lança [LocationException] se o GPS estiver desabilitado ou negado.
  static Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('GPS desativado. Ative nas configurações do dispositivo.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Permissão de localização negada.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Permissão negada permanentemente. Habilite nas configurações do app.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          // Sem limite, a tela ficava aguardando indefinidamente sem sinal.
          timeLimit: gpsTimeout,
        ),
      );
    } on TimeoutException {
      throw const LocationException(
        'Não foi possível obter a localização a tempo. Verifique o sinal de '
        'GPS e tente novamente.',
      );
    }
  }

  /// Tempo máximo de espera pelo GPS. Folgado para não falhar em
  /// "partida a frio" do GPS em campo.
  static const Duration gpsTimeout = Duration(seconds: 60);

  /// Calcula a distância em metros entre dois pontos.
  static double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}

/// Exceção lançada pelo [LocationService] quando o GPS não está disponível.
class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}
