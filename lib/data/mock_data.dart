import '../models/user_profile.dart';

// TODO(Supabase): Replace these local profiles with backend data.
PhotoDisplayStyle currentUserPhotoDisplayStyle =
    PhotoDisplayStyle.profileDetails;

const mockProfiles = [
  UserProfile(
    name: 'Sophie',
    age: 27,
    city: 'Toronto',
    compatibilityScore: 94,
    imagePath: 'assets/avatars/story_sophie.png',
    photoDisplayStyle: PhotoDisplayStyle.profileDetails,
    profession: 'Marketing Manager',
    distanceKm: 3,
    isNew: true,
  ),
  UserProfile(
    name: 'Alex',
    age: 30,
    city: 'Montréal',
    compatibilityScore: 89,
    imagePath: 'assets/avatars/story_02.png',
    photoDisplayStyle: PhotoDisplayStyle.social,
    profession: 'Graphic Designer',
    distanceKm: 5,
  ),
  UserProfile(
    name: 'Taylor',
    age: 29,
    city: 'Vancouver',
    compatibilityScore: 86,
    imagePath: 'assets/avatars/story_sophie.png',
    photoDisplayStyle: PhotoDisplayStyle.social,
    profession: 'Teacher',
    distanceKm: 7,
  ),
  UserProfile(
    name: 'Olivia',
    age: 24,
    city: 'Victoria',
    compatibilityScore: 91,
    imagePath: 'assets/avatars/story_sophie.png',
    photoDisplayStyle: PhotoDisplayStyle.profileDetails,
    profession: 'Student',
    distanceKm: 8,
  ),
  UserProfile(
    name: 'Ava',
    age: 28,
    city: 'Québec City',
    compatibilityScore: 88,
    imagePath: 'assets/avatars/story_02.png',
    photoDisplayStyle: PhotoDisplayStyle.social,
    profession: 'Product Manager',
    distanceKm: 10,
    isNew: true,
  ),
  UserProfile(
    name: 'Mia',
    age: 24,
    city: 'Whistler',
    compatibilityScore: 84,
    imagePath: 'assets/avatars/story_02.png',
    photoDisplayStyle: PhotoDisplayStyle.profileDetails,
    profession: 'Photographer',
    distanceKm: 12,
  ),
];
