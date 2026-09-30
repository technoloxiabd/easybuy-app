import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/wishlist.dart';
import '../widgets/common.dart';
import '../widgets/site.dart';
import '../widgets/video.dart';
import 'catalog_screens.dart' show QtyStepper;

final productProvider = FutureProvider.autoDispose.family<ProductDetail, int>((ref, id) => ref.read(apiProvider).product(id));
final relatedProvider = FutureProvider.autoDispose.family<List<ProductCard>, int>((ref, id) => ref.read(apiProvider).related(id));

/// The website's product page (catalog/show.blade.php), section for section.
///
/// Opens at once (owner, 29 Sep 2026): while the product loads, the page is
/// already there with what the tapped card knew -- photo, name, price --
/// and shimmering placeholders for the rest (see [ProductSkeleton]).
class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key, required this.id, this.preview});
  final int id;

  /// The card that was tapped, when there was one.
  final ProductCard? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productProvider(id));
    return async.when(
      loading: () => ProductSkeleton(preview: preview),
      error: (e, _) => Scaffold(appBar: const SiteHeader(), body: ErrorView(error: e, onRetry: () => ref.invalidate(productProvider(id)))),
      data: (p) => _ProductPage(product: p),
    );
  }
}

class _ProductPage extends ConsumerStatefulWidget {
  const _ProductPage({required this.product});
  final ProductDetail product;

  @override
  ConsumerState<_ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<_ProductPage> {
  ProductDetail get p => widget.product;

  /// sku_id -> pieces.
  final _qty = <String, int>{};
  late int _single = 0;
  String? _selectedValue;
  bool _showAllOptions = false;
  String? _lineTotal;
  Timer? _debounce;

  bool get _hasOptions => p.variants.length > 1;
  int get _pieces => _hasOptions ? _qty.values.fold(0, (a, b) => a + b) : _single;

  /// The option dimension shown as the picture grid ("Colour", "Product
  /// specifications"): the first attribute of each variant.
  String get _dimension => p.variants.firstOrNull?.attributes.firstOrNull?.label ?? 'Option';

  List<(String, String?)> get _values {
    final seen = <String, String?>{};
    for (final v in p.variants) {
      final value = v.attributes.firstOrNull?.value ?? v.skuId;
      seen.putIfAbsent(value, () => v.imageUrl);
    }
    return seen.entries.map((e) => (e.key, e.value)).toList();
  }

  List<Variant> get _rows => p.variants.where((v) => (v.attributes.firstOrNull?.value ?? v.skuId) == _selectedValue).toList();

  /// Pieces chosen under one colour/option, for its swatch badge -- without
  /// it, quantities picked under an option you have moved away from are
  /// invisible (the website's reason too).
  int _countFor(String value) => p.variants
      .where((v) => (v.attributes.firstOrNull?.value ?? v.skuId) == value)
      .fold(0, (sum, v) => sum + (_qty[v.skuId] ?? 0));

  @override
  void initState() {
    super.initState();
    _selectedValue = _values.firstOrNull?.$1;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    _debounce?.cancel();
    final pieces = _pieces;
    // Priced from the first piece, as the website's running total is: the
    // minimum-amount hint and the advance box need the figure below the
    // minimum too.
    if (pieces == 0) {
      setState(() => _lineTotal = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final total = _hasOptions && p.variantsPricedSeparately ? await _variantTotal(pieces) : await _plainTotal(pieces);
        if (mounted && pieces == _pieces) setState(() => _lineTotal = total);
      } catch (_) {
        if (mounted) setState(() => _lineTotal = null);
      }
    });
  }

  Future<String> _plainTotal(int pieces) async {
    final r = await ref.read(apiProvider).price(p.id, pieces, skuId: _hasOptions ? null : p.variants.firstOrNull?.skuId);
    return '${r['line_total_bdt']}';
  }

  /// Options priced apart: each chosen option at ITS price, at the break the
  /// COMBINED quantity reaches -- the cart's rule (1688 counts the whole
  /// product towards a break). The server prices each; the app only adds.
  /// This used to show ৳0 on every such product.
  Future<String> _variantTotal(int pieces) async {
    final lines = _qty.entries.where((e) => e.value > 0).toList();
    final api = ref.read(apiProvider);
    final units = lines.length <= 20
        ? await Future.wait(lines.map((e) async => double.tryParse('${(await api.price(p.id, pieces, skuId: e.key))['unit_price_bdt']}') ?? 0))
        // A very wide pick: the rows' own prices rather than a burst of calls.
        : lines.map((e) => double.tryParse(p.variants.firstWhere((v) => v.skuId == e.key).unitPrice) ?? 0).toList();
    var sum = 0.0;
    for (final (i, e) in lines.indexed) {
      sum += units[i] * e.value;
    }
    return sum.toStringAsFixed(2);
  }

  // ---------------------------------------------------------------- the gate

  OrderRules get _rules => p.orderRules;

  /// The selection's total in taka: the server's figure when it is current,
  /// otherwise the rows' own prices (the page's running total does the same).
  double get _total {
    if (_lineTotal != null) return double.tryParse(_lineTotal!) ?? 0;
    if (_hasOptions) {
      return _qty.entries.fold(0.0, (sum, e) {
        final v = p.variants.where((v) => v.skuId == e.key).firstOrNull;
        return sum + (double.tryParse(p.variantsPricedSeparately ? (v?.unitPrice ?? p.unitPrice) : p.unitPrice) ?? 0) * e.value;
      });
    }
    return (double.tryParse(p.unitPrice) ?? 0) * _single;
  }

  double get _minAmount => double.tryParse(p.minOrderAmount ?? '') ?? 0;

  /// A selection worth the cap or more clears the store's floors on its own
  /// -- but never the supplier's.
  bool get _highValue => (_rules.highValueCap ?? 0) > 0 && _pieces > 0 && _total >= _rules.highValueCap!;
  int get _floor => _highValue ? _rules.supplierMinQuantity : p.minQuantity;
  bool get _qtyShort => _pieces > 0 && _pieces < _floor;
  bool get _amountShort => !_highValue && _minAmount > 0 && _pieces > 0 && _total < _minAmount;

  /// "Almost there": the website's buy-block modal, word for word.
  Future<void> _almostThere(List<InlineSpan> message) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          content: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(radius: 20, backgroundColor: Color(0xFFFEF3C7), child: Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Almost there', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Brand.ink)),
                const SizedBox(height: 6),
                Text.rich(TextSpan(children: message), style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF4B5563))),
              ]),
            ),
          ]),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Brand.blue),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK, got it'),
              ),
            ),
          ],
        ),
      );

  static const _bold = TextStyle(fontWeight: FontWeight.w800, color: Brand.ink);

  /// PICK_OPTIONS_MSG: choose options first, and the floors that apply.
  List<InlineSpan> _pickMessage() {
    final floors = <List<InlineSpan>>[
      if (p.minQuantity > 1) [const TextSpan(text: 'সর্বনিম্ন '), TextSpan(text: '${Money.bn(p.minQuantity)} টি', style: _bold)],
      if (_minAmount > 0) [const TextSpan(text: 'সর্বনিম্ন '), TextSpan(text: '${Money.bn(_minAmount.round())} টাকার', style: _bold)],
    ];
    return [
      const TextSpan(text: "প্রথমে আপনার পছন্দের পণ্যটি বেছে নিন — তারপর সাইজ বা রঙের পাশে থাকা 'Add'-এ ট্যাপ/ক্লিক করে পরিমাণ লিখুন।"),
      if (floors.isNotEmpty) ...[
        const TextSpan(text: ' '),
        for (final (i, f) in floors.indexed) ...[if (i > 0) const TextSpan(text: ' এবং '), ...f],
        const TextSpan(text: ' অর্ডার করতে হবে।'),
      ],
    ];
  }

  /// shortMsg(): short of the minimum pieces, naming the supplier when the
  /// floor is theirs.
  List<InlineSpan> _shortMessage() {
    final need = _floor;
    return [
      TextSpan(
        text: need > _rules.storeMinQuantity
            ? 'এই সাপ্লায়ার/ফ্যাক্টরি ${Money.bn(need)} টি আইটেমের নিচে অর্ডার গ্রহণ করেন না'
            : 'এটি অর্ডার করতে আপনাকে কমপক্ষে ${Money.bn(need)} টি আইটেম যোগ করতে হবে',
      ),
      TextSpan(text: ' (আপনি যেকোনো ভ্যারিয়েন্ট মিলিয়ে নিতে পারেন) — আরও ${Money.bn(need - _pieces)} টি আইটেম যোগ করুন'),
    ];
  }

  List<InlineSpan> _amountMessage() => [
        const TextSpan(text: 'এই পণ্যটি অর্ডার করতে হলে পণ্যটির মোট মূল্য কমপক্ষে '),
        TextSpan(text: Money.bn(Money.bdt('$_minAmount')), style: _bold),
        const TextSpan(text: ' বা তার বেশি হতে হবে — অর্ডার করতে আরও '),
        TextSpan(text: Money.bn(Money.bdt('${_minAmount - _total}')), style: _bold),
        const TextSpan(text: ' এর পণ্য যোগ করুন।'),
      ];

  Future<void> _add({required bool buyNow}) async {
    final cart = ref.read(cartProvider.notifier);
    // The website's __attemptBuy(): explain, never pad a short selection up
    // to the minimum behind the customer's back (owner, 29 Sep 2026: 2 pcs
    // "added" and the cart showed 3).
    if (_pieces == 0) {
      return _almostThere(_hasOptions ? _pickMessage() : [const TextSpan(text: 'Please enter a quantity.')]);
    }
    if (_qtyShort) return _almostThere(_shortMessage());
    if (_amountShort) return _almostThere(_amountMessage());
    if (_hasOptions) {
      await cart.add(p.id, variants: Map.fromEntries(_qty.entries.where((e) => e.value > 0)));
    } else {
      await cart.add(p.id, skuId: p.variants.firstOrNull?.skuId, quantity: _single);
    }
    if (!mounted) return;
    if (buyNow) {
      context.push('/checkout');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: const Text('Added to cart'),
        action: SnackBarAction(label: 'View cart', onPressed: () => context.go('/cart')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SiteHeader(),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
        _titleCard(),
        const SizedBox(height: 16),
        _gallery(),
        const SizedBox(height: 16),
        _buyCard(),
        if (p.shipping.isNotEmpty) ...[const SizedBox(height: 16), _ShippingCard(title: p.shippingTitle, methods: p.shipping)],
        const SizedBox(height: 16),
        _InfoTabs(product: p),
        _Related(product: p),
      ]),
      bottomNavigationBar: _bottomBar(),
    );
  }

  // ---------------------------------------------------------------- title

  String get _shareUrl => p.shareUrl ?? '${AppConfig.siteBase}/p/${p.id}';

  Widget _titleCard() {
    final saved = ref.watch(wishlistProvider).any((x) => x.id == p.id);
    return WebCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Material(
            color: const Color(0xFFF3F4F6),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.canPop() ? context.pop() : context.go('/'),
              child: const SizedBox(width: 44, height: 44, child: Icon(Icons.chevron_left, size: 28)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(p.title, style: productTitleStyle)),
        ]),
        if (p.categoryName != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              side: const BorderSide(color: Brand.blue, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: p.categoryId == null ? null : () => context.push('/category/${p.categoryId}'),
            icon: const Icon(Icons.sell_outlined, size: 18),
            label: Text(p.categoryName!, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          // Pills wrap onto a second line on narrow phones; the actions stay put.
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              if (p.saleCount > 0) _Pill(icon: Icons.verified_outlined, text: '${compactCount(p.saleCount)} sold', filled: true),
              if (p.ordersCount > 0) _Pill(text: '${p.ordersCount} orders'),
            ]),
          ),
          const SizedBox(width: 6),
          _SquareAction(
            icon: saved ? Icons.favorite : Icons.favorite_border,
            color: saved ? Brand.orange : const Color(0xFF374151),
            tooltip: saved ? 'Remove from wishlist' : 'Add to wishlist',
            onTap: () async {
              final added = await ref.read(wishlistProvider.notifier).toggle(p.toCard());
              if (mounted) showMessage(context, added ? 'Saved to your wishlist' : 'Removed from your wishlist');
            },
          ),
          const SizedBox(width: 6),
          // The website's short /p/{id} link, for copying and sharing alike.
          _SquareAction(
            icon: Icons.copy_rounded,
            tooltip: 'Copy link',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: _shareUrl));
              if (mounted) showMessage(context, 'Link copied');
            },
          ),
          const SizedBox(width: 6),
          // Share on WhatsApp, as the website's green button does. Chat with
          // the manager is the floating button (ChatFab), on every screen.
          _SquareAction(
            iconWidget: SvgPicture.string(_whatsAppLogo, width: 19, height: 19, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
            background: const Color(0xFF22C55E),
            tooltip: 'Share on WhatsApp',
            onTap: () => launchUrl(
              Uri.parse('https://wa.me/?text=${Uri.encodeComponent('${p.title} $_shareUrl')}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ]),
      ]),
    );
  }

  // ---------------------------------------------------------------- gallery

  Widget _gallery() => WebCard(padding: const EdgeInsets.all(12), child: _Gallery(images: p.images, videoUrl: p.videoUrl));

  // ---------------------------------------------------------------- buy

  Widget _buyCard() {
    final approxPieces = p.minOrderAmount == null
        ? null
        : ((double.tryParse(p.minOrderAmount!) ?? 0) / ((double.tryParse(p.unitPrice) ?? 1).clamp(0.01, double.infinity))).ceil();

    return WebCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (p.isSoldOut || p.onPricingHold) ...[
          NoticeBox(p.isSoldOut ? 'Sold out — this item is not available right now.' : 'Price under review — this item cannot be ordered until its price is verified.', tone: NoticeTone.danger),
          const SizedBox(height: 12),
        ],
        if (p.priceTiers.length > 1) ...[_tiers(), const SizedBox(height: 14)],
        if (_hasOptions) ..._optionPicker() else _singleRow(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$_pieces', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              const Padding(padding: EdgeInsets.only(bottom: 3), child: Text('pcs selected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              const Spacer(),
              Text(Money.bdt(_pieces == 0 ? '0' : '$_total'),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Brand.orange)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (p.minQuantity > 1) _Chip('Min ${p.minQuantity} pcs ${p.minQuantityIsSupplier ? '(supplier)' : 'per product'}', amber: p.minQuantityIsSupplier),
              if (p.minOrderAmount != null) _Chip('Min order ${Money.bdt(p.minOrderAmount)}${approxPieces != null ? ' · ≈ $approxPieces pcs' : ''}'),
              if (p.estimatedWeightKg != null) _Chip('~${Money.kg(p.estimatedWeightKg).replaceAll(' kg', '')} kg'),
            ]),
            // The page's live hints, while the selection is short.
            if (_qtyShort) _AmberHint([
              TextSpan(text: p.minQuantityIsSupplier ? 'এই সাপ্লায়ার/ফ্যাক্টরি ' : 'এটি অর্ডার করতে আপনাকে কমপক্ষে '),
              TextSpan(text: '${Money.bn(p.minQuantity)} টি', style: _bold),
              TextSpan(text: p.minQuantityIsSupplier ? ' আইটেমের নিচে অর্ডার গ্রহণ করেন না' : ' আইটেম যোগ করতে হবে'),
              const TextSpan(text: ' (আপনি যেকোনো ভ্যারিয়েন্ট মিলিয়ে নিতে পারেন) — আরও '),
              TextSpan(text: Money.bn(_floor - _pieces), style: _bold),
              const TextSpan(text: ' টি আইটেম যোগ করুন'),
            ]),
            if (_amountShort) _AmberHint(_amountMessage()),
          ]),
        ),
        if (_pieces > 0 && _rules.hasAdvance) ...[const SizedBox(height: 14), _AdvanceBox(rules: _rules, pieces: _pieces, total: _total)],
        // The admin's condition note is pre-selection guidance: once a
        // quantity is chosen the live hints carry the rules with real
        // numbers, so the website hides it -- and so does the app.
        if (p.orderNote != null && _pieces == 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(p.orderNote!, style: const TextStyle(color: Color(0xFF92400E), fontSize: 15, height: 1.45))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _tiers() => Row(children: [
        for (final t in p.priceTiers)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Column(children: [
                Text(Money.bdt(t.unitPrice), style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.orange, fontSize: 16)),
                Text(t.maxQuantity == null ? '≥ ${t.minQuantity} pcs' : '${t.minQuantity}–${t.maxQuantity} pcs', style: const TextStyle(fontSize: 11.5, color: Brand.grayText)),
              ]),
            ),
          ),
      ]);

  List<Widget> _optionPicker() {
    final values = _values;
    final shown = _showAllOptions ? values : values.take(10).toList();
    final hasImages = values.any((v) => v.$2 != null);
    return [
      Text.rich(TextSpan(children: [
        TextSpan(text: '$_dimension: ', style: const TextStyle(fontWeight: FontWeight.w800)),
        TextSpan(text: _selectedValue ?? '', style: const TextStyle(color: Brand.blue)),
      ]), style: const TextStyle(fontSize: 17, height: 1.35)),
      const SizedBox(height: 12),
      if (hasImages)
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Room for the count badges, which sit over the corners.
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(top: 6, right: 6),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final (value, image) in shown)
              GestureDetector(
                onTap: () => setState(() => _selectedValue = value),
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: value == _selectedValue ? Brand.blue : const Color(0xFFE5E7EB), width: value == _selectedValue ? 2.5 : 1),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: NetImage(image, radius: 7),
                    ),
                  ),
                  if (_countFor(value) > 0) Positioned(right: -6, top: -6, child: _CountBadge(_countFor(value))),
                ]),
              ),
          ],
        )
      else
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (value, _) in shown)
            Stack(clipBehavior: Clip.none, children: [
              ChoiceChip(label: Text(value), selected: value == _selectedValue, onSelected: (_) => setState(() => _selectedValue = value)),
              if (_countFor(value) > 0) Positioned(right: -6, top: -6, child: _CountBadge(_countFor(value))),
            ]),
        ]),
      if (values.length > 10)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => setState(() => _showAllOptions = !_showAllOptions),
            child: Text(_showAllOptions ? 'Show fewer options' : 'Show all ${values.length} options', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      const SizedBox(height: 10),
      _table(),
    ];
  }

  Widget _table() => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            color: const Color(0xFFF9FAFB),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: const Row(children: [
              Expanded(flex: 4, child: Text('OPTION', style: TextStyle(fontWeight: FontWeight.w700, color: Brand.grayText, fontSize: 13, letterSpacing: .5))),
              Expanded(flex: 2, child: Text('PRICE', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: Brand.grayText, fontSize: 13, letterSpacing: .5))),
              Expanded(flex: 5, child: Text('QUANTITY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: Brand.grayText, fontSize: 13, letterSpacing: .5))),
            ]),
          ),
          for (final v in _rows)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
              child: Row(children: [
                Expanded(
                  flex: 4,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.attributes.length > 1 ? Attribute.describe(v.attributes.skip(1).toList()) : (v.attributes.firstOrNull?.value ?? v.skuId), style: const TextStyle(fontSize: 15)),
                    if (v.stock != null) Text('${NumberFormat('#,##0').format(v.stock)} in stock', style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
                Expanded(
                  flex: 2,
                  child: Text(Money.bdt(p.variantsPricedSeparately ? v.unitPrice : p.unitPrice),
                      textAlign: TextAlign.center, style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: (_qty[v.skuId] ?? 0) == 0
                        ? FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Brand.blue, minimumSize: const Size(96, 40)),
                            onPressed: p.isSoldOut ? null : () {
                              // The first tap jumps to what is still needed to reach the minimum.
                              final need = (p.minQuantity - _pieces).clamp(1, 100000);
                              _qty[v.skuId] = need;
                              _changed();
                            },
                            child: const Text('Add'),
                          )
                        // Shrinks rather than overflows on the narrowest phones.
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: QtyStepper(value: _qty[v.skuId] ?? 0, onChanged: (n) {
                              _qty[v.skuId] = n;
                              _changed();
                            }),
                          ),
                  ),
                ),
              ]),
            ),
        ]),
      );

  Widget _singleRow() => Row(children: [
        const Expanded(child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
        _single == 0
            ? FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Brand.blue, minimumSize: const Size(110, 44)),
                onPressed: p.isSoldOut ? null : () {
                  _single = p.minQuantity;
                  _changed();
                },
                child: const Text('Add'),
              )
            : QtyStepper(value: _single, onChanged: (n) {
                _single = n;
                _changed();
              }),
      ]);

  // ---------------------------------------------------------------- bottom bar

  Widget _bottomBar() {
    // Active at 0 pieces, as on the website: a tap says what is missing.
    final disabled = p.isSoldOut || p.onPricingHold;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(children: [
            _BarIcon(icon: Icons.home_outlined, label: 'Home', onTap: () => context.go('/')),
            _BarIcon(icon: Icons.menu, label: 'Categories', onTap: () => context.go('/categories')),
            const SizedBox(width: 6),
            Expanded(
              child: BusyButton(label: 'Add to Cart', outlined: false, color: Brand.blue, onPressed: disabled ? null : () => _add(buyNow: false)),
            ),
            const SizedBox(width: 8),
            Expanded(child: BusyButton(label: 'Buy Now', onPressed: disabled ? null : () => _add(buyNow: true))),
          ]),
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: const Color(0xFF4B5563)),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
          ]),
        ),
      );
}

/// The website's swatch badge: the pieces chosen under that option, in a
/// blue bubble on the swatch's corner.
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 22),
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Brand.blue,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Text(NumberFormat('#,##0').format(count), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, height: 1.1)),
      );
}

/// An amber hint box under the running total, as the website's.
class _AmberHint extends StatelessWidget {
  const _AmberHint(this.spans);
  final List<InlineSpan> spans;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFF92400E))),
          const SizedBox(width: 8),
          Expanded(child: Text.rich(TextSpan(children: spans), style: const TextStyle(fontSize: 15, height: 1.65, color: Color(0xFF92400E)))),
        ]),
      );
}

/// The website's advance-payment box: what this selection costs, and what is
/// payable now versus on delivery.
class _AdvanceBox extends StatelessWidget {
  const _AdvanceBox({required this.rules, required this.pieces, required this.total});
  final OrderRules rules;
  final int pieces;
  final double total;

  static const _hl = TextStyle(fontWeight: FontWeight.w800, color: Brand.orange);

  @override
  Widget build(BuildContext context) {
    final now = rules.advanceOn(total);
    final rest = total - now;
    final pct = rules.advancePercent ?? 0;
    String pctLabel(double v) => Money.bn(v == v.roundToDouble() ? v.round() : v);
    final sentence = <InlineSpan>[
      if (pct > 0 && pct < 100) ...[
        const TextSpan(text: 'এখন আপনাকে মোট অর্ডারের '),
        TextSpan(text: '${pctLabel(pct)}%', style: _hl),
        const TextSpan(text: ' এর '),
        TextSpan(text: Money.bdt('$now'), style: _hl),
        const TextSpan(text: ' প্রদান করতে হবে — বাকি '),
        TextSpan(text: '${pctLabel(100 - pct)}%', style: _hl),
        const TextSpan(text: ' এর '),
        TextSpan(text: Money.bdt('$rest'), style: _hl),
        const TextSpan(text: ' ডেলিভারির সময় পরিশোধ করতে হবে।'),
      ] else if (pct >= 100) ...[
        const TextSpan(text: 'এখন আপনাকে মোট অর্ডারের '),
        TextSpan(text: '${pctLabel(pct)}%', style: _hl),
        const TextSpan(text: ' এর '),
        TextSpan(text: Money.bdt('$now'), style: _hl),
        const TextSpan(text: ' অর্থাৎ সম্পূর্ণ মূল্য পরিশোধ করতে হবে।'),
      ] else ...[
        const TextSpan(text: 'এখন আপনাকে সর্বনিম্ন '),
        TextSpan(text: Money.bdt('${rules.advanceFixed}'), style: _hl),
        const TextSpan(text: ' প্রদান করতে হবে — বাকি '),
        TextSpan(text: Money.bdt('$rest'), style: _hl),
        const TextSpan(text: ' ডেলিভারির সময় পরিশোধ করতে হবে।'),
      ],
    ];
    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: strong ? Brand.ink : const Color(0xFF4B5563), fontWeight: strong ? FontWeight.w800 : FontWeight.w400))),
            Text(value, style: TextStyle(fontSize: strong ? 17 : 15, fontWeight: strong ? FontWeight.w800 : FontWeight.w600, color: strong ? Brand.orange : Brand.ink)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFED7AA))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        row('Unit price', Money.bdt('${total / pieces}')),
        row('Selected quantity', '$pieces'),
        row('Total', Money.bdt('$total')),
        const Divider(color: Color(0xFFFED7AA), height: 14),
        row('Net payable now', Money.bdt('$now'), strong: true),
        const SizedBox(height: 8),
        Text.rich(TextSpan(children: sentence), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF374151))),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon, this.filled = false});
  final String text;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: filled ? Brand.blue : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 15, color: filled ? Colors.white : Brand.grayText), const SizedBox(width: 3)],
          Text(text, style: TextStyle(color: filled ? Colors.white : const Color(0xFF4B5563), fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      );
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({this.icon, this.iconWidget, required this.onTap, required this.tooltip, this.color = const Color(0xFF374151), this.background = const Color(0xFFF3F4F6)});
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(width: 36, height: 36, child: Center(child: iconWidget ?? Icon(icon, size: 19, color: color))),
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.amber = false});
  final String text;
  final bool amber;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: amber ? const Color(0xFFFFFBEB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: amber ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB)),
        ),
        child: Text(text, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: amber ? const Color(0xFF92400E) : const Color(0xFF374151))),
      );
}

// ------------------------------------------------------------------ gallery

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images, this.videoUrl});
  final List<String> images;
  final String? videoUrl;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  PageController _pages = PageController();
  int _index = 0;

  /// The main frame shows the video instead of the photos, as the website's
  /// gallery does; any photo thumb brings the photos back (and stops it).
  bool _video = false;

  void _showPhoto(int i) {
    if (_video) {
      // The photos come back as a fresh PageView, opened on the chosen one.
      _pages.dispose();
      setState(() {
        _pages = PageController(initialPage: i);
        _index = i;
        _video = false;
      });
      return;
    }
    _pages.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _zoom() => Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
          body: PageView.builder(
            controller: PageController(initialPage: _index),
            itemCount: widget.images.length,
            itemBuilder: (_, i) => InteractiveViewer(maxScale: 4, child: Center(child: NetImage(widget.images[i], fit: BoxFit.contain, radius: 0))),
          ),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.isEmpty && widget.videoUrl != null) return AspectRatio(aspectRatio: 1, child: ProductVideo(url: widget.videoUrl!));
    if (images.isEmpty) return const AspectRatio(aspectRatio: 1, child: NetImage(null));
    return Column(children: [
      AspectRatio(
        aspectRatio: 1,
        child: _video
            ? ProductVideo(url: widget.videoUrl!, poster: images.first)
            : Stack(children: [
          PageView.builder(
            controller: _pages,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => GestureDetector(onTap: _zoom, child: NetImage(images[i], fit: BoxFit.contain, radius: 10)),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(icon: const Icon(Icons.zoom_in, color: Color(0xFF374151)), onPressed: _zoom),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 72,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final (i, url) in images.indexed) ...[
            _Thumb(
              selected: !_video && i == _index,
              onTap: () => _showPhoto(i),
              child: NetImage(url, radius: 8),
            ),
            // Second position, as on the website: the first photo stays the
            // lead, and the video is never buried at the end of a long strip.
            if (i == 0 && widget.videoUrl != null)
              _Thumb(
                selected: _video,
                onTap: () => setState(() => _video = true),
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(images.first, radius: 8),
                  Container(decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8))),
                  const Center(child: CircleAvatar(radius: 16, backgroundColor: Colors.white, child: Icon(Icons.play_arrow_rounded, color: Brand.ink))),
                ]),
              ),
          ],
        ]),
      ),
    ]);
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Brand.blue : const Color(0xFFE5E7EB), width: selected ? 2.5 : 1),
          ),
          child: child,
        ),
      );
}

// ------------------------------------------------------------------ shipping

class _ShippingCard extends StatefulWidget {
  const _ShippingCard({required this.title, required this.methods});
  final String title;
  final List<ShippingMethod> methods;

  @override
  State<_ShippingCard> createState() => _ShippingCardState();
}

class _ShippingCardState extends State<_ShippingCard> {
  int _tab = 0;

  /// "ক্যাটাগরিঃ A" -> "A", the letter in the round badge.
  String _letter(String name) {
    final parts = name.split(RegExp(r'[\s:ঃ]+')).where((x) => x.isNotEmpty).toList();
    final last = parts.isEmpty ? '•' : parts.last;
    return last.length <= 2 ? last : last.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    final method = widget.methods[_tab.clamp(0, widget.methods.length - 1)];
    return WebCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.inventory_2_outlined, color: Brand.blue),
          const SizedBox(width: 8),
          Text(widget.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        if (widget.methods.length > 1)
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(24)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final (i, m) in widget.methods.indexed)
                  GestureDetector(
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: i == _tab ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: i == _tab ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 4)] : null,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(m.name.toLowerCase().contains('sea') ? Icons.directions_boat_outlined : Icons.flight_outlined,
                            size: 18, color: i == _tab ? Brand.blue : Brand.grayText),
                        const SizedBox(width: 6),
                        Text(m.name, style: TextStyle(fontWeight: FontWeight.w700, color: i == _tab ? Brand.blue : Brand.grayText)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        for (final r in method.rates)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3F4F6))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 14, backgroundColor: Brand.blue, child: Text(_letter(r.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                const SizedBox(width: 10),
                Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                if (r.pricePerKg != null)
                  Text('${Money.bdt(r.pricePerKg).replaceFirst('৳', '')} BDT', style: const TextStyle(color: Brand.blue, fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              const SizedBox(height: 8),
              Text(r.details, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14.5, height: 1.5)),
            ]),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ related

/// The website's "Related products" strip: the same category's top sellers,
/// two-up in the standard card, below the tabs. Loads after the page and
/// draws nothing when there is nothing to show (or it fails), as the
/// website's partial does.
class _Related extends ConsumerWidget {
  const _Related({required this.product});
  final ProductDetail product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(relatedProvider(product.id)).value ?? const <ProductCard>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: WebCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KickerHeader(
            title: 'Related products',
            onViewAll: product.categoryId == null ? null : () => context.push('/category/${product.categoryId}'),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, box) {
            // The same sizing as the listing grid's cards.
            final card = (box.maxWidth - 12) / 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: card + 122 * MediaQuery.textScalerOf(context).scale(1),
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => WebProductCard(product: items[i]),
            );
          }),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ tabs

class _InfoTabs extends ConsumerStatefulWidget {
  const _InfoTabs({required this.product});
  final ProductDetail product;

  @override
  ConsumerState<_InfoTabs> createState() => _InfoTabsState();
}

class _InfoTabsState extends ConsumerState<_InfoTabs> {
  int _tab = 0;
  List<String>? _description;
  bool _loadingDescription = false;
  Object? _descriptionError;

  @override
  void initState() {
    super.initState();
    _description = widget.product.descriptionImages;
  }

  Future<void> _loadDescription() async {
    if (_description != null || _loadingDescription) return;
    setState(() => _loadingDescription = true);
    try {
      final images = await ref.read(apiProvider).description(widget.product.id);
      if (mounted) setState(() => _description = images);
    } catch (e) {
      if (mounted) setState(() => _descriptionError = e);
    } finally {
      if (mounted) setState(() => _loadingDescription = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = ['Specification', 'Description', 'Seller Info'];
    return WebCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
          child: Row(children: [
            for (final (i, t) in tabs.indexed)
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _tab = i);
                    if (i == 1) _loadDescription();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == _tab ? Brand.blue : Colors.transparent, width: 3))),
                    child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: i == _tab ? Brand.blue : Brand.grayText)),
                  ),
                ),
              ),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: [_spec(), _desc(), _seller()][_tab]),
      ]),
    );
  }

  Widget _table(List<Attribute> rows) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (final (i, r) in rows.indexed)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 130,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    border: Border(top: i == 0 ? BorderSide.none : const BorderSide(color: Color(0xFFF3F4F6)), right: const BorderSide(color: Color(0xFFF3F4F6))),
                  ),
                  child: Text(r.label, style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w500, fontSize: 14.5)),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border(top: i == 0 ? BorderSide.none : const BorderSide(color: Color(0xFFF3F4F6)))),
                    child: Text(r.value, style: const TextStyle(fontSize: 14.5, height: 1.4)),
                  ),
                ),
              ]),
            ),
        ]),
      );

  Widget _spec() => widget.product.specs.isEmpty
      ? const Text('No specifications were published for this product.', style: TextStyle(color: Brand.grayText))
      : _table(widget.product.specs);

  Widget _desc() {
    if (_loadingDescription) return const LoadingView();
    if (_descriptionError != null && _description == null) return ErrorView(error: _descriptionError!, onRetry: _loadDescription);
    final images = _description ?? const [];
    if (_description == null) return const LoadingView();
    if (images.isEmpty) return const Text('No description images were published for this product.', style: TextStyle(color: Brand.grayText));
    return Column(children: [for (final url in images) NetImage(url, fit: BoxFit.fitWidth, radius: 0)]);
  }

  Widget _seller() {
    final s = widget.product.seller;
    if (s == null) return const Text('No seller information for this product.', style: TextStyle(color: Brand.grayText));
    final type = s['is_super_factory'] == true ? 'Super factory' : (s['is_factory'] == true ? 'Factory' : s['biz_type']);
    final id = int.tryParse('${s['id']}');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${s['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      if (s['biz_type'] != null)
        Padding(padding: const EdgeInsets.only(top: 2), child: Text('${s['biz_type']}', style: const TextStyle(fontSize: 12.5, color: Brand.grayText))),
      // The website's "Visit Store": the seller's page here in the app,
      // everything of theirs in our catalogue.
      if (id != null) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => context.push('/seller/$id', extra: s),
            style: FilledButton.styleFrom(
              backgroundColor: Brand.blue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Visit Store', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
      const SizedBox(height: 12),
      _table([
        Attribute("Seller's total sales", compactCount(int.tryParse('${s['total_sales']}') ?? 0)),
        if (s['rating'] != null) Attribute("Seller's rating", '${s['rating']} / 5'),
        Attribute("Seller's products listed", '${s['products']}'),
        if (s['years'] != null) Attribute('Years in business', '${s['years']} years'),
        if (type != null) Attribute('Supplier type', '$type'),
        if (s['location'] != null) Attribute('Location', '${s['location']}'),
        Attribute('Units sold (this product)', compactCount(widget.product.saleCount)),
      ]),
    ]);
  }
}

/// The product name on its page: the website's 17px bold, a step down from
/// the heavier 19px it used to be.
const productTitleStyle = TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, height: 1.35);

/// The website's WhatsApp glyph (catalog/show.blade.php).
const _whatsAppLogo = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#fff" fill-rule="evenodd" d="M17.5 14.4c-.3-.2-1.7-.9-2-1-.3-.1-.5-.1-.7.1-.2.3-.7 1-.9 1.2-.2.2-.3.2-.6.1-1.6-.8-2.7-1.5-3.7-3.3-.3-.5.3-.5.8-1.5.1-.2 0-.4 0-.5s-.7-1.6-.9-2.2c-.2-.5-.5-.5-.7-.5h-.6c-.2 0-.5.1-.8.4-.3.3-1 1-1 2.5s1.1 2.9 1.2 3.1c.1.2 2.1 3.2 5.1 4.4 1.9.8 2.6.9 3.5.7.6-.1 1.7-.7 1.9-1.4.2-.7.2-1.2.2-1.4-.1-.1-.3-.2-.6-.3M12 2a10 10 0 00-8.6 15L2 22l5.1-1.3A10 10 0 1012 2z"/></svg>';

/// The product page while it loads: the same cards in the same places, with
/// what the tapped card already knew filled in and a soft shimmer where the
/// rest will land -- so the tap answers at once, and nothing jumps when the
/// details arrive.
class ProductSkeleton extends StatelessWidget {
  const ProductSkeleton({super.key, this.preview});
  final ProductCard? preview;

  @override
  Widget build(BuildContext context) {
    final card = preview;
    return Scaffold(
      appBar: const SiteHeader(),
      body: Shimmer(
        child: ListView(physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          WebCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Material(
                  color: const Color(0xFFF3F4F6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => context.canPop() ? context.pop() : context.go('/'),
                    child: const SizedBox(width: 44, height: 44, child: Icon(Icons.chevron_left, size: 28)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: card != null
                      ? Text(card.title, style: productTitleStyle)
                      : const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Bone(height: 16), SizedBox(height: 8), Bone(height: 16, width: 180)]),
                ),
              ]),
              const SizedBox(height: 14),
              const Row(children: [Bone(height: 34, width: 130, radius: 20), Spacer(), Bone(height: 36, width: 36, radius: 10), SizedBox(width: 6), Bone(height: 36, width: 36, radius: 10), SizedBox(width: 6), Bone(height: 36, width: 36, radius: 10)]),
            ]),
          ),
          const SizedBox(height: 16),
          WebCard(
            padding: const EdgeInsets.all(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: card?.imageUrl != null ? NetImage(card!.imageUrl, radius: 12) : const Bone(radius: 12),
            ),
          ),
          const SizedBox(height: 16),
          WebCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (card != null && !card.onPricingHold)
                Text('${card.priceFrom ? 'from ' : ''}${Money.bdt(card.unitPrice)}', style: const TextStyle(color: Brand.orange, fontSize: 24, fontWeight: FontWeight.w800))
              else
                const Bone(height: 26, width: 120),
              const SizedBox(height: 14),
              const Bone(height: 14),
              const SizedBox(height: 10),
              const Bone(height: 14, width: 220),
              const SizedBox(height: 18),
              const Row(children: [Bone(height: 64, width: 64, radius: 10), SizedBox(width: 8), Bone(height: 64, width: 64, radius: 10), SizedBox(width: 8), Bone(height: 64, width: 64, radius: 10)]),
            ]),
          ),
        ]),
      ),
    );
  }
}
