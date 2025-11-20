import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:smartspend/services/transaction_summary_service.dart';
import 'package:smartspend/widgets/add_transaction.dart';

class HomeScreen extends StatefulWidget {
  final ScrollController? scrollController;
  final Function(String)? onNavigate;

  const HomeScreen({super.key, this.scrollController, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TransactionSummaryService _summaryService =
      TransactionSummaryService();
  final DateTime _currentMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  bool _isTransactionsExpanded = true;

  @override
  Widget build(BuildContext context) {
    // --- Palette ---
    final Color bgTop = const Color(0xFFE3F2FD);
    final Color bgBottom = const Color(0xFFF3F8FC);
    final Color primaryBlue = const Color(0xFF2979FF);
    final Color cardBlue1 = const Color(0xFF448AFF);
    final Color cardBlue2 = const Color(0xFF1565C0);
    final Color textDark = const Color(0xFF102027);
    final Color sheetColor = const Color(0xFF051C3F);

    if (user == null) {
      return const Center(child: Text("Please log in."));
    }

    return Scaffold(
      body: StreamBuilder<List<AppTransaction>>(
        stream: _summaryService.transactionsForMonth(
          uid: user!.uid,
          month: _currentMonth,
        ),
        builder: (context, snapshot) {
          final transactions = snapshot.data ?? [];
          final totalBalance = _summaryService.getBalance(transactions);

          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bgTop, bgBottom],
                  ),
                ),
              ),
              Positioned(
                top: -60,
                left: -60,
                child: _buildBlurCircle(primaryBlue.withValues(alpha:0.2), 300),
              ),
              Positioned(
                top: 200,
                right: -80,
                child: _buildBlurCircle(Colors.cyanAccent.withValues(alpha:0.15), 250),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16), // Better top spacing
                  // --- CUSTOM HEADER ---
                  Row(
                    children: [
                      // Menu Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 24,
                          color: textDark,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Title right beside menu
                      Text(
                        "SmartSpend",
                        style: TextStyle(
                          color: textDark,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const Spacer(),

                      // Profile Icon
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? Icon(Icons.person, color: primaryBlue)
                              : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // --- Glassy "Visa" Card ---
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        colors: [cardBlue1, cardBlue2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cardBlue2.withValues(alpha:0.4),
                          blurRadius: 25,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -30,
                          right: -30,
                          child: _buildGlassCircle(180),
                        ),
                        Positioned(
                          bottom: -50,
                          left: -20,
                          child: _buildGlassCircle(200),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(
                                    Icons.nfc,
                                    color: Colors.white70,
                                    size: 32,
                                  ),
                                  Container(
                                    width: 40,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha:0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.white38,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Total Balance",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _summaryService.formatCurrency(totalBalance),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    user?.displayName?.toUpperCase() ??
                                        "CARD HOLDER",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const Text(
                                    "12/28",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- Activities Section ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Activities",
                        style: TextStyle(
                          color: textDark,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.more_horiz, color: Colors.grey[400]),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildGlassActivityBtn(Icons.add, "Top Up", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddTransactionScreen(),
                          ),
                        );
                      }),
                      _buildGlassActivityBtn(
                        Icons.swap_horiz,
                        "Transfer",
                        () {},
                      ),
                      _buildGlassActivityBtn(
                        Icons.file_download_outlined,
                        "Withdraw",
                        () {},
                      ),
                      _buildGlassActivityBtn(
                        Icons.shopping_bag_outlined,
                        "Shop",
                        () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Transactions Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: _isTransactionsExpanded
                  ? MediaQuery.of(context).size.height * 0.55
                  : 140,
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: sheetColor.withValues(alpha:0.5),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isTransactionsExpanded = !_isTransactionsExpanded;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      child: Icon(
                        _isTransactionsExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28.0,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          "Transactions",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isTransactionsExpanded)
                    Expanded(
                      child: transactions.isEmpty
                          ? const Center(
                              child: Text(
                                "No transactions yet",
                                style: TextStyle(color: Colors.white38),
                              ),
                            )
                          : ListView.builder(
                              controller: widget.scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              itemCount: transactions.length,
                              itemBuilder: (context, index) {
                                final txn = transactions[index];
                                return _buildDarkTransactionTile(txn);
                              },
                            ),
                    )
                  else
                    const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      );
        }
    )
    );
  }
  // --- Helpers ---

  Widget _buildBlurCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildGlassCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
    );
  }

  Widget _buildGlassActivityBtn(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2979FF).withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF0D1B2A), size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF546E7A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkTransactionTile(AppTransaction transaction) {
    final bool isExpense = transaction.isExpense;
    final double amount = transaction.absoluteAmount;
    final DateTime date = transaction.date;
    final IconData icon = _iconForCategory(transaction.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d • h:mm a').format(date),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "${isExpense ? '-' : '+'}${_summaryService.formatCurrency(amount)}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
        return Icons.restaurant;
      case 'transportation':
        return Icons.directions_car;
      case 'salary':
      case 'income':
        return Icons.work;
      case 'entertainment':
        return Icons.movie;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'bills':
        return Icons.receipt_long_outlined;
      default:
        return Icons.category;
    }
  }
}
