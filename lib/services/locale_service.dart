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
    'Messages': 'Messages',
    'Your matches': 'Vos matchs',
    'My profile': 'Mon profil',
    'Settings': 'Paramètres',
    'Filters': 'Filtres',
    'Notifications': 'Notifications',
    'Edit profile': 'Modifier le profil',
    'Manage photos': 'Gérer les photos',
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
    'Retry': 'Réessayer',
    'Read': 'Lu',
    'Message deleted': 'Message supprimé',
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
