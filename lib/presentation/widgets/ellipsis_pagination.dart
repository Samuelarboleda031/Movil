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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildArrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              const SizedBox(width: 8),
              ..._buildPageNumbers(),
              const SizedBox(width: 8),
              _buildArrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
              ),
            ],
          ),
        ),
      ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.divider.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.gold.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Text(
          page.toString(),
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildArrowButton({required IconData icon, VoidCallback? onTap}) {
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.divider.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.white : AppColors.grey.withOpacity(0.5),
          size: 22,
        ),
      ),
    );
  }
}

class _EllipsisDot extends StatelessWidget {
  const _EllipsisDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 30,
      alignment: Alignment.center,
      child: Text(
        '...',
        style: TextStyle(
          color: AppColors.grey.withOpacity(0.7),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
