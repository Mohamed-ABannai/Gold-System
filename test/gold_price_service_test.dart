import 'package:flutter_test/flutter_test.dart';
import 'package:gold_system/src/gold_price_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('fetchBahrainSpotPrices converts XAU USD price to BHD', () async {
    final service = GoldPriceService(
      client: MockClient((request) async {
        if (request.url.host == 'api.gold-api.com') {
          return http.Response(
            '{"price": 4500, "updatedAt": "2026-06-02T13:48:21Z"}',
            200,
          );
        }
        return http.Response('{"rates": {"BHD": 0.376}}', 200);
      }),
    );

    final prices = await service.fetchBahrainSpotPrices();

    expect(prices.usdPerOunce, 4500);
    expect(prices.usdToBhd, 0.376);
    expect(prices.bhdPerOunce, 1692);
    expect(prices.updatedAt.toIso8601String(), '2026-06-02T13:48:21.000Z');
  });
}
