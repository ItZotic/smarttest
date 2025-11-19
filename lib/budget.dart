import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for text input formatter
import 'package:intl/intl.dart';
import 'package:smartspend/services/transaction_summary_service.dart';
import 'package:smartspend/ui/category_icons.dart';
import 'package:smartspend/ui/smart_spend_theme.dart';
// ❗️ UPDATE THIS IMPORT to match your project
import 'package:smartspend/services/firestore_service.dart';

class BudgetScreen extends StatefulWidget {
  final ScrollController? scrollController;

  const BudgetScreen({super.key, this.scrollController});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();
  final TransactionSummaryService _summaryService =
      TransactionSummaryService(firestore: FirebaseFirestore.instance);

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  String get _formattedMonthYear => DateFormat('MMMM, yyyy').format(_selectedMonth);

  Stream<List<AppTransaction>> _transactionsForSelectedMonth() {
    return _summaryService.transactionsForMonth(
      uid: user!.uid,
      month: _selectedMonth,
    );
  }

  Stream<double> _budgetTotalStream() {
    final monthKey =
        "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
    return FirebaseFirestore.instance
        .collection('budgets')
        .where('uid', isEqualTo: user!.uid)
        .where('month', isEqualTo: monthKey)
        .snapshots()
        .map((snapshot) => snapshot.docs.fold<double>(
              0,
              (sum, doc) =>
                  sum + ((doc.data()['limit'] as num?)?.toDouble() ?? 0.0),
            ));
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _firestoreService.ensureDefaultCategories(uid: user!.uid);
    }
  }

  void _onAddBudgetPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap on a category to set its monthly budget.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: Text("Please log in to view your budget."));
    }

    return Scaffold(
      backgroundColor: lightBgBottom,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Budget',
          style: TextStyle(
            color: navy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppTransaction>>(
          stream: _transactionsForSelectedMonth(),
          builder: (context, snapshot) {
            final transactions = snapshot.data ?? [];
            final totalSpentString = _summaryService.formatCurrency(
              _summaryService.getTotalExpense(transactions),
            );

            return Column(
              children: [
                SmartSpendCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _goToPreviousMonth,
                        icon:
                            const Icon(Icons.chevron_left_rounded, color: navy),
                      ),
                      Column(
                        children: [
                          Text(
                            _formattedMonthYear,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Monthly budget overview',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _goToNextMonth,
                        icon: const Icon(
                            Icons.chevron_right_rounded, color: navy),
                      ),
                    ],
                  ),
                ),
                SmartSpendCard(
                  margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<double>(
                          stream: _budgetTotalStream(),
                          builder: (context, budgetSnapshot) {
                            final totalBudgetString =
                                _summaryService.formatCurrency(
                                    budgetSnapshot.data ?? 0);
                            return _BudgetStatCard(
                              label: 'Total Budget',
                              amount: totalBudgetString,
                              chipColor: primaryBlue.withOpacity(0.15),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BudgetStatCard(
                          label: 'Total Spent',
                          amount: totalSpentString,
                          chipColor: Colors.red.withOpacity(0.10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(child: _buildCategoryList()),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        onPressed: _onAddBudgetPressed,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildCategoryList() {
    return SmartSpendCard(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense Categories',
            style: TextStyle(
              color: navy,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.streamUserCategories(
                uid: user!.uid,
                type: 'expense',
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No expense categories found.',
                      style: TextStyle(color: Colors.black45, fontSize: 13),
                    ),
                  );
                }

                final categoryDocs = snapshot.data!.docs;
                return ListView.builder(
                  controller: widget.scrollController,
                  itemCount: categoryDocs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _buildCategoryRow(categoryDocs[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔽 --- THIS WIDGET IS NOW FIXED --- 🔽
  Widget _buildCategoryRow(DocumentSnapshot categoryDoc) {
    final categoryData = categoryDoc.data() as Map<String, dynamic>;
    final categoryName = categoryData['name'] ?? 'Unnamed';
    final categoryId = categoryDoc.id;

    // --- ❗️ UPDATED LOGIC ---
    // Read the 'icon' string from the document
    final iconString = categoryData['icon'] ?? 'category';
    // Look up the IconData from our map
    final iconData = categoryIconMap[iconString] ?? Icons.category;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: lightBgTop,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primaryBlue.withOpacity(0.15),
            child: Icon(iconData, color: primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tap to assign a limit',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: navy,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              _showSetBudgetDialog(
                categoryId,
                categoryName,
                iconData,
              );
            },
            child: const Text(
              'Set Budget',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showSetBudgetDialog(
    String categoryId,
    String categoryName,
    IconData iconData,
  ) {
    final TextEditingController limitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Set budget',
            style: TextStyle(
              color: navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primaryBlue.withOpacity(0.15),
                    child: Icon(
                      iconData,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      categoryName,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: limitController,
                decoration: InputDecoration(
                  labelText: 'Limit',
                  prefixText: '₱',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Month: $_formattedMonthYear',
                style: const TextStyle(color: Colors.black45),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final limit = double.tryParse(limitController.text);
                if (limit == null || limit <= 0) {
                  return;
                }

                try {
                  await _firestoreService.setBudget(
                    uid: user!.uid,
                    categoryId: categoryId,
                    categoryName: categoryName,
                    limit: limit,
                    month: _selectedMonth,
                  );
                  Navigator.of(context).pop();
                } catch (e) {
                  debugPrint("Failed to set budget: $e");
                }
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  // --- 🗑 REMOVED ---
  // The old _getIcon function is no longer needed.
}

class _BudgetStatCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color chipColor;

  const _BudgetStatCard({
    required this.label,
    required this.amount,
    required this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
        ],
      ),
    );
  }
}
