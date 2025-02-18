import 'package:flutter/material.dart';

class MapSourceDropdown extends StatelessWidget {
  final String selectedSource;
  final List<String> sources;
  final void Function(String?)? onChanged;

  const MapSourceDropdown({
    Key? key,
    required this.selectedSource,
    required this.sources,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xfff9a72b),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedSource,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          dropdownColor: const Color(0xfff9a72b),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          items: sources.map((source) {
            return DropdownMenuItem<String>(
              value: source,
              child: Text("Source: $source"),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
