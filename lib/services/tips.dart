import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// "Buy me a coffee": one-time tips through the App Store / Google Play.
/// Nothing unlocks; a tip is a thank-you.
enum Tip {
  small('tinta.tip.small', 'Coffee', 1),
  medium('tinta.tip.medium', 'Big coffee', 2),
  large('tinta.tip.large', 'Coffee & cake', 3);

  const Tip(this.productId, this.label, this.cups);

  /// Consumable product id; the same in App Store Connect and Play Console.
  final String productId;
  final String label;
  final int cups;

  static Tip? byId(String id) {
    for (final t in values) {
      if (t.productId == id) return t;
    }
    return null;
  }
}

/// A tip as the store sells it.
class TipOffer {
  const TipOffer(this.tip, this.price, [this.details]);

  final Tip tip;

  /// Localized, e.g. "$1.99" or "₹99".
  final String price;
  final ProductDetails? details;
}

enum TipOutcome { purchased, pending, failed, canceled }

/// The store, behind an interface so tests can stand in for it.
abstract class TipStore {
  Future<bool> isAvailable();
  Future<List<TipOffer>> offers();
  Future<void> buy(TipOffer offer);

  /// Purchase updates, as (product id, outcome). Must be listened to from
  /// launch: the stores redeliver unfinished purchases.
  Stream<(String, TipOutcome)> get updates;
}

/// Apple / Google through the in_app_purchase plugin.
class StoreTipStore implements TipStore {
  final _iap = InAppPurchase.instance;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<TipOffer>> offers() async {
    final r = await _iap.queryProductDetails({
      for (final t in Tip.values) t.productId,
    });
    final offers = [
      for (final d in r.productDetails)
        if (Tip.byId(d.id) case final tip?) TipOffer(tip, d.price, d),
    ]..sort((a, b) => a.tip.index.compareTo(b.tip.index));
    return offers;
  }

  @override
  Future<void> buy(TipOffer offer) => _iap.buyConsumable(
    purchaseParam: PurchaseParam(productDetails: offer.details!),
  );

  @override
  Stream<(String, TipOutcome)> get updates =>
      _iap.purchaseStream.asyncExpand((list) async* {
        for (final p in list) {
          final outcome = switch (p.status) {
            PurchaseStatus.purchased ||
            PurchaseStatus.restored => TipOutcome.purchased,
            PurchaseStatus.pending => TipOutcome.pending,
            PurchaseStatus.canceled => TipOutcome.canceled,
            PurchaseStatus.error => TipOutcome.failed,
          };
          // Finish the transaction so the store doesn't redeliver it.
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          yield (p.productID, outcome);
        }
      });
}

/// No store (tests, unsupported platforms).
class NoTipStore implements TipStore {
  const NoTipStore();
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<List<TipOffer>> offers() async => const [];
  @override
  Future<void> buy(TipOffer offer) async {}
  @override
  Stream<(String, TipOutcome)> get updates => const Stream.empty();
}

enum TipJarState { idle, loading, unavailable, ready, buying, thanked }

/// What the tip sheet shows; owns the store connection for the app's life.
class TipJar extends ChangeNotifier {
  TipJar([this.store = const NoTipStore()]);

  final TipStore store;
  StreamSubscription<(String, TipOutcome)>? _sub;

  TipJarState _state = TipJarState.idle;
  List<TipOffer> _offers = const [];
  Tip? _buying;
  String? _error;

  TipJarState get state => _state;
  List<TipOffer> get offers => _offers;

  /// The tip being paid for, while [state] is [TipJarState.buying].
  Tip? get buying => _buying;

  /// Why the last payment didn't go through (cleared on the next try).
  String? get error => _error;

  void Function(Tip tip)? _onTipped;
  final _unreported = <Tip>[];

  /// Called after every completed tip (e.g. to count them in prefs). Tips
  /// that land before it is set (during the splash) are reported then.
  set onTipped(void Function(Tip tip)? f) {
    _onTipped = f;
    if (f == null) return;
    for (final t in _unreported) {
      f(t);
    }
    _unreported.clear();
  }

  /// Start listening for purchases. Call once, at launch.
  void start() {
    _sub ??= store.updates.listen(_onUpdate);
  }

  /// Fetch prices (when the sheet opens).
  Future<void> load() async {
    if (_state == TipJarState.loading || _state == TipJarState.buying) return;
    _set(TipJarState.loading);
    _error = null;
    try {
      if (!await store.isAvailable()) return _set(TipJarState.unavailable);
      _offers = await store.offers();
      _set(_offers.isEmpty ? TipJarState.unavailable : TipJarState.ready);
    } catch (_) {
      _set(TipJarState.unavailable);
    }
  }

  Future<void> buy(TipOffer offer) async {
    if (_state == TipJarState.buying) return;
    _buying = offer.tip;
    _error = null;
    _set(TipJarState.buying);
    try {
      await store.buy(offer);
    } catch (_) {
      _buying = null;
      _error = 'The payment didn’t start. Try again in a moment.';
      _set(TipJarState.ready);
    }
  }

  /// Back to the choices (after a thank-you, when the sheet reopens).
  void reset() {
    if (_state == TipJarState.thanked) {
      _set(_offers.isEmpty ? TipJarState.idle : TipJarState.ready);
    }
  }

  void _onUpdate((String, TipOutcome) update) {
    final (id, outcome) = update;
    final tip = Tip.byId(id);
    if (tip == null) return;
    switch (outcome) {
      case TipOutcome.purchased:
        _buying = null;
        final report = _onTipped;
        report == null ? _unreported.add(tip) : report(tip);
        _set(TipJarState.thanked);
      case TipOutcome.pending:
        // Waiting on the store (e.g. Ask to Buy); stays "buying".
        break;
      case TipOutcome.canceled:
        _buying = null;
        _set(_offers.isEmpty ? TipJarState.idle : TipJarState.ready);
      case TipOutcome.failed:
        _buying = null;
        _error = 'The payment didn’t go through. You weren’t charged.';
        _set(_offers.isEmpty ? TipJarState.idle : TipJarState.ready);
    }
  }

  void _set(TipJarState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class TipJarScope extends InheritedNotifier<TipJar> {
  const TipJarScope({super.key, required TipJar jar, required super.child})
    : super(notifier: jar);

  static TipJar of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TipJarScope>()!.notifier!;
}
