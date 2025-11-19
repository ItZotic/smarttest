import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AppTransaction {
  final String id;
  final double amount;
  final String type;
  final String category;
  final DateTime date;
  final DateTime createdAt;

  AppTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.createdAt,
  });

  bool get isExpense => type == 'expense';
  double get absoluteAmount => amount.abs();

  factory AppTransaction.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final type = (data['type'] ?? 'expense').toString().toLowerCase();
    final category = (data['category'] ?? 'Other').toString();

    DateTime resolveDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    final date = resolveDate(data['date'] ?? data['createdAt']);
    final createdAt = resolveDate(data['createdAt'] ?? date);

    return AppTransaction(
      id: doc.id,
      amount: amount,
      type: type,
      category: category,
      date: date,
      createdAt: createdAt,
    );
  }
}

class TransactionSummaryService {
  TransactionSummaryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: '₱', decimalDigits: 2);

  Stream<List<AppTransaction>> transactionsStream({
    required String uid,
    DateTime? start,
    DateTime? end,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('transactions')
        .where('uid', isEqualTo: uid);

    if (start != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    if (end != null) {
      query = query.where('date', isLessThan: Timestamp.fromDate(end));
    }

    query = query.orderBy('date', descending: true);

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => AppTransaction.fromSnapshot(doc))
              .toList(),
        );
  }

  Stream<List<AppTransaction>> transactionsForMonth({
    required String uid,
    DateTime? month,
  }) {
    final target = month ?? DateTime.now();
    final start = DateTime(target.year, target.month, 1);
    final end = DateTime(target.year, target.month + 1, 1);
    return transactionsStream(uid: uid, start: start, end: end);
  }

  double getTotalIncome(List<AppTransaction> transactions) {
    return transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.absoluteAmount);
  }

  double getTotalExpense(List<AppTransaction> transactions) {
    return transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.absoluteAmount);
  }

  double getBalance(List<AppTransaction> transactions) {
    return getTotalIncome(transactions) - getTotalExpense(transactions);
  }

  Map<String, double> expenseTotalsByCategory(List<AppTransaction> transactions) {
    final Map<String, double> totals = {};
    for (final txn in transactions.where((t) => t.isExpense)) {
      totals[txn.category] =
          (totals[txn.category] ?? 0) + txn.absoluteAmount;
    }
    return totals;
  }

  String formatCurrency(double value) => _currencyFormatter.format(value);
}
