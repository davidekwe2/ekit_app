import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../themes/colors.dart';
import '../models/ranking.dart';
import '../services/ranking_service.dart';
import 'user_profile_page.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> with SingleTickerProviderStateMixin {
  List<UserRanking> _topUsers = [];
  UserRanking? _userRanking;
  bool _isLoading = false;
  int _totalUsers = 0;
  late TabController _tabController;
  int _selectedTab = 0; // 0 = Daily, 1 = Weekly, 2 = Overall

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _selectedTab) {
        setState(() {
          _selectedTab = _tabController.index;
        });
        _loadRankings();
      }
    });
    _loadRankings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh rankings when page becomes visible (e.g., when navigating back)
    _loadRankings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRankings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<UserRanking> topUsers;
      UserRanking? userRanking;

      if (_selectedTab == 0) {
        // Daily
        debugPrint('Loading daily rankings...');
        topUsers = await RankingService.getTopDailyRankedUsers(limit: 100);
        userRanking = await RankingService.getDailyRanking();
      } else if (_selectedTab == 1) {
        // Weekly
        debugPrint('Loading weekly rankings...');
        topUsers = await RankingService.getTopWeeklyRankedUsers(limit: 100);
        userRanking = await RankingService.getWeeklyRanking();
      } else {
        // Overall
        debugPrint('Loading overall rankings...');
        topUsers = await RankingService.getTopOverallRankedUsers(limit: 100);
        userRanking = await RankingService.getOverallRanking();
      }
      
      debugPrint('Loaded ${topUsers.length} users in rankings');
      debugPrint('User ranking: ${userRanking?.rank ?? "not found"}');
      
      if (mounted) {
        setState(() {
          _topUsers = topUsers;
          _userRanking = userRanking;
          _totalUsers = topUsers.length;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading rankings: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final cardColor = theme.cardColor;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Leaderboard',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: textColor.withOpacity(0.6),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Overall'),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : _topUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 80,
                          color: textColor.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No rankings yet',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Take some quizzes to appear on the leaderboard!',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: textColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User's ranking card (if they're ranked)
                      if (_userRanking != null && _userRanking!.totalQuizzes > 0)
                        _buildUserRankingCard(_userRanking!, textColor, cardColor, isDark),
                      if (_userRanking != null && _userRanking!.totalQuizzes > 0)
                        const SizedBox(height: 24),

                      // Top Rankings Header
                      Row(
                        children: [
                          Icon(Icons.emoji_events, color: AppColors.accent2, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            _selectedTab == 0 ? 'Top Rankings (Today)' :
                            _selectedTab == 1 ? 'Top Rankings (This Week)' :
                            'Top Rankings (Overall)',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Top 3 podium
                      if (_topUsers.length >= 3)
                        _buildPodium(_topUsers.take(3).toList(), textColor, cardColor, currentUserId),
                      if (_topUsers.length >= 3) const SizedBox(height: 24),

                      // Rest of rankings
                      ..._topUsers.asMap().entries.map((entry) {
                        final index = entry.key;
                          final user = entry.value;
                          final isCurrentUser = user.userId == currentUserId;

                          // Skip top 3 if podium is shown
                          if (_topUsers.length >= 3 && index < 3) {
                            return const SizedBox.shrink();
                          }

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfilePage(userId: user.userId),
                                ),
                              );
                            },
                            child: _buildRankingCard(
                              user,
                              index + 1,
                              textColor,
                              cardColor,
                              isDark,
                              isCurrentUser,
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
    );
  }

  Widget _buildUserRankingCard(UserRanking ranking, Color textColor, Color cardColor, bool isDark) {
    final rankCategory = RankingService.getRankCategory(ranking, _totalUsers);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Your Ranking',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rankCategory,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rank #${ranking.rank}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${ranking.totalCorrectAnswers}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Correct',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${ranking.totalQuizzes}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Quizzes',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(List<UserRanking> top3, Color textColor, Color cardColor, String? currentUserId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd place
        Expanded(
          child: Column(
            children: [
              _buildPodiumUser(top3[1], 2, textColor, cardColor, currentUserId),
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.accent.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: Text(
                    '2',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // 1st place
        Expanded(
          child: Column(
            children: [
              _buildPodiumUser(top3[0], 1, textColor, cardColor, currentUserId),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accent2, AppColors.accent2.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        '1',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // 3rd place
        Expanded(
          child: Column(
            children: [
              _buildPodiumUser(top3[2], 3, textColor, cardColor, currentUserId),
              Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: Text(
                    '3',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumUser(UserRanking user, int position, Color textColor, Color cardColor, String? currentUserId) {
    final isCurrentUser = user.userId == currentUserId;
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(userId: user.userId),
          ),
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.primary.withOpacity(0.2) : cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          ClipOval(
            child: user.photoURL != null
                ? Image.network(
                    user.photoURL!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 50,
                        height: 50,
                        color: AppColors.primary.withOpacity(0.2),
                        child: Icon(Icons.person, color: AppColors.primary),
                      );
                    },
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: AppColors.primary.withOpacity(0.2),
                    child: Icon(Icons.person, color: AppColors.primary),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            user.displayName ?? 'User',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${user.totalCorrectAnswers} correct',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildRankingCard(
    UserRanking user,
    int rank,
    Color textColor,
    Color cardColor,
    bool isDark,
    bool isCurrentUser,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.primary.withOpacity(0.15) : cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank number
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _getRankColor(rank).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: _getRankColor(rank),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getRankColor(rank),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // User avatar
          ClipOval(
            child: user.photoURL != null
                ? Image.network(
                    user.photoURL!,
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 45,
                        height: 45,
                        color: AppColors.primary.withOpacity(0.2),
                        child: Icon(Icons.person, color: AppColors.primary, size: 24),
                      );
                    },
                  )
                : Container(
                    width: 45,
                    height: 45,
                    color: AppColors.primary.withOpacity(0.2),
                    child: Icon(Icons.person, color: AppColors.primary, size: 24),
                  ),
          ),
          const SizedBox(width: 12),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName ?? 'User',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'You',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.quiz, size: 12, color: textColor.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${user.totalQuizzes} quizzes',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: textColor.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, size: 12, color: AppColors.success.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${user.totalCorrectAnswers} correct',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: textColor.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Score badge
          Container(
            constraints: const BoxConstraints(minWidth: 50),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_getRankColor(rank), _getRankColor(rank).withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${user.averageScore.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'avg',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return AppColors.accent2; // Gold
    if (rank == 2) return AppColors.accent; // Silver
    if (rank == 3) return AppColors.primary; // Bronze
    return AppColors.primary.withOpacity(0.7);
  }
}

