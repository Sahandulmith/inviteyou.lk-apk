import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final Color color;
  final IconData icon;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subValue,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardTheme.color ?? Colors.white,
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      if (subValue != null)
                        Text(
                          subValue!,
                          style: TextStyle(
                            fontSize: 12,
                            color: color.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
