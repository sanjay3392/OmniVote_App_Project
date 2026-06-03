import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../constants/app_constants.dart';
import '../auth/login_screen.dart';
import '../../services/storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.verified_user_rounded,
      title: 'Secure Voting',
      description: 'Your vote is protected by blockchain technology and biometric authentication',
      color: AppColors.primary,
    ),
    OnboardingPage(
      icon: Icons.visibility_rounded,
      title: 'Transparent Results',
      description: 'Track your vote on the blockchain and verify election results in real-time',
      color: AppColors.secondary,
    ),
    OnboardingPage(
      icon: Icons.speed_rounded,
      title: 'Instant Confirmation',
      description: 'Get immediate confirmation of your vote with a cryptographic receipt',
      color: AppColors.info,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _onGetStarted() async {
    final storageService = await StorageService.init();
    await storageService.setFirstLaunchComplete();
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], index);
                },
              ),
            ),
            _buildPageIndicator(),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Column(
                children: [
                  if (_currentPage == _pages.length - 1)
                    FadeInUp(
                      child: _buildButton(
                        'Get Started',
                        onPressed: _onGetStarted,
                      ),
                    )
                  else
                    FadeInUp(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _onGetStarted,
                            child: const Text(
                              'Skip',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          _buildButton(
                            'Next',
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, int index) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInDown(
            delay: Duration(milliseconds: 200 * index),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: page.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                page.icon,
                size: 100,
                color: page.color,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingXL * 2),
          FadeInUp(
            delay: Duration(milliseconds: 400 * index),
            child: Text(
              page.title,
              style: AppTextStyles.h1,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          FadeInUp(
            delay: Duration(milliseconds: 600 * index),
            child: Text(
              page.description,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppColors.primary
                : AppColors.textLight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(AppDimensions.radiusCircle),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, {VoidCallback? onPressed, bool compact = false}) {
    return SizedBox(
      width: compact ? null : double.infinity,
      height: AppDimensions.buttonHeightM,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppDimensions.paddingXL : 0,
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.button.copyWith(color: AppColors.textWhite),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
