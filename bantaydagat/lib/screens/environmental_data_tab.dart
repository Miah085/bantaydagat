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
  
  double _currentTemp = 0.0;
  double _feelsLike = 0.0;
  int _humidity = 0;
  double _windSpeed = 0.0;
  double _windDirDegrees = 0.0;
  double _rain = 0.0;
  int _weatherCode = 0;
  String _lastUpdated = "";

  List<dynamic> _forecastDates = [];
  List<dynamic> _forecastCodes = [];
  List<dynamic> _forecastMaxTemp = [];
  List<dynamic> _forecastMinTemp = [];
  List<dynamic> _forecastRain = [];

  @override
  void initState() {
    super.initState();
    _fetchOpenMeteoData();
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

    const String apiUrl = 
      "https://api.open-meteo.com/v1/forecast?latitude=14.3025&longitude=120.7617&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum&timezone=Asia%2FManila";

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
            _rain = current['precipitation'].toDouble();
            _weatherCode = current['weather_code'].toInt();
            _windSpeed = current['wind_speed_10m'].toDouble();
            _windDirDegrees = current['wind_direction_10m'].toDouble();
            _lastUpdated = DateFormat('h:mm:ss a').format(DateTime.now());

            final daily = data['daily'];
            _forecastDates = daily['time'].take(5).toList();
            _forecastCodes = daily['weather_code'].take(5).toList();
            _forecastMaxTemp = daily['temperature_2m_max'].take(5).toList();
            _forecastMinTemp = daily['temperature_2m_min'].take(5).toList();
            _forecastRain = daily['precipitation_sum'].take(5).toList();

            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        throw Exception("Failed to load weather data");
      }
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _isLoading = false; });
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
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF0F82A0)));
    if (_hasError) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.cloud_off, size: 48, color: Colors.grey), const SizedBox(height: 16), const Text("Unable to fetch weather data.", style: TextStyle(color: Colors.grey)), TextButton(onPressed: _fetchOpenMeteoData, child: const Text("Retry"))]));

    String condition = _getWeatherCondition(_weatherCode);
    String windDir = _getWindDirection(_windDirDegrees);
    
    bool isFavorable = _weatherCode < 61; 
    Color statusBgColor = isFavorable ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    Color statusBorderColor = isFavorable ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA);
    Color statusTextColor = isFavorable ? const Color(0xFF065F46) : const Color(0xFF991B1B);
    IconData statusIcon = isFavorable ? Icons.check_circle_outline : Icons.warning_amber_rounded;
    String statusTitle = isFavorable ? "Weather: Favorable for Turtle Release" : "Weather: Unfavorable for Release";

    return Container(
      color: const Color(0xFFF1F5F9), 
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Environmental Monitoring", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text("Real-time environmental data for sea turtle pre-release safety assessment.", style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: const Color(0xFF0284C7), borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_outlined, color: Colors.white, size: 16), SizedBox(width: 8), Text("Weather", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))])),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Icon(Icons.circle, size: 10, color: Color(0xFF0284C7)), const SizedBox(width: 8), Text("OPEN-METEO API", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.blueGrey.shade600))]),
                    const SizedBox(height: 4),
                    const Text("Current Conditions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const Text("Brgy. Labac, Naic, Cavite", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                InkWell(onTap: _fetchOpenMeteoData, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.refresh, size: 14, color: Color(0xFF64748B)), SizedBox(width: 6), Text("Refresh", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))])))
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: statusBgColor, border: Border.all(color: statusBorderColor), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusTextColor, size: 28), const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(statusTitle, style: TextStyle(fontWeight: FontWeight.bold, color: statusTextColor, fontSize: 15)), const SizedBox(height: 2), Text("$condition - Wind $_windSpeed km/h $windDir - Rain: $_rain mm", style: TextStyle(color: statusTextColor.withOpacity(0.8), fontSize: 13))])),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5, // Adjusted to give the boxes a bit more vertical height
              children: [
                _buildDataCard("Air Temperature", "$_currentTemp°C", "Feels like $_feelsLike°C", Icons.thermostat, const Color(0xFFEF4444)),
                _buildDataCard("Humidity", "$_humidity%", "Relative humidity at 2m", Icons.water_drop_outlined, const Color(0xFF3B82F6)),
                _buildDataCard("Wind Speed", "$_windSpeed km/h", "Direction: $windDir", Icons.air, const Color(0xFF0EA5E9)),
                _buildDataCard("Condition", condition, "Rain: $_rain mm", Icons.cloud_outlined, const Color(0xFF64748B)),
              ],
            ),
            const SizedBox(height: 32),
            const Text("5-Day Forecast", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, itemCount: _forecastDates.length,
                itemBuilder: (context, index) {
                  DateTime date = DateTime.parse(_forecastDates[index]);
                  return Container(
                    width: 140, margin: const EdgeInsets.only(right: 16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('EEE, MMM d').format(date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))), const SizedBox(height: 8),
                        Text(_getWeatherCondition(_forecastCodes[index]), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("${_forecastMaxTemp[index]}°", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444), fontSize: 14)), const SizedBox(width: 8), Text("${_forecastMinTemp[index]}°", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12))]), const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.umbrella_outlined, size: 12, color: Color(0xFF94A3B8)), const SizedBox(width: 4), Text("${_forecastRain[index]} mm", style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))])
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text("Source: open-meteo.com • Last updated: $_lastUpdated", style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // FIX APPLIED HERE: Added FittedBox to scale down text automatically
  Widget _buildDataCard(String title, String value, String subtext, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          const SizedBox(height: 4),
          Text(subtext, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}