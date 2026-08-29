import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/job_model.dart';
import '../../../core/providers/job_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/global_error_boundary.dart';
import '../../jobs/screens/job_detail_screen.dart';
import '../../jobs/widgets/job_card.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  GoogleMapController? _mapController;
  JobPost? _selectedJob;
  bool _mapError = false;

  void _moveToCity(String city) {
    try {
      final target = LocationService.getCityCoordinates(city);
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 13.5),
        ),
      );
    } catch (e) {
      debugPrint('MapView animateCamera error: $e');
      setState(() => _mapError = true);
    }
  }

  Widget _buildMapFallback(List<JobPost> jobs) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.orange.shade100,
          child: Row(
            children: [
              Icon(Icons.map_outlined, color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Map display offline — showing nearby job listings.',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _mapError = false),
                child: const Text('Retry Map'),
              ),
            ],
          ),
        ),
        Expanded(
          child: jobs.isEmpty
              ? const Center(
                  child: Text('No jobs available in this location.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return JobCard(job: job);
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = Provider.of<JobProvider>(context);
    final jobs = jobProvider.filteredJobs;

    final markers = jobs.map((job) {
      return Marker(
        markerId: MarkerId(job.id),
        position: LatLng(job.latitude, job.longitude),
        infoWindow: InfoWindow(
          title: job.title,
          snippet: 'GHS ${job.payRate.toStringAsFixed(0)} / ${job.payUnit}',
        ),
        onTap: () {
          setState(() {
            _selectedJob = job;
          });
        },
      );
    }).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Explorer'),
      ),
      body: GlobalErrorBoundary(
        errorBuilder: (context, details, retry) {
          return _buildMapFallback(jobs);
        },
        child: _mapError
            ? _buildMapFallback(jobs)
            : Stack(
                children: [
                  // Google Map View
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LocationService.accraCenter,
                      zoom: 13.0,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    markers: markers,
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                  ),

                  // Top City Switcher Pills
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['Accra', 'Kumasi', 'Tema'].map((city) {
                          final isSelected = jobProvider.selectedCity == city;
                          return ChoiceChip(
                            label: Text(city),
                            selected: isSelected,
                            onSelected: (_) {
                              jobProvider.setCityFilter(city);
                              _moveToCity(city);
                            },
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              color:
                                  isSelected ? Colors.white : AppTheme.textDark,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Selected Job Card overlay at bottom of screen
                  if (_selectedJob != null)
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedJob!.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () =>
                                      setState(() => _selectedJob = null),
                                ),
                              ],
                            ),
                            Text(
                              '${_selectedJob!.locationName} (${_selectedJob!.city})',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'GHS ${_selectedJob!.payRate.toStringAsFixed(0)} / ${_selectedJob!.payUnit}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => JobDetailScreen(
                                            jobId: _selectedJob!.id),
                                      ),
                                    );
                                  },
                                  child: const Text('View Job'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
