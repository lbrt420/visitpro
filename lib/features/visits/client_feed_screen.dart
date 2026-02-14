import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/visit.dart';
import '../../core/providers/session_provider.dart';
import '../../core/ui/widgets/app_brand_header.dart';
import '../../core/ui/widgets/async_state_view.dart';
import 'visits_controller.dart';

class ClientFeedScreen extends ConsumerStatefulWidget {
  const ClientFeedScreen({
    super.key,
    this.initialVisitId,
  });

  final String? initialVisitId;

  @override
  ConsumerState<ClientFeedScreen> createState() => _ClientFeedScreenState();
}

class _ClientFeedScreenState extends ConsumerState<ClientFeedScreen> {
  final Map<String, GlobalKey> _visitCardKeys = <String, GlobalKey>{};
  bool _didJumpToInitialVisit = false;
  String _lastInitialVisitId = '';
  String _lastRequestedFocusVisitId = '';

  @override
  void initState() {
    super.initState();
    _lastInitialVisitId = widget.initialVisitId?.trim() ?? '';
  }

  @override
  void didUpdateWidget(covariant ClientFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextVisitId = widget.initialVisitId?.trim() ?? '';
    if (nextVisitId != _lastInitialVisitId) {
      _lastInitialVisitId = nextVisitId;
      _didJumpToInitialVisit = false;
      _visitCardKeys.clear();
      if (nextVisitId.isNotEmpty) {
        ref.invalidate(clientFeedProvider);
      }
    }
  }

  void _invalidateClientFeed(WidgetRef ref, List<ClientFeedItem> items) {
    for (final item in items) {
      ref.invalidate(visitsByPropertyProvider(item.property.id));
    }
    ref.invalidate(clientFeedProvider);
  }

  Future<void> _refreshClientFeed(WidgetRef ref, List<ClientFeedItem> items) async {
    _invalidateClientFeed(ref, items);
    await ref.read(clientFeedProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(clientFeedProvider);
    final session = ref.watch(sessionProvider);
    final pendingFocusVisitId = (ref.watch(pendingVisitFocusProvider) ?? '').trim();
    final routeVisitId = widget.initialVisitId?.trim() ?? '';
    final targetVisitId = pendingFocusVisitId.isNotEmpty ? pendingFocusVisitId : routeVisitId;
    _syncFocusTarget(targetVisitId);

    return Scaffold(
      body: AsyncStateView<List<ClientFeedItem>>(
        value: feed,
        onRetry: () => feed.whenData((items) => _invalidateClientFeed(ref, items)),
        data: (items) {
          _scheduleJumpToInitialVisit(items, targetVisitId);
          if (items.isEmpty) {
            return const _EmptyClientFeedState();
          }
          return RefreshIndicator(
            onRefresh: () => _refreshClientFeed(ref, items),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const AppBrandHeader();
                }

                final item = items[index - 1];
                final visit = item.visit;
                final visitCardKey = _visitCardKeys.putIfAbsent(visit.id, () => GlobalKey());
                final isClientViewer = session.role == UserRole.client;
                final isOwnVisit = session.userId != null &&
                    session.userId!.isNotEmpty &&
                    session.userId == visit.createdByUserId;
                final actorName = isOwnVisit ? l10n.youWord : visit.workerName;
                final checkedLabels = visit.serviceChecklist
                    .map((itemId) => l10n.serviceChecklistItemLabel(itemId))
                    .toList();

                return Card(
                  key: visitCardKey,
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: Builder(
                          builder: (context) {
                            final workerAvatarUrl = (visit.workerAvatarUrl ?? '').trim();
                            final companyLogoUrl = item.property.companyLogoUrl.trim();
                            final imageUrl = workerAvatarUrl.startsWith('http')
                                ? workerAvatarUrl
                                : (companyLogoUrl.startsWith('http') ? companyLogoUrl : '');
                            final hasImage = imageUrl.isNotEmpty;
                            return CircleAvatar(
                              backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
                              child: hasImage
                                  ? null
                                  : const Icon(Icons.business_outlined, size: 18),
                            );
                          },
                        ),
                        title: RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.titleMedium,
                            children: [
                              TextSpan(
                                text: actorName,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: isClientViewer
                                    ? ' ${l10n.visitedYourProperty} '
                                    : ' ${l10n.visitedPropertyPhrase} ',
                              ),
                              TextSpan(
                                text: item.property.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        subtitle: Text(
                          _formatDate(context, visit.createdAt),
                        ),
                      ),
                      if (visit.photos.isNotEmpty) _FeedPhotoGallery(photos: visit.photos),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.serviceTypeLabel(visit.serviceType),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              visit.note.isEmpty ? l10n.noVisitNote : visit.note,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 10),
                            if (checkedLabels.isNotEmpty)
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: checkedLabels
                                    .map((label) => _statusChip(context, label))
                                    .toList(),
                              ),
                            const SizedBox(height: 8),
                            _ReactionBar(
                              visitId: visit.id,
                              propertyId: item.property.id,
                              initialReactionCounts: visit.reactionCounts,
                              initialUserReaction: visit.userReaction,
                              initialReactionDetails: visit.reactionDetails,
                              canReact: session.role == UserRole.client,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _scheduleJumpToInitialVisit(List<ClientFeedItem> items, String targetVisitId) {
    if (_didJumpToInitialVisit || targetVisitId.isEmpty) {
      return;
    }
    if (!items.any((item) => item.visit.id == targetVisitId)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _visitCardKeys[targetVisitId]?.currentContext;
      if (targetContext == null) {
        // The target card may not be laid out yet.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final retryContext = _visitCardKeys[targetVisitId]?.currentContext;
          if (retryContext == null) {
            return;
          }
          _didJumpToInitialVisit = true;
          Scrollable.ensureVisible(
            retryContext,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: 0.08,
          );
          ref.read(pendingVisitFocusProvider.notifier).clear();
        });
        return;
      }
      _didJumpToInitialVisit = true;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
      ref.read(pendingVisitFocusProvider.notifier).clear();
    });
  }

  void _syncFocusTarget(String targetVisitId) {
    if (targetVisitId.isEmpty) {
      _lastRequestedFocusVisitId = '';
      return;
    }
    if (targetVisitId == _lastRequestedFocusVisitId) {
      return;
    }
    _lastRequestedFocusVisitId = targetVisitId;
    _didJumpToInitialVisit = false;
  }

  String _formatDate(BuildContext context, DateTime date) {
    final material = MaterialLocalizations.of(context);
    final use24h = MediaQuery.of(context).alwaysUse24HourFormat;
    final datePart = material.formatMediumDate(date);
    final timePart = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: use24h,
    );
    return '$datePart $timePart';
  }

  Widget _statusChip(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle,
          size: 14,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _FeedPhotoGallery extends StatelessWidget {
  const _FeedPhotoGallery({required this.photos});

  final List<Photo> photos;

  @override
  Widget build(BuildContext context) {
    final count = photos.length;
    if (count == 1) {
      return AspectRatio(
        aspectRatio: 16 / 10,
        child: _tile(context, 0),
      );
    }
    if (count == 2) {
      return SizedBox(
        height: 220,
        child: Row(
          children: [
            Expanded(child: _tile(context, 0)),
            const SizedBox(width: 2),
            Expanded(child: _tile(context, 1)),
          ],
        ),
      );
    }
    if (count == 3) {
      return SizedBox(
        height: 250,
        child: Row(
          children: [
    Expanded(flex: 2, child: _tile(context, 0)),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _tile(context, 1)),
                  const SizedBox(height: 2),
                  Expanded(child: _tile(context, 2)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 250,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _tile(context, 0)),
                const SizedBox(width: 2),
                Expanded(child: _tile(context, 1)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _tile(context, 2)),
                const SizedBox(width: 2),
                Expanded(
                  child: _tile(
                    context,
                    3,
                    overlayText: count > 4 ? '+${count - 4}' : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, int index, {String? overlayText}) {
    final photo = photos[index];
    final imageUrl = photo.url;
    return Material(
      color: const Color(0xFFF1F3F4),
      child: InkWell(
        onTap: () => _openViewer(context, initialIndex: index),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.startsWith('http'))
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 36),
                ),
              )
            else
              const Center(
                child: Icon(Icons.photo, size: 40),
              ),
            if (overlayText != null)
              Container(
                color: Colors.black.withValues(alpha: 0.45),
                alignment: Alignment.center,
                child: Text(
                  overlayText,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openViewer(BuildContext context, {required int initialIndex}) async {
    final pageController = PageController(initialPage: initialIndex);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        var currentIndex = initialIndex;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: photos.length,
                    onPageChanged: (index) {
                      setState(() {
                        currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final url = photos[index].url;
                      return Center(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: url.startsWith('http')
                              ? Image.network(
                                  url,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white70,
                                    size: 52,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo,
                                  color: Colors.white70,
                                  size: 52,
                                ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${currentIndex + 1} / ${photos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    pageController.dispose();
  }
}

class _ReactionBar extends ConsumerStatefulWidget {
  const _ReactionBar({
    required this.visitId,
    required this.propertyId,
    required this.initialReactionCounts,
    required this.initialUserReaction,
    required this.initialReactionDetails,
    required this.canReact,
  });

  final String visitId;
  final String propertyId;
  final Map<String, int> initialReactionCounts;
  final String? initialUserReaction;
  final List<VisitReactionDetail> initialReactionDetails;
  final bool canReact;

  @override
  ConsumerState<_ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends ConsumerState<_ReactionBar> {
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  String? _dragHoverEmoji;
  Map<String, GlobalKey> _emojiKeys = <String, GlobalKey>{};

  @override
  void dispose() {
    _removeReactionOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedEmoji = widget.canReact ? widget.initialUserReaction : null;
    final visibleReactionDetails = widget.initialReactionDetails.where((detail) {
      if (detail.names.isEmpty) {
        return false;
      }
      if (widget.canReact && selectedEmoji != null && detail.emoji == selectedEmoji) {
        // User already sees their own selected emoji in the reaction control.
        return false;
      }
      return true;
    }).toList();

    return Row(
      children: [
        if (widget.canReact)
          GestureDetector(
            onTap: () async {
              if (selectedEmoji == null) {
                await _submitReaction('👍');
                return;
              }
              // Tap selected reaction to remove it and reveal the + control again.
              await _submitReaction(selectedEmoji);
            },
            onLongPressStart: (details) {
              _showReactionOverlay(
                context: context,
                selectedEmoji: selectedEmoji,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateDragSelection(details.globalPosition);
              });
            },
            onLongPressMoveUpdate: (details) {
              _updateDragSelection(details.globalPosition);
            },
            onLongPressEnd: (_) async {
              final hovered = _dragHoverEmoji;
              _removeReactionOverlay();
              if (hovered == null) {
                return;
              }
              if (selectedEmoji != null && hovered == selectedEmoji) {
                return;
              }
              await _submitReaction(hovered);
            },
            onLongPressCancel: _removeReactionOverlay,
            child: Container(
              key: _anchorKey,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: selectedEmoji == null
                  ? null
                  : BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedEmoji ?? '🙂',
                    style: const TextStyle(fontSize: 18),
                  ),
                  if (selectedEmoji == null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '+',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (widget.canReact && visibleReactionDetails.isNotEmpty) const SizedBox(width: 8),
        if (visibleReactionDetails.isNotEmpty)
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: visibleReactionDetails
                  .map((detail) => _reactionDetailPill(context, detail))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _reactionDetailPill(BuildContext context, VisitReactionDetail detail) {
    final names = detail.names.join(', ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.labelSmall,
          children: [
            TextSpan(
              text: '${detail.emoji} ',
              style: const TextStyle(fontSize: 18),
            ),
            TextSpan(
              text: names,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReaction(String emoji) async {
    if (!widget.canReact) {
      return;
    }
    try {
      await ref.read(visitsControllerProvider).toggleVisitReaction(
            propertyId: widget.propertyId,
            visitId: widget.visitId,
            emoji: emoji,
          );
    } catch (_) {
      // Keep silent for now; feed refresh will keep last known server state.
    }
  }

  void _showReactionOverlay({
    required BuildContext context,
    required String? selectedEmoji,
  }) {
    _removeReactionOverlay();
    final anchorContext = _anchorKey.currentContext;
    if (anchorContext == null) {
      return;
    }
    final anchorRender = anchorContext.findRenderObject();
    final overlayRender = Overlay.of(context).context.findRenderObject();
    if (anchorRender is! RenderBox || overlayRender is! RenderBox) {
      return;
    }

    _emojiKeys = {
      for (final emoji in FeedReactionsNotifier.availableEmojis) emoji: GlobalKey(),
    };
    final anchorTopCenter = anchorRender.localToGlobal(
      Offset(anchorRender.size.width / 2, 0),
      ancestor: overlayRender,
    );
    const menuWidth = 196.0;
    const menuHeight = 42.0;
    const margin = 8.0;
    final left = (anchorTopCenter.dx - (menuWidth / 2)).clamp(
      margin,
      overlayRender.size.width - menuWidth - margin,
    );
    final top = (anchorTopCenter.dy - menuHeight - 10).clamp(
      margin,
      overlayRender.size.height - menuHeight - margin,
    );

    _dragHoverEmoji = selectedEmoji;
    _overlayEntry = OverlayEntry(
      builder: (_) {
        return Positioned(
          left: left,
          top: top,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: menuWidth,
                height: menuHeight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F232A),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: FeedReactionsNotifier.availableEmojis.map((emoji) {
                    final highlighted = emoji == _dragHoverEmoji;
                    return AnimatedContainer(
                      key: _emojiKeys[emoji],
                      duration: const Duration(milliseconds: 90),
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      transform: highlighted
                          ? (Matrix4.identity()..translate(0.0, -6.0)..scale(1.22))
                          : Matrix4.identity(),
                      decoration: highlighted
                          ? BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
    _overlayEntry?.markNeedsBuild();
  }

  void _removeReactionOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _emojiKeys = <String, GlobalKey>{};
    _dragHoverEmoji = null;
  }

  void _updateDragSelection(Offset globalPosition) {
    if (_overlayEntry == null) {
      return;
    }
    String? hovered;
    for (final entry in _emojiKeys.entries) {
      final context = entry.value.currentContext;
      if (context == null) {
        continue;
      }
      final render = context.findRenderObject();
      if (render is! RenderBox) {
        continue;
      }
      final origin = render.localToGlobal(Offset.zero);
      final rect = origin & render.size;
      if (rect.inflate(12).contains(globalPosition)) {
        hovered = entry.key;
        break;
      }
    }
    if (hovered == _dragHoverEmoji) {
      return;
    }
    setState(() {
      _dragHoverEmoji = hovered;
    });
    _overlayEntry?.markNeedsBuild();
  }
}

class _EmptyClientFeedState extends StatelessWidget {
  const _EmptyClientFeedState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
      children: [
        const AppBrandHeader(),
        const SizedBox(height: 18),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.dynamic_feed_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  l10n.noUpdatesYet,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.feedEmptyHelp,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
