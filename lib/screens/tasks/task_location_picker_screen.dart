// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/widgets/maps/advanced_web_map.dart';
import 'package:order_tracker/utils/web_platform.dart' as web_platform;

class TaskLocationPickerResult {
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? district;
  final String? street;
  final String? postalCode;

  TaskLocationPickerResult({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.district,
    this.street,
    this.postalCode,
  });
}

class TaskLocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const TaskLocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
  });

  @override
  State<TaskLocationPickerScreen> createState() =>
      _TaskLocationPickerScreenState();
}

class _SearchResult {
  final double latitude;
  final double longitude;
  final String name;

  const _SearchResult({
    required this.latitude,
    required this.longitude,
    required this.name,
  });
}

class _TaskLocationPickerScreenState extends State<TaskLocationPickerScreen> {
  late LatLng _selected;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  bool _searching = false;
  List<_SearchResult> _searchResults = const [];
  bool _webMapsReady = true;

  @override
  void initState() {
    super.initState();
    final hasInitial = widget.initialLat != null && widget.initialLng != null;
    final lat = widget.initialLat ?? 24.7136;
    final lng = widget.initialLng ?? 46.6753;
    _selected = LatLng(lat, lng);
    final initialAddress = widget.initialAddress?.trim();
    _addressController.text =
        (initialAddress != null && initialAddress.isNotEmpty)
        ? initialAddress
        : 'الرياض';
    if (!hasInitial) {
      _loadCurrentLocation();
    }
    if (kIsWeb) {
      _webMapsReady = false;
      _checkWebMapsReady();
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _streetController.dispose();
    _postalCodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkWebMapsReady() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final mapsLoaded = web_platform.isGoogleMapsReady();
    if (!mounted) return;
    setState(() => _webMapsReady = mapsLoaded);
  }

  Future<void> _loadCurrentLocation() async {
    final position = await _determinePosition();
    if (position == null || !mounted) return;
    _selectLocation(LatLng(position.latitude, position.longitude));
  }

  Future<Position?> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'order-tracker-app'},
      );
      if (response.statusCode != 200) return;
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is! Map) return;
      final address = data['address'];
      if (address is! Map) return;

      final city =
          address['city'] ??
          address['town'] ??
          address['village'] ??
          address['state'] ??
          '';
      final district =
          address['suburb'] ??
          address['neighbourhood'] ??
          address['city_district'] ??
          '';
      final street =
          address['road'] ?? address['street'] ?? address['residential'] ?? '';
      final postalCode = address['postcode'] ?? '';
      final displayName = data['display_name']?.toString() ?? '';

      if (!mounted) return;
      setState(() {
        if (displayName.isNotEmpty) {
          _addressController.text = displayName;
        }
        _cityController.text = city.toString();
        _districtController.text = district.toString();
        _streetController.text = street.toString();
        _postalCodeController.text = postalCode.toString();
      });
    } catch (_) {}
  }

  Future<void> _searchOnMap() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();

    // دعم إدخال الإحداثيات مباشرة
    final latLng = _parseLatLng(query);
    if (latLng != null) {
      _selectLocation(latLng);
      return;
    }

    setState(() {
      _searching = true;
      _searchResults = const [];
    });
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'order-tracker-app'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List && data.isNotEmpty) {
          final results = <_SearchResult>[];
          for (final item in data) {
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            if (lat == null || lon == null) continue;
            final name = item['display_name']?.toString() ?? '';
            results.add(
              _SearchResult(latitude: lat, longitude: lon, name: name),
            );
          }

          if (results.isNotEmpty) {
            if (mounted) {
              setState(() => _searchResults = results);
            }
            final first = results.first;
            _updateSelection(
              LatLng(first.latitude, first.longitude),
              clearResults: false,
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  LatLng? _parseLatLng(String input) {
    final parts = input.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _updateSelection(LatLng pos, {bool clearResults = true}) {
    setState(() {
      _selected = pos;
      if (clearResults) _searchResults = const [];
    });
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 14)),
    );
  }

  void _selectLocation(LatLng pos, {String? addressHint}) {
    _updateSelection(pos, clearResults: true);
    if (addressHint != null && addressHint.trim().isNotEmpty) {
      _addressController.text = addressHint;
    }
    _reverseGeocode(pos);
  }

  Widget _buildMap() {
    if (kIsWeb) {
      if (!_webMapsReady) return _buildWebMapsError();
      return AdvancedWebMap(
        center: _selected,
        zoom: 13,
        primaryMarker: _selected,
        onTap: (pos) => _selectLocation(pos),
      );
    }
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _selected, zoom: 13),
      markers: {Marker(markerId: const MarkerId('task'), position: _selected)},
      onMapCreated: (controller) => _mapController = controller,
      onTap: (pos) => _selectLocation(pos),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'ابحث عن موقع أو أدخل (lat,lng)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = const []);
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchOnMap(),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        _searching
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                onPressed: _searchOnMap,
                icon: const Icon(Icons.search),
              ),
      ],
    );
  }

  Widget _buildSearchResultsBox(BuildContext context, double height) {
    if (_searchResults.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: SizedBox(
        height: height,
        child: ListView.separated(
          itemCount: _searchResults.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final result = _searchResults[index];
            return ListTile(
              title: Text(
                result.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}',
              ),
              onTap: () {
                _selectLocation(
                  LatLng(result.latitude, result.longitude),
                  addressHint: result.name,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الإحداثيات: ${_selected.latitude}, ${_selected.longitude}'),
        const SizedBox(height: 8),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'عنوان الموقع (اختياري)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cityController,
          decoration: const InputDecoration(labelText: 'المدينة (اختياري)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _districtController,
          decoration: const InputDecoration(labelText: 'الحي (اختياري)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _streetController,
          decoration: const InputDecoration(labelText: 'الشارع (اختياري)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _postalCodeController,
          decoration: const InputDecoration(
            labelText: 'الرمز البريدي (اختياري)',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                TaskLocationPickerResult(
                  latitude: _selected.latitude,
                  longitude: _selected.longitude,
                  address: _addressController.text.trim().isEmpty
                      ? null
                      : _addressController.text.trim(),
                  city: _cityController.text.trim().isEmpty
                      ? null
                      : _cityController.text.trim(),
                  district: _districtController.text.trim().isEmpty
                      ? null
                      : _districtController.text.trim(),
                  street: _streetController.text.trim().isEmpty
                      ? null
                      : _streetController.text.trim(),
                  postalCode: _postalCodeController.text.trim().isEmpty
                      ? null
                      : _postalCodeController.text.trim(),
                ),
              );
            },
            child: const Text('تأكيد الموقع'),
          ),
        ),
      ],
    );
  }

  Widget _buildMapCard(BuildContext context, Widget child) {
    final radius = BorderRadius.circular(18);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد الموقع على الخريطة'),
        centerTitle: true,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final resultsHeight = isWide ? 220.0 : 160.0;
          final inputTheme = theme.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.4,
              ),
            ),
          );

          final mapWidget = _buildMapCard(context, _buildMap());

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF6F8FF), Color(0xFFF3FBF7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Theme(
                data: theme.copyWith(
                  inputDecorationTheme: inputTheme,
                  elevatedButtonTheme: ElevatedButtonThemeData(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                child: isWide
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(child: mapWidget),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 380,
                              child: Card(
                                elevation: 4,
                                shadowColor: Colors.black12,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildSearchBar(),
                                        const SizedBox(height: 12),
                                        _buildSearchResultsBox(
                                          context,
                                          resultsHeight,
                                        ),
                                        if (_searchResults.isNotEmpty)
                                          const SizedBox(height: 12),
                                        _buildInfoPanel(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: _buildSearchBar(),
                          ),
                          if (_searchResults.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                              child: _buildSearchResultsBox(
                                context,
                                resultsHeight,
                              ),
                            ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                              child: mapWidget,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: _buildInfoPanel(),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWebMapsError() {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF2F3F5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 48, color: Colors.black38),
          const SizedBox(height: 12),
          const Text(
            'تعذّر تحميل Google Maps على الويب',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'تحقق من Console للمتصفح. الأسباب الشائعة: مفتاح غير مفعّل، القيود (Referer)، أو Billing غير مفعّل.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _checkWebMapsReady,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
