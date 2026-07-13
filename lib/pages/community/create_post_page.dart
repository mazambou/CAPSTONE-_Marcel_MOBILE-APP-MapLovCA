part of '../../app.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  bool commentsEnabled = true;

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
        title: Text('Jamie', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Row(
          children: [
            Icon(Icons.people_outline, size: 16),
            SizedBox(width: 5),
            Text('Friends only'),
          ],
        ),
      ),
      const TextField(
        minLines: 5,
        maxLines: 8,
        decoration: InputDecoration(
          hintText: 'Share something with your friends...',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add photos'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: commentsEnabled,
        onChanged: (value) => setState(() => commentsEnabled = value),
        title: const Text('Allow comments'),
      ),
      const SizedBox(height: 14),
      _PrimaryButton(
        'Publish to friends',
        onPressed: () => Navigator.pop(context),
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
