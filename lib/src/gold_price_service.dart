import 'dart:convert';

import 'package:http/http.dart' as http;

class GoldSpotPrices {
  const GoldSpotPrices({
    required this.bhdPerOunce,
    required this.usdPerOunce,
    required this.usdToBhd,
    required this.updatedAt,
  });

  final double bhdPerOunce;
  final double usdPerOunce;
  final double usdToBhd;
  final DateTime updatedAt;
}

class GoldPriceService {
  GoldPriceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _goldUri = Uri.parse('https://api.gold-api.com/price/XAU');
  static final Uri _usdRatesUri = Uri.parse(
    'https://open.er-api.com/v6/latest/USD',
  );

  Future<GoldSpotPrices> fetchBahrainSpotPrices() async {
    final responses = await Future.wait([
      _client.get(_goldUri),
      _client.get(_usdRatesUri),
    ]);

    final goldResponse = responses[0];
    final ratesResponse = responses[1];
    if (goldResponse.statusCode < 200 || goldResponse.statusCode >= 300) {
      throw GoldPriceException('تعذر جلب سعر الذهب العالمي.');
    }
    if (ratesResponse.statusCode < 200 || ratesResponse.statusCode >= 300) {
      throw GoldPriceException('تعذر جلب تحويل الدولار إلى الدينار.');
    }

    final goldData = jsonDecode(goldResponse.body) as Map<String, dynamic>;
    final ratesData = jsonDecode(ratesResponse.body) as Map<String, dynamic>;
    final usdPerOunce = (goldData['price'] as num?)?.toDouble();
    final rates = ratesData['rates'] as Map<String, dynamic>?;
    final usdToBhd = (rates?['BHD'] as num?)?.toDouble();
    final updatedAtText = goldData['updatedAt'] as String?;

    if (usdPerOunce == null || usdPerOunce <= 0) {
      throw GoldPriceException('بيانات سعر الذهب غير مكتملة.');
    }
    if (usdToBhd == null || usdToBhd <= 0) {
      throw GoldPriceException('بيانات تحويل BHD غير مكتملة.');
    }

    final updatedAt = updatedAtText == null
        ? DateTime.now().toUtc()
        : DateTime.tryParse(updatedAtText)?.toUtc() ?? DateTime.now().toUtc();

    return GoldSpotPrices(
      bhdPerOunce: usdPerOunce * usdToBhd,
      usdPerOunce: usdPerOunce,
      usdToBhd: usdToBhd,
      updatedAt: updatedAt,
    );
  }
}

class GoldPriceException implements Exception {
  const GoldPriceException(this.message);

  final String message;

  @override
  String toString() => message;
}
