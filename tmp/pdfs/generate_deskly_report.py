from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


OUTPUT = "output/pdf/rapport-final-deskly.pdf"

PRIMARY = colors.HexColor("#31BB80")
PRIMARY_DARK = colors.HexColor("#249967")
DEEP = colors.HexColor("#203E40")
BG = colors.HexColor("#F6F8F7")
SOFT = colors.HexColor("#EEF5F2")
BORDER = colors.HexColor("#DDE7E3")
TEXT = colors.HexColor("#162625")
MUTED = colors.HexColor("#687A77")
WARNING = colors.HexColor("#D97706")
ERROR = colors.HexColor("#DC2626")


class ReportDoc(BaseDocTemplate):
    def __init__(self, filename):
        super().__init__(
            filename,
            pagesize=A4,
            rightMargin=1.55 * cm,
            leftMargin=1.55 * cm,
            topMargin=1.6 * cm,
            bottomMargin=1.5 * cm,
            title="Rapport final Deskly",
            author="Codex",
        )
        frame = Frame(
            self.leftMargin,
            self.bottomMargin,
            self.width,
            self.height,
            id="normal",
        )
        self.addPageTemplates(
            [PageTemplate(id="deskly", frames=[frame], onPage=self._footer)]
        )

    def _footer(self, canvas, doc):
        canvas.saveState()
        canvas.setFillColor(MUTED)
        canvas.setFont("Helvetica", 8)
        canvas.drawString(self.leftMargin, 0.8 * cm, "Deskly - Rapport final technique et produit")
        canvas.drawRightString(A4[0] - self.rightMargin, 0.8 * cm, f"Page {doc.page}")
        canvas.restoreState()


styles = getSampleStyleSheet()
styles.add(
    ParagraphStyle(
        name="CoverTitle",
        parent=styles["Title"],
        fontName="Helvetica-Bold",
        fontSize=31,
        leading=36,
        textColor=DEEP,
        alignment=TA_CENTER,
        spaceAfter=18,
    )
)
styles.add(
    ParagraphStyle(
        name="CoverSub",
        parent=styles["BodyText"],
        fontSize=13,
        leading=19,
        textColor=MUTED,
        alignment=TA_CENTER,
        spaceAfter=14,
    )
)
styles.add(
    ParagraphStyle(
        name="H1Deskly",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=19,
        leading=24,
        textColor=DEEP,
        spaceBefore=14,
        spaceAfter=8,
    )
)
styles.add(
    ParagraphStyle(
        name="H2Deskly",
        parent=styles["Heading2"],
        fontName="Helvetica-Bold",
        fontSize=13,
        leading=17,
        textColor=TEXT,
        spaceBefore=9,
        spaceAfter=5,
    )
)
styles.add(
    ParagraphStyle(
        name="BodyDeskly",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=9.5,
        leading=14,
        textColor=TEXT,
        spaceAfter=6,
    )
)
styles.add(
    ParagraphStyle(
        name="SmallDeskly",
        parent=styles["BodyText"],
        fontSize=8.5,
        leading=12,
        textColor=MUTED,
    )
)
styles.add(
    ParagraphStyle(
        name="Callout",
        parent=styles["BodyText"],
        fontName="Helvetica-Bold",
        fontSize=10,
        leading=14,
        textColor=DEEP,
        backColor=SOFT,
        borderColor=BORDER,
        borderWidth=0.8,
        borderPadding=8,
        spaceBefore=6,
        spaceAfter=10,
    )
)


def p(text, style="BodyDeskly"):
    return Paragraph(text, styles[style])


def bullets(items):
    return ListFlowable(
        [ListItem(p(item, "BodyDeskly"), leftIndent=10) for item in items],
        bulletType="bullet",
        leftIndent=14,
        bulletFontName="Helvetica",
        bulletFontSize=6,
        bulletColor=PRIMARY_DARK,
    )


def section(title):
    return p(title, "H1Deskly")


def sub(title):
    return p(title, "H2Deskly")


def status(value):
    if value == "OK":
        return '<font color="#249967"><b>OK</b></font>'
    if value == "PARTIEL":
        return '<font color="#D97706"><b>PARTIEL</b></font>'
    if value == "RISQUE":
        return '<font color="#DC2626"><b>RISQUE</b></font>'
    return value


def table(data, widths=None, header=True):
    body = [[p(str(cell), "BodyDeskly") for cell in row] for row in data]
    t = Table(body, colWidths=widths, hAlign="LEFT", repeatRows=1 if header else 0)
    style = [
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("BOX", (0, 0), (-1, -1), 0.6, BORDER),
        ("INNERGRID", (0, 0), (-1, -1), 0.35, BORDER),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]
    if header:
        style.extend(
            [
                ("BACKGROUND", (0, 0), (-1, 0), DEEP),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ]
        )
    t.setStyle(TableStyle(style))
    return t


story = []

story += [
    Spacer(1, 4.5 * cm),
    p("deskly", "CoverTitle"),
    p("Rapport final complet et factuel", "CoverTitle"),
    p(
        "Audit produit, architecture Flutter, Firebase, synchronisation pro-client, "
        "qualite et feuille de route.",
        "CoverSub",
    ),
    Spacer(1, 0.8 * cm),
    table(
        [
            ["Application", "Deskly / ClientFlow Pro"],
            ["Repository analyse", "/Users/david/dev/flutter_projects/clientflow_pro"],
            ["Date", "10 septembre 2026"],
            ["Mode", "Lecture seule - aucune modification fonctionnelle"],
            ["Validation", "flutter analyze: OK - flutter test: 33 tests passes"],
        ],
        widths=[4.2 * cm, 11.2 * cm],
        header=False,
    ),
    PageBreak(),
]

story += [
    section("1. Resume produit"),
    p(
        "Deskly est une application Flutter de gestion client/projet destinee aux "
        "professionnels, petites entreprises, artisans, agences et independants. Elle "
        "centralise clients, projets, taches, actions prioritaires, portail client, "
        "messagerie, documents, demandes de documents, validations, timeline, PDF, "
        "notifications internes et themes clair/sombre."
    ),
    p(
        "Le produit va au-dela d'un CRM simple : il construit un espace de collaboration "
        "entre professionnel et client autour de l'avancement, des documents, des messages "
        "et des elements a valider."
    ),
    section("2. Parcours global"),
    bullets(
        [
            "Demarrage par SplashPage, puis orientation selon Firebase Auth et role detecte.",
            "Parcours public : onboarding, choix de role, connexion pro, inscription pro, connexion client, invitation client, suivi par code.",
            "Parcours professionnel : dashboard, clients, projets, taches, messages, reglages.",
            "Parcours client : accueil, avancement, messages, documents, profil, detail projet et validations.",
            "GoRouter applique une thematisation separee : AppRoleTheme.professional et AppRoleTheme.client.",
        ]
    ),
    sub("Routes principales"),
    table(
        [
            ["Zone", "Routes"],
            ["Public", "/, /onboarding, /role-choice, /login, /register, /track, /client/login, /client/invite"],
            ["Professionnel", "/main, /clients/add, /clients/:clientId, /projects/add, /projects/:projectId, /tasks/add, /messages, /settings"],
            ["Client", "/client/home, /client/progress, /client/messages, /client/documents, /client/profile, /client/projects/:projectId"],
        ],
        widths=[3.2 * cm, 12.8 * cm],
    ),
]

story += [
    section("3. Authentification et roles"),
    p(
        "Firebase Authentication est utilise pour les comptes professionnels et clients. "
        "Le role est determine par users/{uid}.role lorsque disponible, puis par la presence "
        "d'un document client_accounts/{uid}."
    ),
    table(
        [
            ["Element", "Constat"],
            ["Compte professionnel", "Cree dans users/{uid} avec role professional, nom, email et createdAt."],
            ["Compte client", "Cree depuis un code d'invitation, puis lie a client_accounts/{clientUid}."],
            ["Invitation", "client_invitations/{token} et compatibilite legacy avec shared_clients/{token}."],
            ["Session", "GoRouterRefreshStream ecoute authStateChanges et redirige selon le role."],
            ["Champs client clefs", "uid, clientId, professionalId, email, displayName, role, projectIds, sharedClientId."],
        ],
        widths=[4.2 * cm, 11.8 * cm],
    ),
    p(
        "Fichiers principaux : lib/data/services/auth_service.dart, "
        "lib/data/services/client_portal_service.dart, "
        "lib/data/models/client_account_model.dart."
    ),
]

story += [
    section("4. Espace professionnel"),
    sub("Dashboard"),
    bullets(
        [
            "Affiche l'accueil professionnel, les KPI, l'etat des projets, les actions prioritaires, Morning Brief et activite client si disponible.",
            "Project Pulse est presente en UI comme etat des projets : en bonne voie, en attente client, a surveiller.",
            "Les donnees viennent des providers clients, projets, taches, actions, documents et pulse.",
        ]
    ),
    sub("Clients"),
    bullets(
        [
            "Liste avec recherche, filtres, FAB compact, compteur clients/actifs.",
            "Fiche client structuree en Vue d'ensemble, Projets, Documents, Portail.",
            "Notes independantes avec creation, modification et suppression.",
            "Portail client affiche directement statut, explication du code, code, copie code/lien et revocation.",
        ]
    ),
    sub("Projets"),
    bullets(
        [
            "Liste projets avec recherche, filtres de statut, detail projet et export PDF.",
            "Creation manuelle ou via templates.",
            "Detail projet : Synthese, Travail, Validations.",
            "Validations remplace Livrables dans l'interface, mais les modeles techniques restent Deliverable.",
        ]
    ),
    sub("Taches, messages, documents, reglages"),
    bullets(
        [
            "Taches pro dans users/{professionalUid}/tasks, avec synchronisation portail client.",
            "Messages pro/client via shared_clients/{sharedClientId}/messages.",
            "Documents : demandes de documents, upload, validation/refus, suppression selon l'interface actuelle.",
            "Reglages : profil, theme, notifications, legal, deconnexion.",
        ]
    ),
]

story += [
    section("5. Espace client"),
    table(
        [
            ["Page", "Role actuel"],
            ["Accueil", "Projet principal, progression, etape actuelle/prochaine, actions a faire, documents a fournir."],
            ["Avancement", "Detail du projet cote client avec synthese, travail, validations et timeline visible."],
            ["Messages", "Conversation avec le professionnel via le meme fil shared_clients que le pro."],
            ["Documents", "Demandes de documents et envoi de fichiers par le client."],
            ["Validations", "Elements a valider, versions, ouverture fichier/lien, validation ou demande de modification."],
            ["Profil", "Compte client, projets accessibles, deconnexion."],
            ["Notifications", "Notifications in-app Firestore filtrees par recipientUid."],
        ],
        widths=[3.8 * cm, 12.2 * cm],
    ),
    p(
        "Le portail client possede une identite visuelle dediee, plus calme, avec ClientTheme "
        "et AppRoleTheme.client."
    ),
]

story += [
    section("6. Synchronisation pro-client"),
    table(
        [
            ["Donnee", "Source principale", "Lecture client", "Etat"],
            ["Projets", "users/{proUid}/projects", "Meme projet via clientId/projectIds/sharedClientId", status("OK")],
            ["Taches", "users/{proUid}/tasks", "Filtrees par internal/private", status("OK")],
            ["Actions", "users/{proUid}/project_actions", "visibleToClient et assignedTo client", status("OK")],
            ["Messages", "shared_clients/{sharedClientId}/messages", "Meme thread pro/client", status("OK")],
            ["Documents", "Storage partage + client_accounts/{clientUid}/documents", "Architecture hybride", status("PARTIEL")],
            ["Validations", "users/{proUid}/deliverables et deliverable_versions", "Meme source lue par client", status("PARTIEL")],
            ["Timeline", "users/{proUid}/timeline + copie client_accounts", "Copie visible client", status("PARTIEL")],
            ["Notifications", "notifications", "recipientUid", status("OK")],
        ],
        widths=[2.9 * cm, 4.7 * cm, 5.5 * cm, 2.4 * cm],
    ),
]

story += [
    section("7. Firebase et backend"),
    sub("Configuration"),
    bullets(
        [
            "Projet Firebase configure : app-clientflow-pro.",
            "Bucket configure : app-clientflow-pro.firebasestorage.app.",
            "firebase_options.dart et GoogleService-Info.plist iOS correspondent au meme projet.",
            "firebase.json pointe vers firestore.rules et storage.rules.",
        ]
    ),
    sub("Collections observees"),
    table(
        [
            ["Collection", "Usage"],
            ["users/{uid}", "Profil utilisateur et role."],
            ["users/{uid}/clients", "Clients du professionnel."],
            ["users/{uid}/projects", "Projets source cote professionnel."],
            ["users/{uid}/tasks", "Taches source cote professionnel."],
            ["users/{uid}/project_actions", "Action Center."],
            ["users/{uid}/document_requests", "Demandes de documents source pro."],
            ["users/{uid}/deliverables", "Validations/livrables."],
            ["users/{uid}/deliverable_versions", "Versions de validations."],
            ["users/{uid}/deliverable_annotations", "Annotations visuelles."],
            ["client_accounts/{clientUid}", "Compte portail client."],
            ["shared_clients/{sharedClientId}/messages", "Messagerie commune."],
            ["shared_projects/{shareId}", "Snapshots publics de suivi par code."],
            ["notifications", "Notifications internes."],
        ],
        widths=[6.2 * cm, 9.8 * cm],
    ),
    p(
        "Risque P0 : storage.rules est encore en regle temporaire ultra-ciblee sur "
        "shared_clients/9AVELB avec deux UID codes en dur. Cette regle est utile au diagnostic "
        "mais ne doit pas partir en production.",
        "Callout",
    ),
]

story += [
    section("8. Architecture Flutter"),
    bullets(
        [
            "Architecture par features : auth, dashboard, clients, projects, tasks, messages, client_portal, documents, deliverables, notifications, timeline, settings.",
            "Riverpod structure les repositories, services, controllers et providers d'ecran.",
            "GoRouter gere les routes et redirections role-based.",
            "FirestoreService centralise les collections utilisateur professionnelles via users/{uid}/{collection}.",
            "Les modeles sont simples, serialisables, avec getters utiles et copyWith sur les donnees evolutives.",
        ]
    ),
    section("9. Technologies et packages"),
    table(
        [
            ["Package", "Usage"],
            ["flutter_riverpod", "State management et providers."],
            ["go_router", "Navigation et redirections."],
            ["firebase_core", "Initialisation Firebase."],
            ["firebase_auth", "Authentification pro/client."],
            ["cloud_firestore", "Base de donnees temps reel."],
            ["firebase_storage", "Fichiers documents/validations."],
            ["file_picker", "Selection de fichiers."],
            ["url_launcher", "Ouverture liens/fichiers externes."],
            ["pdf + printing", "Generation et partage PDF projet."],
            ["shared_preferences / flutter_secure_storage", "Preferences et donnees locales sensibles."],
        ],
        widths=[5.2 * cm, 10.8 * cm],
    ),
]

story += [
    section("10. UI/UX et design system"),
    p(
        "Les couleurs sont centralisees dans AppTheme et AppRoleTheme. Le cote pro garde "
        "l'identite Deskly mint/teal. Le cote client utilise un background plus calme, des "
        "surfaces douces et reserve le vert principal aux CTA, progressions et etats actifs."
    ),
    table(
        [
            ["Zone", "Palette dominante"],
            ["Professionnel", "#31BB80, #203E40, #F6F8F7, #FFFFFF, #DDE7E3"],
            ["Client", "#F4F8F6, #203E40, #70827D, #2B5954, #6FAE96, #31BB80"],
            ["Composants", "Cards, search field, filter tabs, badges, notification bell, empty states, header buttons."],
        ],
        widths=[3.7 * cm, 12.3 * cm],
    ),
    section("11. Progression et statut projet"),
    p(
        "La source technique actuelle est ProjectTimelineProgressService. Elle calcule "
        "project.progress et project.status a partir de timeline events, actions et taches. "
        "Le statut derive de la progression : 0% = Planifie, entre 0% et 100% = En cours, "
        "100% = Termine."
    ),
    p(
        "Ecart produit a noter : une demande precedente visait une progression basee uniquement "
        "sur les etapes. Le code actuel combine etapes, actions et taches. Il faut trancher cette "
        "regle avant production.",
        "Callout",
    ),
]

story += [
    section("12. Project Templates"),
    p(
        "Les templates sont configures localement dans lib/data/templates/project_templates.dart. "
        "Ils peuvent creer un projet, une timeline, des taches, des actions client et des demandes "
        "de documents dans un batch Firestore."
    ),
    table(
        [
            ["Template", "Contenu typique"],
            ["Site internet", "Brief, contenus, maquette, validation, developpement, recette, livraison."],
            ["Identite visuelle", "Brief, moodboard, pistes creatives, validation, livraison des fichiers."],
            ["Application mobile", "Cadrage, UX/UI, developpement, tests, publication."],
            ["Shooting photo", "Existe dans le code mais peut ne pas etre affiche dans la selection actuelle."],
            ["Projet architecture", "Existe dans le code mais peut ne pas etre affiche dans la selection actuelle."],
            ["Campagne marketing", "Existe dans le code mais peut ne pas etre affiche dans la selection actuelle."],
            ["Personnalise", "Garde le comportement manuel sans template."],
        ],
        widths=[4.4 * cm, 11.6 * cm],
    ),
]

story += [
    section("13. Tests et qualite"),
    p("Commandes executees pendant l'audit :"),
    table(
        [
            ["Commande", "Resultat"],
            ["flutter analyze", "No issues found - execution OK."],
            ["flutter test", "33 tests passes - All tests passed."],
        ],
        widths=[4.2 * cm, 11.8 * cm],
    ),
    sub("Tests presents"),
    bullets(
        [
            "client_note_model_test.dart",
            "client_portal_models_test.dart",
            "deliverable_annotation_model_test.dart",
            "deliverable_models_test.dart",
            "document_request_model_test.dart",
            "morning_brief_model_test.dart",
            "project_pulse_service_test.dart",
            "project_templates_test.dart",
            "project_timeline_progress_service_test.dart",
            "project_waiting_status_service_test.dart",
            "timeline_event_model_test.dart",
            "widget_test.dart",
        ]
    ),
    sub("Limites de couverture"),
    bullets(
        [
            "Peu ou pas de tests d'integration Firebase reels.",
            "Pas de parcours E2E complet professionnel vers client.",
            "Regles Firestore/Storage non testees automatiquement.",
            "Peu de tests UI complexes sur les formulaires et modales.",
        ]
    ),
]

story += [
    section("14. Etat fonctionnel aujourd'hui"),
    table(
        [
            ["Fonction", "Etat", "Commentaire"],
            ["Auth pro", status("OK"), "Creation et connexion presentes."],
            ["Auth client invitation", status("OK"), "Code invitation et compte client presents."],
            ["Clients", status("OK"), "Liste, fiche, notes, portail."],
            ["Projets", status("OK"), "Creation, liste, detail, synchronisation."],
            ["Taches pro/client", status("OK"), "Client lit les taches non internes/privees."],
            ["Messagerie", status("OK"), "Source commune shared_clients/messages."],
            ["Actions client", status("PARTIEL"), "Fonctionnelle mais dependante de regles complexes."],
            ["Documents", status("PARTIEL"), "Upload Storage OK en diagnostic, Firestore hybride."],
            ["Validations", status("PARTIEL"), "Flux present mais historique de bugs permission/lifecycle."],
            ["Timeline", status("PARTIEL"), "Donnees visibles, mais copie client encore utilisee."],
            ["PDF projet", status("OK"), "Service existant et branche UI detectee."],
            ["Notifications internes", status("OK"), "Firestore, badge non lu."],
            ["Regles Storage production", status("RISQUE"), "Regle temporaire codee en dur."],
        ],
        widths=[4.2 * cm, 2.8 * cm, 9.0 * cm],
    ),
]

story += [
    section("15. Bugs et limites actuelles"),
    bullets(
        [
            "storage.rules est volontairement temporaire et limite a shared_clients/9AVELB avec deux UID fixes.",
            "Certaines donnees client sont encore miroir/copie dans client_accounts, ce qui peut creer des decalages.",
            "La progression actuelle combine timeline, actions et taches au lieu d'etre strictement basee sur les etapes.",
            "Des logs temporaires restent visibles dans les providers/services client.",
            "Les regles Firestore sont puissantes mais difficiles a maintenir sans tests de securite automatises.",
            "shared_projects et shared_clients ont des lectures publiques par code, a valider selon le niveau de confidentialite attendu.",
            "Les validations ont connu des problemes de permissions et de lifecycle Flutter ; le flux existe mais doit etre teste E2E.",
        ]
    ),
    section("16. Differenciateurs produit"),
    bullets(
        [
            "Portail client separe de l'espace professionnel.",
            "Actions client/professionnel pour comprendre qui bloque le projet.",
            "Demandes de documents structurees.",
            "Validations de livrables avec versions.",
            "Timeline projet visible cote client.",
            "Project Pulse et Morning Brief.",
            "Messagerie integree au contexte client/projet.",
            "Rapport PDF projet.",
        ]
    ),
]

story += [
    section("17. Valeur commerciale"),
    p(
        "Deskly repond a un probleme clair : reduire les allers-retours disperses entre "
        "email, WhatsApp, Drive et messages informels. L'app donne au professionnel un centre "
        "de pilotage et au client un espace clair pour suivre, fournir, valider et communiquer."
    ),
    table(
        [
            ["Cible", "Valeur"],
            ["Freelances", "Centraliser clients, projets, validations et relances."],
            ["Agences", "Structurer la relation client et les documents."],
            ["Artisans / petites entreprises", "Offrir un suivi professionnel sans outil complexe."],
            ["Architectes / designers", "Partager et valider des etapes, documents et livrables."],
        ],
        widths=[4.5 * cm, 11.5 * cm],
    ),
    section("18. Competences techniques demontrees"),
    bullets(
        [
            "Flutter multi-ecrans avec architecture par feature.",
            "Riverpod, AsyncNotifier, FutureProvider et StreamProvider.",
            "GoRouter avec redirection selon role.",
            "Firebase Auth, Firestore, Storage et rules.",
            "Synchronisation temps reel pro-client.",
            "Upload fichiers, generation PDF, notifications internes.",
            "Modeles, repositories, services et tests unitaires.",
        ]
    ),
]

story += [
    section("19. Roadmap recommandee"),
    table(
        [
            ["Priorite", "Actions recommandees"],
            ["P0", "Remplacer storage.rules temporaire par regles dynamiques securisees. Nettoyer logs temporaires. Verifier validations/documents en E2E. Ajouter tests de rules Firebase."],
            ["P1", "Choisir la source exacte de progression. Simplifier les miroirs client_accounts. Ajouter tests integration pro-client. Stabiliser ouverture fichiers PDF/images."],
            ["P2", "Notifications push FCM. Back-office templates. Annotations PDF. Analytics produit. Activity feed complet."],
        ],
        widths=[2.5 * cm, 13.5 * cm],
    ),
    PageBreak(),
    section("20. Plan pour un futur PDF commercial"),
    bullets(
        [
            "Couverture Deskly avec proposition de valeur.",
            "Probleme marche et cible.",
            "Solution et parcours pro/client.",
            "Fonctionnalites clefs illustrees par captures.",
            "Architecture technique simplifiee.",
            "Securite Firebase et qualite.",
            "Roadmap et conclusion commerciale.",
        ]
    ),
    p(
        "Conclusion : Deskly possede deja une base produit ambitieuse et differenciante. "
        "Avant une demonstration fiable, la priorite est de stabiliser Storage, reduire les "
        "duplications de donnees et valider le parcours complet pro-client.",
        "Callout",
    ),
]


doc = ReportDoc(OUTPUT)
doc.build(story)
print(OUTPUT)
