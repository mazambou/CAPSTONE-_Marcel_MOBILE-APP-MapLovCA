import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final instance = LocaleService._();
  static const _key = 'maplov_locale';

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  Future<void> load({Locale? deviceLocale}) async {
    final code = (await SharedPreferences.getInstance()).getString(_key);
    _locale = resolveInitialLocale(
      savedLanguageCode: code,
      deviceLocale:
          deviceLocale ?? WidgetsBinding.instance.platformDispatcher.locale,
    );
    notifyListeners();
  }

  @visibleForTesting
  static Locale resolveInitialLocale({
    required String? savedLanguageCode,
    required Locale deviceLocale,
  }) {
    if (savedLanguageCode == 'fr' || savedLanguageCode == 'en') {
      return Locale(savedLanguageCode!);
    }
    return deviceLocale.languageCode == 'fr'
        ? const Locale('fr')
        : const Locale('en');
  }

  Future<void> setLanguage(String code) async {
    if (code != 'en' && code != 'fr') return;
    _locale = Locale(code);
    await (await SharedPreferences.getInstance()).setString(_key, code);
    notifyListeners();
  }
}

class MapLovLocalizations {
  const MapLovLocalizations(this.locale);
  final Locale locale;

  static MapLovLocalizations of(BuildContext context) =>
      Localizations.of<MapLovLocalizations>(context, MapLovLocalizations) ??
      const MapLovLocalizations(Locale('en'));

  static const delegate = _MapLovLocalizationsDelegate();

  static const _values = <String, Map<String, String>>{
    'en': {
      'discover': 'Discover',
      'messages': 'Messages',
      'map': 'Map',
      'matches': 'Matches',
      'likes': 'Likes',
      'profile': 'Profile',
      'filters': 'Filters',
      'notifications': 'Notifications',
      'language': 'Language',
      'apply_language': 'Apply language',
    },
    'fr': {
      'discover': 'Découvrir',
      'messages': 'Messages',
      'map': 'Carte',
      'matches': 'Matchs',
      'likes': 'J’aime',
      'profile': 'Profil',
      'filters': 'Filtres',
      'notifications': 'Notifications',
      'language': 'Langue',
      'apply_language': 'Appliquer la langue',
    },
  };

  String text(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;

  static const _french = <String, String>{
    'Discover': 'Découvrir',
    'Most liked photos': 'Photos les plus aimées',
    'Location access needed': 'Accès à la localisation requis',
    'Open settings': 'Ouvrir les paramètres',
    'Try again': 'Réessayer',
    'Turn on device location to discover members near you.':
        'Activez la localisation de l’appareil pour découvrir les membres à proximité.',
    'Location access is blocked. Open MapLov settings and allow location while using the app.':
        'L’accès à la localisation est bloqué. Ouvrez les paramètres de MapLov et autorisez la localisation pendant l’utilisation.',
    'MapLov needs location access to show nearby members. Your exact position is never displayed.':
        'MapLov a besoin de la localisation pour afficher les membres à proximité. Votre position exacte n’est jamais affichée.',
    'Messages': 'Messages',
    'Online': 'En ligne',
    'Offline': 'Hors ligne',
    'Today': 'Aujourd’hui',
    'Type a message...': 'Écrire un message…',
    'Compatibility': 'Compatibilité',
    'You have a strong connection!': 'Vous avez une forte connexion !',
    'Messages are private. Only chat participants can access this conversation.':
        'Les messages sont privés. Seuls les participants peuvent accéder à cette conversation.',
    'Your matches': 'Vos matchs',
    'My profile': 'Mon profil',
    'Settings': 'Paramètres',
    'Filters': 'Filtres',
    'Notifications': 'Notifications',
    'Edit profile': 'Modifier le profil',
    'Manage photos': 'Gérer les photos',
    'Photo under moderation': 'Photo en cours de modération',
    'Report': 'Signaler',
    'Report this photo?': 'Signaler cette photo ?',
    'Photo reported for review.': 'Photo signalée pour vérification.',
    'You have already reported this photo.':
        'Vous avez déjà signalé cette photo.',
    'Delete this photo?': 'Supprimer cette photo ?',
    'Delete permanently': 'Supprimer définitivement',
    'Photos awaiting review': 'Photos en attente de vérification',
    'Approve photo': 'Approuver la photo',
    'Dating preferences': 'Préférences de rencontre',
    'Friends': 'Amis',
    'Friend requests': 'Demandes d’amitié',
    'Friends posts': 'Publications des amis',
    'Create post': 'Créer une publication',
    'Post': 'Publication',
    'Secret Garden': 'Jardin Secret',
    'Manage Secret Garden': 'Gérer le Jardin Secret',
    'Garden access requests': 'Demandes d’accès au Jardin',
    'Upgrade to Premium': 'Passer à Premium',
    'Manage subscription': 'Gérer l’abonnement',
    'Privacy': 'Confidentialité',
    'Security': 'Sécurité',
    'Notification settings': 'Paramètres de notification',
    'Help Center': 'Centre d’aide',
    'Legal & consent': 'Juridique et consentement',
    'Terms of Use': 'Conditions d’utilisation',
    'Privacy Policy': 'Politique de confidentialité',
    'Community Guidelines': 'Règles de la communauté',
    'Child Safety Standards': 'Normes de sécurité des enfants',
    'Data and cookie preferences': 'Préférences de données et témoins',
    'Location consent': 'Consentement à la localisation',
    'Request a copy of my data': 'Demander une copie de mes données',
    'Account and data deletion': 'Suppression du compte et des données',
    'Your MapLov data': 'Vos données MapLov',
    'Copy data': 'Copier les données',
    'Data copied securely.': 'Données copiées de façon sécurisée.',
    'Popular topics': 'Sujets populaires',
    'Search for help': 'Rechercher de l’aide',
    'No help article found': 'Aucun article d’aide trouvé',
    'Contact MapLov Support': 'Contacter le soutien MapLov',
    'Contact support': 'Contacter le soutien',
    'Close': 'Fermer',
    'Blocked users': 'Utilisateurs bloqués',
    'Moderation dashboard': 'Tableau de modération',
    'User reports': 'Signalements',
    'User management': 'Gestion des utilisateurs',
    'Moderator audit log': 'Journal d’audit',
    'Save': 'Enregistrer',
    'Cancel': 'Annuler',
    'Delete': 'Supprimer',
    'Done': 'Terminé',
    'Continue': 'Continuer',
    'Message': 'Message',
    'Send Message': 'Envoyer un message',
    'Keep Swiping': 'Continuer à découvrir',
    'Add photo': 'Ajouter une photo',
    'Take a photo': 'Prendre une photo',
    'Choose from gallery': 'Choisir dans la galerie',
    'Create private album': 'Créer un album privé',
    'Creating album…': 'Création de l’album…',
    'Unable to load private albums': 'Impossible de charger les albums privés',
    'No notifications yet.': 'Aucune notification.',
    'No comments yet.': 'Aucun commentaire.',
    'No mutual matches yet': 'Aucun match mutuel pour le moment',
    'Loading…': 'Chargement…',
    'Profile visitors': 'Visiteurs du profil',
    'Profile statistics': 'Statistiques du profil',
    'Home': 'Accueil',
    'Log In': 'Se connecter',
    'Sign Up': 'S’inscrire',
    'Email': 'Courriel',
    'Password': 'Mot de passe',
    'Forgot password?': 'Mot de passe oublié ?',
    'Update password': 'Mettre à jour le mot de passe',
    'Delete account': 'Supprimer le compte',
    'Log Out': 'Se déconnecter',
    'Photo Display': 'Affichage des photos',
    'Subscription': 'Abonnement',
    'Legal & Consent': 'Juridique et consentement',
    'Block user': 'Bloquer l’utilisateur',
    'Report user': 'Signaler l’utilisateur',
    'Suspected minor': 'Mineur présumé',
    'Child sexual exploitation': 'Exploitation sexuelle d’un enfant',
    'Non-consensual intimate content': 'Contenu intime non consensuel',
    'Threat or immediate danger': 'Menace ou danger immédiat',
    'Block this member after reporting':
        'Bloquer ce membre après le signalement',
    'Immediate danger': 'Danger immédiat',
    'I agree to respect the Terms of Use and Community Guidelines.':
        'J’accepte de respecter les conditions d’utilisation et les règles de la communauté.',
    'Retry': 'Réessayer',
    'Read': 'Lu',
    'Message deleted': 'Message supprimé',
    'Delete message?': 'Supprimer le message ?',
    'Delete for me': 'Supprimer pour moi',
    'Delete for everyone': 'Supprimer pour tout le monde',
    'Clear chat': 'Effacer la conversation',
    'Clear chat?': 'Effacer la conversation ?',
    'Clear for me': 'Effacer pour moi',
    'Clear for everyone': 'Effacer pour tout le monde',
    'Chat cleared.': 'Conversation effacée.',
    'Photo display': 'Affichage des photos',
    'Profile details': 'Détails du profil',
    'Social interactions': 'Interactions sociales',
    'Voice message': 'Message vocal',
    'Text message could not be sent.': 'Le message n’a pas pu être envoyé.',
    'Photo could not be sent.': 'La photo n’a pas pu être envoyée.',
    'Voice message could not be sent.':
        'Le message vocal n’a pas pu être envoyé.',
    'Mark all as read': 'Tout marquer comme lu',
    'Mark as read': 'Marquer comme lu',
    'Archive': 'Archiver',
    'All': 'Tout',
    'Garden': 'Jardin',
    'Posts': 'Publications',
    'Save preferences': 'Enregistrer les préférences',
    'Who you want to meet': 'Qui souhaitez-vous rencontrer',
    'Search location': 'Zone de recherche',
    'Compatibility priorities': 'Priorités de compatibilité',
    'Gender': 'Genre',
    'Everyone': 'Tout le monde',
    'Women': 'Femmes',
    'Men': 'Hommes',
    'Non-binary': 'Non binaire',
    'Nearby': 'À proximité',
    'Country': 'Pays',
    'Specific': 'Spécifique',
    'World': 'Monde',
    'Preferred country': 'Pays préféré',
    'Relationship goal': 'Objectif relationnel',
    'Languages': 'Langues',
    'Personality': 'Personnalité',
    'Required gender criterion': 'Critère de genre obligatoire',
    'Hide profiles that do not match this choice.':
        'Masquer les profils qui ne correspondent pas à ce choix.',
    'Required location criterion': 'Critère de localisation obligatoire',
    'Otherwise, location remains a preference.':
        'Sinon, la localisation reste une préférence.',
    'Required relationship goal': 'Objectif relationnel obligatoire',
    'Required language criterion': 'Critère de langue obligatoire',
    'Standard Filter': 'Filtre standard',
    'Advanced Filter': 'Filtre avancé',
    'Show Results': 'Afficher les résultats',
    'Religion': 'Religion',
    'Body type': 'Morphologie',
    'Verified profiles only': 'Profils vérifiés uniquement',
    'Active today': 'Actif aujourd’hui',
    'Add a comment…': 'Ajouter un commentaire…',
    'Edit comment': 'Modifier le commentaire',
    'Delete comment': 'Supprimer le commentaire',
    'Delete post': 'Supprimer la publication',
    'Comments': 'Commentaires',
    'Comments enabled': 'Commentaires activés',
    'Select photos': 'Choisir des photos',
    'Publish': 'Publier',
    'Private albums': 'Albums privés',
    'Request access': 'Demander l’accès',
    'Pending': 'En attente',
    'Access request sent.': 'Demande d’accès envoyée.',
    'No private album is available.': 'Aucun album privé disponible.',
    'Manage my Secret Garden': 'Gérer mon Jardin Secret',
    'Private and time-limited access': 'Accès privé et temporaire',
    'No photos in this album.': 'Aucune photo dans cet album.',
    'This access has expired or is no longer available.':
        'Cet accès a expiré ou n’est plus disponible.',
    'Private content cannot be shared or downloaded.':
        'Le contenu privé ne peut être ni partagé ni téléchargé.',
    'Access history': 'Historique des accès',
    'Active access': 'Accès actif',
    'Revoke': 'Révoquer',
    'Rename': 'Renommer',
    'Create album': 'Créer un album',
    'Main': 'Principale',
    'Set main': 'Définir comme principale',
    'Move earlier': 'Déplacer avant',
    'Move later': 'Déplacer après',
    'Subscription status': 'État de l’abonnement',
    'Current plan': 'Forfait actuel',
    'Renewal date': 'Date de renouvellement',
    'Subscription history': 'Historique des abonnements',
    'Invisible mode': 'Mode invisible',
    'Profile views': 'Vues du profil',
    'Search users': 'Rechercher des utilisateurs',
    'Verify profile': 'Vérifier le profil',
    'Verify photo': 'Vérifier la photo',
    'Remove content': 'Supprimer le contenu',
    'Resolution notes': 'Notes de résolution',
    'Resolve report': 'Résoudre le signalement',
    'No reports found.': 'Aucun signalement trouvé.',
    'No users found.': 'Aucun utilisateur trouvé.',
    'Access denied': 'Accès refusé',
    'This page is restricted to the moderation team.':
        'Cette page est réservée à l’équipe de modération.',
    'Skip': 'Passer',
    'Next': 'Suivant',
    'Get Started': 'Commencer',
    'Find Love Near You': 'Trouvez l’amour près de vous',
    'Discover meaningful connections with people near you.':
        'Découvrez des liens sincères avec des personnes près de vous.',
    'Smart Matching': 'Compatibilité intelligente',
    'Meet compatible people chosen around what matters to you.':
        'Rencontrez des personnes compatibles selon ce qui compte pour vous.',
    'Chat & Connect': 'Discutez et créez des liens',
    'Start a conversation and turn a match into something real.':
        'Commencez une conversation et transformez un match en histoire réelle.',
    'Safe & Verified Community': 'Communauté sécurisée et vérifiée',
    'Connect confidently in a community built around trust.':
        'Échangez en confiance dans une communauté fondée sur la fiabilité.',
    'Choose the language used by MapLov.':
        'Choisissez la langue utilisée par MapLov.',
    'English': 'Anglais',
    'Français': 'Français',
    'Choose multiple photos': 'Choisir plusieurs photos',
    'Select all the photos to upload at once':
        'Sélectionnez toutes les photos à téléverser en une seule fois',
    'Purchase status': 'État de l’achat',
    'Waiting for the store confirmation…':
        'En attente de la confirmation de la boutique…',
    '/ month': '/ mois',
    'Explore Premium plans': 'Découvrir les forfaits Premium',
    'Restore purchases': 'Restaurer les achats',
    'Restore a subscription purchased on this store account.':
        'Restaurer un abonnement acheté avec ce compte de boutique.',
    'Restore request sent to the store.':
        'Demande de restauration envoyée à la boutique.',
    'Billing history': 'Historique de facturation',
    'No store transactions yet.':
        'Aucune transaction de boutique pour le moment.',
    'No conversations yet': 'Aucune conversation pour le moment',
    'Open a profile and tap Message to start.':
        'Ouvrez un profil et appuyez sur Message pour commencer.',
    'Documents': 'Documents',
    'Choose a photo': 'Choisir une photo',
    'Choose a document': 'Choisir un document',
    'Video call': 'Appel vidéo',
    'Voice call': 'Appel vocal',
    'Close emojis': 'Fermer les émojis',
    'Emoji': 'Émoji',
    'Remove friend': 'Supprimer l’ami',
    'Search friends': 'Rechercher des amis',
    'Unable to load friends': 'Impossible de charger les amis',
    'Your friends have not shared anything yet.':
        'Vos amis n’ont encore rien partagé.',
    'Friends only': 'Amis seulement',
    'Allow comments': 'Autoriser les commentaires',
    'Share something with your friends...':
        'Partagez quelque chose avec vos amis…',
    'Add text or a photo first.': 'Ajoutez d’abord du texte ou une photo.',
    'Write a respectful comment…': 'Écrire un commentaire respectueux…',
    'Add a respectful comment...': 'Ajouter un commentaire respectueux…',
    'Comment': 'Commenter',
    'Comment added.': 'Commentaire ajouté.',
    'Delete publication': 'Supprimer la publication',
    'Show my profile in Discover': 'Afficher mon profil dans Découvrir',
    'Show approximate distance': 'Afficher la distance approximative',
    'Your exact location is never displayed.':
        'Votre position exacte n’est jamais affichée.',
    'Show online status': 'Afficher le statut en ligne',
    'Post visibility': 'Visibilité des publications',
    'Secret Garden access': 'Accès au Jardin Secret',
    'Invisible navigation requires Premium VIP.':
        'La navigation invisible nécessite Premium VIP.',
    'VIP members can stay out of Discover. People can see your profile after you like them or send them a message.':
        'Les membres VIP peuvent rester invisibles dans Découvrir. Les personnes peuvent voir votre profil après que vous les avez aimées ou leur avez envoyé un message.',
    'Email verified': 'Courriel vérifié',
    'Change password': 'Modifier le mot de passe',
    'Active sessions': 'Sessions actives',
    '1 signed-in device': '1 appareil connecté',
    'Recent login activity': 'Activité de connexion récente',
    'Other sessions were signed out.':
        'Les autres sessions ont été déconnectées.',
    'Sign out of all other devices': 'Déconnecter tous les autres appareils',
    'No visitors yet.': 'Aucun visiteur pour le moment.',
    'No interests added yet.': 'Aucun intérêt ajouté.',
    'Add or remove profile photos': 'Ajouter ou supprimer des photos de profil',
    'New compatible profiles': 'Nouveaux profils compatibles',
    '3 suggestions were added today':
        '3 suggestions ont été ajoutées aujourd’hui',
    'Friend request accepted': 'Demande d’amitié acceptée',
    'Sophie is now your friend': 'Sophie est maintenant votre amie',
    'No profiles found': 'Aucun profil trouvé',
    'Try another tab or adjust your filters.':
        'Essayez un autre onglet ou modifiez vos filtres.',
    'NEW': 'NOUVEAU',
    'New ✨': 'Nouveau ✨',
    '● Online': '● En ligne',
    'Activity status': 'Statut d’activité',
    'Automatic': 'Automatique',
    'Updated automatically when you use MapLov':
        'Mis à jour automatiquement lorsque vous utilisez MapLov',
    'Read only': 'Lecture seule',
    'Country of origin is chosen once during registration.':
        'Le pays d’origine est choisi une seule fois lors de l’inscription.',
    'City of origin is chosen once during registration.':
        'La ville d’origine est choisie une seule fois lors de l’inscription.',
    'Change and re-verify your phone number to update it.':
        'Modifiez et vérifiez de nouveau votre numéro de téléphone pour le mettre à jour.',
    'Distance is calculated from your private location. Age is calculated from your date of birth. Neither can be edited manually.':
        'La distance est calculée à partir de votre position privée. L’âge est calculé à partir de votre date de naissance. Aucun des deux ne peut être modifié manuellement.',
    'Complete the information that other members can use in Quick, Standard, and Advanced Filters.':
        'Complétez les renseignements que les autres membres peuvent utiliser dans les filtres rapide, standard et avancé.',
    'First name and city are required.':
        'Le prénom et la ville sont obligatoires.',
    'Select at least one language.': 'Sélectionnez au moins une langue.',
    'Photo verified': 'Photo vérifiée',
    'Quick Filter': 'Filtre rapide',
    'Reset': 'Réinitialiser',
    'Interests': 'Intérêts',
    'Age range': 'Tranche d’âge',
    'Want children': 'Souhait d’avoir des enfants',
    'Relationship status': 'Situation amoureuse',
    'Education level': 'Niveau d’études',
    'Basic': 'Essentiel',
    'Refine your main preferences': 'Affinez vos préférences principales',
    'Family & Relationship': 'Famille et relation',
    'Your life situation and relationship goals':
        'Votre situation personnelle et vos objectifs relationnels',
    'Appearance': 'Apparence',
    'Physical preferences': 'Préférences physiques',
    'Eye color': 'Couleur des yeux',
    'Hair color': 'Couleur des cheveux',
    'Education & Career': 'Études et carrière',
    'Education and professional background':
        'Formation et parcours professionnel',
    'Profession': 'Profession',
    'Income level': 'Niveau de revenu',
    'Verified & Activity': 'Vérification et activité',
    'Trust and activity': 'Confiance et activité',
    'Verified profile': 'Profil vérifié',
    'Advanced filters require Premium Plus.':
        'Les filtres avancés nécessitent Premium Plus.',
    'Advanced filters help you find better matches.':
        'Les filtres avancés vous aident à trouver de meilleures compatibilités.',
    'Some options are available with MapLov Premium.':
        'Certaines options sont offertes avec MapLov Premium.',
    'Distance': 'Distance',
    'Search radius': 'Rayon de recherche',
    'International search': 'Recherche internationale',
    'Choose how far MapLov should search for profiles.':
        'Choisissez jusqu’à quelle distance MapLov doit rechercher des profils.',
    'Choose a country and optionally a city, without a distance limit.':
        'Choisissez un pays et, facultativement, une ville, sans limite de distance.',
    'Your profile country': 'Pays de votre profil',
    'Select Any city to search everywhere in Canada.':
        'Sélectionnez Toute ville pour rechercher partout au Canada.',
    'Near me': 'Près de moi',
    'Location unavailable': 'Localisation indisponible',
    'Only approximate distance is shown. Exact locations stay private.':
        'Seule la distance approximative est affichée. Les positions exactes restent privées.',
    'No new likes yet': 'Aucun nouveau J’aime pour le moment',
    'New people who like your profile will appear here.':
        'Les nouvelles personnes qui aiment votre profil apparaîtront ici.',
    'See who likes you': 'Voir qui vous aime',
    'View plans': 'Voir les forfaits',
    'Upgrade to reveal the people who already liked your profile.':
        'Passez à Premium pour découvrir les personnes qui ont déjà aimé votre profil.',
    'People who liked your profile appear here. Open a photo or profile before deciding whether to like them back.':
        'Les personnes qui ont aimé votre profil apparaissent ici. Ouvrez une photo ou un profil avant de décider de les aimer en retour.',
    'Keep discovering people you like.':
        'Continuez à découvrir des personnes qui vous plaisent.',
    'Compatibility details': 'Détails de compatibilité',
    'Highly compatible': 'Très compatible',
    'Increase your chances': 'Augmentez vos chances',
    'Complete your profile to get more matches!':
        'Complétez votre profil pour obtenir plus de matchs !',
    'Compatibility helps you discover people. Messaging remains available to everyone.':
        'La compatibilité vous aide à découvrir des personnes. La messagerie reste accessible à tous.',
    'Report a problem': 'Signaler un problème',
    'Accept': 'Accepter',
    'Accept request': 'Accepter la demande',
    'Decline request': 'Refuser la demande',
    'Wants to connect': 'Souhaite entrer en contact',
    'Retry friend requests': 'Réessayer de charger les demandes',
    'You can send a new friend request later if you change your mind.':
        'Vous pourrez envoyer une nouvelle demande d’amitié plus tard si vous changez d’avis.',
    'Would you like to accept this request?':
        'Souhaitez-vous accepter cette demande ?',
    'Visible to everyone': 'Visible par tout le monde',
    'Permission required': 'Autorisation requise',
    'Report profile': 'Signaler le profil',
    'Block profile': 'Bloquer le profil',
    'This photo cannot be reported.': 'Cette photo ne peut pas être signalée.',
    'This photo is not available.': 'Cette photo n’est pas disponible.',
    'The photo will be reviewed confidentially by the MapLov moderation team.':
        'La photo sera examinée confidentiellement par l’équipe de modération MapLov.',
    'Super Like sent.': 'Super Like envoyé.',
    'Looking for': 'Recherche',
    'About me': 'À propos de moi',
    'Age': 'Âge',
    'Public Photos': 'Photos publiques',
    'Create your account': 'Créer votre compte',
    'Tell us a little about yourself.': 'Parlez-nous un peu de vous.',
    'This choice is permanent after account creation.':
        'Ce choix est définitif après la création du compte.',
    'Change the phone country code to update residence.':
        'Modifiez l’indicatif téléphonique pour mettre à jour le pays de résidence.',
    'Code': 'Code',
    'Email or Phone': 'Courriel ou téléphone',
    'Welcome Back': 'Bon retour',
    'Sign in to continue your journey':
        'Connectez-vous pour poursuivre votre parcours',
    'Remember me': 'Se souvenir de moi',
    'or': 'ou',
    'Back to login': 'Retour à la connexion',
    'Check your inbox': 'Vérifiez votre boîte de réception',
    'Verify your email': 'Vérifiez votre courriel',
    'Resend verification email': 'Renvoyer le courriel de vérification',
    'Create new password': 'Créer un nouveau mot de passe',
    'Choose a strong password with at least 8 characters, one number and one symbol.':
        'Choisissez un mot de passe fort contenant au moins 8 caractères, un chiffre et un symbole.',
    'Your password has been updated.': 'Votre mot de passe a été mis à jour.',
    'Age confirmation': 'Confirmation de l’âge',
    'MapLov is for adults only': 'MapLov est réservé aux adultes',
    'Date of birth': 'Date de naissance',
    'Previous year': 'Année précédente',
    'Next year': 'Année suivante',
    'Confirm': 'Confirmer',
    'You must be at least 18 years old to create an account and use MapLov Canada.':
        'Vous devez avoir au moins 18 ans pour créer un compte et utiliser MapLov Canada.',
    'Verify your phone number': 'Vérifiez votre numéro de téléphone',
    'Phone number being verified':
        'Numéro de téléphone en cours de vérification',
    'Phone verification protects accounts and helps keep MapLov authentic.':
        'La vérification téléphonique protège les comptes et contribue à préserver l’authenticité de MapLov.',
    'Confirm this phone number': 'Confirmer ce numéro de téléphone',
    'Temporary testing option: the phone will remain unverified.':
        'Option de test temporaire : le téléphone restera non vérifié.',
    'Back to dating preferences': 'Retour aux préférences de rencontre',
    'Create your profile': 'Créer votre profil',
    'Add profile photo': 'Ajouter une photo de profil',
    'Your name and birth date are already saved. Confirm your current residence, then tell MapLov where you are originally from.':
        'Votre nom et votre date de naissance sont déjà enregistrés. Confirmez votre résidence actuelle, puis indiquez à MapLov d’où vous venez.',
    'Enable location for Discover': 'Activer la localisation pour Découvrir',
    'Not now': 'Pas maintenant',
    'MapLov uses your current GPS position to initialize Discover and calculate approximate distances. Your exact coordinates are never shown to other members, and background location is not used.':
        'MapLov utilise votre position GPS actuelle pour initialiser Découvrir et calculer les distances approximatives. Vos coordonnées exactes ne sont jamais affichées aux autres membres et la localisation en arrière-plan n’est pas utilisée.',
    'Tell MapLov who you would like to meet. These preferences improve your compatibility results.':
        'Indiquez à MapLov qui vous souhaitez rencontrer. Ces préférences améliorent vos résultats de compatibilité.',
    'Back to profile details': 'Retour aux détails du profil',
    'Choose how other MapLov members will see your profile photos. You can change this preference at any time.':
        'Choisissez comment les autres membres de MapLov verront vos photos de profil. Vous pouvez modifier cette préférence à tout moment.',
    'This setting controls only the presentation of your profile photos. Your privacy and visibility settings remain unchanged.':
        'Ce réglage contrôle uniquement la présentation de vos photos de profil. Vos paramètres de confidentialité et de visibilité restent inchangés.',
    'Shows your photo with your relationship goal, location, age, height and biography.':
        'Affiche votre photo avec votre objectif relationnel, votre localisation, votre âge, votre taille et votre biographie.',
    'Uses an immersive photo layout where visitors can like, comment or send a Super Like.':
        'Utilise une présentation photo immersive où les visiteurs peuvent aimer, commenter ou envoyer un Super Like.',
    'Profile photos required': 'Photos de profil requises',
    'Your first photo is your main profile photo. Photos are stored privately and served with temporary secure links.':
        'Votre première photo est votre photo de profil principale. Les photos sont stockées de manière privée et diffusées avec des liens temporaires sécurisés.',
    'Your profile must keep at least one photo.':
        'Votre profil doit conserver au moins une photo.',
    'This action cannot be undone.': 'Cette action est irréversible.',
    'Delete photo': 'Supprimer la photo',
    'Permanently delete this photo?': 'Supprimer définitivement cette photo ?',
    'My private moments': 'Mes moments privés',
    'Review waiting requests': 'Examiner les demandes en attente',
    'Access history and active access': 'Historique des accès et accès actifs',
    'No access history yet.': 'Aucun historique d’accès.',
    'Add photos': 'Ajouter des photos',
    'Delete album': 'Supprimer l’album',
    'No access request is waiting.': 'Aucune demande d’accès en attente.',
    'You decide who can view your private albums and for how long.':
        'Vous décidez qui peut voir vos albums privés et pendant combien de temps.',
    'Requested access to a private album': 'A demandé l’accès à un album privé',
    'Allow': 'Autoriser',
    'Permanent': 'Permanent',
    'Access is time-limited. The owner can revoke it at any time.':
        'L’accès est limité dans le temps. Le propriétaire peut le révoquer à tout moment.',
    'Delete private photo': 'Supprimer la photo privée',
    'Notifications marked as read.': 'Notifications marquées comme lues.',
    'Security notifications cannot be disabled.':
        'Les notifications de sécurité ne peuvent pas être désactivées.',
    'You have not blocked anyone.': 'Vous n’avez bloqué personne.',
    'Unblock': 'Débloquer',
    'Blocked people cannot find your profile, message you or interact with your content.':
        'Les personnes bloquées ne peuvent pas trouver votre profil, vous écrire ni interagir avec votre contenu.',
    'Try a shorter search or contact support.':
        'Essayez une recherche plus courte ou contactez le soutien.',
    'MVP legal documents': 'Documents juridiques du MVP',
    'Questions: privacy@maplov.ca': 'Questions : privacy@maplov.ca',
    'This report is confidential.': 'Ce signalement est confidentiel.',
    'Report submitted for review.': 'Signalement soumis pour examen.',
    'After blocking, you will no longer see each other, exchange messages, or receive notifications. You can unblock this person later in Settings.':
        'Après le blocage, vous ne pourrez plus vous voir, échanger des messages ni recevoir de notifications. Vous pourrez débloquer cette personne plus tard dans les paramètres.',
    'User blocked.': 'Utilisateur bloqué.',
    'You will no longer see each other or exchange messages.':
        'Vous ne pourrez plus vous voir ni échanger de messages.',
    'Optional comment': 'Commentaire facultatif',
    'Contact local emergency services. An in-app report is not an emergency service.':
        'Contactez les services d’urgence locaux. Un signalement dans l’application n’est pas un service d’urgence.',
    'Audit log': 'Journal d’audit',
    'Review pending safety reports':
        'Examiner les signalements de sécurité en attente',
    'Search, suspend or ban accounts':
        'Rechercher, suspendre ou bannir des comptes',
    'Review moderator actions': 'Examiner les actions des modérateurs',
    'Restricted to authorized MapLov moderators.':
        'Réservé aux modérateurs MapLov autorisés.',
    'No reports to review.': 'Aucun signalement à examiner.',
    'No moderation action has been recorded.':
        'Aucune action de modération n’a été enregistrée.',
    'No user data is available in demo mode.':
        'Aucune donnée utilisateur n’est disponible en mode démo.',
    'Activate': 'Activer',
    'Suspend': 'Suspendre',
    'Ban': 'Bannir',
    'Dismiss': 'Rejeter',
    'Review': 'Examiner',
    'Resolve': 'Résoudre',
    'Remove reported content': 'Supprimer le contenu signalé',
    'Suspend reported account': 'Suspendre le compte signalé',
    'Show password': 'Afficher le mot de passe',
    'Hide password': 'Masquer le mot de passe',
    '6-digit code': 'Code à 6 chiffres',
    'Bio': 'Biographie',
    'Curious traveler, coffee enthusiast...':
        'Voyageur curieux, amateur de café…',
    'Tell people about yourself': 'Parlez de vous aux autres membres',
    'Country of residence (from phone)':
        'Pays de résidence (selon le téléphone)',
    'City of residence': 'Ville de résidence',
    'Country of origin': 'Pays d’origine',
    'City of origin': 'Ville d’origine',
    'City in Canada': 'Ville au Canada',
    'From': 'De',
    'To': 'À',
    'Access duration': 'Durée de l’accès',
    'Album name': 'Nom de l’album',
    'Optional moderation notes': 'Notes de modération facultatives',
    'Woman': 'Femme',
    'Man': 'Homme',
    'Prefer not to say': 'Préfère ne pas répondre',
    'Long-term': 'Relation à long terme',
    'Dating': 'Rencontres',
    'Friendship': 'Amitié',
    'Networking': 'Réseautage',
    'English & French': 'Anglais et français',
    'French': 'Français',
    'Any language': 'Toutes les langues',
    'Any personality': 'Toute personnalité',
    'Calm': 'Calme',
    'Creative': 'Créatif',
    'Adventurous': 'Aventureux',
    'Intellectual': 'Intellectuel',
    'Any': 'Tous',
    'Any city': 'Toute ville',
    'Any country': 'Tout pays',
    'Other city': 'Autre ville',
    'Any profession': 'Toute profession',
    'Any income level': 'Tout niveau de revenu',
    'Current residence': 'Résidence actuelle',
    'Current country of residence': 'Pays de résidence actuel',
    'Current city of residence': 'Ville de résidence actuelle',
    'Your origin': 'Votre origine',
    'Determined by your verified phone number.':
        'Déterminé par votre numéro de téléphone vérifié.',
    'Country of origin can only be chosen once.':
        'Le pays d’origine ne peut être choisi qu’une seule fois.',
    'City of origin can only be chosen once.':
        'La ville d’origine ne peut être choisie qu’une seule fois.',
    'Continue to preferences': 'Continuer vers les préférences',
    'Saving…': 'Enregistrement…',
    'Push notifications': 'Notifications poussées',
    'In-app notifications': 'Notifications dans l’application',
    'Post likes and comments': 'J’aime et commentaires des publications',
    'Secret Garden requests': 'Demandes du Jardin Secret',
    'Compatibility suggestions': 'Suggestions de compatibilité',
    'Marketing updates': 'Actualités promotionnelles',
    'Security alerts': 'Alertes de sécurité',
    'Important events by email': 'Événements importants par courriel',
    'Quiet hours (10 PM–7 AM)': 'Période silencieuse (22 h–7 h)',
    'Access requests': 'Demandes d’accès',
    'Decline': 'Refuser',
    'Height': 'Taille',
    'Back': 'Retour',
    'Edit': 'Modifier',
    'Forgot password': 'Mot de passe oublié',
    'Manage my album': 'Gérer mon album',
    'No photos are awaiting review.':
        'Aucune photo n’est en attente de vérification.',
    'Only administrators can change account status. Every action is written to the audit log.':
        'Seuls les administrateurs peuvent modifier le statut d’un compte. Chaque action est inscrite au journal d’audit.',
    'Posts are private and visible only to accepted friends.':
        'Les publications sont privées et visibles uniquement par les amis acceptés.',
    'Resolve with notes': 'Résoudre avec des notes',
    'Secure payment  •  Cancel anytime':
        'Paiement sécurisé  •  Annulation en tout temps',
    'The file and its public database record will be removed.':
        'Le fichier et son enregistrement public dans la base de données seront supprimés.',
    'This action is permanent': 'Cette action est définitive',
    'This page is protected by the PostgreSQL admin role and RLS policies.':
        'Cette page est protégée par le rôle administrateur PostgreSQL et les politiques RLS.',
    'Unable to load your MapLov profile.':
        'Impossible de charger votre profil MapLov.',
    'Unable to load your likes': 'Impossible de charger vos J’aime',
    'Use the photo review queue above to approve or permanently remove this photo.':
        'Utilisez la file de vérification ci-dessus pour approuver ou supprimer définitivement cette photo.',
    'Your profile will immediately become unavailable. Your data will then follow the legal retention and deletion process.':
        'Votre profil deviendra immédiatement indisponible. Vos données suivront ensuite le processus légal de conservation et de suppression.',
    'Your security, our priority': 'Votre sécurité, notre priorité',
    'Moderation': 'Modération',
    'All reports': 'Tous les signalements',
    'Agreements and MapLov rules': 'Accords et règles de MapLov',
    'Add a comment': 'Ajouter un commentaire',
    'More preferences': 'Plus de préférences',
    'Origin': 'Origine',
    'Place of residence': 'Lieu de résidence',
    'Score breakdown': 'Détail du score',
    'Why you may connect': 'Pourquoi vous pourriez créer un lien',
    'Subscription actions': 'Actions liées à l’abonnement',
    'Basic matching information': 'Informations de compatibilité essentielles',
    'Education & career': 'Études et carrière',
    'Family & relationship': 'Famille et relation',
    'Profile information': 'Informations du profil',
    'Verification & activity': 'Vérification et activité',
    'My community': 'Ma communauté',
    'Photos': 'Photos',
    'Recent activity': 'Activité récente',
    'About you': 'À propos de vous',
    'About': 'À propos',
    'Photo albums': 'Albums photo',
    'Submit report': 'Envoyer le signalement',
    'Why are you reporting this?': 'Pourquoi effectuez-vous ce signalement ?',
    'Access control': 'Contrôle des accès',
    'Private content': 'Contenu privé',
    'Account protection': 'Protection du compte',
    'Full name': 'Nom complet',
    'Phone number': 'Numéro de téléphone',
    'Confirm password': 'Confirmer le mot de passe',
    'City of residence name': 'Nom de la ville de résidence',
    'City of origin name': 'Nom de la ville d’origine',
    'Create Account': 'Créer le compte',
    'First name': 'Prénom',
    'City': 'Ville',
    'Country of residence': 'Pays de résidence',
    'Goal': 'Objectif',
    'Children preference': 'Préférence concernant les enfants',
    'Beard': 'Barbe',
    'Smoking': 'Tabagisme',
    'Long-term relationship': 'Relation à long terme',
    'Marriage': 'Mariage',
    'Spanish': 'Espagnol',
    'Arabic': 'Arabe',
    'Mandarin': 'Mandarin',
    'Other': 'Autre',
    'Travel': 'Voyage',
    'Music': 'Musique',
    'Hiking': 'Randonnée',
    'Fitness': 'Mise en forme',
    'Food': 'Gastronomie',
    'Movies': 'Films',
    'Reading': 'Lecture',
    'Photography': 'Photographie',
    'Cooking': 'Cuisine',
    'Art': 'Art',
    'Christian': 'Chrétien',
    'Muslim': 'Musulman',
    'Hindu': 'Hindou',
    'Buddhist': 'Bouddhiste',
    'Jewish': 'Juif',
    'Spiritual': 'Spirituel',
    'Atheist': 'Athée',
    'Not sure yet': 'Pas encore certain',
    'Have children': 'A des enfants',
    'Don’t want children': 'Ne souhaite pas d’enfants',
    'Single': 'Célibataire',
    'Divorced': 'Divorcé',
    'Separated': 'Séparé',
    'Widowed': 'Veuf',
    'Slim': 'Mince',
    'Athletic': 'Athlétique',
    'Average': 'Moyenne',
    'Curvy': 'Avec des courbes',
    'Full-figured': 'Ronde',
    'Brown': 'Brun',
    'Blue': 'Bleu',
    'Green': 'Vert',
    'Hazel': 'Noisette',
    'Gray': 'Gris',
    'Black': 'Noir',
    'Auburn': 'Auburn',
    'Blonde': 'Blond',
    'Red': 'Roux',
    'Not applicable': 'Sans objet',
    'No beard': 'Sans barbe',
    'Short beard': 'Barbe courte',
    'Full beard': 'Barbe complète',
    'Non-smoker': 'Non-fumeur',
    'Occasionally': 'Occasionnellement',
    'Smoker': 'Fumeur',
    'High school': 'École secondaire',
    'College': 'Collège',
    'Bachelor’s': 'Baccalauréat',
    'Master’s': 'Maîtrise',
    'Doctorate': 'Doctorat',
    'Managed by MapLov verification': 'Géré par la vérification MapLov',
    '1 hour': '1 heure',
    '5 minutes': '5 minutes',
    '10 minutes': '10 minutes',
    '20 minutes': '20 minutes',
    'Choose the plan that fits your needs\nand enjoy the full ':
        'Choisissez le forfait qui répond à vos besoins\net profitez de l’expérience ',
    ' experience.': ' au complet.',
    'New to MapLov? ': 'Nouveau sur MapLov ? ',
    ' – Connecting hearts, everywhere.': ' – Des cœurs connectés, partout.',
    'At MapLov, we protect your privacy and your data.\n':
        'Chez MapLov, nous protégeons votre vie privée et vos données.\n',
    'Effective date: July 16, 2026 • MVP draft':
        'Date d’entrée en vigueur : 16 juillet 2026 • Ébauche MVP',
    'General support: support@maplov.ca\n':
        'Soutien général : support@maplov.ca\n',
    'MapLov applies privacy-by-design controls inspired by PIPEDA, Québec Law 25 and GDPR principles. Legal compliance depends on final policies and operational practices.':
        'MapLov applique des contrôles de protection de la vie privée dès la conception, inspirés de la LPRPDE, de la Loi 25 du Québec et des principes du RGPD. La conformité juridique dépend des politiques finales et des pratiques opérationnelles.',
    'MapLov production configuration is unavailable. Please install an official build or contact support.':
        'La configuration de production MapLov est indisponible. Installez une version officielle ou contactez le soutien.',
    'These operational drafts must be reviewed by qualified Canadian privacy counsel before public launch.':
        'Ces ébauches opérationnelles doivent être examinées par un conseiller juridique canadien qualifié en protection de la vie privée avant le lancement public.',
    'Welcome to MapLov': 'Bienvenue sur MapLov',
    'Coffee': 'Café',
    'Eligibility': 'Admissibilité',
    'Acceptable use': 'Utilisation acceptable',
    'User content': 'Contenu des utilisateurs',
    'Safety and moderation': 'Sécurité et modération',
    'Subscriptions': 'Abonnements',
    'Data we process': 'Données que nous traitons',
    'Why we process it': 'Pourquoi nous les traitons',
    'Sharing': 'Partage',
    'Retention and deletion': 'Conservation et suppression',
    'Your choices': 'Vos choix',
    'Respect and consent': 'Respect et consentement',
    'Prohibited content': 'Contenu interdit',
    'Reporting': 'Signalement',
    'Enforcement': 'Application des règles',
    'Adults only': 'Adultes seulement',
    'Zero tolerance': 'Tolérance zéro',
    'Response process': 'Processus d’intervention',
    'Safety contact': 'Contact de sécurité',
    'User-initiated access': 'Accès déclenché par l’utilisateur',
    'Purpose and display': 'Objectif et affichage',
    'Control': 'Contrôle',
    'MapLov is strictly for people aged 18 or older. You must provide accurate account information and may maintain only one personal account.':
        'MapLov est strictement réservé aux personnes âgées de 18 ans ou plus. Vous devez fournir des renseignements exacts et ne pouvez conserver qu’un seul compte personnel.',
    'Do not harass, threaten, impersonate, exploit, solicit illegal services, distribute intimate content without consent, or use MapLov for scams, spam or commercial scraping.':
        'Il est interdit de harceler, menacer, usurper une identité, exploiter autrui, solliciter des services illégaux, diffuser du contenu intime sans consentement ou utiliser MapLov pour des arnaques, du pourriel ou de l’extraction commerciale de données.',
    'You remain responsible for content you upload. You grant MapLov the limited rights required to store, display and moderate that content while providing the service.':
        'Vous restez responsable du contenu que vous téléversez. Vous accordez à MapLov les droits limités nécessaires pour stocker, afficher et modérer ce contenu dans le cadre du service.',
    'MapLov may remove content, restrict features, suspend accounts or preserve evidence when necessary for safety, fraud prevention, legal compliance or enforcement of these terms.':
        'MapLov peut supprimer du contenu, restreindre des fonctionnalités, suspendre des comptes ou conserver des éléments de preuve lorsque cela est nécessaire pour la sécurité, la prévention de la fraude, la conformité légale ou l’application de ces conditions.',
    'Paid plans are billed through the applicable app store. Renewal, cancellation and refunds follow the store terms and applicable consumer law.':
        'Les forfaits payants sont facturés par la boutique d’applications concernée. Le renouvellement, l’annulation et les remboursements suivent les conditions de la boutique et les lois applicables en matière de protection du consommateur.',
    'Account identifiers, age and profile details, photos, messages, approximate or precise device location when requested, preferences, safety reports, subscription status and technical security records.':
        'Identifiants de compte, âge et détails du profil, photos, messages, position approximative ou précise de l’appareil lorsque demandée, préférences, signalements de sécurité, état de l’abonnement et registres techniques de sécurité.',
    'To create accounts, recommend compatible profiles, enable communication, prevent abuse, moderate content, provide subscriptions and satisfy legal obligations.':
        'Pour créer des comptes, recommander des profils compatibles, permettre les communications, prévenir les abus, modérer le contenu, fournir les abonnements et respecter les obligations légales.',
    'Profile content is shared according to your visibility choices. Service providers process data only to operate MapLov. We do not sell precise location or private messages.':
        'Le contenu du profil est partagé selon vos choix de visibilité. Les fournisseurs de services traitent les données uniquement pour exploiter MapLov. Nous ne vendons ni la position précise ni les messages privés.',
    'A deletion request immediately hides the account. Unless retention is legally required, associated account data is scheduled for permanent erasure after 30 days.':
        'Une demande de suppression masque immédiatement le compte. Sauf obligation légale de conservation, les données associées au compte sont supprimées définitivement après 30 jours.',
    'You can change visibility, location display and notification preferences, request an export, block members, report content and request account deletion from Settings.':
        'Vous pouvez modifier la visibilité, l’affichage de la position et les préférences de notification, demander une exportation, bloquer des membres, signaler du contenu et demander la suppression du compte dans les paramètres.',
    'Treat every member with dignity. Consent must be voluntary, informed and reversible. Stop contact immediately when asked.':
        'Traitez chaque membre avec dignité. Le consentement doit être volontaire, éclairé et révocable. Cessez immédiatement tout contact lorsqu’on vous le demande.',
    'No child sexual abuse or exploitation, grooming, trafficking, threats, hate, non-consensual intimate imagery, illegal sexual services, fraud, impersonation or targeted harassment.':
        'Aucun abus ou exploitation sexuelle d’enfants, manipulation, trafic, menace, haine, image intime non consensuelle, service sexuel illégal, fraude, usurpation d’identité ou harcèlement ciblé n’est permis.',
    'Use the separate Report and Block controls available on profiles, posts, photos and conversations. Reports are confidential and reviewed by the moderation team.':
        'Utilisez les commandes Signaler et Bloquer offertes sur les profils, publications, photos et conversations. Les signalements sont confidentiels et examinés par l’équipe de modération.',
    'Responses may include content removal, warnings, feature restrictions, suspension, banning and reports to appropriate authorities where required.':
        'Les mesures peuvent inclure la suppression de contenu, des avertissements, des restrictions de fonctionnalités, une suspension, un bannissement et un signalement aux autorités compétentes lorsque requis.',
    'People under 18 are prohibited from creating or using a MapLov account. Suspected underage accounts should be reported immediately.':
        'Les personnes de moins de 18 ans ne peuvent ni créer ni utiliser un compte MapLov. Tout compte soupçonné d’appartenir à une personne mineure doit être signalé immédiatement.',
    'MapLov prohibits child sexual abuse and exploitation, CSAM, grooming, sextortion, trafficking and any attempt to sexualize or endanger a minor.':
        'MapLov interdit les abus et l’exploitation sexuels d’enfants, le matériel d’abus pédosexuel, la manipulation, la sextorsion, le trafic et toute tentative de sexualiser ou de mettre en danger une personne mineure.',
    'Reported content is restricted and reviewed. Confirmed illegal material is preserved only as legally required, removed from access and reported to the appropriate Canadian or international authority.':
        'Le contenu signalé est restreint et examiné. Le matériel illégal confirmé est conservé uniquement selon les exigences légales, retiré de l’accès et signalé à l’autorité canadienne ou internationale compétente.',
    'Report urgent child-safety concerns in the app and contact child-safety@maplov.ca. Contact emergency services when someone is in immediate danger.':
        'Signalez dans l’application toute préoccupation urgente concernant la sécurité des enfants et écrivez à child-safety@maplov.ca. Contactez les services d’urgence lorsqu’une personne est en danger immédiat.',
    'MapLov requests foreground location while you complete registration to initialize Discover, and again when you open Nearby or explicitly refresh your location. It does not request background location.':
        'MapLov demande la localisation au premier plan pendant l’inscription afin d’initialiser Découvrir, puis lorsque vous ouvrez À proximité ou actualisez explicitement votre position. L’application ne demande pas la localisation en arrière-plan.',
    'Coordinates support distance and nearby discovery. Other members see only an approximate distance when that preference is enabled, never your raw coordinates.':
        'Les coordonnées servent au calcul des distances et à la découverte à proximité. Les autres membres voient uniquement une distance approximative lorsque cette préférence est activée, jamais vos coordonnées brutes.',
    'You may deny or revoke location permission in Android settings. Country, city and worldwide search remain available without continuous location access.':
        'Vous pouvez refuser ou révoquer l’autorisation de localisation dans les paramètres Android. Les recherches par pays, par ville et dans le monde restent accessibles sans localisation continue.',
    'Creating and verifying an account': 'Créer et vérifier un compte',
    'Why my profile is not in Discover':
        'Pourquoi mon profil n’apparaît pas dans Découvrir',
    'Profile photo requirements': 'Exigences relatives aux photos de profil',
    'Likes and matches': 'J’aime et matchs',
    'Messages and deletion': 'Messages et suppression',
    'Secret Garden safety': 'Sécurité du Jardin Secret',
    'Blocking and reporting': 'Blocage et signalement',
    'Location and privacy': 'Localisation et vie privée',
    'Premium subscriptions': 'Abonnements Premium',
    'Exporting or deleting your data': 'Exporter ou supprimer vos données',
    'Register with one email address and one phone number, confirm your email, complete your profile and verify the SMS code. MapLov permits one personal account per person.':
        'Inscrivez-vous avec une adresse courriel et un numéro de téléphone, confirmez votre courriel, complétez votre profil et vérifiez le code SMS. MapLov autorise un seul compte personnel par personne.',
    'Complete the required profile fields, add a main photo, keep Discover visibility enabled and check the other account’s age, gender and location filters. Your own profile never appears in your Discover results.':
        'Complétez les champs obligatoires du profil, ajoutez une photo principale, gardez la visibilité dans Découvrir activée et vérifiez les filtres d’âge, de genre et de localisation de l’autre compte. Votre propre profil n’apparaît jamais dans vos résultats Découvrir.',
    'A main profile photo is required before interacting. At least three profile photos are required before opening full member profiles. Use clear, recent photos that belong to you.':
        'Une photo de profil principale est requise avant toute interaction. Au moins trois photos de profil sont nécessaires pour ouvrir le profil complet d’un membre. Utilisez des photos claires, récentes et qui vous appartiennent.',
    'A compatibility score above 80% may create a match according to your preferences. Below that threshold, a reciprocal profile like or reciprocal photo like creates the match.':
        'Un score de compatibilité supérieur à 80 % peut créer un match selon vos préférences. Sous ce seuil, un J’aime réciproque sur le profil ou une photo crée le match.',
    'Tap your own message to delete it for yourself or, when eligible, for everyone. Clear Chat follows your plan: Plus removes your unread messages remotely; VIP can clear the whole conversation on both accounts.':
        'Appuyez sur votre propre message pour le supprimer pour vous ou, lorsque permis, pour tout le monde. Effacer la conversation dépend de votre forfait : Plus supprime à distance vos messages non lus; VIP peut effacer toute la conversation sur les deux comptes.',
    'Secret Garden access is explicit, time-limited and revocable. Never upload content without consent. Report a member immediately if private content is copied, threatened or shared.':
        'L’accès au Jardin Secret est explicite, limité dans le temps et révocable. Ne téléversez jamais de contenu sans consentement. Signalez immédiatement un membre si du contenu privé est copié, menacé ou partagé.',
    'Block stops discovery, messages and notifications between both accounts. Report sends a confidential safety review. For immediate danger, contact local emergency services.':
        'Le blocage interrompt la découverte, les messages et les notifications entre les deux comptes. Le signalement déclenche un examen confidentiel de sécurité. En cas de danger immédiat, contactez les services d’urgence locaux.',
    'MapLov requests foreground location during registration to initialize Discover and refreshes it when you open Nearby. It stores coordinates for discovery but displays only approximate distance. It never requests background location.':
        'MapLov demande la localisation au premier plan pendant l’inscription afin d’initialiser Découvrir et l’actualise lorsque vous ouvrez À proximité. L’application conserve les coordonnées pour la découverte, mais affiche uniquement une distance approximative. Elle ne demande jamais la localisation en arrière-plan.',
    'Manage or cancel billing through Google Play. Restoring purchases reconnects an eligible store subscription to the signed-in MapLov account.':
        'Gérez ou annulez la facturation dans Google Play. La restauration des achats reconnecte un abonnement admissible de la boutique au compte MapLov connecté.',
    'Open Settings, then Legal & consent to request a data export. Delete Account immediately hides your profile and schedules permanent account erasure after the stated retention period.':
        'Ouvrez Paramètres, puis Juridique et consentement pour demander une exportation des données. Supprimer le compte masque immédiatement votre profil et planifie la suppression définitive du compte après la période de conservation indiquée.',
    'General support: support@maplov.ca\nPrivacy: privacy@maplov.ca\nChild safety: child-safety@maplov.ca\n\nInclude your account email, device model and a short description. Never send your password or SMS code.':
        'Soutien général : support@maplov.ca\nVie privée : privacy@maplov.ca\nSécurité des enfants : child-safety@maplov.ca\n\nIndiquez l’adresse courriel de votre compte, le modèle de votre appareil et une brève description. N’envoyez jamais votre mot de passe ni votre code SMS.',
    'Incorrect email, phone number, or password.':
        'Courriel, numéro de téléphone ou mot de passe incorrect.',
    'Please verify your email before signing in.':
        'Veuillez vérifier votre courriel avant de vous connecter.',
    'An account already exists for this email.':
        'Un compte existe déjà pour ce courriel.',
    'Use at least 8 characters, including a number and a symbol.':
        'Utilisez au moins 8 caractères, dont un chiffre et un symbole.',
    'Too many attempts. Please wait a moment and try again.':
        'Trop de tentatives. Patientez un moment, puis réessayez.',
    'The verification code is invalid or has expired.':
        'Le code de vérification est invalide ou a expiré.',
    'SMS verification is currently unavailable. Check the Supabase SMS provider configuration.':
        'La vérification par SMS est actuellement indisponible. Vérifiez la configuration du fournisseur SMS Supabase.',
    'Unable to connect. Check your internet connection.':
        'Connexion impossible. Vérifiez votre connexion Internet.',
    'Authentication failed. Please try again.':
        'Échec de l’authentification. Veuillez réessayer.',
    'No phone number is attached to this account.':
        'Aucun numéro de téléphone n’est associé à ce compte.',
    'Enter your email or phone and password.':
        'Saisissez votre courriel ou votre téléphone et votre mot de passe.',
    'Enter a valid email address.': 'Saisissez une adresse courriel valide.',
    'Type DELETE exactly to confirm.':
        'Saisissez exactement DELETE pour confirmer.',
    'Passwords do not match.': 'Les mots de passe ne correspondent pas.',
    'Confirm your age and accept every required agreement first.':
        'Confirmez d’abord votre âge et acceptez tous les accords obligatoires.',
    'Enter your full name.': 'Saisissez votre nom complet.',
    'Enter a valid phone number.': 'Saisissez un numéro de téléphone valide.',
    'Enter your city.': 'Saisissez votre ville.',
    'Enter your city of origin.': 'Saisissez votre ville d’origine.',
    'Select your date of birth': 'Sélectionnez votre date de naissance',
    'Location services are disabled.':
        'Les services de localisation sont désactivés.',
    'Location permission was denied.':
        'L’autorisation de localisation a été refusée.',
    'Location permission is blocked in the device settings.':
        'L’autorisation de localisation est bloquée dans les paramètres de l’appareil.',
    'Now': 'Maintenant',
    'Add friend': 'Ajouter comme ami',
    'Allow international discovery': 'Autoriser la découverte internationale',
    'When disabled, your profile is hidden from searches that use the International option.':
        'Lorsque cette option est désactivée, votre profil est masqué des recherches utilisant l’option International.',
  };

  String translate(String value) {
    if (locale.languageCode != 'fr') return value;
    final exact = _french[value];
    if (exact != null) return exact;
    for (final entry in _french.entries) {
      if (entry.key.toLowerCase() == value.toLowerCase()) return entry.value;
    }
    final privatePhotos = RegExp(r'^(\d+) private photos$').firstMatch(value);
    if (privatePhotos != null) {
      return '${privatePhotos.group(1)} photos privées';
    }
    final photos = RegExp(r'^(\d+) photos$').firstMatch(value);
    if (photos != null) {
      final count = int.parse(photos.group(1)!);
      return '$count ${count == 1 ? 'photo' : 'photos'}';
    }
    final comments = RegExp(r'^(\d+) Comments?$').firstMatch(value);
    if (comments != null) {
      final count = int.parse(comments.group(1)!);
      return '$count ${count == 1 ? 'commentaire' : 'commentaires'}';
    }
    final likes = RegExp(r'^(\d+) likes$').firstMatch(value);
    if (likes != null) {
      return '${likes.group(1)} J’aime';
    }
    final postLikes = RegExp(r'^(\d+) Likes?$').firstMatch(value);
    if (postLikes != null) return '${postLikes.group(1)} J’aime';
    final ageRange = RegExp(r'^Age range: (.+)$').firstMatch(value);
    if (ageRange != null) return 'Tranche d’âge : ${ageRange.group(1)}';
    final hello = RegExp(r'^Say hello to (.+)$').firstMatch(value);
    if (hello != null) return 'Dites bonjour à ${hello.group(1)}';
    final distance = RegExp(r'^● (.+) km away$').firstMatch(value);
    if (distance != null) return '● À ${distance.group(1)} km';
    final aboutDistance = RegExp(r'^About (.+) km away$').firstMatch(value);
    if (aboutDistance != null) {
      return 'À environ ${aboutDistance.group(1)} km';
    }
    final cityDistance = RegExp(
      r'^(.+) • About (.+) km away$',
    ).firstMatch(value);
    if (cityDistance != null) {
      return '${cityDistance.group(1)} • À environ ${cityDistance.group(2)} km';
    }
    final matchScore = RegExp(r'^(\d+)% Match$').firstMatch(value);
    if (matchScore != null) return '${matchScore.group(1)} % de compatibilité';
    final compatible = RegExp(r'^(\d+)% compatible$').firstMatch(value);
    if (compatible != null) {
      return '${compatible.group(1)} % compatible';
    }
    final height = RegExp(r'^Height: (.+)$').firstMatch(value);
    if (height != null) return 'Taille : ${height.group(1)}';
    final origin = RegExp(r'^Originally from (.+)$').firstMatch(value);
    if (origin != null) return 'Originaire de ${origin.group(1)}';
    final minutes = RegExp(r'^(\d+)m$').firstMatch(value);
    if (minutes != null) return 'Il y a ${minutes.group(1)} min';
    final hours = RegExp(r'^(\d+)h$').firstMatch(value);
    if (hours != null) return 'Il y a ${hours.group(1)} h';
    final days = RegExp(r'^(\d+)d$').firstMatch(value);
    if (days != null) return 'Il y a ${days.group(1)} j';
    final removeFriend = RegExp(
      r'^Remove (.+) from friends\?$',
    ).firstMatch(value);
    if (removeFriend != null) {
      return 'Supprimer ${removeFriend.group(1)} de vos amis ?';
    }
    final friendRequest = RegExp(
      r'^Friend request from (.+)$',
    ).firstMatch(value);
    if (friendRequest != null) {
      return 'Demande d’amitié de ${friendRequest.group(1)}';
    }
    final photoComments = RegExp(
      r'^Comments on (.+)’s photo$',
    ).firstMatch(value);
    if (photoComments != null) {
      return 'Commentaires sur la photo de ${photoComments.group(1)}';
    }
    const errorActions = <String, String>{
      'Unable to add the private photo': 'Impossible d’ajouter la photo privée',
      'Unable to apply filters': 'Impossible d’appliquer les filtres',
      'Unable to cancel friend request':
          'Impossible d’annuler la demande d’amitié',
      'Unable to clear this chat': 'Impossible d’effacer cette conversation',
      'Unable to delete this message': 'Impossible de supprimer ce message',
      'Unable to export your data': 'Impossible d’exporter vos données',
      'Unable to load all profile details':
          'Impossible de charger tous les détails du profil',
      'Unable to load photo moderation':
          'Impossible de charger la modération des photos',
      'Unable to load your saved filters. Default filters will be used':
          'Impossible de charger vos filtres enregistrés. Les filtres par défaut seront utilisés',
      'Unable to open the gallery': 'Impossible d’ouvrir la galerie',
      'Unable to publish': 'Impossible de publier',
      'Unable to refresh profiles': 'Impossible d’actualiser les profils',
      'Unable to refresh the profile photo':
          'Impossible d’actualiser la photo de profil',
      'Unable to remove friend': 'Impossible de supprimer cet ami',
      'Unable to report this photo': 'Impossible de signaler cette photo',
      'Unable to request access': 'Impossible de demander l’accès',
      'Unable to save preferences': 'Impossible d’enregistrer les préférences',
      'Unable to save profile': 'Impossible d’enregistrer le profil',
      'Unable to save your location': 'Impossible d’enregistrer votre position',
      'Unable to start conversation': 'Impossible de démarrer la conversation',
      'Unable to start the conversation':
          'Impossible de démarrer la conversation',
      'Unable to update friend request':
          'Impossible de mettre à jour la demande d’amitié',
      'Unable to update friendship': 'Impossible de mettre à jour cette amitié',
      'Unable to update this Super Like':
          'Impossible de mettre à jour ce Super Like',
      'Unable to update this like': 'Impossible de mettre à jour ce J’aime',
      'Unable to update this photo like':
          'Impossible de mettre à jour le J’aime de cette photo',
      'Unable to update your location':
          'Impossible de mettre à jour votre position',
      'Unable to update international discovery':
          'Impossible de mettre à jour la découverte internationale',
    };
    for (final entry in errorActions.entries) {
      if (value == entry.key) return entry.value;
      if (value.startsWith('${entry.key}:')) {
        return '${entry.value} :${value.substring(entry.key.length + 1)}';
      }
    }
    if (value.startsWith('Unable to ')) {
      return 'Impossible d’effectuer cette action.';
    }
    return value;
  }
}

extension MapLovTranslation on BuildContext {
  String tr(String value) => MapLovLocalizations.of(this).translate(value);
}

class _MapLovLocalizationsDelegate
    extends LocalizationsDelegate<MapLovLocalizations> {
  const _MapLovLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      const ['en', 'fr'].contains(locale.languageCode);
  @override
  Future<MapLovLocalizations> load(Locale locale) =>
      SynchronousFuture(MapLovLocalizations(locale));
  @override
  bool shouldReload(covariant LocalizationsDelegate<MapLovLocalizations> old) =>
      false;
}
