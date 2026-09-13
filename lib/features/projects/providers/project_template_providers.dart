import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/firestore_providers.dart';
import '../../../data/services/project_template_service.dart';
import '../../auth/providers/auth_providers.dart';

final projectTemplateServiceProvider = Provider<ProjectTemplateService>((ref) {
  return ProjectTemplateService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});
