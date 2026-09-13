import 'package:clientflow_pro/data/templates/project_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('projectTemplates', () {
    test('website template contains expected preparation data', () {
      final website = projectTemplates.firstWhere(
        (template) => template.id == 'website',
      );

      expect(website.name, 'Site internet');
      expect(website.timeline.length, 7);
      expect(website.documentRequests.length, 5);
      expect(website.clientActions.length, 3);
      expect(website.tasks, isNotEmpty);
      expect(website.timeline.first.status, 'current');
    });

    test('custom template keeps current manual behavior', () {
      final custom = projectTemplates.firstWhere(
        (template) => template.id == 'custom',
      );

      expect(custom.isCustom, isTrue);
      expect(custom.timeline, isEmpty);
      expect(custom.tasks, isEmpty);
      expect(custom.clientActions, isEmpty);
      expect(custom.documentRequests, isEmpty);
    });
  });
}
