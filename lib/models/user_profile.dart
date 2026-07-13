enum PhotoDisplayStyle { profileDetails, social }

class UserProfile {
  const UserProfile({
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
  });

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
}
