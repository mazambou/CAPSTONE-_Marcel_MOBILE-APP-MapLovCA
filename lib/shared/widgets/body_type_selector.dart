part of '../../app.dart';

class _GenderSingleSelector extends StatelessWidget {
  const _GenderSingleSelector({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final value in const ['Women', 'Men', 'Non-binary'])
        ChoiceChip(
          key: Key('gender_${value.toLowerCase().replaceAll('-', '_')}'),
          label: Text(context.tr(value)),
          selected: selected == value,
          onSelected: (isSelected) {
            if (isSelected) onChanged(value);
          },
        ),
    ],
  );
}

class _BodyTypeSelector extends StatefulWidget {
  const _BodyTypeSelector({
    required this.selected,
    required this.onChanged,
    required this.enabledGalleries,
    this.multiple = false,
    this.requireValidation = false,
    this.prompt = 'Choose the silhouette that resembles you most',
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final Set<String> enabledGalleries;
  final bool multiple;
  final bool requireValidation;
  final String prompt;

  @override
  State<_BodyTypeSelector> createState() => _BodyTypeSelectorState();
}

class _BodyTypeSelectorState extends State<_BodyTypeSelector> {
  String? openGallery;
  late Set<String> draftSelected;

  @override
  void initState() {
    super.initState();
    draftSelected = {...widget.selected};
  }

  @override
  void didUpdateWidget(covariant _BodyTypeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (openGallery == null) draftSelected = {...widget.selected};
  }

  void _toggleGallery(String gallery) {
    if (!widget.enabledGalleries.contains(gallery)) return;
    if (widget.requireValidation && openGallery != null) return;
    setState(() {
      openGallery = openGallery == gallery ? null : gallery;
      draftSelected = {...widget.selected};
    });
  }

  void _select(String id) {
    final next = widget.requireValidation
        ? {...draftSelected}
        : {...widget.selected};
    if (widget.multiple) {
      if (!next.add(id)) next.remove(id);
    } else {
      if (next.length == 1 && next.contains(id)) {
        next.clear();
      } else {
        next
          ..clear()
          ..add(id);
      }
    }
    if (widget.requireValidation) {
      setState(() => draftSelected = next);
    } else {
      widget.onChanged(next);
    }
  }

  void _validateSelection() {
    widget.onChanged({...draftSelected});
    setState(() => openGallery = null);
  }

  void _clearSelection() {
    widget.onChanged(<String>{});
    setState(() {
      draftSelected.clear();
      openGallery = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gallery = widget.enabledGalleries.contains(openGallery)
        ? openGallery
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(widget.prompt),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                widget.multiple
                    ? 'Select one or more options. No preference is active by default.'
                    : 'This optional choice can be changed at any time.',
              ),
              style: const TextStyle(color: AppColors.grayText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final value in const ['Women', 'Men', 'All silhouettes'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: OutlinedButton(
                        key: Key(
                          'body_gallery_${value.toLowerCase().replaceAll(' ', '_')}',
                        ),
                        onPressed:
                            widget.enabledGalleries.contains(value) &&
                                (!widget.requireValidation ||
                                    gallery == null ||
                                    gallery == value)
                            ? () => _toggleGallery(value)
                            : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          backgroundColor: gallery == value
                              ? AppColors.deepPink.withValues(alpha: 0.12)
                              : null,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(context.tr(value)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.multiple) ...[
              const SizedBox(height: 8),
              ChoiceChip(
                key: const Key('body_type_no_preference'),
                label: Text(context.tr('No preference')),
                selected:
                    (widget.requireValidation && gallery != null
                            ? draftSelected
                            : widget.selected)
                        .isEmpty,
                onSelected: (_) => _clearSelection(),
              ),
            ],
            if (gallery != null) ...[
              const SizedBox(height: 14),
              _BodyTypeGrid(
                gallery: gallery,
                selected: widget.requireValidation
                    ? draftSelected
                    : widget.selected,
                onSelected: _select,
              ),
              if (widget.requireValidation) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('body_type_validate_selection'),
                    onPressed: _validateSelection,
                    icon: const Icon(Icons.check),
                    label: Text(context.tr('Validate selection')),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _BodyTypeGrid extends StatelessWidget {
  const _BodyTypeGrid({
    required this.gallery,
    required this.selected,
    required this.onSelected,
  });

  final String gallery;
  final Set<String> selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final presentations = switch (gallery) {
      'Women' => const ['women'],
      'Men' => const ['men'],
      _ => const ['women', 'men'],
    };
    final entries = [
      for (final presentation in presentations)
        for (final option in _bodyTypeOptions) (presentation, option),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final (presentation, option) = entries[index];
        final visualId = '${presentation}_${option.id}';
        final isSelected = selected.contains(visualId);
        final semanticPresentation = presentation == 'women'
            ? context.tr('Feminine silhouette')
            : context.tr('Masculine silhouette');
        final cardKey = gallery == 'All silhouettes'
            ? 'body_type_all_${presentation}_${option.id}'
            : 'body_type_${presentation}_${option.id}';
        return Semantics(
          button: true,
          selected: isSelected,
          excludeSemantics: true,
          label: '${context.tr(option.label)}, $semanticPresentation',
          child: InkWell(
            key: Key(cardKey),
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelected(visualId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.deepPink : Colors.black12,
                  width: isSelected ? 3 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.asset(
                            'assets/body_types/$presentation/${option.id}.webp',
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 5, 6, 9),
                          child: Text(
                            context.tr(option.label),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Positioned(
                      right: 7,
                      top: 7,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.deepPink,
                        child: Icon(Icons.check, color: Colors.white, size: 17),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
