import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../core/breakpoints.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/ilyass_dropdown.dart';
import '../../core/ilyass_form.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/document.dart';
import '../../models/document_lookups.dart';
import '../../models/unit_of_measure.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/list_panel.dart';
import '../../widgets/state_views.dart';
import '../auth/auth_controller.dart';
import 'document_draft.dart';
import 'document_line_sheet.dart';
import 'documents_controller.dart';

/// Opens the document editor as its own page — a new document when [document]
/// is null. Resolves to true once something was saved.
Future<bool?> openDocumentEditor(
  BuildContext context, {
  SalesDocument? document,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => DocumentEditorScreen(document: document)),
  );
}

/// Creates or edits a document.
///
/// **Creating walks five steps in order** — Type, Details, Parties, Lines,
/// Review — and a step opens only once the ones before it are complete, so
/// nobody is asked for a warehouse before saying what kind of document it is.
/// Each Next checks its own step and says what is still missing; nothing
/// reaches the server until Create on the last step.
///
/// **Editing opens every step at once**: the same sections, reachable in any
/// order from the step track, and one Save for all of them.
///
/// A pushed page rather than a dialog: five steps of fields need the height,
/// and on a phone a dialog this size is a sheet whose top you cannot see.
class DocumentEditorScreen extends ConsumerStatefulWidget {
  const DocumentEditorScreen({super.key, this.document});

  final SalesDocument? document;

  @override
  ConsumerState<DocumentEditorScreen> createState() =>
      _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends ConsumerState<DocumentEditorScreen> {
  /// Ilyass Style reading cap: a form stretched across a 1920px monitor puts
  /// a label at one edge and its field at the other.
  static const double _formMaxWidth = 880;

  DocumentDraft? _draft;

  /// What the server holds of this document — as loaded, or what an
  /// interrupted save got through. Null while nothing has been saved.
  DocumentDraft? _server;

  DocumentStep _step = DocumentStep.type;

  /// The furthest step reached; the track opens every step up to it.
  int _reached = 0;
  bool _initialising = false;
  bool _dirty = false;
  bool _saving = false;
  bool _fetchingNumber = false;
  String? _problem;
  String? _saveError;
  String? _numberNote;
  String? _loadError;
  int? _categoryFilter;

  final _number = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  final _internalNote = TextEditingController();
  final _discount = TextEditingController();

  bool get _editing => widget.document != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _step = DocumentStep.lines;
    _bind(_number, (d) => d.number, (d, text) => d.copyWith(number: text));
    _bind(
      _reference,
      (d) => d.reference,
      (d, text) => d.copyWith(reference: text),
    );
    _bind(_note, (d) => d.note, (d, text) => d.copyWith(note: text));
    _bind(
      _internalNote,
      (d) => d.internalNote,
      (d, text) => d.copyWith(internalNote: text),
    );
    _discount.addListener(() {
      final draft = _draft;
      if (draft == null) return;
      final value = _parse(_discount.text) ?? 0;
      if (value != draft.discount) _update(draft.copyWith(discount: value));
    });
  }

  /// Keeps [controller] and one draft field in step. Only a real change
  /// writes back, so filling the fields in code does not mark the draft dirty.
  void _bind(
    TextEditingController controller,
    String Function(DocumentDraft draft) read,
    DocumentDraft Function(DocumentDraft draft, String text) write,
  ) {
    controller.addListener(() {
      final draft = _draft;
      if (draft == null || read(draft) == controller.text) return;
      _update(write(draft, controller.text));
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _number,
      _reference,
      _note,
      _internalNote,
      _discount,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static double? _parse(String text) {
    final raw = text.trim().replaceAll(',', '.');
    return raw.isEmpty ? null : double.tryParse(raw);
  }

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  void _update(DocumentDraft next) {
    setState(() {
      _draft = next;
      _dirty = true;
      _problem = null;
    });
  }

  /// Takes [draft] as the editor's state and fills the fields from it.
  void _adopt(DocumentDraft draft) {
    _draft = draft;
    _number.text = draft.number;
    _reference.text = draft.reference;
    _note.text = draft.note;
    _internalNote.text = draft.internalNote;
    _discount.text = draft.discount == 0 ? '' : _plain(draft.discount);
  }

  /// A new document starts out handled by whoever is signed in, in the only
  /// warehouse when there is just one — the two answers nobody should have to
  /// give twice.
  DocumentDraft _blank(DocumentLookups lookups) {
    final email = ref.read(authProvider).email.trim().toLowerCase();
    final me = email.isEmpty
        ? null
        : lookups.users
              .where((u) => (u.email ?? '').trim().toLowerCase() == email)
              .firstOrNull;
    return DocumentDraft.blank(DateTime.now()).copyWith(
      userId: me?.id,
      warehouseId: lookups.warehouses.length == 1
          ? lookups.warehouses.single.id
          : null,
    );
  }

  Future<void> _initialise(DocumentLookups lookups) async {
    if (!_editing) {
      setState(() => _adopt(_blank(lookups)));
      return;
    }
    setState(() {
      _initialising = true;
      _loadError = null;
    });
    try {
      final document = widget.document!;
      final lines = await loadDraftLines(
        ref.read(apiProvider),
        document,
        lookups,
      );
      if (!mounted) return;
      final draft = DocumentDraft.fromDocument(
        document,
        lookups: lookups,
        lines: lines,
      );
      setState(() {
        _adopt(draft);
        _server = draft;
        _reached = DocumentStep.values.length - 1;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  // --- Navigation between steps ---------------------------------------------

  void _goTo(DocumentStep step) {
    if (!_editing && step.index > _reached) return;
    setState(() {
      _step = step;
      _problem = null;
    });
  }

  void _next() {
    final problem = _draft!.problemAt(_step, creating: !_editing);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _step = _step.next;
      _reached = math.max(_reached, _step.index);
      _problem = null;
    });
  }

  // --- Changes that do more than set a field ---------------------------------

  void _selectType(DocumentTypeOption type, DocumentLookups lookups) {
    final before = _draft!;
    if (before.type?.id == type.id) return;
    var next = before.copyWith(type: type);
    if ((before.type?.isInventoryCount ?? false) != type.isInventoryCount) {
      next = _withExpected(next, lookups);
    }
    _update(next);
    if (!_editing && next.numberFollowsType) _fetchNumber(type);
  }

  /// Asks the server for the next number in [type]'s series.
  Future<void> _fetchNumber(DocumentTypeOption type) async {
    setState(() {
      _fetchingNumber = true;
      _numberNote = null;
    });
    try {
      final number = await ref
          .read(apiProvider)
          .fetchNextDocumentNumber(documentTypeId: type.id);
      if (!mounted) return;
      final now = _draft!;
      // A later pick may have overtaken this request.
      if (now.type?.id != type.id) return;
      setState(() {
        _draft = now.copyWith(number: number, autoNumber: number);
        _dirty = true;
      });
      _number.text = number;
    } on ApiException catch (e) {
      if (mounted && !e.isCancelled) {
        setState(
          () => _numberNote =
              "Couldn't get the next ${type.name} number. ${e.message} "
              'Type a number instead.',
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingNumber = false);
    }
  }

  /// Gives unsaved lines the expected stock an inventory count needs — or
  /// takes it away when the document stops being a count. Saved lines keep
  /// theirs: it is the stock they were counted against, not today's.
  DocumentDraft _withExpected(DocumentDraft draft, DocumentLookups lookups) {
    final counting = draft.type?.isInventoryCount ?? false;
    return draft.copyWith(
      lines: [
        for (final line in draft.lines)
          if (line.serverId != null)
            line
          else
            line.copyWith(
              expectedQuantity: counting
                  ? _expectedFor(line.productId, draft.warehouseId, lookups)
                  : null,
            ),
      ],
    );
  }

  double? _expectedFor(int productId, int? warehouseId, DocumentLookups lookups) {
    final product = lookups.productById(productId);
    if (product == null || warehouseId == null) return null;
    return stockInProductUnit(lookups.stockOf(productId, warehouseId), product);
  }

  Future<void> _pickDate(
    DateTime initial,
    DocumentDraft Function(DocumentDraft draft, DateTime day) apply,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (picked == null || !mounted) return;
    _update(apply(_draft!, picked));
  }

  Future<void> _editLine(DocumentLookups lookups, DraftLine? line) async {
    final draft = _draft!;
    final type = draft.type;
    if (type == null) return;
    final result = await showDocumentLineSheet(
      context,
      lookups: lookups,
      type: type,
      warehouseId: draft.warehouseId,
      line: line,
    );
    if (result == null || !mounted) return;
    _update(_draft!.withLine(result));
  }

  // --- Saving ---------------------------------------------------------------

  Future<void> _submit() async {
    final draft = _draft!;
    final problem = draft.firstProblem(creating: !_editing);
    if (problem != null) {
      setState(() {
        _step = problem.$1;
        _problem = problem.$2;
      });
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
      _problem = null;
    });
    try {
      final saved = await DocumentSaver(ref.read(apiProvider)).save(
        draft,
        server: _server,
        onProgress: (current, server) {
          if (!mounted) return;
          setState(() {
            _draft = current;
            _server = server;
          });
        },
      );
      if (!mounted) return;
      ref.invalidate(documentItemsProvider(saved.id!));
      await ref.read(documentsProvider.notifier).load();
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      setState(() {
        _saving = false;
        _dirty = false;
      });
      // After the rebuild, so the page no longer asks to discard its changes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop(true);
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _editing
                ? 'Saved the changes to ${saved.number}.'
                : 'Created ${saved.number}.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted || e.isCancelled) return;
      setState(() {
        _saving = false;
        _saveError = !_editing && _server != null
            ? '${e.message} What was saved so far stays saved — press '
                  'Finish saving to send the rest.'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Could not save: $e';
      });
    }
  }

  Future<void> _confirmLeave() async {
    final discard = await showConfirmDialog(
      context,
      title: _editing ? 'Discard your changes?' : 'Discard this document?',
      message: _editing
          ? 'The document stays as it was last saved.'
          : _server != null
          ? 'What was already saved stays on the server. The rest is lost.'
          : 'Nothing has been saved yet.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lookups = ref.watch(documentLookupsProvider);
    final document = widget.document;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: palette.primaryText),
          title: Text(
            document == null ? 'New document' : 'Edit ${document.number}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.title(palette.primaryText).copyWith(fontSize: 19),
          ),
        ),
        body: lookups.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: error is ApiException
                ? error.message
                : 'Could not load the document editor. $error',
            onRetry: () => ref.invalidate(documentLookupsProvider),
          ),
          data: (lookups) => _content(context, lookups),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, DocumentLookups lookups) {
    if (_loadError != null) {
      return ErrorView(
        message: _loadError!,
        onRetry: () => _initialise(lookups),
      );
    }
    if (widget.document?.isPosDocument ?? false) {
      return const ErrorView(
        message:
            'This document was rung up on a register. Change it from the POS, '
            'which keeps its stock and payments in step.',
      );
    }
    final draft = _draft;
    if (draft == null) {
      if (!_initialising) {
        _initialising = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _initialise(lookups);
        });
      }
      return const LoadingView();
    }

    final pad = Layout.pagePadding(LayoutTier.watch(context));
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad.left, 4, pad.right, 12),
          child: PageBody(
            maxWidth: _formMaxWidth,
            child: _StepTrack(
              current: _step,
              reached: _reached,
              editing: _editing,
              onSelect: _goTo,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(_step),
            padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 24),
            child: PageBody(
              maxWidth: _formMaxWidth,
              child: switch (_step) {
                DocumentStep.type => _typeStep(lookups, draft),
                DocumentStep.details => _detailsStep(draft),
                DocumentStep.parties => _partiesStep(lookups, draft),
                DocumentStep.lines => _linesStep(lookups, draft),
                DocumentStep.review => _reviewStep(lookups, draft),
              },
            ),
          ),
        ),
        _footer(draft, pad),
      ],
    );
  }

  // --- Steps ----------------------------------------------------------------

  Widget _typeStep(DocumentLookups lookups, DocumentDraft draft) {
    final palette = context.palette;
    final locked = _editing && draft.hasSavedLines;
    final categories = <int, String>{
      for (final type in lookups.types) type.categoryId: type.categoryName,
    };
    final shown = [
      for (final type in lookups.types)
        if (_categoryFilter == null || type.categoryId == _categoryFilter) type,
    ];

    return IlyassFormSection(
      icon: Icons.category_outlined,
      title: 'What are you creating?',
      subtitle: locked
          ? 'Locked: its saved lines already moved stock as '
                '${draft.type?.name ?? 'this type'}.'
          : 'The type sets the number series and whether stock comes in, '
                'goes out, or stays put.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (categories.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  label: 'All',
                  selected: _categoryFilter == null,
                  onTap: () => setState(() => _categoryFilter = null),
                ),
                for (final entry in categories.entries)
                  _Chip(
                    label: entry.value,
                    selected: _categoryFilter == entry.key,
                    onTap: () => setState(() => _categoryFilter = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (shown.isEmpty)
            Text(
              'No document types to choose from yet.',
              style: AppText.body(palette.dim(0.6)),
            )
          else
            IlyassTileGrid(
              minTileWidth: 250,
              children: [
                for (final type in shown)
                  _TypeTile(
                    type: type,
                    selected: draft.type?.id == type.id,
                    onTap: locked ? null : () => _selectType(type, lookups),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _detailsStep(DocumentDraft draft) {
    final palette = context.palette;
    final typeName = draft.type?.name ?? 'document';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IlyassFormSection(
          icon: Icons.tag_rounded,
          title: 'Number and reference',
          subtitle: _editing
              ? null
              : 'Filled in from the $typeName series. Type your own to use '
                    'it instead.',
          child: IlyassFieldRow(
            flexes: const [3, 2],
            children: [
              TextField(
                controller: _number,
                style: AppText.body(palette.primaryText),
                decoration: InputDecoration(
                  labelText: 'Document number',
                  labelStyle: AppText.label(palette.dim(0.7)),
                  helperText: _numberNote,
                  helperMaxLines: 3,
                  helperStyle: AppText.caption(palette.warning),
                  suffixIcon: _editing || draft.type == null
                      ? null
                      : _fetchingNumber
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Use the next $typeName number',
                          onPressed: () => _fetchNumber(draft.type!),
                          icon: Icon(
                            Icons.autorenew_rounded,
                            color: palette.accent,
                          ),
                        ),
                ),
              ),
              TextField(
                controller: _reference,
                style: AppText.body(palette.primaryText),
                decoration: InputDecoration(
                  labelText: 'Reference',
                  hintText: 'Supplier invoice or delivery note',
                  labelStyle: AppText.label(palette.dim(0.7)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IlyassFormSection(
          icon: Icons.event_outlined,
          title: 'Dates',
          subtitle:
              'The stock date is when the goods moved. The stock history is '
              'ordered by it.',
          child: IlyassFieldRow(
            minFieldWidth: 180,
            children: [
              IlyassTapField(
                label: 'Document date',
                value: Fmt.date(draft.date),
                icon: Icons.calendar_today_rounded,
                onTap: () =>
                    _pickDate(draft.date, (d, day) => d.copyWith(date: day)),
              ),
              IlyassTapField(
                label: 'Stock date',
                value: Fmt.date(draft.stockDate),
                icon: Icons.inventory_2_outlined,
                onTap: () => _pickDate(
                  draft.stockDate,
                  // The day changes; the time it was entered at is kept, so
                  // documents on one day stay in the order they were made.
                  (d, day) => d.copyWith(
                    stockDate: DateTime(
                      day.year,
                      day.month,
                      day.day,
                      d.stockDate.hour,
                      d.stockDate.minute,
                    ),
                  ),
                ),
              ),
              IlyassTapField(
                label: 'Due date',
                value: Fmt.date(draft.dueDate),
                icon: Icons.event_available_outlined,
                onTap: () => _pickDate(
                  draft.dueDate,
                  (d, day) => d.copyWith(dueDate: day),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _partiesStep(DocumentLookups lookups, DocumentDraft draft) {
    final type = draft.type;
    final suppliers = type?.tradesWithSuppliers ?? false;
    final customers = [...lookups.customers]
      ..sort((a, b) {
        // The side of the trade this type deals with comes first.
        final rank = (suppliers ? (a.isSupplier ? 0 : 1) : (a.isCustomer ? 0 : 1))
            .compareTo(suppliers ? (b.isSupplier ? 0 : 1) : (b.isCustomer ? 0 : 1));
        return rank != 0
            ? rank
            : a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
    final warehouseLocked = _editing && draft.hasSavedLines;
    final showMissing = _problem != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IlyassFormSection(
          icon: Icons.people_alt_outlined,
          title: 'Who',
          subtitle: suppliers
              ? 'The supplier the goods come from or go back to, and who '
                    'handled it.'
              : 'The customer, and who handled it.',
          child: IlyassFieldRow(
            children: [
              IlyassDropdown<int>(
                label: suppliers ? 'Supplier' : 'Customer',
                searchable: customers.length > 8,
                value: draft.customerId,
                hasError: showMissing && draft.customerId == null,
                items: [
                  for (final c in customers)
                    IlyassDropdownItem(
                      value: c.id,
                      label: c.displayName,
                      caption: c.isSupplier && c.isCustomer
                          ? 'Customer and supplier'
                          : c.isSupplier
                          ? 'Supplier'
                          : null,
                    ),
                ],
                onChanged: (id) => _update(_draft!.copyWith(customerId: id)),
              ),
              IlyassDropdown<int>(
                label: 'Handled by',
                value: draft.userId,
                hasError: showMissing && draft.userId == null,
                helperText: _editing ? 'Set when the document was created.' : null,
                items: [
                  for (final u in lookups.users)
                    IlyassDropdownItem(
                      value: u.id,
                      label: u.displayName,
                      caption: u.roleName,
                    ),
                ],
                onChanged: _editing
                    ? null
                    : (id) => _update(_draft!.copyWith(userId: id)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IlyassFormSection(
          icon: Icons.warehouse_outlined,
          title: 'Where',
          subtitle: _movementSentence(type),
          child: IlyassDropdown<int>(
            label: 'Warehouse',
            value: draft.warehouseId,
            hasError: showMissing && draft.warehouseId == null,
            helperText: warehouseLocked
                ? 'Locked: its saved lines already moved stock in this '
                      'warehouse.'
                : null,
            items: [
              for (final w in lookups.warehouses)
                IlyassDropdownItem(value: w.id, label: w.name),
            ],
            onChanged: warehouseLocked
                ? null
                : (id) {
                    var next = _draft!.copyWith(warehouseId: id);
                    if (next.type?.isInventoryCount ?? false) {
                      next = _withExpected(next, lookups);
                    }
                    _update(next);
                  },
          ),
        ),
      ],
    );
  }

  static String _movementSentence(DocumentTypeOption? type) {
    if (type == null) return 'The warehouse whose stock this document moves.';
    if (type.isInventoryCount) {
      return 'What you count is compared with what this warehouse holds.';
    }
    return switch (type.stockDirection) {
      DocumentTypeOption.stockIn => 'The goods come into this warehouse.',
      DocumentTypeOption.stockOut => 'The goods leave this warehouse.',
      _ => 'This type moves no stock.',
    };
  }

  Widget _linesStep(DocumentLookups lookups, DocumentDraft draft) {
    final palette = context.palette;
    final counting = draft.type?.isInventoryCount ?? false;
    return IlyassFormSection(
      icon: Icons.format_list_bulleted_rounded,
      title: 'Lines',
      trailing: _CountPill(count: draft.lines.length),
      subtitle: counting
          ? 'Enter what you counted. Only the difference from stock on hand '
                'moves.'
          : 'The products this document moves, and their prices.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (draft.lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.playlist_add_rounded,
                    size: 36,
                    color: palette.dim(0.35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No lines yet. Add the products this document moves.',
                    textAlign: TextAlign.center,
                    style: AppText.body(palette.dim(0.6)),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < draft.lines.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  color: palette.primaryText.withValues(alpha: 0.08),
                ),
              _LineRow(
                line: draft.lines[i],
                counting: counting,
                onEdit: () => _editLine(lookups, draft.lines[i]),
                onRemove: () =>
                    _update(_draft!.withoutLine(draft.lines[i].key)),
              ),
            ],
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: () => _editLine(lookups, null),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add line'),
            ),
          ),
          if (draft.lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.primaryText.withValues(alpha: 0.1)),
            const SizedBox(height: 4),
            IlyassValueRow(
              label: 'Lines total',
              value: Fmt.currency(draft.subtotal),
              emphasis: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _reviewStep(DocumentLookups lookups, DocumentDraft draft) {
    final palette = context.palette;
    final type = draft.type;
    final suppliers = type?.tradesWithSuppliers ?? false;
    final fieldLabel = AppText.label(palette.dim(0.7));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IlyassFormSection(
          icon: Icons.fact_check_outlined,
          title: 'Check the document',
          subtitle: _editing ? null : 'Nothing is saved until you create it.',
          child: Column(
            children: [
              IlyassValueRow(label: 'Type', value: type?.label ?? '—'),
              IlyassValueRow(
                label: 'Number',
                value: draft.number.trim().isEmpty ? '—' : draft.number.trim(),
              ),
              IlyassValueRow(
                label: 'Document date',
                value: Fmt.date(draft.date),
              ),
              IlyassValueRow(
                label: 'Stock date',
                value: Fmt.date(draft.stockDate),
              ),
              IlyassValueRow(label: 'Due date', value: Fmt.date(draft.dueDate)),
              IlyassValueRow(
                label: suppliers ? 'Supplier' : 'Customer',
                value: lookups.customerById(draft.customerId)?.displayName ?? '—',
              ),
              IlyassValueRow(
                label: 'Handled by',
                value: lookups.userById(draft.userId)?.displayName ?? '—',
              ),
              IlyassValueRow(
                label: 'Warehouse',
                value: lookups.warehouseById(draft.warehouseId)?.name ?? '—',
              ),
              IlyassValueRow(label: 'Lines', value: '${draft.lines.length}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IlyassFormSection(
          icon: Icons.sell_outlined,
          title: 'Document discount',
          subtitle: _editing
              ? 'Taken off the lines total. Whether it is a percentage or an '
                    'amount is set when the document is created.'
              : 'Taken off the lines total.',
          child: IlyassFieldRow(
            minFieldWidth: 150,
            flexes: const [3, 2],
            children: [
              TextField(
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: AppText.body(palette.primaryText),
                decoration: InputDecoration(
                  labelText: 'Discount',
                  hintText: '0',
                  labelStyle: fieldLabel,
                ),
              ),
              IlyassSegmented<int>(
                segments: [
                  (DiscountKind.percent, '%'),
                  (DiscountKind.amount, AppConfig.currencySuffix),
                ],
                value: draft.discountType,
                onChanged: _editing
                    ? null
                    : (kind) => _update(_draft!.copyWith(discountType: kind)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IlyassFormSection(
          icon: Icons.notes_rounded,
          title: 'Notes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 4,
                style: AppText.body(palette.primaryText),
                decoration: InputDecoration(
                  labelText: 'Note',
                  hintText: 'Printed on the document',
                  labelStyle: fieldLabel,
                ),
              ),
              const SizedBox(height: kIlyassFieldGap),
              TextField(
                controller: _internalNote,
                minLines: 1,
                maxLines: 4,
                style: AppText.body(palette.primaryText),
                decoration: InputDecoration(
                  labelText: 'Internal note',
                  hintText: 'Only staff see this',
                  labelStyle: fieldLabel,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IlyassFormSection(
          icon: Icons.payments_outlined,
          title: 'Total',
          child: Column(
            children: [
              IlyassValueRow(
                label: 'Lines total',
                value: Fmt.currency(draft.subtotal),
              ),
              IlyassValueRow(
                label: 'Discount',
                value: draft.discountAmount == 0
                    ? Fmt.currency(0)
                    : '−${Fmt.currency(draft.discountAmount)}',
              ),
              Divider(
                height: 16,
                color: palette.primaryText.withValues(alpha: 0.1),
              ),
              IlyassValueRow(
                label: 'Total',
                value: Fmt.currency(draft.total),
                emphasis: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Footer -----------------------------------------------------------------

  Widget _footer(DocumentDraft draft, EdgeInsets pad) {
    final palette = context.palette;
    final message = _saveError ?? _problem;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.base,
        border: Border(
          top: BorderSide(color: palette.primaryText.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad.left, 12, pad.right, 12),
          child: PageBody(
            maxWidth: _formMaxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (message != null) ...[
                  _Notice(message: message, isError: _saveError != null),
                  const SizedBox(height: 10),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 560;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _leadingButton() ?? const SizedBox.shrink(),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (wide && draft.lines.isNotEmpty) ...[
                                Flexible(
                                  child: Text(
                                    'Total ${Fmt.currency(draft.total)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.bodyStrong(
                                      palette.primaryText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                              ],
                              _primaryButton(draft, wide: wide),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _leadingButton() {
    final palette = context.palette;
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 50),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      foregroundColor: palette.primaryText,
      side: BorderSide(color: palette.primaryText.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      ),
    );
    if (_editing) {
      return OutlinedButton(
        onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
        style: style,
        child: const Text('Cancel'),
      );
    }
    if (_step.isFirst) return null;
    return OutlinedButton.icon(
      onPressed: _saving ? null : () => _goTo(_step.previous),
      style: style,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text('Back'),
    );
  }

  Widget _primaryButton(DocumentDraft draft, {required bool wide}) {
    final palette = context.palette;
    final style = FilledButton.styleFrom(
      minimumSize: const Size(0, 50),
      padding: const EdgeInsets.symmetric(horizontal: 22),
    );
    final spinner = SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        color: AppTheme.onAccent(palette.accent),
      ),
    );

    if (_editing) {
      return FilledButton(
        onPressed: _saving || !_dirty ? null : _submit,
        style: style,
        child: _saving ? spinner : const Text('Save changes'),
      );
    }
    if (!_step.isLast) {
      return FilledButton(
        onPressed: _saving ? null : _next,
        style: style,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(wide ? 'Next: ${_step.next.title}' : 'Next'),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      );
    }
    return FilledButton(
      onPressed: _saving ? null : _submit,
      style: style,
      child: _saving
          ? spinner
          : Text(draft.isCreated ? 'Finish saving' : 'Create document'),
    );
  }
}

/// Where the operator is in the five steps.
///
/// Wide: every step in a row, joined by a line that fills in as they are
/// reached. Narrow and creating: "Step 2 of 5" with a progress bar — five
/// labelled circles do not fit a phone. Narrow and editing: the steps as a
/// row of tabs, because every one of them is open.
class _StepTrack extends StatelessWidget {
  const _StepTrack({
    required this.current,
    required this.reached,
    required this.editing,
    required this.onSelect,
  });

  final DocumentStep current;
  final int reached;
  final bool editing;
  final ValueChanged<DocumentStep> onSelect;

  bool _open(DocumentStep step) => editing || step.index <= reached;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 640) {
          return Row(
            children: [
              for (final step in DocumentStep.values) ...[
                if (!step.isFirst)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _open(step)
                            ? palette.accent.withValues(alpha: 0.55)
                            : palette.primaryText.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                _StepButton(
                  step: step,
                  isCurrent: step == current,
                  done: !editing && step != current && step.index < reached,
                  enabled: _open(step),
                  onTap: () => onSelect(step),
                ),
              ],
            ],
          );
        }

        if (editing) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final step in DocumentStep.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: _Chip(
                      label: step.title,
                      selected: step == current,
                      onTap: () => onSelect(step),
                    ),
                  ),
              ],
            ),
          );
        }

        final number = current.index + 1;
        final total = DocumentStep.values.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _StepCircle(number: number, isCurrent: true, done: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Step $number of $total',
                        style: AppText.caption(palette.dim(0.65)),
                      ),
                      Text(
                        current.title,
                        style: AppText.headline(palette.primaryText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: number / total,
                minHeight: 6,
                color: palette.accent,
                backgroundColor: palette.primaryText.withValues(alpha: 0.1),
                semanticsLabel: 'Step $number of $total',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.step,
    required this.isCurrent,
    required this.done,
    required this.enabled,
    required this.onTap,
  });

  final DocumentStep step;
  final bool isCurrent;
  final bool done;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colour = isCurrent
        ? palette.accent
        : enabled
        ? palette.primaryText
        : palette.dim(0.4);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: isCurrent,
      label: 'Step ${step.index + 1}, ${step.title}${done ? ', done' : ''}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled && !isCurrent ? onTap : null,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepCircle(
                    number: step.index + 1,
                    isCurrent: isCurrent,
                    done: done,
                    enabled: enabled,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    step.title,
                    style: AppText.style(
                      size: 14,
                      weight: isCurrent ? 800 : 600,
                      color: colour,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.number,
    required this.isCurrent,
    required this.done,
    this.enabled = true,
  });

  final int number;
  final bool isCurrent;
  final bool done;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? palette.accent
            : isCurrent
            ? palette.accent.withValues(alpha: 0.15)
            : null,
        border: Border.all(
          color: done || isCurrent
              ? palette.accent
              : palette.primaryText.withValues(alpha: enabled ? 0.3 : 0.15),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: done
          ? Icon(
              Icons.check_rounded,
              size: 18,
              color: AppTheme.onAccent(palette.accent),
            )
          : Text(
              '$number',
              style: AppText.style(
                size: 13,
                weight: 800,
                color: isCurrent
                    ? palette.accent
                    : palette.dim(enabled ? 0.75 : 0.4),
              ),
            ),
    );
  }
}

/// One document type to pick: its series code set large, its name, and what
/// it does to stock — the consequence of the choice the name does not spell
/// out.
class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final DocumentTypeOption type;
  final bool selected;

  /// Null when the type is locked.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (IconData icon, Color colour, String movement) = type.isInventoryCount
        ? (Icons.fact_check_outlined, palette.accent, 'Corrects stock to the count')
        : switch (type.stockDirection) {
            DocumentTypeOption.stockIn => (
              Icons.move_to_inbox_outlined,
              palette.positive,
              'Adds stock',
            ),
            DocumentTypeOption.stockOut => (
              Icons.outbox_outlined,
              palette.warning,
              'Removes stock',
            ),
            _ => (Icons.remove_rounded, palette.neutral, 'No stock movement'),
          };
    final enabled = onTap != null;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${type.code} ${type.name}, $movement',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || selected ? 1 : 0.5,
        child: Material(
          color: selected
              ? palette.accent.withValues(alpha: 0.12)
              : palette.primaryText.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected
                  ? palette.accent
                  : palette.primaryText.withValues(alpha: 0.12),
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 84),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        constraints: const BoxConstraints(minWidth: 62),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? palette.accent
                              : palette.primaryText.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          type.code.isEmpty ? '—' : type.code,
                          maxLines: 1,
                          style: AppText.style(
                            size: 20,
                            weight: 800,
                            color: selected
                                ? AppTheme.onAccent(palette.accent)
                                : palette.primaryText,
                          ).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodyStrong(
                                palette.primaryText,
                              ).weighted(700),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(icon, size: 16, color: colour),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    movement,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption(
                                      palette.dim(0.7),
                                    ).copyWith(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle_rounded,
                          size: 22,
                          color: palette.accent,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.counting,
    required this.onEdit,
    required this.onRemove,
  });

  final DraftLine line;
  final bool counting;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final money = line.money;
    final expected = line.expectedQuantity;
    final detail = counting
        ? 'Counted ${line.quantityLabel}'
              '${expected == null ? '' : ', in stock ${formatUomQuantity(expected, uomById(line.uomId))}'}'
        : '${line.quantityLabel} × ${Fmt.currency(money.unitPrice)}';
    final extras = [
      if (line.tax != null) line.tax!.label,
      if (line.discount > 0)
        line.discountType == DiscountKind.percent
            ? '${Fmt.quantity(line.discount)}% off'
            : '${Fmt.currency(line.discount)} off each',
    ];
    final amount = Text(
      Fmt.currency(line.total),
      style: AppText.bodyStrong(palette.primaryText).weighted(700),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 440;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      line.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong(palette.primaryText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: AppText.caption(palette.dim(0.7)).copyWith(
                        fontSize: 13,
                      ),
                    ),
                    if (extras.isNotEmpty)
                      Text(
                        extras.join(', '),
                        style: AppText.caption(palette.dim(0.55)),
                      ),
                    if (narrow) ...[const SizedBox(height: 4), amount],
                  ],
                ),
              ),
              if (!narrow) ...[const SizedBox(width: 12), amount],
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Edit line',
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: palette.dim(0.75)),
              ),
              IconButton(
                tooltip: 'Remove line',
                onPressed: onRemove,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: palette.negative,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count', style: AppText.label(palette.accent)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: AppText.style(
        size: 14,
        weight: 700,
        color: selected ? AppTheme.onAccent(palette.accent) : palette.primaryText,
      ),
      selectedColor: palette.accent,
      backgroundColor: palette.primaryText.withValues(alpha: 0.06),
      side: BorderSide(
        color: selected
            ? palette.accent
            : palette.primaryText.withValues(alpha: 0.14),
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// What the footer has to say: what a step still needs, or why a save failed.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colour = isError ? palette.negative : palette.warning;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.controlRadius),
          border: Border.all(color: colour.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 20,
              color: colour,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: AppText.body(palette.primaryText)),
            ),
          ],
        ),
      ),
    );
  }
}
