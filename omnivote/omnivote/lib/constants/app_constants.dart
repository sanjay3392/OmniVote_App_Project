import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5548E8);
  static const Color primaryLight = Color(0xFF8B85FF);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF00D4AA);
  static const Color secondaryDark = Color(0xFF00B894);
  static const Color secondaryLight = Color(0xFF00F5C4);
  
  // Neutral Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color textLight = Color(0xFF95A5A6);
  static const Color textWhite = Color(0xFFFFFFFF);
  
  // Status Colors
  static const Color success = Color(0xFF00D4AA);
  static const Color error = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFFA502);
  static const Color info = Color(0xFF3498DB);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryLight],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8F9FA), Color(0xFFE8EAED)],
  );
}

class AppTextStyles {
  static const String fontFamily = 'Inter';
  
  // Heading Styles
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle h4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  // Body Styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight,
    height: 1.3,
  );
  
  // Button Styles
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static var heading3;
}

class AppDimensions {
  // Padding
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  
  // Border Radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusCircle = 999.0;
  
  // Icon Sizes
  static const double iconS = 16.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;
  
  // Button Heights
  static const double buttonHeightS = 40.0;
  static const double buttonHeightM = 48.0;
  static const double buttonHeightL = 56.0;
}

class AppConfig {
  static const String appName = 'OmniVote';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@omnivote.io';
  
  // API Configuration (Placeholder for backend)
  static const String baseUrl = 'https://api.omnivote.io';
  static const String solanaRpcUrl = 'https://api.mainnet-beta.solana.com';
  
  // Biometric Configuration
  static const int maxBiometricAttempts = 3;
  static const Duration biometricTimeout = Duration(seconds: 30);
  
  // Transaction Configuration
  static const int transactionConfirmationBlocks = 3;
  static const Duration transactionTimeout = Duration(minutes: 2);
}

class AppStrings {
  // Authentication
  static const String welcomeTitle = 'Welcome to OmniVote';
  static const String welcomeSubtitle = 'Secure, Transparent Democracy on Mobile';
  static const String biometricPrompt = 'Authenticate to continue';
  static const String biometricReason = 'Please authenticate to access your voting account';
  
  // Voting
  static const String castVote = 'Cast Your Vote';
  static const String confirmVote = 'Confirm Vote';
  static const String voteSuccess = 'Vote Successfully Cast!';
  static const String voteReceipt = 'Vote Receipt';
  
  // Errors
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorBiometric = 'Biometric authentication failed';
  static const String errorNetwork = 'Network connection error';
  static const String errorTransaction = 'Transaction failed';
  
  // Buttons
  static const String buttonLogin = 'Login with Biometric';
  static const String buttonRegister = 'Create Account';
  static const String buttonVerify = 'Verify Vote';
  static const String buttonContinue = 'Continue';
  static const String buttonCancel = 'Cancel';
}
