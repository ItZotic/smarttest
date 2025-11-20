import 'package:flutter/material.dart';

const Color navy = Color(0xFF081A3E);
const Color primaryBlue = Color(0xFF2979FF);
const Color lightBgTop = Color(0xFFE6F0FF);
const Color lightBgBottom = Color(0xFFF8FBFF);

BoxDecoration smartSpendGradient = const BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      lightBgTop,
      lightBgBottom,
    ],
  ),
);

class SmartSpendAppBarTitle extends StatelessWidget {
  const SmartSpendAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.grid_view_rounded, size: 18, color: navy),
        ),
        const SizedBox(width: 12),
        const Text(
          'SmartSpend',
          style: TextStyle(
            color: navy,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

class SmartSpendCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const SmartSpendCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
