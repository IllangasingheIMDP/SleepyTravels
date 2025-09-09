import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:developer' as developer;
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
  final TextEditingController _radiusController = TextEditingController();
  bool _isPanelExpanded = true;
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

    // Listen to search focus changes to hide/show bottom panel
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild and hide/show the bottom panel
        });
      }
    });
  }

  double? _calculateDistanceToSelected() {
    if (currentLocation == null || selectedLocation == null) return null;
    return _distance.as(LengthUnit.Meter, currentLocation!, selectedLocation!);
  }

  void _onAudioStateChanged() {
    // Update UI when audio playing state changes
    developer.log(
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
      developer.log('Error searching location: $e');
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

  String _formatRadius(int meters) {
    if (meters >= 1000) {
      double km = meters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    } else {
      return '$meters m';
    }
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
                    'Alarm ${alarm.id}: ${alarm.destLat.toStringAsFixed(6)}, ${alarm.destLng.toStringAsFixed(6)} (${_formatRadius(alarm.radiusM)})',
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
    _radiusController.dispose();
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
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
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
      developer.log('Error getting current location: $e');
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
    const Color primaryGold = Color(0xFFF0CB46);
    const Color cardBackground = Color(0xFF001D3D);
    const Color navyBlue = Color(0xFF003566);

    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGold.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryGold.withValues(alpha: 0.2),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: primaryGold,
                  shape: BoxShape.circle,
                  border: Border.all(color: navyBlue, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGold.withValues(alpha: 0.5),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.person, color: navyBlue, size: 12),
              ),
              const SizedBox(width: 8),
              Text(
                currentLocation != null
                    ? 'Your location'
                    : 'Location unavailable',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (selectedLocation != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryGold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.location_on, color: primaryGold, size: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  'Alarm location',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
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

      developer.log(
        'MapScreen: Stopped alarm and deactivated ${activeAlarms.length} alarms',
      );
    } catch (e) {
      developer.log('Error stopping alarm: $e');
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
          developer.log(
            'AudioFile: Successfully saved $originalName to permanent location',
          );
        } else {
          throw Exception('Failed to save audio file to permanent location');
        }
      }
    } catch (e) {
      developer.log('Error picking MP3 file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting audio file: $e')),
        );
      }
    }
  }

  Widget _buildPermissionBanner() {
    if (currentPermission == null) return const SizedBox.shrink();

    const Color primaryGold = Color(0xFFF0CB46);

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
        color = Colors.orange.shade700;
        icon = Icons.location_off;
        onTap = () async {
          await PermissionService.instance.requestLocationPermission();
          _checkPermissionStatus();
        };
        break;
      case LocationPermission.deniedForever:
        message =
            "Location permission permanently denied. Tap to open settings.";
        color = Colors.red.shade700;
        icon = Icons.location_disabled;
        onTap = () => PermissionService.instance.openAppSettings();
        break;
      case LocationPermission.unableToDetermine:
        message = "Unable to determine location permission status";
        color = Colors.grey.shade700;
        icon = Icons.help_outline;
        onTap = null;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: primaryGold.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: primaryGold, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (onTap != null)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: primaryGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: primaryGold,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    const Color primaryGold = Color(0xFFF0CB46);
    const Color cardBackground = Color(0xFF001D3D);
    const Color surfaceColor = Color(0xFF003566);

    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGold.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryGold.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, letterSpacing: 0.5),
        decoration: InputDecoration(
          hintText: 'Search for a location...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.6),
            letterSpacing: 0.5,
          ),
          prefixIcon: const Icon(Icons.search, color: primaryGold, size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: primaryGold),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryGold, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!_showSearchResults) return const SizedBox.shrink();

    const Color primaryGold = Color(0xFFF0CB46);
    const Color cardBackground = Color(0xFF001D3D);
    const Color surfaceColor = Color(0xFF003566);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGold.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryGold.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: _isSearching
          ? Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryGold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Searching...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          : _searchResults.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Icon(
                    Icons.search_off,
                    color: primaryGold.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'No results found',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryGold.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryGold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: primaryGold,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      result.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    subtitle: Text(
                      result.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: primaryGold.withValues(alpha: 0.7),
                      size: 16,
                    ),
                    onTap: () => _selectSearchResult(result),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                      // Unfocus search field when tapping on map
                      _searchFocusNode.unfocus();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: 'com.example.sleepytravels_app',
                    ),
                    // Circle layer to show alarm radius
                    if (selectedLocation != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: selectedLocation!,
                            radius: radius.toDouble(),
                            useRadiusInMeter: true,
                            color: const Color(0xFFF0CB46).withOpacity(0.2),
                            borderColor: const Color(0xFFF0CB46),
                            borderStrokeWidth: 2,
                          ),
                        ],
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
          if (selectedLocation != null &&
              !_searchFocusNode.hasFocus &&
              !_showSearchResults)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: const Color(0xFF001D3D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF0CB46).withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF0CB46).withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Always show distance
                    if (currentLocation != null && selectedLocation != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        margin: const EdgeInsets.only(bottom: 8.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF001D3D).withOpacity(0.8),
                              const Color(0xFF003566).withOpacity(0.6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFF0CB46).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0CB46).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.straighten,
                                color: Color(0xFFF0CB46),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                'Distance: ${_calculateDistanceToSelected()?.toStringAsFixed(1) ?? "Unknown"} meters',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF0CB46),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // If panel is collapsed, show expand button
                    if (!_isPanelExpanded)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isPanelExpanded = true;
                            });
                          },
                          icon: const Icon(
                            Icons.expand_more,
                            color: Color(0xFFF0CB46),
                          ),
                          label: const Text(
                            "Expand",
                            style: TextStyle(
                              color: Color(0xFFF0CB46),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    // If expanded, show full controls
                    if (_isPanelExpanded)
                      Column(
                        children: [
                          // Collapse button at the top
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isPanelExpanded = false;
                                });
                              },
                              icon: const Icon(
                                Icons.expand_less,
                                color: Color(0xFFF0CB46),
                              ),
                              label: const Text(
                                "Collapse",
                                style: TextStyle(
                                  color: Color(0xFFF0CB46),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          // Custom radius input
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF003566),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFF0CB46).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.radio_button_checked,
                                      color: Color(0xFFF0CB46),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Alarm Radius: ${_formatRadius(radius)}",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFF0CB46),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _radiusController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: "Custom radius (m)",
                                          labelStyle: const TextStyle(
                                            color: Color(0xFFF0CB46),
                                          ),
                                          hintText: "Enter radius (min 100)",
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.6,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: const Color(
                                                0xFFF0CB46,
                                              ).withOpacity(0.3),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFF0CB46),
                                              width: 2,
                                            ),
                                          ),
                                          fillColor: const Color(0xFF001D3D),
                                          filled: true,
                                        ),
                                        onChanged: (value) {
                                          final parsed = int.tryParse(value);
                                          if (parsed != null && parsed >= 100) {
                                            setState(() => radius = parsed);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () {
                                        final parsed = int.tryParse(
                                          _radiusController.text,
                                        );
                                        if (parsed == null || parsed < 100) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Radius must be at least 100 meters!",
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        setState(() => radius = parsed);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFF0CB46,
                                        ),
                                        foregroundColor: const Color(
                                          0xFF001D3D,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text("Set"),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: const Color(0xFFF0CB46),
                                    inactiveTrackColor: const Color(
                                      0xFF003566,
                                    ).withOpacity(0.3),
                                    thumbColor: const Color(0xFFF0CB46),
                                    overlayColor: const Color(
                                      0xFFF0CB46,
                                    ).withOpacity(0.2),
                                    valueIndicatorColor: const Color(
                                      0xFF001D3D,
                                    ),
                                    valueIndicatorTextStyle: const TextStyle(
                                      color: Color(0xFFF0CB46),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  child: Slider(
                                    value: radius.toDouble(),
                                    min: 100,
                                    max: 5000,
                                    divisions: 49,
                                    label: _formatRadius(radius),
                                    onChanged: (v) =>
                                        setState(() => radius = v.toInt()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF0CB46),
                                        Color(0xFFCCA000),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFF0CB46,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: pickMP3,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: Icon(
                                      mp3Path == null
                                          ? Icons.audiotrack
                                          : Icons.check_circle,
                                      color: const Color(0xFF001D3D),
                                      size: 20,
                                    ),
                                    label: Text(
                                      mp3Path == null ? "Pick Audio" : "Tone",
                                      style: const TextStyle(
                                        color: Color(0xFF001D3D),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF001D3D),
                                        Color(0xFF003566),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF001D3D,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      if (radius < 100) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Radius must be at least 100 meters!",
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      try {
                                        final alarm = AlarmModel(
                                          destLat: selectedLocation!.latitude,
                                          destLng: selectedLocation!.longitude,
                                          radiusM: radius,
                                          soundPath: mp3Path,
                                          createdAt: DateTime.now()
                                              .millisecondsSinceEpoch,
                                        );
                                        await _repo.addAlarm(alarm);
                                        if (mounted) {
                                          setState(() {
                                            _isPanelExpanded = false;
                                            _radiusController.clear();
                                          });
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text("Alarm saved!"),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "Error saving alarm: $e",
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.save,
                                      color: Color(0xFFF0CB46),
                                      size: 20,
                                    ),
                                    label: const Text(
                                      "Save Alarm",
                                      style: TextStyle(
                                        color: Color(0xFFF0CB46),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: AudioService.instance.isPlaying
          ? FloatingActionButton.extended(
              onPressed: _stopAlarm,
              backgroundColor: Colors.red.shade700,
              foregroundColor: const Color(0xFFF0CB46),
              elevation: 12,
              icon: const Icon(Icons.stop, size: 24),
              label: const Text(
                'STOP ALARM',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 16,
                ),
              ),
            )
          : null,
    );
  }
}
