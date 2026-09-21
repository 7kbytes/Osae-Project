import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/job_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/job_provider.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/utils/input_sanitizer.dart';

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _payRateController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController(text: '+233 24 999 8877');

  String _selectedCategory = 'Construction & Labor';
  String _selectedCity = 'Accra';
  String _selectedPayUnit = 'per day';

  double _latitude = 5.5586;
  double _longitude = -0.2014;

  final List<String> _categories = [
    'Construction & Labor',
    'Hospitality',
    'Cleaning',
    'Retail',
    'Transport',
    'Other',
  ];

  final List<String> _cities = ['Accra', 'Kumasi', 'Tema'];
  final List<String> _payUnits = ['per day', 'per hour', 'fixed'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _payRateController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onCityChanged(String? city) {
    if (city == null) return;
    setState(() {
      _selectedCity = city;
      if (city == 'Accra') {
        _latitude = 5.5586;
        _longitude = -0.2014;
        _locationController.text = 'Circle Market, Accra';
      } else if (city == 'Kumasi') {
        _latitude = 6.6961;
        _longitude = -1.6234;
        _locationController.text = 'Kejetia Market, Kumasi';
      } else if (city == 'Tema') {
        _latitude = 5.6424;
        _longitude = 0.0050;
        _locationController.text = 'Community 1 Market, Tema';
      }
    });
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    final jobProvider = Provider.of<JobProvider>(context, listen: false);
    final me = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (me == null) return;

    final newJob = JobPost(
      id: 'job_${DateTime.now().millisecondsSinceEpoch}',
      title: InputSanitizer.sanitize(_titleController.text),
      description: InputSanitizer.sanitize(_descriptionController.text),
      category: _selectedCategory,
      payRate:
          double.tryParse(
            InputSanitizer.sanitizeNumeric(_payRateController.text),
          ) ??
          150.0,
      payUnit: _selectedPayUnit,
      currency: 'GHS',
      city: _selectedCity,
      locationName: InputSanitizer.sanitize(_locationController.text),
      latitude: _latitude,
      longitude: _longitude,
      posterId: me.id,
      posterName: me.displayName,
      posterPhone: InputSanitizer.sanitizePhone(_phoneController.text),
      createdAt: DateTime.now(),
    );

    final saved = await jobProvider.addJob(newJob);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Job posting created successfully!'
              : (jobProvider.lastError ?? 'Could not save the job.'),
        ),
        backgroundColor: saved ? AppTheme.primaryColor : Colors.red,
      ),
    );
    if (!saved) return;

    // Reset form
    _titleController.clear();
    _descriptionController.clear();
    _payRateController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Informal Job')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Post a New Gig Opportunity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Reach workers nearby in Accra, Kumasi, or Tema instantly.',
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Job Title',
                  hintText: 'e.g. Market Offloader or Restaurant Waiter',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (val) => FormValidators.validateRequired(
                  val,
                  'Job Title',
                  minLength: 3,
                  maxLength: 100,
                ),
              ),
              const SizedBox(height: 16),

              // Category & City Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategory = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCity,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'City'),
                      items: _cities
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: _onCityChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pay Rate & Pay Unit Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _payRateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pay Amount (GHS)',
                        hintText: 'e.g. 150',
                        prefixIcon: Icon(Icons.money),
                      ),
                      validator: (val) => FormValidators.validatePayRate(val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPayUnit,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Pay Rate Unit',
                      ),
                      items: _payUnits
                          .map(
                            (u) => DropdownMenuItem(
                              value: u,
                              child: Text(u, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedPayUnit = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location Landmark
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Exact Location / Landmark',
                  hintText: 'e.g. Container 14 near Circle VIP Bus Station',
                  prefixIcon: Icon(Icons.pin_drop_outlined),
                ),
                validator: (val) => FormValidators.validateRequired(
                  val,
                  'Location',
                  minLength: 3,
                  maxLength: 120,
                ),
              ),
              const SizedBox(height: 16),

              // Contact Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (val) => FormValidators.validateGhanaPhone(val),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Job Description & Requirements',
                  hintText:
                      'Describe what work needs to be done, working hours, and payment timing...',
                  alignLabelWithHint: true,
                ),
                validator: (val) => FormValidators.validateRequired(
                  val,
                  'Job Description',
                  minLength: 5,
                  maxLength: 2000,
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitJob,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Publish Job Posting'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
