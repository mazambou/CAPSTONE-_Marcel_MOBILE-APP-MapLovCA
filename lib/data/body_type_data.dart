part of '../app.dart';

class _BodyTypeOption {
  const _BodyTypeOption(this.id, this.label);

  final String id;
  final String label;
}

const _bodyTypeOptions = <_BodyTypeOption>[
  _BodyTypeOption('slim', 'Slim'),
  _BodyTypeOption('toned', 'Toned'),
  _BodyTypeOption('fit', 'Fit'),
  _BodyTypeOption('athletic', 'Athletic'),
  _BodyTypeOption('muscular', 'Muscular / built'),
  _BodyTypeOption('robust', 'Robust'),
  _BodyTypeOption('round', 'Round'),
  _BodyTypeOption('very_round', 'Very round'),
];

String? _normalizedBodyType(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final normalized = value.trim().toLowerCase().replaceAll('-', '_');
  final presentationMatch = RegExp(
    r'^(women|men)_(.+)$',
  ).firstMatch(normalized);
  final presentation = presentationMatch?.group(1);
  final rawBodyType = presentationMatch?.group(2) ?? normalized;
  final bodyType = switch (rawBodyType) {
    'slim' => 'slim',
    'toned' || 'lean / toned' => 'toned',
    'fit' || 'average' => 'fit',
    'athletic' => 'athletic',
    'muscular' || 'muscular / built' => 'muscular',
    'robust' || 'stocky' => 'robust',
    'round' || 'curvy' => 'round',
    'very_round' || 'full_figured' || 'plus_size' => 'very_round',
    _ => null,
  };
  if (bodyType == null) return null;
  return presentation == null ? bodyType : '${presentation}_$bodyType';
}

String? _defaultSoughtGender(String? profileGender) => switch (profileGender) {
  'Man' => 'Women',
  'Woman' => 'Men',
  'Non-binary' => 'Non-binary',
  _ => null,
};

Set<String> _enabledBodyGalleries(Set<String> soughtGenders) {
  if (soughtGenders.isEmpty) return const {};
  final enabled = <String>{};
  if (soughtGenders.contains('Women')) enabled.add('Women');
  if (soughtGenders.contains('Men')) enabled.add('Men');
  if (soughtGenders.contains('Non-binary')) enabled.add('All silhouettes');
  return enabled;
}

Set<String> _profileBodyGalleries(String gender) => switch (gender) {
  'Woman' => {'Women'},
  'Man' => {'Men'},
  'Non-binary' => {'All silhouettes'},
  _ => {'Women', 'Men', 'All silhouettes'},
};

String? _bodyTypePresentationForGender(String gender) => switch (gender) {
  'Woman' => 'women',
  'Man' => 'men',
  _ => null,
};

String? _normalizedProfileBodyType(String? value, String gender) {
  final normalized = _normalizedBodyType(value);
  if (normalized == null ||
      normalized.startsWith('women_') ||
      normalized.startsWith('men_')) {
    return normalized;
  }
  final presentation = _bodyTypePresentationForGender(gender);
  return presentation == null ? null : '${presentation}_$normalized';
}

bool _bodyTypeAllowedForProfileGender(String? bodyType, String gender) {
  if (bodyType == null) return true;
  return switch (gender) {
    'Woman' => bodyType.startsWith('women_'),
    'Man' => bodyType.startsWith('men_'),
    'Non-binary' || 'Prefer not to say' =>
      bodyType.startsWith('women_') || bodyType.startsWith('men_'),
    _ => false,
  };
}

bool _bodyTypeAllowedForSoughtGender(String bodyType, String soughtGender) =>
    switch (soughtGender) {
      'Women' => bodyType.startsWith('women_'),
      'Men' => bodyType.startsWith('men_'),
      'Non-binary' =>
        bodyType.startsWith('women_') || bodyType.startsWith('men_'),
      _ => false,
    };
