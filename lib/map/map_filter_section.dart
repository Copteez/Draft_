import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:MySecureMap/map/map_source_dropdown.dart';

class MapFilterSection extends StatefulWidget {
  final String selectedParameter;
  final List<String> parameters;
  final Function(String) onParameterChanged;
  final String selectedSource;
  final List<String> sources;
  final Function(String) onSourceChanged;
  final bool isDarkMode;
  final Color darkThemeColor;

  const MapFilterSection({
    Key? key,
    required this.selectedParameter,
    required this.parameters,
    required this.onParameterChanged,
    required this.selectedSource,
    required this.sources,
    required this.onSourceChanged,
    required this.isDarkMode,
    this.darkThemeColor = const Color(0xFF2D3250),
  }) : super(key: key);

  @override
  State<MapFilterSection> createState() => _MapFilterSectionState();
}

class _MapFilterSectionState extends State<MapFilterSection> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDarkMode ? widget.darkThemeColor : Colors.white,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Filter",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Source:",
                          style: TextStyle(
                            fontSize: 16,
                            color: widget.isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xfff9a72b),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  canvasColor: const Color(0xfff9a72b),
                                ),
                                child: DropdownButton<String>(
                                  value: widget.selectedSource,
                                  isExpanded: true,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  items: widget.sources.map((source) {
                                    return DropdownMenuItem<String>(
                                      value: source,
                                      child: Text("Source: $source"),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      widget.onSourceChanged(value);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Parameter:",
                          style: TextStyle(
                            fontSize: 16,
                            color: widget.isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Material(
                          color: Colors.transparent,
                          child: Column(
                            children: widget.parameters
                                .map((param) => RadioListTile<String>(
                                      title: Text(
                                        param,
                                        style: TextStyle(
                                          color: widget.isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      value: param,
                                      groupValue: widget.selectedParameter,
                                      onChanged: (value) {
                                        if (value != null) {
                                          widget.onParameterChanged(value);
                                          Navigator.pop(context);
                                        }
                                      },
                                      activeColor: const Color(0xfff9a72b),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Note: Filter settings do not affect path search results.",
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: widget.isDarkMode
                                ? Colors.white54
                                : Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
