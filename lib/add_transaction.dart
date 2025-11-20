import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// ❗️ UPDATE THIS IMPORT to match your project name in pubspec.yaml
import 'package:smartspend/services/firestore_service.dart';
import 'package:smartspend/ui/category_icons.dart';
import 'package:smartspend/ui/smart_spend_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TextEditingController _descController = TextEditingController();

  // State variables
  String _categoryName = 'Food & Dining';
  // ignore: unused_field
  String _categoryId = '';
  // ignore: unused_field
  String _categoryIcon = 'restaurant';

  String _account = 'Cash';
  String _type = 'Expense';
  DateTime _selectedDate = DateTime.now();
  String _amountText = '';
  bool _isSaving = false;

  final FirestoreService _firestoreService = FirestoreService();
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _firestoreService.ensureDefaultCategories(uid: user!.uid);
    }
  }

  String get _displayAmount {
    if (_amountText.isEmpty) {
      return '0';
    }
    return _amountText;
  }

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

  Future<void> _saveTransaction() async {
    if (user == null) {
      return;
    }

    if (_amountText.isEmpty || double.tryParse(_amountText) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (_descController.text.isEmpty) {
      _descController.text = _categoryName;
    }

    setState(() => _isSaving = true);

    try {
      final double amount = double.parse(_amountText);
      final double finalAmount = _type == 'Expense' ? -amount : amount;

      await FirebaseFirestore.instance.collection('transactions').add({
        'userId': user!.uid,
        'uid': user!.uid,
        'amount': finalAmount,
        'type': _type.toLowerCase(),
        'category': _categoryName,
        'account': _account,
        'name': _descController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction saved!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSelectionSheet({
    required String title,
    required List<String> items,
    required Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF051C3F), // Dark Navy
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        items[index],
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        onSelect(items[index]);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCategorySheet() {
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        return Container(
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Select Category',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: mediaQuery.size.height * 0.5,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestoreService.streamUserCategories(
                      uid: user!.uid,
                      type: _type.toLowerCase(),
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No categories found.'),
                        );
                      }
                      return GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 3.4,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final iconString =
                              (data['icon'] ?? 'category').toString();
                          final iconData =
                              categoryIconMap[iconString] ?? Icons.category;
                          final colorValue =
                              (data['color'] as int?) ?? primaryBlue.value;
                          final color = Color(colorValue);
                          final name = (data['name'] ?? 'Unnamed').toString();

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _categoryName = name;
                                _categoryId = docs[index].id;
                                _categoryIcon = iconString;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: color.withValues(alpha:0.12),
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: color.withValues(alpha:0.2)),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    height: 34,
                                    width: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      iconData,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color bgTop = const Color(0xFFE3F2FD);
    final Color bgBottom = const Color(0xFFF3F8FC);
    final Color primaryBlue = const Color(0xFF2979FF);
    final Color textDark = const Color(0xFF102027);

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
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      "Add Transaction",
                      style: TextStyle(
                        color: textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: _saveTransaction,
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
                            _buildTypeButton("Expense", _type == 'Expense'),
                            const SizedBox(width: 20),
                            _buildTypeButton("Income", _type == 'Income'),
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
                                label: _account,
                                onTap: () => _showSelectionSheet(
                                  title: "Select Account",
                                  items: ["Cash", "Bank", "Savings", "Card"],
                                  onSelect: (val) =>
                                      setState(() => _account = val),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSelector(
                                icon: Icons.category,
                                label: _categoryName,
                                onTap: _showCategorySheet,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- Note Input ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: _descController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: "Add a note...",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                          ),
                          style: TextStyle(color: textDark, fontSize: 16),
                        ),
                      ),

                      // Spacing to push amount down visually
                      const SizedBox(height: 20),

                      // --- Amount Display ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
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
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.backspace_outlined,
                                  size: 20,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
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
                  color: const Color(0xFFE8ECEF),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min, // Important for column in layout
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildKey("7"),
                        _buildKey("8"),
                        _buildKey("9"),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildKey("4"),
                        _buildKey("5"),
                        _buildKey("6"),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildKey("1"),
                        _buildKey("2"),
                        _buildKey("3"),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                setState(() => _selectedDate = picked); }
                            },
                            child: Container(
                              height: 60,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  DateFormat('MMM dd').format(_selectedDate),
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
  }

  Widget _buildTypeButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = label.toUpperCase() == 'INCOME' ? 'Income' : 'Expense';
        });
      },
      child: Row(
        children: [
          if (isSelected)
            Icon(Icons.check_circle, size: 18, color: const Color(0xFF2D79F6)),
          if (isSelected) const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF2D79F6) : Colors.grey,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF2D79F6).withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2D79F6)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
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
    return Expanded(
      child: GestureDetector(
        onTap: () => _onKeyTap(value),
        child: Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1E26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
