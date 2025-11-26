import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/local_storage.dart';
import 'dart:convert';

class WeatherScreen extends StatefulWidget {
  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

// Simple history item class - defined within the same file
class _WeatherHistoryItem {
  final String cityName;
  final double temperature;
  final String description;
  final String iconCode;
  final DateTime timestamp;

  _WeatherHistoryItem({
    required this.cityName,
    required this.temperature,
    required this.description,
    required this.iconCode,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'cityName': cityName,
      'temperature': temperature,
      'description': description,
      'iconCode': iconCode,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory _WeatherHistoryItem.fromJson(Map<String, dynamic> json) {
    return _WeatherHistoryItem(
      cityName: json['cityName'],
      temperature: json['temperature'].toDouble(),
      description: json['description'],
      iconCode: json['iconCode'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService('260648762a5c68e43154ca3104c8660f');
  final TextEditingController _searchController = TextEditingController();

  WeatherData? _currentWeather;
  List<ForecastData> _forecast = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _hasError = false;
  bool _isDayMode = true;
  List<_WeatherHistoryItem> _weatherHistory = [];
  bool _showHistory = false;

  // Storage keys
  static const String _weatherHistoryKey = 'weather_history';

  @override
  void initState() {
    super.initState();
    _loadLastCity();
    _loadWeatherHistory();
    final hour = DateTime.now().hour;
    _isDayMode = hour >= 6 && hour < 18;
  }

  Future<void> _loadLastCity() async {
    final lastCity = await LocalStorage.getLastCity();
    if (lastCity != null && lastCity.isNotEmpty) {
      _searchController.text = lastCity;
      _fetchWeather(lastCity);
    }
  }

  Future<void> _loadWeatherHistory() async {
    final prefs = await LocalStorage.getPrefs();
    final String? historyJson = prefs.getString(_weatherHistoryKey);

    if (historyJson == null) {
      return;
    }

    try {
      final List<dynamic> historyList = json.decode(historyJson);
      setState(() {
        _weatherHistory = historyList.map((item) => _WeatherHistoryItem.fromJson(item)).toList();
      });
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  Future<void> _saveWeatherHistory() async {
    final prefs = await LocalStorage.getPrefs();
    final String historyJson = json.encode(_weatherHistory.map((item) => item.toJson()).toList());
    await prefs.setString(_weatherHistoryKey, historyJson);
  }

  void _toggleDayNight() {
    setState(() {
      _isDayMode = !_isDayMode;
    });
  }

  void _toggleHistory() {
    setState(() {
      _showHistory = !_showHistory;
    });
  }

  Future<void> _fetchWeather(String city) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _showHistory = false;
    });

    try {
      final currentWeatherData = await _weatherService.getCurrentWeather(city);
      final forecastData = await _weatherService.getForecast(city);

      final weatherData = WeatherData.fromJson(currentWeatherData);
      final forecast = _processForecastData(forecastData);

      setState(() {
        _currentWeather = weatherData;
        _forecast = forecast;
        _hasError = false;
      });

      // Add to history
      final historyItem = _WeatherHistoryItem(
        cityName: city,
        temperature: weatherData.temperature,
        description: weatherData.description,
        iconCode: weatherData.iconCode,
        timestamp: DateTime.now(),
      );

      _addToHistory(historyItem);
      await LocalStorage.saveLastCity(city);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _currentWeather = null;
        _forecast = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addToHistory(_WeatherHistoryItem historyItem) {
    // Remove duplicates of the same city
    _weatherHistory.removeWhere((item) => item.cityName.toLowerCase() == historyItem.cityName.toLowerCase());

    // Add new item to beginning
    _weatherHistory.insert(0, historyItem);

    // Keep only last 15 items
    if (_weatherHistory.length > 15) {
      _weatherHistory.removeRange(15, _weatherHistory.length);
    }

    _saveWeatherHistory();
  }

  Future<void> _loadFromHistory(_WeatherHistoryItem historyItem) async {
    _searchController.text = historyItem.cityName;
    await _fetchWeather(historyItem.cityName);
  }

  Future<void> _clearHistory() async {
    final prefs = await LocalStorage.getPrefs();
    await prefs.remove(_weatherHistoryKey);
    setState(() {
      _weatherHistory.clear();
    });
  }

  List<ForecastData> _processForecastData(Map<String, dynamic> data) {
    List<ForecastData> forecast = [];
    final List<dynamic> list = data['list'];

    Map<String, List<ForecastData>> dailyData = {};

    for (var item in list) {
      final forecastItem = ForecastData.fromJson(item);
      final dateKey = '${forecastItem.date.year}-${forecastItem.date.month}-${forecastItem.date.day}';

      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = [];
      }
      dailyData[dateKey]!.add(forecastItem);
    }

    // Get only 5 days forecast
    List<String> dateKeys = dailyData.keys.toList();
    dateKeys.sort();

    int daysToTake = dateKeys.length > 5 ? 5 : dateKeys.length;

    for (int i = 0; i < daysToTake; i++) {
      String dateKey = dateKeys[i];
      List<ForecastData> dayForecasts = dailyData[dateKey]!;

      double minTemp = dayForecasts.first.minTemp;
      double maxTemp = dayForecasts.first.maxTemp;
      String description = dayForecasts.first.description;
      String iconCode = dayForecasts.first.iconCode;

      for (var day in dayForecasts) {
        if (day.minTemp < minTemp) minTemp = day.minTemp;
        if (day.maxTemp > maxTemp) maxTemp = day.maxTemp;
      }

      forecast.add(ForecastData(
        date: dayForecasts.first.date,
        minTemp: minTemp,
        maxTemp: maxTemp,
        description: description,
        iconCode: iconCode,
      ));
    }

    return forecast;
  }

  // Color schemes
  Color get _primaryColor => _isDayMode ? Color(0xFF1E88E5) : Color(0xFF0D47A1);
  Color get _backgroundColor => _isDayMode ? Colors.white : Color(0xFF121212);
  Color get _cardColor => _isDayMode ? Colors.white : Color(0xFF1E1E1E);
  Color get _textColor => _isDayMode ? Colors.black87 : Colors.white;
  Color get _secondaryTextColor => _isDayMode ? Colors.grey[600]! : Colors.grey[400]!;

  Widget _buildWeatherIcon(String iconCode) {
    return Image.network(
      'https://openweathermap.org/img/wn/$iconCode@2x.png',
      width: 80,
      height: 80,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.wb_sunny,
          size: 60,
          color: _isDayMode ? Colors.amber : Colors.yellow[100],
        );
      },
    );
  }

  Widget _buildCurrentWeather() {
    if (_currentWeather == null) return SizedBox();

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDayMode
              ? [Color(0xFF64B5F6), Color(0xFF1976D2)]
              : [Color(0xFF1A237E), Color(0xFF0D47A1)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _isDayMode ? Colors.blue.withOpacity(0.3) : Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentWeather!.cityName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatDate(DateTime.now()),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.history,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: _toggleHistory,
                  ),
                  IconButton(
                    icon: Icon(
                      _isDayMode ? Icons.nightlight_round : Icons.wb_sunny,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: _toggleDayNight,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      '${_currentWeather!.temperature.round()}°',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _currentWeather!.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 20),
              _buildWeatherIcon(_currentWeather!.iconCode),
            ],
          ),
          SizedBox(height: 30),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDetailItem('Humidity', '${_currentWeather!.humidity}%'),
                _buildDetailItem('Wind', '${_currentWeather!.windSpeed} km/h'),
                _buildDetailItem('Feels Like', '${_currentWeather!.temperature.round()}°'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildForecast() {
    if (_forecast.isEmpty) return SizedBox();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Text(
              '5-DAY FORECAST',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ),
          ..._forecast.map((forecast) => _buildForecastItem(forecast)),
        ],
      ),
    );
  }

  Widget _buildForecastItem(ForecastData forecast) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isDayMode ? Colors.grey.withOpacity(0.1) : Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _formatForecastDate(forecast.date),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
          ),
          Image.network(
            'https://openweathermap.org/img/wn/${forecast.iconCode}.png',
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.wb_sunny,
                size: 24,
                color: _isDayMode ? Colors.amber : Colors.yellow[100],
              );
            },
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              forecast.description,
              style: TextStyle(
                fontSize: 14,
                color: _secondaryTextColor,
              ),
            ),
          ),
          Text(
            '${forecast.maxTemp.round()}°',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${forecast.minTemp.round()}°',
            style: TextStyle(
              fontSize: 16,
              color: _secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryScreen() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              if (_weatherHistory.isNotEmpty)
                TextButton(
                  onPressed: _clearHistory,
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _weatherHistory.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: _secondaryTextColor),
                SizedBox(height: 20),
                Text(
                  'No search history',
                  style: TextStyle(
                    fontSize: 18,
                    color: _textColor,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Your searched cities will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: _secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _weatherHistory.length,
            itemBuilder: (context, index) {
              final historyItem = _weatherHistory[index];
              return _buildHistoryItem(historyItem);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(_WeatherHistoryItem historyItem) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isDayMode ? Colors.grey.withOpacity(0.1) : Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Image.network(
          'https://openweathermap.org/img/wn/${historyItem.iconCode}.png',
          width: 50,
          height: 50,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.wb_sunny,
              size: 30,
              color: _isDayMode ? Colors.amber : Colors.yellow[100],
            );
          },
        ),
        title: Text(
          historyItem.cityName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        subtitle: Text(
          '${historyItem.temperature.round()}° • ${historyItem.description}',
          style: TextStyle(
            color: _secondaryTextColor,
          ),
        ),
        trailing: Text(
          _formatTime(historyItem.timestamp),
          style: TextStyle(
            color: _secondaryTextColor,
            fontSize: 12,
          ),
        ),
        onTap: () => _loadFromHistory(historyItem),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    int weekdayIndex = date.weekday % 7;
    int monthIndex = date.month - 1;

    return '${days[weekdayIndex]}, ${date.day} ${months[monthIndex]}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatForecastDate(DateTime date) {
    if (date.day == DateTime.now().day) return 'Today';
    if (date.day == DateTime.now().add(Duration(days: 1)).day) return 'Tomorrow';

    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    int weekdayIndex = date.weekday % 7;

    return days[weekdayIndex];
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[400],
            ),
            SizedBox(height: 24),
            Text(
              'Unable to Load Weather',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _errorMessage.contains('City not found')
                  ? 'City not found. Please check spelling.'
                  : 'Check internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _secondaryTextColor,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _fetchWeather(_searchController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Weather Forecast'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: _isDayMode ? Colors.grey.withOpacity(0.1) : Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: _secondaryTextColor),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: _textColor, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search city...',
                        hintStyle: TextStyle(color: _secondaryTextColor),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _fetchWeather(value);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: _primaryColor),
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        _fetchWeather(_searchController.text);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: _primaryColor,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Getting weather...',
                      style: TextStyle(
                        fontSize: 16,
                        color: _textColor,
                      ),
                    ),
                  ],
                ),
              )
                  : _hasError
                  ? _buildErrorScreen()
                  : _showHistory
                  ? _buildHistoryScreen()
                  : (_currentWeather == null && _forecast.isEmpty)
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 80, color: _secondaryTextColor),
                    SizedBox(height: 20),
                    Text(
                      'Search for a City',
                      style: TextStyle(
                        fontSize: 20,
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextButton(
                      onPressed: _toggleHistory,
                      child: Text(
                        'View Search History',
                        style: TextStyle(
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCurrentWeather(),
                    SizedBox(height: 16),
                    _buildForecast(),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}