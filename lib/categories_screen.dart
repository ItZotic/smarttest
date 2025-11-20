import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartspend/services/firestore_service.dart';
import 'package:smartspend/ui/category_icons.dart';
import 'package:smartspend/ui/smart_spend_theme.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _seedDefaults();
  }

  Future<void> _seedDefaults() async {
    if (user == null) {
      return;
    }
    await _firestoreService.ensureDefaultCategories(uid: user!.uid);
  }

  void _showAddCategoryDialog() {
    final TextEditingController nameController = TextEditingController();
    String selectedType = 'expense';
    String selectedIconString = 'category';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Add new category',
                style: TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Type',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ToggleButtons(
                      isSelected: [
                        selectedType == 'income',
                        selectedType == 'expense',
                      ],
                      onPressed: (index) {
                        setDialogState(() {
                          selectedType = index == 0 ? 'income' : 'expense';
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      selectedColor: Colors.white,
                      fillColor: primaryBlue,
                      color: Colors.black54,
                      constraints: const BoxConstraints(minHeight: 36, minWidth: 90),
                      children: const [
                        Text('Income'),
                        Text('Expense'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Icon',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160,
                      child: GridView.builder(
                        itemCount: categoryIconMap.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (context, index) {
                          final iconKey = categoryIconMap.keys.elementAt(index);
                          final iconData = categoryIconMap.values.elementAt(index);
                          final isSelected = selectedIconString == iconKey;
                          return GestureDetector(
                            onTap: () => setDialogState(() {
                              selectedIconString = iconKey;
                            }),
                            child: CircleAvatar(
                              backgroundColor:
                                  isSelected ? primaryBlue : lightBgTop,
                              child: Icon(
                                iconData,
                                size: 18,
                                color: isSelected ? Colors.white : navy,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty || user == null) {
                      return;
                    }
                    try {
                      await _firestoreService.addCategory(
                        uid: user!.uid,
                        name: nameController.text,
                        type: selectedType,
                        iconString: selectedIconString,
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (e) {
                      debugPrint('Failed to add category: $e');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in...')),
      );
    }

    return Scaffold(
      backgroundColor: lightBgBottom,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Categories',
          style: TextStyle(
            color: navy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SmartSpendCard(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expense Categories',
                style: TextStyle(
                  color: navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildCategoriesGrid()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        onPressed: _showAddCategoryDialog,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildCategoriesGrid() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.streamUserCategories(
        uid: user!.uid,
        type: 'expense',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No categories found.',
              style: TextStyle(color: Colors.black45),
            ),
          );
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 3 / 2,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            return _CategoryTile(data: data);
          },
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CategoryTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final iconString = (data['icon'] ?? 'category').toString();
    final iconData = categoryIconMap[iconString] ?? Icons.category;
    final colorValue = (data['color'] as int?) ?? primaryBlue.toARGB32();
    final color = Color(colorValue);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              (data['name'] ?? 'Unnamed').toString(),
              style: const TextStyle(
                color: navy,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
