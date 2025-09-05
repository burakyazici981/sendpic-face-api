class AppConstants {
  // App Configuration
  static const String appName = 'SendPic';
  static const String appVersion = '1.0.0';
  
  // Database Configuration
  static const String databaseName = 'sendpic.db';
  static const int databaseVersion = 1;
  
  // Token System
  static const int tokensFor6Recipients = 1;
  static const int tokensFor10Recipients = 2;
  static const int tokensFor100Recipients = 10;
  static const int tokensFor1000Recipients = 50;
  
  // Content Limits
  static const int maxImageSizeMB = 10;
  static const int maxVideoSizeMB = 50;
  static const int maxVideoDurationSeconds = 60;
  
  // Storage Buckets
  static const String mediaBucket = 'media';
  static const String profileImagesBucket = 'profile-images';
  
  // Recipient Count Options
  static const List<int> recipientCountOptions = [6, 10, 100, 1000];
  
  // Default Values
  static const int defaultTokenAmount = 50;
  static const int minAge = 18;
  static const int maxAge = 100;
  
  // File Size Limits (in bytes)
  static const int maxImageSizeBytes = maxImageSizeMB * 1024 * 1024;
  static const int maxVideoSizeBytes = maxVideoSizeMB * 1024 * 1024;
  
  // Supported file extensions
  static const List<String> supportedImageExtensions = ['.jpg', '.jpeg', '.png', '.gif'];
  static const List<String> supportedVideoExtensions = ['.mp4', '.mov', '.avi'];
  
  // Session Keys
  static const String userSessionKey = 'current_user_session';
  static const String tokenBalanceKey = 'token_balance_cache';
}
