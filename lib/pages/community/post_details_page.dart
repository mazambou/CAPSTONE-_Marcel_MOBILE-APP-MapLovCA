part of '../../app.dart';

class PostDetailsScreen extends StatefulWidget {
  const PostDetailsScreen({super.key, this.post});
  final MapLovPost? post;

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  final comment = TextEditingController();

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
          author: mockProfiles.first,
          body: 'A perfect day exploring the city ✨',
          mediaUrl: mockProfiles.first.imagePath,
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
            child: post.mediaUrl!.startsWith('http')
                ? Image.network(post.mediaUrl!, height: 360, fit: BoxFit.cover)
                : Image.asset(post.mediaUrl!, height: 360, fit: BoxFit.cover),
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
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Comment added.')));
              }
            },
            child: const Text('Comment'),
          ),
        ],
      ],
    );
  }
}
