part of '../../app.dart';

class PostDetailsScreen extends StatefulWidget {
  const PostDetailsScreen({super.key, this.post});
  final MapLovPost? post;

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  final comment = TextEditingController();
  late Future<List<PostCommentItem>> comments;

  @override
  void initState() {
    super.initState();
    _reloadComments();
  }

  void _reloadComments() => comments = MapLovRepository.instance.postComments(
    widget.post?.id ?? 'demo-post',
  );

  Future<void> _editComment(PostCommentItem item) async {
    final controller = TextEditingController(text: item.body);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    await MapLovRepository.instance.updatePostComment(item.id, value);
    if (mounted) setState(_reloadComments);
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post =
        widget.post ??
        MapLovPost(
          id: 'demo-post',
          author: demoProfileOrUnavailable,
          body: 'A perfect day exploring the city ✨',
          mediaUrl: demoProfileOrUnavailable.imagePath,
          createdAt: DateTime.now(),
        );
    return _AppPage(
      title: 'Post',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundImage: profileImageProvider(post.author),
          ),
          title: Text(
            post.author.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('Friends only'),
        ),
        if (post.mediaUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 360,
              child: PageView(
                children:
                    (post.mediaUrls.isEmpty ? [post.mediaUrl!] : post.mediaUrls)
                        .map(
                          (path) => path.startsWith('http')
                              ? Image.network(path, fit: BoxFit.cover)
                              : Image.asset(path, fit: BoxFit.cover),
                        )
                        .toList(),
              ),
            ),
          ),
        if (post.body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(post.body),
          ),
        if (post.commentsEnabled) ...[
          const _SectionTitle('Add a comment'),
          TextField(
            controller: comment,
            decoration: const InputDecoration(
              hintText: 'Write a respectful comment…',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () async {
              await MapLovRepository.instance.addPostComment(
                post.id,
                comment.text,
              );
              comment.clear();
              if (mounted) setState(_reloadComments);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Comment added.')));
              }
            },
            child: const Text('Comment'),
          ),
          const _SectionTitle('Comments'),
          FutureBuilder<List<PostCommentItem>>(
            future: comments,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? const <PostCommentItem>[];
              if (items.isEmpty) return const Text('No comments yet.');
              return Column(
                children: items
                    .map(
                      (item) => ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profileImageProvider(item.author),
                        ),
                        title: Text(item.author.name),
                        subtitle: Text(item.body),
                        trailing: item.mine
                            ? PopupMenuButton<String>(
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _editComment(item);
                                  } else {
                                    await MapLovRepository.instance
                                        .deletePostComment(item.id);
                                    if (mounted) setState(_reloadComments);
                                  }
                                },
                              )
                            : null,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
        if (post.mine) ...[
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              await MapLovRepository.instance.deletePost(post.id);
              if (context.mounted) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete publication'),
          ),
        ],
      ],
    );
  }
}
