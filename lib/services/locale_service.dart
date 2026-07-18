import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final instance = LocaleService._();
  static const _key = 'maplov_locale';

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  Future<void> load() async {
    final code = (await SharedPreferences.getInstance()).getString(_key);
    if (code == 'fr' || code == 'en') _locale = Locale(code!);
    notifyListeners();
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
    final ageRange = RegExp(r'^Age range: (.+)$').firstMatch(value);
    if (ageRange != null) return 'Tranche d’âge : ${ageRange.group(1)}';
    final hello = RegExp(r'^Say hello to (.+)$').firstMatch(value);
    if (hello != null) return 'Dites bonjour à ${hello.group(1)}';
    if (value.startsWith('Unable to ')) {
      return 'Impossible d’effectuer cette action : ${value.substring(10)}';
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
