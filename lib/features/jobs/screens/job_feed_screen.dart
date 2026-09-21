import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/providers/job_provider.dart';
import '../widgets/job_card.dart';

class JobFeedScreen extends StatefulWidget {
  const JobFeedScreen({super.key});

  @override
  State<JobFeedScreen> createState() => _JobFeedScreenState();
}

class _JobFeedScreenState extends State<JobFeedScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _cities = ['All', 'Accra', 'Kumasi', 'Tema'];
  final List<String> _categories = [
    'All',
    'Construction & Labor',
    'Hospitality',
    'Cleaning',
    'Retail',
    'Transport',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = Provider.of<JobProvider>(context);
    final filteredJobs = jobProvider.filteredJobs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Job Connector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header Container
          Container(
            color: AppTheme.primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (value) => jobProvider.setSearchQuery(value),
                  decoration: InputDecoration(
                    hintText: 'Search jobs near Circle, Kejetia, Tema...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.primaryColor,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              jobProvider.setSearchQuery('');
                            },
                          )
                        : null,
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // City Chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _cities.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final city = _cities[index];
                      final isSelected = jobProvider.selectedCity == city;
                      return ChoiceChip(
                        label: Text(city),
                        selected: isSelected,
                        onSelected: (_) => jobProvider.setCityFilter(city),
                        selectedColor: AppTheme.secondaryColor,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Category Selector
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: Colors.white,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = jobProvider.selectedCategory == category;
                return ActionChip(
                  label: Text(category),
                  onPressed: () => jobProvider.setCategoryFilter(category),
                  backgroundColor: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : Colors.grey.shade100,
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textMuted,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),

          // Job Feed List
          Expanded(
            child: (jobProvider.isLoading && filteredJobs.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : (jobProvider.loadError != null && filteredJobs.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 56),
                        const SizedBox(height: 12),
                        Text(jobProvider.loadError!),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: jobProvider.retryLoad,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : filteredJobs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No jobs found matching your criteria.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try adjusting your city or search keywords.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredJobs.length,
                    itemBuilder: (context, index) {
                      return JobCard(job: filteredJobs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
