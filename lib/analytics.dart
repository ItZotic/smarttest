import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:smartspend/ui/smart_spend_theme.dart';

import 'add_transaction.dart';

class AnalyticsScreen extends StatefulWidget {
  final ScrollController? scrollController;

  const AnalyticsScreen({super.key, this.scrollController});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final TransactionSummaryService _summaryService = TransactionSummaryService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final now = DateTime.now();
    final startWindow = DateTime(now.year, now.month - 5, 1);
    final endWindow = DateTime(now.year, now.month + 1, 1);

    final stream = _summaryService.transactionsStream(
      uid: user.uid,
      start: startWindow,
      end: endWindow,
    );

    return Scaffold(
      backgroundColor: lightBgBottom,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Analytics',
          style: TextStyle(
            color: navy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<List<AppTransaction>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          double income = 0;
          double expenses = 0;
          final Map<String, double> categoryTotals = {};

          final now = DateTime.now();
          final Map<String, double> monthTotals = {};

          final expenseBreakdown =
              _summaryService.expenseTotalsByCategory(monthTransactions);
          final palette = [
            primaryBlue,
            Colors.pinkAccent,
            Colors.amber.shade700,
            Colors.teal,
            Colors.deepPurpleAccent,
            Colors.green.shade600,
          ];
          final pieSections = <PieChartSectionData>[];
          final legendEntries = <Widget>[];
          int colorIndex = 0;
          expenseBreakdown.forEach((category, value) {
            final color = palette[colorIndex % palette.length];
            colorIndex++;
            pieSections.add(
              PieChartSectionData(
                value: value,
                color: color,
                radius: 50,
                title: '',
              ),
            );
            legendEntries.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$category: ${_summaryService.formatCurrency(value)}',
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          });

          final monthLabels = List.generate(6, (index) {
            return DateTime(now.year, now.month - (5 - index), 1);
          });
          final netByMonth = <String, double>{};
          for (final txn in transactions) {
            final key = '${txn.date.year}-${txn.date.month.toString().padLeft(2, '0')}';
            final amount = txn.isExpense ? -txn.absoluteAmount : txn.absoluteAmount;
            netByMonth[key] = (netByMonth[key] ?? 0) + amount;
          }

          final List<String> last6 = [];
          for (int i = 5; i >= 0; i--) {
            final dt = DateTime(now.year, now.month - i, 1);
            final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            return netByMonth[key] ?? 0.0;
          }).toList();
          double minY = monthValues.reduce(math.min);
          double maxY = monthValues.reduce(math.max);
          if ((maxY - minY).abs() < 10) {
            maxY += 10;
            minY -= 10;
          } else {
            final padding = (maxY - minY) * 0.15;
            maxY += padding;
            minY -= padding;
          }

          final monthValues = last6.map((k) => monthTotals[k] ?? 0.0).toList();

          final pieSections = categoryTotals.entries.map((e) {
            final val = e.value.abs();
            return PieChartSectionData(
              value: val,
              color: val == 0
                  ? Colors.grey
                  : (e.value > 0 ? Colors.green : Colors.redAccent),
              radius: 50,
              title: '',
            );
          }).toList();

          final incomeThisMonthString = '₱${income.toStringAsFixed(2)}';
          final expensesThisMonthString = '₱${expenses.toStringAsFixed(2)}';

          final donutChartWidget = PieChart(PieChartData(sections: pieSections));
          final legendWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: categoryTotals.entries.map(
              (e) {
                final color = e.value < 0 ? Colors.redAccent : Colors.green;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${e.key}: ₱${e.value.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ).toList(),
          );

          final lineChartWidget = LineChart(
            LineChartData(
              minY: (monthValues.reduce((a, b) => a < b ? a : b)) * 1.1 - 10,
              maxY: (monthValues.reduce((a, b) => a > b ? a : b)) * 1.1 + 10,
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    monthValues.length,
                    (i) => FlSpot(i.toDouble(), monthValues[i]),
                  ),
                  isCurved: true,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                  color: primaryBlue,
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= last6.length) {
                        return const SizedBox();
                      }
                      final key = last6[idx];
                      final parts = key.split('-');
                      final m = int.parse(parts[1]);
                      final dt = DateTime(int.parse(parts[0]), m);
                      final label = DateFormat.MMM().format(dt);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(label),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true),
                ),
              ),
              gridData: FlGridData(show: true),
            ),
          );

          return SafeArea(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  SmartSpendCard(
                    margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryTile(
                            title: 'Income',
                            amount: incomeThisMonthString,
                            caption: 'This month',
                            amountColor: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryTile(
                            title: 'Expenses',
                            amount: expensesThisMonthString,
                            caption: 'This month',
                            amountColor: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SmartSpendCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expense Breakdown',
                          style: TextStyle(
                            color: navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(height: 180, child: Center(child: donutChartWidget)),
                        const SizedBox(height: 12),
                        legendWidget,
                      ],
                    ),
                  ),
                  SmartSpendCard(
                    margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '6-Month Trend',
                          style: TextStyle(
                            color: navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(height: 200, child: lineChartWidget),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        onPressed: () => _onAddTransactionFromAnalytics(context),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _onAddTransactionFromAnalytics(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final String amount;
  final String caption;
  final Color amountColor;

  const _SummaryTile({
    required this.title,
    required this.amount,
    required this.caption,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12, color: Colors.black54, height: 1.2)),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}
