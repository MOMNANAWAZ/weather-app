import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/local_storage.dart';

class WeatherScreen extends StatefulWidget {
  @override
  _WeatherScreenState createState() => _WeatherScreenState();
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

  @override
  void initState() {
    super.initState();
    _loadLastCity();
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

  void _toggleDayNight() {
    setState(() {
      _isDayMode = !_isDayMode;
    });
  }

  Future<void> _fetchWeather(String city) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final currentWeatherData = await _weatherService.getCurrentWeather(city);
      final forecastData = await _weatherService.getForecast(city);

      setState(() {
        _currentWeather = WeatherData.fromJson(currentWeatherData);
        _forecast = _processForecastData(forecastData);
        _hasError = false;
      });

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
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Temperature display - NO grey circle background
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

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    int weekdayIndex = date.weekday % 7;
    int monthIndex = date.month - 1;

    return '${days[weekdayIndex]}, ${date.day} ${months[monthIndex]}';
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