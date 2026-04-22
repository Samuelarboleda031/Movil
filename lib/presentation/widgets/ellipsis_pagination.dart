import 'package:flutter/material.dart';
import 'package:parte_movil/core/themes/app_colors.dart';

class EllipsisPagination extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final Function(int) onPageChanged;

  const EllipsisPagination({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(
          icon: Icons.chevron_left,
          onTap: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
        ),
        const SizedBox(width: 8),
        ..._buildPageNumbers(),
        const SizedBox(width: 8),
        _buildPageButton(
          icon: Icons.chevron_right,
          onTap: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
        ),
      ],
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> widgets = [];
    
    // Always show first page
    widgets.add(_buildNumberButton(1));

    if (currentPage > 3) {
      widgets.add(const _EllipsisDot());
    }

    // Range around current page
    for (int i = currentPage - 1; i <= currentPage + 1; i++) {
      if (i > 1 && i < totalPages) {
        widgets.add(_buildNumberButton(i));
      }
    }

    if (currentPage < totalPages - 2) {
      widgets.add(const _EllipsisDot());
    }

    // Always show last page
    if (totalPages > 1) {
      widgets.add(_buildNumberButton(totalPages));
    }

    return widgets;
  }

  Widget _buildNumberButton(int page) {
    final isSelected = page == currentPage;
    return GestureDetector(
      onTap: isSelected ? null : () => onPageChanged(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? null : Border.all(color: AppColors.divider),
        ),
        child: Text(
          page.toString(),
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(
          icon,
          color: onTap == null ? AppColors.grey : AppColors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _EllipsisDot extends StatelessWidget {
  const _EllipsisDot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text('...', style: TextStyle(color: AppColors.grey, fontSize: 16)),
    );
  }
}
