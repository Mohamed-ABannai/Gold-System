import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app_database.dart';
import 'src/assistant_service.dart';
import 'src/gold_price_service.dart';
import 'src/ui_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ar';

  final database = AppDatabase();
  await database.init();
  runApp(GoldSystemApp(database: database));
}

class GoldSystemApp extends StatelessWidget {
  const GoldSystemApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gold System',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildGoldTheme(),
      home: LoginScreen(database: database),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }

  Future<void> _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('remembered_username') ?? '';
    if (!mounted || username.isEmpty) return;
    setState(() {
      _usernameController.text = username;
      _rememberMe = true;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = await widget.database.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user == null) {
      setState(() => _error = 'اسم المستخدم أو كلمة المرور غير صحيحة');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('remembered_username', user.username);
    } else {
      await prefs.remove('remembered_username');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            ShellScreen(database: widget.database, currentUser: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          color: AppColors.ice,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Row(
                  children: [
                    Expanded(
                      child: _GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: AppColors.blue,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.diamond_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Gold System',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'نظام محل الذهب لإدارة المبيعات والفواتير والمخزون أوفلاين.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 34),
                            TextField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'اسم المستخدم',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                              onSubmitted: (_) => _login(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _error!,
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ],
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              value: _rememberMe,
                              onChanged: (value) =>
                                  setState(() => _rememberMe = value ?? false),
                              title: const Text('تذكرني'),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _isLoading ? null : _login,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: const Text('تسجيل الدخول'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    if (!MediaQuery.of(context).size.width.isNaN)
                      Expanded(child: _HeroPreview(database: widget.database)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShellScreen extends StatefulWidget {
  const ShellScreen({
    super.key,
    required this.database,
    required this.currentUser,
  });

  final AppDatabase database;
  final AppUser currentUser;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _selectedIndex = 0;
  final List<ProductItem> _invoiceProducts = [];

  void _addProductToInvoice(ProductItem product) {
    if (!product.isAvailable) return;
    if (_invoiceProducts.any((item) => item.id == product.id)) {
      setState(() => _selectedIndex = 3);
      return;
    }
    setState(() {
      _invoiceProducts.add(product);
      _selectedIndex = 3;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تمت إضافة ${product.name} للفاتورة')),
    );
  }

  void _clearInvoiceProducts() => setState(_invoiceProducts.clear);

  void _removeProductFromInvoice(ProductItem product) {
    setState(() {
      _invoiceProducts.removeWhere((item) => item.id == product.id);
    });
  }

  void _logout() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد'),
        content: const Text('هل أنت متأكد بتسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(database: widget.database),
                ),
              );
            },
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(database: widget.database, user: widget.currentUser),
      StoreSettingsPage(database: widget.database),
      ProductsPage(
        database: widget.database,
        invoiceProducts: _invoiceProducts,
        onAddToInvoice: _addProductToInvoice,
      ),
      InvoiceDemoPage(
        database: widget.database,
        user: widget.currentUser,
        initialProducts: _invoiceProducts,
        onRemoveProduct: _removeProductFromInvoice,
        onClearProducts: _clearInvoiceProducts,
      ),
      SalesLedgerPage(database: widget.database, user: widget.currentUser),
      InventoryAuditPage(database: widget.database),
      AiAssistantPage(user: widget.currentUser),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.ice,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) =>
                  setState(() => _selectedIndex = value),
              backgroundColor: Colors.white,
              extended: MediaQuery.of(context).size.width > 980,
              labelType: MediaQuery.of(context).size.width > 980
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.selected,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.diamond_rounded, color: Colors.white),
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: IconButton.filledTonal(
                      tooltip: 'تسجيل الخروج',
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: Text('لوحة التحكم'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront_rounded),
                  label: Text('المتجر'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2_rounded),
                  label: Text('المنتجات'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: Text('فاتورة'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.manage_search_outlined),
                  selectedIcon: Icon(Icons.manage_search_rounded),
                  label: Text('المبيعات'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check_rounded),
                  label: Text('جرد القطع'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.support_agent_outlined),
                  selectedIcon: Icon(Icons.support_agent_rounded),
                  label: Text('المساعد'),
                ),
              ],
            ),
            Expanded(child: pages[_selectedIndex]),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.database, required this.user});

  final AppDatabase database;
  final AppUser user;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _goldPriceService = GoldPriceService();
  late Future<DashboardSnapshot> _future;
  Timer? _goldRefreshTimer;
  bool _isUpdatingGold = false;

  @override
  void initState() {
    super.initState();
    _future = widget.database.dashboardSnapshot();
    _refreshLiveGoldPrice(showMessage: false);
    _goldRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshLiveGoldPrice(showMessage: false),
    );
  }

  @override
  void dispose() {
    _goldRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateBahrainGoldPrice() async {
    await _refreshLiveGoldPrice(showMessage: true);
  }

  Future<void> _refreshLiveGoldPrice({required bool showMessage}) async {
    if (_isUpdatingGold) return;
    setState(() => _isUpdatingGold = true);

    try {
      final spot = await _goldPriceService.fetchBahrainSpotPrices();
      await widget.database.updateGoldPricesFromSpot(
        bhdPerOunce: spot.bhdPerOunce,
        updatedAt: spot.updatedAt,
      );
      if (!mounted) return;
      setState(() {
        _future = widget.database.dashboardSnapshot();
        _isUpdatingGold = false;
      });
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث السعر العالمي: ${spot.usdPerOunce.toStringAsFixed(2)} USD/XAU',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUpdatingGold = false);
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لم يتم تحديث السعر الآن: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE، d MMMM yyyy', 'ar').format(DateTime.now());
    return FutureBuilder<DashboardSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? DashboardSnapshot.empty();
        return _PageScaffold(
          title: 'لوحة التحكم',
          subtitle: 'مرحباً ${widget.user.fullName}، $today',
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 2.25,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StatTile(
                        'سعر عيار 24',
                        '${data.karat24.toStringAsFixed(3)} BHD',
                        Icons.water_drop_outlined,
                      ),
                      _StatTile(
                        'مبيعات اليوم',
                        '${data.todaySales.toStringAsFixed(3)} BHD',
                        Icons.point_of_sale_rounded,
                      ),
                      _StatTile(
                        'القطع المتبقية',
                        '${data.availableProducts}',
                        Icons.inventory_2_outlined,
                      ),
                      _StatTile(
                        'آخر تحديث',
                        data.lastGoldUpdate,
                        Icons.update_rounded,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _Surface(
                        title: 'أسعار الذهب اليومية',
                        icon: Icons.price_change_outlined,
                        child: Column(
                          children: [
                            _GoldPriceRow(
                              'عيار 24',
                              data.karat24,
                              data.karat24 * 1.05,
                            ),
                            _GoldPriceRow(
                              'عيار 22',
                              data.karat22,
                              data.karat22 * 1.05,
                            ),
                            _GoldPriceRow(
                              'عيار 21',
                              data.karat21,
                              data.karat21 * 1.05,
                            ),
                            _GoldPriceRow(
                              'عيار 18',
                              data.karat18,
                              data.karat18 * 1.05,
                            ),
                            const Spacer(),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.icon(
                                onPressed: _isUpdatingGold
                                    ? null
                                    : _updateBahrainGoldPrice,
                                icon: _isUpdatingGold
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.sync_rounded),
                                label: const Text('تحديث السعر'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 5,
                      child: _Surface(
                        title: 'ملخص اليوم',
                        icon: Icons.today_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ChecklistItem(
                              'المبيعات: ${data.todaySales.toStringAsFixed(3)} BHD',
                            ),
                            _ChecklistItem(
                              'المتوفر: ${data.availableProducts} قطعة',
                            ),
                            _ChecklistItem(
                              'آخر تحديث للسعر: ${data.lastGoldUpdate}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StoreSettingsPage extends StatefulWidget {
  const StoreSettingsPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _tax = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  StoreSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.database.getStoreSettings();
    setState(() {
      _settings = settings;
      _name.text = settings.storeName;
      _tax.text = settings.taxNumber;
      _phone.text = settings.phone;
      _address.text = settings.address;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final current = _settings ?? StoreSettings.defaults();
    final updated = current.copyWith(
      storeName: _name.text.trim(),
      taxNumber: _tax.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
    );
    await widget.database.saveStoreSettings(updated);
    setState(() => _settings = updated);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات المتجر')));
  }

  Future<void> _pickAsset(StoreAssetType type) async {
    final updated = await widget.database.pickAndSaveStoreAsset(type);
    if (updated != null) setState(() => _settings = updated);
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'إعدادات المتجر',
      subtitle: 'استورد شعار المحل والختم لاستخدامهم في الفواتير.',
      child: _Surface(
        title: 'بيانات المحل',
        icon: Icons.storefront_rounded,
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _AssetPicker(
                    title: 'شعار المحل',
                    bytes: _settings?.logoBytes,
                    onPick: () => _pickAsset(StoreAssetType.logo),
                  ),
                  _AssetPicker(
                    title: 'ختم المحل',
                    bytes: _settings?.stampBytes,
                    onPick: () => _pickAsset(StoreAssetType.stamp),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ResponsiveFields(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'اسم المحل'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'مطلوب' : null,
                  ),
                  TextFormField(
                    controller: _tax,
                    decoration: const InputDecoration(
                      labelText: 'رقم السجل التجاري',
                    ),
                  ),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  ),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ الإعدادات'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({
    super.key,
    required this.database,
    required this.invoiceProducts,
    required this.onAddToInvoice,
  });

  final AppDatabase database;
  final List<ProductItem> invoiceProducts;
  final ValueChanged<ProductItem> onAddToInvoice;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _type = TextEditingController();
  final _weight = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _search = TextEditingController();
  int _karat = 21;
  int? _karatFilter;
  String _statusFilter = 'all';
  Uint8List? _imageBytes;
  late Future<List<ProductItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.database.getProducts();
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _weight.dispose();
    _quantity.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await widget.database.addProduct(
        name: _name.text.trim(),
        productType: _type.text.trim(),
        karat: _karat,
        weight: double.parse(_weight.text.trim()),
        quantity: int.parse(_quantity.text.trim()),
        imageBytes: _imageBytes,
      );
      setState(() {
        _name.clear();
        _type.clear();
        _weight.clear();
        _quantity.text = '1';
        _imageBytes = null;
        _future = widget.database.getProducts();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت إضافة القطعة')));
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حفظ القطعة: $error')));
    }
  }

  Future<void> _saveEdit(ProductItem product) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await widget.database.updateProduct(
        id: product.id,
        name: _name.text.trim(),
        productType: _type.text.trim(),
        karat: _karat,
        weight: double.parse(_weight.text.trim()),
        quantity: int.parse(_quantity.text.trim()),
        imageBytes: _imageBytes,
      );
      setState(() {
        _name.clear();
        _type.clear();
        _weight.clear();
        _quantity.text = '1';
        _imageBytes = null;
        _future = widget.database.getProducts();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تعديل القطعة')));
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تعديل القطعة: $error')));
    }
  }

  Future<void> _deleteProduct(ProductItem product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف القطعة'),
        content: Text('هل تريد حذف ${product.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.database.deleteProduct(product.id);
      setState(() {
        _future = widget.database.getProducts();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف القطعة')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حذف القطعة: $error')));
    }
  }

  void _openAddProductSheet() {
    _name.clear();
    _type.clear();
    _weight.clear();
    _quantity.text = '1';
    _karat = 21;
    _imageBytes = null;
    _openProductSheet(onSave: _save);
  }

  void _openEditProductSheet(ProductItem product) {
    _name.text = product.name;
    _type.text = product.productType;
    _weight.text = product.weight.toString();
    _quantity.text = product.quantity.toString();
    _karat = product.karat;
    _imageBytes = null;
    _openProductSheet(product: product, onSave: () => _saveEdit(product));
  }

  void _openProductSheet({ProductItem? product, required VoidCallback onSave}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, refreshSheet) {
            Future<void> pickImage() async {
              final bytes = await widget.database.pickImageBytes();
              if (bytes == null) return;
              setState(() => _imageBytes = bytes);
              refreshSheet(() {});
            }

            Future<void> captureImage() async {
              final bytes = await showDialog<Uint8List>(
                context: context,
                builder: (_) => const _CameraCaptureDialog(),
              );
              if (bytes == null) return;
              setState(() => _imageBytes = bytes);
              refreshSheet(() {});
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                  top: 18,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _AddProductForm(
                          formKey: _formKey,
                          title: product == null ? 'إضافة قطعة' : 'تعديل قطعة',
                          saveLabel: product == null
                              ? 'حفظ القطعة'
                              : 'حفظ التعديل',
                          name: _name,
                          type: _type,
                          weight: _weight,
                          quantity: _quantity,
                          karat: _karat,
                          imageBytes: _imageBytes,
                          onKaratChanged: (value) {
                            setState(() => _karat = value ?? _karat);
                            refreshSheet(() {});
                          },
                          onPickImage: pickImage,
                          onCaptureImage: captureImage,
                          onSave: onSave,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<ProductItem> _filterProducts(List<ProductItem> products) {
    final query = _search.text.trim().toLowerCase();
    return products.where((product) {
      final matchesSearch =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.productType.toLowerCase().contains(query);
      final matchesKarat =
          _karatFilter == null || product.karat == _karatFilter;
      final matchesStatus =
          _statusFilter == 'all' ||
          (_statusFilter == 'available' && product.isAvailable) ||
          (_statusFilter == 'sold' && !product.isAvailable);
      return matchesSearch && matchesKarat && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'المنتجات',
      subtitle: 'كل منتج مع الوزن والعيار والكمية وحالة المخزون.',
      child: _Surface(
        title: 'المخزون',
        icon: Icons.inventory_2_outlined,
        child: Column(
          children: [
            _ProductsToolbar(
              search: _search,
              karatFilter: _karatFilter,
              statusFilter: _statusFilter,
              onSearchChanged: (_) => setState(() {}),
              onKaratChanged: (value) => setState(() => _karatFilter = value),
              onStatusChanged: (value) =>
                  setState(() => _statusFilter = value ?? 'all'),
              onAdd: _openAddProductSheet,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<List<ProductItem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final products = _filterProducts(
                    snapshot.data ?? const <ProductItem>[],
                  );
                  if (products.isEmpty) {
                    return const Center(child: Text('لا توجد منتجات مطابقة'));
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1120
                          ? 4
                          : constraints.maxWidth >= 820
                          ? 3
                          : constraints.maxWidth >= 560
                          ? 2
                          : 1;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: columns == 1 ? 2.7 : 0.78,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _ProductCard(
                            product: product,
                            isInInvoice: widget.invoiceProducts.any(
                              (item) => item.id == product.id,
                            ),
                            onAddToInvoice: () =>
                                widget.onAddToInvoice(product),
                            onEdit: product.isAvailable
                                ? () => _openEditProductSheet(product)
                                : null,
                            onDelete: product.isAvailable
                                ? () => _deleteProduct(product)
                                : null,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InvoiceDemoPage extends StatefulWidget {
  const InvoiceDemoPage({
    super.key,
    required this.database,
    required this.user,
    required this.initialProducts,
    required this.onRemoveProduct,
    required this.onClearProducts,
  });

  final AppDatabase database;
  final AppUser user;
  final List<ProductItem> initialProducts;
  final ValueChanged<ProductItem> onRemoveProduct;
  final VoidCallback onClearProducts;

  @override
  State<InvoiceDemoPage> createState() => _InvoiceDemoPageState();
}

class GulfPhoneCountry {
  const GulfPhoneCountry({
    required this.nameAr,
    required this.code,
    required this.localDigits,
  });

  final String nameAr;
  final String code;
  final int localDigits;

  static const bahrain = GulfPhoneCountry(
    nameAr: 'البحرين',
    code: '973',
    localDigits: 8,
  );

  static const values = [
    bahrain,
    GulfPhoneCountry(nameAr: 'السعودية', code: '966', localDigits: 9),
    GulfPhoneCountry(nameAr: 'الإمارات', code: '971', localDigits: 9),
    GulfPhoneCountry(nameAr: 'الكويت', code: '965', localDigits: 8),
    GulfPhoneCountry(nameAr: 'قطر', code: '974', localDigits: 8),
    GulfPhoneCountry(nameAr: 'عمان', code: '968', localDigits: 8),
  ];
}

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key, required this.user});

  final AppUser user;

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final _service = AssistantService();
  final _question = TextEditingController();
  final List<AssistantMessage> _messages = [
    const AssistantMessage(
      fromUser: false,
      text:
          'أهلاً، اسألني عن طريقة استخدام النظام: الفواتير، الشعار، الختم، تسجيل البيع، أو أسعار الذهب.',
    ),
  ];
  bool _isLoading = false;

  Future<void> _send() async {
    final text = _question.text.trim();
    if (text.isEmpty || _isLoading) return;
    setState(() {
      _messages.add(AssistantMessage(fromUser: true, text: text));
      _question.clear();
      _isLoading = true;
    });

    final answer = await _service.answer(
      text,
      employeeName: widget.user.fullName,
    );
    if (!mounted) return;
    setState(() {
      _messages.add(AssistantMessage(fromUser: false, text: answer));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'المساعد الداخلي',
      subtitle:
          'مساعد قصير للموظف يشرح كيف يستخدم النظام. يعمل محلياً بدون مفتاح، ومع Groq عند تمرير المفتاح.',
      child: _Surface(
        title: 'اسأل عن النظام',
        icon: Icons.support_agent_rounded,
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: _messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Align(
                    alignment: message.fromUser
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 620),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: message.fromUser
                            ? AppColors.blue
                            : AppColors.iceStrong,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: message.fromUser
                              ? Colors.white
                              : AppColors.ink,
                          height: 1.45,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _question,
                    decoration: const InputDecoration(
                      hintText: 'مثال: كيف أضيف شعار المحل للفاتورة؟',
                      prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _send,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('إرسال'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceDemoPageState extends State<InvoiceDemoPage> {
  final _formKey = GlobalKey<FormState>();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerPersonalId = TextEditingController();
  final _customerAddress = TextEditingController();
  final Map<int, TextEditingController> _gramPriceControllers = {};
  final Map<int, TextEditingController> _weightControllers = {};
  final Map<int, TextEditingController> _piecePriceControllers = {};
  final Map<int, TextEditingController> _discountControllers = {};
  final Map<int, TextEditingController> _quantityControllers = {};
  final Set<int> _loadingPrices = {};
  final Set<int> _syncingLineControllers = {};
  bool _isSaving = false;
  GulfPhoneCountry _phoneCountry = GulfPhoneCountry.bahrain;
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _syncProductControllers();
  }

  @override
  void didUpdateWidget(covariant InvoiceDemoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncProductControllers();
  }

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _customerPersonalId.dispose();
    _customerAddress.dispose();
    for (final controller in _gramPriceControllers.values) {
      controller.dispose();
    }
    for (final controller in _weightControllers.values) {
      controller.dispose();
    }
    for (final controller in _piecePriceControllers.values) {
      controller.dispose();
    }
    for (final controller in _discountControllers.values) {
      controller.dispose();
    }
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncProductControllers() {
    for (final product in widget.initialProducts) {
      if (_gramPriceControllers.containsKey(product.id) ||
          _loadingPrices.contains(product.id)) {
        continue;
      }
      _loadProductPrice(product);
    }
    final currentIds = widget.initialProducts.map((item) => item.id).toSet();
    final removedIds = _gramPriceControllers.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in removedIds) {
      _gramPriceControllers.remove(id)?.dispose();
      _weightControllers.remove(id)?.dispose();
      _piecePriceControllers.remove(id)?.dispose();
      _quantityControllers.remove(id)?.dispose();
      _discountControllers.remove(id)?.dispose();
    }
  }

  Future<void> _loadProductPrice(ProductItem product) async {
    _loadingPrices.add(product.id);
    final pricePerGram = await widget.database.sellPricePerGram(product.karat);
    if (!mounted) return;
    setState(() {
      _gramPriceControllers[product.id] = TextEditingController(
        text: _invoiceNumber(pricePerGram),
      );
      _weightControllers[product.id] = TextEditingController(
        text: _invoiceNumber(product.weight),
      );
      _piecePriceControllers[product.id] = TextEditingController(
        text: _invoiceNumber(pricePerGram * product.weight),
      );
      _quantityControllers[product.id] = TextEditingController(text: '1');
      _discountControllers[product.id] = TextEditingController(text: '0');
      _loadingPrices.remove(product.id);
    });
  }

  void _removeFromInvoice(ProductItem product) {
    final controller = _gramPriceControllers.remove(product.id);
    controller?.dispose();
    _weightControllers.remove(product.id)?.dispose();
    _piecePriceControllers.remove(product.id)?.dispose();
    _quantityControllers.remove(product.id)?.dispose();
    _discountControllers.remove(product.id)?.dispose();
    widget.onRemoveProduct(product);
  }

  int _lineQuantity(ProductItem product) {
    final maxQuantity = product.quantity.clamp(1, 999999);
    final parsed = int.tryParse(
      _quantityControllers[product.id]?.text.trim() ?? '',
    );
    final quantity = (parsed ?? 1).clamp(1, maxQuantity);
    final controller = _quantityControllers[product.id];
    if (controller != null && controller.text != quantity.toString()) {
      controller.text = quantity.toString();
    }
    return quantity;
  }

  void _setLineQuantity(ProductItem product, int quantity) {
    final maxQuantity = product.quantity.clamp(1, 999999);
    final nextQuantity = quantity.clamp(1, maxQuantity);
    final controller = _quantityControllers[product.id];
    if (controller != null && controller.text != nextQuantity.toString()) {
      controller.text = nextQuantity.toString();
    }
    setState(() {});
  }

  double _lineGrossTotal(ProductItem product) => _safeInvoiceNumber(
    (_lineUnitPrice(product) * _lineQuantity(product))
        .clamp(0, double.infinity)
        .toDouble(),
  );

  double _lineUnitPrice(ProductItem product) => _safeInvoiceNumber(
    double.tryParse(_piecePriceControllers[product.id]?.text.trim() ?? '') ??
        (_lineGramPrice(product) * _lineWeight(product)),
  );

  double _lineWeight(ProductItem product) {
    return _safeInvoiceNumber(
      double.tryParse(_weightControllers[product.id]?.text.trim() ?? '') ??
          product.weight,
    );
  }

  double _lineGramPrice(ProductItem product) {
    return _safeInvoiceNumber(
      double.tryParse(_gramPriceControllers[product.id]?.text.trim() ?? '') ??
          0,
    );
  }

  double _lineDiscount(ProductItem product) {
    return _safeInvoiceNumber(
      double.tryParse(
            _discountControllers[product.id]?.text.trim().isEmpty ?? true
                ? '0'
                : _discountControllers[product.id]!.text.trim(),
          ) ??
          0,
    );
  }

  void _syncLineFromGramOrWeight(ProductItem product) {
    if (_syncingLineControllers.contains(product.id)) return;
    _syncingLineControllers.add(product.id);
    final unitPrice = _lineGramPrice(product) * _lineWeight(product);
    _piecePriceControllers[product.id]?.text = _invoiceNumber(unitPrice);
    _syncingLineControllers.remove(product.id);
    setState(() {});
  }

  void _syncLineFromPiecePrice(ProductItem product) {
    if (_syncingLineControllers.contains(product.id)) return;
    _syncingLineControllers.add(product.id);
    final weight = _lineWeight(product);
    final quantity = _lineQuantity(product);
    final unitPrice = _lineUnitPrice(product);
    if (weight > 0 && quantity > 0) {
      _gramPriceControllers[product.id]?.text = _invoiceNumber(
        unitPrice / weight,
      );
    }
    _syncingLineControllers.remove(product.id);
    setState(() {});
  }

  double get _subtotal => widget.initialProducts.fold<double>(
    0,
    (sum, product) => sum + _lineGrossTotal(product),
  );

  double get _discountAmount => widget.initialProducts.fold<double>(
    0,
    (sum, product) => sum + _lineDiscount(product),
  );

  double get _invoiceTotal =>
      (_subtotal - _discountAmount).clamp(0, double.infinity).toDouble();

  Future<void> _confirmSale() async {
    if (widget.initialProducts.isEmpty || _isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الدفع'),
        content: const Text(
          'هل أنت متأكد أن العميل دفع وتريد طباعة فاتورة تم الشراء؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('نعم، تم الدفع'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      final sale = await widget.database.createSale(
        customerName: _customerName.text.trim().isEmpty
            ? 'عميل نقدي'
            : _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim(),
        customerCountryCode: _phoneCountry.code,
        customerPersonalId: _customerPersonalId.text.trim(),
        customerAddress: _customerAddress.text.trim(),
        paymentMethod: _paymentMethod,
        discount: 0,
        userId: widget.user.id,
        productIds: widget.initialProducts
            .map((product) => product.id)
            .toList(),
        productQuantities: {
          for (final product in widget.initialProducts)
            product.id: _lineQuantity(product),
        },
        productGramPrices: {
          for (final product in widget.initialProducts)
            product.id: _lineGramPrice(product),
        },
        productTotals: {
          for (final product in widget.initialProducts)
            product.id: _lineGrossTotal(product),
        },
        productWeights: {
          for (final product in widget.initialProducts)
            product.id: _lineWeight(product),
        },
        productDiscounts: {
          for (final product in widget.initialProducts)
            product.id: _lineDiscount(product),
        },
      );
      if (!mounted) return;
      setState(() {
        for (final controller in _gramPriceControllers.values) {
          controller.dispose();
        }
        for (final controller in _weightControllers.values) {
          controller.dispose();
        }
        for (final controller in _piecePriceControllers.values) {
          controller.dispose();
        }
        for (final controller in _discountControllers.values) {
          controller.dispose();
        }
        _gramPriceControllers.clear();
        _weightControllers.clear();
        _piecePriceControllers.clear();
        _discountControllers.clear();
        _quantityControllers.clear();
        widget.onClearProducts();
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم بيع ${sale.lines.length} قطعة')),
      );
      try {
        await _printOfficialInvoice(sale, widget.database);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تسجيل البيع، لكن تعذرت طباعة الفاتورة: $error'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تسجيل البيع: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'فاتورة',
      subtitle:
          'أضف القطع من صفحة المنتجات ثم أكد الدفع لتسجيل البيع والطباعة.',
      child: _Surface(
        title: 'فاتورة',
        icon: Icons.receipt_long_rounded,
        child: ListView(
          children: [
            Form(
              key: _formKey,
              child: _ResponsiveFields(
                children: [
                  TextFormField(
                    controller: _customerName,
                    decoration: const InputDecoration(labelText: 'اسم العميل'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'مطلوب' : null,
                  ),
                  TextFormField(
                    controller: _customerPersonalId,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'الرقم الشخصي',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'مطلوب';
                      if (text.length != 9) {
                        return 'الرقم الشخصي 9 أرقام بالضبط';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _customerAddress,
                    decoration: const InputDecoration(
                      labelText: 'العنوان (اختياري)',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('كاش')),
                      DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                      DropdownMenuItem(
                        value: 'benefit_pay',
                        child: Text('بنفت باي'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _paymentMethod = value ?? 'cash'),
                  ),
                  DropdownButtonFormField<GulfPhoneCountry>(
                    initialValue: _phoneCountry,
                    decoration: const InputDecoration(labelText: 'الدولة'),
                    items: GulfPhoneCountry.values
                        .map(
                          (country) => DropdownMenuItem(
                            value: country,
                            child: Text('${country.nameAr} +${country.code}'),
                          ),
                        )
                        .toList(),
                    onChanged: (country) {
                      if (country == null) return;
                      setState(() {
                        _phoneCountry = country;
                        if (_customerPhone.text.length > country.localDigits) {
                          _customerPhone.text = _customerPhone.text.substring(
                            0,
                            country.localDigits,
                          );
                        }
                      });
                    },
                  ),
                  TextFormField(
                    controller: _customerPhone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                        _phoneCountry.localDigits,
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'رقم العميل',
                      prefixText: '+${_phoneCountry.code} ',
                      helperText:
                          '${_phoneCountry.localDigits} أرقام بعد مفتاح الدولة',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'مطلوب';
                      if (text.length != _phoneCountry.localDigits) {
                        return 'الرقم يجب أن يكون ${_phoneCountry.localDigits} أرقام';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'منتجات الفاتورة',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (widget.initialProducts.isEmpty)
              const SizedBox(
                height: 90,
                child: Center(
                  child: Text('أضف المنتجات من صفحة المنتجات أولاً'),
                ),
              )
            else
              Column(
                children: widget.initialProducts.map((product) {
                  final grossTotal = _lineGrossTotal(product);
                  final unitPrice = _lineUnitPrice(product);
                  final gramPrice = _lineGramPrice(product);
                  final discount = _lineDiscount(product);
                  final quantity = _lineQuantity(product);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${product.name} | عيار ${product.karat} | ${quantity}x',
                    ),
                    subtitle: Text(
                      'الوزن ${_lineWeight(product).toStringAsFixed(2)}g | سعر الغرام ${gramPrice.toStringAsFixed(3)} BHD | سعر القطعة قبل التخفيض ${unitPrice.toStringAsFixed(3)} BHD | التخفيض ${discount.toStringAsFixed(3)} BHD | المبلغ قبل التخفيض ${grossTotal.toStringAsFixed(3)} BHD',
                    ),
                    trailing: SizedBox(
                      width: 760,
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.iceStrong),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'إنقاص الكمية',
                                  onPressed: quantity <= 1
                                      ? null
                                      : () => _setLineQuantity(
                                          product,
                                          quantity - 1,
                                        ),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                SizedBox(
                                  width: 50,
                                  child: TextField(
                                    controller:
                                        _quantityControllers[product.id],
                                    readOnly: true,
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'زيادة الكمية',
                                  onPressed:
                                      quantity >=
                                          product.quantity.clamp(1, 999999)
                                      ? null
                                      : () => _setLineQuantity(
                                          product,
                                          quantity + 1,
                                        ),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _gramPriceControllers[product.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'سعر الغرام',
                                suffixText: 'BHD',
                              ),
                              onChanged: (_) =>
                                  _syncLineFromGramOrWeight(product),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _weightControllers[product.id],
                              enabled: false,
                              readOnly: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'الغرام',
                                suffixText: 'g',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _piecePriceControllers[product.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'سعر القطعة',
                                suffixText: 'BHD',
                              ),
                              onChanged: (_) =>
                                  _syncLineFromPiecePrice(product),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _discountControllers[product.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'التخفيض',
                                suffixText: 'BHD',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () => _removeFromInvoice(product),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'المجموع: ${_subtotal.toStringAsFixed(3)} BHD | الخصم: ${_discountAmount.toStringAsFixed(3)} BHD | الإجمالي: ${_invoiceTotal.toStringAsFixed(3)} BHD',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: widget.initialProducts.isEmpty || _isSaving
                    ? null
                    : _confirmSale,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payments_outlined),
                label: const Text('العميل دفع - تسجيل البيع'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _paymentMethodLabel(String value) {
  return switch (value) {
    'cash' => 'كاش',
    'card' => 'بطاقة',
    'benefit_pay' => 'بنفت باي',
    _ => value,
  };
}

String _invoiceNumber(double value) {
  value = _safeInvoiceNumber(value);
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < .001) return rounded.toInt().toString();
  return value
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

double _safeInvoiceNumber(double value) =>
    value.isFinite && !value.isNaN ? value : 0;

String _sanitizeFileName(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ');
  return cleaned.isEmpty ? 'Invoice' : cleaned;
}

Future<void> _printOfficialInvoice(
  SaleRecord sale,
  AppDatabase database,
) async {
  final bytes = await _buildOfficialInvoicePdf(sale, database);
  final customerName = sale.customerName.trim().isEmpty
      ? 'عميل نقدي'
      : sale.customerName.trim();
  await Printing.layoutPdf(
    name: '${_sanitizeFileName(customerName)}.pdf',
    onLayout: (_) async => bytes,
  );
}

Future<void> _downloadOfficialInvoice(
  SaleRecord sale,
  AppDatabase database,
) async {
  final bytes = await _buildOfficialInvoicePdf(sale, database);
  final customerName = sale.customerName.trim().isEmpty
      ? 'عميل نقدي'
      : sale.customerName.trim();
  await FilePicker.saveFile(
    dialogTitle: 'حفظ الفاتورة',
    fileName: '${_sanitizeFileName(customerName)}.pdf',
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    bytes: bytes,
  );
}

Future<Uint8List> _buildOfficialInvoicePdf(
  SaleRecord sale,
  AppDatabase database,
) async {
  final settings = await database.getStoreSettings();
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/tahoma.ttf'));
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/tahomabd.ttf'),
  );
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/invoice/image1.png')).buffer.asUint8List(),
  );
  final whatsapp = pw.MemoryImage(
    (await rootBundle.load(
      'assets/invoice/WhatsappImage.png',
    )).buffer.asUint8List(),
  );
  final instagram = pw.MemoryImage(
    (await rootBundle.load(
      'assets/invoice/InstagramImage.png',
    )).buffer.asUint8List(),
  );
  final invoiceDate = DateFormat(
    'dd/MM/yyyy',
    'en',
  ).format((sale.createdAt ?? DateTime.now()).toLocal());
  final customerName = sale.customerName.trim().isEmpty
      ? 'عميل نقدي'
      : sale.customerName.trim();
  final discount = sale.lines.fold<double>(
    0,
    (sum, line) => sum + line.discount,
  );
  final invoiceLines = sale.lines.isEmpty
      ? [
          InvoiceLine(
            productId: 0,
            name: 'فاتورة',
            productType: '',
            karat: 0,
            weight: 0,
            quantity: 1,
            unitPrice: sale.total,
            discount: sale.discount,
            total: sale.total,
          ),
        ]
      : sale.lines;
  final subtotal = invoiceLines.fold<double>(
    0,
    (sum, line) => sum + line.total + line.discount,
  );
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(base: font, bold: boldFont);
  const gold = PdfColor.fromInt(0xFFC8922A);
  const ink = PdfColor.fromInt(0xFF1F2933);
  const light = PdfColor.fromInt(0xFFF6F1E7);

  pw.Widget rtlText(
    String value, {
    double fontSize = 8,
    pw.Font? font,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Text(
        value.trim().isEmpty ? '-' : value.trim(),
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: fontSize, color: color),
      ),
    );
  }

  pw.Widget infoCell(String ar, String en, String value) {
    final shown = value.trim().isEmpty ? '-' : value.trim();
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: .7),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(en, style: pw.TextStyle(fontSize: 8, color: ink)),
          ),
          pw.Expanded(child: rtlText(shown, font: boldFont, fontSize: 9)),
          pw.Expanded(
            child: pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Text(
                ar,
                style: pw.TextStyle(font: boldFont, fontSize: 8, color: ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget money(double value) => pw.Text(
    value.toStringAsFixed(3),
    textAlign: pw.TextAlign.center,
    style: const pw.TextStyle(fontSize: 8),
  );

  pw.Widget tableCell(pw.Widget child, {PdfColor? color, double vertical = 6}) {
    return pw.Container(
      color: color,
      padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: vertical),
      alignment: pw.Alignment.center,
      child: child,
    );
  }

  pw.TableRow headerRow(List<String> cells, {PdfColor? color}) {
    return pw.TableRow(
      children: cells
          .map(
            (cell) => tableCell(
              pw.Text(
                cell,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: boldFont, fontSize: 7.5, color: ink),
              ),
              color: color,
              vertical: 4.5,
            ),
          )
          .toList(),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 26),
        theme: theme,
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(height: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Directionality(
                  textDirection: pw.TextDirection.ltr,
                  child: pw.Row(
                    children: [
                      pw.Image(whatsapp, width: 168, height: 168),
                      pw.SizedBox(width: 14),
                      pw.Image(instagram, width: 168, height: 168),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Directionality(
                    textDirection: pw.TextDirection.rtl,
                    child: pw.Text(
                      'مبنى: 1009 - طريق: 2331 - مجمع: 423 - جدحفص',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Center(child: pw.Image(logo, width: 250)),
        pw.SizedBox(height: 8),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            children: [
              pw.Center(
                child: pw.Text(
                  'فاتورة',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 18,
                    color: gold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'التاريخ: $invoiceDate',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'CR: ${settings.taxNumber.trim().isEmpty ? '-' : settings.taxNumber.trim()}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Container(height: 2, color: gold),
        pw.SizedBox(height: 12),
        infoCell('اسم العميل', 'Customer Name', customerName),
        infoCell('رقم الهاتف', 'Phone Number', sale.customerPhone),
        infoCell('الرقم الشخصي', 'Personal ID', sale.customerPersonalId),
        infoCell('العنوان', 'Address', sale.customerAddress),
        infoCell(
          'طريقة الدفع',
          'Payment Method',
          _paymentMethodLabel(sale.paymentMethod),
        ),
        pw.SizedBox(height: 14),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .7),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.15),
              1: pw.FlexColumnWidth(.8),
              2: pw.FlexColumnWidth(1.0),
              3: pw.FlexColumnWidth(.9),
              4: pw.FlexColumnWidth(1.1),
              5: pw.FlexColumnWidth(1.0),
              6: pw.FlexColumnWidth(1.2),
            },
            children: [
              headerRow(const [
                'الوصف (Description)',
                'الكمية (Qty)',
                'الوزن (Weight/grams)',
                'العيار (Karat)',
                'سعر القطعة (Item Price) BHD',
                'التخفيض (Discount) BHD',
                'المبلغ (Amount) BHD',
              ], color: light),
              ...invoiceLines.map((line) {
                final description = line.name.trim();
                return pw.TableRow(
                  children: [
                    tableCell(rtlText(description, align: pw.TextAlign.right)),
                    tableCell(pw.Text(line.quantity.toString())),
                    tableCell(pw.Text(line.weight.toStringAsFixed(3))),
                    tableCell(pw.Text(line.karat.toString())),
                    tableCell(money(line.unitPrice)),
                    tableCell(money(line.discount)),
                    tableCell(money(line.total)),
                  ],
                );
              }),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.start,
          children: [
            pw.Container(
              width: 230,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: gold, width: 1),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: rtlText('المجموع', font: boldFont)),
                      pw.Expanded(child: money(subtotal)),
                    ],
                  ),
                  pw.Divider(color: gold, height: 1),
                  pw.Row(
                    children: [
                      pw.Expanded(child: rtlText('التخفيض', font: boldFont)),
                      pw.Expanded(child: money(discount + sale.discount)),
                    ],
                  ),
                  pw.Divider(color: gold, height: 1),
                  pw.Container(
                    color: light,
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Row(
                      children: [
                        pw.Expanded(child: rtlText('الإجمالي', font: boldFont)),
                        pw.Expanded(
                          child: pw.Text(
                            '${(subtotal - (discount + sale.discount)).clamp(0, double.infinity).toStringAsFixed(3)} BHD',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: boldFont),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

class SalesLedgerPage extends StatefulWidget {
  const SalesLedgerPage({
    super.key,
    required this.database,
    required this.user,
  });

  final AppDatabase database;
  final AppUser user;

  @override
  State<SalesLedgerPage> createState() => _SalesLedgerPageState();
}

class InventoryAuditPage extends StatefulWidget {
  const InventoryAuditPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<InventoryAuditPage> createState() => _InventoryAuditPageState();
}

class _InventoryAuditPageState extends State<InventoryAuditPage> {
  late Future<List<ProductItem>> _future;
  DateTime _date = DateTime.now();
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _future = widget.database.getProducts();
  }

  List<ProductItem> _filtered(List<ProductItem> products) {
    return products.where((product) {
      final created = product.createdAt.toLocal();
      final sameDay =
          created.year == _date.year &&
          created.month == _date.month &&
          created.day == _date.day;
      final statusMatch =
          _status == 'all' ||
          (_status == 'available' && product.isAvailable) ||
          (_status == 'sold' && !product.isAvailable);
      return sameDay && statusMatch;
    }).toList();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setState(() => _date = selected);
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'جرد القطع',
      subtitle: 'متابعة القطع المتوفرة والمباعة حسب اليوم للمقارنة.',
      child: _Surface(
        title: 'حركة القطع اليومية',
        icon: Icons.fact_check_outlined,
        child: Column(
          children: [
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(DateFormat('yyyy/MM/dd').format(_date)),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('الكل')),
                      DropdownMenuItem(
                        value: 'available',
                        child: Text('المتوفر'),
                      ),
                      DropdownMenuItem(value: 'sold', child: Text('المباع')),
                    ],
                    onChanged: (value) =>
                        setState(() => _status = value ?? 'all'),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: () => setState(() {
                    _future = widget.database.getProducts();
                  }),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<List<ProductItem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = _filtered(snapshot.data ?? const []);
                  final available = rows
                      .where((item) => item.isAvailable)
                      .fold<int>(0, (sum, item) => sum + item.quantity);
                  final sold = rows
                      .where((item) => !item.isAvailable)
                      .fold<int>(0, (sum, item) => sum + item.quantity);
                  if (rows.isEmpty) {
                    return const Center(child: Text('لا توجد قطع لهذا اليوم'));
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              'المتوفر',
                              '$available',
                              Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatTile(
                              'المباع',
                              '$sold',
                              Icons.sell_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = rows[index];
                            return ListTile(
                              title: Text(item.name),
                              subtitle: Text(
                                '${item.productType} | عيار ${item.karat} | ${item.weight.toStringAsFixed(2)}g',
                              ),
                              trailing: Text(
                                item.isAvailable
                                    ? '${item.quantity}x متوفر'
                                    : 'مباع ${item.quantity}x',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesLedgerPageState extends State<SalesLedgerPage> {
  final _search = TextEditingController();
  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();
  late Future<List<PurchaseLedgerRow>> _future;
  bool _isBusy = false;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _future = widget.database.salesLedger();
  }

  @override
  void dispose() {
    _search.dispose();
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.database.salesLedger(
        search: _search.text,
        fromDate: _fromDate,
        toDate: _toDate,
      );
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = selected;
      } else {
        _toDate = selected;
      }
    });
    _reload();
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _reload();
  }

  void _setPeriod(Duration? duration, {bool year = false}) {
    final now = DateTime.now();
    setState(() {
      _toDate = now;
      if (year) {
        _fromDate = DateTime(now.year, 1, 1);
      } else {
        _fromDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(duration ?? Duration.zero);
      }
    });
    _reload();
  }

  Future<void> _import() async {
    setState(() => _isBusy = true);
    try {
      final count = await widget.database.importSalesCsv();
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _future = widget.database.salesLedger(search: _search.text);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم استيراد $count فاتورة')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر الاستيراد: $error')));
    }
  }

  Future<void> _export() async {
    setState(() => _isBusy = true);
    try {
      await widget.database.exportSalesCsv(day: DateTime.now());
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تجهيز ملف Excel/CSV')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر التصدير: $error')));
    }
  }

  Future<void> _downloadInvoice(PurchaseLedgerRow row) async {
    setState(() => _isBusy = true);
    try {
      final sale = await widget.database.saleRecord(row.saleId);
      await _downloadOfficialInvoice(sale, widget.database);
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تجهيز ملف الفاتورة')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تنزيل الفاتورة: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'المبيعات والعملاء',
      subtitle: 'كل العملاء الذين اشتروا في جدول واحد، مع بحث وفلترة بالتاريخ.',
      child: _Surface(
        title: 'سجل المشتريات',
        icon: Icons.manage_search_rounded,
        child: Column(
          children: [
            _SalesToolbar(
              search: _search,
              fromDate: _fromDate,
              toDate: _toDate,
              isBusy: _isBusy,
              onSearchChanged: (_) => _reload(),
              onPickFrom: () => _pickDate(isFrom: true),
              onPickTo: () => _pickDate(isFrom: false),
              onClearDates: _clearDateFilter,
              onToday: () => _setPeriod(Duration.zero),
              onWeek: () => _setPeriod(const Duration(days: 6)),
              onMonth: () => _setPeriod(const Duration(days: 29)),
              onYear: () => _setPeriod(null, year: true),
              onImport: _import,
              onExport: _export,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<List<PurchaseLedgerRow>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snapshot.data ?? const <PurchaseLedgerRow>[];
                  if (rows.isEmpty) {
                    return const Center(child: Text('لا توجد مبيعات مطابقة'));
                  }
                  return ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: Scrollbar(
                      controller: _horizontalScroll,
                      thumbVisibility: true,
                      notificationPredicate: (notification) =>
                          notification.metrics.axis == Axis.horizontal,
                      child: SingleChildScrollView(
                        controller: _horizontalScroll,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 1160),
                          child: SingleChildScrollView(
                            controller: _verticalScroll,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('التاريخ')),
                                DataColumn(label: Text('العميل')),
                                DataColumn(label: Text('الرقم الشخصي')),
                                DataColumn(label: Text('طريقة الدفع')),
                                DataColumn(label: Text('الهاتف')),
                                DataColumn(label: Text('المنتجات')),
                                DataColumn(label: Text('المجموع')),
                                DataColumn(label: Text('الفاتورة')),
                              ],
                              rows: rows.map((row) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        DateFormat(
                                          'yyyy/MM/dd h:mm a',
                                          'ar',
                                        ).format(row.createdAt.toLocal()),
                                      ),
                                    ),
                                    DataCell(Text(row.customerName)),
                                    DataCell(Text(row.customerPersonalId)),
                                    DataCell(
                                      Text(
                                        _paymentMethodLabel(row.paymentMethod),
                                      ),
                                    ),
                                    DataCell(Text(row.customerPhone)),
                                    DataCell(
                                      SizedBox(
                                        width: 260,
                                        child: Text(
                                          row.productsSummary,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${row.total.toStringAsFixed(3)} BHD',
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        tooltip: 'تنزيل الفاتورة',
                                        onPressed: _isBusy
                                            ? null
                                            : () => _downloadInvoice(row),
                                        icon: const Icon(
                                          Icons.description_rounded,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesToolbar extends StatelessWidget {
  const _SalesToolbar({
    required this.search,
    required this.fromDate,
    required this.toDate,
    required this.isBusy,
    required this.onSearchChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearDates,
    required this.onToday,
    required this.onWeek,
    required this.onMonth,
    required this.onYear,
    required this.onImport,
    required this.onExport,
  });

  final TextEditingController search;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool isBusy;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearDates;
  final VoidCallback onToday;
  final VoidCallback onWeek;
  final VoidCallback onMonth;
  final VoidCallback onYear;
  final VoidCallback onImport;
  final VoidCallback onExport;

  String _dateLabel(String label, DateTime? date) {
    if (date == null) return label;
    return DateFormat('yyyy/MM/dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;
        final searchField = TextField(
          controller: search,
          decoration: const InputDecoration(
            labelText: 'بحث بالاسم، الهاتف، الرقم الشخصي أو المنتج',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: onSearchChanged,
        );
        final dateActions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: onToday, child: const Text('يوم')),
            TextButton(onPressed: onWeek, child: const Text('أسبوع')),
            TextButton(onPressed: onMonth, child: const Text('شهر')),
            TextButton(onPressed: onYear, child: const Text('سنة')),
            OutlinedButton.icon(
              onPressed: onPickFrom,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(_dateLabel('من تاريخ', fromDate)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onPickTo,
              icon: const Icon(Icons.event_rounded),
              label: Text(_dateLabel('إلى تاريخ', toDate)),
            ),
            if (fromDate != null || toDate != null) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'مسح فلتر التاريخ',
                onPressed: onClearDates,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ],
        );
        final fileActions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonalIcon(
              onPressed: isBusy ? null : onImport,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('استيراد'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: isBusy ? null : onExport,
              icon: const Icon(Icons.table_view_rounded),
              label: const Text('Excel'),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: dateActions,
              ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: fileActions),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            dateActions,
            const SizedBox(width: 12),
            fileActions,
          ],
        );
      },
    );
  }
}

class _HeroPreview extends StatelessWidget {
  const _HeroPreview({required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('نواة النظام', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 22),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Icon(
                Icons.point_of_sale_rounded,
                size: 86,
                color: AppColors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 22),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A7AAFD6),
            blurRadius: 38,
            offset: Offset(0, 22),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.blue),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.iceStrong,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldPriceRow extends StatelessWidget {
  const _GoldPriceRow(this.label, this.buyPrice, this.sellPrice);

  final String label;
  final double buyPrice;
  final double sellPrice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          Text('شراء ${buyPrice.toStringAsFixed(3)} BHD'),
          const SizedBox(width: 18),
          Text('بيع ${sellPrice.toStringAsFixed(3)} BHD'),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
          const SizedBox(width: 10),
          Text(text),
        ],
      ),
    );
  }
}

class _AssetPicker extends StatelessWidget {
  const _AssetPicker({
    required this.title,
    required this.bytes,
    required this.onPick,
  });

  final String title;
  final Uint8List? bytes;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.ice,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: bytes == null
                  ? const Icon(
                      Icons.image_outlined,
                      size: 42,
                      color: AppColors.muted,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(bytes!, fit: BoxFit.contain),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'استيراد',
                  onPressed: onPick,
                  icon: const Icon(Icons.upload_file_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraCaptureDialog extends StatefulWidget {
  const _CameraCaptureDialog();

  @override
  State<_CameraCaptureDialog> createState() => _CameraCaptureDialogState();
}

class _CameraCaptureDialogState extends State<_CameraCaptureDialog> {
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  int _cameraId = -1;
  Size? _previewSize;
  bool _isReady = false;
  bool _isBusy = true;
  String _message = 'جاري فتح الكاميرا';

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  @override
  void dispose() {
    _disposeCamera();
    super.dispose();
  }

  Future<void> _openCamera() async {
    setState(() {
      _isBusy = true;
      _message = 'جاري فتح الكاميرا';
    });

    try {
      final cameras = await CameraPlatform.instance.availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameras = const [];
          _isBusy = false;
          _message = 'لا توجد كاميرا متصلة';
        });
        return;
      }

      final camera = cameras[_cameraIndex % cameras.length];
      final cameraId = await CameraPlatform.instance.createCameraWithSettings(
        camera,
        const MediaSettings(
          resolutionPreset: ResolutionPreset.medium,
          fps: 15,
          videoBitrate: 200000,
          audioBitrate: 32000,
          enableAudio: false,
        ),
      );
      final initialized = CameraPlatform.instance
          .onCameraInitialized(cameraId)
          .first;
      await CameraPlatform.instance.initializeCamera(cameraId);
      final event = await initialized;
      setState(() {
        _cameras = cameras;
        _cameraId = cameraId;
        _previewSize = Size(event.previewWidth, event.previewHeight);
        _isReady = true;
        _isBusy = false;
        _message = camera.name;
      });
    } catch (error) {
      setState(() {
        _isReady = false;
        _isBusy = false;
        _message = 'تعذر فتح الكاميرا: $error';
      });
    }
  }

  Future<void> _disposeCamera() async {
    final cameraId = _cameraId;
    if (cameraId < 0) return;
    _cameraId = -1;
    _isReady = false;
    await CameraPlatform.instance.dispose(cameraId);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isBusy) return;
    await _disposeCamera();
    setState(() => _cameraIndex = (_cameraIndex + 1) % _cameras.length);
    await _openCamera();
  }

  Future<void> _takePicture() async {
    if (!_isReady || _cameraId < 0 || _isBusy) return;
    setState(() => _isBusy = true);
    try {
      final file = await CameraPlatform.instance.takePicture(_cameraId);
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (error) {
      setState(() {
        _isBusy = false;
        _message = 'تعذر التقاط الصورة: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewSize = _previewSize;
    return AlertDialog(
      title: const Text('كاميرا المنتج'),
      content: SizedBox(
        width: 620,
        height: 430,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isReady && previewSize != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: previewSize.width / previewSize.height,
                          child: CameraPlatform.instance.buildPreview(
                            _cameraId,
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _message,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(_message, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        if (_cameras.length > 1)
          TextButton.icon(
            onPressed: _isBusy ? null : _switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
            label: const Text('تبديل'),
          ),
        FilledButton.icon(
          onPressed: _isReady && !_isBusy ? _takePicture : null,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('التقاط'),
        ),
      ],
    );
  }
}

class _ProductsToolbar extends StatelessWidget {
  const _ProductsToolbar({
    required this.search,
    required this.karatFilter,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onKaratChanged,
    required this.onStatusChanged,
    required this.onAdd,
  });

  final TextEditingController search;
  final int? karatFilter;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onKaratChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final searchField = TextField(
          controller: search,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'بحث بالاسم أو النوع',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        );
        final filterField = DropdownButtonFormField<int?>(
          initialValue: karatFilter,
          decoration: const InputDecoration(
            labelText: 'فلتر العيار',
            prefixIcon: Icon(Icons.workspace_premium_outlined),
          ),
          items: const [
            DropdownMenuItem<int?>(value: null, child: Text('كل العيارات')),
            DropdownMenuItem<int?>(value: 24, child: Text('عيار 24')),
            DropdownMenuItem<int?>(value: 22, child: Text('عيار 22')),
            DropdownMenuItem<int?>(value: 21, child: Text('عيار 21')),
            DropdownMenuItem<int?>(value: 18, child: Text('عيار 18')),
          ],
          onChanged: onKaratChanged,
        );
        final statusField = DropdownButtonFormField<String>(
          initialValue: statusFilter,
          decoration: const InputDecoration(
            labelText: 'التوفر',
            prefixIcon: Icon(Icons.fact_check_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('الكل')),
            DropdownMenuItem(value: 'available', child: Text('المتوفر')),
            DropdownMenuItem(value: 'sold', child: Text('المباع')),
          ],
          onChanged: onStatusChanged,
        );
        final addButton = SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة'),
          ),
        );

        if (compact) {
          return Column(
            children: [
              searchField,
              const SizedBox(height: 12),
              filterField,
              const SizedBox(height: 12),
              statusField,
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: addButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: searchField),
            const SizedBox(width: 12),
            SizedBox(width: 220, child: filterField),
            const SizedBox(width: 12),
            SizedBox(width: 180, child: statusField),
            const SizedBox(width: 12),
            SizedBox(width: 132, child: addButton),
          ],
        );
      },
    );
  }
}

class _AddProductForm extends StatelessWidget {
  const _AddProductForm({
    required this.formKey,
    required this.title,
    required this.saveLabel,
    required this.name,
    required this.type,
    required this.weight,
    required this.quantity,
    required this.karat,
    required this.imageBytes,
    required this.onKaratChanged,
    required this.onPickImage,
    required this.onCaptureImage,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String saveLabel;
  final TextEditingController name;
  final TextEditingController type;
  final TextEditingController weight;
  final TextEditingController quantity;
  final int karat;
  final Uint8List? imageBytes;
  final ValueChanged<int?> onKaratChanged;
  final VoidCallback onPickImage;
  final VoidCallback onCaptureImage;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.iceStrong,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_box_outlined,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 18),
            _ProductImageBox(
              bytes: imageBytes,
              onPick: onPickImage,
              onCapture: onCaptureImage,
            ),
            const SizedBox(height: 16),
            _ResponsiveFields(
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج',
                    prefixIcon: Icon(Icons.diamond_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: type,
                  decoration: const InputDecoration(
                    labelText: 'النوع',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'مطلوب' : null,
                ),
                DropdownButtonFormField<int>(
                  initialValue: karat,
                  decoration: const InputDecoration(
                    labelText: 'العيار',
                    prefixIcon: Icon(Icons.workspace_premium_outlined),
                  ),
                  items: const [24, 22, 21, 18]
                      .map(
                        (karat) => DropdownMenuItem(
                          value: karat,
                          child: Text('عيار $karat'),
                        ),
                      )
                      .toList(),
                  onChanged: onKaratChanged,
                ),
                TextFormField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'الوزن بالجرام',
                    prefixIcon: Icon(Icons.scale_outlined),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) return 'وزن غير صحيح';
                    return null;
                  },
                ),
                TextFormField(
                  controller: quantity,
                  readOnly: true,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'الكمية',
                    prefixIcon: const Icon(Icons.numbers_rounded),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'إنقاص الكمية',
                          onPressed: () {
                            final current =
                                int.tryParse(quantity.text.trim()) ?? 1;
                            final next = (current - 1).clamp(1, 999999);
                            quantity.text = next.toString();
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          tooltip: 'زيادة الكمية',
                          onPressed: () {
                            final current =
                                int.tryParse(quantity.text.trim()) ?? 1;
                            final next = (current + 1).clamp(1, 999999);
                            quantity.text = next.toString();
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) return 'كمية غير صحيحة';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
                label: Text(saveLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImageBox extends StatelessWidget {
  const _ProductImageBox({
    required this.bytes,
    required this.onPick,
    required this.onCapture,
  });

  final Uint8List? bytes;
  final VoidCallback onPick;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: AppColors.ice,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: bytes == null
                ? const Center(
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.muted,
                      size: 44,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(bytes!, fit: BoxFit.cover),
                  ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('كاميرا'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onPick,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('استيراد'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isInInvoice,
    required this.onAddToInvoice,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductItem product;
  final bool isInInvoice;
  final VoidCallback onAddToInvoice;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: AppColors.ice,
              child: product.imageBytes == null && product.imageUrl == null
                  ? const Center(
                      child: Icon(
                        Icons.diamond_outlined,
                        color: AppColors.blue,
                        size: 44,
                      ),
                    )
                  : product.imageBytes != null
                  ? Image.memory(product.imageBytes!, fit: BoxFit.cover)
                  : Image.network(product.imageUrl!, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _StatusPill(isAvailable: product.isAvailable),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.productType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('عيار ${product.karat}'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${product.weight.toStringAsFixed(2)}g | ${product.isAvailable ? '${product.quantity}x' : 'مباع ${product.quantity}x'}',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: product.isAvailable && !isInInvoice
                            ? onAddToInvoice
                            : null,
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: Text(
                          !product.isAvailable
                              ? 'مباعة'
                              : isInInvoice
                              ? 'مضافة'
                              : 'إضافة',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'تعديل',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: 'حذف',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isAvailable});

  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isAvailable ? AppColors.iceStrong : AppColors.border,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isAvailable ? 'متوفر' : 'مباع',
        style: const TextStyle(fontSize: 12, letterSpacing: 0),
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth > 820
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map((child) => SizedBox(width: fieldWidth, child: child))
              .toList(),
        );
      },
    );
  }
}
