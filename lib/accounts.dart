import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartspend/services/firestore_service.dart';
import 'package:smartspend/services/theme_service.dart';

class AccountsScreen extends StatefulWidget {
  final ScrollController? scrollController;

  const AccountsScreen({super.key, this.scrollController});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final ThemeService _themeService = ThemeService();
  final FirestoreService _firestoreService = FirestoreService();
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeService,
      builder: (context, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            backgroundColor: _themeService.primaryBlue,
            onPressed: _showAddAccountDialog,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_themeService.bgTop, _themeService.bgBottom],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Accounts",
                          style: TextStyle(
                            color: _themeService.textMain,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestoreService.streamAccounts(uid: user!.uid),
                      builder: (context, accountSnapshot) {
                        if (accountSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final accountDocs = accountSnapshot.data?.docs ?? [];

                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: _firestoreService.streamTransactions(
                            uid: user!.uid,
                          ),
                          builder: (context, txSnapshot) {
                            if (txSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final txDocs = txSnapshot.data?.docs ?? [];

                            if (accountDocs.isEmpty && txDocs.isEmpty) {
                              return Center(
                                child: Text(
                                  "No accounts added yet",
                                  style:
                                      TextStyle(color: _themeService.textSub),
                                ),
                              );
                            }

                            final Map<String, _AccountInfo> accountBalances = {};

                            for (final doc in accountDocs) {
                              final data = doc.data();
                              final name = (data['name'] ?? 'Unnamed').toString();
                              final type = (data['type'] ?? '').toString();
                              final docBalance =
                                  (data['balance'] as num?)?.toDouble() ?? 0.0;

                              accountBalances[name] = _AccountInfo(
                                balance: 0,
                                docId: doc.id,
                                type: type,
                                docBalance: docBalance,
                              );
                            }

                            double totalBalance = 0;

                            for (final doc in txDocs) {
                              final data = doc.data();
                              final double amount =
                                  ((data['amount'] as num?)?.toDouble() ?? 0.0)
                                      .abs();
                              final String type =
                                  (data['type'] ?? '').toString().toLowerCase();
                              final String accountName =
                                  (data['accountName'] ?? data['account'] ??
                                          'Unassigned')
                                      .toString();

                              final signedAmount =
                                  type == 'expense' ? -amount : amount;
                              totalBalance += signedAmount;

                              accountBalances.update(
                                accountName,
                                (value) => value.copyWith(
                                  balance: value.balance + signedAmount,
                                  hasTransactions: true,
                                ),
                                ifAbsent: () => _AccountInfo(
                                  balance: signedAmount,
                                  docId: null,
                                  type: accountName,
                                  hasTransactions: true,
                                ),
                              );
                            }

                            // If an account has no transactions, fall back to its stored balance
                            accountBalances.updateAll((key, value) {
                              if (!value.hasTransactions && value.docBalance != 0) {
                                totalBalance += value.docBalance;
                                return value.copyWith(balance: value.docBalance);
                              }
                              return value;
                            });

                            final accountEntries = accountBalances.entries.toList()
                              ..sort((a, b) => a.key.compareTo(b.key));

                            final rows = [
                              _AccountRow(
                                name: 'All Accounts',
                                balance: totalBalance,
                                icon: Icons.account_balance_wallet,
                                enableDeletion: false,
                              ),
                              ...accountEntries.map(
                                (entry) => _AccountRow(
                                  name: entry.key,
                                  balance: entry.value.balance,
                                  docId: entry.value.docId,
                                  icon: _getIconForAccount(entry.value.type),
                                ),
                              ),
                            ];

                            return ListView.separated(
                              controller: widget.scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: rows.length,
                              separatorBuilder: (context, index) => const SizedBox(
                                height: 12,
                              ),
                              itemBuilder: (context, index) {
                                final row = rows[index];

                                return _buildAccountCard(
                                  row.name,
                                  row.balance,
                                  row.icon,
                                  docId: row.docId,
                                  enableDeletion: row.enableDeletion,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForAccount(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('cash')) {
      return Icons.money;
    }
    if (t.contains('bank')) {
      return Icons.account_balance;
    }
    if (t.contains('credit')) {
      return Icons.credit_card;
    }
    if (t.contains('debit')) {
      return Icons.credit_card;
    }
    if (t.contains('wallet') || t.contains('e-wallet')) {
      return Icons.account_balance_wallet;
    }
    return Icons.account_box;
  }

  Widget _buildAccountCard(
    String name,
    double balance,
    IconData icon,
    {String? docId,
    bool enableDeletion = true}
  )
   {
    return GestureDetector(
      onLongPress: enableDeletion && docId != null
          ? () => _showDeleteDialog(docId, name)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _themeService.cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(_themeService.isDarkMode ? 0.3 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _themeService.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _themeService.primaryBlue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: _themeService.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Current Balance",
                    style: TextStyle(
                      color: _themeService.textSub,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _themeService.formatCurrency(balance),
              style: TextStyle(
                color: _themeService.textMain,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountDialog() {
    final nameCtrl = TextEditingController(text: "Cash");
    final amountCtrl = TextEditingController();
    String selectedType = "Cash";

    final List<String> accountTypes = [
      "Cash",
      "Bank",
      "Credit Card",
      "Debit Card",
      "E-Wallet",
      "Savings",
      "Custom",
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _themeService.sheetColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add Account",
                style: TextStyle(
                  color: _themeService.textMain,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Account Type",
                style: TextStyle(color: _themeService.textSub, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _themeService.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _themeService.primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedType,
                    dropdownColor: _themeService.cardBg,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: _themeService.primaryBlue,
                    ),
                    items: accountTypes
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s,
                              style: TextStyle(color: _themeService.textMain),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedType = val!;
                        if (val != "Custom") {
                          nameCtrl.text = val;
                        } else {
                          nameCtrl.clear();
                        }
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "Account Name",
                style: TextStyle(color: _themeService.textSub, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: _themeService.textMain),
                decoration: InputDecoration(
                  hintText: "e.g. My Savings",
                  hintStyle: TextStyle(color: _themeService.textSub),
                  filled: true,
                  fillColor: _themeService.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "Initial Balance",
                style: TextStyle(color: _themeService.textSub, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _themeService.textMain),
                decoration: InputDecoration(
                  hintText: "0.00",
                  hintStyle: TextStyle(color: _themeService.textSub),
                  filled: true,
                  fillColor: _themeService.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _themeService.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.isNotEmpty &&
                        amountCtrl.text.isNotEmpty &&
                        user != null) {
                      try {
                        final double initialBalance =
                            double.tryParse(amountCtrl.text) ?? 0.0;
                        final String accountName = nameCtrl.text;

                        // 1. Create Account Doc
                        await FirebaseFirestore.instance
                            .collection('accounts')
                            .add({
                              'uid': user!.uid,
                              'name': accountName,
                              'type': selectedType,
                              'balance': initialBalance,
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                        // 2. ✅ AUTOMATICALLY ADD INITIAL TRANSACTION
                        // This makes it show up on the Home Screen balance immediately!
                        if (initialBalance != 0) {
                          await FirebaseFirestore.instance
                              .collection('transactions')
                              .add({
                                'uid': user!.uid,
                                'userId': user!.uid, // For compatibility
                                'amount': initialBalance, // Positive for Income
                                'type': 'income',
                                'category': 'Initial Balance',
                                'account': accountName, // Link to this account
                                'accountName': accountName,
                                'name': 'Opening Balance',
                                'date': FieldValue.serverTimestamp(),
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                        }

                        if (!mounted) {
                          return;
                        }

                        Navigator.pop(context);
                      } catch (e) {
                        debugPrint("Error adding account: $e");
                      }
                    }
                  },
                  child: const Text(
                    "SAVE ACCOUNT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _themeService.cardBg,
        title: Text(
          "Delete Account",
          style: TextStyle(color: _themeService.textMain),
        ),
        content: Text(
          "Delete $name? Note: This won't delete associated transactions.",
          style: TextStyle(color: _themeService.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('accounts')
                  .doc(docId)
                  .delete();
              if (!mounted) {
                return;
              }

              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AccountInfo {
  final double balance;
  final String? docId;
  final String type;
  final bool hasTransactions;
  final double docBalance;

  const _AccountInfo({
    required this.balance,
    this.docId,
    required this.type,
    this.hasTransactions = false,
    this.docBalance = 0,
  });

  _AccountInfo copyWith({
    double? balance,
    String? docId,
    String? type,
    bool? hasTransactions,
    double? docBalance,
  }) {
    return _AccountInfo(
      balance: balance ?? this.balance,
      docId: docId ?? this.docId,
      type: type ?? this.type,
      hasTransactions: hasTransactions ?? this.hasTransactions,
      docBalance: docBalance ?? this.docBalance,
    );
  }
}

class _AccountRow {
  final String name;
  final double balance;
  final IconData icon;
  final String? docId;
  final bool enableDeletion;

  const _AccountRow({
    required this.name,
    required this.balance,
    required this.icon,
    this.docId,
    this.enableDeletion = true,
  });
}
