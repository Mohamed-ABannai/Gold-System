import 'dart:convert';

import 'package:http/http.dart' as http;

class AssistantMessage {
  const AssistantMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

class AssistantService {
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const _model = 'llama-3.3-70b-versatile';

  Future<String> answer(String question, {required String employeeName}) async {
    if (!_isSystemQuestion(question) && !_isFriendlyChat(question)) {
      return 'أقدر أجاوب فقط عن Gold System وعمليات النظام الحالية: لوحة التحكم، أسعار الذهب، إعدادات المتجر، الشعار، الختم، البيع، المبيعات، وتسجيل الدخول.';
    }

    if (_apiKey.isEmpty) {
      return _localAnswer(question);
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'temperature': 0.2,
          'max_tokens': 180,
          'messages': [
            {
              'role': 'system',
              'content':
                  'أنت مساعد قصير داخل تطبيق Gold System لمحل ذهب في البحرين. '
                  'يجب أن تجيب فقط عن أسئلة مرتبطة بالنظام نفسه وطريقة استخدامه. '
                  'اسمح بالتحية والسوالف الخفيفة مثل هلا وشخبارك ورد بشكل طبيعي، ثم اربط الكلام بلطف بالنظام إذا احتاج. '
                  'إذا كان السؤال خارج النظام، اعتذر بجملة قصيرة وقل إنك تجيب فقط عن Gold System. '
                  'جاوب بالعربي بخطوات عملية قصيرة جداً. '
                  'ميزات التطبيق الحالية: تسجيل الدخول، لوحة التحكم، تحديث أسعار الذهب العالمية وتحويلها إلى BHD، إعدادات المتجر، استيراد الشعار والختم، صفحة منتجات بصورة ونوع وعيار ووزن وكمية، بيع القطع المتوفرة مع سعر جرام وتخفيض لكل قطعة وخصمها من المخزون، وسجل المبيعات. '
                  'اسم الموظف الحالي: $employeeName.',
            },
            {'role': 'user', 'content': question},
          ],
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'تعذر الاتصال بالمساعد الآن. تأكد من مفتاح Groq أو الإنترنت.';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>;
      final message = choices.first['message'] as Map<String, dynamic>;
      return (message['content'] as String).trim();
    } catch (_) {
      return 'صار خطأ في الاتصال بالمساعد. تقدر تكمل باستخدام الخطوات داخل النظام.';
    }
  }

  bool _isSystemQuestion(String question) {
    final q = question.toLowerCase();
    const allowedTerms = [
      'gold system',
      'system',
      'النظام',
      'برنامج',
      'تطبيق',
      'لوحة',
      'تحكم',
      'ذهب',
      'سعر',
      'اسعار',
      'أسعار',
      'عيار',
      'bhd',
      'دينار',
      'فاتورة',
      'طباعة',
      'عميل',
      'متجر',
      'محل',
      'شعار',
      'ختم',
      'دخول',
      'login',
      'admin',
      'بيع',
      'مبيعات',
      'مخزون',
      'موظف',
      'منتج',
      'منتجات',
      'قطعة',
      'قطع',
      'صورة',
      'كاميرا',
    ];
    return allowedTerms.any(q.contains);
  }

  bool _isFriendlyChat(String question) {
    final q = question.trim().toLowerCase();
    const friendlyTerms = [
      'هلا',
      'هلا والله',
      'مرحبا',
      'السلام عليكم',
      'اهلا',
      'أهلا',
      'شلونك',
      'شخبارك',
      'كيفك',
      'صباح الخير',
      'مساء الخير',
      'hi',
      'hello',
      'hey',
    ];
    return friendlyTerms.any(q.contains) && q.length <= 80;
  }

  String _localAnswer(String question) {
    final q = question.toLowerCase();
    if (_isFriendlyChat(question)) {
      return 'هلا والله، حيّاك. أنا وياك داخل Gold System، نقدر نسجل قطعة، نسجل بيع، أو نراجع المخزون والأسعار.';
    }
    if (q.contains('شعار') || q.contains('ختم')) {
      return 'اذهب إلى صفحة المتجر، اضغط زر الاستيراد بجانب شعار المحل أو ختم المحل، اختر الصورة، ثم اضغط حفظ الإعدادات.';
    }
    if (q.contains('منتج') || q.contains('قطعة') || q.contains('منتج')) {
      return 'افتح صفحة المنتجات، اكتب اسم القطعة ونوعها وعيارها ووزنها والكمية، أضف الصورة، ثم اضغط حفظ القطعة. عند بيعها من الفاتورة تتحول تلقائياً إلى مباع.';
    }
    if (q.contains('فاتورة')) {
      return 'افتح صفحة الفاتورة، اكتب بيانات العميل، اختر القطع المتوفرة، راجع سعر الجرام والتخفيض لكل قطعة، ثم اضغط العميل دفع - تسجيل البيع. بعدها تنخصم القطع من المخزون.';
    }
    if (q.contains('ذهب') || q.contains('سعر')) {
      return 'من لوحة التحكم اضغط تحديث السعر. النظام يجلب السعر العالمي XAU بالدولار، يحوله إلى الدينار البحريني، ثم يحسب سعر الجرام لعيارات 24 و22 و21 و18. كذلك يحدث السعر تلقائياً كل دقيقة أثناء فتح اللوحة.';
    }
    if (q.contains('دخول') || q.contains('login')) {
      return 'سجل الدخول بأحد الحسابات المحلية: Khalil / Kk123456@@ أو abbas / Am123456@@.';
    }
    return 'حالياً تقدر تستخدم: لوحة التحكم، المنتجات، إعدادات المتجر، تسجيل البيع من القطع المتوفرة، وسجل المبيعات. اسألني باسم الصفحة أو العملية التي تريدها.';
  }
}
