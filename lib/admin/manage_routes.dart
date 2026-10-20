import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../services/transit_service.dart';
import '../utils/error_handler.dart';

class ManageRoutesPage extends StatefulWidget {
  const ManageRoutesPage({super.key});

  @override
  State<ManageRoutesPage> createState() => _ManageRoutesPageState();
}

class _ManageRoutesPageState extends State<ManageRoutesPage> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;

  List<Map<String, dynamic>> _allStops = [];
  final List<Map<String, dynamic>> _selectedStops = [];
  String? _stopToAddId;

  @override
  void initState() {
    super.initState();
    _fetchStops();
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchStops() async {
    try {
      final svc = Provider.of<TransitService>(context, listen: false);
      final stops = await svc.fetchAllStops();
      setState(() => _allStops = stops);
    } catch (e) {
      debugPrint('Error fetching stops: $e');
    }
  }

  Future<void> _createRoute() async {
    if (_idController.text.isEmpty || _nameController.text.isEmpty) {
      ErrorHandler.showError(context, 'ID and Name are required');
      return;
    }
    if (_selectedStops.length < 2) {
      ErrorHandler.showError(context, 'A route needs at least 2 stops (start and end)');
      return;
    }

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final svc = Provider.of<TransitService>(context, listen: false);
      final routeId = _idController.text.trim();
      final stopIds = _selectedStops.map((s) => s['id'] as String).toList();
      
      if (await svc.routeExists(routeId)) {
        ErrorHandler.showErrorOnMessenger(messenger, '❌ Route ID already exists!');
        setState(() => _isLoading = false);
        return;
      }
      if (await svc.routeNameExists(_nameController.text.trim())) {
        ErrorHandler.showErrorOnMessenger(messenger, '⚠️ A route with this name already exists!');
        setState(() => _isLoading = false);
        return;
      }

      await svc.createRoute(
        routeId: routeId,
        name: _nameController.text.trim(),
        isActive: _isActive,
        stopIds: stopIds,
      );

      ErrorHandler.showSuccessOnMessenger(messenger, 'Route Created Successfully!');
      _idController.clear();
      _nameController.clear();
      setState(() { _selectedStops.clear(); _stopToAddId = null; });
    } catch (e) {
      ErrorHandler.showErrorOnMessenger(messenger, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addStopToRoute() {
    if (_stopToAddId == null) return;
    // Prevent adding the same stop twice
    if (_selectedStops.any((s) => s['id'] == _stopToAddId)) {
      ErrorHandler.showError(context, '⚠️ This stop is already in the route!');
      return;
    }
    final stop = _allStops.firstWhere((s) => s['id'] == _stopToAddId);
    setState(() {
      _selectedStops.add(stop);
      _stopToAddId = null;
    });
  }

  void _removeStopFromRoute(int index) {
    setState(() => _selectedStops.removeAt(index));
  }

  void _confirmDeleteRoute(BuildContext context, String routeId, String routeName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Route', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$routeName"? This cannot be undone.'),
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
              final messenger = ScaffoldMessenger.of(context);
              try {
                final svc = Provider.of<TransitService>(context, listen: false);
                await svc.deleteRoute(routeId);
                ErrorHandler.showSuccessOnMessenger(messenger, 'Route deleted successfully!');
              } catch (e) {
                ErrorHandler.showErrorOnMessenger(messenger, 'Error: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditRouteDialog(Map<String, dynamic> routeData, String routeId) {
    showDialog(
      context: context,
      builder: (context) => _EditRouteDialog(
        routeData: routeData,
        routeId: routeId,
        allStops: _allStops,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<TransitService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text("Manage Routes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.maroon,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CREATE ROUTE SECTION ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Create New Route", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _idController,
                    decoration: InputDecoration(
                      labelText: "Route ID (e.g. route-1)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Route Name (e.g. Sweileh to Jordan Uni)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.route),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text("Is Route Active?", style: TextStyle(fontWeight: FontWeight.w500)),
                    contentPadding: EdgeInsets.zero,
                    value: _isActive,
                    activeThumbColor: Colors.green,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),

                  const Divider(height: 40),

                  // ── ASSIGN STOPS ──────────────────────────────────────────
                  const Text("Assign Stops (Order matters!)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text("Add stops in the exact order the bus will visit them.", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 16),

                  _StopPickerRow(
                    allStops: _allStops,
                    selectedId: _stopToAddId,
                    onChanged: (val) => setState(() => _stopToAddId = val),
                    onAdd: _stopToAddId == null ? null : _addStopToRoute,
                  ),

                  const SizedBox(height: 16),

                  _SelectedStopsList(
                    stops: _selectedStops,
                    onRemove: _removeStopFromRoute,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) newIndex -= 1;
                        final item = _selectedStops.removeAt(oldIndex);
                        _selectedStops.insert(newIndex, item);
                      });
                    },
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createRoute,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.maroon,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Create Route", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── EXISTING ROUTES SECTION ───────────────────────────────
            const Text("Existing Routes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder(
              stream: svc.routesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Text("No routes found.", style: TextStyle(color: Colors.grey));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final stopIds = (data['stopIds'] as List<dynamic>? ?? []);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppTheme.maroon.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.route, color: AppTheme.maroon),
                        ),
                        title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("ID: ${doc.id}\nStops: ${stopIds.length}", style: TextStyle(color: Colors.grey[600], height: 1.4)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: data['isActive'] ?? false,
                              activeThumbColor: Colors.green,
                              onChanged: (val) => svc.toggleRouteActive(doc.id, val),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Edit route',
                              onPressed: () => _showEditRouteDialog(data, doc.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete route',
                              onPressed: () => _confirmDeleteRoute(context, doc.id, data['name'] ?? doc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── REUSABLE PRIVATE WIDGETS ─────────────────────────────────────────────────

/// Stop picker dropdown + Add button row.
class _StopPickerRow extends StatelessWidget {
  final List<Map<String, dynamic>> allStops;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAdd;

  const _StopPickerRow({
    required this.allStops,
    required this.selectedId,
    required this.onChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                isDense: true,
                hint: const Text("Select a stop..."),
                value: selectedId,
                items: allStops.map((stop) {
                  return DropdownMenuItem<String>(
                    value: stop['id'],
                    child: Text("${stop['id']} - ${stop['name']}", overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.maroon,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onAdd,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ],
    );
  }
}

/// Reorderable list of selected stops with remove buttons.
class _SelectedStopsList extends StatelessWidget {
  final List<Map<String, dynamic>> stops;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _SelectedStopsList({
    required this.stops,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Text("No stops added yet.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stops.length,
        onReorder: onReorder,
        itemBuilder: (context, index) {
          final stop = stops[index];
          final isFirst = index == 0;
          final isLast = index == stops.length - 1;

          return ListTile(
            key: ValueKey('${stop['id']}_$index'),
            leading: CircleAvatar(
              backgroundColor: isFirst ? AppTheme.maroon : (isLast ? Colors.green : Colors.grey.shade300),
              radius: 14,
              child: Text('${index + 1}', style: TextStyle(color: isFirst || isLast ? Colors.white : Colors.black, fontSize: 12)),
            ),
            title: Text(stop['name']),
            subtitle: Text("ID: ${stop['id']}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 20),
              onPressed: () => onRemove(index),
            ),
          );
        },
      ),
    );
  }
}

// ── EDIT ROUTE DIALOG ────────────────────────────────────────────────────────

class _EditRouteDialog extends StatefulWidget {
  final Map<String, dynamic> routeData;
  final String routeId;
  final List<Map<String, dynamic>> allStops;

  const _EditRouteDialog({
    required this.routeData,
    required this.routeId,
    required this.allStops,
  });

  @override
  State<_EditRouteDialog> createState() => _EditRouteDialogState();
}

class _EditRouteDialogState extends State<_EditRouteDialog> {
  late TextEditingController _nameController;
  late bool _isActive;
  final List<Map<String, dynamic>> _selectedStops = [];
  String? _stopToAddId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.routeData['name']);
    _isActive = widget.routeData['isActive'] ?? false;

    final List<dynamic> currentStopIds = widget.routeData['stopIds'] ?? [];
    for (var id in currentStopIds) {
      try {
        _selectedStops.add(widget.allStops.firstWhere((s) => s['id'] == id));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addStop() {
    if (_stopToAddId == null) return;
    // Prevent adding the same stop twice
    if (_selectedStops.any((s) => s['id'] == _stopToAddId)) {
      ErrorHandler.showError(context, '⚠️ This stop is already in the route!');
      return;
    }
    final stop = widget.allStops.firstWhere((s) => s['id'] == _stopToAddId);
    setState(() {
      _selectedStops.add(stop);
      _stopToAddId = null;
    });
  }

  void _removeStop(int index) => setState(() => _selectedStops.removeAt(index));

  Future<void> _saveChanges() async {
    if (_nameController.text.isEmpty) {
      ErrorHandler.showError(context, 'Name is required');
      return;
    }
    if (_selectedStops.length < 2) {
      ErrorHandler.showError(context, 'A route needs at least 2 stops (start and end)');
      return;
    }

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final svc = Provider.of<TransitService>(context, listen: false);
      final routeName = _nameController.text.trim();

      if (routeName != widget.routeData['name']) {
        if (await svc.routeNameExists(routeName)) {
          ErrorHandler.showErrorOnMessenger(messenger, '⚠️ A route with this name already exists!');
          setState(() => _isLoading = false);
          return;
        }
      }

      await svc.updateRoute(
        routeId: widget.routeId,
        name: routeName,
        isActive: _isActive,
        stopIds: _selectedStops.map((s) => s['id'] as String).toList(),
      );

      if (mounted) {
        Navigator.pop(context);
      }
      ErrorHandler.showSuccessOnMessenger(messenger, 'Route Updated Successfully!');
    } catch (e) {
      ErrorHandler.showErrorOnMessenger(messenger, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Edit Route", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Read-only Route ID
                    TextField(
                      controller: TextEditingController(text: widget.routeId),
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Route ID (Cannot be changed)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.tag),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Route Name",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.route),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text("Is Route Active?", style: TextStyle(fontWeight: FontWeight.w500)),
                      contentPadding: EdgeInsets.zero,
                      value: _isActive,
                      activeThumbColor: Colors.green,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                    const Divider(height: 40),
                    const Text("Manage Stops", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _StopPickerRow(
                      allStops: widget.allStops,
                      selectedId: _stopToAddId,
                      onChanged: (val) => setState(() => _stopToAddId = val),
                      onAdd: _stopToAddId == null ? null : _addStop,
                    ),
                    const SizedBox(height: 16),
                    _SelectedStopsList(
                      stops: _selectedStops,
                      onRemove: _removeStop,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (oldIndex < newIndex) newIndex -= 1;
                          final item = _selectedStops.removeAt(oldIndex);
                          _selectedStops.insert(newIndex, item);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.maroon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
