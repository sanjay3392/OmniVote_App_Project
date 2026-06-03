import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../constants/app_constants.dart';
import 'auth/login_screen.dart';
import 'onboarding/onboarding_screen.dart';
import '../services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _controller.forward();
    
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    
    final storageService = await StorageService.init();
    final isFirstLaunch = storageService.isFirstLaunch();
    final user = storageService.getUser();
    
    if (isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else if (user == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildLogo(),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingXL),
              FadeIn(
                delay: const Duration(milliseconds: 800),
                child: Text(
                  AppConfig.appName,
                  style: AppTextStyles.h1.copyWith(
                    color: AppColors.textWhite,
                    fontSize: 36,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              FadeIn(
                delay: const Duration(milliseconds: 1000),
                child: Text(
                  AppStrings.welcomeSubtitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textWhite.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingXL * 2),
              FadeIn(
                delay: const Duration(milliseconds: 1200),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.textWhite),
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.textWhite,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.how_to_vote_rounded,
        size: AppDimensions.iconXL * 1.5,
        color: AppColors.primary,
      ),
    );
  }
}
