import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:smartspend/services/firestore_service.dart';
import 'package:smartspend/services/theme_service.dart';

class AddTransactionScreen extends StatefulWidget {
  // Optional parameters for Edit Mode
  final String? transactionId;
  final Map<String, dynamic>? transactionData;

  const AddTransactionScreen({
    super.key,
    this.transactionId,
    this.transactionData,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TextEditingController _descController = TextEditingController();

  String? _selectedAccountName;
  String? _selectedCategoryName;
  String? _selectedCategoryId;
  bool _isExpense = true;
  DateTime _selectedDate = DateTime.now();
  String _amountText = '';
  bool _isSaving = false;
  bool _isDeleting = false;

  final FirestoreService _firestoreService = FirestoreService();
  final ThemeService _themeService = ThemeService();
  final user = FirebaseAuth.instance.currentUser;

  // Helper to check if we are editing
  bool get isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill data if editing
    if (isEditing && widget.transactionData != null) {
      final data = widget.transactionData!;
      _selectedCategoryName = data['category'] ?? 'Uncategorized';
      _selectedCategoryId = data['categoryId'];
      _selectedAccountName = data['accountName'] ?? data['account'];
      _isExpense = (data['type'] ?? 'expense').toString() != 'income';

      if (data['date'] != null && data['date'] is Timestamp) {
        _selectedDate = (data['date'] as Timestamp).toDate();
      }

      _descController.text = data['name'] ?? '';

      // Handle amount (convert to string without negative sign for display)
      double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      _amountText = amount.abs().toString();

      // Remove decimal if it's .0
      if (_amountText.endsWith('.0')) {
        _amountText = _amountText.substring(0, _amountText.length - 2);
      }
    }
  }

  String get _displayAmount {
    if (_amountText.isEmpty) return '0';
    return _amountText;
  }

  String get _typeString => _isExpense ? 'expense' : 'income';

  void _onKeyTap(String value) {
    setState(() {
      if (value == 'back') {
        if (_amountText.isNotEmpty) {
          _amountText = _amountText.substring(0, _amountText.length - 1);
        }
      } else if (value == '.') {
        if (!_amountText.contains('.')) {
          _amountText += value;
        }
      } else {
        if (_amountText.length < 10) {
          _amountText += value;
        }
      }
    });
  }

  Map<String, dynamic>? _buildTransactionData({
    required bool preserveCreatedAt,
  }) {
    if (user == null) return null;

    if (_amountText.isEmpty || double.tryParse(_amountText) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return null;
    }

    if (_selectedAccountName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose an account')),
      );
      return null;
    }

    if (_selectedCategoryName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a category')),
      );
      return null;
    }

    if (_descController.text.isEmpty) {
      _descController.text = _selectedCategoryName ?? 'Transaction';
    }

    final double amount = double.parse(_amountText);
    final double finalAmount = _isExpense ? -amount : amount;
    final selectedCategoryName = _selectedCategoryName ?? 'Uncategorized';
    final selectedAccountName = _selectedAccountName ?? 'ACCOUNT';

    // ✅ Clean, explicit handling of createdAt (no nested ?: / ??)
    dynamic createdAtValue;
    if (preserveCreatedAt &&
        widget.transactionData != null &&
        widget.transactionData!['createdAt'] != null) {
      createdAtValue = widget.transactionData!['createdAt'];
    } else {
      createdAtValue = FieldValue.serverTimestamp();
    }

    return {
      'userId': user!.uid,
      'uid': user!.uid,
      'amount': finalAmount,
      'type': _typeString,
      'category': selectedCategoryName,
      'categoryId': _selectedCategoryId,
      'accountName': selectedAccountName,
      'account': selectedAccountName,
      'name': _descController.text.trim(),
      'date': Timestamp.fromDate(_selectedDate),
      'createdAt': createdAtValue,
    };
  }

  Future<void> _saveTransaction() async {
    setState(() => _isSaving = true);

    try {
      final data = _buildTransactionData(preserveCreatedAt: false);
      if (data == null) return;

      await FirebaseFirestore.instance.collection('transactions').add(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateTransaction() async {
    if (!isEditing) return;
    setState(() => _isSaving = true);

    try {
      final data = _buildTransactionData(preserveCreatedAt: true);
      if (data == null) return;

      await _firestoreService.updateTransaction(
        uid: user!.uid,
        transactionId: widget.transactionId!,
        data: data,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTransaction() async {
    if (!isEditing) return;

    setState(() => _isDeleting = true);

    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.transactionId)
          .delete();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error deleting: $e')));
        setState(() => _isDeleting = false);
      }
    }
  }

  // ---------------- Selection sheets ----------------

  void _showAccountSheet() {
    if (user == null) return;

    final textColor = _themeService.textMain;
    final sheetBg =
        _themeService.isDarkMode ? _themeService.cardBg : Colors.white;
    final borderColor = _themeService.primaryBlue.withValues(alpha: 0.2);
    final dividerColor = _themeService.textSub.withValues(alpha: 0.15);
    final handleColor = _themeService.textSub.withValues(alpha: 0.5);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: sheetBg,
                  border: Border.all(color: borderColor),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Select Account",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: _firestoreService.streamAccounts(uid: user!.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: _themeService.primaryBlue,
                              ),
                            );
                          }

                          final accounts = snapshot.data?.docs ?? [];

                          if (accounts.isEmpty) {
                            return Center(
                              child: Text(
                                "No accounts found",
                                style: TextStyle(color: _themeService.textSub),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: accounts.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: dividerColor,
                            ),
                            itemBuilder: (context, index) {
                              final account = accounts[index];
                              final data = account.data();
                              final accountName =
                                  (data['name'] ?? 'Unnamed').toString();
                              final accountType = (data['type'] ?? '').toString();

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _themeService.primaryBlue.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet,
                                    color: _themeService.primaryBlue,
                                  ),
                                ),
                                title: Text(
                                  accountName,
                                  style: TextStyle(color: textColor),
                                ),
                                subtitle: accountType.isEmpty
                                    ? null
                                    : Text(
                                        accountType,
                                        style:
                                            TextStyle(color: _themeService.textSub),
                                      ),
                                onTap: () {
                                  setState(() {
                                    _selectedAccountName = accountName;
                                  });
                                  Navigator.pop(context);
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
          ),
        );
      },
    );
  }

  void _showCategorySheet() {
    if (user == null) return;

    final textColor = _themeService.textMain;
    final sheetBg = _themeService.isDarkMode ? _themeService.cardBg : Colors.white;
    final borderColor = _themeService.primaryBlue.withValues(alpha: 0.2);
    final dividerColor = _themeService.textSub.withValues(alpha: 0.15);
    final handleColor = _themeService.textSub.withValues(alpha: 0.5);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: sheetBg,
                  border: Border.all(color: borderColor),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Select Category",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: _firestoreService.streamCategoriesByType(
                          uid: user!.uid,
                          type: _typeString,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: _themeService.primaryBlue,
                              ),
                            );
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Text(
                                _typeString == 'income'
                                    ? 'No income categories yet'
                                    : 'No expense categories yet',
                                style: TextStyle(color: _themeService.textSub),
                              ),
                            );
                          }

                          final docs = snapshot.data!.docs;

                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: dividerColor,
                            ),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data();
                              final categoryName =
                                  (data['name'] as String?) ?? 'Unnamed';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _themeService.primaryBlue
                                      .withValues(alpha: 0.1),
                                  child: Icon(
                                    Icons.category_rounded,
                                    color: _themeService.primaryBlue,
                                  ),
                                ),
                                title: Text(
                                  categoryName,
                                  style: TextStyle(color: textColor),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryName = categoryName;
                                    _selectedCategoryId = doc.id;
                                  });
                                  Navigator.pop(context);
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
          ),
        );
      },
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeService,
      builder: (context, _) {
        final Color bgTop = _themeService.bgTop;
        final Color bgBottom = _themeService.bgBottom;
        final Color primaryBlue = _themeService.primaryBlue;
        final Color textDark = _themeService.textMain;
        final Color textSub = _themeService.textSub;
        final Color cardBg = _themeService.cardBg;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgTop, bgBottom],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // --- Header ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "CANCEL",
                            style: TextStyle(
                              color: textSub,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          isEditing ? "Edit Transaction" : "Add Transaction",
                          style: TextStyle(
                            color: textDark,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _isSaving || _isDeleting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryBlue,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isEditing)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: _deleteTransaction,
                                    ),
                                  TextButton(
                                    onPressed: isEditing
                                        ? _updateTransaction
                                        : _saveTransaction,
                                    child: Text(
                                      "SAVE",
                                      style: TextStyle(
                                        color: primaryBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),

                  // --- Scrollable Content ---
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // --- Type Toggle ---
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildTypeButton("Expense", _isExpense),
                                const SizedBox(width: 20),
                                _buildTypeButton("Income", !_isExpense),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // --- Selectors ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildSelector(
                                    icon: Icons.account_balance_wallet,
                                    label: _selectedAccountName ?? 'ACCOUNT',
                                    onTap: _showAccountSheet,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSelector(
                                    icon: Icons.category,
                                    label:
                                        _selectedCategoryName ?? 'CATEGORY',
                                    onTap: _showCategorySheet,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // --- Note Input ---
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: TextField(
                              controller: _descController,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: "Add a note...",
                                hintStyle: TextStyle(color: textSub),
                                border: InputBorder.none,
                              ),
                              style:
                                  TextStyle(color: textDark, fontSize: 16),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // --- Amount Display ---
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment:
                                  CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _displayAmount,
                                  style: TextStyle(
                                    color: textDark,
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _onKeyTap('back'),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: _themeService
                                                    .isDarkMode
                                                ? 0.25
                                                : 0.05,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.backspace_outlined,
                                      size: 20,
                                      color: textSub,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // --- Big update button in edit mode ---
                          if (isEditing)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0),
                              child: SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _updateTransaction,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    "UPDATE TRANSACTION",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // --- Keypad (Fixed at Bottom) ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _buildKey("7"),
                            _buildKey("8"),
                            _buildKey("9"),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _buildKey("4"),
                            _buildKey("5"),
                            _buildKey("6"),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _buildKey("1"),
                            _buildKey("2"),
                            _buildKey("3"),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _buildKey("."),
                            _buildKey("0"),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(
                                        () => _selectedDate = picked);
                                  }
                                },
                                child: Container(
                                  height: 60,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: _themeService
                                                  .isDarkMode
                                              ? 0.2
                                              : 0.05,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      DateFormat('MMM dd')
                                          .format(_selectedDate),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textDark,
                                      ),
                                    ),
                                  ),
                                ),
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
          ),
        );
      },
    );
  }

  Widget _buildTypeButton(String label, bool isSelected) {
    final Color primaryBlue = _themeService.primaryBlue;
    final Color textSub = _themeService.textSub;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpense = label.toUpperCase() != 'INCOME';
        });
      },
      child: Row(
        children: [
          if (isSelected)
            Icon(Icons.check_circle, size: 18, color: primaryBlue),
          if (isSelected) const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? primaryBlue : textSub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelector({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final Color primaryBlue = _themeService.primaryBlue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: _themeService.cardBg,
          border: Border.all(
            color: primaryBlue.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: _themeService.isDarkMode ? 0.2 : 0.05,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _themeService.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String value) {
    final Color textColor = _themeService.textMain;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onKeyTap(value),
        child: Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: _themeService.cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: _themeService.isDarkMode ? 0.2 : 0.05,
                ),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
