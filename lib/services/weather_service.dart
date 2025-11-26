import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String baseUrl = 'https://api.openweathermap.org/data/2.5';
  final String apiKey;

  WeatherService(this.apiKey);

  Future<Map<String, dynamic>> getCurrentWeather(String city) async {
    try {
      final response = await http.get(
          Uri.parse('$baseUrl/weather?q=$city&appid=$apiKey&units=metric')
      ).timeout(Duration(seconds: 10));

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('City not found');
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key');
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getCurrentWeather: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getForecast(String city) async {
    try {
      final response = await http.get(
          Uri.parse('$baseUrl/forecast?q=$city&appid=$apiKey&units=metric')
      ).timeout(Duration(seconds: 10));

      print('Forecast API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load forecast data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getForecast: $e');
      rethrow;
    }
  }
}