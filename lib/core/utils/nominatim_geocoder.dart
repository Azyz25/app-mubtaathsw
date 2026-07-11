import 'package:dio/dio.dart';

final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 8),
  headers: {'User-Agent': 'MubtaathApp/1.0 (Saudi Students Abroad)'},
));

String _pick(Map<String, dynamic> address, List<String> keys) {
  for (final key in keys) {
    final val = (address[key] as String?)?.trim();
    if (val != null && val.isNotEmpty) return val;
  }
  return '';
}

Future<String> _fetch(double lat, double lon, String lang) async {
  try {
    final resp = await _dio.get<dynamic>(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'format': 'json',
        'lat': lat,
        'lon': lon,
        'accept-language': lang,
        'zoom': 10,
      },
    );
    final raw = resp.data;
    if (raw is! Map<String, dynamic>) return '';
    final address = raw['address'];
    if (address is! Map<String, dynamic>) return '';

    final place = _pick(address, [
      'city', 'town', 'village', 'county', 'municipality', 'state',
    ]);
    final country = (address['country'] as String?)?.trim() ?? '';

    if (place.isEmpty && country.isEmpty) return '';
    if (place.isEmpty) return country;
    if (country.isEmpty) return place;
    return lang == 'ar' ? '$place، $country' : '$place, $country';
  } catch (_) {
    return '';
  }
}

/// Queries Nominatim for both Arabic and English city+country labels in
/// parallel. Either field may be empty if the request fails or times out.
Future<({String ar, String en})> nominatimReverse(
  double lat,
  double lon,
) async {
  final results = await Future.wait([
    _fetch(lat, lon, 'ar'),
    _fetch(lat, lon, 'en'),
  ]);
  return (ar: results[0], en: results[1]);
}
