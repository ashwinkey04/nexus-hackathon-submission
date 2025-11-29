import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/linkedin_post.dart';

class DemoDataService {
  static const String apiUrl =
      'https://signalai-api.atlasprods.com/api/posts/list?limit=5&profileId=cmh7e6cyv000kw0odk3ug7ha3&activeOnly=true';

  /// Fetch demo LinkedIn posts from the API
  Future<List<LinkedInPost>> fetchDemoData() async {
    debugPrint('[DemoDataService] Starting to fetch demo data from API...');
    debugPrint('[DemoDataService] API URL: $apiUrl');
    
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.get(Uri.parse(apiUrl));
      stopwatch.stop();
      
      debugPrint('[DemoDataService] API response received in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[DemoDataService] Response status code: ${response.statusCode}');
      debugPrint('[DemoDataService] Response body length: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final posts = jsonList.map((json) => LinkedInPost.fromJson(json)).toList();
        
        debugPrint('[DemoDataService] Successfully parsed ${posts.length} LinkedIn posts');
        for (int i = 0; i < posts.length; i++) {
          debugPrint('[DemoDataService] Post ${i + 1}: ${posts[i].title}');
          debugPrint('[DemoDataService]   - URL: ${posts[i].url}');
          debugPrint('[DemoDataService]   - Content length: ${posts[i].postText.length} chars');
        }
        
        return posts;
      } else {
        debugPrint('[DemoDataService] ERROR: Failed to load demo data. Status code: ${response.statusCode}');
        debugPrint('[DemoDataService] Response body: ${response.body}');
        throw Exception('Failed to load demo data: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('[DemoDataService] ERROR: Exception while fetching demo data: $e');
      debugPrint('[DemoDataService] Stack trace: $stackTrace');
      throw Exception('Error fetching demo data: $e');
    }
  }
}

