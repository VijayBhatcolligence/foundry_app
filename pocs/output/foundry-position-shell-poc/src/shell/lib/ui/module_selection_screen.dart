// Phase 3.5: Module Selection Screen
// Purpose: Card-based UI for selecting position modules

import 'package:flutter/material.dart';
import '../position/position_resolver.dart';
import '../modules/module_registry.dart';
import 'module_card.dart';

class ModuleSelectionScreen extends StatefulWidget {
  final Position currentPosition;
  final Function(String moduleId) onModuleSelected;

  const ModuleSelectionScreen({
    Key? key,
    required this.currentPosition,
    required this.onModuleSelected,
  }) : super(key: key);

  @override
  State<ModuleSelectionScreen> createState() => _ModuleSelectionScreenState();
}

class _ModuleSelectionScreenState extends State<ModuleSelectionScreen> {
  late final ModuleRegistry _registry;
  List<ModuleMetadata>? _modules;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _registry = ModuleRegistry.instance;
    _loadModules();
  }

  Future<void> _loadModules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final modules = await _registry.getModulesForSelection();
      setState(() {
        _modules = modules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load modules: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Position Module'),
        automaticallyImplyLeading: false, // No back button
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadModules,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_modules == null || _modules!.isEmpty) {
      return const Center(child: Text('No modules available'));
    }

    // Grid layout for cards (responsive: 2 columns on tablet, 1 on phone)
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: _modules!.length,
      itemBuilder: (context, index) {
        return ModuleCard(
          module: _modules![index],
          onTap: () => widget.onModuleSelected(_modules![index].moduleId),
        );
      },
    );
  }
}
