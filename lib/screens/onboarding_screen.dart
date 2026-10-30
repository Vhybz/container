import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
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
      videoAsset: 'assets/lottie/pharmacy.mp4',
    ),
    OnboardingData(
      title: 'Barbershop Operations',
      subtitle: 'APPOINTMENTS & STYLIST COMMISSIONS',
      description: 'Live client queues, grooming service catalogs, barber performance tracking, and automated commission calculations.',
      icon: Icons.content_cut_rounded,
      color: const Color(0xFFF59E0B),
      bgAsset: 'assets/images/bgi/shave.jpg',
      videoAsset: 'assets/lottie/barbershop.mp4',
    ),
    OnboardingData(
      title: 'Tech & Phone Shop',
      subtitle: 'IMEI TRACKING & WARRANTIES',
      description: 'Register device IMEI numbers, track phone repair work orders, manage accessories, and issue digital warranties.',
      icon: Icons.phone_android_rounded,
      color: const Color(0xFF2563EB),
      bgAsset: 'assets/images/bgi/ass.jpg',
      videoAsset: 'assets/lottie/smartphone.mp4',
    ),
    OnboardingData(
      title: 'Cross-Sector Analytics',
      subtitle: 'UNIFIED BUSINESS DOMINANCE',
      description: 'Real-time profit tracking, staff permissions, multi-branch management, and offline-first POS reliability.',
      icon: Icons.insights_rounded,
      color: const Color(0xFF4F46E5),
      bgAsset: 'assets/images/CLI.png',
      videoAsset: 'assets/lottie/data_analytics.mp4',
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
        child: SafeArea(
          child: Stack(
            children: [
              // 1. Content PageView
              PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) => setState(() => _currentPage = page),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPage(_pages[index], index == _currentPage, isSmall, size.height),
              ),

              // 2. Top Branding & Skip
              Positioned(
                top: 16,
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
                bottom: 24,
                left: 30,
                right: 30,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (index) => _buildDot(index)),
                    ),
                    const SizedBox(height: 20),
                    
                    // Action Button
                    Center(
                      child: SizedBox(
                        width: size.width > 480 ? 420 : double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage == _pages.length - 1) {
                              Navigator.pushReplacementNamed(context, '/login');
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 500), 
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
      ),
    );
  }

  Widget _buildPage(OnboardingData data, bool isActive, bool isSmall, double screenHeight) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24.0, 70.0, 24.0, 110.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Video Graphic from assets/lottie
              AnimatedScale(
                duration: const Duration(milliseconds: 800),
                scale: isActive ? 1.0 : 0.6,
                curve: Curves.elasticOut,
                child: SizedBox(
                  width: isSmall ? 130.0 : 160.0,
                  height: isSmall ? 130.0 : 160.0,
                  child: OnboardingVideoPlayer(
                    videoPath: data.videoAsset,
                    color: data.color,
                    icon: data.icon,
                    isSmall: isSmall,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              
              // Text Content
              AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: isActive ? 1.0 : 0.0,
                child: Column(
                  children: [
                    Text(
                      data.subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: data.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.oswald(
                        fontSize: isSmall ? 28 : 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      data.description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: isSmall ? 13 : 15,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

class OnboardingVideoPlayer extends StatefulWidget {
  final String videoPath;
  final Color color;
  final IconData icon;
  final bool isSmall;

  const OnboardingVideoPlayer({
    super.key,
    required this.videoPath,
    required this.color,
    required this.icon,
    this.isSmall = false,
  });

  @override
  State<OnboardingVideoPlayer> createState() => _OnboardingVideoPlayerState();
}

class _OnboardingVideoPlayerState extends State<OnboardingVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant OnboardingVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _controller?.dispose();
      _isInitialized = false;
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset(widget.videoPath);
      _controller = controller;
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0.0);
      await controller.play();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Onboarding video player error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.isSmall ? 130.0 : 160.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: widget.color.withValues(alpha: 0.35), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: _isInitialized && _controller != null && _controller!.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio > 0 ? _controller!.value.aspectRatio : 1.0,
                  child: VideoPlayer(_controller!),
                )
              : Center(
                  child: Icon(
                    widget.icon,
                    color: widget.color,
                    size: size * 0.45,
                  ),
                ),
        ),
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
  final String videoAsset;

  OnboardingData({
    required this.title, 
    required this.subtitle,
    required this.description, 
    required this.icon,
    required this.color,
    required this.bgAsset,
    required this.videoAsset,
  });
}
