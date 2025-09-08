import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../data/repositories/alarm_repository.dart';
import '../data/models/alarm_model.dart';
import '../core/services/permission_service.dart';
import '../core/services/audio_file_service.dart';
import '../core/services/audio_service.dart';
import '../core/services/location_search_service.dart';
import 'alarm_list_screen.dart';
import 'logs_screen.dart';
import 'package:file_picker/file_picker.dart';

class MapScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final int? initialRadius;

  const MapScreen({super.key, this.initialLocation, this.initialRadius});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? selectedLocation;
  LatLng? currentLocation;
  final AlarmRepository _repo = AlarmRepository();
  int radius = 2000;
  String? mp3Path;
  LocationPermission? currentPermission;
  final MapController _mapController = MapController();
  Timer? _locationTimer;
  final Distance _distance = const Distance();

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<LocationSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  Timer? _searchDebounceTimer;

  // Flag to track if this is the initial location load
  bool _hasInitialLocationBeenSet = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
    _getCurrentLocation();
    _startLocationUpdates();

    // Set initial location and radius if provided
    if (widget.initialLocation != null) {
      selectedLocation = widget.initialLocation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(widget.initialLocation!, 15.0);
      });
    }
    if (widget.initialRadius != null) {
      radius = widget.initialRadius!;
    }

    // Listen to audio service playing state changes
    AudioService.instance.isPlayingNotifier.addListener(_onAudioStateChanged);
  }

  double? _calculateDistanceToSelected() {
    if (currentLocation == null || selectedLocation == null) return null;
    return _distance.as(LengthUnit.Meter, currentLocation!, selectedLocation!);
  }

  void _onAudioStateChanged() {
    // Update UI when audio playing state changes
    print(
      'MapScreen: Audio playing state changed: ${AudioService.instance.isPlaying}',
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Debounce search to avoid too many API calls
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      final results = await LocationSearchService.instance.searchLocation(
        query,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Error searching location: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _selectSearchResult(LocationSearchResult result) {
    setState(() {
      selectedLocation = result.coordinates;
      _showSearchResults = false;
      _searchController.clear();
    });

    // Move map to selected location
    _mapController.move(result.coordinates, 15.0);

    // Unfocus search field
    _searchFocusNode.unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${result.displayName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _showSearchResults = false;
      _searchResults = [];
      _isSearching = false;
    });
    _searchFocusNode.unfocus();
  }

  void _showDebugInfo() async {
    final alarms = await _repo.getActiveAlarmsFromDB();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current Location: ${currentLocation?.latitude.toStringAsFixed(6)}, ${currentLocation?.longitude.toStringAsFixed(6)}',
              ),
              Text(
                'Selected Location: ${selectedLocation?.latitude.toStringAsFixed(6)}, ${selectedLocation?.longitude.toStringAsFixed(6)}',
              ),
              if (currentLocation != null && selectedLocation != null)
                Text(
                  'Distance: ${_calculateDistanceToSelected()?.toStringAsFixed(2)} meters',
                ),
              const SizedBox(height: 10),
              Text('Active Alarms: ${alarms.length}'),
              ...alarms.map(
                (alarm) => Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'Alarm ${alarm.id}: ${alarm.destLat.toStringAsFixed(6)}, ${alarm.destLng.toStringAsFixed(6)} (${alarm.radiusM}m)',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('Permission: $currentPermission'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    // Remove the audio service listener
    AudioService.instance.isPlayingNotifier.removeListener(
      _onAudioStateChanged,
    );
    super.dispose();
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _getCurrentLocation();
    });
  }

  Future<void> _checkPermissionStatus() async {
    final permission = await PermissionService.instance.getCurrentPermission();
    if (mounted) {
      setState(() => currentPermission = permission);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await PermissionService.instance
          .getCurrentPermission();
      if (PermissionService.instance.hasLocationPermission(permission)) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() {
            currentLocation = LatLng(position.latitude, position.longitude);
          });

          // Only center the map on current location for the initial load
          if (!_hasInitialLocationBeenSet) {
            _mapController.move(currentLocation!, 15.0);
            _hasInitialLocationBeenSet = true;
          }
        }
      }
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  void _centerOnCurrentLocation() {
    if (currentLocation != null) {
      _mapController.move(currentLocation!, 15.0);
    } else {
      _getCurrentLocation();
    }
  }

  Widget _buildLocationLegend() {
    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 10),
              ),
              const SizedBox(width: 4),
              Text(
                currentLocation != null
                    ? 'Your location'
                    : 'Location unavailable',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          if (selectedLocation != null) ...[
            const SizedBox(height: 4),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: Colors.red, size: 16),
                SizedBox(width: 4),
                Text('Alarm location', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _stopAlarm() async {
    try {
      // Stop the audio
      await AudioService.instance.stop();

      // Deactivate all active alarms
      final activeAlarms = await _repo.getActiveAlarmsFromDB();
      for (var alarm in activeAlarms) {
        await _repo.deactivateAlarm(alarm.id!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stopped alarm and deactivated ${activeAlarms.length} active alarm(s)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      print(
        'MapScreen: Stopped alarm and deactivated ${activeAlarms.length} alarms',
      );
    } catch (e) {
      print('Error stopping alarm: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error stopping alarm: $e')));
      }
    }
  }

  Future<void> pickMP3() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
      );

      if (result != null && result.files.single.path != null) {
        final tempPath = result.files.single.path!;
        final originalName = result.files.single.name;

        // Save the file to permanent storage
        final permanentPath = await AudioFileService.instance.saveAudioFile(
          tempPath,
          originalName,
        );

        if (permanentPath != null) {
          setState(() => mp3Path = permanentPath);
          print(
            'AudioFile: Successfully saved $originalName to permanent location',
          );
        } else {
          throw Exception('Failed to save audio file to permanent location');
        }
      }
    } catch (e) {
      print('Error picking MP3 file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting audio file: $e')),
        );
      }
    }
  }

  Widget _buildPermissionBanner() {
    if (currentPermission == null) return const SizedBox.shrink();

    String message;
    Color color;
    IconData icon;
    VoidCallback? onTap;

    switch (currentPermission!) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return const SizedBox.shrink(); // No banner needed for granted permissions
      case LocationPermission.denied:
        message = "Location permission needed for alarms to work";
        color = Colors.orange;
        icon = Icons.location_off;
        onTap = () async {
          await PermissionService.instance.requestLocationPermission();
          _checkPermissionStatus();
        };
        break;
      case LocationPermission.deniedForever:
        message =
            "Location permission permanently denied. Tap to open settings.";
        color = Colors.red;
        icon = Icons.location_disabled;
        onTap = () => PermissionService.instance.openAppSettings();
        break;
      case LocationPermission.unableToDetermine:
        message = "Unable to determine location permission status";
        color = Colors.grey;
        icon = Icons.help_outline;
        onTap = null;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search for a location...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!_showSearchResults) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: _isSearching
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Searching...'),
                ],
              ),
            )
          : _searchResults.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No results found'),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.blue),
                  title: Text(
                    result.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    result.address,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectSearchResult(result),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SleepyTravels"),
        actions: [
          // Stop alarm button - only show when alarm is playing
          if (AudioService.instance.isPlaying)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              onPressed: _stopAlarm,
              tooltip: 'Stop Alarm',
            ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _showDebugInfo(),
            tooltip: 'Debug Info',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnCurrentLocation,
            tooltip: 'Center on my location',
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlarmListScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPermissionBanner(),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(6.9271, 79.8612),
                    initialZoom: 13,
                    onTap: (tapPosition, point) {
                      setState(() {
                        selectedLocation = point;
                        // Hide search results when user taps on map
                        _showSearchResults = false;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: 'com.example.sleepytravels_app',
                    ),
                    MarkerLayer(
                      markers: [
                        // Current location marker
                        if (currentLocation != null)
                          Marker(
                            point: currentLocation!,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        // Selected location marker (for alarm)
                        if (selectedLocation != null)
                          Marker(
                            point: selectedLocation!,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Search bar positioned at top
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Column(
                    children: [_buildSearchBar(), _buildSearchResults()],
                  ),
                ),
                // Legend positioned at bottom-left
                Positioned(bottom: 10, left: 10, child: _buildLocationLegend()),
              ],
            ),
          ),
          if (selectedLocation != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // Distance display
                  if (currentLocation != null && selectedLocation != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8.0),
                      margin: const EdgeInsets.only(bottom: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        'Distance to alarm location: ${_calculateDistanceToSelected()?.toStringAsFixed(1) ?? "Unknown"} meters',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Row(
                    children: [
                      const Text("Radius (m): "),
                      Expanded(
                        child: Slider(
                          value: radius.toDouble(),
                          min: 500,
                          max: 5000,
                          divisions: 9,
                          label: "$radius m",
                          onChanged: (v) => setState(() => radius = v.toInt()),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: pickMP3,
                        child: Text(
                          mp3Path == null ? "Pick MP3" : "MP3 Selected",
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            final alarm = AlarmModel(
                              destLat: selectedLocation!.latitude,
                              destLng: selectedLocation!.longitude,
                              radiusM: radius,
                              soundPath: mp3Path,
                              createdAt: DateTime.now().millisecondsSinceEpoch,
                            );
                            await _repo.addAlarm(alarm);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Alarm saved!")),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error saving alarm: $e"),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text("Save Alarm"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: AudioService.instance.isPlaying
          ? FloatingActionButton.extended(
              onPressed: _stopAlarm,
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.stop),
              label: const Text('STOP ALARM'),
            )
          : null,
    );
  }
}
