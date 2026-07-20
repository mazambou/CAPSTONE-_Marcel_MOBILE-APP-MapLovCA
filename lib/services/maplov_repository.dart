import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';
import '../data/mock_data.dart';
import '../models/user_profile.dart';

class DiscoveryFilters {
  const DiscoveryFilters({
    this.minimumAge = 18,
    this.maximumAge = 80,
    this.distanceKm = 50,
    this.locationMode = 'near_me',
    this.countries = const [],
    this.cities = const [],
    this.originCountries = const [],
    this.originCities = const [],
    this.languages = const [],
    this.relationshipGoals = const [],
    this.verifiedOnly = false,
    this.activeTodayOnly = false,
    this.genders = const [],
    this.personalities = const [],
    this.interestSlugs = const [],
    this.religions = const [],
    this.bodyTypes = const [],
    this.eyeColors = const [],
    this.hairColors = const [],
    this.minimumHeightCm,
    this.maximumHeightCm,
    this.childrenPreferences = const [],
    this.relationshipStatuses = const [],
    this.educationLevels = const [],
    this.beardStyles = const [],
    this.smokingStatuses = const [],
    this.professionCategories = const [],
    this.incomeLevels = const [],
    this.photoVerifiedOnly = false,
    this.interestImportance = 1,
    this.requiredGenders = false,
    this.requiredLocation = false,
    this.requiredLanguages = false,
    this.requiredRelationshipGoal = false,
  });

  final int minimumAge;
  final int maximumAge;
  final int distanceKm;
  final String locationMode;
  final List<String> countries;
  final List<String> cities;
  final List<String> originCountries;
  final List<String> originCities;
  final List<String> languages;
  final List<String> relationshipGoals;
  final bool verifiedOnly;
  final bool activeTodayOnly;
  final List<String> genders;
  final List<String> personalities;
  final List<String> interestSlugs;
  final List<String> religions;
  final List<String> bodyTypes;
  final List<String> eyeColors;
  final List<String> hairColors;
  final int? minimumHeightCm;
  final int? maximumHeightCm;
  final List<String> childrenPreferences;
  final List<String> relationshipStatuses;
  final List<String> educationLevels;
  final List<String> beardStyles;
  final List<String> smokingStatuses;
  final List<String> professionCategories;
  final List<String> incomeLevels;
  final bool photoVerifiedOnly;
  final int interestImportance;
  final bool requiredGenders;
  final bool requiredLocation;
  final bool requiredLanguages;
  final bool requiredRelationshipGoal;

  Map<String, Object?> toDatabase() => {
    'minimum_age': minimumAge,
    'maximum_age': maximumAge,
    'distance_km': distanceKm,
    'location_mode': locationMode,
    'country_codes': countries,
    'cities': cities,
    'origin_country_names': originCountries,
    'origin_cities': originCities,
    'languages': languages,
    'relationship_goals': relationshipGoals,
    'verified_only': verifiedOnly,
    'active_today_only': activeTodayOnly,
    'genders': genders,
    'personalities': personalities,
    'interest_slugs': interestSlugs,
    'religions': religions,
    'body_types': bodyTypes,
    'eye_colors': eyeColors,
    'hair_colors': hairColors,
    'minimum_height_cm': minimumHeightCm,
    'maximum_height_cm': maximumHeightCm,
    'children_preferences': childrenPreferences,
    'relationship_statuses': relationshipStatuses,
    'education_levels': educationLevels,
    'beard_styles': beardStyles,
    'smoking_statuses': smokingStatuses,
    'profession_categories': professionCategories,
    'income_levels': incomeLevels,
    'photo_verified_only': photoVerifiedOnly,
    'interest_importance': interestImportance,
    'required_genders': requiredGenders,
    'required_location': requiredLocation,
    'required_languages': requiredLanguages,
    'required_relationship_goal': requiredRelationshipGoal,
  };

  factory DiscoveryFilters.fromDatabase(Map<String, dynamic> row) {
    final minimumAge = (row['minimum_age'] as int? ?? 18).clamp(18, 80);
    final rawMaximumAge = (row['maximum_age'] as int? ?? 80).clamp(18, 80);
    final maximumAge = rawMaximumAge < minimumAge ? minimumAge : rawMaximumAge;
    return DiscoveryFilters(
      minimumAge: minimumAge,
      maximumAge: maximumAge,
      distanceKm: row['distance_km'] as int? ?? 50,
      locationMode: row['location_mode'] as String? ?? 'near_me',
      countries: List<String>.from(row['country_codes'] ?? const []),
      cities: List<String>.from(row['cities'] ?? const []),
      originCountries: List<String>.from(
        row['origin_country_names'] ?? const [],
      ),
      originCities: List<String>.from(row['origin_cities'] ?? const []),
      languages: List<String>.from(row['languages'] ?? const []),
      relationshipGoals: List<String>.from(
        row['relationship_goals'] ?? const [],
      ),
      verifiedOnly: row['verified_only'] as bool? ?? false,
      activeTodayOnly: row['active_today_only'] as bool? ?? false,
      genders: List<String>.from(row['genders'] ?? const []),
      personalities: List<String>.from(row['personalities'] ?? const []),
      interestSlugs: List<String>.from(row['interest_slugs'] ?? const []),
      religions: List<String>.from(row['religions'] ?? const []),
      bodyTypes: List<String>.from(row['body_types'] ?? const []),
      eyeColors: List<String>.from(row['eye_colors'] ?? const []),
      hairColors: List<String>.from(row['hair_colors'] ?? const []),
      minimumHeightCm: row['minimum_height_cm'] as int?,
      maximumHeightCm: row['maximum_height_cm'] as int?,
      childrenPreferences: List<String>.from(
        row['children_preferences'] ?? const [],
      ),
      relationshipStatuses: List<String>.from(
        row['relationship_statuses'] ?? const [],
      ),
      educationLevels: List<String>.from(row['education_levels'] ?? const []),
      beardStyles: List<String>.from(row['beard_styles'] ?? const []),
      smokingStatuses: List<String>.from(row['smoking_statuses'] ?? const []),
      professionCategories: List<String>.from(
        row['profession_categories'] ?? const [],
      ),
      incomeLevels: List<String>.from(row['income_levels'] ?? const []),
      photoVerifiedOnly: row['photo_verified_only'] as bool? ?? false,
      interestImportance: row['interest_importance'] as int? ?? 1,
      requiredGenders: row['required_genders'] as bool? ?? false,
      requiredLocation: row['required_location'] as bool? ?? false,
      requiredLanguages: row['required_languages'] as bool? ?? false,
      requiredRelationshipGoal:
          row['required_relationship_goal'] as bool? ?? false,
    );
  }
}

class ProfileLikeResult {
  const ProfileLikeResult({required this.liked, required this.matched});
  final bool liked;
  final bool matched;
}

class PhotoReactionState {
  const PhotoReactionState({
    this.likedPhotoIds = const {},
    this.superLikedPhotoIds = const {},
  });

  final Set<String> likedPhotoIds;
  final Set<String> superLikedPhotoIds;
}

class MatchItem {
  const MatchItem({
    required this.id,
    required this.profile,
    required this.date,
  });
  final String id;
  final UserProfile profile;
  final DateTime date;
}

class PostCommentItem {
  const PostCommentItem({
    required this.id,
    required this.author,
    required this.body,
    required this.mine,
  });
  final String id;
  final UserProfile author;
  final String body;
  final bool mine;
}

class SubscriptionInfo {
  const SubscriptionInfo({
    this.tier = 'free',
    this.status = 'active',
    this.renewsAt,
    this.history = const [],
  });
  final String tier;
  final String status;
  final DateTime? renewsAt;
  final List<Map<String, dynamic>> history;

  bool get isPremium => tier == 'plus' || tier == 'elite' || tier == 'vip';
  bool get isVip => tier == 'elite' || tier == 'vip';
  bool get isElite => isVip;
  String get displayName => isVip
      ? 'VIP'
      : tier == 'plus'
      ? 'Plus'
      : 'Free';
}

class FriendshipItem {
  const FriendshipItem({
    required this.id,
    required this.profile,
    required this.status,
    required this.sentByMe,
  });
  final String id;
  final UserProfile profile;
  final String status;
  final bool sentByMe;
}

class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.profile,
    required this.preview,
    required this.updatedAt,
    this.unread = 0,
  });
  final String id;
  final UserProfile profile;
  final String preview;
  final DateTime updatedAt;
  final int unread;
}

class MapLovMessage {
  const MapLovMessage({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.createdAt,
    this.body,
    this.mediaUrl,
    this.mediaBytes,
    this.deleted = false,
    this.read = false,
  });
  final String id;
  final String senderId;
  final String kind;
  final String? body;
  final String? mediaUrl;
  final Uint8List? mediaBytes;
  final DateTime createdAt;
  final bool deleted;
  final bool read;
}

class MapLovPost {
  const MapLovPost({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    this.mediaUrl,
    this.likes = 0,
    this.comments = 0,
    this.likedByMe = false,
    this.commentsEnabled = true,
    this.mediaUrls = const [],
    this.mine = false,
  });
  final String id;
  final UserProfile author;
  final String body;
  final String? mediaUrl;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final bool likedByMe;
  final bool commentsEnabled;
  final List<String> mediaUrls;
  final bool mine;
}

class GardenAlbumItem {
  const GardenAlbumItem({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description = '',
    this.coverUrl,
    this.photoCount = 0,
    this.accessStatus,
    this.expiresAt,
  });
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String? coverUrl;
  final int photoCount;
  final String? accessStatus;
  final DateTime? expiresAt;
}

class GardenRequestItem {
  const GardenRequestItem({
    required this.id,
    required this.albumId,
    required this.requester,
    required this.status,
    this.requestedSeconds,
  });
  final String id;
  final String albumId;
  final UserProfile requester;
  final String status;
  final int? requestedSeconds;
}

class MapLovNotification {
  const MapLovNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    required this.isRead,
    this.entityType,
    this.entityId,
    this.archived = false,
  });
  final String id;
  final String title;
  final String body;
  final String kind;
  final DateTime createdAt;
  final bool isRead;
  final String? entityType;
  final String? entityId;
  final bool archived;
}

/// Single data gateway for the app. It uses PostgreSQL through Supabase when a
/// session is available and keeps the validated demo usable before deployment.
class MapLovRepository {
  MapLovRepository._();
  static final instance = MapLovRepository._();

  final _uuid = const Uuid();
  final List<MapLovPost> _demoPosts = [];
  final List<MapLovMessage> _demoMessages = [];
  final StreamController<List<MapLovMessage>> _demoMessageStream =
      StreamController<List<MapLovMessage>>.broadcast();
  final Set<String> _demoBlockedIds = {};
  final Set<String> _demoFriendIds = mockProfiles
      .take(1)
      .map((profile) => profile.id)
      .toSet();
  final Set<String> _demoOutgoingFriendRequestIds = {};
  final Set<String> _demoIncomingFriendRequestIds = {};
  final Set<String> _demoLikedIds = {};
  final Set<String> _demoReciprocalLikeIds = {mockProfiles.first.id};
  final Set<String> _demoPhotoLikedProfileIds = {};
  final Set<String> _demoSuperLikedPhotoIds = {};
  final Set<String> _demoReciprocalPhotoLikeIds = {mockProfiles.first.id};
  final Set<String> _demoReportedPhotoIds = {};
  final Set<String> _demoReadConversations = {};
  final Map<String, DateTime> _demoConversationClearedAt = {};
  final Set<String> _demoHiddenMessageIds = {};
  final List<MapLovNotification> _demoNotifications = [
    MapLovNotification(
      id: 'demo-notification-1',
      title: 'Welcome to MapLov',
      body: 'Complete your profile to improve your matches.',
      kind: 'system',
      createdAt: DateTime.now(),
      isRead: false,
    ),
  ];

  SupabaseClient? get _client => SupabaseConfig.client;

  String? get currentUserId => _client?.auth.currentUser?.id;
  bool get isLive => _client != null && currentUserId != null;

  Future<void> setPresence(bool online) async {
    if (!isLive) return;
    try {
      await _client!.rpc('set_my_presence', params: {'online': online});
    } on PostgrestException {
      // Compatibility fallback until the additive presence migration deploys.
      try {
        await _client!
            .from('profiles')
            .update({
              'last_active_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', currentUserId!);
      } catch (_) {
        // Presence is best effort and must never interrupt user actions.
      }
    } catch (_) {
      // Network transitions commonly happen while the app is backgrounded.
      // Presence is best effort and must not become an unhandled exception.
    }
  }

  Future<List<UserProfile>> discoverProfiles({
    String tab = 'Discover',
    DiscoveryFilters filters = const DiscoveryFilters(),
  }) async {
    if (!isLive) {
      if (_client != null) return const [];
      final profiles = mockProfiles.where((profile) {
        if (_demoBlockedIds.contains(profile.id)) return false;
        if (!_profileMatchesFilters(profile, filters)) return false;
        if (tab == 'Nearby' && profile.distanceKm > filters.distanceKm) {
          return false;
        }
        if (tab == 'Online' && !profile.isOnline) return false;
        if (tab == 'New' && !profile.isNew) return false;
        return true;
      }).toList()..sort(_compareDiscoverProfiles);
      return profiles;
    }

    final viewerTier = (await subscriptionInfo()).tier;

    try {
      await _client!.rpc('refresh_my_compatibility_scores');
    } on PostgrestException {
      // The additive MVP migration may not have reached this environment yet.
    }

    if (tab == 'Nearby' ||
        (filters.locationMode == 'near_me' && filters.requiredLocation)) {
      try {
        final nearby =
            await _client!.rpc(
                  'find_nearby_profiles',
                  params: {
                    'radius_km': filters.distanceKm,
                    'result_limit': 100,
                  },
                )
                as List<dynamic>;
        final nearbyRows = nearby.cast<Map<String, dynamic>>();
        final distanceById = <String, int>{
          for (final raw in nearbyRows)
            if (raw['id'] case final String id)
              id: (raw['distance_km'] as num?)?.round() ?? 0,
        };
        if (tab == 'Discover' && currentUserId != null) {
          distanceById.putIfAbsent(currentUserId!, () => 0);
        }
        if (distanceById.isEmpty) return const [];
        final profileRows = await _client!
            .from('profiles')
            .select()
            .inFilter('id', distanceById.keys.toList());
        final hydrated = await _mapInBatches(
          profileRows.cast<Map<String, dynamic>>(),
          _profileFromRow,
        );
        final result = hydrated
            .where((profile) => profile.photoUrls.isNotEmpty)
            .map(
              (profile) => _copyProfile(
                profile,
                distanceKm: distanceById[profile.id] ?? profile.distanceKm,
              ),
            )
            .toList();
        final enriched = await _mapInBatches(result, _enrichCompatibility);
        return enriched
            .where(
              (profile) =>
                  (profile.id == currentUserId && profile.isNew) ||
                  (_profileMatchesFilters(profile, filters) &&
                      _newAccountVisibleToViewer(profile, viewerTier)),
            )
            .toList()
          ..sort(_compareDiscoverProfiles);
      } on PostgrestException {
        // Never replace a failed geographic query with ordinary discovery:
        // those rows do not contain a measured distance and would make the
        // selected Nearby radius misleading.
        rethrow;
      }
    }

    var profileQuery = _client!
        .from('profiles')
        .select()
        .eq('status', 'active')
        .eq('is_discoverable', true);
    if (filters.locationMode == 'specific_country' ||
        filters.locationMode == 'worldwide') {
      final viewerId = currentUserId;
      profileQuery = viewerId == null
          ? profileQuery.eq('allow_international_discovery', true)
          : profileQuery.or(
              'allow_international_discovery.eq.true,id.eq.$viewerId',
            );
    }
    final rows = await profileQuery.limit(100);
    final hydrated = await _mapInBatches(
      rows.cast<Map<String, dynamic>>(),
      _profileFromRow,
    );
    final candidates = hydrated
        .where((profile) {
          if (profile.id == currentUserId) {
            return profile.isNew && profile.photoUrls.isNotEmpty;
          }
          if (!_newAccountVisibleToViewer(profile, viewerTier)) return false;
          if (profile.photoUrls.isEmpty) return false;
          if (profile.age < filters.minimumAge ||
              profile.age > filters.maximumAge) {
            return false;
          }
          if (tab == 'Online' && !profile.isOnline) return false;
          if (tab == 'New' && !profile.isNew) return false;
          return true;
        })
        .map(
          (profile) => profile.id == currentUserId
              ? _copyProfile(profile, distanceKm: 0)
              : profile,
        )
        .toList();
    final enriched = await _mapInBatches(candidates, _enrichCompatibility);
    final profiles = enriched
        .where(
          (profile) =>
              (profile.id == currentUserId && profile.isNew) ||
              _profileMatchesFilters(profile, filters),
        )
        .toList();
    profiles.sort(_compareDiscoverProfiles);
    return profiles;
  }

  bool _newAccountVisibleToViewer(UserProfile profile, String viewerTier) {
    if (!profile.isNew || profile.id == currentUserId) return true;
    final createdAt = profile.createdAt;
    if (createdAt == null) return true;
    return newAccountVisibleToTier(
      createdAt: createdAt,
      viewerTier: viewerTier,
      isOwner: profile.id == currentUserId,
    );
  }

  int _compareDiscoverProfiles(UserProfile a, UserProfile b) {
    if (a.isNew != b.isNew) return a.isNew ? -1 : 1;
    final engagement = b.engagementScore.compareTo(a.engagementScore);
    if (engagement != 0) return engagement;
    return b.compatibilityScore.compareTo(a.compatibilityScore);
  }

  bool _profileMatchesFilters(UserProfile profile, DiscoveryFilters filters) {
    if (!visibleInInternationalDiscovery(
      allowsInternationalDiscovery: profile.allowsInternationalDiscovery,
      isOwner: profile.id == currentUserId,
      locationMode: filters.locationMode,
    )) {
      return false;
    }
    if (profile.age < filters.minimumAge || profile.age > filters.maximumAge) {
      return false;
    }
    if (filters.requiredLocation &&
        filters.locationMode == 'near_me' &&
        profile.distanceKm > filters.distanceKm) {
      return false;
    }
    if (filters.requiredGenders &&
        filters.genders.isNotEmpty &&
        !_matchesFilterValue(
          profile.gender,
          filters.genders,
          normalizeGender: true,
        )) {
      return false;
    }
    if (filters.requiredLocation &&
        filters.countries.isNotEmpty &&
        !filters.countries.any(
          (value) => value.toLowerCase() == profile.country.toLowerCase(),
        )) {
      return false;
    }
    if (filters.requiredLocation &&
        filters.cities.isNotEmpty &&
        !filters.cities.any(
          (value) => value.toLowerCase() == profile.city.toLowerCase(),
        )) {
      return false;
    }
    if (filters.originCountries.isNotEmpty &&
        !filters.originCountries.any(
          (value) => value.toLowerCase() == profile.originCountry.toLowerCase(),
        )) {
      return false;
    }
    if (filters.originCities.isNotEmpty &&
        !filters.originCities.any(
          (value) => value.toLowerCase() == profile.originCity.toLowerCase(),
        )) {
      return false;
    }
    if (filters.requiredLanguages &&
        filters.languages.isNotEmpty &&
        !filters.languages.any(
          (filter) => profile.languages.any(
            (value) =>
                _normalizedFilterValue(value) == _normalizedFilterValue(filter),
          ),
        )) {
      return false;
    }
    if (filters.requiredRelationshipGoal &&
        filters.relationshipGoals.isNotEmpty &&
        !_matchesFilterValue(
          profile.relationshipGoal,
          filters.relationshipGoals,
        )) {
      return false;
    }
    if (filters.interestSlugs.isNotEmpty &&
        !filters.interestSlugs.any(
          (filter) => profile.interests.any(
            (value) =>
                _normalizedFilterValue(value) == _normalizedFilterValue(filter),
          ),
        )) {
      return false;
    }
    if (filters.religions.isNotEmpty &&
        !_matchesFilterValue(profile.religion, filters.religions)) {
      return false;
    }
    if (filters.bodyTypes.isNotEmpty &&
        !_matchesFilterValue(profile.bodyType, filters.bodyTypes)) {
      return false;
    }
    if (filters.eyeColors.isNotEmpty &&
        !_matchesFilterValue(profile.eyeColor, filters.eyeColors)) {
      return false;
    }
    if (filters.hairColors.isNotEmpty &&
        !_matchesFilterValue(profile.hairColor, filters.hairColors)) {
      return false;
    }
    if (filters.minimumHeightCm != null &&
        (profile.heightCm ?? 0) < filters.minimumHeightCm!) {
      return false;
    }
    if (filters.maximumHeightCm != null &&
        (profile.heightCm ?? 1000) > filters.maximumHeightCm!) {
      return false;
    }
    if (filters.childrenPreferences.isNotEmpty &&
        !_matchesFilterValue(
          profile.childrenPreference,
          filters.childrenPreferences,
        )) {
      return false;
    }
    if (filters.relationshipStatuses.isNotEmpty &&
        !_matchesFilterValue(
          profile.relationshipStatus,
          filters.relationshipStatuses,
        )) {
      return false;
    }
    if (filters.educationLevels.isNotEmpty &&
        !_matchesFilterValue(profile.educationLevel, filters.educationLevels)) {
      return false;
    }
    if (filters.beardStyles.isNotEmpty &&
        !_matchesFilterValue(profile.beardStyle, filters.beardStyles)) {
      return false;
    }
    if (filters.smokingStatuses.isNotEmpty &&
        !_matchesFilterValue(profile.smokingStatus, filters.smokingStatuses)) {
      return false;
    }
    if (filters.incomeLevels.isNotEmpty &&
        !_matchesFilterValue(profile.incomeLevel, filters.incomeLevels)) {
      return false;
    }
    if (filters.professionCategories.isNotEmpty &&
        !filters.professionCategories.any(
          (category) =>
              _professionMatchesCategory(profile.profession, category),
        )) {
      return false;
    }
    if (filters.photoVerifiedOnly && !profile.isPhotoVerified) return false;
    if (filters.verifiedOnly && !profile.isVerified) return false;
    if (filters.activeTodayOnly &&
        (profile.lastActiveAt == null ||
            DateTime.now().difference(profile.lastActiveAt!).inHours > 24)) {
      return false;
    }
    return true;
  }

  bool _matchesFilterValue(
    String value,
    List<String> filters, {
    bool normalizeGender = false,
  }) {
    final normalizedValue = normalizeGender
        ? _normalizedGender(value)
        : _normalizedFilterValue(value);
    return filters.any((filter) {
      final normalizedFilter = normalizeGender
          ? _normalizedGender(filter)
          : _normalizedFilterValue(filter);
      return normalizedValue == normalizedFilter;
    });
  }

  String _normalizedGender(String value) {
    return switch (_normalizedFilterValue(value)) {
      'women' || 'woman' => 'woman',
      'men' || 'man' => 'man',
      final normalized => normalized,
    };
  }

  String _normalizedFilterValue(String value) => value.trim().toLowerCase();

  bool _professionMatchesCategory(String profession, String category) {
    final value = _normalizedFilterValue(profession);
    final keywords = switch (_normalizedFilterValue(category)) {
      'technology' => const [
        'engineer',
        'developer',
        'software',
        'technology',
        'data',
        'product',
        'it ',
      ],
      'healthcare' => const ['doctor', 'nurse', 'medical', 'health', 'pharmac'],
      'education' => const ['teacher', 'professor', 'educat', 'school'],
      'business' => const [
        'business',
        'manager',
        'finance',
        'account',
        'marketing',
        'sales',
      ],
      'arts' => const [
        'artist',
        'designer',
        'music',
        'writer',
        'photograph',
        'creative',
      ],
      _ => [category.toLowerCase()],
    };
    return keywords.any(value.contains);
  }

  Future<UserProfile> _enrichCompatibility(UserProfile profile) async {
    if (!isLive) return profile;
    final row = await _client!
        .from('compatibility_scores')
        .select('score, breakdown')
        .eq('user_id', currentUserId!)
        .eq('candidate_id', profile.id)
        .maybeSingle();
    final liked = await _client!
        .from('profile_likes')
        .select('liked_id')
        .eq('liker_id', currentUserId!)
        .eq('liked_id', profile.id)
        .maybeSingle();
    return _copyProfile(
      profile,
      compatibilityScore: row?['score'] as int? ?? profile.compatibilityScore,
      compatibilityBreakdown: Map<String, dynamic>.from(
        row?['breakdown'] as Map? ?? const {},
      ),
      likedByMe: liked != null,
    );
  }

  Future<UserProfile?> getProfile(String id) async {
    if (!isLive) {
      if (_client != null) return null;
      return mockProfiles.where((profile) => profile.id == id).firstOrNull;
    }
    final row = await _client!
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _profileFromRow(row);
  }

  Future<void> saveMyProfile(Map<String, Object?> values) async {
    if (!isLive) return;
    final editableValues = Map<String, Object?>.from(values)
      ..remove('profile_completed_at')
      ..remove('is_discoverable');
    await _client!
        .from('profiles')
        .update(editableValues)
        .eq('id', currentUserId!);
    await completeProfileIfReady();
  }

  Future<void> setInternationalDiscovery(bool allow) async {
    if (!isLive) return;
    await _client!
        .from('profiles')
        .update({'allow_international_discovery': allow})
        .eq('id', currentUserId!);
  }

  Future<bool> completeProfileIfReady() async {
    if (!isLive) return true;
    final profile = await myProfileDetails();
    final photos = await _client!
        .from('profile_photos')
        .select('id')
        .eq('user_id', currentUserId!)
        .eq('moderation_status', 'visible')
        .limit(1);
    final ready =
        profile?['first_name'] != null &&
        profile?['date_of_birth'] != null &&
        profile?['gender'] != null &&
        profile?['city'] != null &&
        profile?['country_name'] != null &&
        (profile?['spoken_languages'] as List?)?.isNotEmpty == true &&
        photos.isNotEmpty;
    if (ready && profile?['profile_completed_at'] == null) {
      await _client!
          .from('profiles')
          .update({
            'profile_completed_at': DateTime.now().toUtc().toIso8601String(),
            'is_discoverable': true,
          })
          .eq('id', currentUserId!);
    } else if (!ready) {
      await _client!
          .from('profiles')
          .update({'profile_completed_at': null, 'is_discoverable': false})
          .eq('id', currentUserId!);
    }
    return ready;
  }

  Future<Map<String, dynamic>?> myProfileDetails() async {
    if (!isLive) return null;
    return _client!
        .from('profiles')
        .select()
        .eq('id', currentUserId!)
        .maybeSingle();
  }

  Future<void> savePreferences(DiscoveryFilters filters) async {
    if (!isLive) return;
    await _client!.from('dating_preferences').upsert({
      'user_id': currentUserId!,
      ...filters.toDatabase(),
    });
    try {
      await _client!.rpc('refresh_my_compatibility_scores');
    } on PostgrestException {
      // Preferences remain valid if the optional compatibility RPC has not
      // been deployed yet.
    }
  }

  Future<DiscoveryFilters> myPreferences() async {
    if (!isLive) return const DiscoveryFilters();
    final row = await _client!
        .from('dating_preferences')
        .select()
        .eq('user_id', currentUserId!)
        .maybeSingle();
    return row == null
        ? const DiscoveryFilters()
        : DiscoveryFilters.fromDatabase(row);
  }

  Future<ProfileLikeResult> toggleProfileLike(String profileId) async {
    if (!isLive) {
      final liked = _demoLikedIds.add(profileId);
      if (!liked) _demoLikedIds.remove(profileId);
      final profile = mockProfiles
          .where((item) => item.id == profileId)
          .firstOrNull;
      return ProfileLikeResult(
        liked: liked,
        matched:
            liked &&
            (_demoReciprocalLikeIds.contains(profileId) ||
                (profile?.compatibilityScore ?? 0) > 80),
      );
    }
    final existing = await _client!
        .from('profile_likes')
        .select('liked_id')
        .eq('liker_id', currentUserId!)
        .eq('liked_id', profileId)
        .maybeSingle();
    if (existing != null) {
      await _client!
          .from('profile_likes')
          .delete()
          .eq('liker_id', currentUserId!)
          .eq('liked_id', profileId);
      return const ProfileLikeResult(liked: false, matched: false);
    }
    final wasMatched = await _hasMatchWith(profileId);
    await _client!.from('profile_likes').insert({
      'liker_id': currentUserId!,
      'liked_id': profileId,
    });
    final isMatched = await _hasMatchWith(profileId);
    return ProfileLikeResult(liked: true, matched: !wasMatched && isMatched);
  }

  Future<bool> _hasMatchWith(String profileId) async {
    if (!isLive) {
      final profile = mockProfiles
          .where((item) => item.id == profileId)
          .firstOrNull;
      return (_demoLikedIds.contains(profileId) &&
              (_demoReciprocalLikeIds.contains(profileId) ||
                  (profile?.compatibilityScore ?? 0) > 80)) ||
          (_demoPhotoLikedProfileIds.contains(profileId) &&
              _demoReciprocalPhotoLikeIds.contains(profileId));
    }
    final match = await _client!
        .from('matches')
        .select('id')
        .or(
          'and(user_a.eq.$currentUserId,user_b.eq.$profileId),and(user_a.eq.$profileId,user_b.eq.$currentUserId)',
        )
        .maybeSingle();
    return match != null;
  }

  Future<List<UserProfile>> profilesWhoLikedMe() async {
    if (!isLive) {
      return _demoReciprocalLikeIds
          .where((id) => !_demoLikedIds.contains(id))
          .map((id) => mockProfiles.where((p) => p.id == id).firstOrNull)
          .whereType<UserProfile>()
          .toList();
    }
    final incoming = await _client!
        .from('profile_likes')
        .select('liker_id, created_at')
        .eq('liked_id', currentUserId!)
        .order('created_at', ascending: false);
    final outgoing = await _client!
        .from('profile_likes')
        .select('liked_id')
        .eq('liker_id', currentUserId!);
    final alreadyLiked = outgoing
        .map((row) => row['liked_id'] as String)
        .toSet();
    final profiles = <UserProfile>[];
    for (final row in incoming) {
      final likerId = row['liker_id'] as String;
      if (alreadyLiked.contains(likerId)) continue;
      final profile = await getProfile(likerId);
      if (profile != null) {
        profiles.add(await _enrichCompatibility(profile));
      }
    }
    return profiles;
  }

  Future<List<MatchItem>> myMatches() async {
    if (!isLive) {
      final candidateIds = {..._demoLikedIds, ..._demoPhotoLikedProfileIds};
      final profiles = candidateIds
          .where((id) {
            final profile = mockProfiles
                .where((item) => item.id == id)
                .firstOrNull;
            return (_demoLikedIds.contains(id) &&
                    (_demoReciprocalLikeIds.contains(id) ||
                        (profile?.compatibilityScore ?? 0) > 80)) ||
                (_demoPhotoLikedProfileIds.contains(id) &&
                    _demoReciprocalPhotoLikeIds.contains(id));
          })
          .map((id) => mockProfiles.where((p) => p.id == id).firstOrNull)
          .whereType<UserProfile>();
      final source = profiles.isEmpty ? mockProfiles.take(3) : profiles;
      return source
          .map(
            (profile) => MatchItem(
              id: 'demo-match-${profile.id}',
              profile: profile,
              date: DateTime.now(),
            ),
          )
          .toList();
    }
    final rows = await _client!
        .from('matches')
        .select()
        .or('user_a.eq.$currentUserId,user_b.eq.$currentUserId')
        .order('matched_at', ascending: false);
    final result = <MatchItem>[];
    for (final row in rows) {
      final otherId = row['user_a'] == currentUserId
          ? row['user_b'] as String
          : row['user_a'] as String;
      final profile = await getProfile(otherId);
      if (profile != null) {
        result.add(
          MatchItem(
            id: row['id'] as String,
            profile: await _enrichCompatibility(profile),
            date: DateTime.parse(row['matched_at'] as String),
          ),
        );
      }
    }
    return result;
  }

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    if (!isLive) return;
    await _client!.rpc(
      'update_my_location',
      params: {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracy,
      },
    );
  }

  Future<void> uploadProfilePhoto({
    required Uint8List bytes,
    required String extension,
  }) async {
    _validateMedia(
      bytes,
      extension,
      allowed: const {'jpg', 'jpeg', 'png', 'webp'},
      maxBytes: 10 * 1024 * 1024,
    );
    if (!isLive) return;
    final userId = currentUserId!;
    final path = '$userId/${_uuid.v4()}.$extension';
    await _client!.storage
        .from('profile-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );
    try {
      await _client!.rpc(
        'register_profile_photo',
        params: {'storage_path_value': path},
      );
      await completeProfileIfReady();
    } catch (_) {
      await _client!.storage.from('profile-media').remove([path]);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> myPhotos() async {
    if (!isLive) {
      return mockProfiles.indexed
          .map(
            (entry) => {
              'id': entry.$2.id,
              'url': entry.$2.imagePath,
              'storage_path': entry.$2.imagePath,
              'is_primary': entry.$1 == 0,
              'display_order': entry.$1,
              'moderation_status': 'visible',
            },
          )
          .toList();
    }
    final rows = await _client!
        .from('profile_photos')
        .select()
        .eq('user_id', currentUserId!)
        .order('display_order');
    return Future.wait(
      rows.map((row) async {
        final result = Map<String, dynamic>.from(row);
        result['url'] = await _signedUrl(
          'profile-media',
          row['storage_path'] as String,
        );
        return result;
      }),
    );
  }

  Future<int> myPhotoCount() async => (await myPhotos()).length;

  Future<bool> deleteProfilePhoto(Map<String, dynamic> photo) async {
    if (!isLive) return true;
    final photos = await _client!
        .from('profile_photos')
        .select('id, is_primary, moderation_status')
        .eq('user_id', currentUserId!)
        .order('display_order');
    final underReview = photo['moderation_status'] == 'under_review';
    if (photos.length <= 1 && !underReview) return false;
    final wasPrimary = photo['is_primary'] == true;
    await _client!.from('profile_photos').delete().eq('id', photo['id']);
    await _client!.storage.from('profile-media').remove([
      photo['storage_path'] as String,
    ]);
    if (wasPrimary) {
      final remaining = await _client!
          .from('profile_photos')
          .select('id')
          .eq('user_id', currentUserId!)
          .order('display_order')
          .limit(1);
      if (remaining.isNotEmpty) {
        await setPrimaryPhoto(remaining.first['id'] as String);
      }
    }
    await completeProfileIfReady();
    return true;
  }

  Future<void> setPrimaryPhoto(String photoId) async {
    if (!isLive) return;
    await _client!.rpc(
      'set_my_primary_photo',
      params: {'photo_id_value': photoId},
    );
  }

  Future<void> reorderProfilePhotos(List<Map<String, dynamic>> photos) async {
    if (!isLive) return;
    // Move through temporary values first to preserve the unique order index.
    for (var index = 0; index < photos.length; index++) {
      await _client!
          .from('profile_photos')
          .update({'display_order': index + 1000})
          .eq('id', photos[index]['id']);
    }
    for (var index = 0; index < photos.length; index++) {
      await _client!
          .from('profile_photos')
          .update({'display_order': index})
          .eq('id', photos[index]['id']);
    }
  }

  Future<ProfileLikeResult> togglePhotoLike(
    String photoId, {
    required String profileId,
    required bool currentlyLiked,
  }) async {
    if (!isLive) {
      final liked = !currentlyLiked;
      if (liked) {
        _demoPhotoLikedProfileIds.add(profileId);
      } else {
        _demoPhotoLikedProfileIds.remove(profileId);
      }
      return ProfileLikeResult(
        liked: liked,
        matched: liked && _demoReciprocalPhotoLikeIds.contains(profileId),
      );
    }
    final existing = await _client!
        .from('photo_likes')
        .select('photo_id')
        .eq('photo_id', photoId)
        .eq('user_id', currentUserId!)
        .maybeSingle();
    if (existing != null) {
      await _client!
          .from('photo_likes')
          .delete()
          .eq('photo_id', photoId)
          .eq('user_id', currentUserId!);
      return const ProfileLikeResult(liked: false, matched: false);
    }
    final wasMatched = await _hasMatchWith(profileId);
    try {
      await _client!.from('photo_likes').insert({
        'photo_id': photoId,
        'user_id': currentUserId!,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      // A stale local reaction state must behave like a toggle, not expose a
      // database constraint error to the user.
      await _client!
          .from('photo_likes')
          .delete()
          .eq('photo_id', photoId)
          .eq('user_id', currentUserId!);
      return const ProfileLikeResult(liked: false, matched: false);
    }
    final isMatched = await _hasMatchWith(profileId);
    return ProfileLikeResult(liked: true, matched: !wasMatched && isMatched);
  }

  Future<bool> togglePhotoSuperLike(
    String photoId, {
    required bool currentlySuperLiked,
  }) async {
    if (!isLive) {
      if (currentlySuperLiked) {
        _demoSuperLikedPhotoIds.remove(photoId);
        return false;
      }
      _demoSuperLikedPhotoIds.add(photoId);
      return true;
    }
    final existing = await _client!
        .from('photo_super_likes')
        .select('photo_id')
        .eq('photo_id', photoId)
        .eq('user_id', currentUserId!)
        .maybeSingle();
    if (existing != null) {
      await _client!
          .from('photo_super_likes')
          .delete()
          .eq('photo_id', photoId)
          .eq('user_id', currentUserId!);
      return false;
    }
    try {
      await _client!.from('photo_super_likes').insert({
        'photo_id': photoId,
        'user_id': currentUserId!,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      await _client!
          .from('photo_super_likes')
          .delete()
          .eq('photo_id', photoId)
          .eq('user_id', currentUserId!);
      return false;
    }
    return true;
  }

  Future<PhotoReactionState> photoReactionState(List<String> photoIds) async {
    if (photoIds.isEmpty || !isLive) return const PhotoReactionState();
    final likes = await _client!
        .from('photo_likes')
        .select('photo_id')
        .eq('user_id', currentUserId!)
        .inFilter('photo_id', photoIds);
    final superLikes = await _client!
        .from('photo_super_likes')
        .select('photo_id')
        .eq('user_id', currentUserId!)
        .inFilter('photo_id', photoIds);
    return PhotoReactionState(
      likedPhotoIds: likes.map((row) => row['photo_id'] as String).toSet(),
      superLikedPhotoIds: superLikes
          .map((row) => row['photo_id'] as String)
          .toSet(),
    );
  }

  Future<String?> profilePhotoId(String profileId, int index) async {
    if (!isLive) return 'demo-photo-$profileId-$index';
    final rows = await _client!
        .from('profile_photos')
        .select('id')
        .eq('user_id', profileId)
        .eq('moderation_status', 'visible')
        .order('is_primary', ascending: false)
        .order('display_order');
    if (index < 0 || index >= rows.length) return null;
    return rows[index]['id'] as String?;
  }

  Future<List<Map<String, String>>> photoComments(String photoId) async {
    if (!isLive) {
      return const [
        {'author': 'Jamie', 'body': 'This is such a beautiful photo!'},
        {'author': 'Taylor', 'body': 'The sunset looks incredible ✨'},
      ];
    }
    final rows = await _client!
        .from('photo_comments')
        .select()
        .eq('photo_id', photoId)
        .isFilter('deleted_at', null)
        .order('created_at');
    final result = <Map<String, String>>[];
    for (final row in rows) {
      final author = await getProfile(row['author_id'] as String);
      result.add({
        'author': author?.name ?? 'MapLov member',
        'body': row['body'] as String,
      });
    }
    return result;
  }

  Future<void> addPhotoComment(String photoId, String body) async {
    if (!isLive || body.trim().isEmpty) return;
    await _client!.from('photo_comments').insert({
      'photo_id': photoId,
      'author_id': currentUserId!,
      'body': body.trim(),
    });
  }

  Future<List<FriendshipItem>> friendships({String? status}) async {
    if (!isLive) {
      final accepted = _demoFriendIds.map(
        (id) => FriendshipItem(
          id: id,
          profile:
              mockProfiles.where((profile) => profile.id == id).firstOrNull ??
              demoProfileOrUnavailable,
          status: 'accepted',
          sentByMe: false,
        ),
      );
      final outgoing = _demoOutgoingFriendRequestIds.map(
        (id) => FriendshipItem(
          id: id,
          profile:
              mockProfiles.where((profile) => profile.id == id).firstOrNull ??
              demoProfileOrUnavailable,
          status: 'pending',
          sentByMe: true,
        ),
      );
      final incoming = _demoIncomingFriendRequestIds.map(
        (id) => FriendshipItem(
          id: id,
          profile:
              mockProfiles.where((profile) => profile.id == id).firstOrNull ??
              demoProfileOrUnavailable,
          status: 'pending',
          sentByMe: false,
        ),
      );
      final all = [...accepted, ...outgoing, ...incoming];
      return status == null
          ? all
          : all.where((item) => item.status == status).toList();
    }
    var query = _client!.from('friendships').select();
    if (status != null) query = query.eq('status', status);
    final rows = await query.order('updated_at', ascending: false);
    final items = await _mapInBatches(rows.cast<Map<String, dynamic>>(), (
      row,
    ) async {
      final sentByMe = row['requester_id'] == currentUserId;
      final otherId =
          (sentByMe ? row['addressee_id'] : row['requester_id']) as String;
      final profile = await getProfile(otherId);
      if (profile == null) return null;
      return FriendshipItem(
        id: row['id'] as String,
        profile: profile,
        status: row['status'] as String,
        sentByMe: sentByMe,
      );
    });
    return items.whereType<FriendshipItem>().toList();
  }

  Future<void> sendFriendRequest(String userId) async {
    if (!isLive) {
      if (!_demoFriendIds.contains(userId) &&
          !_demoIncomingFriendRequestIds.contains(userId)) {
        _demoOutgoingFriendRequestIds.add(userId);
      }
      return;
    }
    await _client!.from('friendships').insert({
      'requester_id': currentUserId!,
      'addressee_id': userId,
    });
  }

  Future<void> respondToFriendRequest(String id, bool accept) async {
    if (!isLive) {
      if (_demoIncomingFriendRequestIds.remove(id) && accept) {
        _demoFriendIds.add(id);
      }
      return;
    }
    await _client!
        .from('friendships')
        .update({
          'status': accept ? 'accepted' : 'declined',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('addressee_id', currentUserId!);
  }

  Future<void> removeFriendship(String id, {bool cancel = false}) async {
    if (!isLive) {
      if (cancel) {
        _demoOutgoingFriendRequestIds.remove(id);
      } else {
        _demoFriendIds.remove(id);
        _demoIncomingFriendRequestIds.remove(id);
      }
      return;
    }
    if (cancel) {
      await _client!
          .from('friendships')
          .update({'status': 'cancelled'})
          .eq('id', id);
    } else {
      await _client!.from('friendships').delete().eq('id', id);
    }
  }

  Future<FriendshipItem?> friendshipWith(
    String userId, {
    UserProfile? profile,
  }) async {
    if (!isLive) {
      final resolvedProfile =
          profile ??
          mockProfiles
              .where((candidate) => candidate.id == userId)
              .firstOrNull ??
          demoProfileOrUnavailable;
      if (_demoFriendIds.contains(userId)) {
        return FriendshipItem(
          id: userId,
          profile: resolvedProfile,
          status: 'accepted',
          sentByMe: false,
        );
      }
      if (_demoOutgoingFriendRequestIds.contains(userId)) {
        return FriendshipItem(
          id: userId,
          profile: resolvedProfile,
          status: 'pending',
          sentByMe: true,
        );
      }
      if (_demoIncomingFriendRequestIds.contains(userId)) {
        return FriendshipItem(
          id: userId,
          profile: resolvedProfile,
          status: 'pending',
          sentByMe: false,
        );
      }
      return null;
    }
    final me = currentUserId!;
    final row = await _client!
        .from('friendships')
        .select()
        .or(
          'and(requester_id.eq.$me,addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.$me)',
        )
        .inFilter('status', const ['pending', 'accepted'])
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final resolvedProfile = profile ?? await getProfile(userId);
    if (resolvedProfile == null) return null;
    return FriendshipItem(
      id: row['id'] as String,
      profile: resolvedProfile,
      status: row['status'] as String,
      sentByMe: row['requester_id'] == me,
    );
  }

  Future<String> startConversation(String userId) async {
    if (!isLive) return 'demo-$userId';
    return await _client!.rpc(
          'start_direct_conversation',
          params: {'other_user': userId},
        )
        as String;
  }

  Future<List<ConversationItem>> conversations() async {
    if (!isLive) {
      return mockProfiles
          .take(4)
          .map(
            (p) => ConversationItem(
              id: 'demo-${p.id}',
              profile: p,
              preview: 'Start a conversation',
              updatedAt: DateTime.now(),
            ),
          )
          .toList();
    }
    final memberships = await _client!
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', currentUserId!)
        .isFilter('left_at', null);
    final hiddenMessageRows = await _client!
        .from('message_deletions')
        .select('message_id')
        .eq('user_id', currentUserId!);
    final hiddenMessageIds = hiddenMessageRows
        .map((row) => row['message_id'] as String)
        .toSet();
    final result = <ConversationItem>[];
    for (final membership in memberships) {
      final conversationId = membership['conversation_id'] as String;
      final others = await _client!
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .neq('user_id', currentUserId!)
          .isFilter('left_at', null)
          .limit(1);
      if (others.isEmpty) continue;
      final profile = await getProfile(others.first['user_id'] as String);
      if (profile == null) continue;
      final clearRow = await _client!
          .from('conversation_clears')
          .select('cleared_at')
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId!)
          .maybeSingle();
      final clearedAt = DateTime.tryParse(
        clearRow?['cleared_at'] as String? ?? '',
      );
      final latest = await _client!
          .from('messages')
          .select('id, body, kind, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(50);
      latest.removeWhere((message) => hiddenMessageIds.contains(message['id']));
      if (latest.length > 1) latest.removeRange(1, latest.length);
      if (latest.isNotEmpty &&
          clearedAt != null &&
          !DateTime.parse(
            latest.first['created_at'] as String,
          ).isAfter(clearedAt)) {
        latest.clear();
      }
      final readRow = await _client!
          .from('conversation_reads')
          .select('last_read_at')
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId!)
          .maybeSingle();
      final unreadRows = await _client!
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId)
          .neq('sender_id', currentUserId!)
          .gt(
            'created_at',
            _latestTimestamp(
              readRow?['last_read_at'] as String?,
              clearRow?['cleared_at'] as String?,
            ),
          );
      unreadRows.removeWhere(
        (message) => hiddenMessageIds.contains(message['id']),
      );
      result.add(
        ConversationItem(
          id: conversationId,
          profile: profile,
          preview: latest.isEmpty
              ? 'Start a conversation'
              : (latest.first['body'] as String? ?? 'Media'),
          updatedAt: latest.isEmpty
              ? DateTime.now()
              : DateTime.parse(latest.first['created_at'] as String),
          unread: unreadRows.length,
        ),
      );
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Stream<List<MapLovMessage>> watchMessages(String conversationId) {
    if (!isLive) {
      return Stream<List<MapLovMessage>>.multi((controller) {
        List<MapLovMessage> visible(List<MapLovMessage> messages) {
          final clearedAt = _demoConversationClearedAt[conversationId];
          return List.unmodifiable(
            messages
                .where(
                  (message) =>
                      !_demoHiddenMessageIds.contains(message.id) &&
                      (clearedAt == null ||
                          message.createdAt.isAfter(clearedAt)),
                )
                .toList(),
          );
        }

        controller.add(visible(_demoMessages));
        final subscription = _demoMessageStream.stream.listen(
          (messages) => controller.add(visible(messages)),
        );
        controller.onCancel = subscription.cancel;
      });
    }
    return _client!
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .asyncMap((rows) async {
          final clearRow = await _client!
              .from('conversation_clears')
              .select('cleared_at')
              .eq('conversation_id', conversationId)
              .eq('user_id', currentUserId!)
              .maybeSingle();
          final clearedAt = DateTime.tryParse(
            clearRow?['cleared_at'] as String? ?? '',
          );
          final otherReads = await _client!
              .from('conversation_reads')
              .select('last_read_at')
              .eq('conversation_id', conversationId)
              .neq('user_id', currentUserId!)
              .order('last_read_at', ascending: false)
              .limit(1);
          final readAt = otherReads.isEmpty
              ? null
              : DateTime.tryParse(otherReads.first['last_read_at'] as String);
          final hiddenRows = await _client!
              .from('message_deletions')
              .select('message_id')
              .eq('user_id', currentUserId!);
          final hiddenIds = hiddenRows
              .map((row) => row['message_id'] as String)
              .toSet();
          return Future.wait(
            rows
                .where(
                  (row) =>
                      !hiddenIds.contains(row['id']) &&
                      (clearedAt == null ||
                          DateTime.parse(
                            row['created_at'] as String,
                          ).isAfter(clearedAt)),
                )
                .map((row) => _messageFromRow(row, otherReadAt: readAt)),
          );
        });
  }

  String _latestTimestamp(String? first, String? second) {
    final firstDate = DateTime.tryParse(first ?? '');
    final secondDate = DateTime.tryParse(second ?? '');
    if (firstDate == null) return second ?? '1970-01-01T00:00:00Z';
    if (secondDate == null) return first!;
    return firstDate.isAfter(secondDate) ? first! : second!;
  }

  String createClientMessageId() => _uuid.v4();

  Future<void> sendMessage(
    String conversationId,
    String body, {
    String? clientMessageId,
  }) async {
    final text = body.trim();
    if (text.isEmpty) return;
    final requestId = clientMessageId ?? createClientMessageId();
    if (!isLive) {
      if (_demoMessages.any((message) => message.id == requestId)) return;
      _demoMessages.add(
        MapLovMessage(
          id: requestId,
          senderId: 'me',
          kind: 'text',
          body: text,
          createdAt: DateTime.now(),
        ),
      );
      _demoMessageStream.add(List.unmodifiable(_demoMessages));
      return;
    }
    try {
      await _client!.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId!,
        'kind': 'text',
        'body': text,
        'client_message_id': requestId,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
  }

  Future<void> sendMessageMedia({
    required String conversationId,
    required Uint8List bytes,
    required String extension,
    required String kind,
    String? fileName,
    String? clientMessageId,
  }) async {
    final requestId = clientMessageId ?? createClientMessageId();
    _validateMedia(
      bytes,
      extension,
      allowed: switch (kind) {
        'voice' => const {'m4a', 'aac', 'mp3', 'ogg'},
        'document' => const {
          'pdf',
          'doc',
          'docx',
          'txt',
          'rtf',
          'csv',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'zip',
        },
        _ => const {'jpg', 'jpeg', 'png', 'webp'},
      },
      maxBytes: 25 * 1024 * 1024,
    );
    if (!isLive) {
      if (_demoMessages.any((message) => message.id == requestId)) return;
      _demoMessages.add(
        MapLovMessage(
          id: requestId,
          senderId: 'me',
          kind: kind,
          body:
              fileName ?? (kind == 'voice' ? 'Voice message' : 'Photo message'),
          mediaBytes: bytes,
          createdAt: DateTime.now(),
        ),
      );
      _demoMessageStream.add(List.unmodifiable(_demoMessages));
      return;
    }
    final path = '${currentUserId!}/$conversationId/$requestId.$extension';
    await _client!.storage
        .from('chat-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    try {
      await _client!.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId!,
        'kind': kind,
        'body': fileName,
        'media_path': path,
        'client_message_id': requestId,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
  }

  Future<void> markConversationRead(String conversationId) async {
    if (!isLive) {
      _demoReadConversations.add(conversationId);
      return;
    }
    await _client!.from('conversation_reads').upsert({
      'conversation_id': conversationId,
      'user_id': currentUserId!,
      'last_read_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteMessage(
    String messageId, {
    required bool forEveryone,
  }) async {
    if (!isLive) {
      final index = _demoMessages.indexWhere(
        (message) => message.id == messageId,
      );
      if (index >= 0) {
        if (forEveryone) {
          final old = _demoMessages[index];
          _demoMessages[index] = MapLovMessage(
            id: old.id,
            senderId: old.senderId,
            kind: old.kind,
            createdAt: old.createdAt,
            deleted: true,
          );
        } else {
          _demoHiddenMessageIds.add(messageId);
        }
        _demoMessageStream.add(List.unmodifiable(_demoMessages));
      }
      return;
    }
    await _client!.rpc(
      'delete_my_message_with_scope',
      params: {'target_message': messageId, 'delete_for_everyone': forEveryone},
    );
  }

  Future<DateTime> clearConversation(
    String conversationId, {
    required bool forEveryone,
  }) async {
    final clearedAt = DateTime.now().toUtc();
    if (!isLive) {
      _demoConversationClearedAt[conversationId] = clearedAt;
      _demoMessageStream.add(List.unmodifiable(_demoMessages));
      return clearedAt;
    }
    final value = await _client!.rpc(
      'clear_my_conversation_with_scope',
      params: {
        'target_conversation': conversationId,
        'clear_for_everyone': forEveryone,
      },
    );
    return DateTime.tryParse(value as String? ?? '') ?? clearedAt;
  }

  Future<List<MapLovPost>> posts() async {
    if (!isLive) {
      if (_demoPosts.isNotEmpty) return List.unmodifiable(_demoPosts);
      return mockProfiles
          .take(3)
          .map(
            (profile) => MapLovPost(
              id: 'demo-post-${profile.id}',
              author: profile,
              body: 'A perfect day exploring the city ✨',
              mediaUrl: profile.imagePath,
              createdAt: DateTime.now(),
            ),
          )
          .toList();
    }
    final rows = await _client!
        .from('posts')
        .select()
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(100);
    final result = <MapLovPost>[];
    for (final row in rows) {
      final author = await getProfile(row['author_id'] as String);
      if (author == null) continue;
      final media = await _client!
          .from('post_media')
          .select('storage_path')
          .eq('post_id', row['id'])
          .order('display_order');
      final mediaUrls = await Future.wait(
        media.map(
          (item) => _signedUrl('post-media', item['storage_path'] as String),
        ),
      );
      final likes = await _client!
          .from('post_likes')
          .select('user_id')
          .eq('post_id', row['id']);
      final comments = await _client!
          .from('post_comments')
          .select('id')
          .eq('post_id', row['id'])
          .isFilter('deleted_at', null);
      result.add(
        MapLovPost(
          id: row['id'] as String,
          author: author,
          body: row['body'] as String? ?? '',
          mediaUrl: mediaUrls.firstOrNull,
          mediaUrls: mediaUrls,
          createdAt: DateTime.parse(row['created_at'] as String),
          likes: likes.length,
          comments: comments.length,
          likedByMe: likes.any((like) => like['user_id'] == currentUserId),
          commentsEnabled: row['comments_enabled'] as bool? ?? true,
          mine: row['author_id'] == currentUserId,
        ),
      );
    }
    return result;
  }

  Future<void> createPost({
    required String body,
    required bool commentsEnabled,
    Uint8List? image,
    String extension = 'jpg',
    List<Uint8List> images = const [],
    List<String> extensions = const [],
  }) async {
    if (!isLive) {
      _demoPosts.insert(
        0,
        MapLovPost(
          id: _uuid.v4(),
          author: mockProfiles.first,
          body: body,
          createdAt: DateTime.now(),
          commentsEnabled: commentsEnabled,
        ),
      );
      return;
    }
    final row = await _client!
        .from('posts')
        .insert({
          'author_id': currentUserId!,
          'body': body.trim().isEmpty ? null : body.trim(),
          'comments_enabled': commentsEnabled,
        })
        .select('id')
        .single();
    final selectedImages = images.isNotEmpty
        ? images
        : image == null
        ? const <Uint8List>[]
        : [image];
    final selectedExtensions = extensions.isNotEmpty ? extensions : [extension];
    if (selectedImages.isNotEmpty) {
      final postId = row['id'] as String;
      for (var index = 0; index < selectedImages.length; index++) {
        final ext = index < selectedExtensions.length
            ? selectedExtensions[index]
            : 'jpg';
        _validateMedia(
          selectedImages[index],
          ext,
          allowed: const {'jpg', 'jpeg', 'png', 'webp'},
          maxBytes: 15 * 1024 * 1024,
        );
        final path = '${currentUserId!}/$postId/${_uuid.v4()}.$ext';
        await _client!.storage
            .from('post-media')
            .uploadBinary(path, selectedImages[index]);
        await _client!.from('post_media').insert({
          'post_id': postId,
          'storage_path': path,
          'display_order': index,
        });
      }
    }
  }

  Future<void> togglePostLike(MapLovPost post) async {
    if (!isLive) return;
    if (post.likedByMe) {
      await _client!
          .from('post_likes')
          .delete()
          .eq('post_id', post.id)
          .eq('user_id', currentUserId!);
    } else {
      await _client!.from('post_likes').insert({
        'post_id': post.id,
        'user_id': currentUserId!,
      });
    }
  }

  Future<void> addPostComment(String postId, String body) async {
    if (!isLive || body.trim().isEmpty) return;
    await _client!.from('post_comments').insert({
      'post_id': postId,
      'author_id': currentUserId!,
      'body': body.trim(),
    });
  }

  Future<List<PostCommentItem>> postComments(String postId) async {
    if (!isLive) {
      return [
        PostCommentItem(
          id: 'demo-comment',
          author: mockProfiles.first,
          body: 'This looks wonderful!',
          mine: false,
        ),
      ];
    }
    final rows = await _client!
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .isFilter('deleted_at', null)
        .order('created_at');
    final result = <PostCommentItem>[];
    for (final row in rows) {
      final author = await getProfile(row['author_id'] as String);
      if (author != null) {
        result.add(
          PostCommentItem(
            id: row['id'] as String,
            author: author,
            body: row['body'] as String,
            mine: row['author_id'] == currentUserId,
          ),
        );
      }
    }
    return result;
  }

  Future<void> updatePostComment(String id, String body) async {
    if (!isLive || body.trim().isEmpty) return;
    await _client!
        .from('post_comments')
        .update({'body': body.trim()})
        .eq('id', id)
        .eq('author_id', currentUserId!);
  }

  Future<void> deletePostComment(String id) async {
    if (!isLive) return;
    await _client!
        .from('post_comments')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('author_id', currentUserId!);
  }

  Future<void> deletePost(String id) async {
    if (!isLive) {
      _demoPosts.removeWhere((post) => post.id == id);
      return;
    }
    await _client!
        .from('posts')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('author_id', currentUserId!);
  }

  Future<List<GardenAlbumItem>> gardenAlbums({String? ownerId}) async {
    if (!isLive) {
      return [
        GardenAlbumItem(
          id: 'demo-garden',
          ownerId: ownerId ?? 'me',
          title: 'My private moments',
          photoCount: 6,
        ),
      ];
    }
    final List<dynamic> rows;
    if (ownerId != null && ownerId != currentUserId) {
      rows = List<dynamic>.from(
        await _client!.rpc(
          'garden_album_summaries',
          params: {'album_owner': ownerId},
        ),
      );
    } else {
      rows = await _client!
          .from('garden_albums')
          .select()
          .eq('owner_id', currentUserId!)
          .order('created_at');
    }
    final result = <GardenAlbumItem>[];
    final requestRows = ownerId != null && ownerId != currentUserId
        ? await _client!
              .from('garden_access_requests')
              .select('album_id, status, expires_at')
              .eq('requester_id', currentUserId!)
              .order('requested_at', ascending: false)
        : const <dynamic>[];
    for (final row in rows) {
      final count = row['photo_count'] as int?;
      final photos = count == null
          ? await _client!
                .from('garden_photos')
                .select('id')
                .eq('album_id', row['id'])
          : const <dynamic>[];
      result.add(
        GardenAlbumItem(
          id: row['id'] as String,
          ownerId: row['owner_id'] as String,
          title: row['title'] as String,
          description: row['description'] as String? ?? '',
          coverUrl: row['cover_path'] == null
              ? null
              : await _signedUrl('secret-garden', row['cover_path'] as String),
          photoCount: count ?? photos.length,
          accessStatus:
              requestRows
                      .where((request) => request['album_id'] == row['id'])
                      .firstOrNull?['status']
                  as String?,
          expiresAt: DateTime.tryParse(
            requestRows
                        .where((request) => request['album_id'] == row['id'])
                        .firstOrNull?['expires_at']
                    as String? ??
                '',
          ),
        ),
      );
    }
    return result;
  }

  Future<String> createGardenAlbum(String title) async {
    if (!isLive) return 'demo-garden';
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Album name is required.');
    }
    final requestStartedAt = DateTime.now().toUtc().subtract(
      const Duration(seconds: 5),
    );
    try {
      final result = await _client!.rpc(
        'create_my_garden_album',
        params: {'album_title': normalizedTitle},
      );
      if (result is String && result.isNotEmpty) return result;

      final created = await _confirmRecentGardenAlbum(
        title: normalizedTitle,
        createdAfter: requestStartedAt,
      );
      if (created != null) return created;
      throw StateError('The private album was created without an identifier.');
    } on PostgrestException catch (error) {
      final created = await _confirmRecentGardenAlbum(
        title: normalizedTitle,
        createdAfter: requestStartedAt,
      );
      if (created != null) return created;
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
      final row = await _client!
          .from('garden_albums')
          .insert({'owner_id': currentUserId!, 'title': normalizedTitle})
          .select('id')
          .single();
      return row['id'] as String;
    } catch (_) {
      final created = await _confirmRecentGardenAlbum(
        title: normalizedTitle,
        createdAfter: requestStartedAt,
      );
      if (created != null) return created;
      rethrow;
    }
  }

  Future<String?> _confirmRecentGardenAlbum({
    required String title,
    required DateTime createdAfter,
  }) async {
    try {
      final rows = await _client!
          .from('garden_albums')
          .select('id')
          .eq('owner_id', currentUserId!)
          .eq('title', title)
          .gte('created_at', createdAfter.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1);
      return rows.isEmpty ? null : rows.first['id'] as String;
    } catch (_) {
      return null;
    }
  }

  Future<void> uploadGardenPhoto({
    required String albumId,
    required Uint8List bytes,
    required String extension,
  }) async {
    _validateMedia(
      bytes,
      extension,
      allowed: const {'jpg', 'jpeg', 'png', 'webp'},
      maxBytes: 10 * 1024 * 1024,
    );
    if (!isLive) return;
    final existing = await _client!
        .from('garden_photos')
        .select('id')
        .eq('album_id', albumId);
    final path = '${currentUserId!}/$albumId/${_uuid.v4()}.$extension';
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw ArgumentError.value(extension, 'extension'),
    };
    await _client!.storage
        .from('secret-garden')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    try {
      await _client!.from('garden_photos').insert({
        'album_id': albumId,
        'owner_id': currentUserId!,
        'storage_path': path,
        'display_order': existing.length,
      });
    } catch (_) {
      await _client!.storage.from('secret-garden').remove([path]);
      rethrow;
    }
  }

  Future<List<String>> gardenPhotoUrls(String albumId) async {
    if (!isLive) {
      return mockProfiles.map((profile) => profile.imagePath).toList();
    }
    final rows = await _client!
        .from('garden_photos')
        .select('storage_path')
        .eq('album_id', albumId)
        .order('display_order');
    return Future.wait(
      rows.map(
        (row) => _signedUrl('secret-garden', row['storage_path'] as String),
      ),
    );
  }

  Future<void> requestGardenAccess(String albumId, int? seconds) async {
    if (!isLive) return;
    await _client!.from('garden_access_requests').insert({
      'album_id': albumId,
      'requester_id': currentUserId!,
      'requested_duration_seconds': seconds,
    });
  }

  Future<List<GardenRequestItem>> gardenRequests() async {
    if (!isLive) {
      return mockProfiles
          .take(2)
          .map(
            (profile) => GardenRequestItem(
              id: profile.id,
              albumId: 'demo-garden',
              requester: profile,
              status: 'pending',
              requestedSeconds: 600,
            ),
          )
          .toList();
    }
    final albums = await gardenAlbums();
    if (albums.isEmpty) return [];
    final rows = await _client!
        .from('garden_access_requests')
        .select()
        .inFilter('album_id', albums.map((a) => a.id).toList())
        .eq('status', 'pending');
    final result = <GardenRequestItem>[];
    for (final row in rows) {
      final requester = await getProfile(row['requester_id'] as String);
      if (requester != null) {
        result.add(
          GardenRequestItem(
            id: row['id'] as String,
            albumId: row['album_id'] as String,
            requester: requester,
            status: row['status'] as String,
            requestedSeconds: row['requested_duration_seconds'] as int?,
          ),
        );
      }
    }
    return result;
  }

  Future<void> respondGardenRequest(
    String id, {
    required bool allow,
    int? seconds,
  }) async {
    if (!isLive) return;
    final now = DateTime.now().toUtc();
    await _client!
        .from('garden_access_requests')
        .update({
          'status': allow ? 'approved' : 'declined',
          'responded_at': now.toIso8601String(),
          'granted_duration_seconds': allow ? seconds : null,
          'expires_at': allow && seconds != null
              ? now.add(Duration(seconds: seconds)).toIso8601String()
              : null,
        })
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> gardenAccessHistory() async {
    if (!isLive) return [];
    final albums = await gardenAlbums();
    if (albums.isEmpty) return [];
    return List<Map<String, dynamic>>.from(
      await _client!
          .from('garden_access_requests')
          .select()
          .inFilter('album_id', albums.map((album) => album.id).toList())
          .order('requested_at', ascending: false),
    );
  }

  Future<List<Map<String, dynamic>>> myGardenRequests() async {
    if (!isLive) return [];
    return List<Map<String, dynamic>>.from(
      await _client!
          .from('garden_access_requests')
          .select()
          .eq('requester_id', currentUserId!)
          .order('requested_at', ascending: false),
    );
  }

  Future<void> revokeGardenAccess(String requestId) async {
    if (!isLive) return;
    await _client!
        .from('garden_access_requests')
        .update({
          'status': 'revoked',
          'revoked_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId);
  }

  Future<void> renameGardenAlbum(String id, String title) async {
    if (!isLive || title.trim().isEmpty) return;
    await _client!
        .from('garden_albums')
        .update({'title': title.trim()})
        .eq('id', id)
        .eq('owner_id', currentUserId!);
  }

  Future<void> deleteGardenAlbum(String id) async {
    if (!isLive) return;
    final photos = await _client!
        .from('garden_photos')
        .select('storage_path')
        .eq('album_id', id);
    if (photos.isNotEmpty) {
      await _client!.storage
          .from('secret-garden')
          .remove(
            photos.map((photo) => photo['storage_path'] as String).toList(),
          );
    }
    await _client!
        .from('garden_albums')
        .delete()
        .eq('id', id)
        .eq('owner_id', currentUserId!);
  }

  Future<void> deleteGardenPhoto(String id, String path) async {
    if (!isLive) return;
    await _client!.from('garden_photos').delete().eq('id', id);
    await _client!.storage.from('secret-garden').remove([path]);
  }

  Future<List<Map<String, dynamic>>> gardenPhotos(String albumId) async {
    if (!isLive) return [];
    final rows = await _client!
        .from('garden_photos')
        .select()
        .eq('album_id', albumId)
        .order('display_order');
    return Future.wait(
      rows.map((row) async {
        final value = Map<String, dynamic>.from(row);
        value['url'] = await _signedUrl(
          'secret-garden',
          row['storage_path'] as String,
        );
        return value;
      }),
    );
  }

  Future<void> blockUser(String userId) async {
    if (!isLive) {
      _demoBlockedIds.add(userId);
      return;
    }
    await _client!.from('blocks').insert({
      'blocker_id': currentUserId!,
      'blocked_id': userId,
    });
  }

  Future<void> unblockUser(String userId) async {
    if (!isLive) {
      _demoBlockedIds.remove(userId);
      return;
    }
    await _client!
        .from('blocks')
        .delete()
        .eq('blocker_id', currentUserId!)
        .eq('blocked_id', userId);
  }

  Future<List<UserProfile>> blockedUsers() async {
    if (!isLive) {
      return mockProfiles.where((p) => _demoBlockedIds.contains(p.id)).toList();
    }
    final rows = await _client!
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', currentUserId!);
    final result = <UserProfile>[];
    for (final row in rows) {
      final profile = await getProfile(row['blocked_id'] as String);
      if (profile != null) result.add(profile);
    }
    return result;
  }

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? comment,
  }) async {
    if (!isLive) return;
    await _client!.from('reports').insert({
      'reporter_id': currentUserId!,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'comment': comment,
    });
  }

  /// Returns false when this account has already reported the same photo.
  Future<bool> reportPhoto(String photoId) async {
    if (!isLive) return _demoReportedPhotoIds.add(photoId);
    try {
      await report(
        targetType: 'photo',
        targetId: photoId,
        reason: 'Inappropriate photo',
        comment: 'Reported from the full-screen photo viewer.',
      );
      return true;
    } on PostgrestException catch (error) {
      if (error.code == '23505') return false;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> moderatedPhotoQueue() async {
    if (!isLive) return [];
    final cases = List<Map<String, dynamic>>.from(
      await _client!
          .from('photo_moderation_cases')
          .select()
          .eq('status', 'under_review')
          .order('opened_at'),
    );
    final result = <Map<String, dynamic>>[];
    for (final moderationCase in cases) {
      final photo = await _client!
          .from('profile_photos')
          .select('id, user_id, storage_path, moderation_status, hidden_at')
          .eq('id', moderationCase['photo_id'])
          .maybeSingle();
      if (photo == null) continue;
      final reports = List<Map<String, dynamic>>.from(
        await _client!
            .from('reports')
            .select('id, reporter_id, reason, comment, status, created_at')
            .eq('target_type', 'photo')
            .eq('target_id', moderationCase['photo_id'])
            .order('created_at'),
      );
      result.add({
        ...moderationCase,
        'photo': photo,
        'url': await _signedUrl(
          'profile-media',
          photo['storage_path'] as String,
        ),
        'reports': reports,
      });
    }
    return result;
  }

  Future<void> approveModeratedPhoto(String photoId, {String? notes}) async {
    if (!isLive) return;
    await _client!
        .from('profile_photos')
        .update({
          'moderation_status': 'visible',
          'hidden_at': null,
          'moderation_notes': notes,
        })
        .eq('id', photoId);
    await _client!
        .from('photo_moderation_cases')
        .update({
          'status': 'approved',
          'decided_at': DateTime.now().toUtc().toIso8601String(),
          'decided_by': currentUserId!,
          'decision_notes': notes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('photo_id', photoId);
    await _client!
        .from('reports')
        .update({
          'status': 'dismissed',
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          'resolution_notes': notes ?? 'Photo approved by moderation.',
        })
        .eq('target_type', 'photo')
        .eq('target_id', photoId)
        .inFilter('status', ['open', 'under_review']);
    await _client!.from('admin_actions').insert({
      'admin_id': currentUserId!,
      'action': 'photo_approved',
      'target_type': 'photo',
      'target_id': photoId,
    });
  }

  Future<void> deleteModeratedPhoto(String photoId) async {
    if (!isLive) return;
    final photo = await _client!
        .from('profile_photos')
        .select('storage_path')
        .eq('id', photoId)
        .maybeSingle();
    if (photo == null) return;
    await _client!
        .from('reports')
        .update({
          'status': 'resolved',
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          'resolution_notes': 'Photo permanently removed by moderation.',
        })
        .eq('target_type', 'photo')
        .eq('target_id', photoId)
        .inFilter('status', ['open', 'under_review']);
    await _client!.from('profile_photos').delete().eq('id', photoId);
    await _client!.storage.from('profile-media').remove([
      photo['storage_path'] as String,
    ]);
    await _client!.from('admin_actions').insert({
      'admin_id': currentUserId!,
      'action': 'photo_removed',
      'target_type': 'photo',
      'target_id': photoId,
    });
  }

  Future<List<Map<String, dynamic>>> moderationReports() async {
    if (!isLive) return [];
    return List<Map<String, dynamic>>.from(
      await _client!
          .from('reports')
          .select()
          .order('created_at', ascending: false),
    );
  }

  Future<void> moderateReport(String id, String status, {String? notes}) async {
    if (!isLive) return;
    final resolved = status == 'resolved' || status == 'dismissed';
    await _client!
        .from('reports')
        .update({
          'status': status,
          'resolved_at': resolved
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          'resolution_notes': notes?.trim().isEmpty == true ? null : notes,
        })
        .eq('id', id);
    await _client!.from('admin_actions').insert({
      'admin_id': currentUserId!,
      'action': 'report_$status',
      'target_type': 'report',
      'target_id': id,
    });
  }

  Future<List<Map<String, dynamic>>> adminUsers() async {
    if (!isLive) return [];
    return List<Map<String, dynamic>>.from(
      await _client!
          .from('profiles')
          .select('id, first_name, city, role, status, created_at')
          .order('created_at', ascending: false),
    );
  }

  Future<void> setAccountStatus(String userId, String status) async {
    if (!isLive) return;
    await _client!.from('profiles').update({'status': status}).eq('id', userId);
    await _client!.from('admin_actions').insert({
      'admin_id': currentUserId!,
      'action': 'account_$status',
      'target_type': 'user',
      'target_id': userId,
    });
  }

  Future<List<Map<String, dynamic>>> adminAuditLog() async {
    if (!isLive) return [];
    return List<Map<String, dynamic>>.from(
      await _client!
          .from('admin_actions')
          .select()
          .order('created_at', ascending: false)
          .limit(200),
    );
  }

  Stream<List<MapLovNotification>> watchNotifications() {
    if (!isLive) return Stream.value(List.unmodifiable(_demoNotifications));
    return _client!
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUserId!)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map(
                (row) => MapLovNotification(
                  id: row['id'] as String,
                  title: row['title'] as String,
                  body: row['body'] as String,
                  kind: row['kind'] as String,
                  createdAt: DateTime.parse(row['created_at'] as String),
                  isRead: row['read_at'] != null,
                  entityType: row['entity_type'] as String?,
                  entityId: row['entity_id'] as String?,
                  archived: row['archived_at'] != null,
                ),
              )
              .where((item) => !item.archived)
              .toList(),
        );
  }

  Future<void> markNotificationsRead() async {
    if (!isLive) {
      for (var i = 0; i < _demoNotifications.length; i++) {
        final item = _demoNotifications[i];
        _demoNotifications[i] = MapLovNotification(
          id: item.id,
          title: item.title,
          body: item.body,
          kind: item.kind,
          createdAt: item.createdAt,
          isRead: true,
        );
      }
      return;
    }
    await _client!
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', currentUserId!)
        .isFilter('read_at', null);
  }

  Future<void> markNotificationRead(String id) async {
    if (!isLive) return;
    await _client!
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  Future<void> archiveNotification(String id) async {
    if (!isLive) {
      _demoNotifications.removeWhere((item) => item.id == id);
      return;
    }
    await _client!
        .from('notifications')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  Future<void> deleteNotification(String id) async {
    if (!isLive) {
      _demoNotifications.removeWhere((item) => item.id == id);
      return;
    }
    await _client!
        .from('notifications')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  Future<Map<String, bool>> notificationPreferences() async {
    const defaults = {
      'messages': true,
      'friend_requests': true,
      'post_activity': true,
      'garden_requests': true,
      'compatibility_suggestions': false,
      'marketing': false,
      'security': true,
      'push_enabled': true,
      'in_app_enabled': true,
      'email_important': true,
      'quiet_hours_enabled': false,
    };
    if (!isLive) return defaults;
    final row = await _client!
        .from('notification_preferences')
        .select()
        .eq('user_id', currentUserId!)
        .maybeSingle();
    if (row == null) return defaults;
    return {
      for (final key in defaults.keys) key: row[key] as bool? ?? defaults[key]!,
    };
  }

  Future<void> saveNotificationPreferences(Map<String, bool> values) async {
    if (!isLive) return;
    await _client!.from('notification_preferences').upsert({
      'user_id': currentUserId!,
      ...values,
    });
  }

  Future<Map<String, dynamic>?> currentAccount() async {
    if (!isLive) return {'status': 'active', 'role': 'user'};
    return _client!
        .from('profiles')
        .select('status, role, profile_completed_at')
        .eq('id', currentUserId!)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> exportMyData() async {
    if (!isLive) {
      return {
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'profile': {'id': 'demo', 'first_name': 'Demo user'},
        'notice': 'Demo export. No server data was accessed.',
      };
    }
    final value = await _client!.rpc('export_my_data');
    return Map<String, dynamic>.from(value as Map);
  }

  Future<SubscriptionInfo> subscriptionInfo() async {
    if (!isLive) return const SubscriptionInfo();
    final rows = await _client!
        .from('subscriptions')
        .select()
        .eq('user_id', currentUserId!)
        .order('created_at', ascending: false);
    final history = List<Map<String, dynamic>>.from(rows);
    final current = history
        .where((item) => item['is_current'] == true)
        .firstOrNull;
    return SubscriptionInfo(
      tier: current?['tier'] as String? ?? 'free',
      status: current?['status'] as String? ?? 'active',
      renewsAt: DateTime.tryParse(
        current?['current_period_end'] as String? ?? '',
      ),
      history: history,
    );
  }

  Future<void> recordProfileView(String profileId) async {
    if (!isLive || profileId == currentUserId) return;
    await _client!.from('profile_views').insert({
      'viewer_id': currentUserId!,
      'viewed_id': profileId,
    });
  }

  Future<List<UserProfile>> profileVisitors() async {
    if (!isLive) return mockProfiles.take(2).toList();
    final rows = await _client!
        .from('profile_views')
        .select('viewer_id, viewed_at')
        .eq('viewed_id', currentUserId!)
        .order('viewed_at', ascending: false)
        .limit(100);
    final result = <UserProfile>[];
    final seen = <String>{};
    for (final row in rows) {
      final id = row['viewer_id'] as String;
      if (seen.add(id)) {
        final profile = await getProfile(id);
        if (profile != null) result.add(profile);
      }
    }
    return result;
  }

  Future<Map<String, int>> profileStatistics() async {
    if (!isLive) {
      return const {'views': 24, 'likes': 8, 'matches': 3, 'messages': 4};
    }
    final views = await _client!
        .from('profile_views')
        .select('viewer_id')
        .eq('viewed_id', currentUserId!);
    final likes = await _client!
        .from('profile_likes')
        .select('liker_id')
        .eq('liked_id', currentUserId!);
    final matches = await _client!
        .from('matches')
        .select('id')
        .or('user_a.eq.$currentUserId,user_b.eq.$currentUserId');
    final conversations = await _client!
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', currentUserId!);
    return {
      'views': views.length,
      'likes': likes.length,
      'matches': matches.length,
      'messages': conversations.length,
    };
  }

  Future<Map<String, int>> adminMetrics() async {
    if (!isLive) return const {'reports': 0, 'review': 0, 'users': 0};
    final reports = await _client!.from('reports').select('id, status');
    final users = await _client!.from('profiles').select('id');
    return {
      'reports': reports.where((item) => item['status'] == 'open').length,
      'review': reports
          .where((item) => item['status'] == 'under_review')
          .length,
      'users': users.length,
    };
  }

  Future<void> verifyProfile(String userId, {bool photo = false}) async {
    if (!isLive) return;
    await _client!
        .from('profiles')
        .update({photo ? 'is_photo_verified' : 'is_verified': true})
        .eq('id', userId);
    await _client!.from('admin_actions').insert({
      'admin_id': currentUserId!,
      'action': photo ? 'photo_verified' : 'profile_verified',
      'target_type': 'user',
      'target_id': userId,
    });
  }

  Future<void> adminRemoveContent(String type, String id) async {
    if (!isLive) return;
    if (type == 'post') {
      await _client!
          .from('posts')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } else if (type == 'comment') {
      await _client!
          .from('post_comments')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } else if (type == 'photo') {
      await _client!.from('profile_photos').delete().eq('id', id);
    } else if (type == 'message') {
      await _client!
          .from('messages')
          .update({
            'body': null,
            'media_path': null,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    }
    await _client!.from('admin_actions').insert({
      'admin_id': currentUserId!,
      'action': 'content_removed',
      'target_type': type,
      'target_id': id,
    });
  }

  Future<UserProfile> _profileFromRow(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    var isVip = false;
    try {
      isVip =
          await _client!.rpc('is_vip_profile', params: {'target_user': id})
              as bool? ??
          false;
    } on PostgrestException {
      // Remains compatible while the additive subscription migration deploys.
    }
    final photos = await _client!
        .from('profile_photos')
        .select(
          'id, storage_path, is_primary, created_at, photo_likes(count), '
          'photo_super_likes(count), photo_comments(count)',
        )
        .eq('user_id', id)
        .eq('moderation_status', 'visible')
        .order('is_primary', ascending: false)
        .order('display_order');
    final urls = <String>[];
    final photoIds = <String>[];
    final likeCounts = <int>[];
    final superLikeCounts = <int>[];
    final commentCounts = <int>[];
    final photoCreatedAts = <DateTime?>[];
    for (final photo in photos) {
      photoIds.add(photo['id'] as String);
      likeCounts.add(_embeddedCount(photo['photo_likes']));
      superLikeCounts.add(_embeddedCount(photo['photo_super_likes']));
      commentCounts.add(_embeddedCount(photo['photo_comments']));
      photoCreatedAts.add(
        DateTime.tryParse(photo['created_at'] as String? ?? ''),
      );
      urls.add(
        await _signedUrl('profile-media', photo['storage_path'] as String),
      );
    }
    final birth = DateTime.tryParse(row['date_of_birth'] as String? ?? '');
    final now = DateTime.now();
    final age =
        row['age'] as int? ??
        (birth == null
            ? 18
            : now.year -
                  birth.year -
                  ((now.month < birth.month ||
                          (now.month == birth.month && now.day < birth.day))
                      ? 1
                      : 0));
    final style = row['photo_display_style'] == 'social'
        ? PhotoDisplayStyle.social
        : PhotoDisplayStyle.profileDetails;
    final lastActive = DateTime.tryParse(
      row['last_active_at'] as String? ?? '',
    );
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    final presenceIsFresh =
        lastActive != null && now.difference(lastActive).inMinutes < 3;
    final presenceFlag = row['is_online'] as bool? ?? false;
    final showOnline =
        row['show_online_status'] as bool? ?? row.containsKey('is_online');
    return UserProfile(
      id: id,
      name: row['first_name'] as String? ?? 'MapLov member',
      age: age,
      city: row['city'] as String? ?? '',
      country: row['country_name'] as String? ?? '',
      originCountry: row['origin_country_name'] as String? ?? '',
      originCity: row['origin_city'] as String? ?? '',
      compatibilityScore: 80,
      imagePath: urls.isEmpty
          ? 'assets/profile/profile_user_placeholder.png'
          : urls.first,
      photoUrls: urls,
      photoIds: photoIds,
      photoLikeCounts: likeCounts,
      photoSuperLikeCounts: superLikeCounts,
      photoCommentCounts: commentCounts,
      photoCreatedAts: photoCreatedAts,
      photoDisplayStyle: style,
      profession: row['profession'] as String? ?? 'MapLov member',
      distanceKm: ((row['distance_km'] as num?)?.round() ?? 5),
      isOnline: showOnline && presenceFlag && presenceIsFresh,
      isNew:
          createdAt?.isAfter(now.subtract(const Duration(days: 28))) ?? false,
      bio: row['bio'] as String? ?? '',
      isVerified: row['is_verified'] as bool? ?? false,
      isVip: isVip,
      gender: row['gender'] as String? ?? '',
      languages: List<String>.from(row['spoken_languages'] ?? const []),
      relationshipGoal: row['relationship_goal'] as String? ?? '',
      interests: List<String>.from(row['interest_slugs'] ?? const []),
      religion: row['religion'] as String? ?? '',
      bodyType: row['body_type'] as String? ?? '',
      eyeColor: row['eye_color'] as String? ?? '',
      hairColor: row['hair_color'] as String? ?? '',
      heightCm: row['height_cm'] as int?,
      childrenPreference: row['children_preference'] as String? ?? '',
      relationshipStatus: row['relationship_status'] as String? ?? '',
      educationLevel: row['education_level'] as String? ?? '',
      beardStyle: row['beard_style'] as String? ?? '',
      smokingStatus: row['smoking_status'] as String? ?? '',
      incomeLevel: row['income_level'] as String? ?? '',
      isPhotoVerified: row['is_photo_verified'] as bool? ?? false,
      allowsInternationalDiscovery:
          row['allow_international_discovery'] as bool? ?? true,
      lastActiveAt: lastActive,
      createdAt: createdAt,
    );
  }

  Future<List<R>> _mapInBatches<T, R>(
    Iterable<T> values,
    Future<R> Function(T value) mapper, {
    int batchSize = 8,
  }) async {
    final input = values.toList(growable: false);
    final result = <R>[];
    for (var start = 0; start < input.length; start += batchSize) {
      final proposedEnd = start + batchSize;
      final end = proposedEnd < input.length ? proposedEnd : input.length;
      result.addAll(await Future.wait(input.sublist(start, end).map(mapper)));
    }
    return result;
  }

  int _embeddedCount(dynamic value) {
    if (value is List && value.isNotEmpty) {
      final count = value.first is Map ? value.first['count'] : null;
      return (count as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  UserProfile _copyProfile(
    UserProfile value, {
    int? compatibilityScore,
    Map<String, dynamic>? compatibilityBreakdown,
    bool? likedByMe,
    int? distanceKm,
  }) => UserProfile(
    id: value.id,
    name: value.name,
    age: value.age,
    city: value.city,
    country: value.country,
    originCountry: value.originCountry,
    originCity: value.originCity,
    compatibilityScore: compatibilityScore ?? value.compatibilityScore,
    imagePath: value.imagePath,
    photoUrls: value.photoUrls,
    photoIds: value.photoIds,
    photoLikeCounts: value.photoLikeCounts,
    photoSuperLikeCounts: value.photoSuperLikeCounts,
    photoCommentCounts: value.photoCommentCounts,
    photoCreatedAts: value.photoCreatedAts,
    photoDisplayStyle: value.photoDisplayStyle,
    profession: value.profession,
    distanceKm: distanceKm ?? value.distanceKm,
    isOnline: value.isOnline,
    isNew: value.isNew,
    bio: value.bio,
    isVerified: value.isVerified,
    isVip: value.isVip,
    gender: value.gender,
    languages: value.languages,
    relationshipGoal: value.relationshipGoal,
    interests: value.interests,
    religion: value.religion,
    bodyType: value.bodyType,
    eyeColor: value.eyeColor,
    hairColor: value.hairColor,
    heightCm: value.heightCm,
    childrenPreference: value.childrenPreference,
    relationshipStatus: value.relationshipStatus,
    educationLevel: value.educationLevel,
    beardStyle: value.beardStyle,
    smokingStatus: value.smokingStatus,
    incomeLevel: value.incomeLevel,
    isPhotoVerified: value.isPhotoVerified,
    allowsInternationalDiscovery: value.allowsInternationalDiscovery,
    compatibilityBreakdown:
        compatibilityBreakdown ?? value.compatibilityBreakdown,
    likedByMe: likedByMe ?? value.likedByMe,
    lastActiveAt: value.lastActiveAt,
    createdAt: value.createdAt,
  );

  Future<MapLovMessage> _messageFromRow(
    Map<String, dynamic> row, {
    DateTime? otherReadAt,
  }) async {
    String? mediaUrl;
    final path = row['media_path'] as String?;
    if (path != null) mediaUrl = await _signedUrl('chat-media', path);
    final createdAt = DateTime.parse(row['created_at'] as String);
    return MapLovMessage(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      kind: row['kind'] as String,
      body: row['body'] as String?,
      mediaUrl: mediaUrl,
      createdAt: createdAt,
      deleted: row['deleted_at'] != null,
      read:
          row['sender_id'] == currentUserId &&
          otherReadAt != null &&
          !createdAt.isAfter(otherReadAt),
    );
  }

  Future<String> _signedUrl(String bucket, String path) =>
      _client!.storage.from(bucket).createSignedUrl(path, 3600);

  void _validateMedia(
    Uint8List bytes,
    String extension, {
    required Set<String> allowed,
    required int maxBytes,
  }) {
    final normalized = extension.toLowerCase().replaceAll('.', '');
    if (!allowed.contains(normalized)) {
      throw ArgumentError('Unsupported media format: $normalized');
    }
    if (bytes.isEmpty || bytes.lengthInBytes > maxBytes) {
      throw ArgumentError('The selected media file is empty or too large.');
    }
    final signatureMatches = switch (normalized) {
      'jpg' || 'jpeg' =>
        bytes.length >= 3 &&
            bytes[0] == 0xff &&
            bytes[1] == 0xd8 &&
            bytes[2] == 0xff,
      'png' =>
        bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4e &&
            bytes[3] == 0x47,
      'webp' =>
        bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP',
      'm4a' =>
        bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp',
      'aac' =>
        bytes.length >= 2 &&
            bytes[0] == 0xff &&
            (bytes[1] == 0xf1 || bytes[1] == 0xf9),
      'mp3' =>
        bytes.length >= 3 &&
            (String.fromCharCodes(bytes.sublist(0, 3)) == 'ID3' ||
                (bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0)),
      'ogg' =>
        bytes.length >= 4 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'OggS',
      _ => false,
    };
    if (!signatureMatches) {
      throw ArgumentError('The file content does not match its extension.');
    }
  }
}
