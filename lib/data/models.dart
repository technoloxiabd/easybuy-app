import '../core/text.dart';
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
  ProductCard({required this.id, required this.title, this.imageUrl, required this.unitPrice, required this.minQuantity, required this.isFactory, required this.isSoldOut, required this.saleCount, this.rating, this.repurchaseRate, this.isSuperFactory = false, this.priceFrom = false, this.onPricingHold = false, this.campaignLabel, this.campaignPrice});

  final int id;
  final String title;
  final String? imageUrl;
  final String unitPrice;
  final int minQuantity;
  final bool isFactory;
  final bool isSoldOut;
  final int saleCount;
  final String? rating;
  final String? repurchaseRate;
  final bool isSuperFactory;

  /// Options priced differently: the price reads "from ৳…".
  final bool priceFrom;

  /// The website shows "Price under review" instead of a price.
  final bool onPricingHold;

  /// A running campaign's badge ("10% OFF"), and for a percent campaign the
  /// discounted price shown beside the struck original.
  final String? campaignLabel;
  final String? campaignPrice;

  factory ProductCard.fromJson(Json j) {
    final campaign = objOrNull(j['campaign']);
    return ProductCard(
      id: integer(j['id']),
      title: titleCase(str(j['title'])),
      imageUrl: strOrNull(j['image_url']),
      unitPrice: str(j['unit_price_bdt'], '0'),
      minQuantity: integer(j['min_quantity'], 1),
      isFactory: boolean(j['is_factory']),
      isSoldOut: boolean(j['is_sold_out']),
      saleCount: integer(j['sale_count']),
      rating: strOrNull(j['rating']),
      repurchaseRate: strOrNull(j['repurchase_rate']),
      isSuperFactory: boolean(j['is_super_factory']),
      priceFrom: boolean(j['price_from']),
      onPricingHold: boolean(j['on_pricing_hold']),
      campaignLabel: campaign == null ? null : strOrNull(campaign['label']),
      campaignPrice: campaign == null ? null : strOrNull(campaign['price_bdt']),
    );
  }

  /// What the wishlist keeps on the phone (the website keeps it in the
  /// browser the same way): enough to draw the card again.
  Json toJson() => {
        'id': id, 'title': title, 'image_url': imageUrl, 'unit_price_bdt': unitPrice,
        'min_quantity': minQuantity, 'is_factory': isFactory, 'is_sold_out': isSoldOut,
        'sale_count': saleCount, 'rating': rating, 'repurchase_rate': repurchaseRate,
        'is_super_factory': isSuperFactory, 'price_from': priceFrom,
      };
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
  ProductDetail({required this.id, required this.title, required this.images, required this.unitPrice, required this.minQuantity, required this.minQuantityIsSupplier, required this.priceTiers, required this.variants, required this.variantsPricedSeparately, required this.isFactory, required this.isSoldOut, required this.saleCount, this.rating, this.estimatedWeightKg, this.slug, this.shareUrl, this.repurchaseRate, this.isSuperFactory = false, this.categoryId, this.categoryName, this.ordersCount = 0, this.onPricingHold = false, this.videoUrl, this.campaignLabel, this.minOrderAmount, this.orderNote, this.specs = const [], this.descriptionImages, this.seller, this.shippingTitle = 'Shipping charges', this.shipping = const [], this.orderRules = const OrderRules()});

  final int id;
  final String title;
  final String? slug;

  /// The short /p/{id} link the website's copy and share buttons hand out.
  final String? shareUrl;
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
  final String? repurchaseRate;
  final bool isSuperFactory;
  final int? categoryId;
  final String? categoryName;
  final int ordersCount;
  final bool onPricingHold;
  final String? videoUrl;
  final String? campaignLabel;
  final String? minOrderAmount;
  final String? orderNote;

  /// The page's buying rules, for the Add to Cart gate and the advance box.
  final OrderRules orderRules;
  final List<Attribute> specs;

  /// Null until fetched (GET /products/{id}/description).
  final List<String>? descriptionImages;
  final Json? seller;
  final String shippingTitle;
  final List<ShippingMethod> shipping;

  /// The card this product would show in a grid -- for the wishlist.
  ProductCard toCard() => ProductCard(
        id: id, title: title, imageUrl: images.firstOrNull, unitPrice: unitPrice, minQuantity: minQuantity,
        isFactory: isFactory, isSoldOut: isSoldOut, saleCount: saleCount, rating: rating,
        repurchaseRate: repurchaseRate, isSuperFactory: isSuperFactory, priceFrom: variantsPricedSeparately,
      );

  factory ProductDetail.fromJson(Json j) => ProductDetail(
        id: integer(j['id']),
        title: titleCase(str(j['title'])),
        slug: strOrNull(j['slug']),
        shareUrl: strOrNull(j['share_url']),
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
        repurchaseRate: strOrNull(j['repurchase_rate']),
        isSuperFactory: boolean(j['is_super_factory']),
        categoryId: intOrNull(obj(j['category'])['id']),
        categoryName: strOrNull(obj(j['category'])['name']),
        ordersCount: integer(j['orders_count']),
        onPricingHold: boolean(j['on_pricing_hold']),
        videoUrl: strOrNull(j['video_url']),
        campaignLabel: strOrNull(obj(j['campaign'])['label']),
        minOrderAmount: strOrNull(j['min_order_amount_bdt']),
        orderNote: strOrNull(j['order_note']),
        orderRules: OrderRules.fromJson(obj(j['order_rules'])),
        specs: listOf(j['specs'], (e) => Attribute(str(e['name']), str(e['value']))),
        descriptionImages: j['description_images'] is List ? (j['description_images'] as List).map((e) => '$e').toList() : null,
        seller: objOrNull(j['seller']),
        shippingTitle: str(j['shipping_title'], 'Shipping charges'),
        shipping: listOf(j['shipping'], ShippingMethod.fromJson),
      );
}

// ---------------------------------------------------------------- website pages

/// Where a banner leads: product / category screen, the Shop tab, or a web page.
/// The website product page's buying rules (its script's MOQ, SUPPLIER_MOQ,
/// HIGH_VALUE_CAP and advance), so the app blocks exactly what it blocks.
class OrderRules {
  const OrderRules({this.storeMinQuantity = 1, this.supplierMinQuantity = 1, this.highValueCap, this.advancePercent, this.advanceFixed = 0});
  final int storeMinQuantity;
  final int supplierMinQuantity;
  final double? highValueCap;

  /// Null when no advance applies; then everything is paid now.
  final double? advancePercent;
  final double advanceFixed;
  bool get hasAdvance => advancePercent != null;

  factory OrderRules.fromJson(Json j) {
    final adv = objOrNull(j['advance']);
    return OrderRules(
      storeMinQuantity: integer(j['store_min_quantity'], 1),
      supplierMinQuantity: integer(j['supplier_min_quantity'], 1),
      highValueCap: double.tryParse('${j['high_value_cap_bdt']}'),
      advancePercent: adv == null ? null : (double.tryParse('${adv['percent']}') ?? 0),
      advanceFixed: adv == null ? 0 : (double.tryParse('${adv['fixed_bdt']}') ?? 0),
    );
  }

  /// "Net payable now" on a total: the greater of the fixed amount and the
  /// percentage, never more than the total, rounded up -- the page's formula.
  double advanceOn(double total) {
    if (!hasAdvance) return total;
    final a = [advanceFixed, total * advancePercent! / 100].reduce((x, y) => x > y ? x : y);
    return (a > total ? total : a).ceilToDouble();
  }
}

/// A tile in the search screen's rail: a popular search or a category.
class SearchTile {
  SearchTile({required this.label, this.imageUrl, this.query, this.categoryId});
  final String label;
  final String? imageUrl;
  final String? query;
  final int? categoryId;
  factory SearchTile.fromJson(Json j) => SearchTile(
        label: str(j['label']),
        imageUrl: strOrNull(j['image_url']),
        query: strOrNull(j['query']),
        categoryId: intOrNull(j['category_id']),
      );
}

class LinkTarget {
  LinkTarget(this.type, this.id, this.url);
  final String type;
  final int? id;
  final String url;
  static LinkTarget? fromJson(Object? v) {
    final j = objOrNull(v);
    return j == null ? null : LinkTarget(str(j['type'], 'url'), intOrNull(j['id']), str(j['url']));
  }
}

class HomeBanner {
  HomeBanner(this.imageUrl, this.link);
  final String imageUrl;
  final LinkTarget? link;
}

class HomeVideo {
  HomeVideo({required this.title, this.posterUrl, this.duration, this.date, required this.url, this.provider, this.embedUrl, this.aspectRatio, this.category});
  final String title;
  final String? posterUrl;
  final String? duration;
  final String? date;

  /// The website's watch page: shared, and the fallback when there is no embed.
  final String url;
  final String? provider;

  /// What the app plays in place (YouTube / Facebook / stream iframe).
  final String? embedUrl;

  /// Width / height; null is the standard 16:9 frame.
  final double? aspectRatio;
  final String? category;

  factory HomeVideo.fromJson(Json v) => HomeVideo(
        title: str(v['title']),
        posterUrl: strOrNull(v['poster_url']),
        duration: strOrNull(v['duration']),
        date: strOrNull(v['date']),
        url: str(v['url']),
        provider: strOrNull(v['provider']),
        embedUrl: strOrNull(v['embed_url']),
        aspectRatio: v['aspect_ratio'] is num ? (v['aspect_ratio'] as num).toDouble() : null,
        category: strOrNull(v['category']),
      );
}

class HomePost {
  HomePost({required this.title, required this.excerpt, this.coverUrl, this.category, this.read, this.date, required this.url});
  final String title;
  final String excerpt;
  final String? coverUrl;
  final String? category;
  final String? read;
  final String? date;
  final String url;
}

class HomeSection {
  HomeSection({required this.title, this.categoryId, required this.products});
  final String title;
  final int? categoryId;
  final List<ProductCard> products;
}

/// GET /home -- the website's homepage, section for section.
class HomeData {
  HomeData({required this.banners, required this.categories, required this.videos, required this.videosHeading, required this.featured, required this.sections, required this.posts, required this.postsHeading});
  final List<HomeBanner> banners;
  final List<Category> categories;
  final List<HomeVideo> videos;
  final Json videosHeading;
  final HomeSection featured;
  final List<HomeSection> sections;
  final List<HomePost> posts;
  final Json postsHeading;

  factory HomeData.fromJson(Json j) {
    HomeSection section(Json s) => HomeSection(title: str(s['title']), categoryId: intOrNull(s['category_id']), products: listOf(s['products'], ProductCard.fromJson));
    return HomeData(
      banners: listOf(j['banners'], (b) => HomeBanner(str(b['image_url']), LinkTarget.fromJson(b['link']))),
      categories: listOf(j['categories'], Category.fromJson),
      videos: listOf(j['videos'], HomeVideo.fromJson),
      videosHeading: obj(j['videos_heading']),
      featured: section(obj(j['featured'])),
      sections: listOf(j['sections'], section),
      posts: listOf(j['posts'], (p) => HomePost(title: str(p['title']), excerpt: str(p['excerpt']), coverUrl: strOrNull(p['cover_url']), category: strOrNull(p['category']), read: strOrNull(p['read']), date: strOrNull(p['date']), url: str(p['url']))),
      postsHeading: obj(j['posts_heading']),
    );
  }
}

/// GET /categories/{id} -- a category page's header and chips.
class CategoryInfo {
  CategoryInfo({required this.id, required this.name, this.parentId, this.parentName, required this.itemCount, required this.chips});
  final int id;
  final String name;
  final int? parentId;
  final String? parentName;
  final int itemCount;
  final List<(int, String, bool)> chips;
  factory CategoryInfo.fromJson(Json j) => CategoryInfo(
        id: integer(j['id']),
        name: str(j['name']),
        parentId: intOrNull(obj(j['parent'])['id']),
        parentName: strOrNull(obj(j['parent'])['name']),
        itemCount: integer(j['item_count']),
        chips: listOf(j['chips'], (c) => (integer(c['id']), str(c['name']), boolean(c['is_active']))),
      );
}

/// One card of the "Recommended" rail.
class Highlight {
  Highlight(this.label, this.background, this.foreground, this.product);
  final String label;
  final String background;
  final String foreground;
  final ProductCard product;
}

/// A page of a list plus where the next one starts (null = the end).
/// One page of a search by photo; [nextPage] null when there is no more.
class ImageMatches {
  ImageMatches({required this.products, this.nextPage});
  final List<ProductCard> products;
  final int? nextPage;
}

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
        title: titleCase(str(j['title'])),
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

/// The website cart page's "Order summary" for the ticked lines.
class CartSummary {
  CartSummary({required this.selectedProducts, this.campaign, required this.netGoods, required this.hasAdvance, required this.dueNow, required this.dueLater, this.advancePercent});
  final int selectedProducts;
  final Json? campaign;
  final String netGoods;
  final bool hasAdvance;
  final String dueNow;
  final String dueLater;
  final String? advancePercent;
  factory CartSummary.fromJson(Json j) => CartSummary(
        selectedProducts: integer(j['selected_products']),
        campaign: objOrNull(j['campaign']),
        netGoods: str(j['net_goods_bdt'], '0.00'),
        hasAdvance: boolean(j['has_advance']),
        dueNow: str(j['due_now_bdt'], '0.00'),
        dueLater: str(j['due_later_bdt'], '0.00'),
        advancePercent: strOrNull(j['advance_percent']),
      );
}

class Cart {
  Cart({required this.items, required this.itemCount, required this.goodsTotal, required this.selectedCount, required this.selectedTotal, this.coupon, this.shippingMethod, this.deliveryMethod, required this.warnings, this.summary, this.shippingMethods = const [], this.deliveryMethods = const [], this.deliveryChoiceRequired = false});

  final CartSummary? summary;
  final List<ShippingMethod> shippingMethods;
  final List<DeliveryMethod> deliveryMethods;
  final bool deliveryChoiceRequired;

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
        summary: objOrNull(j['summary']) == null ? null : CartSummary.fromJson(obj(j['summary'])),
        shippingMethods: listOf(j['shipping_methods'], ShippingMethod.fromJson),
        deliveryMethods: listOf(j['delivery_methods'], DeliveryMethod.fromJson),
        deliveryChoiceRequired: boolean(j['delivery_choice_required']),
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
  Checkout({required this.lines, required this.itemCount, required this.goodsTotal, this.campaign, this.coupon, required this.netGoods, required this.dueNow, required this.dueLater, this.advancePercent, required this.creditBalance, this.shippingMethod, required this.shippingMethods, this.deliveryMethod, required this.deliveryChoiceRequired, required this.deliveryMethods, required this.addresses, this.defaultAddressId, this.addressRequired = true, this.termsTitle, this.termsHtml, required this.blockers, required this.canPlace, this.paymentMethods = const [], this.paymentMethodRequired = false});

  /// Chosen before placing, as on the website's checkout.
  final List<PayMethod> paymentMethods;
  final bool paymentMethodRequired;

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

  /// False when collecting from the warehouse: the address is optional.
  final bool addressRequired;
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
      addressRequired: j['address_required'] != false,
      termsTitle: terms == null ? null : str(terms['title']),
      termsHtml: terms == null ? null : str(terms['html']),
      blockers: listOf(j['blockers'], Notice.fromJson),
      canPlace: boolean(j['can_place']),
      paymentMethods: listOf(payment['methods'], PayMethod.fromJson),
      paymentMethodRequired: boolean(payment['method_required']),
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
        title: titleCase(str(j['title'])),
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
  ThreadMessage({required this.id, required this.mine, this.author, this.body, required this.attachments, this.context, required this.canUndo, this.createdAt, this.isBot = false});
  final int id;
  final bool mine;

  /// The order-status bot's own message: its [bracketed] choices are buttons.
  final bool isBot;
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
        isBot: boolean(j['is_bot']),
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
