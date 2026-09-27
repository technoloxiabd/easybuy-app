import 'json.dart';

// ---------------------------------------------------------------- account

class User {
  User({required this.id, required this.name, required this.phone, this.email, this.photoUrl, required this.phoneVerified, this.defaultAddress});

  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;
  final bool phoneVerified;
  final Address? defaultAddress;

  factory User.fromJson(Json j) => User(
        id: integer(j['id']),
        name: str(j['name']),
        phone: str(j['phone']),
        email: strOrNull(j['email']),
        photoUrl: strOrNull(j['photo_url']),
        phoneVerified: boolean(j['phone_verified']),
        defaultAddress: objOrNull(j['default_address']) == null ? null : Address.fromJson(obj(j['default_address'])),
      );
}

class Address {
  Address({required this.id, this.label, required this.name, required this.phone, required this.address, required this.isDefault});

  final int id;
  final String? label;
  final String name;
  final String phone;
  final String address;
  final bool isDefault;

  factory Address.fromJson(Json j) => Address(
        id: integer(j['id']),
        label: strOrNull(j['label']),
        name: str(j['name']),
        phone: str(j['phone']),
        address: str(j['address']),
        isDefault: boolean(j['is_default']),
      );
}

// ---------------------------------------------------------------- catalogue

class Category {
  Category({required this.id, required this.name, this.nameBn, this.imageUrl, this.children = const []});

  final int id;
  final String name;
  final String? nameBn;
  final String? imageUrl;
  final List<Category> children;

  factory Category.fromJson(Json j) => Category(
        id: integer(j['id']),
        name: str(j['name']),
        nameBn: strOrNull(j['name_bn']),
        imageUrl: strOrNull(j['image_url']),
        children: listOf(j['children'], Category.fromJson),
      );
}

class ProductCard {
  ProductCard({required this.id, required this.title, this.imageUrl, required this.unitPrice, required this.minQuantity, required this.isFactory, required this.isSoldOut, required this.saleCount, this.rating});

  final int id;
  final String title;
  final String? imageUrl;
  final String unitPrice;
  final int minQuantity;
  final bool isFactory;
  final bool isSoldOut;
  final int saleCount;
  final String? rating;

  factory ProductCard.fromJson(Json j) => ProductCard(
        id: integer(j['id']),
        title: str(j['title']),
        imageUrl: strOrNull(j['image_url']),
        unitPrice: str(j['unit_price_bdt'], '0'),
        minQuantity: integer(j['min_quantity'], 1),
        isFactory: boolean(j['is_factory']),
        isSoldOut: boolean(j['is_sold_out']),
        saleCount: integer(j['sale_count']),
        rating: strOrNull(j['rating']),
      );
}

class Attribute {
  Attribute(this.label, this.value);
  final String label;
  final String value;
  factory Attribute.fromJson(Json j) => Attribute(str(j['label']), str(j['value']));

  static String describe(List<Attribute> attributes) =>
      attributes.map((a) => a.label.isEmpty ? a.value : '${a.label}: ${a.value}').join(' · ');
}

class Variant {
  Variant({required this.skuId, required this.attributes, this.imageUrl, required this.unitPrice, this.stock});

  final String skuId;
  final List<Attribute> attributes;
  final String? imageUrl;
  final String unitPrice;
  final int? stock;

  String get label => Attribute.describe(attributes);

  factory Variant.fromJson(Json j) => Variant(
        skuId: str(j['sku_id']),
        attributes: listOf(j['attributes'], Attribute.fromJson),
        imageUrl: strOrNull(j['image_url']),
        unitPrice: str(j['unit_price_bdt'], '0'),
        stock: intOrNull(j['stock']),
      );
}

class PriceTier {
  PriceTier(this.minQuantity, this.maxQuantity, this.unitPrice);
  final int minQuantity;
  final int? maxQuantity;
  final String unitPrice;
  factory PriceTier.fromJson(Json j) =>
      PriceTier(integer(j['min_quantity'], 1), intOrNull(j['max_quantity']), str(j['unit_price_bdt'], '0'));
}

class ProductDetail {
  ProductDetail({required this.id, required this.title, required this.images, required this.unitPrice, required this.minQuantity, required this.minQuantityIsSupplier, required this.priceTiers, required this.variants, required this.variantsPricedSeparately, required this.isFactory, required this.isSoldOut, required this.saleCount, this.rating, this.estimatedWeightKg, this.slug});

  final int id;
  final String title;
  final String? slug;
  final List<String> images;
  final String unitPrice;
  final int minQuantity;
  final bool minQuantityIsSupplier;
  final List<PriceTier> priceTiers;
  final List<Variant> variants;
  final bool variantsPricedSeparately;
  final bool isFactory;
  final bool isSoldOut;
  final int saleCount;
  final String? rating;
  final String? estimatedWeightKg;

  factory ProductDetail.fromJson(Json j) => ProductDetail(
        id: integer(j['id']),
        title: str(j['title']),
        slug: strOrNull(j['slug']),
        images: j['images'] is List ? (j['images'] as List).map((e) => '$e').toList() : const [],
        unitPrice: str(j['unit_price_bdt'], '0'),
        minQuantity: integer(j['min_quantity'], 1),
        minQuantityIsSupplier: boolean(j['min_quantity_is_supplier']),
        priceTiers: listOf(j['price_tiers'], PriceTier.fromJson),
        variants: listOf(j['variants'], Variant.fromJson),
        variantsPricedSeparately: boolean(j['variants_priced_separately']),
        isFactory: boolean(j['is_factory']),
        isSoldOut: boolean(j['is_sold_out']),
        saleCount: integer(j['sale_count']),
        rating: strOrNull(j['rating']),
        estimatedWeightKg: strOrNull(j['estimated_weight_kg']),
      );
}

/// A page of a list plus where the next one starts (null = the end).
class Paged<T> {
  Paged(this.items, this.nextCursor);
  final List<T> items;
  final String? nextCursor;
}

// ---------------------------------------------------------------- cart

class Notice {
  Notice({required this.code, required this.message, this.productId});
  final String code;
  final String message;
  final int? productId;
  factory Notice.fromJson(Json j) => Notice(code: str(j['code']), message: str(j['message']), productId: intOrNull(j['product_id']));
}

class CartItem {
  CartItem({required this.id, required this.productId, this.skuId, required this.title, this.imageUrl, required this.attributes, required this.quantity, required this.isSelected, required this.unitPrice, required this.lineTotal, required this.minQuantity, required this.isAvailable});

  final int id;
  final int productId;
  final String? skuId;
  final String title;
  final String? imageUrl;
  final List<Attribute> attributes;
  final int quantity;
  final bool isSelected;
  final String unitPrice;
  final String lineTotal;
  final int minQuantity;
  final bool isAvailable;

  factory CartItem.fromJson(Json j) => CartItem(
        id: integer(j['id']),
        productId: integer(j['product_id']),
        skuId: strOrNull(j['sku_id']),
        title: str(j['title']),
        imageUrl: strOrNull(j['image_url']),
        attributes: listOf(j['attributes'], Attribute.fromJson),
        quantity: integer(j['quantity'], 1),
        isSelected: boolean(j['is_selected']),
        unitPrice: str(j['unit_price_bdt'], '0'),
        lineTotal: str(j['line_total_bdt'], '0'),
        minQuantity: integer(j['min_quantity'], 1),
        isAvailable: j['is_available'] == null || boolean(j['is_available']),
      );
}

class CouponState {
  CouponState({required this.code, this.label, required this.isValid, this.message, this.discount});
  final String code;
  final String? label;
  final bool isValid;
  final String? message;
  final String? discount;
  factory CouponState.fromJson(Json j) => CouponState(
        code: str(j['code']),
        label: strOrNull(j['label']),
        isValid: boolean(j['is_valid']),
        message: strOrNull(j['message']),
        discount: strOrNull(j['discount_bdt']),
      );
}

class Cart {
  Cart({required this.items, required this.itemCount, required this.goodsTotal, required this.selectedCount, required this.selectedTotal, this.coupon, this.shippingMethod, this.deliveryMethod, required this.warnings});

  final List<CartItem> items;
  final int itemCount;
  final String goodsTotal;
  final int selectedCount;
  final String selectedTotal;
  final CouponState? coupon;
  final String? shippingMethod;
  final String? deliveryMethod;
  final List<Notice> warnings;

  bool get isEmpty => items.isEmpty;

  static Cart empty() => Cart(items: const [], itemCount: 0, goodsTotal: '0.00', selectedCount: 0, selectedTotal: '0.00', warnings: const []);

  factory Cart.fromJson(Json j) => Cart(
        items: listOf(j['items'], CartItem.fromJson),
        itemCount: integer(j['item_count']),
        goodsTotal: str(j['goods_total_bdt'], '0.00'),
        selectedCount: integer(j['selected_count']),
        selectedTotal: str(j['selected_total_bdt'], '0.00'),
        coupon: objOrNull(j['coupon']) == null ? null : CouponState.fromJson(obj(j['coupon'])),
        shippingMethod: strOrNull(j['shipping_method']),
        deliveryMethod: strOrNull(j['delivery_method']),
        warnings: listOf(j['warnings'], Notice.fromJson),
      );
}

// ---------------------------------------------------------------- checkout

class ShippingRate {
  ShippingRate(this.name, this.pricePerKg, this.details);
  final String name;
  final String? pricePerKg;
  final String details;
  factory ShippingRate.fromJson(Json j) => ShippingRate(str(j['name']), strOrNull(j['price_per_kg_bdt']), str(j['details']));
}

class ShippingMethod {
  ShippingMethod({required this.name, this.minAmount, required this.isAvailable, required this.rates});
  final String name;
  final String? minAmount;
  final bool isAvailable;
  final List<ShippingRate> rates;
  factory ShippingMethod.fromJson(Json j) => ShippingMethod(
        name: str(j['name']),
        minAmount: strOrNull(j['min_amount_bdt']),
        isAvailable: j['is_available'] == null || boolean(j['is_available']),
        rates: listOf(j['rates'], ShippingRate.fromJson),
      );
}

class DeliveryMethod {
  DeliveryMethod({required this.name, this.type, this.note, required this.isDefault});
  final String name;
  final String? type;
  final String? note;
  final bool isDefault;
  bool get isPickup => type == 'pickup';
  factory DeliveryMethod.fromJson(Json j) =>
      DeliveryMethod(name: str(j['name']), type: strOrNull(j['type']), note: strOrNull(j['note']), isDefault: boolean(j['is_default']));
}

class Checkout {
  Checkout({required this.lines, required this.itemCount, required this.goodsTotal, this.campaign, this.coupon, required this.netGoods, required this.dueNow, required this.dueLater, this.advancePercent, required this.creditBalance, this.shippingMethod, required this.shippingMethods, this.deliveryMethod, required this.deliveryChoiceRequired, required this.deliveryMethods, required this.addresses, this.defaultAddressId, this.termsTitle, this.termsHtml, required this.blockers, required this.canPlace});

  final List<CartItem> lines;
  final int itemCount;
  final String goodsTotal;
  final Json? campaign;
  final CouponState? coupon;
  final String netGoods;
  final String dueNow;
  final String dueLater;
  final String? advancePercent;
  final String creditBalance;
  final String? shippingMethod;
  final List<ShippingMethod> shippingMethods;
  final String? deliveryMethod;
  final bool deliveryChoiceRequired;
  final List<DeliveryMethod> deliveryMethods;
  final List<Address> addresses;
  final int? defaultAddressId;
  final String? termsTitle;
  final String? termsHtml;
  final List<Notice> blockers;
  final bool canPlace;

  factory Checkout.fromJson(Json j) {
    final totals = obj(j['totals']);
    final payment = obj(j['payment']);
    final terms = objOrNull(j['terms']);
    return Checkout(
      lines: listOf(j['lines'], CartItem.fromJson),
      itemCount: integer(j['item_count']),
      goodsTotal: str(totals['goods_total_bdt'], '0.00'),
      campaign: objOrNull(totals['campaign']),
      coupon: objOrNull(totals['coupon']) == null ? null : CouponState.fromJson(obj(totals['coupon'])),
      netGoods: str(totals['net_goods_bdt'], '0.00'),
      dueNow: str(payment['due_now_bdt'], '0.00'),
      dueLater: str(payment['due_later_bdt'], '0.00'),
      advancePercent: strOrNull(payment['advance_percent']),
      creditBalance: str(payment['credit_balance_bdt'], '0.00'),
      shippingMethod: strOrNull(j['shipping_method']),
      shippingMethods: listOf(j['shipping_methods'], ShippingMethod.fromJson),
      deliveryMethod: strOrNull(j['delivery_method']),
      deliveryChoiceRequired: boolean(j['delivery_choice_required']),
      deliveryMethods: listOf(j['delivery_methods'], DeliveryMethod.fromJson),
      addresses: listOf(j['addresses'], Address.fromJson),
      defaultAddressId: intOrNull(j['default_address_id']),
      termsTitle: terms == null ? null : str(terms['title']),
      termsHtml: terms == null ? null : str(terms['html']),
      blockers: listOf(j['blockers'], Notice.fromJson),
      canPlace: boolean(j['can_place']),
    );
  }
}

// ---------------------------------------------------------------- orders

class NextPayment {
  NextPayment({required this.stage, required this.stageLabel, required this.amount, required this.remaining, required this.pending});
  final String stage;
  final String stageLabel;
  final String amount;
  final String remaining;
  final String pending;
  factory NextPayment.fromJson(Json j) => NextPayment(
        stage: str(j['stage'], 'goods'),
        stageLabel: str(j['stage_label']),
        amount: str(j['amount_bdt'], '0'),
        remaining: str(j['remaining_bdt'], '0'),
        pending: str(j['pending_bdt'], '0'),
      );
}

class OrderSummary {
  OrderSummary({required this.number, required this.status, required this.statusLabel, this.placedAt, this.title, this.thumbnailUrl, required this.productCount, required this.itemCount, required this.goodsTotal, required this.discount, required this.advanceDue, required this.paid, required this.amountDue, required this.isSettled, this.nextPayment, this.shippingMethod, this.deliveryMethod});

  final String number;
  final String status;
  final String statusLabel;
  final DateTime? placedAt;
  final String? title;
  final String? thumbnailUrl;
  final int productCount;
  final int itemCount;
  final String goodsTotal;
  final String discount;
  final String advanceDue;
  final String paid;
  final String amountDue;
  final bool isSettled;
  final NextPayment? nextPayment;
  final String? shippingMethod;
  final String? deliveryMethod;

  factory OrderSummary.fromJson(Json j) => OrderSummary(
        number: str(j['number']),
        status: str(j['status']),
        statusLabel: str(j['status_label']),
        placedAt: date(j['placed_at']),
        title: strOrNull(j['title']),
        thumbnailUrl: strOrNull(j['thumbnail_url']),
        productCount: integer(j['product_count']),
        itemCount: integer(j['item_count']),
        goodsTotal: str(j['goods_total_bdt'], '0'),
        discount: str(j['discount_bdt'], '0'),
        advanceDue: str(j['advance_due_bdt'], '0'),
        paid: str(j['paid_bdt'], '0'),
        amountDue: str(j['amount_due_bdt'], '0'),
        isSettled: boolean(j['is_settled']),
        nextPayment: objOrNull(j['next_payment']) == null ? null : NextPayment.fromJson(obj(j['next_payment'])),
        shippingMethod: strOrNull(j['shipping_method']),
        deliveryMethod: strOrNull(j['delivery_method']),
      );
}

class FileLink {
  FileLink(this.url, this.name, this.kind);
  final String url;
  final String name;

  /// image, video, pdf or file.
  final String kind;
  factory FileLink.fromJson(Json j) => FileLink(str(j['url']), str(j['name']), str(j['kind'], 'file'));
}

class OrderLine {
  OrderLine({required this.id, required this.attributes, this.imageUrl, required this.quantity, required this.unitPrice, required this.lineTotal, required this.isCancelled});
  final int id;
  final List<Attribute> attributes;
  final String? imageUrl;
  final int quantity;
  final String unitPrice;
  final String lineTotal;
  final bool isCancelled;
  factory OrderLine.fromJson(Json j) => OrderLine(
        id: integer(j['id']),
        attributes: listOf(j['attributes'], Attribute.fromJson),
        imageUrl: strOrNull(j['image_url']),
        quantity: integer(j['quantity']),
        unitPrice: str(j['unit_price_bdt'], '0'),
        lineTotal: str(j['line_total_bdt'], '0'),
        isCancelled: boolean(j['is_cancelled']),
      );
}

class OrderItemGroup {
  OrderItemGroup({this.productId, required this.title, this.imageUrl, required this.quantity, required this.total, this.shipping, required this.lines});
  final int? productId;
  final String title;
  final String? imageUrl;
  final int quantity;
  final String total;
  final Json? shipping;
  final List<OrderLine> lines;
  factory OrderItemGroup.fromJson(Json j) => OrderItemGroup(
        productId: intOrNull(j['product_id']),
        title: str(j['title']),
        imageUrl: strOrNull(j['image_url']),
        quantity: integer(j['quantity']),
        total: str(j['total_bdt'], '0'),
        shipping: objOrNull(j['shipping']),
        lines: listOf(j['lines'], OrderLine.fromJson),
      );
}

class Transaction {
  Transaction(this.raw);
  final Json raw;
  bool get isPayment => raw['kind'] == 'payment';
  int? get paymentId => intOrNull(raw['id']);
  String get title => isPayment ? '${str(raw['method'])} · ${str(raw['stage_label'])}' : str(raw['label']);
  String? get detail => isPayment ? strOrNull(raw['reference']) : (strOrNull(raw['reason']) ?? strOrNull(raw['note']));
  String get amount => str(raw['amount_bdt'], '0');
  String get status => str(raw['status']);
  String get sign => str(raw['sign'], '-');
  bool get canEdit => boolean(raw['can_edit']);
  DateTime? get createdAt => date(raw['created_at']);
  List<FileLink> get receipts => listOf(raw['receipts'], FileLink.fromJson);
}

class OrderDetail {
  OrderDetail({required this.summary, required this.items, required this.statement, required this.transactions, required this.refunds, required this.courier, required this.timeline, this.deliveryNote, required this.address, this.notes});

  final OrderSummary summary;
  final List<OrderItemGroup> items;
  final Json statement;
  final List<Transaction> transactions;
  final List<Json> refunds;
  final List<Json> courier;
  final List<Json> timeline;
  final String? deliveryNote;
  final Json address;
  final String? notes;

  bool get canEditAddress => boolean(address['can_edit']);

  factory OrderDetail.fromJson(Json j) => OrderDetail(
        summary: OrderSummary.fromJson(j),
        items: listOf(j['items'], OrderItemGroup.fromJson),
        statement: obj(j['statement']),
        transactions: listOf(j['transactions'], (e) => Transaction(e)),
        refunds: listOf(j['refunds'], (e) => e),
        courier: listOf(j['courier'], (e) => e),
        timeline: listOf(j['timeline'], (e) => e),
        deliveryNote: strOrNull(j['delivery_note']),
        address: obj(j['address']),
        notes: strOrNull(j['notes']),
      );
}

// ---------------------------------------------------------------- payments

class PayMethod {
  PayMethod({required this.id, required this.name, required this.type, this.instructions, required this.account, required this.collectsReference, required this.collectsProof});
  final int id;
  final String name;
  final String type;
  final String? instructions;
  final Map<String, String> account;
  final bool collectsReference;
  final bool collectsProof;
  bool get isGateway => type == 'gateway';
  factory PayMethod.fromJson(Json j) => PayMethod(
        id: integer(j['id']),
        name: str(j['name']),
        type: str(j['type'], 'manual'),
        instructions: strOrNull(j['instructions']),
        account: obj(j['account']).map((k, v) => MapEntry(k, '$v')),
        collectsReference: boolean(j['collects_reference']),
        collectsProof: boolean(j['collects_proof']),
      );
}

class PayOptions {
  PayOptions({required this.stage, required this.stageLabel, required this.outstanding, required this.pending, required this.suggested, this.shippingOnly, required this.canPay, required this.methods});
  final String stage;
  final String stageLabel;
  final String outstanding;
  final String pending;
  final String suggested;
  final String? shippingOnly;
  final bool canPay;
  final List<PayMethod> methods;
  factory PayOptions.fromJson(Json j) => PayOptions(
        stage: str(j['stage'], 'goods'),
        stageLabel: str(j['stage_label']),
        outstanding: str(j['outstanding_bdt'], '0'),
        pending: str(j['pending_bdt'], '0'),
        suggested: str(j['suggested_bdt'], '0'),
        shippingOnly: strOrNull(j['shipping_only_bdt']),
        canPay: boolean(j['can_pay']),
        methods: listOf(j['methods'], PayMethod.fromJson),
      );
}

// ---------------------------------------------------------------- support

class ComplaintSummary {
  ComplaintSummary({required this.number, required this.subject, required this.status, required this.statusLabel, required this.isClosed, this.orderNumber, required this.awaitingSupport, this.updatedAt});
  final String number;
  final String subject;
  final String status;
  final String statusLabel;
  final bool isClosed;
  final String? orderNumber;
  final bool awaitingSupport;
  final DateTime? updatedAt;
  factory ComplaintSummary.fromJson(Json j) => ComplaintSummary(
        number: str(j['number']),
        subject: str(j['subject']),
        status: str(j['status']),
        statusLabel: str(j['status_label']),
        isClosed: boolean(j['is_closed']),
        orderNumber: strOrNull(j['order_number']),
        awaitingSupport: boolean(j['awaiting_support']),
        updatedAt: date(j['updated_at']),
      );
}

class ThreadMessage {
  ThreadMessage({required this.id, required this.mine, this.author, this.body, required this.attachments, this.context, required this.canUndo, this.createdAt});
  final int id;
  final bool mine;
  final String? author;
  final String? body;
  final List<FileLink> attachments;
  final Json? context;
  final bool canUndo;
  final DateTime? createdAt;
  factory ThreadMessage.fromJson(Json j) => ThreadMessage(
        id: integer(j['id']),
        mine: boolean(j['mine']),
        author: strOrNull(j['author']),
        body: strOrNull(j['body']),
        attachments: listOf(j['attachments'], FileLink.fromJson),
        context: objOrNull(j['context']),
        canUndo: boolean(j['can_undo']),
        createdAt: date(j['created_at']),
      );
}

class ComplaintDetail {
  ComplaintDetail({required this.summary, required this.details, required this.attachments, required this.messages});
  final ComplaintSummary summary;
  final String details;
  final List<FileLink> attachments;
  final List<ThreadMessage> messages;
  factory ComplaintDetail.fromJson(Json j) => ComplaintDetail(
        summary: ComplaintSummary.fromJson(j),
        details: str(j['details']),
        attachments: listOf(j['attachments'], FileLink.fromJson),
        messages: listOf(j['messages'], ThreadMessage.fromJson),
      );
}
