import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';

class EnvironmentalDataTab extends StatefulWidget {
  const EnvironmentalDataTab({super.key});

  @override
  State<EnvironmentalDataTab> createState() => _EnvironmentalDataTabState();
}

class _EnvironmentalDataTabState extends State<EnvironmentalDataTab> {
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _timer;
  
  // Current Weather
  double _currentTemp = 0.0;
  double _feelsLike = 0.0;
  int _humidity = 0;
  double _windSpeed = 0.0;
  double _windDirDegrees = 0.0;
  double _rain = 0.0;
  int _weatherCode = 0;
  String _lastUpdated = "";

  // New Solar Data
  double _uvIndex = 0.0;
  String _sunrise = "--:--";
  String _sunset = "--:--";

  // Forecast Data
  List<dynamic> _forecastDates = [];
  List<dynamic> _forecastCodes = [];
  List<dynamic> _forecastMaxTemp = [];
  List<dynamic> _forecastMinTemp = [];
  List<dynamic> _forecastRain = [];

  @override
  void initState() {
    super.initState();
    _fetchOpenMeteoData();
    // Refresh every 15 mins to respect Open-Meteo's free tier limits
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) => _fetchOpenMeteoData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOpenMeteoData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Upgraded API URL to include UV index, sunrise, and sunset
    const String apiUrl = 
      "https://api.open-meteo.com/v1/forecast?latitude=14.3025&longitude=120.7617&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,uv_index_max,sunrise,sunset&timezone=Asia%2FManila";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (mounted) {
          setState(() {
            // Parse Current
            final current = data['current'];
            _currentTemp = current['temperature_2m'].toDouble();
            _humidity = current['relative_humidity_2m'].toInt();
            _feelsLike = current['apparent_temperature'].toDouble();
            _rain = current['precipitation'].toDouble();
            _weatherCode = current['weather_code'].toInt();
            _windSpeed = current['wind_speed_10m'].toDouble();
            _windDirDegrees = current['wind_direction_10m'].toDouble();
            _lastUpdated = DateFormat('h:mm:ss a').format(DateTime.now());

            // Parse Daily (5 days & Solar)
            final daily = data['daily'];
            _forecastDates = daily['time'].take(5).toList();
            _forecastCodes = daily['weather_code'].take(5).toList();
            _forecastMaxTemp = daily['temperature_2m_max'].take(5).toList();
            _forecastMinTemp = daily['temperature_2m_min'].take(5).toList();
            _forecastRain = daily['precipitation_sum'].take(5).toList();
            
            _uvIndex = (daily['uv_index_max'][0] ?? 0.0).toDouble();
            _sunrise = DateFormat('h:mm a').format(DateTime.parse(daily['sunrise'][0]));
            _sunset = DateFormat('h:mm a').format(DateTime.parse(daily['sunset'][0]));

            _isLoading = false;
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
          _isLoading = false;
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
      case 0: case 1: return Icons.wb_sunny;
      case 2: return Icons.wb_cloudy_outlined;
      case 3: return Icons.cloud;
      case 45: case 48: return Icons.foggy;
      case 51: case 53: case 55: case 61: case 63: case 80: case 81: return Icons.water_drop;
      case 65: case 82: return Icons.storm;
      case 95: case 96: case 99: return Icons.thunderstorm;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F82A0)));
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Unable to fetch atmospheric data.", style: TextStyle(color: Colors.grey)),
            TextButton(onPressed: _fetchOpenMeteoData, child: const Text("Retry"))
          ],
        ),
      );
    }

    String condition = _getWeatherCondition(_weatherCode);
    String windDir = _getWindDirection(_windDirDegrees);
    
    // Dynamic Favorable/Warning Status based on weather codes
    bool isFavorable = _weatherCode < 61; // Favorable if it's not raining heavily/thunderstorming
    Color statusBgColor = isFavorable ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    Color statusBorderColor = isFavorable ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA);
    Color statusTextColor = isFavorable ? const Color(0xFF065F46) : const Color(0xFF991B1B);
    IconData statusIcon = isFavorable ? Icons.check_circle_outline : Icons.warning_amber_rounded;
    String statusTitle = isFavorable ? "Atmosphere Favorable for Release" : "Atmosphere Unfavorable for Release";

    return Container(
      color: const Color(0xFFF8FAFC), 
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header with Refresh Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Eco Data", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text("Macro-environmental tracking.", style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400)),
                  ],
                ),
                IconButton(
                  onPressed: _fetchOpenMeteoData,
                  icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
                  tooltip: "Refresh Weather",
                )
              ],
            ),
            const SizedBox(height: 24),

            // Dynamic Favorable Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: statusBgColor, border: Border.all(color: statusBorderColor), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusTextColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(statusTitle, style: TextStyle(fontWeight: FontWeight.bold, color: statusTextColor, fontSize: 14)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Beautiful Hero Weather Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F82A0), Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFF0284C7).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Column(
                children: [
                  const Text("Brgy. Labac, Naic, Cavite", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(_getWeatherIcon(_weatherCode), color: Colors.white, size: 64),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("$_currentTemp°", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1.1)),
                          Text(condition, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeroSubDetail(Icons.thermostat, "Feels Like", "$_feelsLike°C"),
                        _buildHeroSubDetail(Icons.water_drop_outlined, "Humidity", "$_humidity%"),
                        _buildHeroSubDetail(Icons.air, "Wind", "$_windSpeed $windDir"),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Secondary Stats Grid (UV, Rain, Sunrise, Sunset)
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              children: [
                _buildSecondaryCard("Max UV Index", "$_uvIndex", Icons.brightness_high, const Color(0xFFF59E0B)),
                _buildSecondaryCard("Precipitation", "$_rain mm", Icons.umbrella_outlined, const Color(0xFF3B82F6)),
                _buildSecondaryCard("Sunrise", _sunrise, Icons.wb_twilight, const Color(0xFFF97316)),
                _buildSecondaryCard("Sunset", _sunset, Icons.nights_stay_outlined, const Color(0xFF6366F1)),
              ],
            ),
            const SizedBox(height: 32),

            // 5-Day Forecast
            const Text("5-Day Forecast", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),

            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _forecastDates.length,
                itemBuilder: (context, index) {
                  DateTime date = DateTime.parse(_forecastDates[index]);
                  String dayName = index == 0 ? "Today" : DateFormat('EEE, MMM d').format(date);
                  String fCond = _getWeatherCondition(_forecastCodes[index]);
                  IconData fIcon = _getWeatherIcon(_forecastCodes[index]);

                  return Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(16), 
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dayName, style: TextStyle(fontSize: 13, fontWeight: index == 0 ? FontWeight.bold : FontWeight.w600, color: index == 0 ? const Color(0xFF0F82A0) : const Color(0xFF64748B))),
                        const SizedBox(height: 12),
                        Icon(fIcon, color: const Color(0xFF475569), size: 28),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("${_forecastMaxTemp[index]}°", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 16)),
                            const SizedBox(width: 8),
                            Text("${_forecastMinTemp[index]}°", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF94A3B8), fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(fCond, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            
            // Footer
            Center(child: Text("Source: Open-Meteo • Updated: $_lastUpdated", style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
            const SizedBox(height: 40),
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
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildSecondaryCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}