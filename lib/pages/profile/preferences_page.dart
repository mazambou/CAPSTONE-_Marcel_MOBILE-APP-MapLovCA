part of '../../app.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  RangeValues ages = const RangeValues(24, 38);
  String searchMode = 'Near me';
  double distance = 50;
  String selectedCity = 'Any city';
  String preferredCountry = 'Canada';
  String preferredRegion = 'Any region';
  String residenceCountry = 'Canada';
  String residenceRegion = 'Any region';
  String residenceCity = 'Any city';
  String? soughtGender;
  String relationshipGoal = 'Long-term';
  String language = 'Any language';
  String personality = 'Any personality';
  bool requiredLanguage = false;
  bool requiredGoal = false;
  bool loading = true;
  bool saving = false;
  bool premiumPlus = false;
  bool vipAvailable = false;
  bool showingGenderSuggestion = false;
  List<String> savedOriginCountries = const [];
  List<String> savedOriginRegions = const [];
  List<String> savedOriginCities = const [];
  DiscoveryFilters savedFilters = const DiscoveryFilters();
  List<Map<String, dynamic>> upcomingArrivals = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final saved = await MapLovRepository.instance.myPreferences();
    final profile = await MapLovRepository.instance.myProfileDetails();
    final subscription = await MapLovRepository.instance.subscriptionInfo();
    final arrivals = subscription.isVip
        ? await MapLovRepository.instance.myUpcomingArrivals()
        : const <Map<String, dynamic>>[];
    if (!mounted) return;
    setState(() {
      savedFilters = saved;
      ages = RangeValues(
        saved.minimumAge.toDouble(),
        saved.maximumAge.toDouble(),
      );
      final savedSearchMode = switch (saved.locationMode) {
        'my_country' => 'My country',
        'specific_country' || 'worldwide' => 'International',
        _ => 'Near me',
      };
      searchMode = subscription.isPremium ? savedSearchMode : 'Near me';
      distance = saved.distanceKm.toDouble().clamp(1, 100);
      selectedCity = saved.cities.firstOrNull ?? 'Any city';
      final shouldSuggestGenders =
          saved.genders.isEmpty &&
          AuthService.instance.requiresPreferencesCompletion;
      soughtGender = shouldSuggestGenders
          ? _defaultSoughtGender(profile?['gender'] as String?)
          : saved.genders.firstOrNull == null
          ? null
          : _displayGenderFilterValue(saved.genders.first);
      showingGenderSuggestion = shouldSuggestGenders && soughtGender != null;
      relationshipGoal = saved.relationshipGoals.firstOrNull ?? 'Long-term';
      language = saved.languages.firstOrNull ?? 'Any language';
      personality = saved.personalities.firstOrNull ?? 'Any personality';
      preferredCountry = saved.countries.firstOrNull ?? 'Canada';
      preferredRegion = saved.regions.firstOrNull ?? 'Any region';
      residenceCountry =
          profile?['country_name'] as String? ?? residenceCountry;
      residenceRegion =
          profile?['residence_region'] as String? ?? residenceRegion;
      residenceCity = profile?['city'] as String? ?? residenceCity;
      requiredLanguage = saved.requiredLanguages;
      requiredGoal = saved.requiredRelationshipGoal;
      premiumPlus = subscription.isPremium;
      vipAvailable = subscription.isVip;
      upcomingArrivals = arrivals;
      savedOriginCountries = saved.originCountries;
      savedOriginRegions = saved.originRegions;
      savedOriginCities = saved.originCities;
      loading = false;
    });
  }

  void _backToProfileDetails() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
    }
  }

  Future<bool> _confirmRegistrationLocation() async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Enable location for Discover'),
            content: const Text(
              'MapLov uses your current GPS position to initialize Discover and calculate approximate distances. Your exact coordinates are never shown to other members, and background location is not used.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                key: const Key('confirm_registration_location'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _captureCurrentLocation({bool confirm = false}) async {
    if (!MapLovRepository.instance.isLive) return true;
    if (confirm && !await _confirmRegistrationLocation()) return false;
    try {
      await LocationService.instance.updateMyLocation();
      return true;
    } on MapLovLocationFailure catch (failure) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure.requiresSettings
                ? '$failure Open the device settings, allow location while using MapLov, then tap Next again.'
                : 'Location permission is required to initialize Discover. Allow it, then tap Next again.',
          ),
          action: failure.requiresSettings
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () => unawaited(
                    LocationService.instance.openRequiredSettings(failure),
                  ),
                )
              : null,
        ),
      );
      return false;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save your location: $error')),
        );
      }
      return false;
    }
  }

  Future<void> _continue() async {
    if (loading || saving) return;
    if (soughtGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose one gender preference.')),
      );
      return;
    }
    final completingRegistration =
        !AuthService.instance.isConfigured ||
        AuthService.instance.requiresPreferencesCompletion;
    setState(() => saving = true);
    try {
      if (searchMode != 'Near me' && !premiumPlus) {
        setState(() => saving = false);
        final international = searchMode == 'International';
        await _requireSubscriptionFeature(
          context,
          requirement: international
              ? _SubscriptionRequirement.vip
              : _SubscriptionRequirement.premiumPlus,
          feature: international
              ? 'International discovery'
              : 'Country discovery',
          passProduct: international
              ? ExternalPaymentProduct.internationalPass24h
              : ExternalPaymentProduct.countryPass24h,
        );
        return;
      }
      await MapLovRepository.instance.savePreferences(
        DiscoveryFilters(
          minimumAge: ages.start.round(),
          maximumAge: ages.end.round(),
          distanceKm: distance.round(),
          locationMode: switch (searchMode) {
            'My country' => 'my_country',
            'International' => 'specific_country',
            _ => 'near_me',
          },
          countries: switch (searchMode) {
            'My country' => [residenceCountry],
            'International' => [preferredCountry],
            _ => const [],
          },
          regions: searchMode == 'Near me' || preferredRegion == 'Any region'
              ? const []
              : [preferredRegion],
          cities: searchMode != 'Near me' && selectedCity != 'Any city'
              ? [selectedCity]
              : const [],
          genders: [_storedGenderFilterValue(soughtGender!)],
          relationshipGoals: [relationshipGoal],
          languages: language == 'Any language'
              ? const []
              : language == 'English & French'
              ? const ['English', 'French']
              : [language],
          personalities: personality == 'Any personality'
              ? const []
              : [personality],
          originCountries: savedOriginCountries,
          originRegions: savedOriginRegions,
          originCities: savedOriginCities,
          religions: savedFilters.religions,
          bodyTypes: savedFilters.bodyTypes
              .where(
                (value) =>
                    _bodyTypeAllowedForSoughtGender(value, soughtGender!),
              )
              .toList(growable: false),
          eyeColors: savedFilters.eyeColors,
          hairColors: savedFilters.hairColors,
          minimumHeightCm: savedFilters.minimumHeightCm,
          maximumHeightCm: savedFilters.maximumHeightCm,
          childrenPreferences: savedFilters.childrenPreferences,
          relationshipStatuses: savedFilters.relationshipStatuses,
          educationLevels: savedFilters.educationLevels,
          beardStyles: savedFilters.beardStyles,
          smokingStatuses: savedFilters.smokingStatuses,
          professionCategories: savedFilters.professionCategories,
          incomeLevels: savedFilters.incomeLevels,
          photoVerifiedOnly: savedFilters.photoVerifiedOnly,
          verifiedOnly: savedFilters.verifiedOnly,
          activeTodayOnly: savedFilters.activeTodayOnly,
          interestSlugs: savedFilters.interestSlugs,
          interestImportance: savedFilters.interestImportance,
          premiumOnly: savedFilters.premiumOnly,
          vipOnly: savedFilters.vipOnly,
          mostLikedFirst: savedFilters.mostLikedFirst,
          requiredGenders: true,
          requiredLocation: true,
          requiredLanguages: requiredLanguage,
          requiredRelationshipGoal: requiredGoal,
        ),
      );
      if (!await _captureCurrentLocation(confirm: completingRegistration)) {
        return;
      }
      await AuthService.instance.markPreferencesCompleted();
      if (!mounted) return;
      if (AuthService.instance.isConfigured &&
          AuthService.instance.isPhoneVerified) {
        if (completingRegistration) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (_) => false,
          );
          return;
        }
        if (Navigator.canPop(context)) Navigator.pop(context);
        return;
      }
      Navigator.pushNamed(context, AppRoutes.verifyPhone);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save preferences: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _changeSearchMode(String value) async {
    final international = value == 'International';
    final subscription = await MapLovRepository.instance.subscriptionInfo();
    final passActive = value == 'Near me'
        ? false
        : await MapLovRepository.instance.hasActivePaymentEntitlement(
            international ? 'international_pass' : 'country_pass',
          );
    final available =
        value == 'Near me' ||
        (international ? subscription.isVip : subscription.isPremium) ||
        passActive;
    if (!mounted) return;
    if (available) {
      setState(() {
        if (searchMode != value) {
          preferredRegion = 'Any region';
          selectedCity = 'Any city';
        }
        searchMode = value;
      });
      return;
    }
    final granted = await _requireSubscriptionFeature(
      context,
      requirement: international
          ? _SubscriptionRequirement.vip
          : _SubscriptionRequirement.premiumPlus,
      feature: international ? 'International discovery' : 'Country discovery',
      passProduct: international
          ? ExternalPaymentProduct.internationalPass24h
          : ExternalPaymentProduct.countryPass24h,
    );
    if (granted && mounted) {
      setState(() {
        premiumPlus = true;
        preferredRegion = 'Any region';
        selectedCity = 'Any city';
        searchMode = value;
      });
      return;
    }
    return;
  }

  Future<void> _editUpcomingArrival([Map<String, dynamic>? existing]) async {
    if (!vipAvailable) {
      await _requireSubscriptionFeature(
        context,
        requirement: _SubscriptionRequirement.vip,
        feature: 'Arrive bientôt',
      );
      return;
    }
    if (existing == null &&
        upcomingArrivals.where((item) => item['is_active'] != false).length >=
            3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can add up to 3 active destinations.'),
        ),
      );
      return;
    }
    var country =
        existing?['country_name'] as String? ??
        _worldCountries.firstWhere(
          (value) => value != residenceCountry,
          orElse: () => 'France',
        );
    var region = existing?['region_name'] as String?;
    var city = existing?['city_name'] as String?;
    var month = DateTime.tryParse(existing?['arrival_month'] as String? ?? '');
    var active = existing?['is_active'] as bool? ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final regions = _regionsByCountry[country] ?? const <String>[];
          final cities = region == null
              ? const <String>[]
              : _citiesForCountryRegion(country, region!);
          return AlertDialog(
            title: Text(
              existing == null ? 'Add a destination' : 'Edit destination',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: country,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Country'),
                    items: _worldCountries
                        .where((value) => value != residenceCountry)
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() {
                      country = value ?? country;
                      region = null;
                      city = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: regions.contains(region) ? region : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Region (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Entire country'),
                      ),
                      ...regions.map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      region = value == null || value.isEmpty ? null : value;
                      city = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: cities.contains(city) ? city : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'City (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Entire region'),
                      ),
                      ...cities.map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      ),
                    ],
                    onChanged: region == null
                        ? null
                        : (value) => setDialogState(
                            () => city = value == null || value.isEmpty
                                ? null
                                : value,
                          ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Arrival month (optional)'),
                    subtitle: Text(
                      month == null
                          ? 'Not specified'
                          : DateFormat.yMMMM().format(month!),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final now = DateTime.now();
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: month ?? now,
                        firstDate: DateTime(now.year, now.month),
                        lastDate: DateTime(now.year + 5, 12, 31),
                      );
                      if (selected != null) {
                        setDialogState(
                          () => month = DateTime(selected.year, selected.month),
                        );
                      }
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    if (saved != true) return;
    try {
      await MapLovRepository.instance.saveUpcomingArrival(
        id: existing?['id'] as String?,
        country: country,
        region: region,
        city: city,
        arrivalMonth: month,
        isActive: active,
      );
      final arrivals = await MapLovRepository.instance.myUpcomingArrivals();
      if (mounted) setState(() => upcomingArrivals = arrivals);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save destination: $error')),
        );
      }
    }
  }

  Future<void> _deleteUpcomingArrival(Map<String, dynamic> destination) async {
    try {
      await MapLovRepository.instance.deleteUpcomingArrival(
        destination['id'] as String,
      );
      final arrivals = await MapLovRepository.instance.myUpcomingArrivals();
      if (mounted) setState(() => upcomingArrivals = arrivals);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete destination: $error')),
        );
      }
    }
  }

  Widget _upcomingArrivalsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SectionTitle('✈️ Arrive bientôt'),
      Text(
        vipAvailable
            ? 'Choose up to 3 destinations. Only members in those destinations see your arrival badge and travel details.'
            : 'VIP members can appear in up to 3 future destinations without changing their real residence.',
        style: const TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 10),
      if (vipAvailable)
        ...upcomingArrivals.map((item) {
          final parts = <String>[
            if ((item['city_name'] as String? ?? '').isNotEmpty)
              item['city_name'] as String,
            if ((item['region_name'] as String? ?? '').isNotEmpty)
              item['region_name'] as String,
            item['country_name'] as String? ?? '',
          ];
          final month = DateTime.tryParse(
            item['arrival_month'] as String? ?? '',
          );
          return Card(
            child: ListTile(
              leading: Icon(
                Icons.flight_land,
                color: item['is_active'] == false
                    ? AppColors.grayText
                    : const Color(0xFFD4AF37),
              ),
              title: Text(parts.join(', ')),
              subtitle: Text(
                [
                  if (month != null) DateFormat.yMMMM().format(month),
                  item['is_active'] == false ? 'Inactive' : 'Active',
                ].join(' • '),
              ),
              onTap: () => unawaited(_editUpcomingArrival(item)),
              trailing: IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => unawaited(_deleteUpcomingArrival(item)),
              ),
            ),
          );
        }),
      OutlinedButton.icon(
        key: const Key('manage_upcoming_arrival'),
        onPressed: () => unawaited(_editUpcomingArrival()),
        icon: Icon(vipAvailable ? Icons.add_location_alt : Icons.lock),
        label: Text(vipAvailable ? 'Add a destination' : 'Unlock with VIP'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Dating preferences',
    children: [
      const Text(
        'Tell MapLov who you would like to meet. These preferences improve your compatibility results.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const _SectionTitle('Who you want to meet'),
      _GenderSingleSelector(
        selected: soughtGender,
        onChanged: (value) => setState(() {
          soughtGender = value;
          showingGenderSuggestion = false;
        }),
      ),
      if (showingGenderSuggestion)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Suggested from your profile. Confirm or change this choice.',
            style: TextStyle(color: AppColors.grayText, fontSize: 13),
          ),
        ),
      const SizedBox(height: 14),
      Text('Age range: ${ages.start.round()}–${ages.end.round()}'),
      RangeSlider(
        values: ages,
        min: 18,
        max: 80,
        onChanged: (value) => setState(() => ages = value),
      ),
      const _SectionTitle('Search location'),
      _SearchLocationSelector(
        mode: searchMode,
        distance: distance,
        selectedCity: selectedCity,
        selectedCountry: preferredCountry,
        selectedRegion: preferredRegion,
        residenceCountry: residenceCountry,
        residenceRegion: residenceRegion,
        residenceCity: residenceCity,
        onModeChanged: (value) => unawaited(_changeSearchMode(value)),
        onDistanceChanged: (value) => setState(() => distance = value),
        onCityChanged: (value) =>
            setState(() => selectedCity = value ?? 'Any city'),
        onCountryChanged: (value) => setState(() {
          preferredCountry = value ?? 'Canada';
          preferredRegion = 'Any region';
          selectedCity = 'Any city';
        }),
        onRegionChanged: (value) => setState(() {
          preferredRegion = value ?? 'Any region';
          selectedCity = 'Any city';
        }),
      ),
      _upcomingArrivalsSection(),
      const _SectionTitle('Compatibility priorities'),
      DropdownButtonFormField<String>(
        initialValue: relationshipGoal,
        decoration: InputDecoration(labelText: context.tr('Relationship goal')),
        items: ['Long-term', 'Dating', 'Friendship', 'Networking']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) =>
            setState(() => relationshipGoal = value ?? relationshipGoal),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Required relationship goal'),
        value: requiredGoal,
        onChanged: (value) => setState(() => requiredGoal = value),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: language,
        decoration: InputDecoration(labelText: context.tr('Languages')),
        items: ['English & French', 'English', 'French', 'Any language']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => setState(() => language = value ?? language),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Required language criterion'),
        value: requiredLanguage,
        onChanged: (value) => setState(() => requiredLanguage = value),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: personality,
        decoration: InputDecoration(labelText: context.tr('Personality')),
        items:
            [
                  'Any personality',
                  'Calm',
                  'Creative',
                  'Adventurous',
                  'Intellectual',
                ]
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
        onChanged: (value) =>
            setState(() => personality = value ?? personality),
      ),
      const SizedBox(height: 20),
      _PrimaryButton(
        loading
            ? 'Loading…'
            : saving
            ? 'Saving…'
            : 'Next',
        onPressed: _continue,
      ),
      TextButton.icon(
        key: const Key('preferences_back_to_profile'),
        onPressed: saving ? null : _backToProfileDetails,
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to profile details'),
      ),
    ],
  );
}
