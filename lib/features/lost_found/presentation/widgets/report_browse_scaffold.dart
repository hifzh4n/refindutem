import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ReportBrowseScaffold extends StatelessWidget {
  const ReportBrowseScaffold({
    required this.searchController,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.totalCount,
    required this.visibleCount,
    required this.emptyText,
    required this.children,
    super.key,
  });

  final TextEditingController searchController;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final int totalCount;
  final int visibleCount;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stackFilters = constraints.maxWidth < 560;
            final search = TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Search reports',
                hintText: 'Item, location, detail...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            );
            final category = DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.filter_list_rounded),
              ),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onCategoryChanged(value);
                }
              },
            );

            if (stackFilters) {
              return Column(
                children: [search, const SizedBox(height: 12), category],
              );
            }

            return Row(
              children: [
                Expanded(flex: 3, child: search),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: category),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: AppColors.mutedInk,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Showing $visibleCount of $totalCount open reports',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (children.isEmpty)
          Text(
            emptyText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }
}
