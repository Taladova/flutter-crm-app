import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';

Future<String?> showClientDeliverableReviewSheet({
  required BuildContext context,
  required bool approved,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppTheme.cardColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _ClientDeliverableReviewSheet(approved: approved),
  );
}

class _ClientDeliverableReviewSheet extends StatefulWidget {
  const _ClientDeliverableReviewSheet({required this.approved});

  final bool approved;

  @override
  State<_ClientDeliverableReviewSheet> createState() =>
      _ClientDeliverableReviewSheetState();
}

class _ClientDeliverableReviewSheetState
    extends State<_ClientDeliverableReviewSheet> {
  late final TextEditingController _commentController;
  late final FocusNode _commentFocusNode;
  bool _showCommentError = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _commentFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _commentFocusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.approved
                  ? 'Valider cet élément'
                  : 'Demander une modification',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              widget.approved
                  ? 'Cette version sera marquée comme validée.'
                  : 'Ajoutez un commentaire pour expliquer les changements attendus.',
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            if (!widget.approved) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Commentaire obligatoire',
                  hintText: 'Ex : ajuster les couleurs, revoir le texte...',
                  errorText: _showCommentError
                      ? 'Ajoutez un commentaire avant d’envoyer.'
                      : null,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: Icon(
                  widget.approved
                      ? Icons.check_circle_rounded
                      : Icons.edit_note_rounded,
                ),
                label: Text(widget.approved ? 'Valider' : 'Envoyer la demande'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_submitted) return;
    final comment = _commentController.text.trim();
    if (!widget.approved && comment.isEmpty) {
      if (!mounted) return;
      setState(() => _showCommentError = true);
      _commentFocusNode.requestFocus();
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    _submitted = true;
    Navigator.of(context).pop(widget.approved ? '' : comment);
  }
}
