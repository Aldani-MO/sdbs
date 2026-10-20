import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../services/transit_service.dart';
import '../utils/error_handler.dart';
import '../utils/validators.dart';

class ManageStopsPage extends StatefulWidget {
  const ManageStopsPage({super.key});

  @override
  State<ManageStopsPage> createState() => _ManageStopsPageState();
}

class _ManageStopsPageState extends State<ManageStopsPage> {
  final _formKey = GlobalKey<FormState>();

  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _maxController = TextEditingController();

  bool _isLoading = false;

  void _showQrDialog(String stopId, String stopName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(stopName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Stop ID: $stopId', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: QrImageView(
                  data: stopId,
                  version: QrVersions.auto,
                  size: 200,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.maroon),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 16),
              Text('Print this and place it at the stop.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 20),
              ElevatedButton(
                style: AppTheme.primaryButton,
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createStop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final transitService = Provider.of<TransitService>(context, listen: false);
      final stopId = _idController.text.trim();

      // Uniqueness check: Stop ID
      if (await transitService.stopExists(stopId)) {
        if (mounted) ErrorHandler.showError(context, '❌ Stop ID already exists! Use a different ID.');
        setState(() => _isLoading = false);
        return;
      }

      // Uniqueness check: Stop name
      if (await transitService.stopNameExists(_nameController.text.trim())) {
        if (mounted) ErrorHandler.showError(context, '⚠️ A stop with this name already exists!');
        setState(() => _isLoading = false);
        return;
      }

      await transitService.createStop(
        stopId: stopId,
        name: _nameController.text.trim(),
        latitude: double.parse(_latController.text.trim()),
        longitude: double.parse(_lngController.text.trim()),
        maxThreshold: int.parse(_maxController.text.trim()),
      );

      if (mounted) {
        ErrorHandler.showSuccess(context, 'Stop created successfully!');
        _idController.clear();
        _nameController.clear();
        _latController.clear();
        _lngController.clear();
        _maxController.clear();
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transitService = Provider.of<TransitService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Stops"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Create New Stop", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildTextField(_idController, "Stop ID (e.g. 101)"),
              const SizedBox(height: 16),
              _buildTextField(_nameController, "Stop Name (e.g. Sweileh Circle)"),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField(_latController, "Latitude", validator: Validators.latitude)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_lngController, "Longitude", validator: Validators.longitude)),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(_maxController, "Max Threshold (Early Depart)", validator: (v) => Validators.positiveInt(v, 'Max Threshold')),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: AppTheme.primaryButton,
                  onPressed: _isLoading ? null : _createStop,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Create Stop", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
              const SizedBox(height: 40),
              const Text("Existing Stops", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: transitService.stopsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  if (snapshot.data!.docs.isEmpty) return const Text("No stops in database yet.");

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final int maxT = (data['maxThreshold'] ?? 0).toInt();
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on, color: AppTheme.maroon),
                          title: Text(data['name'] ?? 'Unknown'),
                          subtitle: Text("ID: ${doc.id} | Max Threshold: $maxT"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.qr_code, color: AppTheme.maroon),
                                tooltip: 'Show QR Code',
                                onPressed: () => _showQrDialog(doc.id, data['name'] ?? 'Stop ${doc.id}'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDeleteStop(context, doc.id, data['name'] ?? 'Stop ${doc.id}', transitService),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isNumber = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      validator: validator ?? (isNumber
          ? (val) => Validators.numeric(val, hint)
          : (val) => Validators.required(val, hint)),
      decoration: InputDecoration(
        labelText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _confirmDeleteStop(BuildContext context, String stopId, String stopName, TransitService svc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Stop?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$stopName"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await svc.deleteStop(stopId);
                if (context.mounted) ErrorHandler.showSuccess(context, 'Stop deleted successfully!');
              } catch (e) {
                if (context.mounted) ErrorHandler.showError(context, e.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
