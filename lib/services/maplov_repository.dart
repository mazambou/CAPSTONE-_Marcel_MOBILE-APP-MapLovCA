import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
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
    this.languages = const [],
    this.relationshipGoals = const [],
    this.verifiedOnly = false,
    this.activeTodayOnly = false,
  });

  final int minimumAge;
  final int maximumAge;
  final int distanceKm;
  final String locationMode;
  final List<String> countries;
  final List<String> cities;
  final List<String> languages;
  final List<String> relationshipGoals;
  final bool verifiedOnly;
  final bool activeTodayOnly;

  Map<String, Object> toDatabase() => {
    'minimum_age': minimumAge,
    'maximum_age': maximumAge,
    'distance_km': distanceKm,
    'location_mode': locationMode,
    'country_codes': countries,
    'cities': cities,
    'languages': languages,
    'relationship_goals': relationshipGoals,
    'verified_only': verifiedOnly,
    'active_today_only': activeTodayOnly,
  };
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
    this.deleted = false,
  });
  final String id;
  final String senderId;
  final String kind;
  final String? body;
  final String? mediaUrl;
  final DateTime createdAt;
  final bool deleted;
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
}

class GardenAlbumItem {
  const GardenAlbumItem({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description = '',
    this.coverUrl,
    this.photoCount = 0,
  });
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String? coverUrl;
  final int photoCount;
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
  });
  final String id;
  final String title;
  final String body;
  final String kind;
  final DateTime createdAt;
  final bool isRead;
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
  final Set<String> _demoFriendIds = {};
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

  SupabaseClient? get _client {
    if (!AppConfig.hasSupabaseConfiguration) return null;
    return Supabase.instance.client;
  }

  String? get currentUserId => _client?.auth.currentUser?.id;
  bool get isLive => _client != null && currentUserId != null;

  Future<List<UserProfile>> discoverProfiles({
    String tab = 'Discover',
    DiscoveryFilters filters = const DiscoveryFilters(),
  }) async {
    if (!isLive) {
      return mockProfiles.where((profile) {
        if (_demoBlockedIds.contains(profile.id)) return false;
        if (profile.age < filters.minimumAge ||
            profile.age > filters.maximumAge) {
          return false;
        }
        if (profile.distanceKm > filters.distanceKm &&
            filters.locationMode == 'near_me') {
          return false;
        }
        if (tab == 'Nearby' && profile.distanceKm > 10) return false;
        if (tab == 'Online' && !profile.isOnline) return false;
        if (tab == 'New' && !profile.isNew) return false;
        return true;
      }).toList();
    }

    if (tab == 'Nearby' || filters.locationMode == 'near_me') {
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
        final result = <UserProfile>[];
        for (final raw in nearby.cast<Map<String, dynamic>>()) {
          result.add(await _profileFromRow(raw));
        }
        return result;
      } on PostgrestException {
        // A new account may not have shared its position yet. Continue with
        // discovery instead of making the page unusable.
      }
    }

    final rows = await _client!
        .from('profiles')
        .select()
        .neq('id', currentUserId!)
        .eq('status', 'active')
        .eq('is_discoverable', true)
        .limit(100);
    final profiles = <UserProfile>[];
    for (final row in rows) {
      final profile = await _profileFromRow(row);
      if (profile.age < filters.minimumAge ||
          profile.age > filters.maximumAge) {
        continue;
      }
      if (tab == 'Online' && !profile.isOnline) continue;
      if (tab == 'New' && !profile.isNew) continue;
      if (filters.verifiedOnly && !profile.isVerified) continue;
      if (filters.cities.isNotEmpty && !filters.cities.contains(profile.city)) {
        continue;
      }
      profiles.add(profile);
    }
    return profiles;
  }

  Future<UserProfile?> getProfile(String id) async {
    if (!isLive) {
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
    await _client!.from('profiles').update(values).eq('id', currentUserId!);
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
    if (!isLive) return;
    final userId = currentUserId!;
    final existing = await _client!
        .from('profile_photos')
        .select('id, storage_path, display_order, is_primary')
        .eq('user_id', userId)
        .order('display_order');
    final path = '$userId/${_uuid.v4()}.$extension';
    await _client!.storage
        .from('profile-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );
    try {
      await _client!.from('profile_photos').insert({
        'user_id': userId,
        'storage_path': path,
        'display_order': existing.length,
        'is_primary': existing.isEmpty,
      });
    } catch (_) {
      await _client!.storage.from('profile-media').remove([path]);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> myPhotos() async {
    if (!isLive) {
      return mockProfiles
          .map(
            (p) => {
              'id': p.id,
              'url': p.imagePath,
              'storage_path': p.imagePath,
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

  Future<void> deleteProfilePhoto(Map<String, dynamic> photo) async {
    if (!isLive) return;
    await _client!.from('profile_photos').delete().eq('id', photo['id']);
    await _client!.storage.from('profile-media').remove([
      photo['storage_path'] as String,
    ]);
  }

  Future<void> togglePhotoLike(
    String photoId, {
    required bool currentlyLiked,
  }) async {
    if (!isLive) return;
    if (currentlyLiked) {
      await _client!
          .from('photo_likes')
          .delete()
          .eq('photo_id', photoId)
          .eq('user_id', currentUserId!);
    } else {
      await _client!.from('photo_likes').insert({
        'photo_id': photoId,
        'user_id': currentUserId!,
      });
    }
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
      final source = _demoFriendIds.isEmpty
          ? mockProfiles.take(3)
          : mockProfiles.where((p) => _demoFriendIds.contains(p.id));
      return source
          .map(
            (p) => FriendshipItem(
              id: p.id,
              profile: p,
              status: status ?? 'accepted',
              sentByMe: false,
            ),
          )
          .toList();
    }
    var query = _client!.from('friendships').select();
    if (status != null) query = query.eq('status', status);
    final rows = await query.order('updated_at', ascending: false);
    final result = <FriendshipItem>[];
    for (final row in rows) {
      final sentByMe = row['requester_id'] == currentUserId;
      final otherId =
          (sentByMe ? row['addressee_id'] : row['requester_id']) as String;
      final profile = await getProfile(otherId);
      if (profile != null) {
        result.add(
          FriendshipItem(
            id: row['id'] as String,
            profile: profile,
            status: row['status'] as String,
            sentByMe: sentByMe,
          ),
        );
      }
    }
    return result;
  }

  Future<void> sendFriendRequest(String userId) async {
    if (!isLive) {
      _demoFriendIds.add(userId);
      return;
    }
    await _client!.from('friendships').insert({
      'requester_id': currentUserId!,
      'addressee_id': userId,
    });
  }

  Future<void> respondToFriendRequest(String id, bool accept) async {
    if (!isLive) return;
    await _client!
        .from('friendships')
        .update({
          'status': accept ? 'accepted' : 'declined',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> removeFriendship(String id, {bool cancel = false}) async {
    if (!isLive) {
      _demoFriendIds.remove(id);
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
      final latest = await _client!
          .from('messages')
          .select('body, kind, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1);
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
        ),
      );
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Stream<List<MapLovMessage>> watchMessages(String conversationId) {
    if (!isLive) {
      return Stream<List<MapLovMessage>>.multi((controller) {
        controller.add(List.unmodifiable(_demoMessages));
        final subscription = _demoMessageStream.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      });
    }
    return _client!
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .asyncMap((rows) async => Future.wait(rows.map(_messageFromRow)));
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    if (!isLive) {
      _demoMessages.add(
        MapLovMessage(
          id: _uuid.v4(),
          senderId: 'me',
          kind: 'text',
          body: text,
          createdAt: DateTime.now(),
        ),
      );
      _demoMessageStream.add(List.unmodifiable(_demoMessages));
      return;
    }
    await _client!.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': currentUserId!,
      'kind': 'text',
      'body': text,
    });
  }

  Future<void> sendMessageMedia({
    required String conversationId,
    required Uint8List bytes,
    required String extension,
    required String kind,
  }) async {
    if (!isLive) return;
    final path = '${currentUserId!}/$conversationId/${_uuid.v4()}.$extension';
    await _client!.storage.from('chat-media').uploadBinary(path, bytes);
    await _client!.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': currentUserId!,
      'kind': kind,
      'media_path': path,
    });
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
          .order('display_order')
          .limit(1);
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
          mediaUrl: media.isEmpty
              ? null
              : await _signedUrl(
                  'post-media',
                  media.first['storage_path'] as String,
                ),
          createdAt: DateTime.parse(row['created_at'] as String),
          likes: likes.length,
          comments: comments.length,
          likedByMe: likes.any((like) => like['user_id'] == currentUserId),
          commentsEnabled: row['comments_enabled'] as bool? ?? true,
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
    if (image != null) {
      final postId = row['id'] as String;
      final path = '${currentUserId!}/$postId/${_uuid.v4()}.$extension';
      await _client!.storage.from('post-media').uploadBinary(path, image);
      await _client!.from('post_media').insert({
        'post_id': postId,
        'storage_path': path,
      });
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
    final rows = await _client!
        .from('garden_albums')
        .select()
        .eq('owner_id', ownerId ?? currentUserId!)
        .order('created_at');
    final result = <GardenAlbumItem>[];
    for (final row in rows) {
      final photos = await _client!
          .from('garden_photos')
          .select('id')
          .eq('album_id', row['id']);
      result.add(
        GardenAlbumItem(
          id: row['id'] as String,
          ownerId: row['owner_id'] as String,
          title: row['title'] as String,
          description: row['description'] as String? ?? '',
          coverUrl: row['cover_path'] == null
              ? null
              : await _signedUrl('secret-garden', row['cover_path'] as String),
          photoCount: photos.length,
        ),
      );
    }
    return result;
  }

  Future<String> createGardenAlbum(String title) async {
    if (!isLive) return 'demo-garden';
    final row = await _client!
        .from('garden_albums')
        .insert({'owner_id': currentUserId!, 'title': title.trim()})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> uploadGardenPhoto({
    required String albumId,
    required Uint8List bytes,
    required String extension,
  }) async {
    if (!isLive) return;
    final existing = await _client!
        .from('garden_photos')
        .select('id')
        .eq('album_id', albumId);
    final path = '${currentUserId!}/$albumId/${_uuid.v4()}.$extension';
    await _client!.storage.from('secret-garden').uploadBinary(path, bytes);
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

  Future<List<Map<String, dynamic>>> moderationReports() async {
    if (!isLive) return [];
    return List<Map<String, dynamic>>.from(
      await _client!
          .from('reports')
          .select()
          .order('created_at', ascending: false),
    );
  }

  Future<void> moderateReport(String id, String status) async {
    if (!isLive) return;
    final resolved = status == 'resolved' || status == 'dismissed';
    await _client!
        .from('reports')
        .update({
          'status': status,
          'resolved_at': resolved
              ? DateTime.now().toUtc().toIso8601String()
              : null,
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
                ),
              )
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

  Future<Map<String, bool>> notificationPreferences() async {
    const defaults = {
      'messages': true,
      'friend_requests': true,
      'post_activity': true,
      'garden_requests': true,
      'compatibility_suggestions': false,
      'marketing': false,
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

  Future<UserProfile> _profileFromRow(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final photos = await _client!
        .from('profile_photos')
        .select('id, storage_path')
        .eq('user_id', id)
        .order('display_order');
    final urls = <String>[];
    final photoIds = <String>[];
    for (final photo in photos) {
      photoIds.add(photo['id'] as String);
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
    return UserProfile(
      id: id,
      name: row['first_name'] as String? ?? 'MapLov member',
      age: age,
      city: row['city'] as String? ?? '',
      country: row['country_name'] as String? ?? '',
      compatibilityScore: 80,
      imagePath: urls.isEmpty
          ? 'assets/profile/profile_user_placeholder.png'
          : urls.first,
      photoUrls: urls,
      photoIds: photoIds,
      photoDisplayStyle: style,
      profession: row['profession'] as String? ?? 'MapLov member',
      distanceKm: ((row['distance_km'] as num?)?.round() ?? 5),
      isOnline:
          row['is_online'] as bool? ??
          (lastActive != null && now.difference(lastActive).inMinutes < 5),
      isNew:
          DateTime.tryParse(
            row['created_at'] as String? ?? '',
          )?.isAfter(now.subtract(const Duration(days: 14))) ??
          false,
      bio: row['bio'] as String? ?? '',
      isVerified: row['is_verified'] as bool? ?? false,
    );
  }

  Future<MapLovMessage> _messageFromRow(Map<String, dynamic> row) async {
    String? mediaUrl;
    final path = row['media_path'] as String?;
    if (path != null) mediaUrl = await _signedUrl('chat-media', path);
    return MapLovMessage(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      kind: row['kind'] as String,
      body: row['body'] as String?,
      mediaUrl: mediaUrl,
      createdAt: DateTime.parse(row['created_at'] as String),
      deleted: row['deleted_at'] != null,
    );
  }

  Future<String> _signedUrl(String bucket, String path) =>
      _client!.storage.from(bucket).createSignedUrl(path, 3600);
}
