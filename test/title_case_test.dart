import 'package:easybuy/core/text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product names read in Title Case', () {
    expect(titleCase('cross-border 10 simple wooden wall clocks for living room'), 'Cross-Border 10 Simple Wooden Wall Clocks for Living Room');
    expect(titleCase('new nordic style iron wall clock'), 'New Nordic Style Iron Wall Clock');
    // Written capitals are kept; joining words start and end the name in capitals.
    expect(titleCase('USB LED lamp for iPhone and eBay sellers'), 'USB LED Lamp for iPhone and eBay Sellers');
    expect(titleCase('the bag to carry on'), 'The Bag to Carry On');
    expect(titleCase('(new) 3d printed toy 10pcs'), '(New) 3d Printed Toy 10pcs');
    expect(titleCase('চীন থেকে পণ্য'), 'চীন থেকে পণ্য');
  });
}
