part of '../../app.dart';

const _legalDraftVersion = '2026-07-30';

class _LegalCopy {
  const _LegalCopy(this.english, this.french);

  final String english;
  final String french;

  String resolve(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'fr' ? french : english;
}

class _LegalSection {
  const _LegalSection({required this.title, required this.body});

  final _LegalCopy title;
  final _LegalCopy body;
}

class _LegalDocument {
  const _LegalDocument({
    required this.key,
    required this.version,
    required this.title,
    required this.effectiveDate,
    required this.sections,
    required this.contact,
  });

  final String key;
  final String version;
  final _LegalCopy title;
  final _LegalCopy effectiveDate;
  final List<_LegalSection> sections;
  final _LegalCopy contact;
}

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  bool exporting = false;

  void _openDocument(_LegalDocument document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LegalDocumentScreen(document: document),
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
          leading: Icon(Icons.gavel_outlined, color: AppColors.coral),
          title: Text('Legal drafts for MapLov'),
          subtitle: Text(
            'Original Canadian drafts based on MapLov’s actual features. The legal operator name, postal address and final launch date must be confirmed by qualified Canadian counsel before publication.',
          ),
        ),
      ),
      _LegalTile(
        icon: Icons.description_outlined,
        title: _termsDocument.title.resolve(context),
        onTap: () => _openDocument(_termsDocument),
      ),
      _LegalTile(
        icon: Icons.privacy_tip_outlined,
        title: _privacyDocument.title.resolve(context),
        onTap: () => _openDocument(_privacyDocument),
      ),
      _LegalTile(
        icon: Icons.cookie_outlined,
        title: _cookieDocument.title.resolve(context),
        onTap: () => _openDocument(_cookieDocument),
      ),
      _LegalTile(
        icon: Icons.face_retouching_natural_outlined,
        title: _faceVerificationDocument.title.resolve(context),
        onTap: () => _openDocument(_faceVerificationDocument),
      ),
      _LegalTile(
        icon: Icons.groups_outlined,
        title: _communityDocument.title.resolve(context),
        onTap: () => _openDocument(_communityDocument),
      ),
      _LegalTile(
        icon: Icons.child_care_outlined,
        title: _adultEligibilityDocument.title.resolve(context),
        onTap: () => _openDocument(_adultEligibilityDocument),
      ),
      _LegalTile(
        icon: Icons.rule_outlined,
        title: _contentSafetyDocument.title.resolve(context),
        onTap: () => _openDocument(_contentSafetyDocument),
      ),
      _LegalTile(
        icon: Icons.location_on_outlined,
        title: _locationDocument.title.resolve(context),
        onTap: () => _openDocument(_locationDocument),
      ),
      _LegalTile(
        icon: Icons.tune_outlined,
        title: 'Privacy controls',
        onTap: () => Navigator.pushNamed(context, AppRoutes.privacy),
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
          'Questions about privacy or these documents can be sent to privacy@maplov.ca. General support is available at support@maplov.ca.',
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

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({required this.document});

  final _LegalDocument document;

  @override
  Widget build(BuildContext context) => _AppPage(
    title: document.title.resolve(context),
    children: [
      Text(
        '${document.effectiveDate.resolve(context)} • '
        '${Localizations.localeOf(context).languageCode == 'fr' ? 'Version' : 'Version'} '
        '${document.version}',
        style: const TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 8),
      ...document.sections.expand(
        (section) => [
          _SectionTitle(section.title.resolve(context)),
          SelectableText(
            section.body.resolve(context),
            style: const TextStyle(height: 1.48),
          ),
        ],
      ),
      const SizedBox(height: 22),
      SelectableText(
        document.contact.resolve(context),
        style: const TextStyle(
          color: AppColors.grayText,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

const _termsDocument = _LegalDocument(
  key: 'terms_of_use',
  version: _legalDraftVersion,
  title: _LegalCopy('Terms of Use', 'Conditions d’utilisation'),
  effectiveDate: _LegalCopy(
    'Effective date: July 30, 2026 — legal-review draft',
    'Date d’entrée en vigueur : 30 juillet 2026 — projet à réviser juridiquement',
  ),
  contact: _LegalCopy(
    'Questions about these Terms: support@maplov.ca',
    'Questions au sujet des présentes conditions : support@maplov.ca',
  ),
  sections: [
    _LegalSection(
      title: _LegalCopy(
        '1. Agreement and operator',
        '1. Entente et exploitant',
      ),
      body: _LegalCopy(
        'These Terms govern access to the MapLov mobile application, the future maplov.ca website and related services (together, the “Service”). MapLov is the dating-service brand operating the Service in Canada. The final legal name and postal address of the operator must be displayed before commercial launch. By creating an account or using the Service, you enter into a contract with that operator and agree to these Terms, the Community Guidelines and any purchase terms shown before payment. The Privacy Policy describes MapLov’s personal-information practices; acknowledging it does not waive any privacy right or constitute consent to every optional data use.',
        'Les présentes conditions régissent l’accès à l’application mobile MapLov, au futur site maplov.ca et aux services connexes (collectivement, le « Service »). MapLov est la marque du service de rencontres qui exploite le Service au Canada. La dénomination juridique et l’adresse postale définitives de l’exploitant devront être affichées avant le lancement commercial. En créant un compte ou en utilisant le Service, vous concluez un contrat avec cet exploitant et acceptez les présentes conditions, les Règles de la communauté ainsi que les modalités d’achat présentées avant le paiement. La Politique de confidentialité décrit les pratiques de MapLov en matière de renseignements personnels; en prendre connaissance ne vous fait renoncer à aucun droit et ne vaut pas consentement à toutes les utilisations facultatives.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '2. Eligibility and one-person-one-account rule',
        '2. Admissibilité et règle d’un compte par personne',
      ),
      body: _LegalCopy(
        'You may use MapLov only if you are at least 18 years old, can legally enter into a contract, are not prohibited from using the Service by law and have not been permanently removed for a serious safety violation. An account is personal, non-transferable and may not be shared. Unless MapLov expressly authorizes recovery or migration, each person may maintain only one account. You must provide truthful age, identity and account information and keep it reasonably current. MapLov may request proportionate verification when needed for age, account security, fraud prevention or safety.',
        'Vous pouvez utiliser MapLov uniquement si vous avez au moins 18 ans, avez la capacité juridique de conclure un contrat, n’êtes pas légalement empêché d’utiliser le Service et n’avez pas été exclu définitivement pour une violation grave de sécurité. Le compte est personnel, incessible et ne peut être partagé. Sauf autorisation expresse de MapLov dans le cadre d’une récupération ou d’une migration, chaque personne ne peut conserver qu’un seul compte. Vous devez fournir des renseignements véridiques sur votre âge, votre identité et votre compte, puis les maintenir raisonnablement à jour. MapLov peut demander une vérification proportionnée lorsque celle-ci est nécessaire pour l’âge, la sécurité du compte, la prévention de la fraude ou la sécurité.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '3. Account security and communications',
        '3. Sécurité du compte et communications',
      ),
      body: _LegalCopy(
        'Protect your password, verification links and one-time codes. Notify support promptly if you believe someone accessed your account without permission. You are responsible for activity performed through your account until you report unauthorized access, except to the extent applicable law provides otherwise. MapLov may send transactional messages needed to verify or secure your account, operate purchases, answer support requests and give legally required notices. Marketing communications, if introduced, will use a separate consent and unsubscribe process where required.',
        'Protégez votre mot de passe, vos liens de vérification et vos codes à usage unique. Avisez rapidement le soutien si vous croyez qu’une personne a accédé à votre compte sans autorisation. Vous êtes responsable des activités effectuées au moyen de votre compte jusqu’au signalement de l’accès non autorisé, sous réserve des protections prévues par la loi applicable. MapLov peut envoyer les messages transactionnels nécessaires pour vérifier ou sécuriser votre compte, traiter les achats, répondre au soutien et transmettre les avis exigés par la loi. Toute communication marketing éventuellement offerte fera l’objet d’un consentement et d’un mécanisme de désabonnement distincts lorsque la loi l’exige.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '4. Respect, consent and personal safety',
        '4. Respect, consentement et sécurité personnelle',
      ),
      body: _LegalCopy(
        'Treat every person with dignity. Consent to conversation, intimacy, photography or sharing must be voluntary, informed, specific and reversible. A match, like, friendship, message, profile view or Secret Garden permission never establishes consent to any sexual activity or to reuse private content. Stop contacting someone who asks you to stop. Use caution before meeting, meet in a public place, tell someone you trust and never send money or financial credentials to another member. For immediate danger, contact local emergency services; in-app reporting is not an emergency service.',
        'Traitez toute personne avec dignité. Le consentement à une conversation, à l’intimité, à une photographie ou à un partage doit être libre, éclairé, précis et révocable. Une correspondance, une mention J’aime, une amitié, un message, une consultation de profil ou une autorisation d’accès au Jardin secret ne constitue jamais un consentement à une activité sexuelle ni à la réutilisation d’un contenu privé. Cessez de communiquer avec une personne qui le demande. Soyez prudent avant une rencontre, choisissez un lieu public, informez une personne de confiance et n’envoyez jamais d’argent ni d’identifiants financiers à un autre membre. En cas de danger immédiat, communiquez avec les services d’urgence locaux; le signalement dans l’application n’est pas un service d’urgence.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('5. Prohibited conduct', '5. Conduites interdites'),
      body: _LegalCopy(
        'You must not harass, threaten, stalk, exploit, discriminate against, defraud, impersonate or endanger anyone; solicit money, passwords or financial information; facilitate trafficking, sexual exploitation, illegal sexual services or criminal activity; groom or sexualize a minor; distribute intimate material without the depicted person’s consent; misuse reporting or appeals; evade a suspension or ban; scrape profiles; use bots or unauthorized automation; probe security; introduce malicious code; reverse engineer the Service except where law permits; use member data to train an artificial-intelligence system; spam, advertise or recruit without written permission; or use MapLov for surveillance, background investigations or decisions about employment, housing, credit or insurance.',
        'Il est interdit de harceler, menacer, traquer, exploiter, discriminer, frauder, usurper l’identité ou mettre en danger une personne; de solliciter de l’argent, des mots de passe ou des renseignements financiers; de faciliter la traite, l’exploitation sexuelle, des services sexuels illégaux ou une activité criminelle; de préparer ou sexualiser un mineur; de diffuser du contenu intime sans le consentement de la personne représentée; d’abuser des mécanismes de signalement ou d’appel; de contourner une suspension ou une exclusion; d’extraire des profils; d’utiliser des robots ou une automatisation non autorisée; de tester illégalement la sécurité; d’introduire du code malveillant; de désosser le Service sauf lorsque la loi le permet; d’utiliser les données des membres pour entraîner un système d’intelligence artificielle; d’envoyer du pourriel, de faire de la publicité ou du recrutement sans autorisation écrite; ou d’utiliser MapLov à des fins de surveillance, d’enquête sur les antécédents ou de décision concernant l’emploi, le logement, le crédit ou l’assurance.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('6. Prohibited content', '6. Contenu interdit'),
      body: _LegalCopy(
        'Do not upload or send content that is illegal; depicts or sexualizes a minor; promotes child sexual abuse, grooming, sextortion, trafficking, terrorism or violent extremism; contains non-consensual intimate imagery; credibly threatens violence or self-harm; promotes hatred against a protected group; is deliberately fraudulent or defamatory; infringes privacy, publicity or intellectual-property rights; exposes another person’s address, financial data or private communications without authority; contains malware; or is unrelated commercial solicitation. Profile and public-post content must be suitable for an adults-only dating community. Private areas are not exempt from consent, safety or criminal laws.',
        'Ne téléversez et n’envoyez aucun contenu illégal; représentant ou sexualisant un mineur; faisant la promotion de l’exploitation sexuelle d’enfants, du conditionnement, de la sextorsion, de la traite, du terrorisme ou de l’extrémisme violent; comportant des images intimes non consensuelles; menaçant de façon crédible de violence ou d’automutilation; encourageant la haine envers un groupe protégé; délibérément frauduleux ou diffamatoire; portant atteinte à la vie privée, au droit à l’image ou à la propriété intellectuelle; révélant sans autorisation l’adresse, les renseignements financiers ou les communications privées d’une autre personne; contenant un logiciel malveillant; ou constituant une sollicitation commerciale sans rapport avec le Service. Le contenu des profils et des publications doit convenir à une communauté de rencontres réservée aux adultes. Les espaces privés ne sont pas soustraits aux règles de consentement, de sécurité ni au droit criminel.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '7. Your content and the licence needed to operate MapLov',
        '7. Votre contenu et la licence nécessaire au fonctionnement de MapLov',
      ),
      body: _LegalCopy(
        'You keep ownership of content you create. You confirm that you have the rights and permissions needed to upload it. You grant MapLov a non-exclusive, worldwide, royalty-free licence to host, reproduce, format, transmit and display that content only as reasonably necessary to provide, secure, moderate and improve the Service, honour your visibility choices and comply with law. This licence does not authorize MapLov to sell your private messages, private selfie or intimate content. It ends when the content and associated account data are deleted, except for limited backups, evidence preserved for a lawful safety matter and content retained by another member in accordance with law. Other members receive no licence to copy or redistribute your content merely because they can view it.',
        'Vous demeurez propriétaire du contenu que vous créez. Vous confirmez disposer des droits et autorisations nécessaires pour le téléverser. Vous accordez à MapLov une licence non exclusive, mondiale et sans redevance permettant d’héberger, reproduire, mettre en forme, transmettre et afficher ce contenu uniquement dans la mesure raisonnablement nécessaire pour fournir, sécuriser, modérer et améliorer le Service, respecter vos choix de visibilité et se conformer à la loi. Cette licence n’autorise pas MapLov à vendre vos messages privés, votre selfie privé ou votre contenu intime. Elle prend fin lorsque le contenu et les données du compte sont supprimés, sauf pour des sauvegardes limitées, des éléments de preuve conservés dans le cadre légal d’un dossier de sécurité et du contenu conservé légalement par un autre membre. Le simple fait de pouvoir voir votre contenu ne donne à aucun membre le droit de le copier ou de le redistribuer.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '8. Matching, verification and no guarantee',
        '8. Mise en relation, vérification et absence de garantie',
      ),
      body: _LegalCopy(
        'MapLov uses profile information, preferences, filters, location choices and interaction signals to sort or recommend profiles. Compatibility percentages and recommendations are informational estimates, not professional assessments or promises of a relationship. Email, phone, photo or selfie checks confirm only limited technical signals and do not establish a member’s character, intentions, criminal history, health or complete identity. Face comparison is probabilistic and can be wrong. MapLov does not routinely conduct criminal-record or sex-offender checks. You remain responsible for your interactions and should independently exercise judgment.',
        'MapLov utilise les renseignements du profil, les préférences, les filtres, les choix de localisation et les signaux d’interaction pour classer ou recommander des profils. Les pourcentages de compatibilité et recommandations sont des estimations informatives, non des évaluations professionnelles ni des promesses de relation. Les vérifications de courriel, de téléphone, de photo ou de selfie ne confirment que certains signaux techniques et n’établissent ni le caractère, ni les intentions, ni les antécédents criminels, ni la santé, ni l’identité complète d’un membre. La comparaison faciale est probabiliste et peut être erronée. MapLov n’effectue pas systématiquement de vérification des casiers judiciaires ou des registres de délinquants sexuels. Vous demeurez responsable de vos interactions et devez exercer votre propre jugement.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '9. Moderation, reports and appeals',
        '9. Modération, signalements et appels',
      ),
      body: _LegalCopy(
        'MapLov may investigate reports, review relevant account or content records, restrict visibility, remove content, limit features, suspend or close accounts and preserve or disclose information when reasonably necessary for safety, enforcement or legal compliance. Automated signals may help prioritize potential abuse, but material account decisions should be reviewable by an authorized person where appropriate. MapLov may notify a reporter that action was taken without revealing confidential details. If you believe a moderation or face-comparison decision is wrong, contact support@maplov.ca with enough information to locate the decision. Repeatedly false or abusive reports may themselves violate these Terms.',
        'MapLov peut enquêter sur les signalements, examiner les données pertinentes du compte ou du contenu, restreindre la visibilité, supprimer du contenu, limiter des fonctions, suspendre ou fermer des comptes et conserver ou communiquer des renseignements lorsque cela est raisonnablement nécessaire à la sécurité, à l’application des règles ou au respect de la loi. Des signaux automatisés peuvent aider à prioriser les abus potentiels, mais les décisions importantes concernant un compte devraient pouvoir être réexaminées par une personne autorisée lorsque cela est approprié. MapLov peut informer l’auteur d’un signalement qu’une mesure a été prise sans révéler de détails confidentiels. Si vous estimez qu’une décision de modération ou de comparaison faciale est erronée, écrivez à support@maplov.ca avec suffisamment d’information pour retrouver la décision. Les signalements faux ou abusifs répétés peuvent eux-mêmes contrevenir aux présentes conditions.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '10. Privacy, location and biometric processing',
        '10. Vie privée, localisation et traitement biométrique',
      ),
      body: _LegalCopy(
        'The Privacy Policy explains what MapLov collects and why. Precise location is requested only for user-initiated foreground features and is not displayed as raw coordinates to members. The private registration selfie and face-comparison process are governed by a separate Face Verification Notice and an express consent presented immediately before capture. Accepting these Terms alone is not biometric consent. If MapLov materially changes a sensitive-data purpose or service provider, it must provide appropriate notice and obtain a new consent where required.',
        'La Politique de confidentialité explique les renseignements recueillis par MapLov et leurs finalités. La localisation précise est demandée uniquement pour des fonctions de premier plan déclenchées par l’utilisateur et les coordonnées brutes ne sont pas affichées aux membres. Le selfie privé d’inscription et le processus de comparaison faciale sont régis par un Avis sur la vérification faciale distinct et par un consentement exprès présenté immédiatement avant la capture. L’acceptation des présentes conditions ne constitue pas à elle seule un consentement biométrique. Si MapLov modifie de façon importante la finalité d’un renseignement sensible ou un fournisseur qui le traite, MapLov doit fournir l’avis approprié et obtenir un nouveau consentement lorsque la loi l’exige.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '11. Subscriptions, renewal and refunds',
        '11. Abonnements, renouvellement et remboursements',
      ),
      body: _LegalCopy(
        'Optional subscriptions are sold through Apple’s App Store or Google Play. The store checkout shows the price, billing period, taxes and renewal terms before you confirm. Unless the store offer says otherwise, a recurring subscription renews automatically until cancelled through the same store account. Deleting MapLov or closing a MapLov account does not automatically cancel store billing. Cancel renewal in the store settings before the deadline shown by that store; paid benefits generally remain available until the current period ends. The applicable store processes payment, cancellation and refund requests, subject to mandatory consumer law. MapLov may change future plan features or prices with the notice and consent required by the store and applicable law, but will not retroactively reduce a paid period where prohibited.',
        'Les abonnements facultatifs sont vendus par l’App Store d’Apple ou Google Play. Avant la confirmation, la page de paiement de la boutique affiche le prix, la période de facturation, les taxes et les modalités de renouvellement. Sauf indication contraire de l’offre de la boutique, un abonnement récurrent se renouvelle automatiquement jusqu’à son annulation dans le même compte de boutique. La suppression de MapLov ou la fermeture d’un compte MapLov n’annule pas automatiquement la facturation par la boutique. Annulez le renouvellement dans les paramètres de la boutique avant l’échéance qu’elle indique; les avantages payés demeurent généralement accessibles jusqu’à la fin de la période en cours. La boutique concernée traite les paiements, annulations et demandes de remboursement, sous réserve des lois impératives de protection du consommateur. MapLov peut modifier les fonctions ou prix futurs d’un forfait avec l’avis et le consentement exigés par la boutique et la loi applicable, mais ne réduira pas rétroactivement une période payée lorsque la loi l’interdit.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '12. MapLov intellectual property and limited licence',
        '12. Propriété intellectuelle de MapLov et licence limitée',
      ),
      body: _LegalCopy(
        'MapLov, its interface, software, designs, text, logos and non-member content are owned by or licensed to the operator and are protected by applicable law. While your account remains authorized, MapLov grants you a personal, limited, revocable, non-exclusive and non-transferable licence to use the Service for its intended non-commercial purpose. No source code, API, brand element or proprietary dataset is licensed except as expressly stated. Feedback may be used without payment or confidentiality obligation, but MapLov will not claim ownership of personal information included in feedback.',
        'MapLov, son interface, ses logiciels, ses conceptions, ses textes, ses logos et le contenu qui ne provient pas des membres appartiennent à l’exploitant ou lui sont concédés sous licence et sont protégés par la loi applicable. Tant que votre compte est autorisé, MapLov vous accorde une licence personnelle, limitée, révocable, non exclusive et incessible permettant d’utiliser le Service conformément à sa finalité non commerciale. Aucun code source, API, élément de marque ou jeu de données exclusif n’est concédé sauf mention expresse. MapLov peut utiliser vos commentaires sans paiement ni obligation de confidentialité, mais ne revendique pas la propriété des renseignements personnels qu’ils contiennent.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '13. Third-party and app-store terms',
        '13. Services tiers et modalités des boutiques',
      ),
      body: _LegalCopy(
        'Some functions depend on service providers and device platforms, including Supabase, AWS, Apple and Google. Their services may have separate terms and privacy notices. Apple and Google are not responsible for operating MapLov, its member content or support, except for obligations they expressly assume as store providers. If store terms conflict with these Terms concerning billing or platform use, the mandatory store terms control for that issue. MapLov is responsible for addressing claims about the application to the extent required by applicable law.',
        'Certaines fonctions dépendent de fournisseurs et de plateformes, notamment Supabase, AWS, Apple et Google. Leurs services peuvent être régis par des conditions et avis de confidentialité distincts. Apple et Google ne sont pas responsables de l’exploitation de MapLov, du contenu des membres ou du soutien, sauf pour les obligations qu’ils assument expressément à titre de boutiques. Si les conditions d’une boutique contredisent les présentes conditions en matière de facturation ou d’utilisation de la plateforme, les règles impératives de la boutique prévalent pour cette question. MapLov demeure responsable du traitement des réclamations relatives à l’application dans la mesure exigée par la loi applicable.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '14. Suspension, closure and deletion',
        '14. Suspension, fermeture et suppression',
      ),
      body: _LegalCopy(
        'You may stop using MapLov and request account deletion in Settings. A deletion request hides the account promptly and schedules permanent erasure after the stated 30-day recovery period, subject to limited legal preservation. MapLov may suspend or close an account for breach, credible safety risk, fraud, legal requirement or prolonged technical unavailability. When reasonably possible and safe, MapLov will state the general reason and offer a review channel. Closing an account ends the user licence but does not cancel an external store subscription or eliminate provisions that logically survive, including payment obligations, content responsibility, dispute terms and lawful evidence preservation.',
        'Vous pouvez cesser d’utiliser MapLov et demander la suppression du compte dans les paramètres. La demande masque rapidement le compte et planifie l’effacement définitif après la période de récupération annoncée de 30 jours, sous réserve d’une conservation juridique limitée. MapLov peut suspendre ou fermer un compte en cas de violation, de risque crédible pour la sécurité, de fraude, d’exigence légale ou d’indisponibilité technique prolongée. Lorsque cela est raisonnablement possible et sécuritaire, MapLov indiquera le motif général et offrira un mécanisme de révision. La fermeture met fin à la licence d’utilisation, mais n’annule pas un abonnement externe et ne supprime pas les dispositions qui doivent logiquement survivre, notamment les obligations de paiement, la responsabilité liée au contenu, les règles de règlement des différends et la conservation légale d’éléments de preuve.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '15. Service availability and legal warranties',
        '15. Disponibilité du Service et garanties légales',
      ),
      body: _LegalCopy(
        'MapLov is provided using reasonable care, but internet and dating services can experience errors, outages, data loss, unauthorized conduct and inaccurate recommendations. MapLov does not promise uninterrupted availability, a particular number of members, a match, a meeting or any outcome from an interaction. Nothing in these Terms excludes a warranty, remedy or consumer right that cannot legally be excluded. Any disclaimer applies only to the maximum extent permitted by the law that protects you.',
        'MapLov est fourni avec un soin raisonnable, mais les services Internet et de rencontres peuvent subir des erreurs, des interruptions, des pertes de données, des comportements non autorisés et des recommandations inexactes. MapLov ne garantit ni une disponibilité ininterrompue, ni un nombre donné de membres, ni une correspondance, ni une rencontre, ni un résultat découlant d’une interaction. Aucune disposition des présentes conditions n’exclut une garantie, un recours ou un droit du consommateur qui ne peut être légalement exclu. Toute exclusion s’applique uniquement dans la mesure maximale permise par la loi qui vous protège.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '16. Responsibility and limits permitted by law',
        '16. Responsabilité et limites permises par la loi',
      ),
      body: _LegalCopy(
        'Each party remains responsible for loss it causes under applicable law. To the extent the law permits, MapLov is not responsible for indirect or unforeseeable loss caused solely by another member, an external platform or an event beyond reasonable control. MapLov does not exclude responsibility for fraud, wilful misconduct, gross negligence, bodily injury caused by its fault, breach of privacy obligations or any liability that law does not allow it to limit. You are responsible for claims caused by content you had no right to upload or by your unlawful misuse of the Service, but only to the extent established under applicable law.',
        'Chaque partie demeure responsable des pertes qu’elle cause selon la loi applicable. Dans la mesure permise par la loi, MapLov n’est pas responsable des pertes indirectes ou imprévisibles causées uniquement par un autre membre, une plateforme externe ou un événement échappant raisonnablement à son contrôle. MapLov n’exclut aucune responsabilité pour fraude, faute intentionnelle, faute lourde, préjudice corporel causé par sa faute, violation de ses obligations de confidentialité ou responsabilité que la loi interdit de limiter. Vous êtes responsable des réclamations causées par un contenu que vous n’aviez pas le droit de téléverser ou par votre utilisation illégale du Service, mais uniquement dans la mesure établie par la loi applicable.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '17. Governing law and disputes',
        '17. Droit applicable et différends',
      ),
      body: _LegalCopy(
        'These Terms are governed by the laws of Ontario and the federal laws of Canada applicable there, without depriving you of mandatory protections in your province or territory. Before starting a proceeding, the parties should attempt in good faith to resolve the issue through support@maplov.ca, unless urgency, safety or a limitation period makes that impractical. Courts with lawful jurisdiction may hear unresolved disputes. These Terms do not impose mandatory private arbitration, waive a class proceeding, restrict a complaint to a consumer or privacy regulator, or prevent use of a small-claims process where available.',
        'Les présentes conditions sont régies par les lois de l’Ontario et les lois fédérales du Canada qui y sont applicables, sans vous priver des protections impératives de votre province ou territoire. Avant d’intenter une procédure, les parties devraient tenter de bonne foi de résoudre le problème par l’intermédiaire de support@maplov.ca, sauf si l’urgence, la sécurité ou un délai de prescription rend cette démarche impraticable. Les tribunaux légalement compétents peuvent entendre les différends non résolus. Les présentes conditions n’imposent pas d’arbitrage privé obligatoire, ne comportent aucune renonciation à un recours collectif, ne limitent pas le droit de porter plainte auprès d’un organisme de protection du consommateur ou de la vie privée et n’empêchent pas le recours à la Cour des petites créances lorsqu’il est offert.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '18. Changes and general terms',
        '18. Modifications et dispositions générales',
      ),
      body: _LegalCopy(
        'MapLov may update these Terms to reflect law, security, providers or Service changes. Material changes will be explained before they take effect and will require affirmative acceptance when required. If you do not accept a material change, you may stop using the Service and delete your account. If one provision is unenforceable, the rest remains effective to the extent lawful. A failure to enforce once is not a waiver. MapLov may transfer this agreement only as part of a legitimate reorganization, financing or sale that preserves applicable user and privacy rights. You may not transfer your account.',
        'MapLov peut modifier les présentes conditions afin de refléter une évolution de la loi, de la sécurité, des fournisseurs ou du Service. Les modifications importantes seront expliquées avant leur entrée en vigueur et feront l’objet d’une acceptation affirmative lorsque la loi l’exige. Si vous refusez une modification importante, vous pouvez cesser d’utiliser le Service et supprimer votre compte. Si une disposition est inexécutoire, les autres demeurent en vigueur dans la mesure permise. Le fait de ne pas appliquer une règle une fois ne constitue pas une renonciation. MapLov peut transférer cette entente uniquement dans le cadre d’une réorganisation, d’un financement ou d’une vente légitime qui préserve les droits applicables des utilisateurs et leur vie privée. Vous ne pouvez pas transférer votre compte.',
      ),
    ),
  ],
);

const _privacyDocument = _LegalDocument(
  key: 'privacy_policy',
  version: _legalDraftVersion,
  title: _LegalCopy('Privacy Policy', 'Politique de confidentialité'),
  effectiveDate: _LegalCopy(
    'Effective date: July 30, 2026 — legal-review draft',
    'Date d’entrée en vigueur : 30 juillet 2026 — projet à réviser juridiquement',
  ),
  contact: _LegalCopy(
    'Privacy Officer: privacy@maplov.ca',
    'Responsable de la protection des renseignements personnels : privacy@maplov.ca',
  ),
  sections: [
    _LegalSection(
      title: _LegalCopy(
        '1. Scope and accountability',
        '1. Portée et responsabilité',
      ),
      body: _LegalCopy(
        'This Policy applies to MapLov’s mobile application, maplov.ca and related support, safety and account services. MapLov is accountable for personal information under its control, including information processed by service providers. Before launch, MapLov must publish the final legal operator name, postal address and the title or contact details of the person responsible for privacy compliance. Questions, access requests and complaints may be sent to privacy@maplov.ca. This Policy is designed for Canadian private-sector privacy requirements, including PIPEDA and applicable provincial law; rights may vary by province.',
        'La présente politique s’applique à l’application mobile MapLov, à maplov.ca ainsi qu’aux services connexes de soutien, de sécurité et de gestion des comptes. MapLov est responsable des renseignements personnels sous son contrôle, y compris ceux traités par ses fournisseurs. Avant le lancement, MapLov devra publier la dénomination juridique et l’adresse postale définitives de l’exploitant ainsi que le titre ou les coordonnées de la personne responsable de la conformité en matière de vie privée. Les questions, demandes d’accès et plaintes peuvent être envoyées à privacy@maplov.ca. La présente politique est conçue en fonction des règles canadiennes applicables au secteur privé, notamment la LPRPDE et les lois provinciales pertinentes; les droits peuvent varier selon la province.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '2. Information you provide',
        '2. Renseignements que vous fournissez',
      ),
      body: _LegalCopy(
        'Account information includes your name, email, phone number, password handled by Supabase Auth, date of birth, residence and legal-policy acceptance records. Profile information can include gender identity, the genders you wish to meet, relationship goals, languages, origin, city, profession, education, interests, habits, religion, political views, body-type selection, biography and visibility choices. You may provide photos, posts, comments, private messages, audio messages and Secret Garden content. Support and safety information includes reports, blocks, appeals, correspondence and evidence you choose to submit. Purchase records include store, product, transaction identifier, subscription status, period and refund or renewal events; MapLov does not receive your complete payment-card number from an app store.',
        'Les renseignements de compte comprennent notamment votre nom, votre adresse courriel, votre numéro de téléphone, votre mot de passe traité par Supabase Auth, votre date de naissance, votre lieu de résidence et les preuves d’acceptation des documents juridiques. Le profil peut comprendre l’identité de genre, les genres recherchés, les objectifs relationnels, les langues, l’origine, la ville, la profession, les études, les centres d’intérêt, les habitudes, la religion, les opinions politiques, la silhouette choisie, la biographie et les choix de visibilité. Vous pouvez fournir des photos, publications, commentaires, messages privés, messages audio et du contenu du Jardin secret. Les données de soutien et de sécurité comprennent les signalements, blocages, appels, correspondances et éléments de preuve que vous transmettez. Les données d’achat comprennent la boutique, le produit, l’identifiant de transaction, l’état de l’abonnement, la période et les événements de remboursement ou de renouvellement; MapLov ne reçoit pas le numéro complet de votre carte de paiement d’une boutique d’applications.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '3. Sensitive dating and profile information',
        '3. Renseignements sensibles de rencontres et de profil',
      ),
      body: _LegalCopy(
        'A dating profile and its preferences can reveal or suggest sexual orientation, sex life, gender identity, ethnic or national origin, religion, political views, health-related habits and precise social relationships. MapLov treats these fields as sensitive even when you make selected profile details visible. Required and optional fields should be clearly distinguished at collection. You control many visibility settings and can edit most profile fields. MapLov uses this information to provide filters, matching and the visibility choices you request; it is not sold to data brokers or used for employment, housing, credit or insurance decisions.',
        'Un profil de rencontres et ses préférences peuvent révéler ou suggérer l’orientation sexuelle, la vie sexuelle, l’identité de genre, l’origine ethnique ou nationale, la religion, les opinions politiques, des habitudes liées à la santé et des relations sociales précises. MapLov traite ces champs comme sensibles même lorsque vous rendez certains éléments visibles. Les champs obligatoires et facultatifs devraient être clairement distingués au moment de la collecte. Vous contrôlez plusieurs paramètres de visibilité et pouvez modifier la plupart des champs du profil. MapLov utilise ces renseignements pour fournir les filtres, la mise en relation et les choix de visibilité demandés; ils ne sont pas vendus à des courtiers en données ni utilisés pour des décisions d’emploi, de logement, de crédit ou d’assurance.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '4. Private selfie and face-comparison data',
        '4. Selfie privé et données de comparaison faciale',
      ),
      body: _LegalCopy(
        'During registration, MapLov currently asks for one clear private selfie. With a separate express consent, the image is stored in a private Supabase Storage bucket as the account’s reference selfie. MapLov sends image bytes to Amazon Rekognition DetectFaces and CompareFaces to confirm that one face is present, compare the registration selfie with existing private reference selfies to detect duplicate accounts, and compare later profile photos with the account reference. MapLov records technical results such as similarity score, threshold, status, time and provider request identifier. It does not display the reference selfie, create a public face profile or use it for advertising. MapLov’s code does not create an AWS face collection; AWS processing remains subject to MapLov’s AWS contract, region and AI-service opt-out settings. Face matching is probabilistic and can produce false matches or rejections. A rejected person may request human review through support. The separate Face Verification Notice explains the purpose, risks, retention and consequences immediately before capture.',
        'Pendant l’inscription, MapLov demande actuellement un selfie privé et net. Avec un consentement exprès distinct, l’image est conservée dans un compartiment privé de Supabase Storage comme selfie de référence du compte. MapLov transmet les octets des images aux fonctions DetectFaces et CompareFaces d’Amazon Rekognition afin de confirmer la présence d’un seul visage, de comparer le selfie d’inscription aux selfies privés de référence existants pour détecter les comptes en double, puis de comparer les futures photos de profil à la référence du compte. MapLov consigne des résultats techniques comme le score de similitude, le seuil, l’état, l’heure et l’identifiant de requête du fournisseur. Le selfie de référence n’est pas affiché, n’est pas transformé en profil facial public et n’est pas utilisé à des fins publicitaires. Le code de MapLov ne crée pas de collection de visages AWS; le traitement par AWS demeure régi par le contrat, la région et les paramètres d’exclusion des services d’IA du compte AWS de MapLov. La comparaison faciale est probabiliste et peut produire de faux rapprochements ou refus. Une personne refusée peut demander une révision humaine au soutien. L’Avis sur la vérification faciale distinct explique la finalité, les risques, la conservation et les conséquences immédiatement avant la capture.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '5. Location and device permissions',
        '5. Localisation et autorisations de l’appareil',
      ),
      body: _LegalCopy(
        'When you grant foreground location permission, MapLov can receive latitude, longitude, accuracy, city, region and country from the device and geocoding services. Current code requests location during registration to confirm residence and when you open or refresh nearby discovery; it does not request background location. Coordinates support distance and discovery filters. Members see only an approximate distance when you enable that display, not raw coordinates. Camera, photo-library and microphone permissions are used only when you choose the related capture, upload or audio-message feature. Operating-system settings let you revoke a permission, though the related feature may stop working.',
        'Lorsque vous accordez l’autorisation de localisation au premier plan, MapLov peut recevoir la latitude, la longitude, la précision, la ville, la région et le pays depuis l’appareil et les services de géocodage. Le code actuel demande la localisation pendant l’inscription afin de confirmer la résidence, puis lorsque vous ouvrez ou actualisez la découverte à proximité; il ne demande pas la localisation en arrière-plan. Les coordonnées servent à calculer la distance et à appliquer les filtres de découverte. Les membres ne voient qu’une distance approximative lorsque vous activez cet affichage, jamais les coordonnées brutes. Les autorisations de caméra, de photothèque et de microphone sont utilisées uniquement lorsque vous choisissez la fonction correspondante de capture, de téléversement ou de message audio. Les paramètres du système permettent de révoquer une autorisation, mais la fonction concernée peut alors cesser de fonctionner.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '6. Information generated when you use MapLov',
        '6. Renseignements générés par votre utilisation',
      ),
      body: _LegalCopy(
        'MapLov generates interaction records such as likes, matches, friendships, profile views, blocks, reports, notifications, message status, post reactions, Garden access and discovery preferences. It also receives technical records needed to authenticate requests, prevent abuse and troubleshoot, including account and session identifiers, IP-related server logs, timestamps, app or operating-system details, errors and security events made available by the platform or providers. MapLov does not currently include a third-party advertising SDK or a behavioural-advertising profile in the Flutter application.',
        'MapLov génère des données d’interaction comme les mentions J’aime, correspondances, amitiés, consultations de profil, blocages, signalements, notifications, états de messages, réactions aux publications, accès au Jardin et préférences de découverte. MapLov reçoit aussi les données techniques nécessaires pour authentifier les requêtes, prévenir les abus et résoudre les problèmes, notamment des identifiants de compte et de session, des journaux de serveur liés à l’adresse IP, des horodatages, des renseignements sur l’application ou le système d’exploitation, des erreurs et des événements de sécurité fournis par la plateforme ou les fournisseurs. L’application Flutter n’intègre actuellement aucun SDK publicitaire tiers ni profil de publicité comportementale.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '7. Why MapLov uses information',
        '7. Finalités de l’utilisation',
      ),
      body: _LegalCopy(
        'MapLov uses personal information to create and secure accounts; verify email and, when enabled, phone; build and display profiles; apply preferences and filters; calculate approximate distance and compatibility; enable likes, matches, friendships, messaging, posts and private-sharing controls; verify photos and limit duplicate accounts; process and restore subscriptions; provide support; investigate reports; prevent fraud, exploitation and unauthorized access; maintain, debug and improve the Service; comply with lawful requests; and establish or defend legal rights. Optional sensitive fields, precise location and biometric processing require an appropriate consent. MapLov must not reuse information for a new incompatible purpose without notice and any consent required by law.',
        'MapLov utilise les renseignements personnels pour créer et sécuriser les comptes; vérifier le courriel et, lorsqu’elle est activée, le téléphone; créer et afficher les profils; appliquer les préférences et filtres; calculer la distance approximative et la compatibilité; permettre les mentions J’aime, correspondances, amitiés, messages, publications et contrôles de partage privé; vérifier les photos et limiter les comptes en double; traiter et restaurer les abonnements; fournir le soutien; enquêter sur les signalements; prévenir la fraude, l’exploitation et les accès non autorisés; maintenir, corriger et améliorer le Service; répondre aux demandes légales; et faire valoir ou défendre des droits. Les champs sensibles facultatifs, la localisation précise et le traitement biométrique exigent une forme de consentement appropriée. MapLov ne doit pas réutiliser les renseignements pour une nouvelle finalité incompatible sans avis et sans le consentement exigé par la loi.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '8. Matching and automated processing',
        '8. Mise en relation et traitement automatisé',
      ),
      body: _LegalCopy(
        'Discovery results are generated from the filters you set, the other member’s visibility and preferences, location mode, subscription entitlements and compatibility signals derived from profile answers or shared interests. Face comparison and certain abuse controls also use automated thresholds. These outputs can affect which profiles or photos are shown or whether an automated registration step continues, but they are not intended to make legal, employment, credit, insurance or housing decisions. You may change filters, correct profile information and contact support to contest a material verification or moderation result. MapLov should document and test these systems for accuracy, bias and disproportionate impact.',
        'Les résultats de découverte sont générés à partir des filtres choisis, de la visibilité et des préférences de l’autre membre, du mode de localisation, des droits liés à l’abonnement et de signaux de compatibilité dérivés des réponses du profil ou d’intérêts communs. La comparaison faciale et certains contrôles d’abus utilisent également des seuils automatisés. Ces résultats peuvent modifier les profils ou photos affichés ou déterminer si une étape automatisée d’inscription se poursuit, mais ils ne servent pas à prendre des décisions juridiques, d’emploi, de crédit, d’assurance ou de logement. Vous pouvez modifier les filtres, corriger le profil et contacter le soutien pour contester un résultat important de vérification ou de modération. MapLov devrait documenter et tester ces systèmes afin d’en évaluer l’exactitude, les biais et les effets disproportionnés.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '9. When information is visible or shared',
        '9. Visibilité et communication des renseignements',
      ),
      body: _LegalCopy(
        'Other members receive the profile and content fields that your settings and the feature make visible. A message is shared with its participants; friends-only posts with eligible friends; Secret Garden content with members to whom you grant active access. Reports are available to authorized moderation personnel and may include content involving the reported person. MapLov shares only the information reasonably needed with processors that operate hosting, authentication, storage, face comparison, transactional email, geocoding, store billing, security or professional support. It may disclose information when required by valid law, to respond to an emergency involving life or safety, to investigate serious abuse, or as part of a legitimate corporate transaction with appropriate confidentiality protections. MapLov does not sell private selfies, precise coordinates, private messages or sensitive dating preferences.',
        'Les autres membres reçoivent les champs du profil et les contenus rendus visibles par vos paramètres et par la fonction utilisée. Un message est partagé avec les participants à la conversation; une publication réservée aux amis avec les amis admissibles; le contenu du Jardin secret avec les membres auxquels vous accordez un accès actif. Les signalements sont accessibles au personnel de modération autorisé et peuvent contenir du contenu concernant la personne signalée. MapLov communique uniquement les renseignements raisonnablement nécessaires aux sous-traitants qui fournissent l’hébergement, l’authentification, le stockage, la comparaison faciale, les courriels transactionnels, le géocodage, la facturation des boutiques, la sécurité ou le soutien professionnel. MapLov peut communiquer des renseignements lorsqu’une loi valide l’exige, pour répondre à une urgence touchant la vie ou la sécurité, enquêter sur un abus grave ou réaliser une opération commerciale légitime assortie de protections de confidentialité appropriées. MapLov ne vend pas les selfies privés, les coordonnées précises, les messages privés ni les préférences sensibles de rencontres.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '10. Service providers and cross-border processing',
        '10. Fournisseurs et traitement transfrontalier',
      ),
      body: _LegalCopy(
        'Current core providers include Supabase for authentication, PostgreSQL database, server functions and private media storage; Amazon Web Services Rekognition for face detection and comparison; Namecheap Private Email for MapLov transactional email; Apple and Google for mobile distribution, device services and subscription billing; and device-platform geolocation or geocoding services. Depending on provider configuration, information can be processed outside your province or Canada and can be subject to the lawful-access rules of that jurisdiction. MapLov remains accountable for information transferred for processing and must use contracts, access limits and privacy-impact assessments appropriate to sensitivity. For Québec information sent outside Québec, MapLov must complete the required privacy-factor assessment and written processing arrangement before the transfer.',
        'Les principaux fournisseurs actuels comprennent Supabase pour l’authentification, la base PostgreSQL, les fonctions serveur et le stockage privé des médias; Amazon Web Services Rekognition pour la détection et la comparaison de visages; Namecheap Private Email pour les courriels transactionnels de MapLov; Apple et Google pour la distribution mobile, les services de l’appareil et la facturation des abonnements; ainsi que les services de géolocalisation ou de géocodage de la plateforme. Selon la configuration des fournisseurs, les renseignements peuvent être traités à l’extérieur de votre province ou du Canada et être soumis aux règles d’accès légal de cette juridiction. MapLov demeure responsable des renseignements transférés à des fins de traitement et doit utiliser des contrats, des limites d’accès et des évaluations d’impact proportionnés à leur sensibilité. Pour les renseignements québécois communiqués à l’extérieur du Québec, MapLov doit réaliser l’évaluation des facteurs relatifs à la vie privée et conclure l’entente écrite exigées avant le transfert.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '11. Retention and deletion',
        '11. Conservation et suppression',
      ),
      body: _LegalCopy(
        'MapLov keeps account, profile, content, interaction and verification information while the account is active and as needed for the purposes described above. A deletion request hides the profile immediately and schedules deletion of the authentication account, database records and user-owned storage after 30 days. The private reference selfie and face-comparison records follow that account-deletion schedule. A failed candidate upload is removed after the check; a duplicate-registration selfie is removed and MapLov attempts to erase the provisional account. Limited records may be preserved longer when required by tax, accounting, app-store, court, law-enforcement, incident-response or legal-hold obligations, or when necessary to address a serious safety dispute, and must then be isolated and deleted when the reason ends. Provider backups and logs can age out on their documented schedules. MapLov should maintain an internal retention schedule for each system rather than keep data indefinitely.',
        'MapLov conserve les données de compte, de profil, de contenu, d’interaction et de vérification pendant que le compte est actif et aussi longtemps qu’elles sont nécessaires aux finalités décrites. Une demande de suppression masque immédiatement le profil et planifie, après 30 jours, la suppression du compte d’authentification, des données de la base et du stockage appartenant à l’utilisateur. Le selfie privé de référence et les résultats de comparaison faciale suivent ce calendrier de suppression. Un téléversement candidat refusé est supprimé après la vérification; le selfie d’une inscription en double est supprimé et MapLov tente d’effacer le compte provisoire. Certains dossiers limités peuvent être conservés plus longtemps lorsqu’une obligation fiscale, comptable, liée à une boutique, judiciaire, policière, de réponse à un incident ou de préservation juridique l’exige, ou lorsqu’ils sont nécessaires pour traiter un différend grave de sécurité; ils doivent alors être isolés puis supprimés à la fin de cette nécessité. Les sauvegardes et journaux des fournisseurs peuvent expirer selon leurs calendriers documentés. MapLov devrait maintenir un calendrier interne de conservation pour chaque système plutôt que conserver les données indéfiniment.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '12. Your privacy rights and choices',
        '12. Vos droits et vos choix',
      ),
      body: _LegalCopy(
        'Settings let you edit many profile fields, visibility, approximate-distance display, online status, notifications, blocks and account deletion. Legal & Consent provides an account-data export. You may ask MapLov to explain its processing, provide access, correct inaccurate information, withdraw a consent, delete information or review a decision by contacting privacy@maplov.ca. Withdrawal does not invalidate earlier lawful processing and can disable a feature that genuinely needs the information. MapLov may verify identity before fulfilling a request and may withhold limited information where law protects another person, confidential commercial information, an investigation or legal privilege. If a request is refused, MapLov should explain the reason and available complaint route.',
        'Les paramètres permettent de modifier plusieurs champs du profil, la visibilité, l’affichage de la distance approximative, l’état en ligne, les notifications, les blocages et la suppression du compte. La section Juridique et consentement permet d’exporter les données du compte. Vous pouvez demander à MapLov d’expliquer un traitement, de donner accès aux renseignements, de corriger une inexactitude, de retirer un consentement, de supprimer des renseignements ou de réviser une décision en écrivant à privacy@maplov.ca. Le retrait n’invalide pas les traitements licites antérieurs et peut désactiver une fonction qui a réellement besoin du renseignement. MapLov peut vérifier votre identité avant de répondre et peut retenir certains renseignements lorsque la loi protège une autre personne, un renseignement commercial confidentiel, une enquête ou un privilège juridique. En cas de refus, MapLov devrait expliquer le motif et le recours offert.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '13. Safeguards and privacy incidents',
        '13. Mesures de protection et incidents',
      ),
      body: _LegalCopy(
        'MapLov uses measures proportionate to the sensitivity of dating and biometric information, including encrypted transport, authenticated access, row-level database rules, private storage buckets, short-lived signed media links, role-based administration, provider-side secrets and audit records. No system is perfectly secure. MapLov must maintain incident-response procedures, limit and investigate unauthorized access, keep legally required incident records and notify affected people and regulators when an incident creates the applicable risk threshold. Never send a password or one-time code to support.',
        'MapLov utilise des mesures proportionnées à la sensibilité des renseignements de rencontres et biométriques, notamment le chiffrement en transit, l’accès authentifié, les règles de sécurité au niveau des lignes de la base, les compartiments de stockage privés, les liens de médias signés à courte durée, l’administration fondée sur les rôles, les secrets conservés côté fournisseur et les journaux d’audit. Aucun système n’est parfaitement sécuritaire. MapLov doit maintenir une procédure de réponse aux incidents, limiter et enquêter sur les accès non autorisés, tenir les registres exigés et aviser les personnes et organismes concernés lorsqu’un incident atteint le seuil de risque applicable. Ne transmettez jamais votre mot de passe ni un code à usage unique au soutien.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '14. Adults only, policy changes and complaints',
        '14. Adultes seulement, modifications et plaintes',
      ),
      body: _LegalCopy(
        'MapLov is restricted to people aged 18 or older and does not knowingly permit minors to maintain accounts. Report a suspected underage account through the app or child-safety@maplov.ca. MapLov will give advance notice of material privacy changes and obtain a new consent when a new sensitive purpose requires one. A complaint can be sent first to the Privacy Officer at privacy@maplov.ca. You may also contact the Office of the Privacy Commissioner of Canada at priv.gc.ca or, where applicable, the Commission d’accès à l’information du Québec at cai.gouv.qc.ca and the privacy authority in your province.',
        'MapLov est réservé aux personnes âgées de 18 ans ou plus et ne permet pas sciemment à un mineur de conserver un compte. Signalez un compte potentiellement mineur dans l’application ou à child-safety@maplov.ca. MapLov donnera un avis préalable de toute modification importante de ses pratiques de confidentialité et obtiendra un nouveau consentement lorsqu’une nouvelle finalité sensible l’exige. Une plainte peut d’abord être envoyée au responsable de la protection des renseignements personnels à privacy@maplov.ca. Vous pouvez aussi communiquer avec le Commissariat à la protection de la vie privée du Canada à priv.gc.ca ou, selon le cas, avec la Commission d’accès à l’information du Québec à cai.gouv.qc.ca et l’autorité de votre province.',
      ),
    ),
  ],
);

const _cookieDocument = _LegalDocument(
  key: 'cookie_policy',
  version: _legalDraftVersion,
  title: _LegalCopy(
    'Cookie & Similar Technologies Policy',
    'Politique sur les témoins et technologies similaires',
  ),
  effectiveDate: _LegalCopy(
    'Effective date: July 30, 2026 — legal-review draft',
    'Date d’entrée en vigueur : 30 juillet 2026 — projet à réviser juridiquement',
  ),
  contact: _LegalCopy(
    'Cookie and privacy questions: privacy@maplov.ca',
    'Questions sur les témoins et la vie privée : privacy@maplov.ca',
  ),
  sections: [
    _LegalSection(
      title: _LegalCopy('1. Scope', '1. Portée'),
      body: _LegalCopy(
        'This Policy explains cookies, local storage, software-development kits and comparable technologies used by the MapLov application and maplov.ca. It should be read with the Privacy Policy. A cookie is a small value stored by a browser. Mobile applications more often use secure operating-system storage, app preferences, device permissions and provider SDK identifiers that serve similar functions.',
        'La présente politique explique les témoins, le stockage local, les trousses de développement logiciel et les technologies comparables utilisés par l’application MapLov et maplov.ca. Elle doit être lue avec la Politique de confidentialité. Un témoin est une petite valeur enregistrée par un navigateur. Les applications mobiles utilisent plus souvent le stockage sécurisé du système, les préférences de l’application, les autorisations de l’appareil et les identifiants de trousses de fournisseurs qui remplissent des fonctions semblables.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '2. Technologies used in the current release',
        '2. Technologies utilisées dans la version actuelle',
      ),
      body: _LegalCopy(
        'The current Flutter application uses technologies necessary to keep an authenticated Supabase session, remember the language and selected settings, preserve an unfinished authentication intent, secure deep-link callbacks, connect store purchases to the signed-in account and prevent abuse. The future web version can use first-party browser storage for the same essential session and preference functions. These technologies are not used to read unrelated files or browsing history from your device.',
        'L’application Flutter actuelle utilise les technologies nécessaires pour maintenir une session Supabase authentifiée, mémoriser la langue et certains paramètres, conserver l’intention d’une authentification inachevée, sécuriser les retours de liens profonds, relier les achats de boutique au compte connecté et prévenir les abus. La future version Web pourra utiliser le stockage du navigateur de première partie pour les mêmes fonctions essentielles de session et de préférences. Ces technologies ne servent pas à lire des fichiers sans rapport ni l’historique de navigation de votre appareil.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '3. Strictly necessary technologies',
        '3. Technologies strictement nécessaires',
      ),
      body: _LegalCopy(
        'Strictly necessary storage supports login, account security, load balancing, fraud prevention, legal-consent records, purchase verification and the settings required to deliver a feature you requested. Disabling this category can prevent registration, sign-in, subscription restoration or secure navigation from working. Where the law permits, use of these essential technologies is based on providing the requested service rather than optional advertising consent.',
        'Le stockage strictement nécessaire soutient la connexion, la sécurité du compte, la répartition de charge, la prévention de la fraude, les preuves de consentement juridique, la vérification des achats et les paramètres indispensables à une fonction demandée. La désactivation de cette catégorie peut empêcher l’inscription, la connexion, la restauration d’un abonnement ou la navigation sécurisée de fonctionner. Lorsque la loi le permet, ces technologies essentielles sont utilisées pour fournir le service demandé et non sur la base d’un consentement facultatif à la publicité.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '4. Preference and operational storage',
        '4. Stockage de préférences et de fonctionnement',
      ),
      body: _LegalCopy(
        'Preference storage can remember language, whether a session should remain signed in, filter selections and interface choices. Operational SDKs from Supabase, Apple, Google and device services can process technical identifiers, transaction tokens, crash or request details needed to provide their function. MapLov should maintain a current inventory naming each web cookie, mobile SDK, provider, purpose and duration before public launch.',
        'Le stockage de préférences peut mémoriser la langue, le choix de maintenir une session, les filtres et certains choix d’interface. Les trousses opérationnelles de Supabase, Apple, Google et des services de l’appareil peuvent traiter des identifiants techniques, des jetons de transaction, des erreurs ou des détails de requête nécessaires à leur fonction. MapLov devrait maintenir avant le lancement public un inventaire à jour indiquant chaque témoin Web, trousse mobile, fournisseur, finalité et durée.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '5. No advertising or optional analytics in the current app',
        '5. Aucune publicité ni analyse facultative dans l’application actuelle',
      ),
      body: _LegalCopy(
        'The current project does not include a third-party behavioural-advertising SDK, advertising cookie, social-media tracking pixel or optional product-analytics package. MapLov must not activate a non-essential analytics, personalization or advertising technology until this Policy and the technology inventory identify it and an appropriate consent control is available. If introduced, refusing optional tracking must not block core account functions.',
        'Le projet actuel n’intègre aucune trousse de publicité comportementale tierce, aucun témoin publicitaire, aucun pixel de suivi de réseau social ni aucun outil facultatif d’analyse de produit. MapLov ne doit pas activer une technologie non essentielle d’analyse, de personnalisation ou de publicité avant que la présente politique et l’inventaire technologique l’identifient et qu’un contrôle de consentement approprié soit offert. Si un tel outil est ajouté, le refus du suivi facultatif ne doit pas bloquer les fonctions essentielles du compte.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('6. Your controls', '6. Vos contrôles'),
      body: _LegalCopy(
        'You can change mobile permissions in Android or iOS settings, clear application data, sign out, uninstall the app and manage browser storage through browser controls. Clearing storage can sign you out and reset local preferences without deleting server-side account data. Use MapLov’s Delete Account control for account deletion. When the website introduces optional technologies, it should provide a preference control that is as easy to revisit as the original choice.',
        'Vous pouvez modifier les autorisations mobiles dans les réglages Android ou iOS, effacer les données de l’application, vous déconnecter, désinstaller l’application et gérer le stockage du navigateur au moyen de ses paramètres. Effacer le stockage peut vous déconnecter et réinitialiser les préférences locales sans supprimer les données du compte conservées sur les serveurs. Utilisez la fonction Supprimer le compte de MapLov pour demander la suppression du compte. Lorsque le site Web ajoutera des technologies facultatives, il devrait offrir un contrôle de préférences aussi facile à revoir que le choix initial.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        '7. Duration, updates and contact',
        '7. Durée, modifications et contact',
      ),
      body: _LegalCopy(
        'Session values last until expiry, sign-out or revocation. Preference values can remain until you clear them, uninstall the app or the application replaces them. Provider security logs and store tokens follow the retention periods described in the Privacy Policy and provider contracts. MapLov will update this Policy before materially changing tracking practices. Send questions or requests to privacy@maplov.ca.',
        'Les valeurs de session demeurent jusqu’à leur expiration, la déconnexion ou leur révocation. Les préférences peuvent subsister jusqu’à ce que vous les effaciez, désinstalliez l’application ou qu’elles soient remplacées. Les journaux de sécurité des fournisseurs et jetons de boutique suivent les périodes décrites dans la Politique de confidentialité et les contrats des fournisseurs. MapLov mettra à jour la présente politique avant toute modification importante des pratiques de suivi. Envoyez vos questions ou demandes à privacy@maplov.ca.',
      ),
    ),
  ],
);

const _faceVerificationDocument = _LegalDocument(
  key: 'face_verification_notice',
  version: 'face-verification-v3-global-dedup',
  title: _LegalCopy(
    'Face Verification Notice',
    'Avis sur la vérification faciale',
  ),
  effectiveDate: _LegalCopy(
    'Notice updated: July 30, 2026 — legal-review draft',
    'Avis mis à jour : 30 juillet 2026 — projet à réviser juridiquement',
  ),
  contact: _LegalCopy(
    'Questions, withdrawal or review request: privacy@maplov.ca',
    'Question, retrait du consentement ou demande de révision : privacy@maplov.ca',
  ),
  sections: [
    _LegalSection(
      title: _LegalCopy('What MapLov collects', 'Ce que MapLov recueille'),
      body: _LegalCopy(
        'MapLov collects one private registration selfie, facial characteristics contained in that image and technical face-comparison results. The selfie is not shown on your profile. It is stored as the single private reference associated with your account.',
        'MapLov recueille un selfie privé d’inscription, les caractéristiques faciales contenues dans cette image et les résultats techniques des comparaisons. Le selfie n’est pas affiché sur votre profil. Il est conservé comme unique référence privée associée à votre compte.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('Purposes', 'Finalités'),
      body: _LegalCopy(
        'The reference is used to check that the image contains one face, compare it with existing private references to limit duplicate accounts and compare profile-photo uploads with the consenting account holder. It is not used for advertising, public identification or a general face-search product.',
        'La référence sert à confirmer que l’image contient un seul visage, à la comparer aux références privées existantes afin de limiter les comptes en double et à comparer les photos de profil téléversées au titulaire consentant du compte. Elle n’est pas utilisée à des fins publicitaires, d’identification publique ni pour un produit général de recherche faciale.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        'How the comparison works and who receives it',
        'Fonctionnement de la comparaison et destinataire',
      ),
      body: _LegalCopy(
        'The image bytes are transmitted over an encrypted connection to Amazon Rekognition for face detection and pairwise comparison. MapLov stores the private source image in Supabase Storage and stores scores, thresholds, status, time and provider request identifiers in its database. MapLov does not create an AWS face collection. AWS handling of input images depends on MapLov’s contract and account-level AI-service settings.',
        'Les octets de l’image sont transmis par une connexion chiffrée à Amazon Rekognition pour la détection et la comparaison deux à deux des visages. MapLov conserve l’image source privée dans Supabase Storage et enregistre dans sa base les scores, seuils, états, heures et identifiants de requête du fournisseur. MapLov ne crée pas de collection de visages AWS. Le traitement des images d’entrée par AWS dépend du contrat de MapLov et des paramètres des services d’IA de son compte.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        'Risks and automated results',
        'Risques et résultats automatisés',
      ),
      body: _LegalCopy(
        'Face comparison is probabilistic. Image quality, lighting, appearance changes and model performance can cause false matches or false rejections, with potential effects on account creation or photo publication. Central storage of a face image also creates identity-theft and privacy risks if security fails. MapLov limits access and offers a support channel to contest a result, but cannot promise perfect accuracy or zero security risk.',
        'La comparaison faciale est probabiliste. La qualité de l’image, l’éclairage, les changements d’apparence et le rendement du modèle peuvent produire de faux rapprochements ou refus et avoir un effet sur la création du compte ou la publication d’une photo. Le stockage central d’une image faciale crée aussi des risques d’usurpation et de vie privée en cas de défaillance de sécurité. MapLov limite les accès et offre un mécanisme de contestation auprès du soutien, mais ne peut garantir une exactitude parfaite ni l’absence totale de risque.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        'Retention and deletion',
        'Conservation et suppression',
      ),
      body: _LegalCopy(
        'The accepted reference selfie and comparison records are retained while the account remains active. An account-deletion request hides the profile and schedules permanent deletion after 30 days, subject to a narrowly applicable legal hold. Failed candidate uploads and duplicate-registration uploads are removed after processing. Provider copies or logs, if any, follow the provider contract and configured retention or opt-out settings.',
        'Le selfie de référence accepté et les résultats de comparaison sont conservés tant que le compte demeure actif. Une demande de suppression masque le profil et planifie l’effacement définitif après 30 jours, sous réserve d’une obligation juridique limitée. Les téléversements candidats refusés et les selfies d’inscriptions en double sont supprimés après le traitement. Les copies ou journaux éventuels du fournisseur suivent son contrat et les paramètres configurés de conservation ou d’exclusion.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy(
        'Consent, withdrawal and review',
        'Consentement, retrait et révision',
      ),
      body: _LegalCopy(
        'Capture begins only after you actively select “I understand and agree.” Declining leaves the selfie uncaptured. Under the current product design, automated selfie enrollment is required to complete the normal profile-creation path; this design requires Canadian and Québec legal review and a non-biometric alternative where applicable. You may withdraw consent, ask for deletion or challenge a decision by contacting privacy@maplov.ca. Withdrawal can prevent continued use of features that require the reference and does not invalidate processing completed before withdrawal.',
        'La capture commence seulement après que vous avez choisi activement « Je comprends et j’accepte ». Un refus laisse le selfie non capturé. Dans la conception actuelle, l’inscription automatisée du selfie est nécessaire pour terminer le parcours normal de création du profil; cette conception exige une révision juridique canadienne et québécoise ainsi qu’une solution non biométrique lorsqu’elle est requise. Vous pouvez retirer votre consentement, demander la suppression ou contester une décision en écrivant à privacy@maplov.ca. Le retrait peut empêcher l’utilisation continue des fonctions qui ont besoin de la référence et n’invalide pas les traitements effectués avant le retrait.',
      ),
    ),
  ],
);

const _communityDocument = _LegalDocument(
  key: 'community_guidelines',
  version: '2026-07-16',
  title: _LegalCopy('Community Guidelines', 'Règles de la communauté'),
  effectiveDate: _LegalCopy(
    'Effective date: July 16, 2026',
    'Date d’entrée en vigueur : 16 juillet 2026',
  ),
  contact: _LegalCopy(
    'Safety reports: use the in-app controls or support@maplov.ca',
    'Signalements de sécurité : utilisez les contrôles dans l’application ou support@maplov.ca',
  ),
  sections: [
    _LegalSection(
      title: _LegalCopy('Respect and consent', 'Respect et consentement'),
      body: _LegalCopy(
        'Treat every member with dignity. Consent must be voluntary, informed, specific and reversible. Stop contact immediately when asked.',
        'Traitez chaque membre avec dignité. Le consentement doit être libre, éclairé, précis et révocable. Cessez immédiatement tout contact lorsqu’on vous le demande.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('Prohibited content', 'Contenu interdit'),
      body: _LegalCopy(
        'No child sexual abuse or exploitation, grooming, trafficking, threats, hate, non-consensual intimate imagery, illegal sexual services, fraud, impersonation or targeted harassment.',
        'Aucune exploitation sexuelle d’enfants, aucun conditionnement, traite, menace, contenu haineux, image intime non consensuelle, service sexuel illégal, fraude, usurpation d’identité ou harcèlement ciblé.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('Reporting', 'Signalement'),
      body: _LegalCopy(
        'Use the separate Report and Block controls available on profiles, posts, photos and conversations. Reports are confidential and reviewed by authorized moderation personnel.',
        'Utilisez les contrôles distincts Signaler et Bloquer offerts dans les profils, publications, photos et conversations. Les signalements sont confidentiels et examinés par le personnel de modération autorisé.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('Enforcement', 'Application'),
      body: _LegalCopy(
        'Responses can include content removal, warnings, feature restrictions, suspension, account closure and reports to appropriate authorities where required.',
        'Les mesures peuvent comprendre le retrait de contenu, un avertissement, la restriction de fonctions, la suspension, la fermeture du compte et un signalement aux autorités compétentes lorsque cela est requis.',
      ),
    ),
  ],
);

const _adultEligibilityDocument = _LegalDocument(
  key: 'adult_eligibility',
  version: '2026-07-16',
  title: _LegalCopy(
    'Adult Eligibility and Child Safety Standards',
    'Admissibilité des adultes et normes de sécurité des enfants',
  ),
  effectiveDate: _LegalCopy(
    'Effective date: July 16, 2026',
    'Date d’entrée en vigueur : 16 juillet 2026',
  ),
  contact: _LegalCopy(
    'Child-safety reports: child-safety@maplov.ca',
    'Signalements concernant la sécurité des enfants : child-safety@maplov.ca',
  ),
  sections: [
    _LegalSection(
      title: _LegalCopy('Adults only', 'Réservé aux adultes'),
      body: _LegalCopy(
        'People under 18 are prohibited from creating or using a MapLov account. Suspected underage accounts must be reported immediately.',
        'Il est interdit aux personnes de moins de 18 ans de créer ou d’utiliser un compte MapLov. Tout compte soupçonné d’appartenir à un mineur doit être signalé immédiatement.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('Zero tolerance', 'Tolérance zéro'),
      body: _LegalCopy(
        'MapLov prohibits child sexual abuse and exploitation, sexualized depictions of minors, grooming, sextortion, trafficking and any attempt to endanger a minor.',
        'MapLov interdit l’exploitation sexuelle d’enfants, les représentations sexualisées de mineurs, le conditionnement, la sextorsion, la traite et toute tentative de mettre un mineur en danger.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('Response process', 'Processus d’intervention'),
      body: _LegalCopy(
        'Reported content is restricted and reviewed. Confirmed illegal material is preserved only as legally required, removed from access and reported to the appropriate authority.',
        'Le contenu signalé est restreint et examiné. Le matériel illégal confirmé est conservé uniquement dans la mesure exigée par la loi, retiré de l’accès et signalé à l’autorité compétente.',
      ),
    ),
  ],
);

const _contentSafetyDocument = _LegalDocument(
  key: 'content_and_safety_rules',
  version: '2026-07-16',
  title: _LegalCopy(
    'Content, Photo, Reporting and Safety Rules',
    'Règles relatives au contenu, aux photos, aux signalements et à la sécurité',
  ),
  effectiveDate: _LegalCopy(
    'Effective date: July 16, 2026',
    'Date d’entrée en vigueur : 16 juillet 2026',
  ),
  contact: _LegalCopy(
    'Safety questions: support@maplov.ca',
    'Questions de sécurité : support@maplov.ca',
  ),
  sections: [
    _LegalSection(
      title: _LegalCopy('Authentic photos', 'Photos authentiques'),
      body: _LegalCopy(
        'Upload only photos you have the right to use. Profile photos must represent the account holder and must not mislead, impersonate or expose another person without consent.',
        'Téléversez uniquement des photos que vous avez le droit d’utiliser. Les photos de profil doivent représenter le titulaire du compte et ne doivent pas tromper, usurper une identité ni exposer une autre personne sans consentement.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('Private content', 'Contenu privé'),
      body: _LegalCopy(
        'Secret Garden access is explicit, time-limited and revocable. Private access never authorizes copying, threatening to share or distributing intimate content.',
        'L’accès au Jardin secret est explicite, limité dans le temps et révocable. Un accès privé n’autorise jamais la copie, la menace de partage ni la diffusion de contenu intime.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('Reports and blocks', 'Signalements et blocages'),
      body: _LegalCopy(
        'Block to stop direct interaction and report conduct or content that may violate the rules. Do not submit knowingly false reports or use reporting as retaliation.',
        'Bloquez une personne pour interrompre l’interaction directe et signalez les comportements ou contenus susceptibles d’enfreindre les règles. Ne faites pas sciemment de faux signalement et n’utilisez pas le signalement comme représailles.',
      ),
    ),
  ],
);

const _locationDocument = _LegalDocument(
  key: 'location_notice',
  version: '2026-07-16',
  title: _LegalCopy('Location Notice', 'Avis sur la localisation'),
  effectiveDate: _LegalCopy(
    'Effective date: July 16, 2026',
    'Date d’entrée en vigueur : 16 juillet 2026',
  ),
  contact: _LegalCopy(
    'Location privacy questions: privacy@maplov.ca',
    'Questions sur la confidentialité de la localisation : privacy@maplov.ca',
  ),
  sections: [
    _LegalSection(
      title: _LegalCopy(
        'User-initiated access',
        'Accès déclenché par l’utilisateur',
      ),
      body: _LegalCopy(
        'MapLov requests foreground location during registration to initialize residence and discovery, and again when you open Nearby or explicitly refresh location. It does not request background location.',
        'MapLov demande la localisation au premier plan pendant l’inscription afin d’initialiser la résidence et la découverte, puis lorsque vous ouvrez À proximité ou actualisez explicitement la localisation. MapLov ne demande pas la localisation en arrière-plan.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('Purpose and display', 'Finalité et affichage'),
      body: _LegalCopy(
        'Coordinates support distance and nearby discovery. Other members see only approximate distance when that preference is enabled, never raw coordinates.',
        'Les coordonnées servent à calculer la distance et la découverte à proximité. Les autres membres voient uniquement une distance approximative lorsque ce réglage est activé, jamais les coordonnées brutes.',
      ),
    ),
    _LegalSection(
      title: _LegalCopy('Control', 'Contrôle'),
      body: _LegalCopy(
        'You may deny or revoke permission in device settings. Features requiring current location may then be unavailable, while other profile and search controls can remain available.',
        'Vous pouvez refuser ou révoquer l’autorisation dans les réglages de l’appareil. Les fonctions exigeant la localisation actuelle peuvent alors devenir indisponibles, tandis que les autres contrôles de profil et de recherche peuvent demeurer accessibles.',
      ),
    ),
  ],
);
