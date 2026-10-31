import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_ui.dart';
import '../../payments/data/models/payment.dart';
import '../../payments/data/repositories/payment_repository.dart';
import '../data/contract_repository.dart';
import 'contract_detail_screen.dart';

class ContractDetailRouteScreen extends StatefulWidget {
  const ContractDetailRouteScreen({
    super.key,
    required this.contractId,
    required this.dio,
    this.onContractChanged,
  });
  final String contractId;
  final Dio dio;
  final VoidCallback? onContractChanged;

  @override
  State<ContractDetailRouteScreen> createState() =>
      _ContractDetailRouteScreenState();
}

class _ContractDetailRouteScreenState extends State<ContractDetailRouteScreen> {
  late final ContractRepository _contracts = ContractRepository(widget.dio);
  late final PaymentRepository _payments = PaymentRepository(widget.dio);
  late Future<Map<String, dynamic>> _contract;

  @override
  void initState() {
    super.initState();
    _contract = _contracts.detail(widget.contractId);
  }

  void _retry() =>
      setState(() => _contract = _contracts.detail(widget.contractId));

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _contract,
    builder: (context, state) {
      if (state.connectionState == ConnectionState.waiting) {
        return Scaffold(
          appBar: AppBar(title: const Text('Chi tiết hợp đồng')),
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (state.hasError || state.data == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Chi tiết hợp đồng')),
          body: AppErrorState(
            message: 'Không thể tải hợp đồng. Hãy kiểm tra quyền truy cập và thử lại.',
            onRetry: _retry,
          ),
        );
      }
      return ContractDetailScreen(
        contract: state.data!,
        repository: _contracts,
        paymentRepository: _payments,
        onViewPayment: (Payment payment) async {
          await context.push(
            '/payments/${Uri.encodeComponent(payment.id)}/view?contractId=${Uri.encodeComponent(widget.contractId)}',
          );
        },
      );
    },
  );
}
