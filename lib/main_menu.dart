import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'home.dart';
import 'budget.dart';
import 'analytics.dart';
import 'accounts.dart';
import 'categories_screen.dart';
import 'package:smartspend/services/auth_service.dart'; // Check your path for auth service
import 'add_transaction.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;
  late final ScrollController _homeScrollController;
  late final ScrollController _budgetScrollController;
  late final ScrollController _analyticsScrollController;
  late final ScrollController _accountsScrollController;
  late final List<Widget> _pages;
  bool _fabVisible = true;
  final Map<ScrollController, VoidCallback> _controllerListeners = {};

  void _handleScroll(ScrollController controller) {
    if (!controller.hasClients) return;
    final direction = controller.position.userScrollDirection;
    if (direction == ScrollDirection.reverse && _fabVisible) {
      setState(() => _fabVisible = false);
    } else if (direction == ScrollDirection.forward && !_fabVisible) {
      setState(() => _fabVisible = true);
    }
  }

  void _registerController(ScrollController controller) {
    void listener() => _handleScroll(controller);
    controller.addListener(listener);
    _controllerListeners[controller] = listener;
  }

  @override
  void initState() {
    super.initState();
    _homeScrollController = ScrollController();
    _budgetScrollController = ScrollController();
    _analyticsScrollController = ScrollController();
    _accountsScrollController = ScrollController();

    for (final controller in [
      _homeScrollController,
      _budgetScrollController,
      _analyticsScrollController,
      _accountsScrollController,
    ]) {
      _registerController(controller);
    }
    _pages = [
      HomeScreen(scrollController: _homeScrollController),
      BudgetScreen(scrollController: _budgetScrollController),
      AnalyticsScreen(scrollController: _analyticsScrollController),
      AccountsScreen(scrollController: _accountsScrollController),
      const CategoriesScreen(),
    ];
  }

  @override
  void dispose() {
    _controllerListeners.forEach((controller, listener) {
      controller
        ..removeListener(listener)
        ..dispose();
    });
    _controllerListeners.clear();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (!_fabVisible) _fabVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(
      0xFF2D79F6,
    ); // Updated to match new blue theme
    const Color inactiveColor = Colors.grey;

    return Scaffold(
      extendBody: true,
      floatingActionButton: _selectedIndex == 0
          ? null
          : AnimatedSlide(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              offset: _fabVisible ? Offset.zero : const Offset(0, 2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _fabVisible ? 1 : 0,
                child: FloatingActionButton(
                  backgroundColor: primaryColor,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddTransactionScreen()),
                    );
                  },
                ),
              ),
            ),
      floatingActionButtonLocation:
          _selectedIndex == 0 ? null : FloatingActionButtonLocation.endFloat,

      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: inactiveColor,
        showUnselectedLabels: true,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Budget',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Analysis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_rounded),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_rounded),
            label: 'Categories',
          ),
        ],
      ),
    );
  }
}
