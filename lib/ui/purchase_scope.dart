import 'package:flutter/widgets.dart';
import '../services/purchase_service.dart';

/// One app-owned store listener survives route changes and delayed payments.
class PurchaseScope extends InheritedWidget {
  const PurchaseScope({super.key, required this.service, required super.child});
  final PurchaseService service;
  static PurchaseService? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PurchaseScope>()?.service;
  @override
  bool updateShouldNotify(PurchaseScope oldWidget) =>
      oldWidget.service != service;
}
