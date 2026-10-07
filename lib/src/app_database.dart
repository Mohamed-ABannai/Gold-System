import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

enum StoreAssetType { logo, stamp }

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String username;
  final String fullName;
  final String role;

  factory AppUser.fromMap(Map<String, Object?> map) {
    return AppUser(
      id: (map['id'] as num).toInt(),
      username: map['username'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
    );
  }
}

class ProductItem {
  const ProductItem({
    required this.id,
    required this.name,
    required this.productType,
    required this.karat,
    required this.weight,
    required this.quantity,
    required this.status,
    required this.createdAt,
    this.imageBytes,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String productType;
  final int karat;
  final double weight;
  final int quantity;
  final String status;
  final DateTime createdAt;
  final Uint8List? imageBytes;
  final String? imageUrl;

  bool get isAvailable => status == 'available';

  factory ProductItem.fromMap(Map<String, Object?> map) {
    return ProductItem(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String,
      productType: (map['product_type'] as String?) ?? '',
      karat: (map['karat'] as num).toInt(),
      weight: (map['weight'] as num).toDouble(),
      quantity: ((map['quantity'] as num?) ?? 1).toInt(),
      status: (map['status'] as String?) ?? 'available',
      createdAt: DateTime.parse(map['created_at'] as String),
      imageUrl: map['image_url'] as String?,
    );
  }
}

class InvoiceLine {
  const InvoiceLine({
    required this.productId,
    required this.name,
    required this.productType,
    required this.karat,
    required this.weight,
    required this.unitPrice,
    this.discount = 0,
    required this.quantity,
    required this.total,
  });

  final int productId;
  final String name;
  final String productType;
  final int karat;
  final double weight;
  final double unitPrice;
  final double discount;
  final int quantity;
  final double total;

  factory InvoiceLine.fromProduct(
    ProductItem product,
    double unitPrice, {
    double discount = 0,
    int quantity = 1,
  }) {
    final safeQuantity = quantity.clamp(1, product.quantity.clamp(1, 999999));
    final safeUnitPrice = _safeMoney(unitPrice);
    final grossTotal = safeUnitPrice * safeQuantity;
    return InvoiceLine.fromProductTotal(
      product,
      grossTotal,
      discount: discount,
      quantity: safeQuantity,
    );
  }

  factory InvoiceLine.fromProductTotal(
    ProductItem product,
    double grossTotal, {
    double discount = 0,
    int quantity = 1,
  }) {
    final safeGrossTotal = _safeMoney(grossTotal);
    final safeDiscount = _safeMoney(discount);
    final safeQuantity = quantity.clamp(1, product.quantity.clamp(1, 999999));
    final netTotal = (safeGrossTotal - safeDiscount).clamp(0, double.infinity);
    return InvoiceLine(
      productId: product.id,
      name: product.name,
      productType: product.productType,
      karat: product.karat,
      weight: product.weight,
      quantity: safeQuantity,
      unitPrice: safeQuantity <= 0 ? safeGrossTotal : safeGrossTotal / safeQuantity,
      discount: safeDiscount,
      total: netTotal.toDouble(),
    );
  }

  factory InvoiceLine.fromMap(Map<String, Object?> map) {
    final weight = ((map['weight'] as num?) ?? 0).toDouble();
    final total = ((map['total'] as num?) ?? 0).toDouble();
    final safeQuantity = ((map['quantity'] as num?) ?? 1).toInt().clamp(1, 999999);
    return InvoiceLine(
      productId: ((map['product_id'] as num?) ?? 0).toInt(),
      name: (map['name'] as String?) ?? '',
      productType: (map['product_type'] as String?) ?? '',
      karat: ((map['karat'] as num?) ?? 0).toInt(),
      weight: weight,
      quantity: safeQuantity,
      unitPrice:
          ((map['unit_price'] as num?) ??
                  (safeQuantity <= 0 ? total : total / safeQuantity))
              .toDouble(),
      discount: ((map['discount'] as num?) ?? 0).toDouble(),
      total: total,
    );
  }
}

double _safeMoney(double value) => value.isFinite && !value.isNaN ? value : 0;

String _paymentMethodExportLabel(String method) {
  switch (method) {
    case 'cash':
      return 'كاش';
    case 'card':
      return 'بطاقة';
    case 'benefit_pay':
      return 'بنفت باي';
    default:
      return method;
  }
}

class SaleRecord {
  const SaleRecord({
    this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.total,
    required this.lines,
    this.customerPersonalId = '',
    this.customerAddress = '',
    this.paymentMethod = '',
    this.discount = 0,
    this.createdAt,
  });

  final int? id;
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final double total;
  final List<InvoiceLine> lines;
  final String customerPersonalId;
  final String customerAddress;
  final String paymentMethod;
  final double discount;
  final DateTime? createdAt;
}

class PurchaseLedgerRow {
  const PurchaseLedgerRow({
    required this.saleId,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.customerPersonalId,
    required this.paymentMethod,
    required this.total,
    required this.createdAt,
    required this.productsSummary,
  });

  final int saleId;
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final String customerPersonalId;
  final String paymentMethod;
  final double total;
  final DateTime createdAt;
  final String productsSummary;

  factory PurchaseLedgerRow.fromMap(Map<String, Object?> map) {
    return PurchaseLedgerRow(
      saleId: (map['sale_id'] as num).toInt(),
      invoiceNumber: map['invoice_number'] as String,
      customerName: (map['customer_name'] as String?) ?? '',
      customerPhone: (map['customer_phone'] as String?) ?? '',
      customerPersonalId: (map['customer_personal_id'] as String?) ?? '',
      paymentMethod: (map['payment_method'] as String?) ?? '',
      total: ((map['total'] as num?) ?? 0).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      productsSummary: (map['products_summary'] as String?) ?? '',
    );
  }
}

class SoldItemRow {
  const SoldItemRow({
    required this.invoiceNumber,
    required this.customerName,
    required this.createdAt,
    required this.name,
    required this.productType,
    required this.karat,
    required this.weight,
    required this.total,
  });

  final String invoiceNumber;
  final String customerName;
  final DateTime createdAt;
  final String name;
  final String productType;
  final int karat;
  final double weight;
  final double total;

  factory SoldItemRow.fromMap(Map<String, Object?> map) {
    return SoldItemRow(
      invoiceNumber: map['invoice_number'] as String,
      customerName: (map['customer_name'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      name: map['name'] as String,
      productType: (map['product_type'] as String?) ?? '',
      karat: (map['karat'] as num).toInt(),
      weight: ((map['weight'] as num?) ?? 0).toDouble(),
      total: ((map['total'] as num?) ?? 0).toDouble(),
    );
  }
}

class StoreSettings {
  const StoreSettings({
    required this.storeName,
    required this.taxNumber,
    required this.phone,
    required this.address,
    required this.logoBytes,
    required this.stampBytes,
    this.logoPath,
    this.stampPath,
  });

  final String storeName;
  final String taxNumber;
  final String phone;
  final String address;
  final Uint8List? logoBytes;
  final Uint8List? stampBytes;
  final String? logoPath;
  final String? stampPath;

  factory StoreSettings.defaults() {
    return const StoreSettings(
      storeName: 'محل الذهب',
      taxNumber: '',
      phone: '',
      address: '',
      logoBytes: null,
      stampBytes: null,
    );
  }

  factory StoreSettings.fromMap(
    Map<String, Object?> map, {
    Uint8List? logoBytes,
    Uint8List? stampBytes,
  }) {
    return StoreSettings(
      storeName: (map['store_name'] as String?) ?? 'محل الذهب',
      taxNumber: (map['tax_number'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      logoBytes: logoBytes,
      stampBytes: stampBytes,
      logoPath: map['logo_path'] as String?,
      stampPath: map['stamp_path'] as String?,
    );
  }

  StoreSettings copyWith({
    String? storeName,
    String? taxNumber,
    String? phone,
    String? address,
    Uint8List? logoBytes,
    Uint8List? stampBytes,
    String? logoPath,
    String? stampPath,
  }) {
    return StoreSettings(
      storeName: storeName ?? this.storeName,
      taxNumber: taxNumber ?? this.taxNumber,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      logoBytes: logoBytes ?? this.logoBytes,
      stampBytes: stampBytes ?? this.stampBytes,
      logoPath: logoPath ?? this.logoPath,
      stampPath: stampPath ?? this.stampPath,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': 1,
      'store_name': storeName,
      'tax_number': taxNumber,
      'phone': phone,
      'address': address,
      'logo_path': logoPath,
      'stamp_path': stampPath,
    };
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.karat24,
    required this.karat22,
    required this.karat21,
    required this.karat18,
    required this.todaySales,
    required this.availableProducts,
    required this.lastGoldUpdate,
  });

  final double karat24;
  final double karat22;
  final double karat21;
  final double karat18;
  final double todaySales;
  final int availableProducts;
  final String lastGoldUpdate;

  factory DashboardSnapshot.empty() {
    return const DashboardSnapshot(
      karat24: 143.553,
      karat22: 131.591,
      karat21: 125.609,
      karat18: 107.665,
      todaySales: 0,
      availableProducts: 0,
      lastGoldUpdate: 'غير محدد',
    );
  }
}

class AppDatabase {
  static const supabaseUrl = 'https://rufqsbdvbjrfisqjcykf.supabase.co/rest/v1/';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ1ZnFzYmR2YmpyZmlzcWpjeWtmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU0ODIzMDIsImV4cCI6MjEwMTA1ODMwMn0.pW4574_IjTqXrowDyoiLQ0H_iQxN0eu984upes5iI5w';

  static String get _baseUrl {
    final url = supabaseUrl.trim();
    if (url.endsWith('/rest/v1/')) {
      return url.substring(0, url.length - 9);
    }
    if (url.endsWith('/rest/v1')) {
      return url.substring(0, url.length - 8);
    }
    return url;
  }

  Future<void> init() async {
    await _seedDefaults();
  }

  Future<void> _seedDefaults() async {
    await _upsert('users', [
      {
        'username': 'Khalil',
        'password_hash': _hashPassword('Kk123456@@'),
        'full_name': 'Khalil',
        'role': 'employee',
      },
      {
        'username': 'abbas',
        'password_hash': _hashPassword('Am123456@@'),
        'full_name': 'abbas',
        'role': 'employee',
      },
    ], onConflict: 'username');

    final settings = await _single('store_settings', 'select=id&id=eq.1');
    if (settings == null) {
      await _insert('store_settings', StoreSettings.defaults().toMap());
    }

    final existingPrices = await _select('gold_prices', 'select=karat');
    final existingKarats = existingPrices
        .map((row) => (row['karat'] as num).toInt())
        .toSet();
    final missing = [
      {'karat': 24, 'buy_price_per_gram': 143.553, 'margin_percent': 5.0},
      {'karat': 22, 'buy_price_per_gram': 131.591, 'margin_percent': 5.0},
      {'karat': 21, 'buy_price_per_gram': 125.609, 'margin_percent': 5.0},
      {'karat': 18, 'buy_price_per_gram': 107.665, 'margin_percent': 5.0},
    ].where((row) => !existingKarats.contains(row['karat'])).toList();
    if (missing.isNotEmpty) await _insert('gold_prices', missing);
  }

  Future<AppUser?> login(String username, String password) async {
    final row = await _single(
      'users',
      'select=*&username=eq.${_enc(username)}&password_hash=eq.${_hashPassword(password)}',
    );
    return row == null ? null : AppUser.fromMap(row);
  }

  Future<StoreSettings> getStoreSettings() async {
    final row = await _single('store_settings', 'select=*&id=eq.1');
    if (row == null) return StoreSettings.defaults();
    return StoreSettings.fromMap(
      row,
      logoBytes: await _downloadStoreAsset(row['logo_path'] as String?),
      stampBytes: await _downloadStoreAsset(row['stamp_path'] as String?),
    );
  }

  Future<void> saveStoreSettings(StoreSettings settings) async {
    await _upsert('store_settings', settings.toMap(), onConflict: 'id');
  }

  Future<StoreSettings?> pickAndSaveStoreAsset(StoreAssetType type) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return null;

    final file = result.files.single;
    final path = _assetPath(type, file.name);
    await _uploadStorage(
      bucket: 'store-assets',
      path: path,
      bytes: file.bytes!,
      contentType: _contentTypeForName(file.name),
    );

    final current = await getStoreSettings();
    final updated = switch (type) {
      StoreAssetType.logo => current.copyWith(
        logoBytes: file.bytes,
        logoPath: path,
      ),
      StoreAssetType.stamp => current.copyWith(
        stampBytes: file.bytes,
        stampPath: path,
      ),
    };
    await saveStoreSettings(updated);
    return updated;
  }

  Future<Uint8List?> pickImageBytes() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    return result?.files.single.bytes;
  }

  Future<List<ProductItem>> getProducts({bool availableOnly = false}) async {
    final filter = availableOnly ? '&status=eq.available' : '';
    final rows = await _select(
      'products',
      'select=*&order=product_type.asc,status.asc,created_at.desc$filter',
    );
    return rows.map(ProductItem.fromMap).toList();
  }

  Future<void> addProduct({
    required String name,
    required String productType,
    required int karat,
    required double weight,
    required int quantity,
    Uint8List? imageBytes,
  }) async {
    String? imagePath;
    String? imageUrl;
    if (imageBytes != null) {
      imagePath =
          '${DateTime.now().millisecondsSinceEpoch}_${_safeFilePart(name)}.jpg';
      await _uploadStorage(
        bucket: 'product-images',
        path: imagePath,
        bytes: imageBytes,
        contentType: 'image/jpeg',
      );
      imageUrl = _publicStorageUrl('product-images', imagePath);
    }

    await _insert('products', {
      'name': name,
      'product_type': productType,
      'karat': karat,
      'weight': weight,
      'quantity': quantity,
      'image_path': imagePath,
      'image_url': imageUrl,
      'status': 'available',
    });
  }

  Future<void> updateProduct({
    required int id,
    required String name,
    required String productType,
    required int karat,
    required double weight,
    required int quantity,
    Uint8List? imageBytes,
  }) async {
    final body = <String, Object?>{
      'name': name,
      'product_type': productType,
      'karat': karat,
      'weight': weight,
      'quantity': quantity,
    };
    if (imageBytes != null) {
      final imagePath =
          '${DateTime.now().millisecondsSinceEpoch}_${_safeFilePart(name)}.jpg';
      await _uploadStorage(
        bucket: 'product-images',
        path: imagePath,
        bytes: imageBytes,
        contentType: 'image/jpeg',
      );
      body['image_path'] = imagePath;
      body['image_url'] = _publicStorageUrl('product-images', imagePath);
    }
    await _patch('products', 'id=eq.$id', body);
  }

  Future<void> deleteProduct(int id) async {
    await _delete('products', 'id=eq.$id');
  }

  Future<double> sellPricePerGram(int karat) async {
    final row = await _single('gold_prices', 'select=*&karat=eq.$karat');
    if (row == null) return 0;
    final buy = (row['buy_price_per_gram'] as num).toDouble();
    final margin = (row['margin_percent'] as num).toDouble();
    return buy * (1 + margin / 100);
  }

  Future<SaleRecord> createSale({
    required String customerName,
    required String customerPhone,
    String customerEmail = '',
    String customerCountryCode = '973',
    String customerPersonalId = '',
    String customerAddress = '',
    String paymentMethod = '',
    double discount = 0,
    required int userId,
    required List<int> productIds,
    Map<int, int> productQuantities = const {},
    Map<int, double> productGramPrices = const {},
    Map<int, double> productTotals = const {},
    Map<int, double> productWeights = const {},
    Map<int, double> productDiscounts = const {},
  }) async {
    if (productIds.isEmpty) {
      throw ArgumentError('Select at least one product.');
    }

    final productRows = await _select(
      'products',
      'select=*&id=in.(${productIds.join(',')})&status=eq.available',
    );
    if (productRows.length != productIds.length) {
      throw StateError('واحدة من القطع غير متوفرة أو مباعة مسبقاً.');
    }

    final products = productRows.map(ProductItem.fromMap).toList();
    final lines = <InvoiceLine>[];
    for (final product in products) {
      final customGramPrice = productGramPrices[product.id];
      final customTotal = productTotals[product.id];
      final customWeight = productWeights[product.id];
      final itemDiscount = productDiscounts[product.id] ?? 0;
      final saleQuantity = (productQuantities[product.id] ?? product.quantity)
          .clamp(1, product.quantity);
      final saleProduct = customWeight != null && customWeight > 0
          ? ProductItem(
              id: product.id,
              name: product.name,
              productType: product.productType,
              karat: product.karat,
              weight: customWeight,
              quantity: saleQuantity,
              status: product.status,
              createdAt: product.createdAt,
              imageBytes: product.imageBytes,
              imageUrl: product.imageUrl,
            )
          : product;
      lines.add(
        customGramPrice != null && customGramPrice > 0
            ? InvoiceLine.fromProduct(
                saleProduct,
                saleProduct.weight * customGramPrice,
                discount: itemDiscount,
                quantity: saleQuantity,
              )
            : customTotal != null && customTotal > 0
            ? InvoiceLine.fromProductTotal(
                saleProduct,
                customTotal,
                discount: itemDiscount,
                quantity: saleQuantity,
              )
            : InvoiceLine.fromProduct(
                saleProduct,
                saleProduct.weight * await sellPricePerGram(product.karat),
                discount: itemDiscount,
                quantity: saleQuantity,
              ),
      );
    }

    final subtotal = lines.fold<double>(0, (sum, line) => sum + line.total);
    final total = (subtotal - discount).clamp(0, double.infinity).toDouble();
    final invoiceNumber = _generateInvoiceNumber();
    final saleRows = await _insert('sales', {
      'invoice_number': invoiceNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'customer_country_code': customerCountryCode,
      'customer_personal_id': customerPersonalId,
      'customer_address': customerAddress,
      'payment_method': paymentMethod,
      'discount': discount,
      'total': total,
      'user_id': userId,
    }, returnRepresentation: true);
    final saleId = (saleRows.first['id'] as num).toInt();

    await _insert(
      'sale_items',
      lines
          .map(
            (line) => {
              'sale_id': saleId,
              'product_id': line.productId,
              'name': line.name,
              'product_type': line.productType,
              'karat': line.karat,
              'weight': line.weight,
              'quantity': line.quantity,
              'unit_price': line.unitPrice,
              'discount': line.discount,
              'total': line.total,
            },
          )
          .toList(),
    );

    for (final line in lines) {
      final product = products.firstWhere((item) => item.id == line.productId);
      final remaining = product.quantity - line.quantity;
      await _patch('products', 'id=eq.${line.productId}', {
        'quantity': remaining > 0 ? remaining : 0,
        'status': remaining > 0 ? 'available' : 'sold',
      });
    }

    return SaleRecord(
      id: saleId,
      invoiceNumber: invoiceNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      customerPersonalId: customerPersonalId,
      customerAddress: customerAddress,
      paymentMethod: paymentMethod,
      discount: discount,
      total: total,
      lines: lines,
      createdAt: DateTime.now(),
    );
  }

  Future<SaleRecord> saleRecord(int saleId) async {
    final sale = await _single('sales', 'select=*&id=eq.$saleId');
    if (sale == null) throw StateError('الفاتورة غير موجودة');
    final itemRows = await _select(
      'sale_items',
      'select=*&sale_id=eq.$saleId&order=id.asc',
    );
    return SaleRecord(
      id: saleId,
      invoiceNumber: sale['invoice_number'] as String,
      customerName: (sale['customer_name'] as String?) ?? '',
      customerPhone: (sale['customer_phone'] as String?) ?? '',
      customerPersonalId: (sale['customer_personal_id'] as String?) ?? '',
      customerAddress: (sale['customer_address'] as String?) ?? '',
      paymentMethod: (sale['payment_method'] as String?) ?? '',
      discount: ((sale['discount'] as num?) ?? 0).toDouble(),
      total: ((sale['total'] as num?) ?? 0).toDouble(),
      lines: itemRows.map(InvoiceLine.fromMap).toList(),
      createdAt: DateTime.parse(sale['created_at'] as String),
    );
  }

  Future<List<PurchaseLedgerRow>> salesLedger({
    String search = '',
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = search.trim();
    final filters = StringBuffer(
      'select=*&order=created_at.desc${query.isEmpty ? '' : '&search_text=ilike.*${_enc(query)}*'}',
    );
    if (fromDate != null) {
      filters.write(
        '&created_at=gte.${_enc(fromDate.toUtc().toIso8601String())}',
      );
    }
    if (toDate != null) {
      final endOfDay = DateTime(toDate.year, toDate.month, toDate.day + 1);
      filters.write(
        '&created_at=lt.${_enc(endOfDay.toUtc().toIso8601String())}',
      );
    }
    final rows = await _select('sales_ledger', filters.toString());
    return rows.map(PurchaseLedgerRow.fromMap).toList();
  }

  Future<List<SoldItemRow>> soldItemsLedger() async {
    final rows = await _select(
      'sold_items_ledger',
      'select=*&order=created_at.desc',
    );
    return rows.map(SoldItemRow.fromMap).toList();
  }

  Future<int> importSalesCsv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return 0;

    final file = result.files.single;
    final rows = _readImportedRows(file.bytes!, file.extension ?? file.name);
    if (rows.isEmpty) return 0;

    final header = rows.first.map(_normalHeader).toList();
    var imported = 0;
    for (final row in rows.skip(1)) {
      String read(List<String> names) {
        for (final name in names) {
          final index = header.indexOf(name);
          if (index >= 0 && index < row.length) return row[index].trim();
        }
        return '';
      }

      final invoiceNumber = read([
        'invoice',
        'invoice_number',
        'رقم_الفاتورة',
        'الفاتورة',
      ]);
      final customerName = read([
        'name',
        'customer',
        'customer_name',
        'اسم_العميل',
        'العميل',
      ]);
      final customerPhone = read([
        'phone',
        'customer_phone',
        'رقم_الهاتف',
        'الهاتف',
      ]);
      final customerEmail = read([
        'email',
        'customer_email',
        'الايميل',
        'البريد',
      ]);
      final products = read([
        'products',
        'items',
        'product',
        'المنتجات',
        'المنتج',
      ]);
      final productName = read([
        'product_name',
        'item_name',
        'name',
        'اسم_المنتج',
        'الصنف',
      ]);
      final productType = read(['product_type', 'type', 'النوع']);
      final karat = int.tryParse(read(['karat', 'عيار'])) ?? 21;
      final weight = double.tryParse(read(['weight', 'الوزن'])) ?? 0;
      final quantity = int.tryParse(read(['quantity', 'qty', 'الكمية'])) ?? 1;
      final unitPrice =
          double.tryParse(read(['unit_price', 'price', 'سعر_القطعة'])) ?? 0;
      final itemDiscount =
          double.tryParse(read(['discount', 'الخصم', 'التخفيض'])) ?? 0;
      final total =
          double.tryParse(read(['total', 'amount', 'المجموع', 'الاجمالي'])) ??
          0;
      final createdAt = DateTime.tryParse(
        read(['date', 'created_at', 'التاريخ']),
      );

      if (invoiceNumber.isEmpty && customerPhone.isEmpty && products.isEmpty) {
        continue;
      }

      final saleRows = await _upsertReturning('sales', {
        'invoice_number': invoiceNumber.isEmpty
            ? 'IMP-${DateTime.now().microsecondsSinceEpoch}'
            : invoiceNumber,
        'customer_name': customerName.isEmpty ? 'عميل مستورد' : customerName,
        'customer_phone': customerPhone,
        'customer_email': customerEmail,
        'customer_country_code': _detectCountryCode(customerPhone),
        'total': total,
        if (createdAt != null)
          'created_at': createdAt.toUtc().toIso8601String(),
      }, onConflict: 'invoice_number');
      final saleId = (saleRows.first['id'] as num).toInt();
      if (products.isNotEmpty || productName.isNotEmpty) {
        await _insert('sale_items', {
          'sale_id': saleId,
          'name': productName.isNotEmpty ? productName : products,
          'product_type': productType.isNotEmpty ? productType : 'imported',
          'karat': karat,
          'weight': weight,
          'quantity': quantity,
          'unit_price': unitPrice > 0 ? unitPrice : total,
          'discount': itemDiscount,
          'total': total > 0
              ? total
              : (unitPrice - itemDiscount).clamp(0, double.infinity),
        });
      }
      imported++;
    }
    return imported;
  }

  Future<void> exportSalesCsv({DateTime? day}) async {
    final selectedDay = day ?? DateTime.now();
    final rows = await salesLedger();
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'المبيعات');
    final sheet = excel['المبيعات'];
    _appendExcelRow(sheet, [
      'تقرير المبيعات',
      DateFormat('yyyy/MM/dd').format(selectedDay),
    ]);
    _appendExcelRow(sheet, const []);
    _appendExcelRow(sheet, const [
      'رقم الفاتورة',
      'اسم العميل',
      'الرقم الشخصي',
      'طريقة الدفع',
      'الهاتف',
      'المنتجات',
      'المجموع',
      'التخفيض',
      'الإجمالي',
      'الوقت',
    ]);
    for (final row in rows) {
      _appendExcelRow(sheet, [
        row.invoiceNumber,
        row.customerName,
        row.customerPersonalId,
        _paymentMethodExportLabel(row.paymentMethod),
        row.customerPhone,
        row.productsSummary,
        row.total,
        0,
        row.total,
        DateFormat('h:mm a', 'ar').format(row.createdAt.toLocal()),
      ]);
    }
    _appendExcelRow(sheet, const []);
    _appendExcelRow(sheet, [
      '',
      '',
      '',
      '',
      '',
      'مجموع اليوم',
      rows.fold<double>(0, (sum, row) => sum + row.total),
      0,
      rows.fold<double>(0, (sum, row) => sum + row.total),
    ]);

    final bytes = excel.save(fileName: 'daily-export.xlsx');
    if (bytes == null) throw StateError('تعذر إنشاء ملف Excel');
    await FilePicker.saveFile(
      dialogTitle: 'تصدير المبيعات',
      fileName:
          'Najma-Jawllery(${DateFormat('yyyy-MM-dd').format(DateTime.now())}).xlsx',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      bytes: Uint8List.fromList(bytes),
    );
  }

  List<List<String>> _readImportedRows(Uint8List bytes, String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      final excel = Excel.decodeBytes(bytes);
      for (final table in excel.tables.values) {
        if (table.rows.isEmpty) continue;
        return table.rows
            .map(
              (row) => row
                  .map((cell) => cell?.value?.toString() ?? '')
                  .toList(growable: false),
            )
            .where((row) => row.any((cell) => cell.trim().isNotEmpty))
            .toList();
      }
      return const [];
    }

    final text = utf8.decode(bytes, allowMalformed: true);
    return const LineSplitter()
        .convert(text)
        .where((line) => line.trim().isNotEmpty)
        .map(_parseCsvLine)
        .toList();
  }

  Future<DashboardSnapshot> dashboardSnapshot() async {
    final prices = await _select('gold_prices', 'select=*&order=karat.asc');
    if (prices.isEmpty) return DashboardSnapshot.empty();

    final byKarat = <int, double>{};
    var latestUpdate = DateTime.fromMillisecondsSinceEpoch(0);
    for (final row in prices) {
      byKarat[(row['karat'] as num).toInt()] =
          (row['buy_price_per_gram'] as num).toDouble();
      final updatedAt = DateTime.parse(row['updated_at'] as String);
      if (updatedAt.isAfter(latestUpdate)) latestUpdate = updatedAt;
    }

    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).toUtc().toIso8601String();
    final sales = await _select(
      'sales',
      'select=total&created_at=gte.${_enc(todayStart)}',
    );
    final products = await _select(
      'products',
      'select=quantity&status=eq.available',
    );
    final availableProducts = products.fold<int>(
      0,
      (sum, row) => sum + (((row['quantity'] as num?) ?? 1).toInt()),
    );
    final todaySales = sales.fold<double>(
      0,
      (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0),
    );

    return DashboardSnapshot(
      karat24: byKarat[24] ?? 0,
      karat22: byKarat[22] ?? 0,
      karat21: byKarat[21] ?? 0,
      karat18: byKarat[18] ?? 0,
      todaySales: todaySales,
      availableProducts: availableProducts,
      lastGoldUpdate: DateFormat(
        'd MMM yyyy - h:mm a',
        'ar',
      ).format(latestUpdate.toLocal()),
    );
  }

  Future<void> updateGoldPricesFromSpot({
    required double bhdPerOunce,
    DateTime? updatedAt,
  }) async {
    if (bhdPerOunce <= 0) {
      throw ArgumentError(
        'BHD spot price per ounce must be greater than zero.',
      );
    }

    final bhdPerGram24 = bhdPerOunce / 31.1035;
    final timestamp = (updatedAt ?? DateTime.now()).toUtc().toIso8601String();
    await _upsert('gold_prices', [
      {
        'karat': 24,
        'buy_price_per_gram': bhdPerGram24,
        'updated_at': timestamp,
      },
      {
        'karat': 22,
        'buy_price_per_gram': bhdPerGram24 * (22 / 24),
        'updated_at': timestamp,
      },
      {
        'karat': 21,
        'buy_price_per_gram': bhdPerGram24 * (21 / 24),
        'updated_at': timestamp,
      },
      {
        'karat': 18,
        'buy_price_per_gram': bhdPerGram24 * (18 / 24),
        'updated_at': timestamp,
      },
    ], onConflict: 'karat');
  }

  Future<void> updateGoldPricesFromXauRate(double xauRate) async {
    if (xauRate <= 0) {
      throw ArgumentError('XAU/BHD rate must be greater than zero.');
    }
    await updateGoldPricesFromSpot(bhdPerOunce: 1 / xauRate);
  }

  Future<List<Map<String, Object?>>> _select(String table, String query) async {
    final response = await http.get(
      _restUri(table, query),
      headers: _headers(),
    );
    _throwIfFailed(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((row) => Map<String, Object?>.from(row as Map)).toList();
  }

  Future<Map<String, Object?>?> _single(String table, String query) async {
    final rows = await _select(table, '$query&limit=1');
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> _insert(
    String table,
    Object body, {
    bool returnRepresentation = false,
  }) async {
    final response = await http.post(
      _restUri(table, ''),
      headers: _headers(
        prefer: returnRepresentation
            ? 'return=representation'
            : 'return=minimal',
      ),
      body: jsonEncode(body),
    );
    _throwIfFailed(response);
    if (!returnRepresentation || response.body.isEmpty) return const [];
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((row) => Map<String, Object?>.from(row as Map)).toList();
  }

  Future<void> _upsert(
    String table,
    Object body, {
    required String onConflict,
  }) async {
    final response = await http.post(
      _restUri(table, 'on_conflict=$onConflict'),
      headers: _headers(prefer: 'resolution=merge-duplicates,return=minimal'),
      body: jsonEncode(body),
    );
    _throwIfFailed(response);
  }

  Future<List<Map<String, Object?>>> _upsertReturning(
    String table,
    Object body, {
    required String onConflict,
  }) async {
    final response = await http.post(
      _restUri(table, 'on_conflict=$onConflict'),
      headers: _headers(
        prefer: 'resolution=merge-duplicates,return=representation',
      ),
      body: jsonEncode(body),
    );
    _throwIfFailed(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((row) => Map<String, Object?>.from(row as Map)).toList();
  }

  Future<void> _patch(String table, String query, Object body) async {
    final response = await http.patch(
      _restUri(table, query),
      headers: _headers(prefer: 'return=minimal'),
      body: jsonEncode(body),
    );
    _throwIfFailed(response);
  }

  Future<void> _delete(String table, String query) async {
    final response = await http.delete(
      _restUri(table, query),
      headers: _headers(prefer: 'return=minimal'),
    );
    _throwIfFailed(response);
  }

  Future<void> _uploadStorage({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/storage/v1/object/$bucket/$path'),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
        'Content-Type': contentType,
        'x-upsert': 'true',
      },
      body: bytes,
    );
    _throwIfFailed(response);
  }

  Future<Uint8List?> _downloadStoreAsset(String? path) async {
    if (path == null || path.isEmpty) return null;
    final response = await http.get(
      Uri.parse(_publicStorageUrl('store-assets', path)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return response.bodyBytes;
  }

  Uri _restUri(String table, String query) {
    return Uri.parse(
      '$_baseUrl/rest/v1/$table${query.isEmpty ? '' : '?$query'}',
    );
  }

  Map<String, String> _headers({String? prefer}) {
    final headers = {
      'apikey': supabaseAnonKey,
      'Authorization': 'Bearer $supabaseAnonKey',
      'Content-Type': 'application/json',
    };
    if (prefer != null) headers['Prefer'] = prefer;
    return headers;
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw StateError('Supabase ${response.statusCode}: ${response.body}');
  }

  String _publicStorageUrl(String bucket, String path) {
    return '$_baseUrl/storage/v1/object/public/$bucket/$path';
  }

  String _hashPassword(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  String _assetPath(StoreAssetType type, String originalName) {
    final folder = switch (type) {
      StoreAssetType.logo => 'logos',
      StoreAssetType.stamp => 'stamps',
    };
    return '$folder/${DateTime.now().millisecondsSinceEpoch}_${_safeFilePart(originalName)}';
  }

  String _safeFilePart(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return cleaned.isEmpty ? 'asset' : cleaned;
  }

  String _contentTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _enc(String value) => Uri.encodeComponent(value);

  String _normalHeader(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_');
  }

  List<String> _parseCsvLine(String line) {
    final cells = <String>[];
    final current = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        cells.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    cells.add(current.toString());
    return cells;
  }

  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final random = now.microsecondsSinceEpoch.remainder(1000000);
    return '${DateFormat('yyyyddMM').format(now)}-${random.toString().padLeft(6, '0')}';
  }

  void _appendExcelRow(Sheet sheet, List<Object?> values) {
    sheet.appendRow(
      values.map((value) {
        if (value is int) return IntCellValue(value);
        if (value is double) return DoubleCellValue(value);
        return TextCellValue((value ?? '').toString());
      }).toList(),
    );
  }

  String _detectCountryCode(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    for (final code in const ['973', '966', '971', '965', '974', '968']) {
      if (digits.startsWith(code)) return code;
    }
    return '973';
  }
}
