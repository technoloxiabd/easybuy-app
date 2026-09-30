import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../screens/article_screen.dart' show openSiteLink;
import '../screens/image_search_screen.dart' show startImageSearch;
import '../screens/order_screens.dart' show openExternal;

/// The footer's company block; loaded once per session (pull to refresh on
/// Home asks again).
final companyProvider = FutureProvider<CompanyInfo>((ref) => ref.read(apiProvider).company());

const _white = Colors.white;
const _line = Color(0x1AFFFFFF); // white/10

/// The website's footer (layouts/footer.blade.php) as it stands on a phone:
/// deep navy gradient, the trust strip, the brand and contact block, the
/// two link columns with the Bengali shipping note, and the copyright bar
/// (owner, 30 Sep 2026: the app had no footer). The company details are the
/// admin's (Settings › Company) and come from the API; until they arrive, or
/// if they cannot, the footer shows only its fixed parts.
class SiteFooter extends ConsumerWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(companyProvider).value;
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Brand.blue, Brand.blueDark])),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: _white, fontSize: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _TrustStrip(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (company != null) ...[_Brand(company: company), const SizedBox(height: 40)],
              _LinkColumn(title: 'Company', links: [
                ('About us', () => openExternal(context, '${AppConfig.siteBase}/about')),
                ('Contact', () => openExternal(context, '${AppConfig.siteBase}/contact')),
                ('All Products', () => openSiteLink(context, '${AppConfig.siteBase}/products')),
                ('Search by Image', () => startImageSearch(context)),
                ('Videos', () => context.push('/videos')),
                ('Blog', () => openSiteLink(context, '${AppConfig.siteBase}/blog')),
              ]),
              const SizedBox(height: 40),
              _LinkColumn(title: 'Help & Policies', links: [
                ('Returns & Refund', () => openExternal(context, '${AppConfig.siteBase}/returns-refund')),
                ('Privacy Policy', () => openExternal(context, '${AppConfig.siteBase}/privacy-policy')),
                ('Terms & Conditions', () => openExternal(context, '${AppConfig.siteBase}/terms')),
              ]),
              const SizedBox(height: 24),
              const _Note(),
            ]),
          ),
          _BottomBar(legalName: company?.legalName),
        ]),
      ),
    );
  }
}

/// An outline icon from the website's footer: its 24-unit SVG markup,
/// stroked in [color].
Widget _outline(String markup, {double size = 20, Color color = Brand.orange, double stroke = 1.7}) => SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">$markup</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

/// The four service promises above the footer's columns, two by two.
class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  static const _items = [
    ('<path d="M12 19V5m0 0l-6 6m6-6l6 6M4 21h16"/>', 'Air Shipping', '7–12 days'),
    ('<path d="M3 17h18M5 17l1.5-6h11L19 17M9 11V7h6v4M2 21h20"/>', 'Sea Shipping', '35–50 days'),
    ('<path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4h4v4a1 1 0 001 1m-6 0h6"/>', 'Door Delivery', 'Nationwide'),
    ('<path d="M9 12l2 2 4-4m5.6 2A9 9 0 1112 3a9 9 0 018.6 9z"/>', 'Factory Prices', 'Direct wholesale'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget item((String, String, String) t) => Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(12)),
            child: _outline(t.$1, stroke: 1.8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(t.$3, style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ]),
          ),
        ]);
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(children: [
        Row(children: [Expanded(child: item(_items[0])), const SizedBox(width: 24), Expanded(child: item(_items[1]))]),
        const SizedBox(height: 24),
        Row(children: [Expanded(child: item(_items[2])), const SizedBox(width: 24), Expanded(child: item(_items[3]))]),
      ]),
    );
  }
}

/// Logo (or the legal name), tagline, contacts and social icons.
class _Brand extends StatelessWidget {
  const _Brand({required this.company});
  final CompanyInfo company;

  @override
  Widget build(BuildContext context) {
    final c = company;
    final wordmark = Text(c.legalName.isNotEmpty ? c.legalName : c.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5));
    Widget contact(String icon, Widget text, {VoidCallback? onTap, bool top = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: InkWell(
            onTap: onTap,
            child: Row(crossAxisAlignment: top ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
              Padding(padding: EdgeInsets.only(top: top ? 1 : 0), child: _outline(icon)),
              const SizedBox(width: 12),
              Expanded(child: text),
            ]),
          ),
        );
    const soft = TextStyle(color: Colors.white70, height: 1.4);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (c.logoUrl != null)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190, maxHeight: 40),
          child: CachedNetworkImage(imageUrl: c.logoUrl!, height: 40, fit: BoxFit.contain, alignment: Alignment.centerLeft, errorWidget: (_, _, _) => wordmark),
        )
      else
        wordmark,
      if (c.tagline.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(c.tagline, style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white70)),
      ],
      const SizedBox(height: 24),
      if (c.address.isNotEmpty)
        contact('<path d="M17.657 16.657L13.414 20.9a2 2 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/><circle cx="12" cy="11" r="2.5"/>', Text(c.address, style: soft), top: true),
      if (c.phone.isNotEmpty)
        contact(
          '<path d="M3 5a2 2 0 012-2h2.5a1 1 0 011 .76l1 4a1 1 0 01-.29.95l-1.5 1.5a14 14 0 006.1 6.1l1.5-1.5a1 1 0 01.95-.29l4 1a1 1 0 01.76 1V19a2 2 0 01-2 2A16 16 0 013 5z"/>',
          Text(c.phone, style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () => openExternal(context, 'tel:${c.phone.replaceAll(RegExp(r'[^+0-9]'), '')}'),
        ),
      if (c.email.isNotEmpty)
        contact('<path d="M4 6h16v12H4z M4 7l8 6 8-6"/>', Text(c.email, style: soft), onTap: () => openExternal(context, 'mailto:${c.email}')),
      if (c.hours.isNotEmpty) contact('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>', Text(c.hours, style: soft)),
      if (c.social.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final (network, url) in c.social)
              Tooltip(
                message: network.isEmpty ? network : '${network[0].toUpperCase()}${network.substring(1)}',
                child: Material(
                  color: _line,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => openExternal(context, url),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: _socialGlyphs[network.toLowerCase()] != null
                            ? SvgPicture.string(
                                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="${_socialGlyphs[network.toLowerCase()]}"/></svg>',
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(Color(0xE6FFFFFF), BlendMode.srcIn),
                              )
                            // An unknown network: its initial, as the website.
                            : Text(network.isEmpty ? '' : network[0].toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
    ]);
  }
}

/// A heading with its short orange bar, then the links.
class _LinkColumn extends StatelessWidget {
  const _LinkColumn({required this.title, required this.links});
  final String title;
  final List<(String, VoidCallback)> links;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        Container(width: 32, height: 2, decoration: BoxDecoration(color: Brand.orange, borderRadius: BorderRadius.circular(1))),
        const SizedBox(height: 14),
        for (final (label, onTap) in links)
          InkWell(
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(label, style: const TextStyle(color: Colors.white70))),
          ),
      ]);
}

/// "জেনে রাখুন": product prices exclude shipping, charged by real weight.
class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0x0DFFFFFF), border: Border.all(color: _line), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _outline('<path d="M13 16h-1v-4h-1m2-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>', size: 16, stroke: 1.8),
            const SizedBox(width: 8),
            // No uppercase or letter spacing: Bengali has no case.
            const Text('জেনে রাখুন', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
          ]),
          const SizedBox(height: 4),
          const Text(
            'আমাদের ওয়েবসাইটে প্রদর্শিত সকল পণ্যের মূল্য শুধুমাত্র পণ্যের জন্যই প্রযোজ্য। '
            'পার্সেলটি আমাদের ঢাকা ওয়্যারহাউসে পৌঁছানোর পর প্রকৃত ওজনের ভিত্তিতে শিপিং চার্জ যুক্ত করা হবে।',
            style: TextStyle(fontSize: 12, height: 1.6, color: Colors.white60),
          ),
        ]),
      );
}

/// Copyright and the three policy links on a darker band.
class _BottomBar extends StatelessWidget {
  const _BottomBar({this.legalName});
  final String? legalName;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, color: Colors.white54);
    Widget link(String label, String path) => InkWell(
          onTap: () => openExternal(context, '${AppConfig.siteBase}$path'),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: Text(label, style: style)),
        );
    return Container(
      decoration: const BoxDecoration(color: Color(0x33000000), border: Border(top: BorderSide(color: _line))),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(children: [
        if (legalName != null && legalName!.isNotEmpty) Text('© ${DateTime.now().year} $legalName. All rights reserved.', style: style, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          link('Privacy', '/privacy-policy'),
          link('Terms', '/terms'),
          link('Refunds', '/returns-refund'),
        ]),
      ]),
    );
  }
}

/// The website's social glyphs (single-path Simple Icons shapes, 24 units).
const _socialGlyphs = <String, String>{
  'facebook': 'M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z',
  'instagram': 'M12 0C8.74 0 8.333.015 7.053.072 5.775.132 4.905.333 4.14.63c-.789.306-1.459.717-2.126 1.384S.935 3.35.63 4.14C.333 4.905.131 5.775.072 7.053.012 8.333 0 8.74 0 12s.015 3.667.072 4.947c.06 1.277.261 2.148.558 2.913.306.788.717 1.459 1.384 2.126.667.666 1.336 1.079 2.126 1.384.766.296 1.636.499 2.913.558C8.333 23.988 8.74 24 12 24s3.667-.015 4.947-.072c1.277-.06 2.148-.262 2.913-.558.788-.306 1.459-.718 2.126-1.384.666-.667 1.079-1.335 1.384-2.126.296-.765.499-1.636.558-2.913.06-1.28.072-1.687.072-4.947s-.015-3.667-.072-4.947c-.06-1.277-.262-2.149-.558-2.913-.306-.789-.718-1.459-1.384-2.126C21.319 1.347 20.651.935 19.86.63c-.765-.297-1.636-.499-2.913-.558C15.667.012 15.26 0 12 0zm0 2.16c3.203 0 3.585.016 4.85.071 1.17.055 1.805.249 2.227.415.562.217.96.477 1.382.896.419.42.679.819.896 1.381.164.422.36 1.057.413 2.227.057 1.266.07 1.646.07 4.85s-.015 3.585-.074 4.85c-.061 1.17-.256 1.805-.421 2.227-.224.562-.479.96-.899 1.382-.419.419-.824.679-1.38.896-.42.164-1.065.36-2.235.413-1.274.057-1.649.07-4.859.07-3.211 0-3.586-.015-4.859-.074-1.171-.061-1.816-.256-2.236-.421-.569-.224-.96-.479-1.379-.899-.421-.419-.69-.824-.9-1.38-.165-.42-.359-1.065-.42-2.235-.045-1.26-.061-1.649-.061-4.844 0-3.196.016-3.586.061-4.861.061-1.17.255-1.814.42-2.234.21-.57.479-.96.9-1.381.419-.419.81-.689 1.379-.898.42-.166 1.051-.361 2.221-.421 1.275-.045 1.65-.06 4.859-.06l.045.03zm0 3.678c-3.405 0-6.162 2.76-6.162 6.162 0 3.405 2.76 6.162 6.162 6.162 3.405 0 6.162-2.76 6.162-6.162 0-3.405-2.76-6.162-6.162-6.162zM12 16c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4zm7.846-10.405c0 .795-.646 1.44-1.44 1.44-.795 0-1.44-.646-1.44-1.44 0-.794.646-1.439 1.44-1.439.793-.001 1.44.645 1.44 1.439z',
  'youtube': 'M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z',
  'tiktok': 'M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z',
  'whatsapp': 'M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z',
};
