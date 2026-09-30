import 'package:easybuy/ui/app.dart' show pushRoute;
import 'package:easybuy/ui/screens/article_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('website links open the matching app screen', () {
    expect(appRouteFor('https://easybuy.com.bd/blog/how-importing-works'), '/blog?url=${Uri.encodeComponent('https://easybuy.com.bd/blog/how-importing-works')}');
    expect(appRouteFor('https://easybuy.com.bd/blog'), startsWith('/blog?url='));
    expect(appRouteFor('https://easybuy.com.bd/products/iron-wall-clock-722930'), '/product/722930');
    expect(appRouteFor('https://easybuy.com.bd/p/722930'), '/product/722930');
    expect(appRouteFor('https://easybuy.com.bd/category/womens-bags-787'), '/category/787');
    expect(appRouteFor('https://easybuy.com.bd/products?q=hoodie'), '/search/results?q=hoodie');
    expect(appRouteFor('https://easybuy.com.bd/products'), '/shop');
  });

  test('other links stay with the browser', () {
    expect(appRouteFor('https://www.facebook.com/sharer/sharer.php?u=x'), isNull);
    expect(appRouteFor('https://easybuy.com.bd/account/orders'), isNull);
  });

  test('a broadcast notification opens its link in the app', () {
    expect(pushRoute({'type': 'link', 'url': 'https://easybuy.com.bd/products/iron-wall-clock-722930'}), '/product/722930');
    expect(pushRoute({'type': 'link', 'url': 'https://easybuy.com.bd/account/orders'}), isNull);
    expect(pushRoute({'type': 'home'}), isNull);
  });
}
