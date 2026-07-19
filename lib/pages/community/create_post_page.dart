part of '../../app.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _body = TextEditingController();
  bool commentsEnabled = true;
  bool publishing = false;
  final List<Uint8List> images = [];
  final List<String> imageExtensions = [];

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final selected = await ImagePicker().pickMultiImage(
      imageQuality: 82,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (selected.isEmpty) return;
    images
      ..clear()
      ..addAll(
        await Future.wait(selected.take(6).map((file) => file.readAsBytes())),
      );
    imageExtensions
      ..clear()
      ..addAll(selected.take(6).map((file) => file.name.split('.').last));
    if (mounted) setState(() {});
  }

  Future<void> _publish() async {
    if (_body.text.trim().isEmpty && images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add text or a photo first.')),
      );
      return;
    }
    setState(() => publishing = true);
    try {
      await MapLovRepository.instance.createPost(
        body: _body.text,
        commentsEnabled: commentsEnabled,
        images: images,
        extensions: imageExtensions,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to publish: $error')));
      }
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Create post',
    children: [
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundImage: AssetImage(
            'assets/profile/profile_user_placeholder.png',
          ),
        ),
        title: Text(
          'My profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.people_outline, size: 16),
            SizedBox(width: 5),
            Text('Friends only'),
          ],
        ),
      ),
      TextField(
        controller: _body,
        minLines: 5,
        maxLines: 8,
        decoration: InputDecoration(
          hintText: context.tr('Share something with your friends...'),
          alignLabelWithHint: true,
        ),
      ),
      if (images.isNotEmpty) ...[
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: PageView(
              children: images
                  .map((bytes) => Image.memory(bytes, fit: BoxFit.cover))
                  .toList(),
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _pickImage,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(
          images.isEmpty ? 'Add photos' : 'Replace photos (${images.length}/6)',
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: commentsEnabled,
        onChanged: (value) => setState(() => commentsEnabled = value),
        title: const Text('Allow comments'),
      ),
      const SizedBox(height: 14),
      _PrimaryButton(
        publishing ? 'Publishing…' : 'Publish to friends',
        onPressed: publishing ? () {} : _publish,
      ),
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Posts are private and visible only to accepted friends.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grayText, fontSize: 12),
        ),
      ),
    ],
  );
}
