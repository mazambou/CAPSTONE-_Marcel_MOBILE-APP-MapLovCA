enum PhotoDisplayStyle { profileDetails, social }

bool newAccountVisibleToTier({
  required DateTime createdAt,
  required String viewerTier,
  required bool isOwner,
  DateTime? now,
}) {
  if (isOwner) return true;
  final age = (now ?? DateTime.now()).toUtc().difference(createdAt.toUtc());
  final vip = viewerTier == 'vip' || viewerTier == 'elite';
  if (age < const Duration(days: 7)) return vip;
  if (age < const Duration(days: 14)) return vip || viewerTier == 'plus';
  return true;
}

class UserProfile {
  const UserProfile({
    this.id = '',
    required this.name,
    required this.age,
    required this.city,
    required this.compatibilityScore,
    required this.imagePath,
    required this.photoDisplayStyle,
    this.profession = 'MapLov member',
    this.distanceKm = 5,
    this.isOnline = true,
    this.isNew = false,
    this.country = 'Canada',
    this.originCountry = '',
    this.originCity = '',
    this.bio = '',
    this.photoUrls = const [],
    this.photoIds = const [],
    this.photoLikeCounts = const [],
    this.photoSuperLikeCounts = const [],
    this.photoCommentCounts = const [],
    this.photoCreatedAts = const [],
    this.isVerified = false,
    this.isVip = false,
    this.gender = '',
    this.languages = const [],
    this.relationshipGoal = '',
    this.interests = const [],
    this.religion = '',
    this.bodyType = '',
    this.eyeColor = '',
    this.hairColor = '',
    this.heightCm,
    this.compatibilityBreakdown = const {},
    this.likedByMe = false,
    this.lastActiveAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final int age;
  final String city;
  final int compatibilityScore;
  final String imagePath;
  final PhotoDisplayStyle photoDisplayStyle;
  final String profession;
  final int distanceKm;
  final bool isOnline;
  final bool isNew;
  final String country;
  final String originCountry;
  final String originCity;
  final String bio;
  final List<String> photoUrls;
  final List<String> photoIds;
  final List<int> photoLikeCounts;
  final List<int> photoSuperLikeCounts;
  final List<int> photoCommentCounts;
  final List<DateTime?> photoCreatedAts;
  final bool isVerified;
  final bool isVip;
  final String gender;
  final List<String> languages;
  final String relationshipGoal;
  final List<String> interests;
  final String religion;
  final String bodyType;
  final String eyeColor;
  final String hairColor;
  final int? heightCm;
  final Map<String, dynamic> compatibilityBreakdown;
  final bool likedByMe;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;

  int photoLikeCount(int index) =>
      index < photoLikeCounts.length ? photoLikeCounts[index] : 0;
  int photoSuperLikeCount(int index) =>
      index < photoSuperLikeCounts.length ? photoSuperLikeCounts[index] : 0;
  int photoCommentCount(int index) =>
      index < photoCommentCounts.length ? photoCommentCounts[index] : 0;
  DateTime? photoCreatedAt(int index) =>
      index < photoCreatedAts.length ? photoCreatedAts[index] : createdAt;

  int get engagementScore {
    var highest = 0;
    final count = photoUrls.isEmpty ? 1 : photoUrls.length;
    for (var index = 0; index < count; index++) {
      final score =
          photoLikeCount(index) +
          photoSuperLikeCount(index) +
          photoCommentCount(index);
      if (score > highest) highest = score;
    }
    return highest;
  }

  bool get hasNetworkImage =>
      imagePath.startsWith('http://') || imagePath.startsWith('https://');
}

class PopularPhotoEntry {
  const PopularPhotoEntry({required this.profile, required this.photoIndex});

  final UserProfile profile;
  final int photoIndex;

  String get photoUrl => profile.photoUrls.isEmpty
      ? profile.imagePath
      : profile.photoUrls[photoIndex];
  String get stableId => profile.photoIds.length > photoIndex
      ? profile.photoIds[photoIndex]
      : '${profile.id}-$photoIndex';
  int get likeCount => profile.photoLikeCount(photoIndex);
  DateTime? get createdAt => profile.photoCreatedAt(photoIndex);
}
