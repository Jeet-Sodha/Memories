import 'draft_media.dart';
import 'memory_media.dart';

/// One item in the "edit memory" media list: either something that is
/// already saved, or a new file the user just added. The list order is the
/// story order.
class EditMediaEntry {
  final MemoryMedia? saved;
  final DraftMedia? draft;

  const EditMediaEntry.fromSaved(MemoryMedia this.saved) : draft = null;
  const EditMediaEntry.fromDraft(DraftMedia this.draft) : saved = null;

  bool get isNew => draft != null;
  String get id => saved?.id ?? draft!.id;
  String get kind => saved?.mediaType ?? draft!.kind;
}
