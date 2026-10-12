import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'backend_service.dart';
import 'media_upload_service.dart' show integrationErrorText;

class PurchaseService extends ChangeNotifier {
  PurchaseService(this.backend, {InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;
  final BackendService backend;
  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> products = [];
  String? error;
  String status = 'Магазин ещё не подключён.';
  bool busy = false;
  bool available = false;
  bool _disposed = false;
  Future<void> _delivery = Future.value();
  final Set<String> _pendingProducts = {};

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_subscription != null) return;
    if (!backend.isAuthenticated) {
      throw const IntegrationException(
        'Войдите в аккаунт перед покупкой или восстановлением.',
      );
    }
    final ids = backend.config.storeProductIds;
    if (ids.isEmpty) {
      throw const IntegrationException(
        'Магазин не настроен. Обратитесь к администратору приложения.',
      );
    }
    // Subscribe before querying: restored/pending transactions may arrive early.
    _subscription = _store.purchaseStream.listen(
      (purchases) {
        _delivery = _delivery.then((_) => _handle(purchases));
      },
      onError: (Object exception) {
        error = integrationErrorText(exception);
        _notify();
      },
    );
    try {
      available = await _store.isAvailable();
      if (!available) {
        throw const IntegrationException(
          'Магазин недоступен на этом устройстве.',
        );
      }
      final response = await _store.queryProductDetails(ids);
      if (response.error != null) {
        throw const IntegrationException(
          'Не удалось загрузить товары магазина.',
        );
      }
      products = response.productDetails;
      status = response.notFoundIDs.isEmpty
          ? 'Доступ выдаётся только после серверной проверки.'
          : 'Часть товаров недоступна: ${response.notFoundIDs.join(', ')}.';
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<void> buy(ProductDetails product) async {
    if (!backend.isAuthenticated) {
      throw const IntegrationException('Сначала войдите в аккаунт.');
    }
    if (!available || !backend.config.storeProductIds.contains(product.id)) {
      throw const IntegrationException('Товар недоступен.');
    }
    if (busy) return;
    busy = true;
    error = null;
    _pendingProducts.add(product.id);
    _notify();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: backend.userId,
        ),
      );
      if (!started) {
        throw const IntegrationException('Магазин не начал покупку.');
      }
      status = 'Ожидаем ответ магазина.';
    } catch (_) {
      _pendingProducts.remove(product.id);
      busy = _pendingProducts.isNotEmpty;
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<void> restore() async {
    if (!backend.isAuthenticated) {
      throw const IntegrationException('Сначала войдите в аккаунт.');
    }
    if (!available) throw const IntegrationException('Магазин недоступен.');
    status =
        'Запрошено восстановление; ждём транзакции магазина и серверную проверку.';
    error = null;
    _notify();
    await _store.restorePurchases(applicationUserName: backend.userId);
  }

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (_disposed) return;
      if (purchase.status == PurchaseStatus.pending) {
        _pendingProducts.add(purchase.productID);
        busy = true;
        status = 'Платёж ожидает подтверждения магазина.';
        _notify();
        continue;
      }
      try {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          status = 'Проверяем транзакцию на сервере.';
          _notify();
          final data = purchase.verificationData;
          final verified = await backend.verifyPurchase(
            productId: purchase.productID,
            source: data.source,
            receipt: data.serverVerificationData,
            purchaseId: purchase.purchaseID,
          );
          if (!verified) {
            throw const IntegrationException('Сервер не подтвердил покупку.');
          }
          // Never complete a transaction or grant access before verification.
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
          status = 'Транзакция проверена. Права доступа загружаются с сервера.';
          error = null;
        } else if (purchase.status == PurchaseStatus.error) {
          throw const IntegrationException(
            'Магазин отклонил покупку. Доступ не изменён.',
          );
        } else if (purchase.status == PurchaseStatus.canceled) {
          status = 'Покупка отменена.';
        }
      } catch (exception) {
        error = integrationErrorText(exception);
        status =
            'Доступ не подтверждён. Повторите восстановление после устранения ошибки.';
      } finally {
        _pendingProducts.remove(purchase.productID);
        busy = _pendingProducts.isNotEmpty;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
