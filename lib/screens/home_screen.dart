import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// ❗️ UPDATE THIS IMPORT to match your project
import 'package:smartspend/services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  final ScrollController? scrollController;
  // If you use a navigation callback, keep it here
  final Function(String)? onNavigate;

  const HomeScreen({super.key, this.scrollController, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    // Colors from your new palette
    final Color bgTop = const Color(0xFFEAF2F8);
    final Color bgBottom = const Color(0xFFF5F8FA);
    final Color primaryBlue = const Color(0xFF2D79F6);
    final Color textDark = const Color(0xFF1A1E26);

    if (user == null) {
      return const Center(child: Text("Please log in."));
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.streamTransactions(uid: user!.uid),
          builder: (context, snapshot) {
            // 1. Calculate Totals
            double totalIncome = 0;
            double totalExpense = 0;
            final transactions = snapshot.data?.docs ?? [];

            for (var doc in transactions) {
              final data = doc.data() as Map<String, dynamic>;
              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final type = data['type'] as String? ?? 'expense';

              if (type.toLowerCase() == 'income') {
                totalIncome += amount.abs();
              } else {
                totalExpense += amount.abs();
              }
            }
            final totalBalance = totalIncome - totalExpense;

            return ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(
                20,
                60,
                20,
                20,
              ), // Top padding for status bar
              children: [
                // --- Header ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome back,",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.displayName ?? "User",
                          style: TextStyle(
                            color: textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 22,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Icon(Icons.person, color: primaryBlue)
                          : null,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // --- Main Balance Card ---
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D79F6), Color(0xFF5CA0F8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D79F6).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Balance",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "₱${totalBalance.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBalanceRow(
                            Icons.arrow_downward,
                            "Income",
                            "₱${totalIncome.toStringAsFixed(0)}",
                          ),
                          _buildBalanceRow(
                            Icons.arrow_upward,
                            "Expense",
                            "₱${totalExpense.toStringAsFixed(0)}",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- Recent Transactions Header ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Recent Transactions",
                      style: TextStyle(
                        color: textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        /* Navigate to full list */
                      },
                      child: const Text("See All"),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // --- Transaction List ---
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (transactions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        "No transactions yet.\nAdd one!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  )
                else
                  ...transactions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildTransactionTile(data);
                  }),

                // Extra space at bottom so FAB doesn't cover content
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBalanceRow(IconData icon, String label, String amount) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> data) {
    final bool isExpense =
        (data['type'] ?? 'expense').toString().toLowerCase() == 'expense';
    final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final DateTime date =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Icon logic (you can expand this map or use your helper function)
    IconData icon = Icons.category;
    if (data['category'] == 'Food & Dining'){
      icon = Icons.restaurant; }
    else if (data['category'] == 'Transportation') {
      icon = Icons.directions_car; }
    else if (data['category'] == 'Salary') {
      icon = Icons.work; }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF2D79F6)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['category'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1A1E26),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, h:mm a').format(date),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            "${isExpense ? '-' : '+'}₱${amount.abs().toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isExpense ? Colors.redAccent : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
