part of '../../app.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final items = _helpArticles.where(
      (item) =>
          normalized.isEmpty ||
          item.title.toLowerCase().contains(normalized) ||
          item.answer.toLowerCase().contains(normalized),
    );
    return _AppPage(
      title: 'Help Center',
      children: [
        TextField(
          key: const Key('help_search'),
          onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(
            hintText: 'Search for help',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const _SectionTitle('Popular topics'),
        if (items.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.search_off),
              title: Text('No help article found'),
              subtitle: Text('Try a shorter search or contact support.'),
            ),
          )
        else
          ...items.map(
            (item) => ExpansionTile(
              key: ValueKey(item.title),
              leading: Icon(item.icon, color: AppColors.coral),
              title: Text(item.title),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(item.answer),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Contact support'),
              content: const SelectableText(
                'General support: support@maplov.ca\n'
                'Privacy: privacy@maplov.ca\n'
                'Child safety: child-safety@maplov.ca\n\n'
                'Include your account email, device model and a short description. Never send your password or SMS code.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.support_agent),
          label: const Text('Contact MapLov Support'),
        ),
      ],
    );
  }
}

class _HelpArticle {
  const _HelpArticle(this.title, this.answer, this.icon);
  final String title;
  final String answer;
  final IconData icon;
}

const _helpArticles = [
  _HelpArticle(
    'Creating and verifying an account',
    'Register with one email address and one phone number, confirm your email, complete your profile and verify the SMS code. MapLov permits one personal account per person.',
    Icons.person_add_alt_1_outlined,
  ),
  _HelpArticle(
    'Why my profile is not in Discover',
    'Complete the required profile fields, add a main photo, keep Discover visibility enabled and check the other account’s age, gender and location filters. Your own profile never appears in your Discover results.',
    Icons.search_outlined,
  ),
  _HelpArticle(
    'Profile photo requirements',
    'A main profile photo is required before interacting. At least three profile photos are required before opening full member profiles. Use clear, recent photos that belong to you.',
    Icons.photo_library_outlined,
  ),
  _HelpArticle(
    'Likes and matches',
    'A compatibility score above 80% may create a match according to your preferences. Below that threshold, a reciprocal profile like or reciprocal photo like creates the match.',
    Icons.favorite_outline,
  ),
  _HelpArticle(
    'Messages and deletion',
    'Tap your own message to delete it for yourself or, when eligible, for everyone. Clear Chat follows your plan: Plus removes your unread messages remotely; VIP can clear the whole conversation on both accounts.',
    Icons.chat_bubble_outline,
  ),
  _HelpArticle(
    'Secret Garden safety',
    'Secret Garden access is explicit, time-limited and revocable. Never upload content without consent. Report a member immediately if private content is copied, threatened or shared.',
    Icons.lock_outline,
  ),
  _HelpArticle(
    'Blocking and reporting',
    'Block stops discovery, messages and notifications between both accounts. Report sends a confidential safety review. For immediate danger, contact local emergency services.',
    Icons.shield_outlined,
  ),
  _HelpArticle(
    'Location and privacy',
    'MapLov requests foreground location during registration to initialize Discover and refreshes it when you open Nearby. It stores coordinates for discovery but displays only approximate distance. It never requests background location.',
    Icons.location_on_outlined,
  ),
  _HelpArticle(
    'Premium subscriptions',
    'Manage or cancel billing through Google Play. Restoring purchases reconnects an eligible store subscription to the signed-in MapLov account.',
    Icons.workspace_premium_outlined,
  ),
  _HelpArticle(
    'Exporting or deleting your data',
    'Open Settings, then Legal & consent to request a data export. Delete Account immediately hides your profile and schedules permanent account erasure after the stated retention period.',
    Icons.privacy_tip_outlined,
  ),
];
