import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui';

import '../config/sensor_constants.dart';

class EnvironmentalDataTab extends StatefulWidget {
  const EnvironmentalDataTab({super.key});

  @override
  State<EnvironmentalDataTab> createState() => _EnvironmentalDataTabState();
}

class _EnvironmentalDataTabState extends State<EnvironmentalDataTab> {
  bool _isWeatherLoading = true;
  bool _isDbLoading = true;
  bool _hasError = false;
  Timer? _timer;
  
  // Environment Background Sync
  String _bgImagePath = 'assets/images/bg_safe.jpg';
  StreamSubscription<DatabaseEvent>? _liveSubscription;
  final String databaseUrl = "https://bantaydagat-default-rtdb.firebaseio.com/";

  // Current Weather
  double _currentTemp = 0.0;
  double _feelsLike = 0.0;
  int _humidity = 0;
  double _windSpeed = 0.0;
  double _windDirDegrees = 0.0;
  int _weatherCode = 0;
  String _lastUpdated = "";

  // Forecast Data
  List<dynamic> _forecastDates = [];
  List<dynamic> _forecastCodes = [];
  List<dynamic> _forecastMaxTemp = [];
  List<dynamic> _forecastMinTemp = [];

  @override
  void initState() {
    super.initState();
    _setupRealtimeStream();
    _fetchOpenMeteoData();
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) => _fetchOpenMeteoData());
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // --- FETCH LIVE SENSOR DATA TO SYNC THE BACKGROUND ---
  void _setupRealtimeStream() {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: databaseUrl);
    
    _liveSubscription = db.ref('bantaydagat/latest').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        double airTemp = _parseDouble(data['airTemp']);
        double waterTemp = _parseDouble(data['waterTemp']);
        double humidity = _parseDouble(data['humidity']);
        double ph = _parseDouble(data['pH']);
        double turbidity = _parseDouble(data['turbidity']);

        String airStatus = SensorConstants.getStatus('airTemp', airTemp);
        String waterStatus = SensorConstants.getStatus('waterTemp', waterTemp);
        String humStatus = SensorConstants.getStatus('humidity', humidity);
        String phStatus = SensorConstants.getStatus('ph', ph);
        String turbStatus = SensorConstants.getStatus('turbidity', turbidity);

        Map<String, dynamic> assessment = SensorConstants.calculateOverallReleaseStatus([
          airStatus, waterStatus, humStatus, phStatus, turbStatus
        ]);
        
        Color statusColor = _getStrictStatusColor(assessment['status'].toString());
        
        if (statusColor == const Color(0xFFEF4444)) {
          _bgImagePath = 'assets/images/bg_danger.png';
        } else if (statusColor == const Color(0xFFF59E0B)) {
          _bgImagePath = 'assets/images/bg_caution.png';
        } else {
          _bgImagePath = 'assets/images/bg_safe.jpg';
        }

        setState(() {
          _isDbLoading = false;
        });
      }
    });
  }

  Color _getStrictStatusColor(String status) {
    String s = status.toUpperCase();
    if (s.contains('SAFE') || s == 'GO') return const Color(0xFF10B981); 
    if (s.contains('CAUTION') || s.contains('WARNING')) return const Color(0xFFF59E0B); 
    if (s.contains('DANGER') || s.contains('NO-GO')) return const Color(0xFFEF4444); 
    return const Color(0xFF94A3B8); 
  }

  // --- FETCH WEATHER DATA ---
  Future<void> _fetchOpenMeteoData() async {
    if (!mounted) return;
    setState(() => _isWeatherLoading = true);

    const String apiUrl = 
      "https://api.open-meteo.com/v1/forecast?latitude=14.3025&longitude=120.7617&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=Asia%2FManila";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (mounted) {
          setState(() {
            final current = data['current'];
            _currentTemp = current['temperature_2m'].toDouble();
            _humidity = current['relative_humidity_2m'].toInt();
            _feelsLike = current['apparent_temperature'].toDouble();
            _weatherCode = current['weather_code'].toInt();
            _windSpeed = current['wind_speed_10m'].toDouble();
            _windDirDegrees = current['wind_direction_10m'].toDouble();
            _lastUpdated = DateFormat('h:mm:ss a').format(DateTime.now());

            final daily = data['daily'];
            _forecastDates = daily['time'].take(5).toList();
            _forecastCodes = daily['weather_code'].take(5).toList();
            _forecastMaxTemp = daily['temperature_2m_max'].take(5).toList();
            _forecastMinTemp = daily['temperature_2m_min'].take(5).toList();

            _isWeatherLoading = false;
            _hasError = false;
          });
        }
      } else {
        throw Exception("Failed to load weather data");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isWeatherLoading = false;
        });
      }
    }
  }

  String _getWeatherCondition(int code) {
    switch(code) {
      case 0: return "Clear Sky";
      case 1: return "Mainly Clear";
      case 2: return "Partly Cloudy";
      case 3: return "Overcast";
      case 45: case 48: return "Fog";
      case 51: return "Light Drizzle";
      case 53: return "Moderate Drizzle";
      case 55: return "Dense Drizzle";
      case 61: return "Slight Rain";
      case 63: return "Moderate Rain";
      case 65: return "Heavy Rain";
      case 80: case 81: case 82: return "Rain Showers";
      case 95: case 96: case 99: return "Thunderstorm";
      default: return "Unknown";
    }
  }

  IconData _getWeatherIcon(int code) {
    switch(code) {
      case 0: case 1: return Icons.wb_sunny_outlined;
      case 2: return Icons.wb_cloudy_outlined;
      case 3: return Icons.cloud_outlined;
      case 45: case 48: return Icons.foggy;
      case 51: case 53: case 55: case 61: case 63: case 80: case 81: return Icons.water_drop_outlined;
      case 65: case 82: return Icons.tsunami_outlined;
      case 95: case 96: case 99: return Icons.thunderstorm_outlined;
      default: return Icons.cloud_outlined;
    }
  }

  String _getWindDirection(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) return 'N';
    if (degrees >= 22.5 && degrees < 67.5) return 'NE';
    if (degrees >= 67.5 && degrees < 112.5) return 'E';
    if (degrees >= 112.5 && degrees < 157.5) return 'SE';
    if (degrees >= 157.5 && degrees < 202.5) return 'S';
    if (degrees >= 202.5 && degrees < 247.5) return 'SW';
    if (degrees >= 247.5 && degrees < 292.5) return 'W';
    if (degrees >= 292.5 && degrees < 337.5) return 'NW';
    return '';
  }

  Widget _buildGlassCard({required Widget child, Color? borderColor, double borderWidth = 1.5}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55), 
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.2), 
              width: borderWidth
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFullyLoading = _isWeatherLoading || _isDbLoading;

    if (_hasError) {
      return Container(
        color: const Color(0xFF0F172A),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.white60),
              const SizedBox(height: 16),
              const Text("Unable to fetch atmospheric telemetry.", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  _fetchOpenMeteoData();
                  _setupRealtimeStream();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                child: const Text("Retry Connection"),
              )
            ],
          ),
        ),
      );
    }

    String condition = _getWeatherCondition(_weatherCode);
    String windDir = _getWindDirection(_windDirDegrees);
    
    // Banner based strictly on the API weather status
    bool isAtmosphereFavorable = _weatherCode < 61; 
    Color bannerColor = const Color(0xFF10B981); 
    String bannerTitle = "Atmosphere Favorable for Release";

    if (_weatherCode >= 65) {
      bannerColor = const Color(0xFFEF4444); 
      bannerTitle = "Severe Atmospheric Warning";
    } else if (_weatherCode >= 51 && _weatherCode < 65) {
      bannerColor = const Color(0xFFF59E0B); 
      bannerTitle = "Unstable Micro-Climate Warning";
    }

    IconData bannerIcon = isAtmosphereFavorable ? Icons.check_circle_outline : Icons.warning_amber_rounded;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        // THE FIX: Holds the dark background until BOTH weather and sensor data are ready
        image: isFullyLoading 
            ? null 
            : DecorationImage(
                image: AssetImage(_bgImagePath),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken),
              ),
      ),
      child: isFullyLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 120.0, 16.0, 120.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Eco Tracker", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))])),
                          const SizedBox(height: 4),
                          Text("Macro-environmental tracking.", style: TextStyle(fontSize: 14, color: Colors.white70, shadows: const [Shadow(color: Colors.black45, blurRadius: 6)])),
                        ],
                      ),
                      IconButton(
                        onPressed: () {
                          _fetchOpenMeteoData();
                          _setupRealtimeStream();
                        },
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        tooltip: "Refresh Weather",
                      )
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildGlassCard(
                    borderColor: bannerColor.withOpacity(0.6),
                    borderWidth: 2.0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(bannerIcon, color: bannerColor, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(bannerTitle, style: TextStyle(fontWeight: FontWeight.w900, color: bannerColor, fontSize: 14, letterSpacing: 0.3)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Text("Brgy. Labac, Naic, Cavite", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(_getWeatherIcon(_weatherCode), color: Colors.white, size: 68),
                              const SizedBox(width: 24),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${_currentTemp.toStringAsFixed(1)}°", style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1.0, shadows: [Shadow(color: Colors.black54, blurRadius: 6)])),
                                  const SizedBox(height: 2),
                                  Text(condition, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildHeroSubDetail(Icons.thermostat_outlined, "Feels Like", "${_feelsLike.toStringAsFixed(1)}°C"),
                                _buildHeroSubDetail(Icons.water_drop_outlined, "Humidity", "$_humidity%"),
                                _buildHeroSubDetail(Icons.air_outlined, "Wind Speed", "${_windSpeed.toStringAsFixed(1)} $windDir"),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text("5-Day Forecast", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 175,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: _forecastDates.length,
                      itemBuilder: (context, index) {
                        DateTime date = DateTime.parse(_forecastDates[index]);
                        String dayName = index == 0 ? "Today" : DateFormat('EEE, MMM d').format(date);
                        String fCond = _getWeatherCondition(_forecastCodes[index]);
                        IconData fIcon = _getWeatherIcon(_forecastCodes[index]);

                        return Container(
                          width: 135,
                          margin: const EdgeInsets.only(right: 14),
                          child: _buildGlassCard(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(dayName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: index == 0 ? const Color(0xFF3B82F6) : Colors.white70)),
                                  const SizedBox(height: 12),
                                  Icon(fIcon, color: Colors.white, size: 28),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("${_forecastMaxTemp[index].round()}°", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Text("${_forecastMinTemp[index].round()}°", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.5), fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(fCond, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  Center(child: Text("Source: Open-Meteo • Updated: $_lastUpdated", style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.bold))),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroSubDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}