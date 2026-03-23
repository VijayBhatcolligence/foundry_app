// Phase 3.5: Module Card Widget
// Purpose: Reusable card widget for displaying module metadata

import 'package:flutter/material.dart';
import '../modules/module_registry.dart';

class ModuleCard extends StatelessWidget {
  final ModuleMetadata module;
  final VoidCallback onTap;

  const ModuleCard({
    Key? key,
    required this.module,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Module icon (Material icons based on moduleId)
              Icon(
                _getModuleIcon(module.moduleId),
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              // Display name
              Text(
                module.displayName,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Description
              Expanded(
                child: Text(
                  module.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Version badge
              const SizedBox(height: 8),
              Text(
                'v${module.version}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Get Material icon based on moduleId
  IconData _getModuleIcon(String moduleId) {
    switch (moduleId) {
      case 'sample-warehouse':
        return Icons.warehouse;
      case 'sample-inventory':
        return Icons.inventory_2;
      case 'sample-quality':
        return Icons.verified;
      default:
        return Icons.apps;
    }
  }
}
