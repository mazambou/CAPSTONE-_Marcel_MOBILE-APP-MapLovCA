part of '../../app.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  bool exporting = false;

  void _openDocument(String title, List<_LegalSection> sections) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LegalDocumentScreen(title: title, sections: sections),
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => exporting = true);
    try {
      final export = await MapLovRepository.instance.exportMyData();
      final formatted = const JsonEncoder.withIndent('  ').convert(export);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Your MapLov data'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(child: SelectableText(formatted)),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: formatted));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data copied securely.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy data'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to export your data: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Legal & consent',
    children: [
      const Card(
        color: AppColors.palePink,
        child: ListTile(
          leading: Icon(Icons.info_outline, color: AppColors.coral),
          title: Text('MVP legal documents'),
          subtitle: Text(
            'These operational drafts must be reviewed by qualified Canadian privacy counsel before public launch.',
          ),
        ),
      ),
      _LegalTile(
        icon: Icons.description_outlined,
        title: 'Terms of Use',
        onTap: () => _openDocument('Terms of Use', _termsSections),
      ),
      _LegalTile(
        icon: Icons.privacy_tip_outlined,
        title: 'Privacy Policy',
        onTap: () => _openDocument('Privacy Policy', _privacySections),
      ),
      _LegalTile(
        icon: Icons.groups_outlined,
        title: 'Community Guidelines',
        onTap: () => _openDocument('Community Guidelines', _communitySections),
      ),
      _LegalTile(
        icon: Icons.child_care_outlined,
        title: 'Child Safety Standards',
        onTap: () =>
            _openDocument('Child Safety Standards', _childSafetySections),
      ),
      _LegalTile(
        icon: Icons.cookie_outlined,
        title: 'Data and cookie preferences',
        onTap: () => Navigator.pushNamed(context, AppRoutes.privacy),
      ),
      _LegalTile(
        icon: Icons.location_on_outlined,
        title: 'Location consent',
        onTap: () => _openDocument('Location consent', _locationSections),
      ),
      _LegalTile(
        icon: Icons.download_outlined,
        title: exporting ? 'Preparing your data…' : 'Request a copy of my data',
        onTap: exporting ? null : _exportData,
      ),
      _LegalTile(
        icon: Icons.delete_forever_outlined,
        title: 'Account and data deletion',
        onTap: () => Navigator.pushNamed(context, AppRoutes.deleteAccount),
      ),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'MapLov applies privacy-by-design controls inspired by PIPEDA, Québec Law 25 and GDPR principles. Legal compliance depends on final policies and operational practices.',
          style: TextStyle(color: AppColors.grayText),
        ),
      ),
    ],
  );
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _LegalSection {
  const _LegalSection(this.title, this.body);
  final String title;
  final String body;
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({required this.title, required this.sections});
  final String title;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) => _AppPage(
    title: title,
    children: [
      const Text(
        'Effective date: July 16, 2026 • MVP draft',
        style: TextStyle(color: AppColors.grayText),
      ),
      ...sections.expand(
        (section) => [
          _SectionTitle(section.title),
          SelectableText(context.tr(section.body)),
        ],
      ),
      const SizedBox(height: 20),
      SelectableText(context.tr('Questions: privacy@maplov.ca')),
    ],
  );
}

const _termsSections = [
  _LegalSection(
    'Eligibility',
    'MapLov is strictly for people aged 18 or older. You must provide accurate account information and may maintain only one personal account.',
  ),
  _LegalSection(
    'Acceptable use',
    'Do not harass, threaten, impersonate, exploit, solicit illegal services, distribute intimate content without consent, or use MapLov for scams, spam or commercial scraping.',
  ),
  _LegalSection(
    'User content',
    'You remain responsible for content you upload. You grant MapLov the limited rights required to store, display and moderate that content while providing the service.',
  ),
  _LegalSection(
    'Safety and moderation',
    'MapLov may remove content, restrict features, suspend accounts or preserve evidence when necessary for safety, fraud prevention, legal compliance or enforcement of these terms.',
  ),
  _LegalSection(
    'Subscriptions',
    'Paid plans are billed through the applicable app store. Renewal, cancellation and refunds follow the store terms and applicable consumer law.',
  ),
];

const _privacySections = [
  _LegalSection(
    'Data we process',
    'Account identifiers, age and profile details, photos, messages, approximate or precise device location when requested, preferences, safety reports, subscription status and technical security records.',
  ),
  _LegalSection(
    'Why we process it',
    'To create accounts, recommend compatible profiles, enable communication, prevent abuse, moderate content, provide subscriptions and satisfy legal obligations.',
  ),
  _LegalSection(
    'Sharing',
    'Profile content is shared according to your visibility choices. Service providers process data only to operate MapLov. We do not sell precise location or private messages.',
  ),
  _LegalSection(
    'Retention and deletion',
    'A deletion request immediately hides the account. Unless retention is legally required, associated account data is scheduled for permanent erasure after 30 days.',
  ),
  _LegalSection(
    'Your choices',
    'You can change visibility, location display and notification preferences, request an export, block members, report content and request account deletion from Settings.',
  ),
];

const _communitySections = [
  _LegalSection(
    'Respect and consent',
    'Treat every member with dignity. Consent must be voluntary, informed and reversible. Stop contact immediately when asked.',
  ),
  _LegalSection(
    'Prohibited content',
    'No child sexual abuse or exploitation, grooming, trafficking, threats, hate, non-consensual intimate imagery, illegal sexual services, fraud, impersonation or targeted harassment.',
  ),
  _LegalSection(
    'Reporting',
    'Use the separate Report and Block controls available on profiles, posts, photos and conversations. Reports are confidential and reviewed by the moderation team.',
  ),
  _LegalSection(
    'Enforcement',
    'Responses may include content removal, warnings, feature restrictions, suspension, banning and reports to appropriate authorities where required.',
  ),
];

const _childSafetySections = [
  _LegalSection(
    'Adults only',
    'People under 18 are prohibited from creating or using a MapLov account. Suspected underage accounts should be reported immediately.',
  ),
  _LegalSection(
    'Zero tolerance',
    'MapLov prohibits child sexual abuse and exploitation, CSAM, grooming, sextortion, trafficking and any attempt to sexualize or endanger a minor.',
  ),
  _LegalSection(
    'Response process',
    'Reported content is restricted and reviewed. Confirmed illegal material is preserved only as legally required, removed from access and reported to the appropriate Canadian or international authority.',
  ),
  _LegalSection(
    'Safety contact',
    'Report urgent child-safety concerns in the app and contact child-safety@maplov.ca. Contact emergency services when someone is in immediate danger.',
  ),
];

const _locationSections = [
  _LegalSection(
    'User-initiated access',
    'MapLov requests foreground location while you complete registration to initialize Discover, and again when you open Nearby or explicitly refresh your location. It does not request background location.',
  ),
  _LegalSection(
    'Purpose and display',
    'Coordinates support distance and nearby discovery. Other members see only an approximate distance when that preference is enabled, never your raw coordinates.',
  ),
  _LegalSection(
    'Control',
    'You may deny or revoke location permission in Android settings. Country, city and worldwide search remain available without continuous location access.',
  ),
];
