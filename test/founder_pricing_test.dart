import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungr/core/constants/business_rules.dart';
import 'package:hungr/features/storefront/domain/tiffin_item_model.dart';
import 'package:hungr/features/storefront/domain/tiffin_shop_model.dart';
import 'package:hungr/features/storefront/presentation/viewmodels/cart_viewmodel.dart';
import 'package:hungr/features/storefront/presentation/viewmodels/tiffin_shops_viewmodel.dart';

void main() {
  test('An empty live catalog does not advertise fallback breakfasts', () async {
    final stream = StreamController<List<TiffinShop>>();
    final container = ProviderContainer(overrides: [
      tiffinShopsProvider.overrideWith((ref) => TiffinShopsViewModel(catalogStream: stream.stream)),
    ]);
    addTearDown(container.dispose);
    addTearDown(stream.close);
    expect(passRotationItems(container.read(tiffinShopsProvider)), isNotEmpty);
    stream.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(passRotationItems(container.read(tiffinShopsProvider)), isEmpty);
  });

  test('Rotation checks every selling kitchen', () {
    final dosa = TiffinItem.findById('item_set_dosa')!;
    final uttapam = dosa.copyWith(id: 'item_uttapam', name: 'Uttapam', price: 50);
    final shop = TiffinShop.standardShops.first;
    final shops = [
      shop.copyWith(menuItems: [dosa, uttapam, TiffinItem.findById('addon_filter_coffee')!]),
      shop.copyWith(id: 'other', menuItems: [dosa.copyWith(price: 54), uttapam]),
    ];
    expect(passRotationItems(shops), [uttapam]);
    expect(passRotationItems([shop.copyWith(menuItems: [])]), isEmpty);
    expect(passRotationItems(TiffinShop.standardShops), contains(dosa));
  });

  test('Compact dishes use shop templates and isolate bad entries', () {
    final dosa = TiffinItem.findById('item_set_dosa')!;
    final custom = dosa.copyWith(id: 'item_uttapam', name: 'Uttapam');
    final shop = TiffinShop.fromMap({
      'menuItems': [custom.toMap(), {'id': dosa.id}],
      'dishes': [
        {'price': 40}, {'id': 'unknown', 'price': 45},
        {'id': dosa.id, 'price': -1}, {'id': dosa.id, 'price': '45'},
        {'id': dosa.id, 'price': 40, 'name': false},
        {'id': custom.id, 'price': 45}, {'id': dosa.id, 'price': 54},
      ],
    });
    expect(shop.menuItems.map((d) => (d.name, d.price)), [(custom.name, 45), (dosa.name, 54)]);
    expect(TiffinShop.fromMap({'dishes': [{'id': 'unknown', 'price': 45}]}).menuItems, isEmpty);
  });

  test('margin is per item and the pass cap applies after the margin', () {
    final dish = TiffinItem.standardMenuItems.first;
    int customerPrice(int hotelPrice) => BusinessRules.customerPriceForHotelPrice(hotelPrice);
    expect(customerPrice(0), 5);
    expect(customerPrice(45) * 2, 100);
    expect(() => customerPrice(-1), throwsArgumentError);
    for (final (price, eligible) in [(0, false), (-1, false), (1, true),
      (customerPrice(45), true), (customerPrice(46), false)]) {
      expect(dish.copyWith(price: price).isPassEligible, eligible, reason: 'customer price: $price');
    }
  });

  test('shop and single-day cart use the saved customer price, even above the pass cap', () {
    final template = TiffinItem.findById('item_set_dosa')!;
    final price = BusinessRules.customerPriceForHotelPrice(49);
    final shop = TiffinShop.fromMap({'id': 'fixture-shop', 'dishes': [
      {'id': template.id, 'name': template.name, 'price': price},
    ]});
    final dish = shop.menuItems.single;
    expect(dish.price, 54);
    expect(dish.isPassEligible, isFalse);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    final key = CartState.shopItemKey(shop.id, dish.id);
    cart.addItem(key, dish: dish);
    cart.addItem(key);
    cart.addItem(template.id);
    final state = container.read(cartProvider);
    expect(state.itemForKey(key)!.price, price);
    expect(state.itemsSubtotal, 2 * price + template.price);
    expect(state.savingsAmount, 2 * dish.savingsAmount + template.savingsAmount);
    cart.removeItem(key);
    expect(container.read(cartProvider).itemsSubtotal, price + template.price);
  });

  test('single-day dishes are not included or silently billed as part of a pass', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    final dish = TiffinItem.findById('item_poori_masala')!;
    cart.addItem(dish.id);
    final singleDay = container.read(cartProvider);
    expect(singleDay.totalPayable, dish.price);
    cart.setOrderMode(OrderMode.subscriptionPass);
    final pass = container.read(cartProvider);
    expect(pass.totalPayable, pass.passSubtotal);
    cart.addItem(dish.id);
    expect(container.read(cartProvider).orderMode, OrderMode.singleDay);
    expect(container.read(cartProvider).totalPayable, 2 * dish.price);
  });
}
