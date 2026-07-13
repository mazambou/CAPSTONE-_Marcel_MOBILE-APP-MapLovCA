part of '../../app.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  late Future<List<MapLovPost>> _posts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _posts = MapLovRepository.instance.posts();

  Future<void> _create() async {
    final changed = await Navigator.pushNamed(context, AppRoutes.createPost);
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Friends posts',
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: const Text('Create post'),
        ),
      ),
      const SizedBox(height: 12),
      FutureBuilder<List<MapLovPost>>(
        future: _posts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data ?? const <MapLovPost>[];
          if (posts.isEmpty) {
            return const Text('Your friends have not shared anything yet.');
          }
          return Column(
            children: posts
                .map(
                  (post) => Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundImage: profileImageProvider(post.author),
                          ),
                          title: Text(post.author.name),
                          subtitle: const Text('Friends only'),
                          trailing: IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportUserScreen(
                                  profile: post.author,
                                  targetType: 'post',
                                  targetId: post.id,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.more_horiz),
                          ),
                        ),
                        if (post.mediaUrl != null)
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostDetailsScreen(post: post),
                              ),
                            ),
                            child: post.mediaUrl!.startsWith('http')
                                ? Image.network(
                                    post.mediaUrl!,
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Image.asset(
                                    post.mediaUrl!,
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        if (post.body.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(post.body),
                          ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () async {
                                await MapLovRepository.instance.togglePostLike(
                                  post,
                                );
                                if (mounted) setState(_reload);
                              },
                              icon: Icon(
                                post.likedByMe
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: post.likedByMe ? AppColors.coral : null,
                              ),
                            ),
                            Text(
                              '${post.likes} Like${post.likes == 1 ? '' : 's'}',
                            ),
                            const SizedBox(width: 20),
                            const Icon(Icons.chat_bubble_outline),
                            const SizedBox(width: 6),
                            Text(
                              '${post.comments} Comment${post.comments == 1 ? '' : 's'}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}
