enum PhotoDisplayStyle { profileDetails, social }

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
    this.bio = '',
    this.photoUrls = const [],
    this.photoIds = const [],
    this.isVerified = false,
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
  final String bio;
  final List<String> photoUrls;
  final List<String> photoIds;
  final bool isVerified;

  bool get hasNetworkImage =>
      imagePath.startsWith('http://') || imagePath.startsWith('https://');
}
