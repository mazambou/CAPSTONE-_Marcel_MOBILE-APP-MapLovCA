import '../config/app_config.dart';
import '../models/user_profile.dart';

// Offline/demo fallback. MapLovRepository replaces these rows with PostgreSQL
// data whenever a configured Supabase session is available.
PhotoDisplayStyle currentUserPhotoDisplayStyle =
    PhotoDisplayStyle.profileDetails;

const unavailableProfile = UserProfile(
  id: 'unavailable',
  name: 'Profile unavailable',
  age: 18,
  city: '',
  compatibilityScore: 0,
  imagePath: 'assets/profile/profile_user_placeholder.png',
  photoDisplayStyle: PhotoDisplayStyle.profileDetails,
);

UserProfile get demoProfileOrUnavailable =>
    AppConfig.allowDemoData ? mockProfiles.first : unavailableProfile;

const mockProfiles = [
  UserProfile(
    id: '00000000-0000-4000-8000-000000000001',
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
    id: '00000000-0000-4000-8000-000000000002',
    name: 'Alex',
    age: 30,
    city: 'Montréal',
    compatibilityScore: 89,
    imagePath: 'assets/avatars/story_02.png',
    photoDisplayStyle: PhotoDisplayStyle.social,
    photoLikeCounts: [24],
    photoSuperLikeCounts: [3],
    photoCommentCounts: [2],
    profession: 'Graphic Designer',
    distanceKm: 5,
  ),
  UserProfile(
    id: '00000000-0000-4000-8000-000000000003',
    name: 'Taylor',
    age: 29,
    city: 'Vancouver',
    compatibilityScore: 86,
    imagePath: 'assets/avatars/story_sophie.png',
    photoDisplayStyle: PhotoDisplayStyle.social,
    photoLikeCounts: [18],
    photoSuperLikeCounts: [2],
    photoCommentCounts: [5],
    profession: 'Teacher',
    distanceKm: 7,
  ),
  UserProfile(
    id: '00000000-0000-4000-8000-000000000004',
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
    id: '00000000-0000-4000-8000-000000000005',
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
    id: '00000000-0000-4000-8000-000000000006',
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
