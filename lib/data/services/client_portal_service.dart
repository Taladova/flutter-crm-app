import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_notification_model.dart';
import '../models/client_account_model.dart';
import '../models/client_action_model.dart';
import '../models/client_document_model.dart';
import '../models/client_invitation_model.dart';
import '../models/client_message_model.dart';
import '../models/client_model.dart';
import '../models/deliverable_annotation_model.dart';
import '../models/deliverable_model.dart';
import '../models/deliverable_version_model.dart';
import '../models/document_request_model.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/timeline_event_model.dart';

class ClientPortalService {
  ClientPortalService({
    required this.firestore,
    required this.auth,
    required this.storage,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseStorage storage;

  CollectionReference<Map<String, dynamic>> get _invitations =>
      firestore.collection('client_invitations');

  CollectionReference<Map<String, dynamic>> get _accounts =>
      firestore.collection('client_accounts');

  CollectionReference<Map<String, dynamic>> get _sharedClients =>
      firestore.collection('shared_clients');

  CollectionReference<Map<String, dynamic>> get _sharedProjects =>
      firestore.collection('shared_projects');

  Future<String> createInvitation({
    required String professionalId,
    required ClientModel client,
    required List<ProjectModel> projects,
  }) async {
    final token = _generateToken();
    final projectIds = projects.map((project) => project.id).toList();

    final data = {
      'token': token,
      'professionalId': professionalId,
      'ownerUid': professionalId,
      'clientId': client.id,
      'clientName': client.name,
      'clientEmail': client.email,
      'projectIds': projectIds,
      'status': 'active',
      'clientUid': '',
      'createdAt': FieldValue.serverTimestamp(),
      'claimedAt': null,
    };

    try {
      await _invitations.doc(token).set(data);
    } catch (_) {
      await _sharedClients.doc(token).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    for (final project in projects) {
      await _sharedProjects
          .doc('${token}_${project.id}')
          .set(
            _publicProjectData(
              professionalId: professionalId,
              project: project,
              clientId: client.id,
            ),
            SetOptions(merge: true),
          );
    }

    return token;
  }

  Future<void> revokeInvitation(String token) async {
    final normalizedToken = token.trim().toUpperCase();
    if (normalizedToken.isEmpty) return;

    await Future.wait([
      _invitations.doc(normalizedToken).delete().catchError((_) {}),
      _sharedClients.doc(normalizedToken).delete().catchError((_) {}),
    ]);
  }

  Future<ClientInvitationModel?> fetchInvitation(String token) async {
    final normalizedToken = token.trim().toUpperCase();
    if (normalizedToken.isEmpty) return null;

    try {
      final doc = await _invitations.doc(normalizedToken).get();
      if (doc.exists && doc.data() != null) {
        return ClientInvitationModel.fromJson(doc.data()!);
      }
    } catch (_) {
      // New invitation rules may not be deployed yet. Fall back to the
      // legacy shared client collection used by the current app.
    }

    final legacyDoc = await _sharedClients.doc(normalizedToken).get();
    if (!legacyDoc.exists || legacyDoc.data() == null) {
      final projectDoc = await _sharedProjects.doc(normalizedToken).get();
      if (!projectDoc.exists || projectDoc.data() == null) return null;

      final projectData = projectDoc.data()!;
      final projectId = projectData['projectId'] as String? ?? '';
      final clientUid = projectData['clientUid'] as String? ?? '';

      return ClientInvitationModel.fromJson({
        'token': normalizedToken,
        'professionalId':
            projectData['professionalId'] ?? projectData['ownerUid'] ?? '',
        'clientId': projectData['clientId'] ?? projectData['clientName'] ?? '',
        'clientName': projectData['clientName'] ?? '',
        'clientEmail': projectData['clientEmail'] ?? '',
        'projectIds': projectId.isEmpty
            ? const <String>[]
            : <String>[projectId],
        'status': clientUid.isEmpty ? 'active' : 'claimed',
        'clientUid': clientUid,
        'createdAt': projectData['createdAt'] ?? projectData['updatedAt'],
        'claimedAt': projectData['claimedAt'],
      });
    }

    final data = legacyDoc.data()!;
    return ClientInvitationModel.fromJson({
      'token': normalizedToken,
      'professionalId': data['professionalId'] ?? data['ownerUid'] ?? '',
      'clientId': data['clientId'] ?? '',
      'clientName': data['clientName'] ?? '',
      'clientEmail': data['clientEmail'] ?? '',
      'projectIds': data['projectIds'] ?? const <String>[],
      'status': data['status'] ?? 'active',
      'clientUid': data['clientUid'] ?? '',
      'createdAt': data['createdAt'] ?? data['updatedAt'],
      'claimedAt': data['claimedAt'],
    });
  }

  Future<ClientAccountModel> registerFromInvitation({
    required String token,
    required String name,
    required String email,
    required String password,
  }) async {
    final invitation = await fetchInvitation(token);
    if (invitation == null || !invitation.isActive) {
      throw StateError('Invitation invalide ou expirée.');
    }

    if (invitation.clientEmail.isNotEmpty &&
        invitation.clientEmail.toLowerCase() != email.toLowerCase()) {
      throw StateError('Cet email ne correspond pas à l’invitation.');
    }

    UserCredential credential;
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') rethrow;

      credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final existingUserDoc = await firestore
          .collection('users')
          .doc(credential.user?.uid)
          .get();
      final existingRole = existingUserDoc.data()?['role'];
      if (existingRole != null && existingRole != 'client') {
        throw StateError(
          'Cette adresse email est déjà utilisée par un compte professionnel.',
        );
      }
    }
    final user = credential.user;
    if (user == null) {
      throw StateError('Compte client introuvable après création.');
    }

    await user.updateDisplayName(name);

    // Best-effort: if the professional already published a shared_clients
    // space for this client before they claimed their invite, capture its
    // id right away so this account never has to re-derive it later.
    final existingSharedClientId = await _findSharedClientIdFor(
      professionalId: invitation.professionalId,
      clientId: invitation.clientId,
      clientEmail: email,
    );

    final account = ClientAccountModel(
      uid: user.uid,
      clientId: invitation.clientId,
      professionalId: invitation.professionalId,
      email: email,
      displayName: name,
      projectIds: invitation.projectIds,
      sharedClientId: existingSharedClientId,
    );

    final userRef = firestore.collection('users').doc(user.uid);

    await userRef.set({
      'name': name,
      'email': email,
      'role': 'client',
      'clientId': invitation.clientId,
      'professionalId': invitation.professionalId,
      'projectIds': invitation.projectIds,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final accountRef = _accounts.doc(user.uid);

    await accountRef.set({
      ...account.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    });

    final projectsBatch = firestore.batch();
    for (final projectId in invitation.projectIds) {
      projectsBatch.set(accountRef.collection('projects').doc(projectId), {
        'id': projectId,
        'projectId': projectId,
        'professionalId': invitation.professionalId,
        'clientId': invitation.clientId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await projectsBatch.commit();

    for (final projectId in invitation.projectIds) {
      final projectData = await _publicProjectSnapshot(
        professionalId: invitation.professionalId,
        projectId: projectId,
        clientId: invitation.clientId,
      );
      await accountRef
          .collection('projects')
          .doc(projectId)
          .set(projectData, SetOptions(merge: true));
    }

    await _backfillSharedMessagesToClientAccount(
      accountRef: accountRef,
      token: invitation.token,
    );

    try {
      final invitationRef = _invitations.doc(invitation.token);
      await invitationRef.update({
        'status': 'claimed',
        'clientUid': user.uid,
        'claimedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await _sharedClients.doc(invitation.token).set({
        'status': 'claimed',
        'clientUid': user.uid,
        'claimedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return account;
  }

  Future<ClientAccountModel?> currentClientAccount({
    bool debugLog = true,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return null;

    if (debugLog) {
      // TEMP DIAGNOSTIC LOG — see clientflow_pro professional/client link audit.
      // ignore: avoid_print
      print(
        '[account] currentAuthUid=$uid role=client path=client_accounts/$uid',
      );
    }

    try {
      final doc = await _accounts
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));
      if (doc.exists && doc.data() != null) {
        final account = ClientAccountModel.fromJson(doc.data()!);
        if (account.projectIds.isNotEmpty) {
          if (debugLog) {
            // ignore: avoid_print
            print(
              '[account] resolved uid=${account.uid} clientId=${account.clientId} '
              'professionalId=${account.professionalId} '
              'displayName=${account.displayName} role=${account.role}',
            );
          }
          return account;
        }

        final repairedAccount = await _accountFromClaimedInvitation(uid);
        if (repairedAccount != null) return repairedAccount;

        return account;
      }
    } catch (_) {
      // Fall back to user document for accounts created before the dedicated
      // client_accounts rules are deployed.
    }

    final claimedAccount = await _accountFromClaimedInvitation(uid);
    if (claimedAccount != null) return claimedAccount;

    final userDoc = await firestore
        .collection('users')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 10));
    final data = userDoc.data();
    if (data == null || data['role'] != 'client') return null;

    final account = ClientAccountModel.fromJson({
      'uid': uid,
      'clientId': data['clientId'] ?? '',
      'professionalId': data['professionalId'] ?? '',
      'email': data['email'] ?? auth.currentUser?.email ?? '',
      'displayName': data['name'] ?? auth.currentUser?.displayName ?? '',
      'role': 'client',
      'projectIds': data['projectIds'] ?? const <String>[],
      'createdAt': data['createdAt'],
      'lastLoginAt': data['lastLoginAt'],
    });

    if (debugLog) {
      // ignore: avoid_print
      print(
        '[account] resolved (legacy users/ fallback) uid=${account.uid} '
        'clientId=${account.clientId} professionalId=${account.professionalId} '
        'displayName=${account.displayName} role=${account.role}',
      );
    }

    await _repairClientAccount(account);
    return account;
  }

  /// Lets the client know which professional they're linked to: reads the
  /// display name off `users/{professionalId}` (the same field the
  /// professional sets from their own Réglages page).
  Future<String?> fetchProfessionalName(String professionalId) async {
    if (professionalId.isEmpty) return null;

    try {
      final doc = await firestore
          .collection('users')
          .doc(professionalId)
          .get()
          .timeout(const Duration(seconds: 10));
      final name = doc.data()?['name'] as String?;
      return (name == null || name.trim().isEmpty) ? null : name.trim();
    } catch (_) {
      return null;
    }
  }

  Future<ClientAccountModel?> _accountFromClaimedInvitation(String uid) async {
    ClientInvitationModel? invitation;

    try {
      final invitationSnapshot = await _invitations
          .where('clientUid', isEqualTo: uid)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));
      if (invitationSnapshot.docs.isNotEmpty) {
        invitation = ClientInvitationModel.fromJson(
          invitationSnapshot.docs.first.data(),
        );
      }
    } catch (_) {
      invitation = null;
    }

    try {
      invitation ??= await _legacyInvitationForCurrentUser(uid);
    } catch (_) {
      invitation = null;
    }

    final email = auth.currentUser?.email ?? '';
    if (invitation == null && email.isNotEmpty) {
      invitation = await _invitationByClientEmail(email);
    }

    if (invitation == null) return null;

    final account = ClientAccountModel(
      uid: uid,
      clientId: invitation.clientId,
      professionalId: invitation.professionalId,
      email: email.isNotEmpty ? email : invitation.clientEmail,
      displayName: auth.currentUser?.displayName?.trim().isNotEmpty == true
          ? auth.currentUser!.displayName!
          : invitation.clientName,
      projectIds: invitation.projectIds,
    );

    await firestore.collection('users').doc(uid).set({
      'name': account.displayName,
      'email': account.email,
      'role': 'client',
      'clientId': account.clientId,
      'professionalId': account.professionalId,
      'projectIds': account.projectIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _repairClientAccount(account);
    return account;
  }

  Future<ClientInvitationModel?> _legacyInvitationForCurrentUser(
    String uid,
  ) async {
    final snapshot = await _sharedClients
        .where('clientUid', isEqualTo: uid)
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 6));
    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return ClientInvitationModel.fromJson({
      'token': snapshot.docs.first.id,
      'professionalId': data['professionalId'] ?? data['ownerUid'] ?? '',
      'clientId': data['clientId'] ?? '',
      'clientName': data['clientName'] ?? '',
      'clientEmail': data['clientEmail'] ?? '',
      'projectIds': data['projectIds'] ?? const <String>[],
      'status': data['status'] ?? 'claimed',
      'clientUid': data['clientUid'] ?? uid,
      'createdAt': data['createdAt'] ?? data['updatedAt'],
      'claimedAt': data['claimedAt'],
    });
  }

  Future<ClientInvitationModel?> _invitationByClientEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    final invitation = await _invitationByEmailFrom(_invitations, email);
    if (invitation != null) return invitation;

    final legacy = await _invitationByEmailFrom(_sharedClients, email);
    if (legacy != null) return legacy;

    return _invitationByEmailFrom(_sharedClients, normalizedEmail);
  }

  Future<ClientInvitationModel?> _invitationByEmailFrom(
    CollectionReference<Map<String, dynamic>> collection,
    String email,
  ) async {
    try {
      final snapshot = await collection
          .where('clientEmail', isEqualTo: email)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));
      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      return ClientInvitationModel.fromJson({
        'token': data['token'] ?? snapshot.docs.first.id,
        'professionalId': data['professionalId'] ?? data['ownerUid'] ?? '',
        'clientId': data['clientId'] ?? '',
        'clientName': data['clientName'] ?? '',
        'clientEmail': data['clientEmail'] ?? '',
        'projectIds': data['projectIds'] ?? const <String>[],
        'status': data['status'] ?? 'claimed',
        'clientUid': data['clientUid'] ?? auth.currentUser?.uid ?? '',
        'createdAt': data['createdAt'] ?? data['updatedAt'],
        'claimedAt': data['claimedAt'],
      });
    } catch (_) {
      return null;
    }
  }

  Future<List<ProjectModel>> currentClientProjects() async {
    final account = await currentClientAccount();
    if (account == null || account.projectIds.isEmpty) return [];

    final projects = <ProjectModel>[];
    for (final projectId in account.projectIds) {
      try {
        final doc = await _accounts
            .doc(account.uid)
            .collection('projects')
            .doc(projectId)
            .get()
            .timeout(const Duration(seconds: 6));
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final project = ProjectModel.fromJson({
            ...data,
            'id': data['id'] ?? projectId,
          });
          if (project.title.trim().isNotEmpty) {
            projects.add(project);
            continue;
          }
        }
      } catch (_) {
        // Fall back to the public tracking snapshot below.
      }

      final sharedProject = await _projectFromSharedSnapshot(
        projectId,
      ).timeout(const Duration(seconds: 6), onTimeout: () => null);
      if (sharedProject != null) {
        projects.add(sharedProject);
      }
    }

    return projects;
  }

  Stream<List<ProjectModel>> currentClientProjectsStream() async* {
    final uid = auth.currentUser?.uid;
    final account = await currentClientAccount();
    if (account == null) {
      // ignore: avoid_print
      print(
        '[client-projects]\n'
        'currentAuthUid=${uid ?? ''}\n'
        'clientId=\n'
        'professionalId=\n'
        'sharedClientId=\n'
        'projectIds=[]\n'
        'queryPath=client_accounts/${uid ?? '(no-auth)'}/projects\n'
        'projectsFound=0',
      );
      yield const <ProjectModel>[];
      return;
    }

    yield* clientProjectsStreamForAccount(account, currentAuthUid: uid);
  }

  Stream<List<ProjectModel>> clientProjectsStreamForAccount(
    ClientAccountModel account, {
    String? currentAuthUid,
  }) async* {
    final uid = currentAuthUid ?? auth.currentUser?.uid;
    final sharedClientId = await _ensureProfessionalClientSpace(
      account,
      logAsChat: false,
    );
    final sharedClientData = await _sharedClientData(sharedClientId);
    final sharedProjectIds =
        (sharedClientData?['projectIds'] as List?)?.cast<String>() ??
        const <String>[];
    final projectIds = <String>{
      ...account.projectIds,
      ...sharedProjectIds,
    }.where((projectId) => projectId.trim().isNotEmpty).toList();

    if (projectIds.isEmpty) {
      yield* _projectsByClientMatchStream(
        account: account,
        sharedClientId: sharedClientId,
        sharedClientData: sharedClientData,
        uid: uid,
      );
      return;
    }

    final queryPath =
        'users/${account.professionalId}/projects where documentId in ${projectIds.take(30).toList()}';

    yield* firestore
        .collection('users')
        .doc(account.professionalId)
        .collection('projects')
        .where(FieldPath.documentId, whereIn: projectIds.take(30).toList())
        .snapshots()
        .asyncMap((snapshot) async {
          final projects = <ProjectModel>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final project = ProjectModel.fromJson({
              ...data,
              'id': data['id'] ?? doc.id,
            });
            if (_projectBelongsToClient(project, account, projectIds)) {
              _logClientHomeProjectMatch(project, account);
              projects.add(project);
            }
          }
          projects.sort((a, b) => a.title.compareTo(b.title));
          // ignore: avoid_print
          print(
            '[client-projects]\n'
            'currentAuthUid=${uid ?? account.uid}\n'
            'clientId=${account.clientId}\n'
            'professionalId=${account.professionalId}\n'
            'sharedClientId=$sharedClientId\n'
            'projectIds=$projectIds\n'
            'queryPath=$queryPath\n'
            'projectsFound=${projects.length}',
          );
          return projects;
        });
  }

  Future<Map<String, dynamic>?> _sharedClientData(String sharedClientId) async {
    if (sharedClientId.isEmpty) return null;

    try {
      final doc = await _sharedClients
          .doc(sharedClientId)
          .get()
          .timeout(const Duration(seconds: 6));
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Stream<List<ProjectModel>> _projectsByClientMatchStream({
    required ClientAccountModel account,
    required String sharedClientId,
    required Map<String, dynamic>? sharedClientData,
    required String? uid,
  }) {
    final queryPath =
        'users/${account.professionalId}/projects client match by clientId/clientName';

    if (account.clientId.trim().isEmpty) {
      // ignore: avoid_print
      print(
        '[client-projects]\n'
        'currentAuthUid=${uid ?? account.uid}\n'
        'clientId=${account.clientId}\n'
        'professionalId=${account.professionalId}\n'
        'sharedClientId=$sharedClientId\n'
        'projectIds=[]\n'
        'queryPath=$queryPath\n'
        'projectsFound=0',
      );
      return Stream.value(const <ProjectModel>[]);
    }

    return firestore
        .collection('users')
        .doc(account.professionalId)
        .collection('projects')
        .snapshots()
        .map((snapshot) {
          final projects =
              snapshot.docs
                  .map(
                    (doc) => ProjectModel.fromJson({
                      ...doc.data(),
                      'id': doc.data()['id'] ?? doc.id,
                    }),
                  )
                  .where(
                    (project) => _projectMatchesClientAccount(
                      project: project,
                      account: account,
                      sharedClientData: sharedClientData,
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.title.compareTo(b.title));

          for (final project in projects) {
            _logClientHomeProjectMatch(project, account);
          }

          // ignore: avoid_print
          print(
            '[client-projects]\n'
            'currentAuthUid=${uid ?? account.uid}\n'
            'clientId=${account.clientId}\n'
            'professionalId=${account.professionalId}\n'
            'sharedClientId=$sharedClientId\n'
            'projectIds=[]\n'
            'queryPath=$queryPath\n'
            'projectsFound=${projects.length}',
          );
          return projects;
        });
  }

  bool _projectBelongsToClient(
    ProjectModel project,
    ClientAccountModel account,
    List<String> projectIds,
  ) {
    if (!projectIds.contains(project.id)) return false;
    if (project.clientId.isEmpty) return true;
    return project.clientId == account.clientId;
  }

  bool _projectMatchesClientAccount({
    required ProjectModel project,
    required ClientAccountModel account,
    required Map<String, dynamic>? sharedClientData,
  }) {
    final projectClientId = project.clientId.trim().toLowerCase();
    final accountClientId = account.clientId.trim().toLowerCase();
    if (projectClientId.isNotEmpty && projectClientId == accountClientId) {
      return true;
    }

    final projectClientName = project.clientName.trim().toLowerCase();
    final accountName = account.displayName.trim().toLowerCase();
    final sharedClientName = '${sharedClientData?['clientName'] ?? ''}'
        .trim()
        .toLowerCase();
    final sharedClientEmail = '${sharedClientData?['clientEmail'] ?? ''}'
        .trim()
        .toLowerCase();
    final accountEmail = account.email.trim().toLowerCase();

    return projectClientName.isNotEmpty &&
        (projectClientName == accountName ||
            projectClientName == sharedClientName ||
            projectClientName == sharedClientEmail ||
            projectClientName == accountEmail);
  }

  Future<List<String>> _accessibleProjectIdsForAccount(
    ClientAccountModel account,
  ) async {
    final sharedClientId = await _ensureProfessionalClientSpace(
      account,
      logAsChat: false,
    );
    final sharedClientData = await _sharedClientData(sharedClientId);
    final sharedProjectIds =
        (sharedClientData?['projectIds'] as List?)?.cast<String>() ??
        const <String>[];
    final projectIds = <String>{
      ...account.projectIds,
      ...sharedProjectIds,
    }.where((projectId) => projectId.trim().isNotEmpty).toList();

    if (projectIds.isNotEmpty) return projectIds;

    final snapshot = await firestore
        .collection('users')
        .doc(account.professionalId)
        .collection('projects')
        .get();

    final matchedIds = snapshot.docs
        .map(
          (doc) => ProjectModel.fromJson({
            ...doc.data(),
            'id': doc.data()['id'] ?? doc.id,
          }),
        )
        .where(
          (project) => _projectMatchesClientAccount(
            project: project,
            account: account,
            sharedClientData: sharedClientData,
          ),
        )
        .map((project) => project.id)
        .where((projectId) => projectId.trim().isNotEmpty)
        .toList();

    return matchedIds;
  }

  void _logClientHomeProjectMatch(
    ProjectModel project,
    ClientAccountModel account,
  ) {
    // ignore: avoid_print
    print(
      '[client-home] project match\n'
      'projectId=${project.id}\n'
      'clientId=${project.clientId.isEmpty ? account.clientId : project.clientId}\n'
      'projectName=${project.title}',
    );
  }

  Future<void> syncProjectForClientAccounts({
    required String professionalId,
    required ProjectModel project,
    String clientId = '',
  }) async {
    // ignore: avoid_print
    print(
      '[project-share][pro] START\n'
      'professionalId=$professionalId\n'
      'clientId=$clientId\n'
      'projectId=${project.id}\n'
      'projectPath=users/$professionalId/projects/${project.id}',
    );

    await _syncProjectForClientInvitations(
      professionalId: professionalId,
      project: project,
      clientId: clientId,
    );

    final snapshot = await _accounts
        .where('professionalId', isEqualTo: professionalId)
        .get();

    final normalizedClientId = clientId.trim().toLowerCase();
    final normalizedClientName = project.clientName.trim().toLowerCase();

    for (final account in snapshot.docs) {
      final data = account.data();
      final accountProjectIds =
          (data['projectIds'] as List?)?.cast<String>() ?? const <String>[];
      final accountClientId = '${data['clientId'] ?? ''}'.trim().toLowerCase();
      final accountName = '${data['displayName'] ?? ''}'.trim().toLowerCase();
      final alreadyLinked = accountProjectIds.contains(project.id);
      final matchesClient =
          (normalizedClientId.isNotEmpty &&
              accountClientId == normalizedClientId) ||
          (normalizedClientName.isNotEmpty &&
              (accountName == normalizedClientName ||
                  accountClientId == normalizedClientName));

      if (!alreadyLinked && !matchesClient) continue;

      await account.reference.set({
        'projectIds': FieldValue.arrayUnion([project.id]),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final projectRef = account.reference
          .collection('projects')
          .doc(project.id);
      final previousProject = await projectRef.get();
      final previousData = previousProject.data();
      final publicProjectChanged =
          previousProject.exists &&
          previousData != null &&
          (previousData['status'] != project.status ||
              previousData['deadline'] != project.deadline ||
              previousData['progress'] != project.progress ||
              previousData['currentStep'] != project.currentStep ||
              previousData['nextStep'] != project.nextStep);

      await projectRef.set(
        _publicProjectData(
          professionalId: professionalId,
          project: project,
          clientId: data['clientId'] ?? clientId,
        ),
        SetOptions(merge: true),
      );

      // ignore: avoid_print
      print(
        '[project-share][pro] LINKED\n'
        'clientAccountPath=client_accounts/${account.id}\n'
        'clientProjectPath=client_accounts/${account.id}/projects/${project.id}\n'
        'sharedClientId=${data['sharedClientId'] ?? ''}\n'
        'projectIds=arrayUnion(${project.id})',
      );

      if (publicProjectChanged) {
        await _createNotification(
          recipientUid: account.id,
          title: 'Projet mis à jour',
          body: project.title,
          type: 'project_updated',
          projectId: project.id,
        );
      }
    }
  }

  Future<void> _syncProjectForClientInvitations({
    required String professionalId,
    required ProjectModel project,
    required String clientId,
  }) async {
    final normalizedClientId = clientId.trim().toLowerCase();
    final normalizedClientName = project.clientName.trim().toLowerCase();

    Future<void> syncCollection({
      required CollectionReference<Map<String, dynamic>> collection,
      required String professionalField,
    }) async {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await collection
            .where(professionalField, isEqualTo: professionalId)
            .get()
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        return;
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final invitationClientId = '${data['clientId'] ?? ''}'
            .trim()
            .toLowerCase();
        final invitationClientName = '${data['clientName'] ?? ''}'
            .trim()
            .toLowerCase();
        final matchesClient =
            (normalizedClientId.isNotEmpty &&
                invitationClientId == normalizedClientId) ||
            (normalizedClientName.isNotEmpty &&
                (invitationClientName == normalizedClientName ||
                    invitationClientId == normalizedClientName));

        if (!matchesClient) continue;

        await doc.reference.set({
          'projectIds': FieldValue.arrayUnion([project.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // ignore: avoid_print
        print(
          '[project-share][pro] INVITATION_LINKED\n'
          'collection=${collection.path}\n'
          'sharedClientId=${doc.id}\n'
          'projectIds=arrayUnion(${project.id})\n'
          'sharedProjectPath=shared_projects/${doc.id}_${project.id}',
        );

        await _sharedProjects
            .doc('${doc.id}_${project.id}')
            .set(
              _publicProjectData(
                professionalId: professionalId,
                project: project,
                clientId: data['clientId'] ?? clientId,
              ),
              SetOptions(merge: true),
            )
            .catchError((_) {});
      }
    }

    await syncCollection(
      collection: _invitations,
      professionalField: 'professionalId',
    );
    await syncCollection(
      collection: _sharedClients,
      professionalField: 'ownerUid',
    );
  }

  Future<void> _repairClientAccount(ClientAccountModel account) async {
    if (account.uid.isEmpty) return;

    final accountRef = _accounts.doc(account.uid);

    try {
      await accountRef
          .set({
            ...account.toJson(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 6));

      for (final projectId in account.projectIds) {
        await accountRef
            .collection('projects')
            .doc(projectId)
            .set({
              'projectId': projectId,
              'professionalId': account.professionalId,
              'clientId': account.clientId,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 6));
      }
    } catch (_) {
      // The public project snapshot can still render the client portal.
    }
  }

  Future<ProjectModel?> _projectFromSharedSnapshot(String projectId) async {
    final snapshot = await _sharedProjects
        .where('projectId', isEqualTo: projectId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data();

    return ProjectModel.fromJson({
      'id': data['projectId'] ?? projectId,
      'title': data['title'] ?? '',
      'clientName': data['clientName'] ?? '',
      'type': data['type'] ?? '',
      'status': data['status'] ?? 'Planifié',
      'budget': data['budget'] ?? '',
      'deadline': data['deadline'] ?? '',
      'progress': data['progress'] ?? 0.0,
      'notes': data['notes'] ?? '',
      'shareToken': snapshot.docs.first.id,
    });
  }

  /// Single source of truth for the client<->professional conversation:
  /// both sides read and write `shared_clients/{sharedClientId}/messages`
  /// (the professional's chat UI already uses this collection). No message
  /// is duplicated into `client_accounts/{clientUid}/messages` anymore.
  Stream<List<ClientMessageModel>> clientMessagesStream() async* {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      yield const [];
      return;
    }

    final account = await currentClientAccount();
    if (account == null) {
      yield const [];
      return;
    }

    final token = await _ensureProfessionalClientSpace(account);

    // TEMP DIAGNOSTIC LOG — see clientflow_pro professional/client link audit.
    // ignore: avoid_print
    print(
      '[chat][client] currentAuthUid=$uid role=client '
      'professionalId=${account.professionalId} clientId=${account.clientId} '
      'sharedClientId=$token path=shared_clients/$token/messages',
    );

    yield* _sharedClients
        .doc(token)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClientMessageModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> sendClientMessage(String text) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final account = await currentClientAccount();
    if (account == null) return;

    final token = await _ensureProfessionalClientSpace(account);

    // TEMP DIAGNOSTIC LOG — see clientflow_pro professional/client link audit.
    // ignore: avoid_print
    print(
      '[chat][client] currentAuthUid=$uid role=client '
      'professionalId=${account.professionalId} clientId=${account.clientId} '
      'sharedClientId=$token senderType=client senderUid=$uid '
      'path=shared_clients/$token/messages',
    );

    await _sharedClients.doc(token).collection('messages').add({
      'senderType': 'client',
      'senderUid': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _createNotification(
      recipientUid: account.professionalId,
      title: 'Nouveau message client',
      body: '${account.displayName} vous a envoyé un message.',
      type: 'message_client',
    );
  }

  /// Resolves the single shared_clients doc this client's conversation with
  /// their professional lives under.
  ///
  /// client_accounts/{uid}.sharedClientId is the source of truth once set —
  /// no query, no chance of drifting from what the professional already
  /// uses. It's only ever derived (never guessed/hardcoded) the first time,
  /// by matching clientId/email against the spaces the professional owns —
  /// the exact same key SharedClientService.publish() matches on, on the
  /// professional's side — then cached back onto client_accounts so every
  /// future call (any device, any session) reads the same id straight away.
  /// A new shared_clients doc is only ever created when that search finds
  /// nothing at all for this professional/client pair.
  Future<String> _ensureProfessionalClientSpace(
    ClientAccountModel account, {
    bool logAsChat = true,
  }) async {
    if (account.sharedClientId.isNotEmpty) {
      if (logAsChat) {
        // ignore: avoid_print
        print('[chat][client] sharedClientId=${account.sharedClientId}');
      }
      return account.sharedClientId;
    }

    final owned = await _sharedClients
        .where('ownerUid', isEqualTo: account.professionalId)
        .get();

    var token = _findExistingSharedClientToken(
      docs: owned.docs,
      clientId: account.clientId,
      clientEmail: account.email,
    );

    if (token.isEmpty) {
      token = _generateToken();
      await _sharedClients.doc(token).set({
        'ownerUid': account.professionalId,
        'professionalId': account.professionalId,
        'clientId': account.clientId,
        'clientName': account.displayName,
        'clientEmail': account.email,
        'status': 'claimed',
        'clientUid': account.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await _accounts.doc(account.uid).set({
      'sharedClientId': token,
    }, SetOptions(merge: true));

    if (logAsChat) {
      // ignore: avoid_print
      print('[chat][client] sharedClientId=$token');
    }

    return token;
  }

  /// Best-effort lookup used at claim time: does the professional already
  /// have a shared_clients space for this client? Read-only, never creates
  /// one — claimInvitation() just wants to capture it if it's already there.
  Future<String> _findSharedClientIdFor({
    required String professionalId,
    required String clientId,
    required String clientEmail,
  }) async {
    if (professionalId.isEmpty) return '';
    try {
      final owned = await _sharedClients
          .where('ownerUid', isEqualTo: professionalId)
          .get();
      return _findExistingSharedClientToken(
        docs: owned.docs,
        clientId: clientId,
        clientEmail: clientEmail,
      );
    } catch (_) {
      return '';
    }
  }

  /// Matches by clientId first (exact — both sides derive it from the same
  /// source value), then a trimmed/lowercased email as a fallback so casing
  /// or whitespace differences don't cause a spurious new token.
  String _findExistingSharedClientToken({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String clientId,
    required String clientEmail,
  }) {
    if (clientId.isNotEmpty) {
      for (final doc in docs) {
        if (doc.data()['clientId'] == clientId) return doc.id;
      }
    }

    final normalizedEmail = clientEmail.trim().toLowerCase();
    if (normalizedEmail.isNotEmpty) {
      for (final doc in docs) {
        final docEmail = '${doc.data()['clientEmail'] ?? ''}'
            .trim()
            .toLowerCase();
        if (docEmail == normalizedEmail) return doc.id;
      }
    }

    return '';
  }

  /// Writes the professional's canonical sharedClientId onto the matching
  /// client_accounts record(s), so the client side finds it via the cached
  /// field above instead of ever having to re-derive or guess it.
  Future<void> syncSharedClientIdToAccounts({
    required String professionalId,
    required String token,
    required String clientId,
    required String clientName,
    required String clientEmail,
  }) async {
    final accounts = await _matchingClientAccounts(
      professionalId: professionalId,
      clientId: clientId,
      clientName: clientName,
      clientEmail: clientEmail,
    );

    for (final account in accounts) {
      if (account.data()['sharedClientId'] == token) continue;
      await account.reference.set({
        'sharedClientId': token,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _backfillSharedMessagesToClientAccount({
    required DocumentReference<Map<String, dynamic>> accountRef,
    required String token,
  }) async {
    final normalizedToken = token.trim().toUpperCase();
    if (normalizedToken.isEmpty) return;

    final messages = await _sharedClients
        .doc(normalizedToken)
        .collection('messages')
        .orderBy('createdAt')
        .get();

    final batch = firestore.batch();
    for (final message in messages.docs) {
      batch.set(
        accountRef.collection('messages').doc(message.id),
        message.data(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<Map<String, dynamic>> _publicProjectSnapshot({
    required String professionalId,
    required String projectId,
    required String clientId,
  }) async {
    final sharedProject = await _projectFromSharedSnapshot(projectId);
    if (sharedProject != null && sharedProject.title.trim().isNotEmpty) {
      return _publicProjectData(
        professionalId: professionalId,
        project: sharedProject,
        clientId: clientId,
      );
    }

    Map<String, dynamic>? data;
    try {
      final doc = await firestore
          .collection('users')
          .doc(professionalId)
          .collection('projects')
          .doc(projectId)
          .get();
      data = doc.data();
    } catch (_) {
      data = null;
    }

    if (data == null) {
      return {
        'id': projectId,
        'projectId': projectId,
        'professionalId': professionalId,
        'clientId': clientId,
        'createdAt': FieldValue.serverTimestamp(),
      };
    }

    return _publicProjectData(
      professionalId: professionalId,
      project: ProjectModel.fromJson({...data, 'id': data['id'] ?? projectId}),
      clientId: clientId,
    );
  }

  Map<String, dynamic> _publicProjectData({
    required String professionalId,
    required ProjectModel project,
    required String clientId,
  }) {
    return {
      'id': project.id,
      'projectId': project.id,
      'professionalId': professionalId,
      'clientId': clientId,
      'title': project.title,
      'clientName': project.clientName,
      'type': project.type,
      'status': project.status,
      'budget': project.budget,
      'deadline': project.deadline,
      'progress': project.progress,
      'currentStep': project.currentStep,
      'nextStep': project.nextStep,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Notifies the client that their professional replied. The message text
  /// itself is NOT duplicated into client_accounts/{clientUid}/messages
  /// anymore — both sides read and write only shared_clients/{sharedClientId}
  /// /messages (see SharedClientService.sendMessage).
  Future<void> notifyClientAccountsOfProfessionalMessage({
    required String professionalId,
    required String clientId,
    required String clientName,
    required String clientEmail,
  }) async {
    final accounts = await _matchingClientAccounts(
      professionalId: professionalId,
      clientId: clientId,
      clientName: clientName,
      clientEmail: clientEmail,
    );

    for (final account in accounts) {
      await _createNotification(
        recipientUid: account.id,
        title: 'Nouveau message',
        body: 'Votre prestataire vous a envoyé un message.',
        type: 'message_professional',
      );
    }
  }

  Future<void> backfillClientMessagesToProfessionalSpace({
    required String professionalId,
    required String token,
    required String clientId,
    required String clientName,
    required String clientEmail,
  }) async {
    final accounts = await _matchingClientAccounts(
      professionalId: professionalId,
      clientId: clientId,
      clientName: clientName,
      clientEmail: clientEmail,
    );

    for (final account in accounts) {
      final messages = await account.reference
          .collection('messages')
          .where('senderType', isEqualTo: 'client')
          .get();

      for (final message in messages.docs) {
        await _sharedClients
            .doc(token)
            .collection('messages')
            .doc(message.id)
            .set(message.data(), SetOptions(merge: true));
      }
    }
  }

  Future<void> syncTaskForClientAccounts({
    required String professionalId,
    required TaskModel task,
  }) async {
    final snapshot = await _accounts
        .where('professionalId', isEqualTo: professionalId)
        .where('projectIds', arrayContains: task.projectId)
        .get();

    for (final account in snapshot.docs) {
      if (!task.visibleToClient) {
        await Future.wait([
          account.reference.collection('tasks').doc(task.id).delete(),
          account.reference.collection('actions').doc(task.id).delete(),
          account.reference.collection('timeline').doc(task.id).delete(),
        ]).catchError((_) => <void>[]);
        continue;
      }

      final accountData = account.data();
      await account.reference.collection('tasks').doc(task.id).set({
        ...task.toJson(),
        'professionalUid': professionalId,
        'clientId': accountData['clientId'] ?? '',
      }, SetOptions(merge: true));

      await account.reference.collection('actions').doc(task.id).set({
        'id': task.id,
        'professionalUid': professionalId,
        'projectId': task.projectId,
        'clientId': accountData['clientId'] ?? '',
        'title': task.title,
        'description': task.status == 'Terminé'
            ? 'Cette tâche a été marquée comme terminée.'
            : 'Tâche prévue côté prestataire · priorité ${task.priority}',
        'assignedTo': 'professional',
        'type': 'task',
        'priority': _taskPriorityToActionPriority(task.priority),
        'status': task.status == 'Terminé' ? 'completed' : 'pending',
        'visibleToClient': task.visibleToClient,
        'dueDate': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'completedAt': task.status == 'Terminé'
            ? FieldValue.serverTimestamp()
            : null,
      }, SetOptions(merge: true));

      await account.reference.collection('timeline').doc(task.id).set({
        'id': task.id,
        'projectId': task.projectId,
        'professionalUid': professionalId,
        'title': task.title,
        'description': task.status == 'Terminé'
            ? 'Tâche terminée'
            : 'Tâche prévue côté prestataire',
        'status': task.status == 'Terminé' ? 'completed' : 'upcoming',
        'order': DateTime.now().millisecondsSinceEpoch,
        'visibleToClient': task.visibleToClient,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteTaskForClientAccounts({
    required String professionalId,
    required TaskModel task,
  }) async {
    if (task.projectId.isEmpty) return;

    final snapshot = await _accounts
        .where('professionalId', isEqualTo: professionalId)
        .where('projectIds', arrayContains: task.projectId)
        .get();

    for (final account in snapshot.docs) {
      await Future.wait([
        account.reference.collection('tasks').doc(task.id).delete(),
        account.reference.collection('actions').doc(task.id).delete(),
        account.reference.collection('timeline').doc(task.id).delete(),
      ]).catchError((_) => <void>[]);
    }
  }

  Future<void> syncTimelineEventForClientAccounts({
    required TimelineEventModel event,
  }) async {
    final accounts = await _accounts
        .where('professionalId', isEqualTo: event.professionalUid)
        .where('projectIds', arrayContains: event.projectId)
        .get();

    for (final account in accounts.docs) {
      final docRef = account.reference.collection('timeline').doc(event.id);
      if (!event.visibleToClient) {
        final existing = await docRef.get();
        if (existing.exists) await docRef.delete();
        continue;
      }
      await docRef.set(event.toJson(), SetOptions(merge: true));
    }
  }

  Future<void> deleteTimelineEventForClientAccounts({
    required TimelineEventModel event,
  }) async {
    final accounts = await _accounts
        .where('professionalId', isEqualTo: event.professionalUid)
        .where('projectIds', arrayContains: event.projectId)
        .get();

    for (final account in accounts.docs) {
      await account.reference.collection('timeline').doc(event.id).delete();
    }
  }

  Future<void> syncProjectActionForClientAccounts({
    required ClientActionModel action,
  }) async {
    final accounts = await _accounts
        .where('professionalId', isEqualTo: action.professionalUid)
        .where('projectIds', arrayContains: action.projectId)
        .get();

    for (final account in accounts.docs) {
      final docRef = account.reference.collection('actions').doc(action.id);

      if (!action.visibleToClient) {
        final existing = await docRef.get();
        if (existing.exists) await docRef.delete();
        continue;
      }

      final accountData = account.data();
      final existingAction = await docRef.get();
      await docRef.set({
        ...action.toJson(),
        'clientId': action.clientId.isNotEmpty
            ? action.clientId
            : accountData['clientId'] ?? '',
      }, SetOptions(merge: true));

      if (!existingAction.exists &&
          action.assignedTo == 'client' &&
          action.status == 'pending') {
        await _createNotification(
          recipientUid: account.id,
          title: action.type == 'validation'
              ? 'Nouvelle validation'
              : action.type == 'document'
              ? 'Document demandé'
              : 'Nouvelle action à réaliser',
          body: action.title,
          type: action.type == 'validation'
              ? 'validation_requested'
              : action.type == 'document'
              ? 'document_requested'
              : 'client_action',
          projectId: action.projectId,
        );
      }
    }
  }

  Future<void> deleteActionForClientAccounts({
    required ClientActionModel action,
  }) async {
    if (action.professionalUid.isEmpty || action.projectId.isEmpty) return;

    final accounts = await _accounts
        .where('professionalId', isEqualTo: action.professionalUid)
        .where('projectIds', arrayContains: action.projectId)
        .get();

    for (final account in accounts.docs) {
      final docRef = account.reference.collection('actions').doc(action.id);
      final existing = await docRef.get();
      if (existing.exists) await docRef.delete();
    }
  }

  Future<void> completeCurrentClientAction(ClientActionModel action) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final account = await currentClientAccount();
    if (account == null) return;

    // Same source of truth as reviewDeliverableVersion/addDeliverableAnnotation
    // and as the Firestore rules themselves (isAllowedClientProject): is this
    // project actually linked under client_accounts/{uid}/projects, not the
    // flat account.projectIds array, which can be empty/stale even when the
    // client genuinely has access (e.g. resolved only through the
    // shared_clients/sharedClientId fallback match — see
    // clientHomeProjectsProvider / clientProjectsStreamForAccount).
    final projectLink = await _accounts
        .doc(uid)
        .collection('projects')
        .doc(action.projectId)
        .get();

    final canComplete =
        action.assignedTo == 'client' &&
        action.visibleToClient &&
        action.status == 'pending' &&
        projectLink.exists &&
        action.professionalUid == account.professionalId;

    if (!canComplete) {
      throw StateError('Cette action ne peut pas être modifiée côté client.');
    }

    final completedData = {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = firestore.batch();
    batch.set(
      _accounts.doc(uid).collection('actions').doc(action.id),
      completedData,
      SetOptions(merge: true),
    );
    batch.set(
      firestore
          .collection('users')
          .doc(account.professionalId)
          .collection('project_actions')
          .doc(action.id),
      completedData,
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  String _taskPriorityToActionPriority(String priority) {
    switch (priority) {
      case 'Haute':
        return 'high';
      case 'Basse':
        return 'low';
      default:
        return 'medium';
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _matchingClientAccounts({
    required String professionalId,
    required String clientId,
    required String clientName,
    required String clientEmail,
  }) async {
    final snapshot = await _accounts
        .where('professionalId', isEqualTo: professionalId)
        .get();

    final normalizedEmail = clientEmail.trim().toLowerCase();
    final normalizedName = clientName.trim().toLowerCase();

    return snapshot.docs.where((doc) {
      final data = doc.data();
      final accountClientId = '${data['clientId'] ?? ''}'.trim().toLowerCase();
      final accountEmail = '${data['email'] ?? ''}'.trim().toLowerCase();
      final accountName = '${data['displayName'] ?? ''}'.trim().toLowerCase();

      return (clientId.isNotEmpty && data['clientId'] == clientId) ||
          (normalizedEmail.isNotEmpty && accountEmail == normalizedEmail) ||
          (normalizedName.isNotEmpty &&
              (accountName == normalizedName ||
                  accountClientId == normalizedName));
    }).toList();
  }

  /// Read-only lookup of the client_accounts record linked to one of the
  /// professional's own clients — reuses the exact same matching logic as
  /// everywhere else (_matchingClientAccounts). Used by the "Espaces
  /// clients" detail page to show the last-login date, when available.
  Future<ClientAccountModel?> findClientAccountFor({
    required String professionalId,
    required String clientId,
    required String clientName,
    required String clientEmail,
  }) async {
    final matches = await _matchingClientAccounts(
      professionalId: professionalId,
      clientId: clientId,
      clientName: clientName,
      clientEmail: clientEmail,
    );
    if (matches.isEmpty) return null;
    return ClientAccountModel.fromJson(matches.first.data());
  }

  Stream<List<ClientDocumentModel>> documentsStream() {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _accounts
        .doc(uid)
        .collection('documents')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClientDocumentModel.fromJson(doc.data()))
              .toList(),
        );
  }

  Stream<List<DocumentRequestModel>> documentRequestsStream() {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _accounts
        .doc(uid)
        .collection('document_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => DocumentRequestModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList(),
        );
  }

  Stream<List<DeliverableModel>> deliverablesStream() async* {
    try {
      yield* _professionalDeliverablesStream();
    } catch (_) {
      yield* _clientAccountDeliverablesStream();
    }
  }

  Stream<List<DeliverableModel>> _professionalDeliverablesStream() async* {
    final account = await currentClientAccount();
    if (account == null || account.projectIds.isEmpty) {
      yield const <DeliverableModel>[];
      return;
    }

    final projectIds = account.projectIds
        .where((projectId) => projectId.trim().isNotEmpty)
        .take(30)
        .toList();
    if (projectIds.isEmpty) {
      yield const <DeliverableModel>[];
      return;
    }

    yield* firestore
        .collection('users')
        .doc(account.professionalId)
        .collection('deliverables')
        .where('projectId', whereIn: projectIds)
        .snapshots()
        .map((snapshot) {
          final deliverables = snapshot.docs
              .map(
                (doc) =>
                    DeliverableModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .toList();
          deliverables.sort(_compareDeliverables);
          return deliverables;
        });
  }

  /// Validations for exactly the projects the client portal has already
  /// resolved as accessible (see clientHomeProjectsProvider / the
  /// account.projectIds + shared_clients union it performs) — reused here
  /// instead of re-deriving project access independently, so this list
  /// never falls out of sync with what Accueil/Avancement/Profil show.
  /// Reads users/{professionalId}/deliverables directly: no client-side
  /// copy is created.
  Stream<List<DeliverableModel>> deliverablesStreamForProjects({
    required String professionalId,
    required String clientId,
    required String sharedClientId,
    required List<String> projectIds,
  }) async* {
    final ids = projectIds
        .where((projectId) => projectId.trim().isNotEmpty)
        .take(30)
        .toList();

    if (professionalId.isEmpty || ids.isEmpty) {
      // ignore: avoid_print
      print(
        '[validation][client][load]\n'
        'projectId=\n'
        'clientId=$clientId\n'
        'sharedClientId=$sharedClientId\n'
        'queryPath=users/$professionalId/deliverables\n'
        'validationsFound=0',
      );
      yield const <DeliverableModel>[];
      return;
    }

    final queryPath =
        'users/$professionalId/deliverables where projectId in $ids';

    yield* firestore
        .collection('users')
        .doc(professionalId)
        .collection('deliverables')
        .where('projectId', whereIn: ids)
        .snapshots()
        .map((snapshot) {
          final deliverables = snapshot.docs
              .map(
                (doc) =>
                    DeliverableModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .where((deliverable) => deliverable.visibleToClient)
              .toList();
          deliverables.sort(_compareDeliverables);
          // ignore: avoid_print
          print(
            '[validation][client][load]\n'
            'projectId=${ids.join(',')}\n'
            'clientId=$clientId\n'
            'sharedClientId=$sharedClientId\n'
            'queryPath=$queryPath\n'
            'validationsFound=${deliverables.length}',
          );
          return deliverables;
        });
  }

  Stream<List<DeliverableModel>> _clientAccountDeliverablesStream() {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _accounts
        .doc(uid)
        .collection('deliverables')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    DeliverableModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .toList(),
        );
  }

  Stream<List<DeliverableVersionModel>> deliverableVersionsStream() async* {
    try {
      yield* _professionalDeliverableVersionsStream();
    } catch (_) {
      yield* _clientAccountDeliverableVersionsStream();
    }
  }

  Stream<List<DeliverableVersionModel>>
  _professionalDeliverableVersionsStream() async* {
    final account = await currentClientAccount();
    if (account == null || account.projectIds.isEmpty) {
      yield const <DeliverableVersionModel>[];
      return;
    }

    final projectIds = account.projectIds
        .where((projectId) => projectId.trim().isNotEmpty)
        .take(30)
        .toList();
    if (projectIds.isEmpty) {
      yield const <DeliverableVersionModel>[];
      return;
    }

    yield* firestore
        .collection('users')
        .doc(account.professionalId)
        .collection('deliverable_versions')
        .where('projectId', whereIn: projectIds)
        .snapshots()
        .map((snapshot) {
          final versions = snapshot.docs
              .map(
                (doc) => DeliverableVersionModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList();
          versions.sort(_compareDeliverableVersions);
          return versions;
        });
  }

  /// Same reuse principle as deliverablesStreamForProjects, for versions.
  Stream<List<DeliverableVersionModel>> deliverableVersionsStreamForProjects({
    required String professionalId,
    required String clientId,
    required String sharedClientId,
    required List<String> projectIds,
  }) async* {
    final ids = projectIds
        .where((projectId) => projectId.trim().isNotEmpty)
        .take(30)
        .toList();

    if (professionalId.isEmpty || ids.isEmpty) {
      yield const <DeliverableVersionModel>[];
      return;
    }

    final queryPath =
        'users/$professionalId/deliverable_versions where projectId in $ids';

    yield* firestore
        .collection('users')
        .doc(professionalId)
        .collection('deliverable_versions')
        .where('projectId', whereIn: ids)
        .snapshots()
        .map((snapshot) {
          final versions = snapshot.docs
              .map(
                (doc) => DeliverableVersionModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList();
          versions.sort(_compareDeliverableVersions);
          // ignore: avoid_print
          print(
            '[validation][client][load]\n'
            'projectId=${ids.join(',')}\n'
            'clientId=$clientId\n'
            'sharedClientId=$sharedClientId\n'
            'queryPath=$queryPath\n'
            'versionsFound=${versions.length}',
          );
          return versions;
        });
  }

  Stream<List<DeliverableVersionModel>>
  _clientAccountDeliverableVersionsStream() {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _accounts
        .doc(uid)
        .collection('deliverable_versions')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => DeliverableVersionModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList(),
        );
  }

  int _compareDeliverables(DeliverableModel a, DeliverableModel b) {
    final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1900);
    final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1900);
    return bDate.compareTo(aDate);
  }

  int _compareDeliverableVersions(
    DeliverableVersionModel a,
    DeliverableVersionModel b,
  ) {
    final aDate = a.uploadedAt ?? DateTime(1900);
    final bDate = b.uploadedAt ?? DateTime(1900);
    final dateCompare = bDate.compareTo(aDate);
    if (dateCompare != 0) return dateCompare;
    return b.versionNumber.compareTo(a.versionNumber);
  }

  Stream<List<DeliverableAnnotationModel>> deliverableAnnotationsStream() {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _accounts
        .doc(uid)
        .collection('deliverable_annotations')
        .snapshots()
        .map((snapshot) {
          final annotations = snapshot.docs
              .map(
                (doc) => DeliverableAnnotationModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .toList();
          annotations.sort((a, b) {
            final aDate = a.createdAt ?? DateTime(1900);
            final bDate = b.createdAt ?? DateTime(1900);
            return aDate.compareTo(bDate);
          });
          return annotations;
        });
  }

  Future<void> addDeliverableAnnotation({
    required DeliverableModel deliverable,
    required DeliverableVersionModel version,
    required double x,
    required double y,
    required String comment,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final account = await currentClientAccount();
    if (account == null) return;

    final canAccessProject = await _currentClientCanAccessProject(
      account: account,
      projectId: deliverable.projectId,
    );

    if (!canAccessProject ||
        deliverable.professionalUid != account.professionalId ||
        version.deliverableId != deliverable.id) {
      throw StateError('Accès refusé à ce livrable.');
    }

    final now = DateTime.now();
    final annotation = DeliverableAnnotationModel(
      id: 'annotation_${now.microsecondsSinceEpoch}',
      deliverableVersionId: version.id,
      deliverableId: deliverable.id,
      projectId: deliverable.projectId,
      professionalUid: deliverable.professionalUid,
      authorUid: uid,
      x: x.clamp(0.0, 1.0),
      y: y.clamp(0.0, 1.0),
      pageNumber: null,
      comment: comment,
      createdAt: now,
      resolved: false,
    );

    final batch = firestore.batch();
    final professionalRef = firestore
        .collection('users')
        .doc(account.professionalId)
        .collection('deliverable_annotations')
        .doc(annotation.id);
    final clientRef = _accounts
        .doc(uid)
        .collection('deliverable_annotations')
        .doc(annotation.id);

    batch.set(professionalRef, annotation.toJson());
    batch.set(clientRef, annotation.toJson());
    await batch.commit();
  }

  Future<void> reviewDeliverableVersion({
    required DeliverableModel deliverable,
    required DeliverableVersionModel version,
    required bool approved,
    required String comment,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final account = await currentClientAccount();
    if (account == null) return;

    final canAccessProject = await _currentClientCanAccessProject(
      account: account,
      projectId: deliverable.projectId,
    );

    if (!canAccessProject ||
        deliverable.professionalUid != account.professionalId) {
      throw StateError('Accès refusé à ce livrable.');
    }

    final nextStatus = approved ? 'approved' : 'changesRequested';
    final reviewedAt = DateTime.now();
    final actionId = _deliverableValidationActionId(
      deliverable.id,
      version.versionNumber,
    );
    final professionalRef = firestore
        .collection('users')
        .doc(account.professionalId);
    final deliverableRef = professionalRef
        .collection('deliverables')
        .doc(deliverable.id);
    final versionRef = professionalRef
        .collection('deliverable_versions')
        .doc(version.id);
    final actionRef = professionalRef
        .collection('project_actions')
        .doc(actionId);
    final actionDoc = await actionRef.get();
    final actionData = actionDoc.data();
    final canCompleteAction =
        actionDoc.exists &&
        actionData?['status'] == 'pending' &&
        actionData?['assignedTo'] == 'client' &&
        actionData?['visibleToClient'] == true;

    // ignore: avoid_print
    print(
      '[validation][client][update-paths]\n'
      'deliverablePath=${deliverableRef.path}\n'
      'versionPath=${versionRef.path}\n'
      'actionPath=${actionRef.path}\n'
      'actionExists=${actionDoc.exists}\n'
      'canCompleteAction=$canCompleteAction\n'
      'changedFields=deliverable(status,updatedAt),'
      'version(status,clientComment,reviewedAt,reviewedBy)',
    );

    final batch = firestore.batch();
    batch.set(deliverableRef, {
      'status': nextStatus,
      'updatedAt': reviewedAt,
    }, SetOptions(merge: true));
    batch.set(versionRef, {
      'status': nextStatus,
      'clientComment': approved ? null : comment,
      'reviewedAt': reviewedAt,
      'reviewedBy': uid,
    }, SetOptions(merge: true));
    if (canCompleteAction) {
      batch.update(actionRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    // ignore: avoid_print
    print(
      '[validation][client][update]\n'
      'validationId=${deliverable.id}\n'
      'oldStatus=${deliverable.status}\n'
      'newStatus=$nextStatus',
    );

    await _createNotification(
      recipientUid: account.professionalId,
      title: approved ? 'Validation client effectuée' : 'Modification demandée',
      body: deliverable.title,
      type: approved ? 'validation_approved' : 'changes_requested',
      projectId: deliverable.projectId,
    );
  }

  Future<bool> _currentClientCanAccessProject({
    required ClientAccountModel account,
    required String projectId,
  }) async {
    if (projectId.trim().isEmpty || account.professionalId.trim().isEmpty) {
      return false;
    }

    final projectLink = await _accounts
        .doc(account.uid)
        .collection('projects')
        .doc(projectId)
        .get();
    if (projectLink.exists &&
        projectLink.data()?['professionalId'] == account.professionalId) {
      return true;
    }

    if (account.projectIds.contains(projectId)) return true;

    final projectDoc = await firestore
        .collection('users')
        .doc(account.professionalId)
        .collection('projects')
        .doc(projectId)
        .get();
    final projectData = projectDoc.data();
    return projectData != null &&
        '${projectData['clientId'] ?? ''}' == account.clientId;
  }

  Future<void> uploadClientDocument({
    required String name,
    required String comment,
    required String fileName,
    required Uint8List bytes,
    String? requestId,
    String? projectId,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      // ignore: avoid_print
      print('[document-upload][client] ABORT — no currentAuthUid');
      return;
    }

    final account = await currentClientAccount();
    if (account == null) {
      // ignore: avoid_print
      print(
        '[document-upload][client] ABORT — no client_accounts record for '
        'currentAuthUid=$uid',
      );
      return;
    }

    final documentId = _accounts.doc(uid).collection('documents').doc().id;
    final linkedProjectId = projectId?.trim().isNotEmpty == true
        ? projectId!.trim()
        : account.projectIds.isEmpty
        ? ''
        : account.projectIds.first;
    final sharedClientId = await _ensureProfessionalClientSpace(
      account,
      logAsChat: false,
    );
    if (sharedClientId.isEmpty) {
      throw StateError('Espace client partagé introuvable.');
    }
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath = _sharedDocumentStoragePath(
      sharedClientId: sharedClientId,
      projectId: linkedProjectId,
      documentId: documentId,
      fileName: safeFileName,
    );

    // ignore: avoid_print
    print(
      '[document-upload]\n'
      'sharedClientId=$sharedClientId\n'
      'projectId=$linkedProjectId\n'
      'authUid=$uid\n'
      'storagePath=$storagePath',
    );

    // ignore: avoid_print
    print(
      '[document-upload][client] START\n'
      '  currentAuthUid=$uid\n'
      '  clientId=${account.clientId}\n'
      '  professionalId=${account.professionalId}\n'
      '  sharedClientId=$sharedClientId\n'
      '  projectId=$linkedProjectId\n'
      '  fileName=$fileName\n'
      '  fileSize=${bytes.length}\n'
      '  storageBucket=${storage.bucket}\n'
      '  storagePath=$storagePath',
    );

    // ignore: avoid_print
    print(
      '[document-upload][client] step2 storage reference created ref=$storagePath',
    );

    final ref = storage.ref(storagePath);

    // ignore: avoid_print
    print('[document-upload][client] step3 putData started');

    late final TaskSnapshot upload;
    try {
      upload = await ref.putData(
        bytes,
        SettableMetadata(contentType: _mimeTypeFromFileName(fileName)),
      );
      // ignore: avoid_print
      print(
        '[document-upload][client] step4 Storage upload SUCCEEDED '
        'bytesTransferred=${upload.bytesTransferred} state=${upload.state}',
      );
    } on FirebaseException catch (e, stackTrace) {
      // ignore: avoid_print
      print(
        '[document-upload][client] step4 Storage upload FAILED\n'
        '  code=${e.code}\n'
        '  message=${e.message}\n'
        '  plugin=${e.plugin}\n'
        '  stackTrace=$stackTrace',
      );
      rethrow;
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print(
        '[document-upload][client] step4 Storage upload FAILED (non-Firebase) '
        'error=$e\n  stackTrace=$stackTrace',
      );
      rethrow;
    }

    String url;
    try {
      url = await upload.ref.getDownloadURL();
      // ignore: avoid_print
      print('[document-upload][client] step5 downloadURL resolved url=$url');
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print(
        '[document-upload][client] step5 downloadURL FAILED error=$e\n'
        '  stackTrace=$stackTrace',
      );
      rethrow;
    }

    final docRef = _accounts.doc(uid).collection('documents').doc(documentId);
    final firestoreData = {
      'id': documentId,
      'name': name,
      'type': 'document',
      'clientId': account.clientId,
      'clientUid': uid,
      'projectId': linkedProjectId,
      'uploadedBy': 'client',
      'url': url,
      'storagePath': storagePath,
      'status': 'Reçu',
      'comment': comment,
      'requestId': requestId ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // ignore: avoid_print
    print(
      '[document-upload][client] step6 Firestore write started '
      'path=client_accounts/$uid/documents/$documentId',
    );

    try {
      await docRef.set(firestoreData);
      // ignore: avoid_print
      print('[document-upload][client] step7 Firestore write SUCCEEDED');
    } on FirebaseException catch (e, stackTrace) {
      // ignore: avoid_print
      print(
        '[document-upload][client] step7 Firestore write FAILED\n'
        '  code=${e.code}\n'
        '  message=${e.message}\n'
        '  plugin=${e.plugin}\n'
        '  stackTrace=$stackTrace',
      );
      rethrow;
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print(
        '[document-upload][client] step7 Firestore write FAILED (non-Firebase) '
        'error=$e\n  stackTrace=$stackTrace',
      );
      rethrow;
    }

    if (requestId != null && requestId.isNotEmpty) {
      try {
        await _markClientDocumentRequestReceived(
          account: account,
          requestId: requestId,
          documentId: documentId,
        );
      } on FirebaseException catch (e, stackTrace) {
        // ignore: avoid_print
        print(
          '[document-upload][client] request update FAILED\n'
          '  code=${e.code}\n'
          '  message=${e.message}\n'
          '  plugin=${e.plugin}\n'
          '  requestId=$requestId\n'
          '  documentId=$documentId\n'
          '  stackTrace=$stackTrace',
        );
      } catch (e, stackTrace) {
        // ignore: avoid_print
        print(
          '[document-upload][client] request update FAILED (non-Firebase)\n'
          '  error=$e\n'
          '  requestId=$requestId\n'
          '  documentId=$documentId\n'
          '  stackTrace=$stackTrace',
        );
        // The uploaded document is already available to both sides. If rules
        // for request/action mirroring are not deployed yet, do not report the
        // whole upload as failed to the client.
      }
    }

    await _createNotification(
      recipientUid: account.professionalId,
      title: 'Document reçu',
      body: '${account.displayName} a envoyé $name.',
      type: 'document_received',
      projectId: linkedProjectId,
    );
  }

  Future<void> _markClientDocumentRequestReceived({
    required ClientAccountModel account,
    required String requestId,
    required String documentId,
  }) async {
    final clientRequestRef = _accounts
        .doc(account.uid)
        .collection('document_requests')
        .doc(requestId);
    final clientActionRef = _accounts
        .doc(account.uid)
        .collection('actions')
        .doc(requestId);
    final professionalRequestRef = firestore
        .collection('users')
        .doc(account.professionalId)
        .collection('document_requests')
        .doc(requestId);
    final professionalActionRef = firestore
        .collection('users')
        .doc(account.professionalId)
        .collection('project_actions')
        .doc(requestId);
    final professionalActionSnapshot = await professionalActionRef.get();
    final professionalActionData = professionalActionSnapshot.data();
    final canCompleteProfessionalAction =
        professionalActionSnapshot.exists &&
        professionalActionData?['status'] == 'pending' &&
        professionalActionData?['assignedTo'] == 'client' &&
        professionalActionData?['visibleToClient'] == true;

    // ignore: avoid_print
    print(
      '[document-upload][client] Firestore request update\n'
      'clientRequestPath=${clientRequestRef.path}\n'
      'professionalRequestPath=${professionalRequestRef.path}\n'
      'professionalActionPath=${professionalActionRef.path}\n'
      'professionalActionExists=${professionalActionSnapshot.exists}\n'
      'canCompleteProfessionalAction=$canCompleteProfessionalAction\n'
      'fields=status,uploadedDocumentId,clientUid,updatedAt',
    );

    await clientRequestRef.set({
      'status': 'received',
      'uploadedDocumentId': documentId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await professionalRequestRef.set({
      'status': 'received',
      'uploadedDocumentId': documentId,
      'clientUid': account.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (canCompleteProfessionalAction) {
      await professionalActionRef.update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final clientActionSnapshot = await clientActionRef.get();
    if (clientActionSnapshot.exists) {
      await clientActionRef.set({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> syncDocumentRequestForClientAccounts({
    required DocumentRequestModel request,
  }) async {
    final accounts = await _accounts
        .where('professionalId', isEqualTo: request.professionalUid)
        .where('projectIds', arrayContains: request.projectId)
        .get();

    for (final account in accounts.docs) {
      final data = account.data();
      final accountClientId = '${data['clientId'] ?? ''}';
      if (request.clientId.isNotEmpty && accountClientId != request.clientId) {
        continue;
      }

      await account.reference
          .collection('document_requests')
          .doc(request.id)
          .set({
            ...request.toJson(),
            'clientUid': account.id,
          }, SetOptions(merge: true));
    }
  }

  Future<void> deleteDocumentRequestForClientAccounts({
    required DocumentRequestModel request,
  }) async {
    final accounts = await _accounts
        .where('professionalId', isEqualTo: request.professionalUid)
        .where('projectIds', arrayContains: request.projectId)
        .get();

    for (final account in accounts.docs) {
      await account.reference
          .collection('document_requests')
          .doc(request.id)
          .delete();
    }
  }

  Future<void> updateDocumentRequestStatusForClient({
    required DocumentRequestModel request,
  }) async {
    if (request.clientUid.isNotEmpty) {
      await _accounts
          .doc(request.clientUid)
          .collection('document_requests')
          .doc(request.id)
          .set(request.toJson(), SetOptions(merge: true));
      return;
    }

    await syncDocumentRequestForClientAccounts(request: request);
  }

  Future<void> uploadProfessionalDocumentForClient({
    required String professionalId,
    required String clientId,
    required String clientName,
    required String clientEmail,
    required String name,
    required String comment,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final accounts = await _matchingClientAccounts(
      professionalId: professionalId,
      clientId: clientId,
      clientName: clientName,
      clientEmail: clientEmail,
    );
    if (accounts.isEmpty) {
      throw StateError(
        'Aucun compte client connecté trouvé pour recevoir ce document.',
      );
    }

    for (final account in accounts) {
      final accountData = account.data();
      final projectIds =
          (accountData['projectIds'] as List?)?.cast<String>() ??
          const <String>[];
      final documentId = account.reference.collection('documents').doc().id;
      final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final linkedProjectId = projectIds.isEmpty ? '' : projectIds.first;
      final sharedClientId = await _sharedClientIdForAccountDoc(
        account: account,
        professionalId: professionalId,
        clientId: clientId,
        clientName: clientName,
        clientEmail: clientEmail,
      );
      if (sharedClientId.isEmpty) {
        throw StateError('Espace client partagé introuvable.');
      }
      final storagePath = _sharedDocumentStoragePath(
        sharedClientId: sharedClientId,
        projectId: linkedProjectId,
        documentId: documentId,
        fileName: safeFileName,
      );

      // ignore: avoid_print
      print(
        '[document-upload]\n'
        'sharedClientId=$sharedClientId\n'
        'projectId=$linkedProjectId\n'
        'authUid=$professionalId\n'
        'storagePath=$storagePath',
      );

      final ref = storage.ref(storagePath);
      await ref.putData(
        bytes,
        SettableMetadata(contentType: _mimeTypeFromFileName(fileName)),
      );
      final url = await ref.getDownloadURL();

      await account.reference.collection('documents').doc(documentId).set({
        'id': documentId,
        'name': name,
        'type': 'document',
        'clientId': accountData['clientId'] ?? clientId,
        'clientUid': account.id,
        'projectId': linkedProjectId,
        'uploadedBy': 'freelancer',
        'url': url,
        'storagePath': storagePath,
        'status': 'Validé',
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<List<ClientDocumentModel>> professionalDocumentsStream({
    required String professionalId,
    required String clientId,
    required String clientName,
    required String clientEmail,
  }) {
    return _accounts
        .where('professionalId', isEqualTo: professionalId)
        .snapshots()
        .asyncExpand((snapshot) {
          final matchingAccounts = snapshot.docs.where((doc) {
            final data = doc.data();
            final accountClientId = '${data['clientId'] ?? ''}';
            final accountEmail = '${data['email'] ?? ''}'.toLowerCase();
            final accountName = '${data['displayName'] ?? ''}'.toLowerCase();
            return accountClientId == clientId ||
                (clientEmail.isNotEmpty &&
                    accountEmail == clientEmail.toLowerCase()) ||
                (clientName.isNotEmpty &&
                    accountName == clientName.toLowerCase());
          });

          if (matchingAccounts.isEmpty) {
            return Stream.value(const <ClientDocumentModel>[]);
          }

          return matchingAccounts.first.reference
              .collection('documents')
              .orderBy('createdAt', descending: true)
              .snapshots()
              .map(
                (documentsSnapshot) => documentsSnapshot.docs
                    .map(
                      (doc) => ClientDocumentModel.fromJson({
                        ...doc.data(),
                        'id': doc.id,
                        'clientUid': matchingAccounts.first.id,
                      }),
                    )
                    .toList(),
              );
        });
  }

  Future<void> deleteCurrentClientDocument(ClientDocumentModel document) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || document.id.isEmpty) return;

    await _deleteStoredFile(document.storagePath);
    await _accounts.doc(uid).collection('documents').doc(document.id).delete();
  }

  Future<void> deleteProfessionalDocument({
    required ClientDocumentModel document,
    required String professionalId,
    required String clientId,
    required String clientName,
    required String clientEmail,
  }) async {
    if (document.id.isEmpty) return;

    await _deleteStoredFile(document.storagePath);

    if (document.clientUid.isNotEmpty) {
      await _accounts
          .doc(document.clientUid)
          .collection('documents')
          .doc(document.id)
          .delete();
      return;
    }

    final accounts = await _matchingClientAccounts(
      professionalId: professionalId,
      clientId: clientId,
      clientName: clientName,
      clientEmail: clientEmail,
    );

    for (final account in accounts) {
      final docRef = account.reference.collection('documents').doc(document.id);
      final doc = await docRef.get();
      if (doc.exists) await docRef.delete();
    }
  }

  Future<void> _deleteStoredFile(String storagePath) async {
    if (storagePath.trim().isEmpty) return;
    try {
      await storage.ref(storagePath).delete();
    } catch (_) {
      // The Firestore document can still be removed if the file was already
      // deleted, moved, or Storage is not configured yet.
    }
  }

  String _sharedDocumentStoragePath({
    required String sharedClientId,
    required String projectId,
    required String documentId,
    required String fileName,
  }) {
    final normalizedProjectId = projectId.trim().isEmpty
        ? 'general'
        : projectId.trim();
    return 'shared_clients/$sharedClientId/projects/$normalizedProjectId/documents/$documentId/$fileName';
  }

  Future<String> _sharedClientIdForAccountDoc({
    required QueryDocumentSnapshot<Map<String, dynamic>> account,
    required String professionalId,
    required String clientId,
    required String clientName,
    required String clientEmail,
  }) async {
    final accountData = account.data();
    final existingSharedClientId = '${accountData['sharedClientId'] ?? ''}'
        .trim();
    if (existingSharedClientId.isNotEmpty) return existingSharedClientId;

    var sharedClientId = await _findSharedClientIdFor(
      professionalId: professionalId,
      clientId: '${accountData['clientId'] ?? clientId}',
      clientEmail: '${accountData['email'] ?? clientEmail}',
    );

    if (sharedClientId.isEmpty) {
      sharedClientId = _generateToken();
      await _sharedClients.doc(sharedClientId).set({
        'ownerUid': professionalId,
        'professionalId': professionalId,
        'clientId': accountData['clientId'] ?? clientId,
        'clientName': accountData['displayName'] ?? clientName,
        'clientEmail': accountData['email'] ?? clientEmail,
        'status': 'claimed',
        'clientUid': account.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await account.reference.set({
      'sharedClientId': sharedClientId,
    }, SetOptions(merge: true));

    return sharedClientId;
  }

  Future<void> _createNotification({
    required String recipientUid,
    required String title,
    required String body,
    required String type,
    String projectId = '',
  }) async {
    if (recipientUid.trim().isEmpty) return;

    final docRef = firestore.collection('notifications').doc();
    try {
      await docRef.set({
        'id': docRef.id,
        'recipientUid': recipientUid,
        'title': title,
        'body': body,
        'type': type,
        'projectId': projectId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Notifications are useful, but they must never block the core action
      // that just succeeded, such as uploading a document or sending a message.
    }
  }

  Stream<List<ClientActionModel>> actionsStream() async* {
    try {
      yield* _professionalActionsStream();
    } catch (_) {
      yield* _clientAccountActionsStream();
    }
  }

  Stream<List<ClientActionModel>> _professionalActionsStream() async* {
    final account = await currentClientAccount();
    if (account == null || account.projectIds.isEmpty) {
      yield const <ClientActionModel>[];
      return;
    }

    yield* actionsStreamForAccount(account);
  }

  Stream<List<ClientActionModel>> actionsStreamForAccount(
    ClientAccountModel account,
  ) async* {
    final projectIds = (await _accessibleProjectIdsForAccount(
      account,
    )).where((projectId) => projectId.trim().isNotEmpty).take(30).toList();
    if (projectIds.isEmpty) {
      yield const <ClientActionModel>[];
      return;
    }

    yield* firestore
        .collection('users')
        .doc(account.professionalId)
        .collection('project_actions')
        .where('projectId', whereIn: projectIds)
        .where('visibleToClient', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final actions = snapshot.docs
              .map(
                (doc) =>
                    ClientActionModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .where((action) => action.visibleToClient)
              .toList();
          actions.sort(_compareClientActions);
          return actions;
        });
  }

  Stream<List<ClientActionModel>> _clientAccountActionsStream() {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _accounts
        .doc(uid)
        .collection('actions')
        .where('visibleToClient', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final actions = snapshot.docs
              .map(
                (doc) =>
                    ClientActionModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .where((action) => action.visibleToClient)
              .toList();
          actions.sort(_compareClientActions);
          return actions;
        });
  }

  int _compareClientActions(ClientActionModel a, ClientActionModel b) {
    if (a.status != b.status) return a.status == 'pending' ? -1 : 1;
    final aDate = a.dueDate ?? DateTime(9999);
    final bDate = b.dueDate ?? DateTime(9999);
    final dateCompare = aDate.compareTo(bDate);
    if (dateCompare != 0) return dateCompare;
    return a.title.compareTo(b.title);
  }

  Stream<List<TimelineEventModel>> timelineStream(String projectId) {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    final queryPath =
        'client_accounts/$uid/timeline where projectId == $projectId visibleToClient == true';

    // ignore: avoid_print
    print(
      '[client-progress] timeline started\n'
      'projectId=$projectId\n'
      'queryPath=$queryPath',
    );

    return _accounts
        .doc(uid)
        .collection('timeline')
        .where('projectId', isEqualTo: projectId)
        .where('visibleToClient', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final events = snapshot.docs
              .map((doc) => TimelineEventModel.fromJson(doc.data()))
              .toList();
          events.sort((a, b) => a.order.compareTo(b.order));
          // ignore: avoid_print
          print(
            '[client-progress] timeline count=${events.length}\n'
            'queryPath=$queryPath',
          );
          return events;
        })
        .handleError((error) {
          if (error is FirebaseException) {
            // ignore: avoid_print
            print(
              '[client-progress] timeline error\n'
              'FirebaseException.code=${error.code}\n'
              'FirebaseException.message=${error.message}\n'
              'queryPath=$queryPath',
            );
          } else {
            // ignore: avoid_print
            print(
              '[client-progress] timeline error\n'
              'error=$error\n'
              'queryPath=$queryPath',
            );
          }
        });
  }

  Stream<List<AppNotificationModel>> notificationsStream() {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => AppNotificationModel.fromJson(doc.data()))
              .toList();
          notifications.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return notifications;
        });
  }

  Stream<List<TaskModel>> tasksStream() async* {
    try {
      yield* _professionalTasksStream();
    } catch (_) {
      yield* _clientAccountTasksStream();
    }
  }

  Stream<List<TaskModel>> _professionalTasksStream() async* {
    final account = await currentClientAccount();
    if (account == null) {
      yield const <TaskModel>[];
      return;
    }

    yield* tasksStreamForAccount(account);
  }

  Stream<List<TaskModel>> tasksStreamForAccount(
    ClientAccountModel account,
  ) async* {
    final projectIds = (await _accessibleProjectIdsForAccount(
      account,
    )).where((projectId) => projectId.trim().isNotEmpty).take(30).toList();
    if (projectIds.isEmpty) {
      yield const <TaskModel>[];
      return;
    }

    yield* firestore
        .collection('users')
        .doc(account.professionalId)
        .collection('tasks')
        .where('projectId', whereIn: projectIds)
        .snapshots()
        .map((snapshot) {
          final allTasks = snapshot.docs
              .map((doc) => TaskModel.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
          final visibleTasks = allTasks
              .where((task) => task.isVisibleInClientPortal)
              .toList();
          final tasksByProject = <String, List<TaskModel>>{};
          for (final task in allTasks) {
            tasksByProject.putIfAbsent(task.projectId, () => []).add(task);
          }
          for (final projectId in projectIds) {
            final projectTasks = tasksByProject[projectId] ?? const [];
            final projectVisibleTasks = projectTasks
                .where((task) => task.isVisibleInClientPortal)
                .toList();
            final internalTasks = projectTasks
                .where((task) => task.internal || task.isPrivate)
                .length;
            final assignedToClient = projectVisibleTasks
                .where((task) => task.isAssignedToClient)
                .length;
            // ignore: avoid_print
            print(
              '[client-tasks]\n'
              'projectId=$projectId\n'
              'tasksFound=${projectTasks.length}\n'
              'visibleTasks=${projectVisibleTasks.length}\n'
              'internalTasks=$internalTasks\n'
              'assignedToClient=$assignedToClient',
            );
          }
          visibleTasks.sort(_compareClientTasks);
          return visibleTasks;
        });
  }

  Stream<List<TaskModel>> _clientAccountTasksStream() {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _accounts
        .doc(uid)
        .collection('tasks')
        .where('visibleToClient', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs
              .map((doc) => TaskModel.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
          tasks.sort(_compareClientTasks);
          return tasks;
        });
  }

  int _compareClientTasks(TaskModel a, TaskModel b) {
    final projectCompare = a.projectName.compareTo(b.projectName);
    if (projectCompare != 0) return projectCompare;
    return _taskStatusRank(a.status).compareTo(_taskStatusRank(b.status));
  }

  int _taskStatusRank(String status) {
    switch (status) {
      case 'À faire':
        return 0;
      case 'En cours':
        return 1;
      case 'Terminé':
        return 2;
      default:
        return 3;
    }
  }

  String _generateToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _mimeTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }

  String _deliverableValidationActionId(
    String deliverableId,
    int versionNumber,
  ) {
    return 'deliverable_${deliverableId}_v${versionNumber}_validation';
  }
}
