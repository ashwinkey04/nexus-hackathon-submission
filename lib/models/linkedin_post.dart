class LinkedInPost {
  final String url;
  final String userId;
  final String title;
  final String headline;
  final String postText;
  final String postTextHtml;
  final List<String> hashtags;

  LinkedInPost({
    required this.url,
    required this.userId,
    required this.title,
    required this.headline,
    required this.postText,
    required this.postTextHtml,
    required this.hashtags,
  });

  factory LinkedInPost.fromJson(Map<String, dynamic> json) {
    return LinkedInPost(
      url: json['url'] ?? '',
      userId: json['user_id'] ?? '',
      title: json['title'] ?? '',
      headline: json['headline'] ?? '',
      postText: json['post_text'] ?? '',
      postTextHtml: json['post_text_html'] ?? '',
      hashtags: List<String>.from(json['hashtags'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'user_id': userId,
      'title': title,
      'headline': headline,
      'post_text': postText,
      'post_text_html': postTextHtml,
      'hashtags': hashtags,
    };
  }

  /// Convert post to searchable text content for RAG
  String toSearchableContent() {
    final buffer = StringBuffer();
    buffer.writeln('Title: $title');
    buffer.writeln('Headline: $headline');
    buffer.writeln('\n$postText');
    if (hashtags.isNotEmpty) {
      buffer.writeln('\nHashtags: ${hashtags.join(', ')}');
    }
    return buffer.toString();
  }

  /// Get a short display name for the document
  String get displayName {
    // Extract a short title from the URL or title
    final shortTitle = title.length > 50 ? '${title.substring(0, 47)}...' : title;
    return 'LinkedIn: $shortTitle';
  }
}

