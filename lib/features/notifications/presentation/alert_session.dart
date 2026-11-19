import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/nearby_alert_service.dart';
import '../../../services/notification_service.dart';
import '../../favorability/data/environmental_alert_service.dart';

/// Reavalia ao abrir e retomar o app, sem agendamento ou serviço pago.
class AlertSession extends StatefulWidget {
  final String userId;
  final Widget child;
  const AlertSession({super.key, required this.userId, required this.child});
  @override
  State<AlertSession> createState() => _AlertSessionState();
}

class _AlertSessionState extends State<AlertSession>
    with WidgetsBindingObserver {
  late final NearbyAlertService _nearby;
  late final EnvironmentalAlertService _environmental;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nearby = context.read<NearbyAlertService>();
    _environmental = context.read<EnvironmentalAlertService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
  }

  Future<void> _check() async {
    // Independentes: falha em FCM, clima ou ocorrências não bloqueia o outro.
    final notifications = context.read<NotificationService>();
    await notifications.prepareLocal(widget.userId);
    if (!mounted) return;
    unawaited(notifications.initialize(widget.userId));
    unawaited(_nearby.check(widget.userId));
    unawaited(_environmental.run(widget.userId));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_nearby.stop());
    _environmental.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
