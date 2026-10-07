import 'package:flutter_test/flutter_test.dart';
import 'package:gold_system/src/assistant_service.dart';

void main() {
  test('assistant refuses questions outside Gold System', () async {
    final service = AssistantService();

    final answer = await service.answer(
      'ما حالة الطقس اليوم؟',
      employeeName: 'مدير النظام',
    );

    expect(answer, contains('أقدر أجاوب فقط عن Gold System'));
  });
}
