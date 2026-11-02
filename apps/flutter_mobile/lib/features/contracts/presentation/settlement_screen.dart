import 'package:flutter/material.dart';

import '../data/contract_repository.dart';
import 'contract_settlement_screen.dart';

/// Compatibility entry point retained for callers of the incoming settlement UI.
/// Settlement actions and refund tracking are implemented by the canonical
/// ContractSettlementScreen.
class SettlementScreen extends StatelessWidget {
  const SettlementScreen({
    super.key,
    required this.repo,
    required this.contractId,
    this.onChanged,
  });

  final ContractRepository repo;
  final String contractId;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => ContractSettlementScreen(
    contractId: contractId,
    repository: repo,
    onChanged: onChanged,
  );
}
