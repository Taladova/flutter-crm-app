import 'package:flutter_test/flutter_test.dart';

import 'package:clientflow_pro/data/models/client_note_model.dart';

void main() {
  test('ClientNoteModel preserves independent note data', () {
    final createdAt = DateTime(2026, 8, 28, 10, 30);
    final updatedAt = DateTime(2026, 8, 28, 11, 45);

    final note = ClientNoteModel(
      id: 'note_1',
      clientId: 'client_1',
      content: 'Prévoir une relance lundi.',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    expect(note.toJson(), {
      'id': 'note_1',
      'clientId': 'client_1',
      'content': 'Prévoir une relance lundi.',
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    });
  });

  test('ClientNoteModel copyWith edits only the selected note content', () {
    final note = ClientNoteModel(
      id: 'note_1',
      clientId: 'client_1',
      content: 'Ancienne note',
    );

    final updated = note.copyWith(content: 'Nouvelle note');

    expect(updated.id, 'note_1');
    expect(updated.clientId, 'client_1');
    expect(updated.content, 'Nouvelle note');
  });
}
