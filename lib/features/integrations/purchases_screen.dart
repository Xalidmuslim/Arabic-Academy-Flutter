import 'package:flutter/material.dart';

import '../../services/backend_service.dart';
import '../../services/purchase_service.dart';
import '../../ui/purchase_scope.dart';
import 'integration_widgets.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key, required this.backend, this.purchases});
  final BackendService backend;

  /// App-owned service keeps pending transactions subscribed across navigation.
  final PurchaseService? purchases;
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen>
    with IntegrationActions<PurchasesScreen> {
  late final PurchaseService _purchases;
  bool _initialized = false;
  bool _ownsService = false;
  Future<List<Map<String, dynamic>>>? _access;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final shared = widget.purchases ?? PurchaseScope.of(context);
    _ownsService = shared == null;
    _purchases = shared ?? PurchaseService(widget.backend);
    _purchases.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runAction(_connect);
    });
  }

  void _changed() {
    // A verified transaction triggers a fresh read; never a local access flag.
    if (mounted && _purchases.status.startsWith('Транзакция проверена')) {
      setState(() => _access = widget.backend.entitlements());
    }
  }

  Future<void> _connect() async {
    await _purchases.initialize();
    if (mounted) setState(() => _access = widget.backend.entitlements());
  }

  @override
  void dispose() {
    _purchases.removeListener(_changed);
    if (_ownsService) _purchases.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Покупки и восстановление')),
    body: ListenableBuilder(
      listenable: _purchases,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const IntegrationNotice(
            'Оплату проводит магазин устройства. '
            'Курс или подписка открывается только после проверки транзакции сервером. '
            'Восстановление проверяется таким же способом.',
          ),
          actionStatus,
          Text(_purchases.status),
          if (_purchases.error != null)
            Text(
              _purchases.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          OutlinedButton(
            onPressed: working ? null : () => runAction(_connect),
            child: const Text('Подключить / обновить магазин'),
          ),
          for (final product in _purchases.products)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(product.description),
                    Text(product.price),
                    FilledButton(
                      onPressed: working || _purchases.busy
                          ? null
                          : () => runAction(() => _purchases.buy(product)),
                      child: const Text('Купить'),
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton(
            onPressed: working || _purchases.busy || !_purchases.available
                ? null
                : () => runAction(_purchases.restore),
            child: const Text('Восстановить покупки'),
          ),
          if (_access != null)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _access,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Не удалось загрузить права доступа.');
                }
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                final active = snapshot.data!.where((row) {
                  if (row['expires_at'] == null) return true;
                  return DateTime.tryParse(
                        row['expires_at'].toString(),
                      )?.isAfter(DateTime.now()) ==
                      true;
                }).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Права доступа с сервера:'),
                    if (active.isEmpty)
                      const Text('Действующих прав доступа нет.'),
                    for (final row in active)
                      Text(
                        'Курс: ${row['course_id']}; '
                        '${row['expires_at'] == null ? 'без срока' : 'до ${row['expires_at']}'}',
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    ),
  );
}
