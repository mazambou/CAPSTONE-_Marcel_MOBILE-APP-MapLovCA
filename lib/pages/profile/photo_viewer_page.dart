part of '../../app.dart';

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({
    super.key,
    this.profile,
    this.initialIndex = 0,
    this.displayStyleOverride,
  });

  final UserProfile? profile;
  final int initialIndex;
  final PhotoDisplayStyle? displayStyleOverride;

  @override
  Widget build(BuildContext context) {
    final selectedProfile = profile ?? demoProfileOrUnavailable;
    final displayStyle =
        displayStyleOverride ?? selectedProfile.photoDisplayStyle;

    return switch (displayStyle) {
      PhotoDisplayStyle.social => _SocialPhotoViewer(
        profile: selectedProfile,
        initialIndex: initialIndex,
      ),
      PhotoDisplayStyle.profileDetails => _DetailedPhotoViewer(
        profile: selectedProfile,
        initialIndex: initialIndex,
      ),
    };
  }
}

Future<void> _confirmPhotoReport(
  BuildContext context, {
  required UserProfile profile,
  required int photoIndex,
}) async {
  final photoId = profile.photoIds.length > photoIndex
      ? profile.photoIds[photoIndex]
      : MapLovRepository.instance.isLive
      ? null
      : 'demo-photo-${profile.id}-$photoIndex';
  if (photoId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This photo cannot be reported.')),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Report this photo?'),
      content: const Text(
        'The photo will be reviewed confidentially by the MapLov moderation team.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Report'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    final submitted = await MapLovRepository.instance.reportPhoto(photoId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submitted
              ? 'Photo reported for review.'
              : 'You have already reported this photo.',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to report this photo: $error')),
    );
  }
}

class _DetailedPhotoViewer extends StatefulWidget {
  const _DetailedPhotoViewer({
    required this.profile,
    required this.initialIndex,
  });

  final UserProfile profile;
  final int initialIndex;

  @override
  State<_DetailedPhotoViewer> createState() => _DetailedPhotoViewerState();
}

class _DetailedPhotoViewerState extends State<_DetailedPhotoViewer> {
  late final PageController _pageController;
  late final UserProfile _profile;
  late final List<String> _photos;
  late int _currentIndex;
  late bool _profileLiked;
  bool _focusMode = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _photos = _profile.photoUrls.isNotEmpty
        ? List.of(_profile.photoUrls)
        : [_profile.imagePath];
    _currentIndex = widget.initialIndex.clamp(0, _photos.length - 1);
    _profileLiked = _profile.likedByMe;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showPreviousPhoto() {
    final nextIndex = _currentIndex == 0
        ? _photos.length - 1
        : _currentIndex - 1;
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _showNextPhoto() {
    final nextIndex = (_currentIndex + 1) % _photos.length;
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _toggleProfileLike() async {
    final result = await _toggleProfileLikeFromDetails(context, _profile);
    if (result != null && mounted) {
      setState(() => _profileLiked = result.liked);
    }
  }

  Future<void> _openChat() async {
    try {
      final id = await MapLovRepository.instance.startConversation(_profile.id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: id, profile: _profile),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start conversation: $error')),
        );
      }
    }
  }

  Future<void> _reportCurrentPhoto() => _confirmPhotoReport(
    context,
    profile: _profile,
    photoIndex: _currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _photos.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) => mediaImage(
              _photos[index],
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          if (!_focusMode) const _PhotoViewerGradient(),
          Positioned.fill(
            child: GestureDetector(
              key: const Key('detailed_photo_focus_toggle'),
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _focusMode = !_focusMode),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                children: [
                  _PhotoViewerHeader(
                    profile: _profile,
                    profileLiked: _profileLiked,
                    onProfileLike: _toggleProfileLike,
                    compact: _focusMode,
                  ),
                  if (!_focusMode) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          _PhotoBadge(
                            icon: Icons.photo_library_outlined,
                            label: '${_photos.length} photos',
                          ),
                          const _PhotoBadge(
                            icon: Icons.circle,
                            label: 'Online',
                            iconColor: Color(0xFF29D391),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PhotoNavigationButton(
                        icon: Icons.chevron_left,
                        onPressed: _showPreviousPhoto,
                      ),
                      _PhotoNavigationButton(
                        icon: Icons.chevron_right,
                        onPressed: _showNextPhoto,
                      ),
                    ],
                  ),
                  Spacer(flex: _focusMode ? 4 : 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _PhotoBadge(
                      icon: Icons.info_outline,
                      label: '${_currentIndex + 1}/${_photos.length}',
                    ),
                  ),
                  if (!_focusMode) ...[
                    const SizedBox(height: 10),
                    _PhotoProfilePanel(profile: _profile),
                  ],
                  const SizedBox(height: 12),
                  _PhotoActions(
                    onMessage: _openChat,
                    onReport: _reportCurrentPhoto,
                    showReport:
                        MapLovRepository.instance.currentUserId != _profile.id,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialPhotoViewer extends StatefulWidget {
  const _SocialPhotoViewer({required this.profile, required this.initialIndex});

  final UserProfile profile;
  final int initialIndex;

  @override
  State<_SocialPhotoViewer> createState() => _SocialPhotoViewerState();
}

class _SocialPhotoViewerState extends State<_SocialPhotoViewer> {
  late final PageController _pageController;
  late final List<String> _photos;
  late int _currentIndex;
  bool _liked = false;
  bool _superLiked = false;
  late bool _profileLiked;
  int _likeCount = 24;

  @override
  void initState() {
    super.initState();
    _photos = widget.profile.photoUrls.isNotEmpty
        ? List.of(widget.profile.photoUrls)
        : [widget.profile.imagePath];
    _currentIndex = widget.initialIndex.clamp(0, _photos.length - 1);
    _profileLiked = widget.profile.likedByMe;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPhoto(int index) {
    final normalizedIndex = (index + _photos.length) % _photos.length;
    _pageController.animateToPage(
      normalizedIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _toggleLike() async {
    final photoId = widget.profile.photoIds.length > _currentIndex
        ? widget.profile.photoIds[_currentIndex]
        : MapLovRepository.instance.isLive
        ? null
        : 'demo-photo-${widget.profile.id}-$_currentIndex';
    if (photoId == null) return;
    try {
      final result = await MapLovRepository.instance.togglePhotoLike(
        photoId,
        profileId: widget.profile.id,
        currentlyLiked: _liked,
      );
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likeCount += result.liked ? 1 : -1;
      });
      if (result.matched) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewMatchScreen(profile: widget.profile),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update this photo like: $error')),
      );
    }
  }

  Future<void> _toggleProfileLike() async {
    final result = await _toggleProfileLikeFromDetails(context, widget.profile);
    if (result != null && mounted) {
      setState(() => _profileLiked = result.liked);
    }
  }

  void _toggleSuperLike() {
    setState(() => _superLiked = !_superLiked);
  }

  void _openComments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF19171C),
      showDragHandle: true,
      builder: (context) => _PhotoCommentsSheet(
        profile: widget.profile,
        photoId: widget.profile.photoIds.length > _currentIndex
            ? widget.profile.photoIds[_currentIndex]
            : 'demo-photo',
      ),
    );
  }

  Future<void> _reportCurrentPhoto() => _confirmPhotoReport(
    context,
    profile: widget.profile,
    photoIndex: _currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _photos.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) => mediaImage(
              _photos[index],
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          const _SocialPhotoGradient(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                children: [
                  _PhotoViewerHeader(
                    profile: widget.profile,
                    profileLiked: _profileLiked,
                    onProfileLike: _toggleProfileLike,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        _PhotoBadge(
                          icon: Icons.photo_library_outlined,
                          label: '${_photos.length} photos',
                        ),
                        const _PhotoBadge(
                          icon: Icons.circle,
                          label: 'Online',
                          iconColor: Color(0xFF29D391),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _SocialPhotoActions(
                      liked: _liked,
                      superLiked: _superLiked,
                      likeCount: _likeCount,
                      onLike: _toggleLike,
                      onComment: _openComments,
                      onSuperLike: _toggleSuperLike,
                    ),
                  ),
                  const Spacer(),
                  if (MapLovRepository.instance.currentUserId !=
                      widget.profile.id) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _PhotoReportButton(onPressed: _reportCurrentPhoto),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _SocialProfileFacts(profile: widget.profile),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundOverlayButton(
                        icon: Icons.chevron_left,
                        onPressed: () => _goToPhoto(_currentIndex - 1),
                        size: 52,
                      ),
                      const SizedBox(width: 16),
                      _PhotoBadge(
                        icon: Icons.photo_outlined,
                        label: '${_currentIndex + 1}/${_photos.length}',
                      ),
                      const SizedBox(width: 16),
                      _RoundOverlayButton(
                        icon: Icons.chevron_right,
                        onPressed: () => _goToPhoto(_currentIndex + 1),
                        size: 52,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialPhotoActions extends StatelessWidget {
  const _SocialPhotoActions({
    required this.liked,
    required this.superLiked,
    required this.likeCount,
    required this.onLike,
    required this.onComment,
    required this.onSuperLike,
  });

  final bool liked;
  final bool superLiked;
  final int likeCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSuperLike;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SocialSideAction(
          key: const Key('social_photo_like'),
          icon: liked ? Icons.favorite : Icons.favorite_border,
          label: liked ? '$likeCount Liked' : '$likeCount Likes',
          color: liked ? AppColors.deepPink : Colors.white,
          onPressed: onLike,
        ),
        const SizedBox(height: 13),
        _SocialSideAction(
          key: const Key('social_photo_comment'),
          icon: Icons.mode_comment_outlined,
          label: 'Comment',
          color: Colors.white,
          onPressed: onComment,
        ),
        const SizedBox(height: 13),
        _SocialSideAction(
          key: const Key('social_photo_super_like'),
          iconWidget: _SuperLikeGlyph(
            key: const Key('super_like_love_icon'),
            active: superLiked,
            size: 31,
          ),
          label: superLiked ? 'Super Liked' : 'Super Like',
          color: Colors.white,
          onPressed: onSuperLike,
        ),
      ],
    );
  }
}

class _SocialSideAction extends StatelessWidget {
  const _SocialSideAction({
    super.key,
    this.icon,
    this.iconWidget,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Column(
        children: [
          Material(
            color: Colors.black.withValues(alpha: 0.58),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 54,
                height: 54,
                child: iconWidget ?? Icon(icon, color: color, size: 29),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black, blurRadius: 5)],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialProfileFacts extends StatelessWidget {
  const _SocialProfileFacts({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          flex: 4,
          child: _SocialFactCard(
            icon: Icons.favorite_outline,
            label: 'Looking for',
            value: 'Serious relationship',
            color: AppColors.softPink,
          ),
        ),
        const SizedBox(width: 7),
        const Expanded(
          flex: 3,
          child: _SocialFactCard(
            icon: Icons.translate,
            label: 'Languages',
            value: 'EN, FR',
            color: Color(0xFF29D391),
          ),
        ),
        const SizedBox(width: 7),
        const Expanded(
          flex: 3,
          child: _SocialFactCard(
            icon: Icons.straighten,
            label: 'Height',
            value: '165 cm',
            color: Color(0xFFFFC12E),
          ),
        ),
      ],
    );
  }
}

class _SocialFactCard extends StatelessWidget {
  const _SocialFactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCommentsSheet extends StatefulWidget {
  const _PhotoCommentsSheet({required this.profile, required this.photoId});

  final UserProfile profile;
  final String photoId;

  @override
  State<_PhotoCommentsSheet> createState() => _PhotoCommentsSheetState();
}

class _PhotoCommentsSheetState extends State<_PhotoCommentsSheet> {
  final controller = TextEditingController();
  late Future<List<Map<String, String>>> comments;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      comments = MapLovRepository.instance.photoComments(widget.photoId);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    await MapLovRepository.instance.addPhotoComment(
      widget.photoId,
      controller.text,
    );
    controller.clear();
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comments on ${widget.profile.name}’s photo',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<Map<String, String>>>(
              future: comments,
              builder: (context, snapshot) => Column(
                children: (snapshot.data ?? const <Map<String, String>>[])
                    .map(
                      (item) => _PhotoComment(
                        author: item['author']!,
                        text: item['body']!,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add a respectful comment...',
                hintStyle: const TextStyle(color: Colors.white54),
                fillColor: Colors.white.withValues(alpha: 0.1),
                suffixIcon: IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send, color: AppColors.coral),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoComment extends StatelessWidget {
  const _PhotoComment({required this.author, required this.text});

  final String author;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(
        author,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }
}

class _SocialPhotoGradient extends StatelessWidget {
  const _SocialPhotoGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB8000000), Colors.transparent, Color(0xC9000000)],
          stops: [0, 0.45, 1],
        ),
      ),
    );
  }
}

class _PhotoViewerGradient extends StatelessWidget {
  const _PhotoViewerGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Color(0x11000000),
            Color(0x22000000),
            Color(0xE6000000),
          ],
          stops: [0, 0.24, 0.55, 1],
        ),
      ),
    );
  }
}

class _PhotoViewerHeader extends StatelessWidget {
  const _PhotoViewerHeader({
    required this.profile,
    required this.profileLiked,
    required this.onProfileLike,
    this.compact = false,
  });

  final UserProfile profile;
  final bool profileLiked;
  final VoidCallback onProfileLike;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundOverlayButton(
          icon: Icons.close,
          onPressed: () => Navigator.pop(context),
        ),
        if (!compact) const SizedBox(width: 12),
        if (!compact)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        key: Key('viewer_profile_name_${profile.name}'),
                        onTap: () async {
                          if (!await _requireProfilePhotos(
                                context,
                                minimum: 3,
                              ) ||
                              !context.mounted) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PublicProfileScreen(profile: profile),
                            ),
                          );
                        },
                        child: Text(
                          '${profile.name}, ${profile.age}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      color: Color(0xFF2D8CFF),
                      size: 22,
                    ),
                    if (profile.isVip) ...[
                      const SizedBox(width: 6),
                      const _VipBadge(compact: true),
                    ],
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${profile.city}, ${profile.country}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (compact) const Spacer(),
        IconButton.filledTonal(
          key: Key('photo_profile_like_${profile.name}'),
          tooltip: profileLiked ? 'Remove profile like' : 'Like profile',
          onPressed: onProfileLike,
          constraints: const BoxConstraints.tightFor(width: 56, height: 56),
          icon: Icon(
            profileLiked ? Icons.favorite : Icons.favorite_border,
            color: AppColors.deepPink,
            size: 33,
          ),
        ),
        if (!compact) const SizedBox(width: 4),
        if (!compact)
          PopupMenuButton<String>(
            color: const Color(0xFF27232A),
            iconColor: Colors.white,
            icon: const Icon(Icons.more_horiz, size: 30),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Report profile')),
              PopupMenuItem(value: 'block', child: Text('Block profile')),
            ],
            onSelected: (value) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => value == 'block'
                    ? BlockUserScreen(profile: profile)
                    : ReportUserScreen(profile: profile),
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoProfilePanel extends StatelessWidget {
  const _PhotoProfilePanel({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.format_quote, color: AppColors.coral, size: 23),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Looking for a meaningful relationship ❤️',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            children: [
              Expanded(
                child: _PhotoFact(
                  icon: Icons.location_on_outlined,
                  value: profile.city,
                  label: 'Canada',
                ),
              ),
              const _PhotoFactDivider(),
              Expanded(
                child: _PhotoFact(
                  icon: Icons.cake_outlined,
                  value: '${profile.age} years',
                  label: 'Age',
                ),
              ),
              const _PhotoFactDivider(),
              const Expanded(
                child: _PhotoFact(
                  icon: Icons.straighten,
                  value: '165 cm',
                  label: 'Height',
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          const Text(
            'About me',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'I love travelling, discovering new restaurants and spending time in nature. 🌿',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _PhotoFact extends StatelessWidget {
  const _PhotoFact({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.coral, size: 23),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _PhotoFactDivider extends StatelessWidget {
  const _PhotoFactDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 58, color: Colors.white24);
  }
}

class _PhotoActions extends StatelessWidget {
  const _PhotoActions({
    required this.onMessage,
    required this.onReport,
    required this.showReport,
  });

  final VoidCallback onMessage;
  final VoidCallback onReport;
  final bool showReport;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: showReport
                ? _PhotoReportButton(onPressed: onReport)
                : const SizedBox.shrink(),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PhotoActionButton(
              icon: Icons.chat_bubble_outline,
              color: AppColors.deepPink,
              size: 70,
              onPressed: onMessage,
            ),
            const SizedBox(width: 16),
            _PhotoActionButton(
              color: AppColors.coral,
              size: 58,
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Super Like sent.'))),
              child: const _SuperLikeGlyph(
                key: Key('super_like_love_icon'),
                size: 31,
              ),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}

class _PhotoActionButton extends StatelessWidget {
  const _PhotoActionButton({
    this.icon,
    this.child,
    required this.color,
    required this.size,
    required this.onPressed,
  }) : assert(icon != null || child != null);

  final IconData? icon;
  final Widget? child;
  final Color color;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 8,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: child ?? Icon(icon, color: color, size: size * 0.48),
        ),
      ),
    );
  }
}

class _PhotoReportButton extends StatelessWidget {
  const _PhotoReportButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('report_current_photo'),
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.black.withValues(alpha: .58),
      side: const BorderSide(color: Colors.white54),
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
    icon: const Icon(Icons.flag_outlined, size: 20),
    label: const Text('Report'),
  );
}

class _SuperLikeGlyph extends StatelessWidget {
  const _SuperLikeGlyph({super.key, this.active = true, required this.size});

  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.favorite,
          color: active ? AppColors.coral : Colors.white,
          size: size,
        ),
        Icon(
          Icons.north_east_rounded,
          color: active ? Colors.white : AppColors.coral,
          size: size * .58,
        ),
      ],
    ),
  );
}

class _PhotoNavigationButton extends StatelessWidget {
  const _PhotoNavigationButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _RoundOverlayButton(icon: icon, onPressed: onPressed, size: 52);
  }
}

class _RoundOverlayButton extends StatelessWidget {
  const _RoundOverlayButton({
    required this.icon,
    required this.onPressed,
    this.size = 46,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.55),
        ),
      ),
    );
  }
}
