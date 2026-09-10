import 'package:flutter/material.dart';

class CartItemTile extends StatelessWidget {
  final String name;
  final String? category;
  final String qty;
  final String weight;
  final String amount;
  final VoidCallback onDelete;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const CartItemTile({
    super.key,
    required this.name,
    this.category,
    required this.qty,
    required this.weight,
    required this.amount,
    required this.onDelete,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.shopping_bag_outlined, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category != null)
                  Text(
                    category!.toUpperCase(), 
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  name, 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(weight, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
              ],
            ),
          ),
          if (onDecrement != null && onIncrement != null) ...[
            InkWell(
              onTap: onDecrement,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.remove, size: 14),
              ),
            ),
            const SizedBox(width: 4),
            Text(qty, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 4),
            InkWell(
              onTap: onIncrement,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.add, size: 14),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(amount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.onSurface)),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.close_rounded, size: 16, color: theme.colorScheme.error.withValues(alpha: 0.8)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
