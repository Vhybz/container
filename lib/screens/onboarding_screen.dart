import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Pharmacy Management',
      subtitle: 'PRESCRIPTIONS & EXPIRY CONTROL',
      description: 'Track medication batches, lot expiration alerts, patient prescription records, and instant OTC dispensing.',
      icon: Icons.local_pharmacy_rounded,
      color: const Color(0xFF10B981),
      bgAsset: 'assets/images/bgi/meds.jpg',
    ),
    OnboardingData(
      title: 'Barbershop Operations',
      subtitle: 'APPOINTMENTS & STYLIST COMMISSIONS',
      description: 'Live client queues, grooming service catalogs, barber performance tracking, and automated commission calculations.',
      icon: Icons.content_cut_rounded,
      color: const Color(0xFFF59E0B),
      bgAsset: 'assets/images/bgi/shave.jpg',
    ),
    OnboardingData(
      title: 'Tech & Phone Shop',
      subtitle: 'IMEI TRACKING & WARRANTIES',
      description: 'Register device IMEI numbers, track phone repair work orders, manage accessories, and issue digital warranties.',
      icon: Icons.phone_android_rounded,
      color: const Color(0xFF2563EB),
      bgAsset: 'assets/images/bgi/ass.jpg',
    ),
    OnboardingData(
      title: 'Cross-Sector Analytics',
      subtitle: 'UNIFIED BUSINESS DOMINANCE',
      description: 'Real-time profit tracking, staff permissions, multi-branch management, and offline-first POS reliability.',
      icon: Icons.insights_rounded,
      color: const Color(0xFF4F46E5),
      bgAsset: 'assets/images/CLI.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.primarySlate,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.splashAuthBackdrop,
        ),
        child: Stack(
          children: [
            // 1. Content PageView
            PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) => setState(() => _currentPage = page),
              itemCount: _pages.length,
              itemBuilder: (context, index) => _buildPage(_pages[index], index == _currentPage, isSmall),
            ),

            // 2. Top Branding & Skip
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'MULTI-BUSINESS MANAGER',
                        style: GoogleFonts.oswald(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: Text(
                      'SKIP',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Bottom Controls
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 40,
              left: 30,
              right: 30,
              child: Column(
                children: [
                  // Progress Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) => _buildDot(index)),
                  ),
                  SizedBox(height: isSmall ? 30 : 50),
                  
                  // Action Button
                  Center(
                    child: SizedBox(
                      width: size.width > 460 ? 400 : double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage == _pages.length - 1) {
                            Navigator.pushReplacementNamed(context, '/login');
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 600), 
                              curve: Curves.easeInOutQuart,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].color,
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shadowColor: _pages[_currentPage].color.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Row(
                            key: ValueKey(_currentPage),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1 ? 'GET STARTED' : 'CONTINUE',
                                style: GoogleFonts.oswald(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                _currentPage == _pages.length - 1 ? Icons.check_circle_outline : Icons.arrow_forward_ios_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildPage(OnboardingData data, bool isActive, bool isSmall) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Animated Icon/Graphic
          AnimatedScale(
            duration: const Duration(milliseconds: 1000),
            scale: isActive ? 1.0 : 0.4,
            curve: Curves.elasticOut,
            child: Container(
              padding: EdgeInsets.all(isSmall ? 25 : 35),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: data.color.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  if (isActive)
                    BoxShadow(
                      color: data.color.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Icon(data.icon, size: isSmall ? 60 : 80, color: data.color),
            ),
          ),
          SizedBox(height: isSmall ? 35 : 50),
          
          // Text Content
          AnimatedOpacity(
            duration: const Duration(milliseconds: 800),
            opacity: isActive ? 1.0 : 0.0,
            child: Column(
              children: [
                Text(
                  data.subtitle,
                  style: GoogleFonts.inter(
                    color: data.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.oswald(
                    fontSize: isSmall ? 32 : 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: isSmall ? 14 : 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmall ? 170 : 210), // Bottom padding for controls
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    bool isSelected = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: 8,
      width: isSelected ? 32 : 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isSelected ? _pages[_currentPage].color : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: _pages[_currentPage].color.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final String bgAsset;

  OnboardingData({
    required this.title, 
    required this.subtitle,
    required this.description, 
    required this.icon,
    required this.color,
    required this.bgAsset,
  });
}
