class WalletTxn {
  const WalletTxn({
    required this.txnId,
    required this.amount,
    required this.amountFormatted,
    required this.type,
    required this.createdAt,
    this.note,
  });

  final int txnId;
  final int amount;
  final String amountFormatted;
  final String type;
  final String? note;
  final DateTime createdAt;

  bool get isCredit => amount >= 0;

  String get typeLabel {
    switch (type) {
      case 'CREDIT_SALE':
        return 'Tiền bán hàng';
      case 'DEBIT_WITHDRAW':
        return 'Rút tiền';
      case 'REFUND_WITHDRAW':
        return 'Hoàn rút tiền';
      default:
        return type;
    }
  }

  factory WalletTxn.fromJson(Map<String, dynamic> json) => WalletTxn(
        txnId: (json['txnId'] as num).toInt(),
        amount: (json['amount'] as num).toInt(),
        amountFormatted: json['amountFormatted'] as String? ?? '',
        type: json['type'] as String? ?? '',
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class WalletInfo {
  const WalletInfo({
    required this.balance,
    required this.balanceFormatted,
    required this.transactions,
  });

  final int balance;
  final String balanceFormatted;
  final List<WalletTxn> transactions;

  factory WalletInfo.fromJson(Map<String, dynamic> json) => WalletInfo(
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        balanceFormatted: json['balanceFormatted'] as String? ?? '0đ',
        transactions: (json['transactions'] as List<dynamic>? ?? [])
            .map((e) => WalletTxn.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WithdrawalItem {
  const WithdrawalItem({
    required this.withdrawalId,
    required this.amount,
    required this.amountFormatted,
    required this.bankName,
    required this.bankAccount,
    required this.accountHolder,
    required this.status,
    required this.createdAt,
  });

  final int withdrawalId;
  final int amount;
  final String amountFormatted;
  final String bankName;
  final String bankAccount;
  final String accountHolder;
  final String status;
  final DateTime createdAt;

  String get statusLabel {
    switch (status) {
      case 'Completed':
        return 'Đã chuyển';
      case 'Pending':
        return 'Đang xử lý';
      case 'Rejected':
        return 'Bị từ chối';
      default:
        return status;
    }
  }

  factory WithdrawalItem.fromJson(Map<String, dynamic> json) => WithdrawalItem(
        withdrawalId: (json['withdrawalId'] as num).toInt(),
        amount: (json['amount'] as num).toInt(),
        amountFormatted: json['amountFormatted'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        bankAccount: json['bankAccount'] as String? ?? '',
        accountHolder: json['accountHolder'] as String? ?? '',
        status: json['status'] as String? ?? 'Pending',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
