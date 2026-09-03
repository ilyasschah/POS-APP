// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get setSerialPort => 'Port série';

  @override
  String get setDisplayCharset => 'Jeu de caractères de l\'afficheur';

  @override
  String get setDisplayCharsetHint =>
      'Ce que le micrologiciel de l\'afficheur sait afficher — il s\'agit du matériel, pas de la langue de l\'application. Essayez d\'abord Arabe (Windows-1256) ; ne choisissez l\'option inversée que si l\'afficheur écrit les mots arabes à l\'envers.';

  @override
  String get charsetAscii => 'Simple (accents simplifiés)';

  @override
  String get charsetLatin1 => 'Europe de l\'Ouest (accents conservés)';

  @override
  String get charsetArabic => 'Arabe (Windows-1256)';

  @override
  String get charsetArabicVisual =>
      'Arabe, inversé (seulement si les mots sont à l\'envers)';

  @override
  String get printerConnection => 'Connexion';

  @override
  String get printerConnectionSystem => 'Cet ordinateur (imprimante Windows)';

  @override
  String get printerConnectionSystemUnavailable =>
      'Cet appareil (ouvre la boîte de dialogue d\'impression)';

  @override
  String get printerConnectionNetwork => 'Imprimante réseau (Wi-Fi / LAN)';

  @override
  String get printerConnectionHint =>
      'Une imprimante réseau imprime sans boîte de dialogue, sur les tablettes comme sur cet ordinateur.';

  @override
  String get printerConnectionHintMobile =>
      'Cet appareil ne peut pas imprimer directement sur une imprimante système — il ne peut qu\'ouvrir la boîte de dialogue. Choisissez Imprimante réseau et saisissez son adresse.';

  @override
  String get printerHost => 'Adresse de l\'imprimante';

  @override
  String get printerTcpPort => 'Port';

  @override
  String get poleDisplayTotalDue => 'TOTAL A PAYER';

  @override
  String get poleDisplayWelcome => 'BIENVENUE !';

  @override
  String get portNoneDetected => 'Aucun détecté';

  @override
  String get portNoneDetectedHint =>
      'Cette machine ne signale aucun port COM ou LPT. Vérifiez le câble et le Gestionnaire de périphériques, puis rouvrez cet écran.';

  @override
  String portNotDetected(String port) {
    return '$port (non détecté)';
  }

  @override
  String get portRefresh => 'Actualiser les ports';

  @override
  String get registerChoose => 'Choisir la caisse';

  @override
  String get registerSubtitle =>
      'La caisse que cet appareil utilise. Les appareils sur la même caisse partagent sa session ouverte, ses documents et son tiroir.';

  @override
  String get registerThisDeviceOnly => 'Cet appareil uniquement';

  @override
  String get registerThisDeviceOnlyHint =>
      'Sa propre session, partagée avec rien d’autre.';

  @override
  String get registerTrading => 'Session ouverte';

  @override
  String get registerIdle => 'Aucune session ouverte';

  @override
  String get registerNew => 'Nouvelle caisse';

  @override
  String get registerNameHint => 'ex. Caisse principale';

  @override
  String get registerListOffline =>
      'Impossible de charger les caisses. Choisir une caisse partagée nécessite une connexion.';

  @override
  String get registerSwitchBlocked =>
      'Fermez la session de cette caisse avant de changer. Partir maintenant la laisserait ouverte, sans moyen d’y revenir d’ici.';

  @override
  String get setRegister => 'Caisse';

  @override
  String get sessionJoinRegister => 'Vendre dans cette session';

  @override
  String get sessionJoinTitle => 'Utiliser cette caisse ?';

  @override
  String sessionJoinBody(String register, String session) {
    return 'Cet appareil va travailler sur $register. Les ventes que vous saisissez iront dans la session $session, avec tous les autres terminaux — et n’importe lequel peut la fermer.';
  }

  @override
  String get sessionJoinBlocked =>
      'Cet appareil a déjà sa propre session ouverte. Fermez-la avant de passer à une autre caisse, sinon elle reste ouverte sans que rien ne puisse l’atteindre.';

  @override
  String get sessionJoinNoRegister =>
      'Cette session n’a pas fini de se synchroniser : la caisse à laquelle elle appartient n’est pas encore connue ici. Synchronisez puis réessayez.';

  @override
  String get sessionJoinOpenElsewhere =>
      'Une autre caisse a déjà une session ouverte. Vendez dans celle-là plutôt que d’en démarrer une seconde.';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionSaveChanges => 'Enregistrer les modifications';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionEdit => 'Modifier';

  @override
  String get actionAdd => 'Ajouter';

  @override
  String get actionClose => 'Fermer';

  @override
  String get actionConfirm => 'Confirmer';

  @override
  String get actionRetry => 'Réessayer';

  @override
  String get actionSearch => 'Rechercher';

  @override
  String get actionRemove => 'Retirer';

  @override
  String get actionUpload => 'Téléverser';

  @override
  String get actionSkip => 'Passer';

  @override
  String get deviceRegistrationTitle => 'Enregistrement de l\'appareil';

  @override
  String get deviceRegistrationSubtitle =>
      'Connectez-vous avec votre compte pour lier ce terminal';

  @override
  String get fieldEmail => 'E-mail';

  @override
  String get fieldPassword => 'Mot de passe';

  @override
  String get developerMode => 'Mode développeur';

  @override
  String get unlinkDeviceConfirm =>
      'Voulez-vous vraiment dissocier cet appareil ?';

  @override
  String get unlinkDevice => 'Dissocier l\'appareil';

  @override
  String get timeClock => 'POINTAGE';

  @override
  String get roleAdmin => 'Administrateur';

  @override
  String get roleCashier => 'Caissier';

  @override
  String get reloadUsers => 'Recharger les utilisateurs';

  @override
  String get relinkDevice => 'Relier l\'appareil';

  @override
  String get couldNotLoadUsers =>
      'Impossible de charger les utilisateurs sur ce terminal.';

  @override
  String get noUsersCached => 'Aucun utilisateur en cache sur ce terminal.';

  @override
  String get restoringUsersFromServer =>
      'Restauration des utilisateurs depuis le serveur…';

  @override
  String get reconnectToRestoreUsers =>
      'Reconnectez-vous pour les restaurer, ou reliez à nouveau cet appareil pour vous connecter.';

  @override
  String get actionYes => 'Oui';

  @override
  String get actionNo => 'Non';

  @override
  String get actionApply => 'Appliquer';

  @override
  String get actionContinue => 'Continuer';

  @override
  String get actionSet => 'Définir';

  @override
  String get actionSwitch => 'Changer';

  @override
  String get actionProceedAnyway => 'Continuer quand même';

  @override
  String deleteProductsConfirm(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count produits ? Cette action est irréversible.',
      one: 'Supprimer 1 produit ? Cette action est irréversible.',
    );
    return '$_temp0';
  }

  @override
  String get colorMarkerHint =>
      'Colore la tuile du produit dans le menu et la liste des produits.';

  @override
  String get modifiersHint =>
      'Ajoutez des notes comme « Très épicé » ou « Contient des noix ».';

  @override
  String get barcodesHint =>
      'Attribuez plusieurs codes-barres (article, boîte ou palette).';

  @override
  String get importComplete => 'Import terminé';

  @override
  String get documentCreated => 'Document créé : ';

  @override
  String importErrorCount(num count) {
    return '$count erreur(s) :';
  }

  @override
  String get importTitle => 'Importer';

  @override
  String get selectFile => 'Choisir un fichier';

  @override
  String get indicatesRequiredField => '* Indique un champ obligatoire';

  @override
  String get skipColumn => '(Ignorer)';

  @override
  String get duplicatesQuestion => 'Que faire en cas de doublons ?';

  @override
  String get createDocumentFromQuantity =>
      'Créer un document à partir de la quantité indiquée';

  @override
  String get actionPreview => 'Aperçu';

  @override
  String get fieldName => 'Nom';

  @override
  String get fieldProductGroup => 'Groupe de produits';

  @override
  String get fieldSku => 'SKU';

  @override
  String get fieldMeasurementUnit => 'Unité de mesure';

  @override
  String get fieldCost => 'Coût';

  @override
  String get fieldMarkup => 'Majoration';

  @override
  String get fieldTax => 'Taxe';

  @override
  String get fieldTaxInclusivePrice => 'Prix taxes comprises';

  @override
  String get fieldPriceChangeAllowed => 'Modification du prix autorisée';

  @override
  String get fieldUsingDefaultQuantity => 'Utilise la quantité par défaut';

  @override
  String get fieldServiceNotStock => 'Service (sans gestion de stock)';

  @override
  String get fieldEnabled => 'Activé';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldQuantity => 'Quantité';

  @override
  String get fieldSupplier => 'Fournisseur';

  @override
  String get fieldReorderPoint => 'Seuil de réapprovisionnement';

  @override
  String get fieldPreferredQuantity => 'Quantité souhaitée';

  @override
  String get fieldLowStockWarning => 'Alerte de stock faible';

  @override
  String get fieldLowStockWarningQuantity =>
      'Quantité d\'alerte de stock faible';

  @override
  String get cannotDelete => 'Suppression impossible';

  @override
  String get deleteGroup => 'Supprimer le groupe';

  @override
  String deleteGroupConfirm(String name) {
    return 'Voulez-vous vraiment supprimer « $name » ?';
  }

  @override
  String get productGroups => 'Groupes de produits';

  @override
  String get newGroup => 'Nouveau groupe';

  @override
  String get deleteGroupTooltip => 'Supprimer le groupe';

  @override
  String get failedToLoadGroups => 'Échec du chargement des groupes';

  @override
  String get noneRoot => 'Aucun (racine)';

  @override
  String get chooseImage => 'Choisir une image';

  @override
  String get searchProductsEllipsis => 'Rechercher des produits…';

  @override
  String get failedToLoadProducts => 'Échec du chargement des produits';

  @override
  String get noProductsFoundShort => 'Aucun produit trouvé';

  @override
  String get noProductGroupsYet => 'Aucun groupe de produits';

  @override
  String get createOneToOrganize => 'Créez-en un pour organiser vos produits';

  @override
  String get createGroup => 'Créer un groupe';

  @override
  String get customersLabel => 'Clients';

  @override
  String get customerLabel => 'Client';

  @override
  String get languageLabel => 'Langue';

  @override
  String get categoriesLabel => 'Catégories';

  @override
  String get errorLabel => 'Erreur';

  @override
  String get accountUserEmail => 'Compte / e-mail utilisateur';

  @override
  String get dateFormatLabel => 'Format de date';

  @override
  String get accessLevel => 'Niveau d\'accès';

  @override
  String get actions => 'Actions';

  @override
  String get addFirstUser => 'Ajouter un premier utilisateur';

  @override
  String get addNewUser => 'Ajouter un utilisateur';

  @override
  String get addPayment => 'Ajouter un paiement';

  @override
  String get addUser => 'Ajouter un utilisateur';

  @override
  String get adminResetDevicePin => 'Admin : réinitialiser le PIN';

  @override
  String get adminResetPassword => 'Admin : réinitialiser le mot de passe';

  @override
  String get filterAll => 'Tous';

  @override
  String get allCustomers => 'Tous les clients';

  @override
  String get allDocumentTypes => 'Tous les types de document';

  @override
  String get allTransactions => 'Toutes les transactions';

  @override
  String get allUsers => 'Tous les utilisateurs';

  @override
  String get allWarehouses => 'Tous les entrepôts';

  @override
  String get amount => 'Montant';

  @override
  String get assignToWarehouse => 'Affecter à un entrepôt';

  @override
  String get couldNotLoadRules => 'Impossible de charger les règles';

  @override
  String get colCreated => 'CRÉÉ';

  @override
  String get colCustomer => 'CLIENT';

  @override
  String get dateLabel => 'Date';

  @override
  String get deleteDocument => 'Supprimer le document';

  @override
  String get deleteRule => 'Supprimer la règle';

  @override
  String get deleteUser => 'Supprimer l\'utilisateur';

  @override
  String get colDisc => 'REM';

  @override
  String get discountBreakdown => 'Détail des remises';

  @override
  String get documentExplorer => 'Explorateur de documents';

  @override
  String get editRules => 'Modifier les règles';

  @override
  String get editUser => 'Modifier l\'utilisateur';

  @override
  String get errorLoadingTaxes => 'Erreur lors du chargement des taxes';

  @override
  String get excel => 'Excel';

  @override
  String get expirationDate => 'Date d\'expiration';

  @override
  String get expirationDateOptional => 'Date d\'expiration (facultatif)';

  @override
  String get firstName => 'Prénom';

  @override
  String get firstNameRequired => 'Prénom *';

  @override
  String get fixed => 'Fixe';

  @override
  String get idLabel => 'ID';

  @override
  String get initialQuantity => 'Quantité initiale';

  @override
  String get internalNote => 'NOTE INTERNE';

  @override
  String get inventoryMasterList => 'Liste principale de l\'inventaire';

  @override
  String get itemDiscount => 'Remise sur article';

  @override
  String get lastName => 'Nom';

  @override
  String get lastNameRequired => 'Nom *';

  @override
  String get lowStock => 'Stock faible';

  @override
  String get lowStockWarning => 'Alerte de stock faible';

  @override
  String get manageWarehouses => 'Gérer les entrepôts';

  @override
  String get markAsUnpaid => 'Marquer comme impayé ?';

  @override
  String get needsReorder => 'À réapprovisionner';

  @override
  String get colNew => 'NOUVEAU';

  @override
  String get newFourDigitPin => 'Nouveau PIN à 4 chiffres';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get newQuantity => 'Nouvelle quantité';

  @override
  String get noSecurityRules => 'Aucune règle de sécurité trouvée.';

  @override
  String get securityRulesIntro =>
      'Choisissez qui peut utiliser chaque partie du POS. Caissier : tout le monde ; Admin : uniquement un administrateur — un caissier qui essaie est invité à vous demander.';

  @override
  String securityRulesSummary(int total, int adminOnly) {
    return '$total règles · $adminOnly réservées à l\'admin';
  }

  @override
  String securityCategoryCount(int count, int restricted) {
    return '$count · $restricted réservées à l\'admin';
  }

  @override
  String get securityLevelCashierHint =>
      'Les caissiers et les admins peuvent le faire';

  @override
  String get securityLevelAdminHint => 'Seul un administrateur peut le faire';

  @override
  String get noTaxShort => 'Aucune taxe';

  @override
  String get noneLabel => 'Aucun';

  @override
  String get noteLabel => 'Note';

  @override
  String get colNumber => 'NUMÉRO';

  @override
  String get colOrderNo => 'N° COMMANDE';

  @override
  String get paid => 'Payé';

  @override
  String get partial => 'Partiel';

  @override
  String get passwordRequired => 'Mot de passe *';

  @override
  String get paymentType => 'Type de paiement';

  @override
  String get preferredQuantity => 'Quantité souhaitée';

  @override
  String get priceAfterTax => 'Prix (taxes comprises)';

  @override
  String get priceBeforeTax => 'Prix hors taxes';

  @override
  String get printStockReportPdf => 'Imprimer le rapport de stock (PDF)';

  @override
  String get productLabel => 'Produit';

  @override
  String get productRequired => 'Produit *';

  @override
  String get referenceDocument => 'Document de référence';

  @override
  String get removeStock => 'Retirer du stock';

  @override
  String get reorderPoint => 'Seuil de réapprovisionnement';

  @override
  String get reports => 'Rapports';

  @override
  String get ruleExistsEditing => 'La règle existe — modification';

  @override
  String get saveStockReportPdf => 'Enregistrer le rapport en PDF';

  @override
  String get searchProductNameOrCode => 'Rechercher un nom ou code produit…';

  @override
  String get searchReports => 'Rechercher des rapports';

  @override
  String get securityActions => 'Actions de sécurité';

  @override
  String get selectDocumentType => 'Choisir le type de document';

  @override
  String get selectReport => 'Choisir un rapport';

  @override
  String get showReport => 'Afficher le rapport';

  @override
  String get colStatus => 'STATUT';

  @override
  String get colSvc => 'SVC';

  @override
  String get syncAndRefresh => 'Synchroniser et actualiser';

  @override
  String get tabNotFound => 'Onglet introuvable';

  @override
  String get taxOptional => 'Taxe (facultatif)';

  @override
  String get taxAmount => 'Montant de la taxe';

  @override
  String get totalDiscounts => 'Total des remises';

  @override
  String get typeLabel => 'Type';

  @override
  String get unpaid => 'Impayé';

  @override
  String get updateItem => 'Mettre à jour l\'article';

  @override
  String get colUpdated => 'MIS À JOUR';

  @override
  String get colUser => 'UTILISATEUR';

  @override
  String get userRequired => 'Utilisateur *';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get usernameRequired => 'Nom d\'utilisateur *';

  @override
  String get usersAndSecurity => 'Utilisateurs et sécurité';

  @override
  String get valueTotal => 'Valeur (total)';

  @override
  String get warehouse => 'Entrepôt';

  @override
  String get warehouseRequired => 'Entrepôt *';

  @override
  String get warningThreshold => 'Seuil d\'alerte';

  @override
  String get yesDeletePayments => 'Oui, supprimer les paiements';

  @override
  String errorLoadingDocuments(String message) {
    return 'Erreur lors du chargement des documents : $message';
  }

  @override
  String errorLoadingSecurityRules(String message) {
    return 'Erreur lors du chargement des règles : $message';
  }

  @override
  String errorLoadingUsers(String message) {
    return 'Erreur lors du chargement des utilisateurs : $message';
  }

  @override
  String saveFailed(String message) {
    return 'Échec de l\'enregistrement : $message';
  }

  @override
  String savedToPath(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String get addBooking => 'Ajouter une réservation';

  @override
  String get addCard => 'Ajouter une carte';

  @override
  String get addFirstTaxRate => 'Ajouter un premier taux de taxe';

  @override
  String get addFirstWarehouse => 'Ajouter un premier entrepôt';

  @override
  String get addLoyaltyCard => 'Ajouter une carte de fidélité';

  @override
  String get addPromotion => 'Ajouter une promotion';

  @override
  String get addTable => 'Ajouter une table';

  @override
  String get addTimeCard => 'Ajouter un pointage';

  @override
  String get addWarehouse => 'Ajouter un entrepôt';

  @override
  String get addResizeRenameTables =>
      'Ajouter, redimensionner et renommer les tables';

  @override
  String get allEmployees => 'Tous les employés ...';

  @override
  String get applyName => 'Appliquer le nom';

  @override
  String get endShiftConfirm => 'Voulez-vous vraiment terminer votre service ?';

  @override
  String get back => 'Retour';

  @override
  String get bookingAlerts => 'Alertes de réservation';

  @override
  String get bookingSaved => 'Réservation enregistrée !';

  @override
  String get cardNumber => 'Numéro de carte';

  @override
  String get shapeCircle => 'Cercle';

  @override
  String get clockIn => 'Pointer l\'arrivée';

  @override
  String get clockOut => 'Pointer le départ';

  @override
  String get confirmDelete => 'Confirmer la suppression';

  @override
  String get couldNotLoadEmployees => 'Impossible de charger les employés';

  @override
  String get created => 'Créé';

  @override
  String get currencies => 'Devises';

  @override
  String get customerRequired => 'Client *';

  @override
  String get dashboard => 'Tableau de bord';

  @override
  String get days => 'Jours';

  @override
  String get deleteBooking => 'Supprimer la réservation';

  @override
  String get deleteLoyaltyCard => 'Supprimer la carte de fidélité';

  @override
  String get deleteTax => 'Supprimer la taxe';

  @override
  String get deleteWarehouse => 'Supprimer l\'entrepôt';

  @override
  String get documentItemsColumns => 'Colonnes des articles';

  @override
  String get documentType => 'Type de document';

  @override
  String get documents => 'Documents';

  @override
  String get documentsColumns => 'Colonnes des documents';

  @override
  String get hintTwentyPercent => 'ex. 20 pour 20 %';

  @override
  String get hintSecondFloor => 'Ex. : deuxième étage';

  @override
  String get earningRule => 'Règle de gain';

  @override
  String get editFloorPlan => 'Modifier le plan de salle';

  @override
  String get employee => 'Employé';

  @override
  String get enableLoyaltyPoints => 'Activer les points de fidélité';

  @override
  String get endDate => 'Date de fin';

  @override
  String get endOfDay => 'Fin de journée';

  @override
  String get endShift => 'Terminer le service';

  @override
  String get endTime => 'Heure de fin';

  @override
  String get colExport => 'EXPORTER';

  @override
  String get externalRef => 'Réf. externe';

  @override
  String get floorPlan => 'Plan de salle';

  @override
  String get gotIt => 'Compris';

  @override
  String get guestNameRequired => 'Nom du client *';

  @override
  String get guests => 'Invités';

  @override
  String get leaveBlankAutoAssign => 'Laisser vide pour attribution auto';

  @override
  String get logout => 'Déconnexion';

  @override
  String get loyaltyCards => 'Cartes de fidélité';

  @override
  String get loyaltySettings => 'Paramètres de fidélité';

  @override
  String get minPurchaseAmount => 'Montant d\'achat min.';

  @override
  String get moveStock => 'Déplacer le stock';

  @override
  String get moveStockTo => 'Déplacer le stock vers…';

  @override
  String get myCompany => 'Ma société';

  @override
  String get nameRequired => 'Nom *';

  @override
  String get newFloor => 'Nouvel étage';

  @override
  String get newFloorPlan => 'Nouveau plan de salle';

  @override
  String get newTax => 'Nouvelle taxe';

  @override
  String get newTaxRate => 'Nouveau taux de taxe';

  @override
  String get nextDay => 'Jour suivant';

  @override
  String get noWarehousesFound => 'Aucun entrepôt trouvé.';

  @override
  String get notesOptional => 'Notes (facultatif)';

  @override
  String get numberLabel => 'Numéro';

  @override
  String get oldTax => 'Ancienne taxe';

  @override
  String get openDocument => 'Ouvrir le document';

  @override
  String get openOrder => 'Ouvrir la commande';

  @override
  String get openOrders => 'Commandes ouvertes';

  @override
  String get openService => 'Ouvrir le service';

  @override
  String get openedAt => 'Ouvert à';

  @override
  String get orderNoLabel => 'N° de commande';

  @override
  String get pageLabel => 'Page :';

  @override
  String get paymentLabel => 'Paiement';

  @override
  String get paymentTypesShort => 'Types de paiement';

  @override
  String get pendingLower => 'en attente';

  @override
  String get points => 'Points';

  @override
  String get pointsEarned => 'Points gagnés';

  @override
  String get posLabel => 'POS';

  @override
  String get previousDay => 'Jour précédent';

  @override
  String get priceLabel => 'Prix';

  @override
  String get promotions => 'Promotions';

  @override
  String get rateRequired => 'Taux *';

  @override
  String get redemptionRule => 'Règle d\'utilisation';

  @override
  String get refresh => 'Actualiser';

  @override
  String get removeFloor => 'Supprimer l\'étage';

  @override
  String get removeFloorPlan => 'Supprimer le plan de salle';

  @override
  String get removeTable => 'Supprimer la table';

  @override
  String get rename => 'Renommer';

  @override
  String get replace => 'Remplacer';

  @override
  String get revokeStock => 'Révoquer le stock';

  @override
  String get rowsPerPage => 'Lignes par page :';

  @override
  String get sales => 'Ventes';

  @override
  String get saveUpper => 'ENREGISTRER';

  @override
  String get searchCustomer => 'Rechercher un client...';

  @override
  String get searchDocument => 'Rechercher un document...';

  @override
  String get selectEmployee => 'Choisir un employé';

  @override
  String get selectTablesRequired => 'Choisir les tables *';

  @override
  String get settings => 'Paramètres';

  @override
  String get shiftManagement => 'Gestion des services';

  @override
  String get showGrid => 'Afficher la grille';

  @override
  String get showQr => 'Afficher le QR';

  @override
  String get snapToGrid => 'Aligner sur la grille';

  @override
  String get shapeSquare => 'Carré';

  @override
  String get startDate => 'Date de début';

  @override
  String get startService => 'Démarrer le service';

  @override
  String get startShift => 'Commencer le service';

  @override
  String get startTime => 'Heure de début';

  @override
  String get startingPoints => 'Points de départ';

  @override
  String get statusLabel => 'Statut';

  @override
  String get stayOnCalendar => 'Rester sur le calendrier';

  @override
  String get stock => 'Stock';

  @override
  String get switchTaxes => 'Changer les taxes';

  @override
  String get taxRates => 'Taux de taxe';

  @override
  String get totalBeforeDiscount => 'Total avant remise';

  @override
  String get totalBeforeTax => 'Total hors taxes';

  @override
  String get unitOfMeasure => 'Unité de mesure';

  @override
  String get userLabel => 'Utilisateur';

  @override
  String get users => 'Utilisateurs';

  @override
  String get warehouseHasStock => 'L\'entrepôt contient du stock';

  @override
  String get warehouseNameRequired => 'Nom de l\'entrepôt *';

  @override
  String get warehouses => 'Entrepôts';

  @override
  String get whichTableForOrder => 'Sur quelle table placer cette commande ?';

  @override
  String errorLoadingLoyaltyCards(String message) {
    return 'Erreur lors du chargement des cartes : $message';
  }

  @override
  String errorLoadingWarehouses(String message) {
    return 'Erreur lors du chargement des entrepôts : $message';
  }

  @override
  String get colActions => 'ACTIONS';

  @override
  String get addCash => 'Ajouter de l\'argent';

  @override
  String get addItem => 'Ajouter un article';

  @override
  String get addProductLower => 'Ajouter un produit';

  @override
  String get addPromotionItem => 'Ajouter un article promo';

  @override
  String get addReturnedProducts => 'Ajouter les produits retournés';

  @override
  String get addTimeCardUpper => 'AJOUTER UN POINTAGE';

  @override
  String get allWarehousesCap => 'Tous les entrepôts';

  @override
  String get appliesTo => 'S\'applique à';

  @override
  String get deleteVoidReasonConfirm =>
      'Voulez-vous vraiment supprimer ce motif d\'annulation ?';

  @override
  String get authorise => 'Autoriser';

  @override
  String get bookingHistory => 'Historique des réservations';

  @override
  String get cancelEdit => 'Annuler la modification';

  @override
  String get cashIn => 'Entrée de caisse';

  @override
  String get cashInOut => 'Entrées / sorties de caisse';

  @override
  String get cashMovement => 'Mouvement de caisse';

  @override
  String get cashOut => 'Sortie de caisse';

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String get closeRegister => 'Clôturer la caisse';

  @override
  String get confirmNewPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get country => 'Pays';

  @override
  String get createUser => 'Créer un utilisateur';

  @override
  String get creditPayments => 'Paiements à crédit';

  @override
  String get currencyCodeRequired => 'Code de devise (ex. USD) *';

  @override
  String get currencyNameRequired => 'Nom de la devise (ex. dollar US) *';

  @override
  String get customersSuppliers => 'Clients et fournisseurs';

  @override
  String get colDate => 'DATE';

  @override
  String get deleteCurrency => 'Supprimer la devise';

  @override
  String get deleteVoidReason => 'Supprimer le motif d\'annulation';

  @override
  String get descriptionOptional => 'Description (facultatif)';

  @override
  String get discountType => 'Type de remise';

  @override
  String get discountValue => 'Valeur de la remise';

  @override
  String get hintWifiBill => 'ex. facture wifi, avance';

  @override
  String get cashReasonHint =>
      'Saisissez le motif de l\'entrée ou sortie de caisse...';

  @override
  String get errorLoadingTables => 'Erreur lors du chargement des tables';

  @override
  String get exitApplication => 'Quitter l\'application';

  @override
  String get failedToLoadOrders => 'Échec du chargement des commandes';

  @override
  String get feedback => 'Retour d\'expérience';

  @override
  String get financialInfo => 'Infos financières';

  @override
  String get fixedAmount => 'Montant fixe';

  @override
  String get fullScreen => 'Plein écran';

  @override
  String get generalInfo => 'Infos générales';

  @override
  String get globalCurrencies => 'Devises globales';

  @override
  String get gridView => 'Grille';

  @override
  String get hideSidebar => 'Masquer la barre latérale';

  @override
  String get isActive => 'Actif';

  @override
  String get isEnabled => 'Activé';

  @override
  String get listView => 'Liste';

  @override
  String get loadingPaymentTypes => 'Chargement des types de paiement…';

  @override
  String get locationAddress => 'Emplacement et adresse';

  @override
  String get management => 'Gestion';

  @override
  String get managerAuthorisation => 'Autorisation du responsable';

  @override
  String get managerPin => 'PIN du responsable';

  @override
  String get menuLabel => 'Menu';

  @override
  String get newCurrency => 'Nouvelle devise';

  @override
  String get noCurrenciesFound => 'Aucune devise trouvée.';

  @override
  String get noPromotionsFound => 'Aucune promotion trouvée.';

  @override
  String get blindReturn => 'Pas de reçu ? Retour à l\'aveugle';

  @override
  String get noUserLoggedIn => 'Aucun utilisateur connecté.';

  @override
  String get noUsersFound => 'Aucun utilisateur trouvé';

  @override
  String get noVoidReasonsYet => 'Aucun motif d\'annulation.';

  @override
  String get colNote => 'NOTE';

  @override
  String get oldPassword => 'Ancien mot de passe';

  @override
  String get paymentMethodColon => 'Mode de paiement :';

  @override
  String get paymentTypeLower => 'Type de paiement';

  @override
  String get percentage => 'Pourcentage';

  @override
  String get percentageSign => 'Pourcentage (%)';

  @override
  String get posSystem => 'Système POS';

  @override
  String get power => 'Alimentation';

  @override
  String get powerOptions => 'Options d\'alimentation';

  @override
  String get promotionName => 'Nom de la promotion';

  @override
  String get promotionsManagement => 'Gestion des promotions';

  @override
  String get quickSettings => 'Réglages rapides';

  @override
  String get rankDisplayOrderLower => 'Rang (ordre d\'affichage)';

  @override
  String get refundItems => 'Articles à rembourser';

  @override
  String get refundPaymentType => 'Type de paiement du remboursement';

  @override
  String get removeCash => 'Retirer de l\'argent';

  @override
  String get requiredQty => 'Qté requise';

  @override
  String get restartApplication => 'Redémarrer l\'application';

  @override
  String get sameProduct => 'Même produit';

  @override
  String get savePin => 'Enregistrer le PIN';

  @override
  String get searchReceiptToSeeItems =>
      'Recherchez un reçu pour voir ses articles';

  @override
  String get searchByName => 'Rechercher par nom…';

  @override
  String get searchByOrderStaffTable =>
      'Rechercher par commande, employé ou table';

  @override
  String get searchNamePhoneCard => 'Rechercher nom, téléphone ou n° de carte…';

  @override
  String get searchProductEllipsis => 'Rechercher un produit…';

  @override
  String get searchWarehouse => 'Rechercher un entrepôt…';

  @override
  String get selectCustomer => 'Choisir un client';

  @override
  String get selectWarehouse => 'Choisir un entrepôt';

  @override
  String get selectYourCompany => 'Choisissez votre société';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get supplier => 'Fournisseur';

  @override
  String get targetUid => 'UID cible (ex. ID produit)';

  @override
  String get taxExempt => 'Exonéré de taxe';

  @override
  String get totalRefundAmount => 'MONTANT TOTAL DU REMBOURSEMENT';

  @override
  String get turnOffPc => 'Éteindre le PC';

  @override
  String get colType => 'TYPE';

  @override
  String get updateDevicePin => 'Mettre à jour le PIN de l\'appareil';

  @override
  String get updatePinForDevice => 'Mettre à jour le PIN de cet appareil';

  @override
  String get useWeight => 'Utiliser le poids';

  @override
  String get userInfo => 'Infos utilisateur';

  @override
  String get userInfoSecurity => 'Infos utilisateur et sécurité';

  @override
  String get viewOpenSales => 'Voir les ventes ouvertes';

  @override
  String get viewSalesHistory => 'Voir l\'historique des ventes';

  @override
  String get voidReasons => 'Motifs d\'annulation';

  @override
  String get welcomeToYourPos => 'Bienvenue sur votre POS';

  @override
  String errorLoadingBookings(String message) {
    return 'Erreur lors du chargement des réservations : $message';
  }

  @override
  String errorLoadingCustomers(String message) {
    return 'Erreur lors du chargement des clients : $message';
  }

  @override
  String get addPrinter => 'Ajouter une imprimante';

  @override
  String get addressFormat => 'Format d\'adresse';

  @override
  String get allProducts2 => 'Tous les produits';

  @override
  String get forceOnCreditSales =>
      'Toujours affiché sur les ventes à crédit ; forcé même si payé';

  @override
  String get amountDue => 'Montant dû';

  @override
  String get bottom => 'Bas';

  @override
  String get cashDrawerCommand => 'Commande du tiroir-caisse';

  @override
  String get change => 'Monnaie';

  @override
  String get collapseSidebar => 'Réduire la barre latérale';

  @override
  String get companyHeader => 'En-tête de la société';

  @override
  String get kitchenPrintingSection => 'Impression cuisine';

  @override
  String get autoKitchenPrintOnCheckout =>
      'Imprimer automatiquement les tickets de cuisine à l\'encaissement';

  @override
  String get autoKitchenPrintSubtitle =>
      'Ce terminal uniquement. À la finalisation d\'une vente, imprime les mêmes tickets de station que le bouton Cuisine.';

  @override
  String get companyPhoneTel => 'Téléphone de la société (Tél)';

  @override
  String get companyTaxNumber => 'Numéro fiscal de la société';

  @override
  String get customLabels => 'Libellés personnalisés';

  @override
  String get customerDetailLabels => 'Libellés des détails client';

  @override
  String get customerDetails => 'Détails du client';

  @override
  String get customizeReceipt => 'Personnaliser le reçu';

  @override
  String get decimalPlaces => 'Décimales';

  @override
  String get deletePrinter => 'Supprimer l\'imprimante';

  @override
  String get discountColumn => 'Colonne remise';

  @override
  String get hintBarPrinter => 'ex. imprimante du bar';

  @override
  String get expandSidebar => 'Développer la barre latérale';

  @override
  String get font => 'Police';

  @override
  String get fontFamily => 'Famille de police';

  @override
  String get fontSettings => 'Paramètres de police';

  @override
  String get footer => 'Pied de page';

  @override
  String get footerText => 'Texte du pied de page';

  @override
  String get forRtlLanguages => 'Pour les langues RTL (arabe, hébreu)';

  @override
  String get globalFooter => 'Pied de page global';

  @override
  String get globalHeader => 'En-tête global';

  @override
  String get header => 'En-tête';

  @override
  String get headerAndFooter => 'En-tête et pied de page';

  @override
  String get headerText => 'Texte de l\'en-tête';

  @override
  String get invoiceFont => 'Police de la facture';

  @override
  String get invoiceSettings => 'Paramètres de facture';

  @override
  String get itemsCount => 'Nombre d\'articles';

  @override
  String get kitchenPrinting => 'Impression cuisine';

  @override
  String get leftSide => 'Gauche';

  @override
  String get localizeText => 'Localiser le texte';

  @override
  String get marginsMm => 'Marges (en millimètres)';

  @override
  String get mergeIdenticalItems => 'Fusionner les articles identiques';

  @override
  String get noCategoryFilter =>
      'Aucun filtre de catégorie — imprime tous les articles';

  @override
  String get noPrintersFound => 'Aucune imprimante trouvée';

  @override
  String get printerSelectionUnsupportedOnThisDevice =>
      'Cet appareil ne peut pas sélectionner d\'imprimante système. L\'impression ouvre la boîte de dialogue d\'impression de l\'appareil.';

  @override
  String get numberOfCopies => 'Nombre de copies';

  @override
  String get openCashDrawerLower => 'Ouvrir le tiroir-caisse';

  @override
  String get options => 'Options';

  @override
  String get orderNumberLower => 'Numéro de commande';

  @override
  String get otherSettings => 'Autres paramètres';

  @override
  String get outstandingBalance => 'Solde restant dû';

  @override
  String get paidAmount => 'Montant payé';

  @override
  String get paymentMethods => 'Modes de paiement';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get printAddress => 'Imprimer l\'adresse';

  @override
  String get printBarcode => 'Imprimer le code-barres';

  @override
  String get printCategory => 'Catégorie d\'impression';

  @override
  String get printDemoReceipt => 'Imprimer un reçu de test';

  @override
  String get printInA5 => 'Imprimer au format A5';

  @override
  String get printItemsCount => 'Imprimer le nombre d\'articles';

  @override
  String get printKitchenTicket => 'Imprimer le ticket cuisine';

  @override
  String get printLargeOrderNumber => 'Imprimer un grand numéro de commande';

  @override
  String get printLogoFullWidth => 'Imprimer le logo pleine largeur';

  @override
  String get printMeasurementUnit => 'Imprimer l\'unité de mesure';

  @override
  String get printTrailingCounter =>
      'Imprimer seulement le compteur final (ex. 000008)';

  @override
  String get printOrderNumber => 'Imprimer le numéro de commande';

  @override
  String get printOutstandingBalance => 'Imprimer le solde dû';

  @override
  String get printPhoneTel => 'Imprimer le téléphone (Tél)';

  @override
  String get printTaxName => 'Imprimer le nom de la taxe';

  @override
  String get printTaxNumber => 'Imprimer le numéro fiscal';

  @override
  String get printTaxTotals => 'Imprimer les totaux de taxe';

  @override
  String get printTemplates => 'Modèles d\'impression';

  @override
  String get printTotalQuantity => 'Imprimer la quantité totale';

  @override
  String get printerName => 'Nom de l\'imprimante';

  @override
  String get printerSettings => 'Paramètres d\'imprimante';

  @override
  String get printers => 'Imprimantes';

  @override
  String get productGroupsUpper => 'GROUPES DE PRODUITS';

  @override
  String get receiptContent => 'Contenu du reçu';

  @override
  String get receiptLabels => 'Libellés du reçu';

  @override
  String get receiptNumber => 'Numéro de reçu';

  @override
  String get refreshAll => 'Tout actualiser';

  @override
  String get refreshPrinters => 'Actualiser les imprimantes';

  @override
  String get renamePrinter => 'Renommer l\'imprimante';

  @override
  String get reporting => 'Rapports';

  @override
  String get restricted => 'Restreint';

  @override
  String get rightSide => 'Droite';

  @override
  String get rightToLeft => 'De droite à gauche';

  @override
  String get cashDrawerSignalHint =>
      'Envoie un signal au tiroir-caisse après le paiement';

  @override
  String get shortReceiptNumber => 'Numéro de reçu court';

  @override
  String get subtotal => 'Sous-total';

  @override
  String get taxColumn => 'Colonne taxe';

  @override
  String get taxNumber => 'Numéro fiscal';

  @override
  String get titleLabel => 'Titre';

  @override
  String get top => 'Haut';

  @override
  String get topCustomers => 'MEILLEURS CLIENTS';

  @override
  String get topProducts => 'MEILLEURS PRODUITS';

  @override
  String get totalRevenue => 'CHIFFRE D\'AFFAIRES TOTAL';

  @override
  String get fallbackWordingHint =>
      'Désactiver pour revenir au libellé par défaut';

  @override
  String get useCustomLabels =>
      'Utiliser des libellés personnalisés dans les rapports et factures';

  @override
  String get kitchenFireHint =>
      'Déclencher cette imprimante via le bouton Cuisine. Avec';

  @override
  String get myCompanyLower => 'Ma société';

  @override
  String get customersSuppliersLower => 'Clients et fournisseurs';

  @override
  String get usersSecurityLower => 'Utilisateurs et sécurité';

  @override
  String get voidReasonsLower => 'Motifs d\'annulation';

  @override
  String get taxRatesLower => 'Taux de taxe';

  @override
  String get paymentTypesLower => 'Types de paiement';

  @override
  String get rptSalesByProduct => 'Produits';

  @override
  String get rptSalesByGroup => 'Groupes de produits';

  @override
  String get rptSalesByCustomer => 'Clients';

  @override
  String get rptTaxRates => 'Taux de taxe';

  @override
  String get rptUsers => 'Utilisateurs';

  @override
  String get rptItemList => 'Liste des articles';

  @override
  String get rptPaymentTypes => 'Types de paiement';

  @override
  String get rptPaymentByUser => 'Types de paiement par utilisateur';

  @override
  String get rptPaymentByCustomer => 'Types de paiement par client';

  @override
  String get rptRefunds => 'Remboursements';

  @override
  String get rptInvoiceList => 'Liste des factures';

  @override
  String get rptDailySales => 'Ventes quotidiennes';

  @override
  String get rptHourlySales => 'Ventes horaires';

  @override
  String get rptHourlyByGroup => 'Ventes horaires par groupe';

  @override
  String get rptByTable => 'Table ou numéro de commande';

  @override
  String get rptProfitMargin => 'Bénéfice et marge';

  @override
  String get rptUnpaidSales => 'Ventes impayées';

  @override
  String get rptStartingCash => 'Fonds de caisse';

  @override
  String get rptVoidedItems => 'Articles annulés';

  @override
  String get rptDiscountsGranted => 'Remises accordées';

  @override
  String get rptDiscountsBySource => 'Remises par source';

  @override
  String get rptItemDiscounts => 'Remises sur articles';

  @override
  String get rptStockMovement => 'Mouvement de stock';

  @override
  String get rptSuppliers => 'Fournisseurs';

  @override
  String get rptUnpaidPurchase => 'Achats impayés';

  @override
  String get rptPurchaseDiscounts => 'Remises sur achats';

  @override
  String get rptPurchasedItemDiscounts => 'Remises sur articles achetés';

  @override
  String get rptPurchaseInvoiceList => 'Liste des factures d\'achat';

  @override
  String get rptExpirationDate => 'Date d\'expiration';

  @override
  String get rptReorderList => 'Liste de réapprovisionnement';

  @override
  String get rptLowStockWarning => 'Alerte de stock faible';

  @override
  String get rptTransactionHistory => 'Historique des transactions';

  @override
  String get secSales => 'Ventes';

  @override
  String get secPurchase => 'Achats';

  @override
  String get secStockReturn => 'Retour de stock';

  @override
  String get secLossAndDamage => 'Perte et dommage';

  @override
  String get secStockControl => 'Contrôle des stocks';

  @override
  String get secFinance => 'Finance';

  @override
  String get accent => 'Accent';

  @override
  String get backups => 'Sauvegardes';

  @override
  String get barcodeScanning => 'Lecture de codes-barres';

  @override
  String get clockInUpper => 'POINTER L\'ARRIVÉE';

  @override
  String get clockOutUpper => 'POINTER LE DÉPART';

  @override
  String get customerDisplayLower => 'Afficheur client';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeLight => 'Clair';

  @override
  String get databaseLower => 'Base de données';

  @override
  String get deviceNameLower => 'Nom de l\'appareil';

  @override
  String get dualCurrencyLower => 'Double devise';

  @override
  String get enableBookings => 'Activer les réservations';

  @override
  String get endOfDayLower => 'Fin de journée';

  @override
  String get generalLower => 'Général';

  @override
  String get kitchenDisplayLower => 'Écran de cuisine';

  @override
  String get loadingCurrencies => 'Chargement des devises…';

  @override
  String get loyaltyCardsLower => 'Cartes de fidélité';

  @override
  String get onScreenKeyboard => 'Clavier à l\'écran';

  @override
  String get openReservation => 'Ouvrir la réservation';

  @override
  String get reservedTable => 'Table réservée';

  @override
  String get selectCustomerLower => 'Choisir un client';

  @override
  String get selectEllipsisShort => 'Sélectionner…';

  @override
  String get touchKeyboardHint =>
      'Afficher un clavier tactile lors de la saisie.';

  @override
  String get subscriptionUpper => 'ABONNEMENT';

  @override
  String get takeReservationsHint => 'Accepter les réservations à l\'avance.';

  @override
  String get textSize => 'Taille du texte';

  @override
  String get theme => 'Thème';

  @override
  String get timeClockTitle => 'Pointage';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get totalUpper => 'TOTAL';

  @override
  String get walkIn => 'Sans réservation';

  @override
  String get weighingScaleLower => 'Balance';

  @override
  String get trimZerosFromCode => 'Supprimer les zéros du code produit';

  @override
  String get posNamePrefixHint =>
      'Nom du POS — préfixe des numéros de document';

  @override
  String get promotionsLower => 'Promotions';

  @override
  String get welcomeBody =>
      'Un point de vente rapide et hors ligne pour votre comptoir et vos tablettes. Configurez-le en quelques touches.';

  @override
  String get featBarcodeBody =>
      'Scannez pour encaisser ou trouver un produit instantanément.';

  @override
  String get featCustomerDisplayBody =>
      'Affichez la commande et le total sur un second écran.';

  @override
  String get featKitchenBody =>
      'Envoyez les commandes directement en cuisine (KDS).';

  @override
  String get featBackupsBody =>
      'Des sauvegardes locales automatiques protègent vos données.';

  @override
  String get featScaleBody =>
      'Vendez au poids via une balance série connectée.';

  @override
  String get featPromotionsBody => 'Remises automatiques et tarifs spéciaux.';

  @override
  String get featLoyaltyBody =>
      'Points et récompenses qui fidélisent vos clients.';

  @override
  String get exitManagement => 'Quitter la gestion';

  @override
  String get chooseColumns => 'Choisir les colonnes';

  @override
  String get viewPrintReceipt => 'Voir et imprimer le reçu';

  @override
  String get deleteItemAction => 'Supprimer l\'article';

  @override
  String get editItemAction => 'Modifier l\'article';

  @override
  String get noStockAssigned => 'Aucun stock attribué à cet article';

  @override
  String get noStockControlRules =>
      'Aucune règle de contrôle des stocks configurée';

  @override
  String get selectGroupToEdit =>
      'Sélectionnez un groupe à modifier ou créez-en un.';

  @override
  String editNamedTitle(Object name) {
    return 'Modifier $name';
  }

  @override
  String forceResetPinTitle(Object name) {
    return 'Réinitialiser le PIN : $name';
  }

  @override
  String forceResetPasswordTitle(Object name) {
    return 'Réinitialiser le mot de passe : $name';
  }

  @override
  String editPaymentTitle(Object id) {
    return 'Modifier le paiement n°$id';
  }

  @override
  String editDashTitle(Object name) {
    return 'Modifier — $name';
  }

  @override
  String confirmDeleteQuoted(Object name) {
    return 'Voulez-vous vraiment supprimer « $name » ?';
  }

  @override
  String codeValueLabel(Object code) {
    return 'Code : $code';
  }

  @override
  String idValueLabel(Object id) {
    return 'ID : $id';
  }

  @override
  String assignProductToWarehouse(Object name) {
    return 'Affecter $name à un entrepôt';
  }

  @override
  String deleteQuotedConfirm(Object name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String deletePlainConfirm(Object name) {
    return 'Supprimer $name ?';
  }

  @override
  String removeDiscardConfirm(Object name) {
    return 'Retirer « $name » ? Ses réglages seront perdus.';
  }

  @override
  String removeQuotedConfirm(Object name) {
    return 'Retirer « $name » ?';
  }

  @override
  String typeValueLabel(Object type) {
    return 'Type : $type';
  }

  @override
  String ofPagesLabel(Object total) {
    return 'sur $total';
  }

  @override
  String fixedAmountSymLabel(Object sym) {
    return 'Montant fixe ($sym)';
  }

  @override
  String couldNotReadSyncStatus(Object message) {
    return 'Impossible de lire l\'état de synchronisation : $message';
  }

  @override
  String uidValueLabel(Object uid, Object value) {
    return 'UID : $uid | Valeur : $value';
  }

  @override
  String enterFieldHint(Object field) {
    return 'Saisir $field';
  }

  @override
  String get actionClear => 'Effacer';

  @override
  String get noStockAssignedWarehouse => 'Aucun stock attribué à cet entrepôt';

  @override
  String get noStockAssignedProduct => 'Aucun stock attribué à ce produit';

  @override
  String get orderSummary => 'Récapitulatif';

  @override
  String get promotionLabel => 'Promotion';

  @override
  String get subtotalInclTax => 'Sous-total (TTC)';

  @override
  String get customerDiscountLabel => 'Remise client';

  @override
  String get cartDiscountLabel => 'Remise panier';

  @override
  String get taxInclLabel => 'Taxe (incluse)';

  @override
  String get itemDiscountLabel => 'Remise article';

  @override
  String get itemDiscountsPlural => 'Remises articles';

  @override
  String get taxesLabel => 'Taxes';

  @override
  String get pointsRedeemed => 'Points utilisés';

  @override
  String get subtotalLabel => 'Sous-total';

  @override
  String get applyDiscount => 'Appliquer la remise';

  @override
  String get cartTab => 'Panier';

  @override
  String get itemTab => 'Article';

  @override
  String get selectItemFirst =>
      'Veuillez d\'abord sélectionner un article dans le panier.';

  @override
  String get noItemSelected => 'Aucun article sélectionné !';

  @override
  String get selectedItemNotFound => 'Article sélectionné introuvable.';

  @override
  String get discountBelowCost => 'La remise placerait le prix sous le coût.';

  @override
  String get discountNegativePrice => 'La remise donnerait un prix négatif.';

  @override
  String inclPrefix(Object name) {
    return 'incl. $name';
  }

  @override
  String get saveAndRestart => 'Enregistrer';

  @override
  String get resourceMode => 'Mode de ressource';

  @override
  String get resourceModeHint => 'Ce à quoi un créneau est attribué';

  @override
  String get defaultDuration => 'Durée par défaut';

  @override
  String get defaultDurationHint =>
      'Durée pré-remplie lors de l\'ajout d\'une réservation';

  @override
  String get timeSnapping => 'Alignement du temps';

  @override
  String get timeSnappingHint =>
      'Intervalle de la grille pour choisir les heures';

  @override
  String get couldNotLoadCurrencies => 'Impossible de charger les devises';

  @override
  String get fontPreview => 'Aperçu : Portez ce vieux whisky';

  @override
  String get chooseTheme => 'CHOISIR LE THÈME';

  @override
  String get posButtonsHint =>
      'Choisissez les boutons d\'action affichés sur l\'écran principal.';

  @override
  String get couldNotLoadTaxRates => 'Impossible de charger les taux de taxe';

  @override
  String get noTaxRatesDefined =>
      'Aucun taux de taxe défini. Ajoutez-les sous Taux de taxe.';

  @override
  String get taxDefaultRequiredTitle => 'Choisissez un taux de taxe par défaut';

  @override
  String get taxDefaultRequiredBody =>
      'Le prix TTC nécessite un taux de taxe par défaut. Choisissez-en au moins un — il sera appliqué à chaque nouveau produit et verrouillé en caisse.';

  @override
  String get taxDefaultRequiredNoRates =>
      'Aucun taux de taxe défini. Créez-en un sous Taux de taxe avant d\'activer cette option.';

  @override
  String get defaultTaxRateDisabledHint =>
      'Activez le prix TTC ci-dessus pour appliquer un taux de taxe par défaut.';

  @override
  String get taxLockedBySetting =>
      'Défini dans Paramètres → Général → Taxe. Non modifiable ici.';

  @override
  String get taxLockedShort => 'Verrouillé';

  @override
  String get couldNotLoadWarehouses => 'Impossible de charger les entrepôts';

  @override
  String get defaultWarehouseHint =>
      'Utilisé pour vérifier la disponibilité du stock dans le menu POS.';

  @override
  String get waitingForScale => 'En attente d\'un poids de la balance…';

  @override
  String get restoreDefaults => 'Rétablir les valeurs par défaut';

  @override
  String get sameMachineSecondMonitor => 'Même machine / second écran';

  @override
  String get otherDeviceSameNetwork => 'Autre appareil sur le même réseau';

  @override
  String get categoriesPrintedOnGroup => 'Catégories imprimées sur ce groupe';

  @override
  String get noPrinterGroupsYet => 'Aucun groupe d\'imprimantes.';

  @override
  String get noKitchenDisplays => 'Aucun écran de cuisine configuré.';

  @override
  String get noGroupSelectedReceivesAll =>
      'Aucun groupe sélectionné → reçoit tous les articles.';

  @override
  String get openDatabaseLocation =>
      'Ouvrir l\'emplacement de la base de données';

  @override
  String get setZeroToDisableBackups =>
      'Mettre à 0 pour désactiver les sauvegardes planifiées';

  @override
  String get statusExpired => 'Expiré';

  @override
  String get statusInvalid => 'Invalide';

  @override
  String get statusNotActivated => 'Non activé';

  @override
  String get onboardingWillShow =>
      'L\'intégration s\'affichera au prochain lancement de l\'application.';

  @override
  String get autoLabel => 'Auto';

  @override
  String get themeDimmed => 'Atténué';

  @override
  String get themeNight => 'Nuit';

  @override
  String get themeGray => 'Gris';

  @override
  String get themeHighContrast => 'Contraste élevé';

  @override
  String get colorBlue => 'Bleu';

  @override
  String get colorGreen => 'Vert';

  @override
  String get colorPink => 'Rose';

  @override
  String get colorPurple => 'Violet';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorRed => 'Rouge';

  @override
  String get allFields => 'Tous les champs';

  @override
  String get signInOnlineAgain =>
      'Vous devrez vous connecter en ligne pour réutiliser le POS.';

  @override
  String get tablesLabel => 'Tables';

  @override
  String get bookingLabel => 'Réservation';

  @override
  String get posNameFullHint =>
      'Un nom court et UNIQUE pour ce terminal. Il devient le préfixe de chaque numéro de document (ex. CAISSE1-200-000045), afin que deux POS ne produisent jamais le même numéro. Lettres et chiffres uniquement.';

  @override
  String get defaultTaxRateFullHint =>
      'Appliqué automatiquement aux produits ajoutés au panier qui n\'ont pas de taxe propre.';

  @override
  String get serialScaleWindowsOnly =>
      'Les balances série ne sont prises en charge que sous Windows. Sur cet appareil, utilisez l\'option d\'analyse de code-barres ci-dessus avec une balance à étiquettes.';

  @override
  String get openCustomerDisplayFullHint =>
      'Ouvre l\'afficheur client en plein écran sur cette machine. Idéal pour un second écran — glissez la fenêtre et appuyez sur F11.';

  @override
  String get printerGroupsHelp =>
      'Regroupez les catégories de produits en stations (ex. Cuisine, Bar). Attribuez un groupe à un écran ci-dessous et cet écran n\'affiche que les articles de ces catégories.';

  @override
  String get receivesAllItems =>
      'Reçoit tous les articles. Créez des groupes d\'imprimantes ci-dessus pour router par catégorie.';

  @override
  String get autoSyncFullHint =>
      'Envoyez vos modifications locales et récupérez les données à jour automatiquement en arrière-plan.';

  @override
  String get replayOnboardingHint =>
      'Rejouez la visite de bienvenue. Elle réapparaîtra au prochain lancement de l\'application sur cet appareil.';

  @override
  String pairingRequestSent(Object ip) {
    return 'Demande d\'appairage envoyée à $ip — le KDS devrait passer à la vue cuisine.';
  }

  @override
  String kdsTabletsHelp(Object port) {
    return 'Chaque tablette KDS écoute sur le port $port. Ajouter son IP l\'appaire avec ce POS et pousse les commandes via le réseau local — le KDS fonctionne hors ligne, sans internet.';
  }

  @override
  String get statusActive => 'Actif';

  @override
  String get statusEnabled => 'Activé';

  @override
  String get statusDisabled => 'Désactivé';

  @override
  String get statusOn => 'Activé';

  @override
  String get statusOff => 'Désactivé';

  @override
  String expiresInDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expire dans $count jours',
      one: 'Expire dans 1 jour',
    );
    return '$_temp0';
  }

  @override
  String deviceCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appareils',
      one: '1 appareil',
    );
    return '$_temp0';
  }

  @override
  String get scaleBarcodePriceHint =>
      'Si activé, la valeur encodée est un prix et la quantité est calculée comme prix ÷ prix unitaire';

  @override
  String get webDisplayHint =>
      'Héberge un écran de commande interactif accessible depuis tout navigateur du réseau';

  @override
  String savedFieldFailed(Object field) {
    return 'Échec de l\'enregistrement de $field';
  }

  @override
  String prefixColonValue(Object prefix) {
    return 'Préfixe : $prefix';
  }

  @override
  String unlinkEmailWarning(Object email) {
    return 'Cela dissociera $email de ce terminal. Vous devrez vous connecter en ligne pour réutiliser le POS.';
  }

  @override
  String get unlinkTerminalWarning =>
      'Cela dissociera ce terminal. Vous devrez vous connecter en ligne pour réutiliser le POS.';

  @override
  String get builtInBadge => 'INTÉGRÉ';

  @override
  String get printerType => 'Type d\'imprimante';

  @override
  String get paperSize => 'Taille du papier';

  @override
  String get copiesPerTransaction => 'Copies par transaction';

  @override
  String get headerPrintedTopHint => 'Imprimé en haut de chaque reçu';

  @override
  String get footerThankYouHint => 'ex. Merci de votre visite !';

  @override
  String get generalLabel => 'Général';

  @override
  String get categoryLabel => 'Catégorie';

  @override
  String get chooseCustomerDetailsHint =>
      'Choisissez les détails client imprimés sur le reçu.';

  @override
  String get addressFormatFullHint =>
      'Définissez comment les lignes d\'adresse sont imprimées sur les reçus et factures.';

  @override
  String get tapPlaceholderHint =>
      'Touchez un espace réservé pour l\'insérer :';

  @override
  String get invoiceTitleHint => 'ex. FACTURE';

  @override
  String get invoiceHeaderHint => 'Imprimé au-dessus de la facture';

  @override
  String get invoiceFooterHint => 'ex. coordonnées bancaires, conditions';

  @override
  String get addPrinterHint =>
      'Ajoutez une imprimante par station, puis ouvrez ses réglages pour configurer la taille du papier, les marges, l\'en-tête/pied de page et le tiroir-caisse.';

  @override
  String get kitchenFireFullHint =>
      'Déclencher cette imprimante via le bouton Cuisine. Si plusieurs sont activées, la catégorie ci-dessous décide de ce que chacune imprime.';

  @override
  String get categoryFilterHint =>
      'Cette imprimante n\'imprime que les produits dont la catégorie appartient au groupe sélectionné (ex. Bar → boissons). Choisissez « Tous les produits » pour imprimer tout le ticket ici.';

  @override
  String get noPrinterGroupsDefined =>
      'Aucun groupe d\'imprimantes défini. Créez-les dans Paramètres → Afficheur client → Groupes d\'imprimantes.';

  @override
  String get headerDetailsFullHint =>
      'Détails imprimés sous le logo / nom de l\'entreprise en haut du reçu. Les textes d\'en-tête et de pied de page se règlent par imprimante (⚙ → Général).';

  @override
  String get sessionExpiredMsg =>
      'Votre session a expiré. Veuillez vous reconnecter.';

  @override
  String get enterPin => 'Saisir le PIN';

  @override
  String get syncingMasterData => 'Synchronisation des données…';

  @override
  String get confirmNewPin => 'Confirmer le nouveau PIN';

  @override
  String get createFourDigitPin => 'Créer un PIN à 4 chiffres';

  @override
  String get companyName => 'Nom de la société';

  @override
  String get taxNumberLabel => 'Numéro fiscal';

  @override
  String get emailAddress => 'Adresse e-mail';

  @override
  String get streetName => 'Nom de la rue';

  @override
  String get buildingNo => 'N° de bâtiment';

  @override
  String get additionalStreet => 'Rue complémentaire';

  @override
  String get plotId => 'ID de parcelle';

  @override
  String get districtSubdivision => 'District / subdivision';

  @override
  String get postalCode => 'Code postal';

  @override
  String get cityLabel => 'Ville';

  @override
  String get stateProvince => 'État / province';

  @override
  String get bankAccountNumber => 'Numéro de compte bancaire';

  @override
  String get bankDetails => 'Coordonnées bancaires (IBAN, SWIFT, etc.)';

  @override
  String get rateLabel => 'Taux';

  @override
  String get taxOnTotal => 'Taxe sur le total';

  @override
  String get noTaxRatesFound => 'Aucun taux de taxe trouvé.';

  @override
  String get editVoidReason => 'Modifier le motif d\'annulation';

  @override
  String get addVoidReason => 'Ajouter un motif d\'annulation';

  @override
  String get addReason => 'Ajouter un motif';

  @override
  String get totalDue => 'Total à payer';

  @override
  String get replaceTaxesHint =>
      'Utilisez ce formulaire pour remplacer les taxes de tous les produits. Sélectionnez l\'ancienne taxe à remplacer par la nouvelle et cliquez sur Remplacer.';

  @override
  String errorLoadingTaxesMsg(Object message) {
    return 'Erreur lors du chargement des taxes : $message';
  }

  @override
  String get orderTypeLabel => 'Type de commande';

  @override
  String get noServiceStatuses => 'Aucun statut de service configuré.';

  @override
  String get quantityCannotBeNegative =>
      'La quantité ne peut pas être négative.';

  @override
  String get cannotCalcQuantity =>
      'Impossible de calculer la quantité : le prix unitaire est nul.';

  @override
  String get parsedQuantityZero =>
      'La quantité lue est nulle — vérifiez la configuration du code-barres de la balance.';

  @override
  String get selectTableFirst => 'Veuillez d\'abord sélectionner une table !';

  @override
  String get notAvailableOtherWarehouse =>
      'Ce produit n\'est disponible dans aucun autre entrepôt.';

  @override
  String get selectTableFromFloorPlan =>
      'Veuillez d\'abord sélectionner une table depuis le plan de salle !';

  @override
  String get cartIsEmpty => 'Le panier est vide';

  @override
  String get totalPromotionalDiscount => 'Total des remises promotionnelles';

  @override
  String get calendarBookingUpdated =>
      'La réservation du calendrier sera mise à jour automatiquement.';

  @override
  String get confirmTransfer => 'Confirmer le transfert';

  @override
  String get setAbout => 'À propos';

  @override
  String get setAccentColor => 'Couleur d\'accent';

  @override
  String get setAddPrinterGroup => 'Ajouter un groupe d\'imprimantes';

  @override
  String get setAddress => 'Adresse';

  @override
  String get setAdvancedSettings => 'PARAMÈTRES AVANCÉS';

  @override
  String get setTaxInclusiveDefaultHint =>
      'Tous les nouveaux produits seront en prix taxes comprises';

  @override
  String get setAllowNegativePrice => 'Autoriser les prix négatifs';

  @override
  String get setAllowTablelessOrders => 'Autoriser les commandes sans table';

  @override
  String get setAllowWalkInTableOrders =>
      'Autoriser les commandes sans réservation';

  @override
  String get setApi => 'API';

  @override
  String get setApiBaseUrl => 'URL de base de l\'API';

  @override
  String get setAppearance => 'APPARENCE';

  @override
  String get setApplicationStyle => 'STYLE DE L\'APPLICATION';

  @override
  String get setAutoBackup => 'Sauvegarde auto';

  @override
  String get setAutoSync => 'SYNCHRONISATION AUTO';

  @override
  String get setAutomaticBackups => 'SAUVEGARDES AUTOMATIQUES';

  @override
  String get setAutoUpdateCostPrice => 'Mettre à jour le coût à l\'achat';

  @override
  String get setBackUpEvery => 'Sauvegarder automatiquement tous les';

  @override
  String get setBackupOnClose => 'Sauvegarder à la fermeture';

  @override
  String get setBackupOnStart => 'Sauvegarder au démarrage';

  @override
  String get setBackupLocation => 'Emplacement des sauvegardes';

  @override
  String get setBarcodeParsing => 'ANALYSE DES CODES-BARRES';

  @override
  String get setBaudRate => 'Débit en bauds';

  @override
  String get setBitsPerSecond => 'Bits par seconde';

  @override
  String get setBooking => 'RÉSERVATION';

  @override
  String get setBookingSettings => 'Paramètres de réservation';

  @override
  String get setBookingsButton => 'Bouton Réservations';

  @override
  String get setBottomLine => 'Ligne du bas';

  @override
  String get setBusinessDay => 'JOURNÉE COMMERCIALE';

  @override
  String get setCashDrawer => 'Tiroir-caisse';

  @override
  String get setCashDrawerButton => 'Bouton Tiroir-caisse';

  @override
  String get setChangeQuantity => 'Modifier la quantité';

  @override
  String get setChangeQuantityButton => 'Bouton Modifier la quantité';

  @override
  String get setColor => 'Couleur';

  @override
  String get setComPort => 'Port COM';

  @override
  String get setCompany => 'SOCIÉTÉ';

  @override
  String get setCopyLanUrl => 'Copier l\'URL du réseau local';

  @override
  String get setCostPriceMarkup => 'Majoration basée sur le coût';

  @override
  String get setCurrency => 'Devise';

  @override
  String get setCustomerButton => 'Bouton Client';

  @override
  String get setCustomerDisplay => 'Afficheur client';

  @override
  String get setCustomerDisplayEnabled => 'Afficheur client activé';

  @override
  String get setDataBits => 'Bits de données';

  @override
  String get setDatabase => 'BASE DE DONNÉES';

  @override
  String get setDatabaseBackup => 'Base de données et sauvegarde';

  @override
  String get setDbSize => 'Taille de la base';

  @override
  String get setDefaultBarcodeFormat => 'Format de code-barres par défaut';

  @override
  String get setDefaultDiscountType => 'Type de remise par défaut';

  @override
  String get setDefaultDueDays => 'Échéance par défaut (jours)';

  @override
  String get setDefaultMeasurementUnit => 'Unité de mesure par défaut';

  @override
  String get setDefaultScreen => 'Écran par défaut';

  @override
  String get setDefaultSearch => 'Mode de recherche par défaut';

  @override
  String get setDefaultServiceType => 'Type de service par défaut';

  @override
  String get setDefaultTaxRate => 'Taux de taxe par défaut';

  @override
  String get setDefaultWarehouse => 'Entrepôt par défaut';

  @override
  String get setDeleteBackupsOlderThan =>
      'Supprimer les sauvegardes de plus de';

  @override
  String get setDeleteOldBackups =>
      'Supprimer automatiquement les anciennes sauvegardes';

  @override
  String get setDeleteServiceStatus => 'Supprimer le statut de service';

  @override
  String get setDeleteServiceType => 'Supprimer le type de service';

  @override
  String get setDevice => 'APPAREIL';

  @override
  String get setDeviceName => 'Nom de l\'appareil';

  @override
  String get setDevices => 'Appareils';

  @override
  String get setDiscountApplyRule => 'Règle d\'application de la remise';

  @override
  String get setDiscountButton => 'Bouton Remise';

  @override
  String get setSyncToast =>
      'Afficher une notification à chaque synchronisation';

  @override
  String get setDisplayMessages => 'MESSAGES DE L\'AFFICHEUR';

  @override
  String get setDisplayPrintTaxIncluded =>
      'Afficher et imprimer les articles taxes comprises';

  @override
  String get setDualCurrencyHint =>
      'Afficher les prix et totaux dans une seconde devise';

  @override
  String get setShowPrintDialog =>
      'Afficher la boîte de dialogue d\'impression';

  @override
  String get setDualCurrency => 'DOUBLE DEVISE';

  @override
  String get setDualCurrencyEnabled => 'Double devise activée';

  @override
  String get setEnableAutomaticBackups =>
      'Activer les sauvegardes automatiques';

  @override
  String get setEnableAutoSync => 'Activer la synchronisation auto';

  @override
  String get setEnableBookings => 'Activer les réservations / calendrier';

  @override
  String get setEnableFloorPlan => 'Activer le plan de salle / tables';

  @override
  String get setEnableLiveWebDisplay => 'Activer l\'afficheur client web';

  @override
  String get setEnableMovingAverage => 'Activer le prix moyen pondéré';

  @override
  String get setEnableVirtualKeyboard => 'Activer le clavier virtuel';

  @override
  String get setEnableScaleBarcode => 'Activer les codes-barres de balance';

  @override
  String get setExchangeRate => 'Taux de change';

  @override
  String get setFeatures => 'FONCTIONNALITÉS';

  @override
  String get setFirstTwoDigits => 'Deux premiers chiffres / préfixe';

  @override
  String get setFlowControl => 'Contrôle de flux';

  @override
  String get setFontSize => 'Taille de police';

  @override
  String get setFromEmailAddress => 'Adresse e-mail expéditeur';

  @override
  String get setFromName => 'Nom de l\'expéditeur';

  @override
  String get setGeneral => 'GÉNÉRAL';

  @override
  String get setIanaTimezone => 'Fuseau horaire IANA';

  @override
  String get setInventory => 'INVENTAIRE';

  @override
  String get setItems => 'ARTICLES';

  @override
  String get setKdsIp => 'Adresse IP du KDS';

  @override
  String get setKitchenDisplay => 'Écran de cuisine';

  @override
  String get setKdsTablets => 'TABLETTES ÉCRAN DE CUISINE';

  @override
  String get setLastSync => 'Dernière synchronisation';

  @override
  String get setLayout => 'Disposition';

  @override
  String get setLoadingCurrencies => 'Chargement des devises…';

  @override
  String get setMenuGrid => 'GRILLE DU MENU';

  @override
  String get setMenuGridColumns => 'Colonnes de la grille';

  @override
  String get setMenuGridRows => 'Lignes de la grille';

  @override
  String get setMenuLayout => 'Disposition du menu (liste / grille)';

  @override
  String get setMergeItemsOnReceipt => 'Fusionner les articles sur le reçu';

  @override
  String get setMessageDuration => 'Durée du message (secondes)';

  @override
  String get setMessagePosition => 'Position du message';

  @override
  String get setMessages => 'MESSAGES (NOTIFICATIONS)';

  @override
  String get setMovingAveragePrice => 'PRIX MOYEN PONDÉRÉ';

  @override
  String get setNumberOfCharacters => 'Nombre de caractères';

  @override
  String get setNumberOfDecimals => 'Nombre de décimales';

  @override
  String get setProductCodeDigits => 'Nombre de chiffres du code produit';

  @override
  String get setPaymentTypeRows => 'Nombre de lignes de types de paiement';

  @override
  String get setOnboarding => 'INTÉGRATION';

  @override
  String get setOpen => 'Ouvrir';

  @override
  String get setOpenCustomerDisplay => 'Ouvrir l\'afficheur client';

  @override
  String get setOpenInBrowser =>
      'Ouvrir dans le navigateur (glisser vers le 2e écran)';

  @override
  String get setOpenOnThisDevice => 'OUVRIR SUR CET APPAREIL';

  @override
  String get setOrderAndPayment => 'Commande et paiement';

  @override
  String get setOrderNumberPrefix => 'Préfixe du numéro de commande';

  @override
  String get setParity => 'Parité';

  @override
  String get setScaleBarcodeHint =>
      'Lire le poids/prix des codes-barres imprimés par une balance';

  @override
  String get setPayment => 'PAIEMENT';

  @override
  String get setPhone => 'Téléphone';

  @override
  String get setPosButtonBar => 'BARRE DE BOUTONS';

  @override
  String get setPosNameHint => 'Nom du POS — préfixe des numéros de document';

  @override
  String get setPreventNegativeInventory => 'Empêcher un stock négatif';

  @override
  String get setPreventSaleBelowCost => 'Empêcher la vente sous le coût';

  @override
  String get setPrint => 'Imprimer';

  @override
  String get setPrintLargeOrderNumber => 'Imprimer un grand numéro de commande';

  @override
  String get setPrinterReceiptSettings => 'Paramètres d\'imprimante et de reçu';

  @override
  String get setPrinterGroups => 'GROUPES D\'IMPRIMANTES';

  @override
  String get setProductDefaults => 'VALEURS PAR DÉFAUT DES PRODUITS';

  @override
  String get setReadLiveWeight =>
      'Lire le poids en direct d\'une balance série';

  @override
  String get setRefundButton => 'Bouton Remboursement';

  @override
  String get setRegional => 'RÉGIONAL';

  @override
  String get setRegisteredAccount => 'Compte enregistré';

  @override
  String get setRenewsEnds => 'Renouvellement / fin';

  @override
  String get setRepair => 'Réappairer';

  @override
  String get setReplay => 'Rejouer';

  @override
  String get setRequestServiceTypeAuto =>
      'Demander le type de service automatiquement';

  @override
  String get setRequireReasonOnVoid => 'Exiger un motif d\'annulation';

  @override
  String get setRequiresFloorPlan => 'Nécessite l\'activation du plan de salle';

  @override
  String get setRescanPorts => 'Réanalyser les ports';

  @override
  String get setResetOrderNumber => 'Réinitialiser le numéro à la clôture';

  @override
  String get setWalkInHint => 'Enregistrer une commande sur place sans table';

  @override
  String get setRoom => 'Salle';

  @override
  String get setRows => 'Lignes';

  @override
  String get setScalePrintsPrice =>
      'La balance imprime le prix au lieu de la quantité';

  @override
  String get setScreenDisplayWeb => 'AFFICHAGE ÉCRAN (WEB)';

  @override
  String get setSearchAllSettings => 'Rechercher dans les paramètres...';

  @override
  String get setSearchButton => 'Bouton Recherche';

  @override
  String get setSecondaryCurrencySymbol => 'Symbole de la devise secondaire';

  @override
  String get setSelectBusinessDayOnStart => 'Choisir la journée au démarrage';

  @override
  String get setSelectEllipsis => 'Sélectionner…';

  @override
  String get setSendToKitchen => 'Envoyer en cuisine';

  @override
  String get setSendToKitchenButton => 'Bouton Envoyer en cuisine';

  @override
  String get setSender => 'EXPÉDITEUR';

  @override
  String get setSeparateRowPerItem => 'Une ligne par article';

  @override
  String get setSerialConnection => 'CONNEXION SÉRIE';

  @override
  String get setServiceStatusSelector => 'Sélecteur de statut de service';

  @override
  String get setServiceStatuses => 'Statuts de service';

  @override
  String get setServiceTypeHeader => 'TYPE DE SERVICE';

  @override
  String get setServiceTypeSelector => 'Sélecteur de type de service';

  @override
  String get setServiceTypes => 'Types de service';

  @override
  String get setShowAllOccupied => 'Afficher toutes les tables occupées';

  @override
  String get setShowCashInOnStart => 'Afficher le fonds de caisse au démarrage';

  @override
  String get setShowItemsOnPaymentForm =>
      'Afficher les articles sur le formulaire de paiement';

  @override
  String get setShowOrderTotalOnPole =>
      'Afficher le total sur un afficheur VFD / LCD série';

  @override
  String get setShowOrderTypeButtons =>
      'Afficher les boutons de type de commande';

  @override
  String get setShowProductImages =>
      'Afficher les images produits dans la grille';

  @override
  String get setShowSearchOptions =>
      'Afficher les boutons de mode de recherche';

  @override
  String get setShowServiceStatusBadge =>
      'Afficher le badge de statut sur les cartes';

  @override
  String get setShowSyncNotification =>
      'Afficher la notification de synchronisation';

  @override
  String get setShowTablesButton => 'Afficher le bouton Tables dans le POS';

  @override
  String get setSignOut => 'Se déconnecter';

  @override
  String get setSignOutDevice => 'Déconnecter l\'appareil';

  @override
  String get setSingleItemDiscount => 'Remise sur article autorisée';

  @override
  String get setSingleUser => 'Utilisateur unique';

  @override
  String get setSmtpHost => 'Hôte SMTP';

  @override
  String get setSmtpPort => 'Port SMTP';

  @override
  String get setSmtpServer => 'SERVEUR SMTP';

  @override
  String get setSorting => 'Tri';

  @override
  String get setStaff => 'Personnel';

  @override
  String get setStartOrderFreeTable =>
      'Démarrer une commande sur une table libre sans réservation';

  @override
  String get setStarted => 'Démarré';

  @override
  String get setStartup => 'DÉMARRAGE';

  @override
  String get setStopBits => 'Bits d\'arrêt';

  @override
  String get setScaleStreamHint =>
      'Transmet le poids d\'une balance COM vers le pavé de quantité';

  @override
  String get setStripLeadingZeros =>
      'Supprimer les zéros initiaux avant la recherche';

  @override
  String get setSubscription => 'Abonnement';

  @override
  String get setSystemInfo => 'INFOS SYSTÈME';

  @override
  String get setTable => 'Table';

  @override
  String get setTablesFloorPlan => 'Tables / plan de salle';

  @override
  String get setTablesFloorPlanButton => 'Bouton Tables / plan de salle';

  @override
  String get setTablesButtonLabel => 'Libellé du bouton Tables';

  @override
  String get setTaxHeader => 'TAXE';

  @override
  String get setTaxButton => 'Bouton Taxe';

  @override
  String get setTaxIncludedByDefault => 'Taxe incluse dans le prix par défaut';

  @override
  String get setTaxNo => 'N° de taxe';

  @override
  String get setTestDisplay => 'Tester l\'affichage';

  @override
  String get setThankYouMessage => 'Message de remerciement (après paiement)';

  @override
  String get setThemeMode => 'Mode du thème';

  @override
  String get setTimezone => 'Fuseau horaire';

  @override
  String get setTopLine => 'Ligne du haut';

  @override
  String get setTrackUnconfirmedVoids =>
      'Suivre les articles annulés non confirmés';

  @override
  String get setTransferButton => 'Bouton Transfert';

  @override
  String get setUpdateSalePriceFromMarkup =>
      'Mettre à jour le prix de vente selon la majoration';

  @override
  String get setUsers => 'UTILISATEURS';

  @override
  String get setVoidItems => 'ARTICLES ANNULÉS';

  @override
  String get setWarehouseSwitcher => 'Sélecteur d\'entrepôt';

  @override
  String get setWarehouseSwitcherButton => 'Bouton Sélecteur d\'entrepôt';

  @override
  String get setWeighingScale => 'Balance';

  @override
  String get setWelcomeMessage => 'MESSAGE DE BIENVENUE';

  @override
  String get setWelcomeMessageLabel =>
      'Message de bienvenue (écran d\'attente)';

  @override
  String get setWelcomeBottomLine => 'Ligne du bas du message de bienvenue';

  @override
  String get setWelcomeTopLine => 'Ligne du haut du message de bienvenue';

  @override
  String get setWhenToSync => 'Quand synchroniser';

  @override
  String get setWritingDirection => 'Sens d\'écriture';

  @override
  String get setHintCaisse => 'ex. CAISSE1';

  @override
  String get setHintUber => 'ex. UBER';

  @override
  String get setHintUberEats => 'ex. Uber Eats';

  @override
  String get setHintWaiting => 'ex. En attente';

  @override
  String get selectExportType => 'Choisir le type d\'export';

  @override
  String get exportCsv => 'CSV (Excel)';

  @override
  String get exportXml => 'XML';

  @override
  String get deleteProducts => 'Supprimer les produits';

  @override
  String get showHideColumns => 'Afficher / masquer les colonnes';

  @override
  String get alwaysShown => 'Toujours affiché';

  @override
  String get actionReset => 'Réinitialiser';

  @override
  String get products => 'Produits';

  @override
  String get columns => 'Colonnes';

  @override
  String get importLabel => 'Importer';

  @override
  String get exportLabel => 'Exporter';

  @override
  String get addProduct => 'Ajouter un produit';

  @override
  String get categoriesHeader => 'CATÉGORIES';

  @override
  String get errorLoadingGroups => 'Erreur lors du chargement des catégories';

  @override
  String get allProducts => 'Tous les produits';

  @override
  String get noProductsFound => 'Aucun produit trouvé.';

  @override
  String noProductsMatchSearch(String query) {
    return 'Aucun produit ne correspond à \"$query\".';
  }

  @override
  String get productNameRequired => 'Nom du produit *';

  @override
  String get categoryGroup => 'Catégorie / Groupe';

  @override
  String get noneUncategorized => 'Aucune (non catégorisé)';

  @override
  String get productCodeSku => 'Code produit / SKU';

  @override
  String get plu => 'PLU';

  @override
  String get measurementUnit => 'Unité de mesure';

  @override
  String get measurementUnitHint => 'ex. kg, pcs';

  @override
  String get sellByWeight => 'Vendre au poids';

  @override
  String get sellByWeightHint =>
      'Activé, le point de vente demande une quantité au lieu d\'ajouter une unité. Sans balance connectée, le bouton « Prix » modifie la quantité.';

  @override
  String get uomStockUnit => 'unité de stock';

  @override
  String get uomCategoryUnit => 'Unité';

  @override
  String get uomCategoryWeight => 'Poids';

  @override
  String get uomCategoryVolume => 'Volume';

  @override
  String get uomCategoryLength => 'Longueur';

  @override
  String uomStockHeldIn(String unit) {
    return 'Le stock est compté en $unit.';
  }

  @override
  String uomStockConversionNote(String unit, String factor, String stockUnit) {
    return 'Prix par $unit. Le stock bouge en $stockUnit — 1 $unit = $factor $stockUnit.';
  }

  @override
  String get weighItem => 'Peser l’article';

  @override
  String get placeOnScale => 'Placez l’article sur la balance';

  @override
  String get scaleNotConnected =>
      'Aucune balance connectée — saisissez la quantité';

  @override
  String get useThisWeight => 'Utiliser ce poids';

  @override
  String get enterQuantity => 'Saisir la quantité';

  @override
  String get priceEditsQuantity => 'Prix modifie la quantité';

  @override
  String get keypadAmount => 'Montant';

  @override
  String amountBuysQuantity(String amount, String quantity) {
    return '$amount donne $quantity';
  }

  @override
  String get barcodeRules => 'Règles de code-barres';

  @override
  String barcodeRulesHint(Object NNDD) {
    return 'Les règles définissent comment un code-barres scanné est lu. Un code-barres correspond à la première règle dont le motif convient, donc l\'ordre compte. Un motif peut encoder une valeur telle qu\'un poids ou un prix : $NNDD indique où se trouvent les chiffres, et les positions D sont des décimales. Un produit dont le code-barres encode une valeur doit stocker ces positions à zéro.';
  }

  @override
  String get ruleName => 'Nom de la règle';

  @override
  String get ruleType => 'Type';

  @override
  String get ruleEncoding => 'Encodage';

  @override
  String get rulePattern => 'Motif du code-barres';

  @override
  String get ruleTypeUnit => 'Produit à l’unité';

  @override
  String get ruleTypeWeighted => 'Produit pesé';

  @override
  String get ruleTypePriced => 'Produit avec prix';

  @override
  String get ruleTypeDiscounted => 'Produit remisé';

  @override
  String get addRuleLine => 'Ajouter une ligne';

  @override
  String get barcodeRulesSaved => 'Règles de code-barres enregistrées';

  @override
  String get testBarcode => 'Tester un code-barres';

  @override
  String get testBarcodeNoMatch =>
      'Aucune règle ne correspond à ce code-barres';

  @override
  String testBarcodeMatched(String rule, String value) {
    return 'Règle $rule — valeur $value';
  }

  @override
  String get weightNotAllowedForService =>
      'Un service ne peut pas être vendu au poids.';

  @override
  String get scaleReadFailed => 'Impossible de lire la balance';

  @override
  String get ageRestrictionHint => 'ex. 18';

  @override
  String get sellingPriceRequired => 'Prix de vente *';

  @override
  String get purchaseCost => 'Coût d\'achat';

  @override
  String get marginMarkup => 'Marge / Majoration (%)';

  @override
  String get rankDisplayOrder => 'Rang (ordre d\'affichage)';

  @override
  String get description => 'Description';

  @override
  String get priceIsTaxInclusive => 'Prix du produit taxes comprises';

  @override
  String get isServiceNotPhysical => 'Est un service (non physique)';

  @override
  String get changePriceAllowed => 'Modification du prix autorisée';

  @override
  String get isEnabledVisible => 'Activé (visible)';

  @override
  String get productColorMarker => 'Marqueur de couleur du produit';

  @override
  String get productImage => 'Image du produit';

  @override
  String get productImageHint =>
      'Remplace l\'icône par défaut sur la tuile du menu.';

  @override
  String get removeImage => 'Supprimer l\'image';

  @override
  String get taxInclusiveNotAppliedNote =>
      'Attention : la caisse ajoute encore cette taxe au prix. Le prix TTC est enregistré sur le produit mais pas encore appliqué à l\'encaissement.';

  @override
  String get pricingTab => 'Tarification';

  @override
  String taxBreakdownIncluded(String price, String tax, String net) {
    return '$price inclut $tax de taxe · net $net';
  }

  @override
  String taxBreakdownAdded(String price, String tax, String total) {
    return '$price + $tax de taxe = $total';
  }

  @override
  String get applyTaxes => 'Appliquer les taxes';

  @override
  String get failedToLoadTaxes => 'Échec du chargement des taxes';

  @override
  String get primaryTaxRate => 'Taux de taxe principal';

  @override
  String get noTax => 'Aucune taxe';

  @override
  String get productModifiersComments =>
      'Modificateurs et commentaires du produit';

  @override
  String get newModifierComment => 'Nouveau modificateur / commentaire';

  @override
  String get newModifierHint => 'ex. Sans oignons';

  @override
  String get deleteComment => 'Supprimer le commentaire';

  @override
  String get productBarcodes => 'Codes-barres du produit';

  @override
  String get barcode => 'Code-barres';

  @override
  String get generateBarcode => 'Générer un code-barres';

  @override
  String get noBarcodesYet => 'Aucun code-barres attribué.';

  @override
  String get pendingSync => 'Synchronisation en attente';

  @override
  String get deleteBarcode => 'Supprimer le code-barres';

  @override
  String get transactionBlocked => 'Transaction bloquée';

  @override
  String get actionOk => 'OK';

  @override
  String get transactionSuccessful => 'Transaction réussie';

  @override
  String get printReceiptPrompt => 'Voulez-vous imprimer un reçu ?';

  @override
  String get saveAsPdf => 'Enregistrer en PDF';

  @override
  String get printReceipt => 'Imprimer le reçu';

  @override
  String get splitPayments => 'Paiements fractionnés';

  @override
  String get totalLabel => 'Total';

  @override
  String get paidLabel => 'Payé';

  @override
  String get remainingLabel => 'Restant';

  @override
  String get changeLabel => 'Monnaie';

  @override
  String get removeCustomer => 'Retirer le client';

  @override
  String get redeemPoints => 'Utiliser les points';

  @override
  String get pointsToUse => 'Points à utiliser';

  @override
  String get decrementOnePoint => '-1 pt';

  @override
  String get incrementOnePoint => '+1 pt';

  @override
  String useMaxPoints(String points) {
    return 'Utiliser le max ($points pts)';
  }

  @override
  String get actionRedeem => 'Utiliser';

  @override
  String get paymentTypes => 'Types de paiement';

  @override
  String get showNavigation => 'Afficher la navigation';

  @override
  String get visibleColumns => 'Colonnes visibles';

  @override
  String get columnsTooltip => 'Colonnes';

  @override
  String get refreshTooltip => 'Actualiser';

  @override
  String get newPaymentType => 'Nouveau type de paiement';

  @override
  String errorLoadingPaymentTypes(String message) {
    return 'Erreur lors du chargement des types de paiement : $message';
  }

  @override
  String get noCompanySelectedShort => 'Aucune société sélectionnée.';

  @override
  String get noPaymentTypesFound => 'Aucun type de paiement trouvé.';

  @override
  String get addFirstPaymentType => 'Ajouter un premier type de paiement';

  @override
  String deletePaymentTypeConfirm(String name) {
    return 'Supprimer le type de paiement « $name » ?';
  }

  @override
  String get fieldNameRequired => 'Nom *';

  @override
  String get codeRequired => 'Code *';

  @override
  String get taxCodeAlreadyUsed => 'Déjà utilisé par une autre taxe';

  @override
  String get taxNameAlreadyUsed => 'Déjà utilisé par une autre taxe';

  @override
  String get fieldCode => 'Code';

  @override
  String get fieldPosition => 'Position';

  @override
  String get fieldShortcut => 'Raccourci';

  @override
  String get actionUpdate => 'Mettre à jour';

  @override
  String errorWithMessage(String message) {
    return 'Erreur : $message';
  }

  @override
  String get activePromotions => 'Promotions actives';

  @override
  String get noActivePromotions => 'Aucune promotion active pour le moment.';

  @override
  String ordersReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commandes prêtes',
      one: '1 commande prête',
    );
    return '$_temp0';
  }

  @override
  String get selectOrderType => 'Choisir le type de commande';

  @override
  String get serviceStatus => 'Statut du service';

  @override
  String get selectServiceStatus => 'Choisir le statut du service';

  @override
  String get posDiscount => 'Remise';

  @override
  String get posQuantity => 'Quantité';

  @override
  String get posTax => 'Taxe';

  @override
  String get posTransfer => 'Transférer';

  @override
  String get posRefund => 'Remboursement';

  @override
  String get posKitchen => 'Cuisine';

  @override
  String get posAddition => 'Addition';

  @override
  String get setAdditionButton => 'Bouton Addition';

  @override
  String get additionPrinted => 'Addition imprimée';

  @override
  String get posOrder => 'Commande';

  @override
  String get posBookings => 'Réservations';

  @override
  String get posPromos => 'Promos';

  @override
  String get posVoid => 'ANNULER';

  @override
  String get posPay => 'PAYER';

  @override
  String productRunningLow(String product) {
    return 'Le stock de $product est faible';
  }

  @override
  String productOutOfStock(String product) {
    return '$product est en rupture de stock';
  }

  @override
  String get availableIn => 'Disponible dans :';

  @override
  String quantityInStock(String qty) {
    return '$qty en stock';
  }

  @override
  String get noCompanySelected =>
      'Aucune société sélectionnée. Ouvrez le menu et choisissez une société.';

  @override
  String get errorLoadingData => 'Erreur lors du chargement des données';

  @override
  String get searchProductsHint => 'Rechercher des produits...';

  @override
  String get paginationFirst => 'Première';

  @override
  String get paginationPrevious => 'Précédente';

  @override
  String get paginationNext => 'Suivante';

  @override
  String get paginationLast => 'Dernière';

  @override
  String get voidOrder => 'Annuler la commande';

  @override
  String get voidOrderConfirm =>
      'Voulez-vous vraiment annuler cette commande ?';

  @override
  String get enterVoidReason => 'Saisissez le motif d\'annulation ici';

  @override
  String get refreshOrderNumber => 'Actualiser le numéro de commande';

  @override
  String get setSalePrice => 'Définir le prix de vente';

  @override
  String get fieldPrice => 'Prix';

  @override
  String get ageRestriction => 'Limite d\'âge';

  @override
  String confirmMinimumAge(String minAge) {
    return 'Confirmer ($minAge+)';
  }

  @override
  String get noTaxesAvailable => 'Aucune taxe disponible dans le système.';

  @override
  String get transferOrder => 'Transférer la commande';

  @override
  String get assignStaff => 'Assigner un employé';

  @override
  String get unassigned => 'Non assigné';

  @override
  String get assignRoomOrResource => 'Assigner une salle / ressource';

  @override
  String get noRoom => 'Aucune salle';

  @override
  String selectAvailableSpace(String space) {
    return 'Choisir $space disponible';
  }

  @override
  String get errorMissingCompanyContext =>
      'Erreur : contexte société ou utilisateur manquant.';

  @override
  String failedToQueueZReport(String message) {
    return 'Échec de la mise en file du rapport Z : $message';
  }

  @override
  String zReportNumber(String number) {
    return 'Rapport Z n° $number';
  }

  @override
  String get shiftSummaryUpper => 'RÉSUMÉ DU POSTE';

  @override
  String get dateTimeLabel => 'Date / Heure';

  @override
  String get rangeLabel => 'Plage';

  @override
  String get totalSales => 'Total des ventes';

  @override
  String get totalReturns => 'Total des retours';

  @override
  String get discountsLabel => 'Remises';

  @override
  String get taxableTotal => 'Total imposable';

  @override
  String get totalTax => 'Total des taxes';

  @override
  String get cashMovementsUpper => 'MOUVEMENTS DE CAISSE';

  @override
  String get tenderTypesUpper => 'MOYENS DE PAIEMENT';

  @override
  String get noPaymentsRecorded => 'Aucun paiement enregistré.';

  @override
  String get grandTotalUpper => 'TOTAL GÉNÉRAL';

  @override
  String get unknownLabel => 'Inconnu';

  @override
  String get currentShiftOpen => 'Poste en cours (ouvert)';

  @override
  String get historyZReports => 'Historique (rapports Z)';

  @override
  String get noOpenTransactions =>
      'Aucune transaction ouverte.\nLa caisse est équilibrée.';

  @override
  String get tenderBreakdown => 'Détail des encaissements';

  @override
  String get expectedInDrawer => 'ATTENDU EN CAISSE';

  @override
  String get shiftDetails => 'Détails du poste';

  @override
  String get cashierOnDuty => 'Caissier en service';

  @override
  String get unknownUser => 'UTILISATEUR INCONNU';

  @override
  String get transactionsLabel => 'Transactions';

  @override
  String openPaymentsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paiements ouverts',
      one: '1 paiement ouvert',
    );
    return '$_temp0';
  }

  @override
  String get shiftIsOpen => 'Poste ouvert';

  @override
  String get closeRegisterExplain =>
      'La clôture de la caisse finalisera ces transactions, générera un rapport Z et remettra à zéro les totaux du jour. Assurez-vous que les prélèvements d\'espèces sont terminés avant de continuer.';

  @override
  String get noZReportsYet => 'Aucun rapport Z généré pour l\'instant.';

  @override
  String zReportOnDate(String date) {
    return 'Rapport Z • $date';
  }

  @override
  String zReportSubtitle(String count, String total) {
    return 'Documents : $count  •  Total général : $total';
  }

  @override
  String get enterValidAmount => 'Veuillez saisir un montant valide.';

  @override
  String get selectDocumentOrAutoDistribute =>
      'Veuillez sélectionner au moins un document ou activer la répartition automatique.';

  @override
  String get nothingToSettle =>
      'Rien à régler — les documents sélectionnés sont déjà payés.';

  @override
  String anErrorOccurred(String message) {
    return 'Une erreur est survenue : $message';
  }

  @override
  String get useCustomerBalance => 'Utiliser le solde client';

  @override
  String get automaticDistribution => 'Répartition automatique';

  @override
  String get loadUnpaidDocuments => 'Charger les documents impayés';

  @override
  String get summaryLabel => 'Résumé';

  @override
  String get customerBalance => 'Solde du client';

  @override
  String get totalInSelectedDocuments => 'Total des documents sélectionnés';

  @override
  String get customerNotSelectedReconcile =>
      'Aucun client sélectionné.\nVeuillez choisir un client pour le lettrage.';

  @override
  String get autoDistributeExplain =>
      'Le montant payé sera réparti automatiquement\nsur toutes les ventes impayées.';

  @override
  String get noUnpaidDocumentsForCustomer =>
      'Aucun document impayé pour ce client.';

  @override
  String get balanceLabel => 'Solde';

  @override
  String get internalNoteLabel => 'Note interne';

  @override
  String get allDates => 'Toutes les dates';

  @override
  String userNumbered(String id) {
    return 'Utilisateur $id';
  }

  @override
  String get periodLabel => 'Période';

  @override
  String get docSearchHint => 'Rechercher un document, ou choisir un filtre';

  @override
  String get filterSuggestionsSection => 'Rechercher';

  @override
  String filterNumberContains(Object query) {
    return 'Le numero contient \"$query\"';
  }

  @override
  String filterReferenceContains(Object query) {
    return 'La reference contient \"$query\"';
  }

  @override
  String filterCustomerContains(Object query) {
    return 'Le client contient \"$query\"';
  }

  @override
  String get filterCustomRange => 'Periode personnalisee...';

  @override
  String get filterKeepTyping => 'Continuez a taper pour affiner la liste';

  @override
  String get documentNumber => 'Numéro de document';

  @override
  String get documentNumberHint => 'ex. 26-200-000001';

  @override
  String get externalDocument => 'Document externe';

  @override
  String get paidStatus => 'Statut de paiement';

  @override
  String get totalResultsUpper => 'TOTAL DES RÉSULTATS';

  @override
  String get noDocumentsMatchingFilters =>
      'Aucun document ne correspond aux filtres.';

  @override
  String get notAvailableShort => 'N/D';

  @override
  String get documentDeleted => 'Document supprimé';

  @override
  String get deleteFailed => 'Échec de la suppression';

  @override
  String get monthAbbreviations =>
      'janv.,févr.,mars,avr.,mai,juin,juil.,août,sept.,oct.,nov.,déc.';

  @override
  String get selectDocumentTypeError =>
      'Veuillez sélectionner un type de document.';

  @override
  String get selectCustomerSupplierError =>
      'Veuillez sélectionner un client / fournisseur.';

  @override
  String get selectUserError => 'Veuillez sélectionner un utilisateur.';

  @override
  String get selectWarehouseError => 'Veuillez sélectionner un entrepôt.';

  @override
  String get couldNotResolveLocalDocument =>
      'Impossible de retrouver le document local.';

  @override
  String get documentSaved => 'Document enregistré !';

  @override
  String get newDocument => 'Nouveau document';

  @override
  String editDocumentNumbered(String number) {
    return 'Modifier le document — $number';
  }

  @override
  String documentNumbered(String number) {
    return 'Document — $number';
  }

  @override
  String saveHeaderFirstHint(String action) {
    return 'Enregistrez d\'abord l\'en-tête du document (Infos document → $action) pour gérer les articles, les remises et les paiements.';
  }

  @override
  String get documentInfo => 'Infos document';

  @override
  String get partiesLogistics => 'Tiers et logistique';

  @override
  String get financialsNotes => 'Finances et notes';

  @override
  String get documentItems => 'Articles du document';

  @override
  String get paymentsTab => 'Paiements';

  @override
  String get dueDate => 'Date d\'échéance';

  @override
  String get stockDate => 'Date de stock';

  @override
  String get supplierRequired => 'Fournisseur *';

  @override
  String get applyAfterTax => 'Appliquer après taxe';

  @override
  String get saveHeaderChanges => 'Enregistrer l\'en-tête';

  @override
  String get createAndAddItems => 'Créer et ajouter des articles';

  @override
  String get noItemsAddedYet => 'Aucun article ajouté pour l\'instant.';

  @override
  String get clickAddProductToStart =>
      'Cliquez sur « Ajouter un produit » pour commencer.';

  @override
  String get qtyShort => 'Qté';

  @override
  String get itemDiscShort => 'Rem. art.';

  @override
  String get actionsLabel => 'Actions';

  @override
  String get deleteItem => 'Supprimer l\'article';

  @override
  String deleteItemConfirm(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get itemsBaseTotal => 'Total de base des articles :';

  @override
  String get selectProductError => 'Veuillez sélectionner un produit.';

  @override
  String failedToAddItem(String message) {
    return 'Échec de l\'ajout de l\'article : $message';
  }

  @override
  String updateFailedWithMessage(String message) {
    return 'Échec de la mise à jour : $message';
  }

  @override
  String get itemTax => 'Taxe de l\'article';

  @override
  String get appliedPayments => 'Paiements appliqués';

  @override
  String get deleteAllPaymentsWarning =>
      'Ce document est intégralement soldé.\n\nContinuer supprimera définitivement toutes les transactions de paiement associées. Confirmer ?';

  @override
  String get documentTotal => 'Total du document';

  @override
  String get totalPaid => 'Total payé';

  @override
  String get remainingBalance => 'Solde restant';

  @override
  String get noPaymentsAddedYet => 'Aucun paiement ajouté pour l\'instant.';

  @override
  String get deletePayment => 'Supprimer le paiement';

  @override
  String get deletePaymentConfirm =>
      'Voulez-vous vraiment supprimer ce paiement ?';

  @override
  String get selectPaymentTypeError =>
      'Veuillez sélectionner un type de paiement.';

  @override
  String get failedToAddPayment => 'Échec de l\'ajout du paiement.';

  @override
  String get updateFailedShort => 'Échec de la mise à jour.';

  @override
  String paymentTypeNamed(String name) {
    return 'Type de paiement : $name';
  }

  @override
  String get discountLabel => 'Remise';

  @override
  String get orderNumberLabel => 'Numéro de commande';

  @override
  String get updatedLabel => 'Mis à jour';

  @override
  String get statusGracePeriod => 'Renouvellement en retard';

  @override
  String get actionCreate => 'Créer';

  @override
  String get activeDevices => 'Appareils actifs';

  @override
  String get addAtLeastOneProduct =>
      'Ajoutez au moins un produit à la promotion';

  @override
  String get addCustomerSupplier => 'Ajouter un client / fournisseur';

  @override
  String get addToPromotion => 'Ajouter à la promotion';

  @override
  String get administrator => 'Administrateur';

  @override
  String get allStockEntriesUpper => 'TOUTES LES ENTRÉES DE STOCK';

  @override
  String get assignAddStock => 'Affecter / ajouter du stock';

  @override
  String get barcodesTab => 'Codes-barres';

  @override
  String cannotDeleteProductsLinked(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Impossible de supprimer $count produits — liés à des commandes ou documents existants',
      one:
          'Impossible de supprimer 1 produit — lié à des commandes ou documents existants',
    );
    return '$_temp0';
  }

  @override
  String get clearEstimate => 'Effacer le devis';

  @override
  String codeWithValue(String code) {
    return 'Code : $code';
  }

  @override
  String get companyUpdatedSuccessfully => 'Société mise à jour avec succès';

  @override
  String get conditionalPromoHint =>
      'Conditionnel (ex. : achetez-en 2, obtenez une remise)';

  @override
  String get costPrice => 'Prix de revient';

  @override
  String couldNotDeleteNamed(String name, String message) {
    return 'Impossible de supprimer « $name » : $message';
  }

  @override
  String couldNotSaveNamed(String name, String message) {
    return 'Impossible d\'enregistrer « $name » : $message';
  }

  @override
  String get countriesLabel => 'Pays';

  @override
  String get createEstimate => 'Créer un devis';

  @override
  String get createPromotion => 'Créer une promotion';

  @override
  String get customerAdded => 'Client ajouté';

  @override
  String get customerUpdated => 'Client mis à jour';

  @override
  String get daysOfWeekLabel => 'Jours de la semaine : ';

  @override
  String deleteWithCount(num count) {
    return 'Supprimer ($count)';
  }

  @override
  String deletedSomeProductsBlocked(num deleted, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$deleted supprimé(s) · $count produits conservés — liés à des commandes ou documents existants',
      one:
          '$deleted supprimé(s) · 1 produit conservé — lié à des commandes ou documents existants',
    );
    return '$_temp0';
  }

  @override
  String get deletedSuccessfully => 'Supprimé avec succès';

  @override
  String get designFloorPlans => 'Concevoir les plans de salle';

  @override
  String get detailsTab => 'Détails';

  @override
  String get deviceRevokedSuccessfully => 'Appareil révoqué avec succès';

  @override
  String get displayRank => 'Ordre d\'affichage';

  @override
  String get dueDatePeriodDays => 'Délai d\'échéance (jours)';

  @override
  String get editCustomer => 'Modifier le client';

  @override
  String get editProduct => 'Modifier le produit';

  @override
  String get editPromotion => 'Modifier la promotion';

  @override
  String get editQuantity => 'Modifier la quantité';

  @override
  String get endDateBeforeStartDate =>
      'La date de fin est antérieure à la date de début';

  @override
  String get everyDay => 'Tous les jours';

  @override
  String exportFailed(String message) {
    return 'Échec de l\'exportation : $message';
  }

  @override
  String exportedProductsTo(num count, String path) {
    return '$count produits exportés vers $path';
  }

  @override
  String get failedToCreateUser => 'Échec de la création de l\'utilisateur.';

  @override
  String get failedToSaveChanges =>
      'Échec de l\'enregistrement des modifications.';

  @override
  String get failedToUpdateUser => 'Échec de la mise à jour de l\'utilisateur.';

  @override
  String get failedToUploadLogo => 'Échec du téléversement du logo.';

  @override
  String get finishSetup => 'Terminer la configuration';

  @override
  String get flagLow => 'BAS';

  @override
  String get flagReorder => 'RÉAPPRO';

  @override
  String get floorPlanTables => 'Plan de salle / tables';

  @override
  String get folderColor => 'Couleur du dossier';

  @override
  String get folderImage => 'Image du dossier';

  @override
  String get forceReset => 'Réinitialisation forcée';

  @override
  String get groupDeleted => 'Groupe supprimé';

  @override
  String get groupHasChildrenCannotDelete =>
      'Ce groupe contient des produits ou des sous-groupes et ne peut pas être supprimé.';

  @override
  String get groupName => 'Nom du groupe';

  @override
  String get groupNameHint => 'ex. : Boissons, Desserts';

  @override
  String itemsCountValue(num count) {
    return 'Articles : $count';
  }

  @override
  String linkedAt(String date) {
    return 'Lié : $date';
  }

  @override
  String get logoUpdatedSuccessfully => 'Logo mis à jour avec succès';

  @override
  String get lowStockWarningHelp =>
      'Alerter lorsque le stock passe sous le seuil';

  @override
  String get nameIsRequired => 'Le nom est obligatoire.';

  @override
  String get nameIsRequiredShort => 'Le nom est obligatoire';

  @override
  String get newPasswordsDoNotMatch =>
      'Les nouveaux mots de passe ne correspondent pas';

  @override
  String get newProduct => 'Nouveau produit';

  @override
  String get newProductGroup => 'Nouveau groupe de produits';

  @override
  String get nextTaxesAndStock => 'Suivant : taxes et stock';

  @override
  String get noActiveDevicesFound => 'Aucun appareil actif trouvé.';

  @override
  String get noConnectionAddUsers =>
      'Aucune connexion. L\'ajout d\'utilisateurs nécessite une connexion.';

  @override
  String get noConnectionDeleteUsers =>
      'Aucune connexion. La suppression d\'utilisateurs nécessite une connexion.';

  @override
  String get noCountriesAvailable => 'Aucun pays disponible.';

  @override
  String get noCustomersFound => 'Aucun client trouvé.';

  @override
  String get noEmailProvided => 'Aucune adresse e-mail fournie';

  @override
  String get noLogoUploadedYet => 'Aucun logo téléversé pour le moment';

  @override
  String noProductsMatchQuery(String query) {
    return 'Aucun produit ne correspond à « $query »';
  }

  @override
  String get noPromotionsYet =>
      'Aucune promotion pour le moment. Appuyez sur « Ajouter une promotion » pour en créer une.';

  @override
  String get noSuppliersFound => 'Aucun fournisseur trouvé.';

  @override
  String onBelowValue(num value) {
    return 'Activé — en dessous de $value';
  }

  @override
  String get operationFailed => 'L\'opération a échoué.';

  @override
  String get overrideTaxes => 'Remplacer les taxes';

  @override
  String get parentFolder => 'Dossier parent';

  @override
  String get passwordForciblyReset => 'Mot de passe réinitialisé de force !';

  @override
  String get passwordUpdatedSuccessfully =>
      'Mot de passe mis à jour avec succès';

  @override
  String get pendingSyncNew => 'Synchronisation en attente (nouveau)';

  @override
  String get pendingSyncUpdate => 'Synchronisation en attente (mise à jour)';

  @override
  String get pinForciblyResetForDevice =>
      'Code PIN réinitialisé de force pour cet appareil !';

  @override
  String get pinMustBeFourDigits => 'Le code PIN doit comporter 4 chiffres';

  @override
  String get pinUpdatedSuccessfully => 'Code PIN mis à jour avec succès';

  @override
  String get pleaseEnterProductName => 'Veuillez saisir un nom de produit.';

  @override
  String get pleaseSelectACountry => 'Veuillez sélectionner un pays.';

  @override
  String get preferredQty => 'Qté préférée';

  @override
  String get preferredQuantityHelp => 'Quantité cible à maintenir en stock';

  @override
  String productIdLabel(num id) {
    return 'ID produit : $id';
  }

  @override
  String get productSavedLocallySyncFirst =>
      'Produit enregistré localement. Synchronisez pour terminer la configuration (taxes, codes-barres, stock).';

  @override
  String get productUpdatedSuccessfully => 'Produit mis à jour avec succès !';

  @override
  String get productsAssigned => 'Produits affectés avec succès';

  @override
  String productsDeletedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits supprimés',
      one: '1 produit supprimé',
    );
    return '$_temp0';
  }

  @override
  String promotionsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count promotions',
      one: '1 promotion',
    );
    return '$_temp0';
  }

  @override
  String get quickInventory => 'Inventaire rapide';

  @override
  String get removeFromPromotion => 'Retirer de la promotion';

  @override
  String removeStockFromWarehouseConfirm(String product, String warehouse) {
    return 'Retirer $product de $warehouse ?';
  }

  @override
  String get reorderPointHelp =>
      'Déclencher un réapprovisionnement lorsque le stock passe sous ce niveau';

  @override
  String get reprintReceipt => 'Réimprimer le reçu';

  @override
  String get requiredField => 'Obligatoire';

  @override
  String saveAssignmentsCount(num count) {
    return 'Enregistrer les affectations ($count sélectionnés)';
  }

  @override
  String get saveCompanyChangesUpper => 'ENREGISTRER LES MODIFICATIONS';

  @override
  String get saveFailedShort => 'Échec de l\'enregistrement.';

  @override
  String savedLocallyNoServerId(String name) {
    return '« $name » enregistré localement, mais le serveur n\'a pas renvoyé d\'identifiant. Il sera renvoyé lors de la prochaine synchronisation.';
  }

  @override
  String get savedLocallyWillSyncOnline =>
      'Enregistré localement. Sera synchronisé une fois en ligne.';

  @override
  String get savedOfflineWillSync =>
      'Enregistré hors ligne. Sera synchronisé une fois connecté.';

  @override
  String savedOfflineWillSyncNamed(String name) {
    return '« $name » enregistré hors ligne — il sera synchronisé au retour du serveur.';
  }

  @override
  String get savingUpper => 'ENREGISTREMENT...';

  @override
  String get scanOrEnterBarcode => 'Scannez ou saisissez le code-barres';

  @override
  String securityRuleUpdated(String rule) {
    return '$rule mis à jour.';
  }

  @override
  String get securityRules => 'Règles de sécurité';

  @override
  String get selectAtLeastOneDay =>
      'Sélectionnez au moins un jour de la semaine';

  @override
  String get selectProductsFromLeft =>
      'Sélectionnez des produits à gauche pour les ajouter à la promotion.';

  @override
  String get selectedProducts => 'Produits sélectionnés';

  @override
  String get sellingPrice => 'Prix de vente';

  @override
  String get serverErrorCheckInputs =>
      'Une erreur serveur s\'est produite. Veuillez vérifier vos saisies.';

  @override
  String get serviceTag => 'Service';

  @override
  String setTaxesAndInventoryFor(String name) {
    return 'Définir les taxes et l\'inventaire : $name';
  }

  @override
  String get setupComplete => 'Configuration terminée !';

  @override
  String get startingCashLower => 'Fonds de caisse';

  @override
  String get statusInactive => 'Inactif';

  @override
  String get stockControlRules => 'Règles de contrôle du stock';

  @override
  String get stockControlRulesUpper => 'RÈGLES DE CONTRÔLE DU STOCK';

  @override
  String get stockInWarehouseUpper => 'STOCK DANS L\'ENTREPÔT';

  @override
  String stockRulesForProduct(String name) {
    return 'Règles de stock — $name';
  }

  @override
  String get stockStatusHealthy => 'Stock sain';

  @override
  String get stockStatusLow =>
      'Stock faible — au niveau d\'alerte ou en dessous';

  @override
  String get stockStatusReorder =>
      'Au point de réapprovisionnement ou en dessous';

  @override
  String get suggestedOrder => 'Commande suggérée';

  @override
  String suggestedOrderValue(String qty, num target) {
    return '+$qty pour atteindre $target';
  }

  @override
  String get tapCameraIconToChangeLogo =>
      'Appuyez sur l\'icône appareil photo pour changer le logo';

  @override
  String get thisDevice => 'Cet appareil';

  @override
  String get unexpectedErrorOccurred =>
      'Une erreur inattendue s\'est produite.';

  @override
  String get unexpectedErrorTryAgain =>
      'Une erreur inattendue s\'est produite. Veuillez réessayer.';

  @override
  String uomWithValue(String unit) {
    return 'UM : $unit';
  }

  @override
  String get updateFailed => 'Échec de la mise à jour';

  @override
  String get userDeletedSuccessfully => 'Utilisateur supprimé avec succès.';

  @override
  String get userProfileLower => 'Profil utilisateur';

  @override
  String get viewAllOpenOrders => 'Voir toutes les commandes ouvertes';

  @override
  String get viewCostPrices => 'Voir les prix de revient';

  @override
  String get voidItem => 'Annuler l\'article';

  @override
  String get warningThresholdHelp =>
      'Afficher un avertissement lorsque la quantité est inférieure à cette valeur';

  @override
  String get weekdayAbbreviations => 'lun.,mar.,mer.,jeu.,ven.,sam.,dim.';

  @override
  String get weekdays => 'Jours ouvrables';

  @override
  String get weekends => 'Week-ends';

  @override
  String get willDeleteWhenConnectionRestored =>
      'Sera supprimé une fois la connexion rétablie';

  @override
  String get zeroStockQuantitySale => 'Vente avec stock à zéro';

  @override
  String addressWithValue(String address) {
    return 'Adresse : $address';
  }

  @override
  String get beginTrackingSession =>
      'Démarrez une session de suivi pour pointer vos heures.';

  @override
  String cashEntriesCount(num count) {
    return 'Mouvements de caisse ($count)';
  }

  @override
  String checkoutError(String message) {
    return 'Erreur d\'encaissement : $message';
  }

  @override
  String get clockOutMustBeAfterClockIn =>
      'La sortie doit être postérieure à l\'entrée.';

  @override
  String get completeTransaction => 'Valider\nla transaction';

  @override
  String couldNotLoadEntries(String message) {
    return 'Impossible de charger les mouvements : $message';
  }

  @override
  String get creditNeedsCustomer =>
      'Le paiement à crédit nécessite un client sélectionné.\n\nVeuillez choisir un client avant de valider cette transaction.';

  @override
  String deleteDocumentConfirmPermanent(String number) {
    return 'Supprimer « $number » ? Cette action est irréversible.';
  }

  @override
  String discountWithAmount(String amount, String symbol) {
    return 'Remise : $amount $symbol';
  }

  @override
  String documentsCountValue(num count) {
    return 'Nombre de documents : $count';
  }

  @override
  String get enterValidAmountAboveZero =>
      'Saisissez un montant valide supérieur à zéro.';

  @override
  String get exceedsMaximum => 'Dépasse le maximum';

  @override
  String get failedToLoadCustomers => 'Échec du chargement des clients';

  @override
  String get failedToLoadOrder => 'Échec du chargement de la commande.';

  @override
  String featureComingSoon(String feature) {
    return '$feature — bientôt disponible';
  }

  @override
  String get filterByCustomer => 'Filtrer par client';

  @override
  String get hoursReport => 'Rapport des heures';

  @override
  String labelWithColon(String label) {
    return '$label : ';
  }

  @override
  String get lastMonth => 'Le mois dernier';

  @override
  String get lastWeek => 'La semaine dernière';

  @override
  String get lastYear => 'L\'année dernière';

  @override
  String maxUsableThisOrder(String points) {
    return 'Maximum utilisable pour cette commande : $points pts';
  }

  @override
  String get missingCompanyOrUserContext =>
      'Contexte société ou utilisateur manquant.';

  @override
  String get mySales => 'Mes ventes';

  @override
  String get myShift => 'Mon service';

  @override
  String get noActiveShift => 'Aucun service en cours';

  @override
  String get noCashMovementsToday => 'Aucun mouvement de caisse aujourd\'hui.';

  @override
  String get noItemsForDocument => 'Aucun article trouvé pour ce document.';

  @override
  String get noOpenOrders => 'Aucune commande ouverte';

  @override
  String noOrdersMatchQuery(String query) {
    return 'Aucune commande ne correspond à « $query »';
  }

  @override
  String get noSalesDocumentsForPeriod =>
      'Aucun document de vente pour la période sélectionnée.';

  @override
  String get noTimeEntriesInRange =>
      'Aucun pointage dans la période sélectionnée.';

  @override
  String get nothingToExportInRange => 'Rien à exporter dans cette période';

  @override
  String get nowSelectEndDate => 'Sélectionnez maintenant une date de fin';

  @override
  String get paymentMethod => 'Mode de paiement';

  @override
  String pointsBalanceWorth(String points, String value, String symbol) {
    return 'Solde : $points pts = $value $symbol';
  }

  @override
  String get predefinedPeriod => 'Période prédéfinie';

  @override
  String get receiptLabel => 'Reçu';

  @override
  String redeemingPoints(String points, String amount, String symbol) {
    return 'Utilisation de $points pts (−$amount $symbol)';
  }

  @override
  String get reportCopiedAsCsv =>
      'Rapport copié dans le presse-papiers au format CSV';

  @override
  String get salesHistoryTitle => 'Historique des ventes';

  @override
  String get saveCashIn => 'Enregistrer l\'entrée';

  @override
  String get saveCashOut => 'Enregistrer la sortie';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get selectAnEmployeeError => 'Sélectionnez un employé.';

  @override
  String get selectDocumentToViewItems =>
      'Sélectionnez un document ci-dessus pour afficher ses articles.';

  @override
  String get sendEmail => 'Envoyer un e-mail';

  @override
  String get shiftOpen => 'Service en cours';

  @override
  String get shiftStillOpen => 'En cours';

  @override
  String get tapToRedeemPoints => 'Appuyez pour utiliser les points';

  @override
  String taxNoWithValue(String number) {
    return 'N° de TVA : $number';
  }

  @override
  String get thisMonth => 'Ce mois-ci';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get thisYear => 'Cette année';

  @override
  String get timeCardAdded => 'Pointage ajouté';

  @override
  String totalAmountWithValue(String amount, String symbol) {
    return 'Montant total : $amount $symbol';
  }

  @override
  String get totalCompleted => 'Total (terminés)';

  @override
  String get totalHours => 'Total des heures';

  @override
  String totalHoursWithValue(String hours) {
    return 'Total des heures : $hours';
  }

  @override
  String get weekdayInitials => 'Lu,Ma,Me,Je,Ve,Sa,Di';

  @override
  String get yesterday => 'Hier';

  @override
  String noStockAvailableIn(String warehouse) {
    return 'Aucun stock disponible dans $warehouse.';
  }

  @override
  String get theSelectedWarehouse => 'l\'entrepôt sélectionné';

  @override
  String warehouseNumbered(String id) {
    return 'Entrepôt $id';
  }

  @override
  String switchedToWarehouse(String warehouse) {
    return 'Basculé sur $warehouse — touchez le produit pour l\'ajouter.';
  }

  @override
  String lowStockAddAnyway(String qty, String unit) {
    return 'L\'ajout de cet article ne laisse que $qty $unit en stock, au niveau d\'alerte de stock bas ou en dessous.\n\nL\'ajouter quand même ?';
  }

  @override
  String get unitsFallback => 'unité(s)';

  @override
  String kitchenPrintError(String message) {
    return 'Erreur d\'impression cuisine : $message';
  }

  @override
  String kitchenTicketsPrinted(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString tickets cuisine envoyés',
      one: 'Ticket cuisine envoyé',
    );
    return '$_temp0';
  }

  @override
  String get kitchenNoStationMatched =>
      'Aucune imprimante de poste ne couvre ces articles — impression du ticket complet à la place.';

  @override
  String couldNotSaveOrder(String message) {
    return 'Impossible d\'enregistrer la commande : $message';
  }

  @override
  String scaleBarcodeProductNotFound(String code) {
    return 'Code-barres balance : produit « $code » introuvable.';
  }

  @override
  String errorCreatingOrder(String message) {
    return 'Erreur lors de la création de la commande : $message';
  }

  @override
  String get orderSavedToTable => 'Commande enregistrée sur la table !';

  @override
  String get orderSaved => 'Commande enregistrée !';

  @override
  String get orderVoided => 'Commande annulée';

  @override
  String get orderTransferred => 'Commande transférée';

  @override
  String transferFailed(String message) {
    return 'Échec du transfert : $message';
  }

  @override
  String receiptAlreadyRefunded(String reference) {
    return 'Ce ticket a déjà été remboursé (réf. : $reference).';
  }

  @override
  String receiptNotFound(String number) {
    return 'Ticket « $number » introuvable.';
  }

  @override
  String get managerPinNotRecognised =>
      'Code PIN gérant non reconnu. Un retour à l\'aveugle nécessite un administrateur.';

  @override
  String get addAtLeastOneItemToReturn =>
      'Ajoutez au moins un article à retourner.';

  @override
  String get selectRefundPaymentType =>
      'Sélectionnez un mode de remboursement.';

  @override
  String get blindRefundQueued =>
      'Retour à l\'aveugle en file d\'attente — synchronisation automatique.';

  @override
  String blindRefundProcessed(String number) {
    return 'Retour à l\'aveugle $number traité.';
  }

  @override
  String get lookUpReceiptFirst => 'Recherchez d\'abord un ticket.';

  @override
  String get selectAtLeastOneItemToRefund =>
      'Sélectionnez au moins un article à rembourser.';

  @override
  String get refundQueued =>
      'Remboursement en file d\'attente — synchronisation automatique.';

  @override
  String refundProcessed(String number) {
    return 'Remboursement $number traité.';
  }

  @override
  String get customerReceiptOptional => 'N° de ticket du client (facultatif)';

  @override
  String get optionalFromPaperReceipt => 'facultatif — depuis le ticket papier';

  @override
  String get blindReturnManagerAuthorised =>
      'Retour à l\'aveugle — autorisé par un gérant. Aucun ticket d\'origine.';

  @override
  String get blindReturnExplain =>
      'Un retour à l\'aveugle rembourse des marchandises sans ticket. Un gérant doit l\'approuver.';

  @override
  String priceTimesMaxQty(String price, String qty) {
    return '$price × max $qty';
  }

  @override
  String get advancedHardware => 'Avancé / matériel';

  @override
  String get changeAllowed => 'Rendu de monnaie autorisé';

  @override
  String get colCustomerRequired => 'Client requis';

  @override
  String get colMarkPaid => 'Marquer payé';

  @override
  String get colQuickPay => 'Paiement rapide';

  @override
  String get colSlip => 'Bordereau';

  @override
  String get coreSettings => 'Paramètres principaux';

  @override
  String get customerRequiredLabel => 'Client requis';

  @override
  String deleteTaxRateConfirm(String name) {
    return 'Voulez-vous vraiment supprimer le taux de taxe « $name » ?';
  }

  @override
  String get editPaymentType => 'Modifier le mode de paiement';

  @override
  String get editTaxRate => 'Modifier le taux de taxe';

  @override
  String get enterValidNumber => 'Saisissez un nombre valide';

  @override
  String get fiscal => 'Fiscal';

  @override
  String get markAsPaid => 'Marquer comme payé';

  @override
  String get oldAndNewTaxMustDiffer =>
      'L\'ancienne et la nouvelle taxe doivent être différentes.';

  @override
  String get paymentTypeDeleted => 'Mode de paiement supprimé';

  @override
  String get pleaseSelectBothTaxes => 'Veuillez sélectionner les deux taxes.';

  @override
  String get quickPayment => 'Paiement rapide';

  @override
  String get slipRequired => 'Bordereau requis';

  @override
  String get switchFailed => 'Échec du remplacement.';

  @override
  String taxRateAppliedSuccessfully(
    String rate,
    String oldName,
    String newName,
  ) {
    return 'Taux $rate de « $oldName » appliqué à « $newName » avec succès.';
  }

  @override
  String get taxRateDeleted => 'Taux de taxe supprimé';

  @override
  String get yearTotal => 'TOTAL DE L\'ANNÉE';

  @override
  String get topMonth => 'MEILLEUR MOIS';

  @override
  String monthlySalesYear(String year) {
    return 'VENTES MENSUELLES — $year';
  }

  @override
  String activeMonthsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois actifs',
      one: '1 mois actif',
    );
    return '$_temp0';
  }

  @override
  String get periodicReports => 'Rapports périodiques';

  @override
  String get selectDateRangeToFilter =>
      'Sélectionnez une plage de dates pour filtrer les cartes ci-dessous';

  @override
  String get failedToLoadYearlyData =>
      'Échec du chargement des données annuelles';

  @override
  String get noDataToDisplay => 'Aucune donnée à afficher';

  @override
  String get selectedPeriod => 'Période sélectionnée';

  @override
  String get filterLabel => 'Filtre';

  @override
  String get customersAndSuppliers => 'Clients et fournisseurs';

  @override
  String get cashRegister => 'Caisse';

  @override
  String get colImage => 'Image';

  @override
  String get fieldUnit => 'Unité';

  @override
  String get markupPercent => 'Marge %';

  @override
  String get lastPurchase => 'Dernier achat';

  @override
  String get fieldRank => 'Rang';

  @override
  String get taxInclusive => 'Taxe incluse';

  @override
  String get priceChange => 'Changement de prix';

  @override
  String get businessPartnerRequired => 'Partenaire commercial (obligatoire)';

  @override
  String get addServiceType => 'Ajouter un type de service';

  @override
  String get allValuesMustBePositive =>
      'Toutes les valeurs doivent être des nombres positifs.';

  @override
  String get bookingArrived => 'Arrivé';

  @override
  String get bookingCompleted => 'Terminée';

  @override
  String get bookingInService => 'En service';

  @override
  String get bookingNoShow => 'Absent';

  @override
  String get bookingPending => 'En attente';

  @override
  String couldNotCheckStock(String message) {
    return 'Impossible de vérifier le stock : $message';
  }

  @override
  String deleteLoyaltyCardConfirm(String name) {
    return 'Supprimer la carte de fidélité de $name ? Cette action est irréversible.';
  }

  @override
  String earningRuleExample(String symbol) {
    return 'ex. : 100 $symbol dépensés rapportent 10 pts';
  }

  @override
  String get editServiceType => 'Modifier le type de service';

  @override
  String get editWarehouse => 'Modifier l\'entrepôt';

  @override
  String get enterValidPointsValue =>
      'Saisissez une valeur de points valide et non négative.';

  @override
  String failedToAddCard(String message) {
    return 'Échec de l\'ajout de la carte : $message';
  }

  @override
  String failedToDeleteCard(String message) {
    return 'Échec de la suppression : $message';
  }

  @override
  String failedToUpdateCard(String message) {
    return 'Échec de la mise à jour de la carte : $message';
  }

  @override
  String guestsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invités',
      one: '1 invité',
    );
    return '$_temp0';
  }

  @override
  String get historyTab => 'Historique';

  @override
  String get loyaltyCardAdded => 'Carte de fidélité ajoutée';

  @override
  String get loyaltyCardDeleted => 'Carte de fidélité supprimée';

  @override
  String get loyaltyCardUpdated => 'Carte de fidélité mise à jour';

  @override
  String get loyaltySettingsSaved => 'Paramètres de fidélité enregistrés';

  @override
  String get newWarehouse => 'Nouvel entrepôt';

  @override
  String get noCardNumber => 'Aucun numéro de carte';

  @override
  String get noCompletedBookings =>
      'Aucune réservation terminée pour le moment.';

  @override
  String get noLoyaltyCardsYet => 'Aucune carte de fidélité pour le moment.';

  @override
  String get noUpcomingBookings => 'Aucune réservation à venir.';

  @override
  String get onePointEquals => '1 point équivaut à';

  @override
  String orderNumbered(String number) {
    return 'Commande n° $number';
  }

  @override
  String get pleaseSelectACustomer => 'Veuillez sélectionner un client.';

  @override
  String get pointsCannotBeNegative =>
      'Les points ne peuvent pas être négatifs.';

  @override
  String redemptionRuleExample(String symbol) {
    return 'ex. : 1 pt = 1 $symbol de remise à l\'encaissement';
  }

  @override
  String removeNamedConfirm(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String stockMovedWarehouseDeleted(String name) {
    return 'Stock déplacé vers $name ; entrepôt supprimé';
  }

  @override
  String tablesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tables',
      one: '1 table',
    );
    return '$_temp0';
  }

  @override
  String get upcoming => 'À venir';

  @override
  String get warehouseAndStockDeleted => 'Entrepôt et son stock supprimés';

  @override
  String get warehouseDeleted => 'Entrepôt supprimé';

  @override
  String warehouseStillHoldsStock(String name, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '« $name » contient encore $count articles en stock. Que faut-il en faire avant de supprimer l\'entrepôt ?',
      one:
          '« $name » contient encore 1 article en stock. Que faut-il en faire avant de supprimer l\'entrepôt ?',
    );
    return '$_temp0';
  }

  @override
  String get beforeTax => 'Avant taxe';

  @override
  String get afterTax => 'Après taxe';

  @override
  String get listLabel => 'Liste';

  @override
  String get gridLabel => 'Grille';

  @override
  String get cancelUpper => 'ANNULER';

  @override
  String get noCategory => 'Aucune catégorie';

  @override
  String get enterAGroupName => 'Saisissez un nom de groupe.';

  @override
  String categoryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count catégories',
      one: '1 catégorie',
    );
    return '$_temp0';
  }

  @override
  String get enterAnIpAddress => 'Saisissez une adresse IP';

  @override
  String get invalidIpWithExample => 'IP invalide (ex. 192.168.1.100)';

  @override
  String get invalidIp => 'IP invalide';

  @override
  String get backupDatabase => 'Sauvegarder la base de données';

  @override
  String get backingUpEllipsis => 'Sauvegarde en cours…';

  @override
  String backupSaved(String file) {
    return 'Sauvegarde enregistrée : $file';
  }

  @override
  String backupFailed(String message) {
    return 'Échec de la sauvegarde : $message';
  }

  @override
  String get selectBackupFolder => 'Choisir le dossier de sauvegarde';

  @override
  String get autoBackupExplain =>
      'Créez automatiquement des copies de sauvegarde de vos données pour vous protéger contre les pertes ou les corruptions';

  @override
  String get unitHours => 'heures';

  @override
  String get unitDays => 'jours';

  @override
  String settingSaved(String setting) {
    return '$setting enregistré';
  }

  @override
  String get customerDisplayQrHint =>
      'Scannez le code QR pour ouvrir l\'affichage client sur n\'importe quel appareil connecté à Internet.';

  @override
  String get everythingIsSynced => 'Tout est synchronisé';

  @override
  String get exitApplicationConfirm =>
      'Voulez-vous vraiment quitter l\'application ?';

  @override
  String failedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count échecs',
      one: '1 échec',
    );
    return '$_temp0';
  }

  @override
  String get fontSizeDefault => 'Par défaut';

  @override
  String get fontSizeLarge => 'Grande';

  @override
  String get fontSizeLarger => 'Très grande';

  @override
  String get fontSizeSmall => 'Petite';

  @override
  String itemsPendingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments en attente',
      one: '1 élément en attente',
    );
    return '$_temp0';
  }

  @override
  String pendingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count en attente',
      one: '1 en attente',
    );
    return '$_temp0';
  }

  @override
  String get syncAfterEverySave => 'Après chaque enregistrement';

  @override
  String get syncCashMovements => 'Mouvements de caisse';

  @override
  String get syncCompletedSales => 'Ventes terminées en attente d\'envoi';

  @override
  String get syncCustomerDiscounts => 'Remises client';

  @override
  String get syncEveryHour => 'Toutes les heures';

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get syncProductTaxes => 'Taxes produit';

  @override
  String get syncShifts => 'Services';

  @override
  String get syncStatusTitle => 'État de synchronisation';

  @override
  String get syncStockCounts => 'Inventaires';

  @override
  String get syncStockTransfers => 'Transferts de stock';

  @override
  String get syncVoids => 'Annulations';

  @override
  String get syncZReports => 'Rapports Z';

  @override
  String get syncedStatus => 'Synchronisé';

  @override
  String get syncingEllipsis => 'Synchronisation…';

  @override
  String get backupPathHintWindows => 'ex. D:\\database\\Backup';

  @override
  String get backupPathHintUnix => 'ex. /home/user/backups';

  @override
  String get backupPathHintManaged =>
      'Géré par l\'application — touchez Ouvrir l\'emplacement';

  @override
  String get exchangeRateHint => 'ex. 1.08  (1 principale = X secondaire)';

  @override
  String get addServiceStatus => 'Ajouter un statut de service';

  @override
  String get clearFavorites => 'Effacer les favoris';

  @override
  String get editServiceStatus => 'Modifier le statut de service';

  @override
  String get hintTablesRooms => 'ex. : Tables, Salles';

  @override
  String get hintUnitsExample => 'ex. : pcs, kg, L';

  @override
  String get includeSubgroups => 'Inclure les sous-groupes';

  @override
  String get noReportsFound => 'Aucun rapport trouvé.';

  @override
  String noSettingsMatching(String query) {
    return 'Aucun paramètre ne correspond à « $query »';
  }

  @override
  String get notSet => 'Non défini';

  @override
  String get reportComingSoon => 'Ce rapport sera bientôt disponible.';

  @override
  String scaleErrorWithMessage(String message) {
    return 'Erreur de balance : $message';
  }

  @override
  String get selectBusinessPartnerInFilter =>
      'Veuillez sélectionner un partenaire commercial dans le panneau de filtres.';

  @override
  String get selectReportToViewOrPrint =>
      'Sélectionnez un rapport à consulter ou imprimer';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String ageRestrictionBody(num age) {
    return 'Ce produit exige que le client ait au moins $age ans.\n\nVeuillez confirmer que le client remplit cette condition avant de continuer.';
  }

  @override
  String get bookingCompletedLocked =>
      'Cette réservation est terminée et ne peut pas être modifiée.';

  @override
  String get bookingPrefix => 'Réservation : ';

  @override
  String get branch => 'Succursale';

  @override
  String clockedInWithValue(String value) {
    return 'Pointé · $value';
  }

  @override
  String deleteBookingConfirm(String name) {
    return 'Supprimer la réservation de « $name » ?';
  }

  @override
  String get editBooking => 'Modifier la réservation';

  @override
  String errorLoadingDataWithMessage(String message) {
    return 'Erreur lors du chargement des données : $message';
  }

  @override
  String errorLoadingSpaces(String message) {
    return 'Erreur lors du chargement des espaces : $message';
  }

  @override
  String get exitEditMode => 'Quitter le mode édition';

  @override
  String get newBooking => 'Nouvelle réservation';

  @override
  String noFreeSpacesAvailable(String space) {
    return 'Aucun(e) $space disponible';
  }

  @override
  String get openOrderNow => 'Ouvrir la commande maintenant';

  @override
  String get removeFloorPlanConfirm =>
      'Cela supprimera définitivement le plan de salle et toutes ses tables. Continuer ?';

  @override
  String get sendingSignal => 'Envoi du signal...';

  @override
  String get shapeLabel => 'Forme';

  @override
  String get sizeLabel => 'Taille';

  @override
  String get staffPrefix => '  ·  Personnel : ';

  @override
  String tableNumbered(String number) {
    return 'Table n° $number';
  }

  @override
  String taxesForProduct(String product) {
    return 'Taxes · $product';
  }

  @override
  String get testDrawerOpen => 'Tester l\'ouverture du tiroir';

  @override
  String todayWithValue(String value) {
    return 'Aujourd\'hui : $value';
  }

  @override
  String get updateStatusUpper => 'METTRE À JOUR LE STATUT';

  @override
  String voidReasonPrompt(String number) {
    return 'Saisissez ou sélectionnez un motif d\'annulation pour « $number »';
  }

  @override
  String get accessDenied => 'Accès refusé';

  @override
  String get accessDeniedBody =>
      'Vous n\'avez pas l\'autorisation de consulter cette section.\nChoisissez une autre section dans le menu ou demandez l\'accès à un administrateur.';

  @override
  String get accessDeniedAskAdmin =>
      'Vous n\'avez pas l\'autorisation d\'effectuer cette action.\nDemandez à un administrateur de la faire pour vous.';

  @override
  String get checkingUpper => 'VÉRIFICATION…';

  @override
  String get chooseYourMenuLayout => 'Choisissez la disposition de votre menu';

  @override
  String get connectingEllipsis => 'Connexion…';

  @override
  String createFirstAdminFor(String company) {
    return 'Créez le premier utilisateur administrateur pour $company';
  }

  @override
  String discountAmountLine(String currency, String amount) {
    return 'Remise  −$currency $amount';
  }

  @override
  String get editCurrency => 'Modifier la devise';

  @override
  String enableResource(String resource) {
    return 'Activer $resource';
  }

  @override
  String get errorLoadingRooms => 'Erreur lors du chargement des salles';

  @override
  String expiredOnDate(String date) {
    return 'Expiré le $date';
  }

  @override
  String get getGoingInThreeSteps => 'Démarrez en 3 étapes';

  @override
  String get managementPortal => 'Portail de gestion';

  @override
  String get menuLayoutHint =>
      'L\'affichage des produits sur l\'écran de vente — modifiable à tout moment dans les Paramètres.';

  @override
  String get noFloorPlans => 'Aucun plan de salle';

  @override
  String openOrderForEachResource(String resource) {
    return 'Ouvrez une commande pour chaque $resource.';
  }

  @override
  String get poweredByPos => 'Propulsé par POS';

  @override
  String get reconnectingEllipsis => 'Reconnexion…';

  @override
  String get retryConnectionUpper => 'RÉESSAYER LA CONNEXION';

  @override
  String checkedAgainstEndpoint(String endpoint) {
    return 'Vérifié auprès de $endpoint';
  }

  @override
  String scaleUnitMismatch(String scaleUnit, String productUnit) {
    return 'La balance affiche $scaleUnit mais cet article est tarifé au $productUnit — aucune conversion n\'est appliquée.';
  }

  @override
  String get selectServiceTypeForOrder =>
      'Sélectionnez le type de service pour cette commande';

  @override
  String tableHeldByReservation(String name) {
    return 'Cette table est réservée pour « $name ».';
  }

  @override
  String get thankYou => 'Merci !';

  @override
  String get weWillSwitchOnFeatures =>
      'Nous activerons les bonnes fonctionnalités pour vous.';

  @override
  String get whatsYourBusiness => 'Quelle est votre activité ?';

  @override
  String get changeThisLaterInSettings =>
      'Vous pourrez modifier tout cela plus tard dans les Paramètres.';

  @override
  String get everythingBuiltIn => 'Tout est inclus — aucun module à acheter.';

  @override
  String get everythingYouGet => 'Tout ce que vous obtenez';

  @override
  String get getStarted => 'Commencer';

  @override
  String get linkDeviceUpper => 'ASSOCIER L\'APPAREIL';

  @override
  String numberOfProductsToImport(num count) {
    return 'Nombre de produits à importer : $count';
  }

  @override
  String get setUpYourTerminal => 'Configurez votre terminal';

  @override
  String get statusExpiresToday => 'Expire aujourd\'hui';

  @override
  String get accessDeniedNoPermission =>
      'Accès refusé : vous n\'avez pas l\'autorisation d\'effectuer cette action.';

  @override
  String alreadyBookedDuringTime(String what, String name, String range) {
    return 'Ce/cette $what est déjà réservé(e) sur ce créneau — $name ($range).';
  }

  @override
  String get cannotBookInPast =>
      'Impossible de créer une réservation dans le passé.';

  @override
  String changesRejected(num count, String details) {
    return '$count modifications ont été rejetées : $details';
  }

  @override
  String get couldNotFindActiveOrder =>
      'Impossible de trouver une commande active.';

  @override
  String get couldNotOpenReservationOrder =>
      'Impossible d\'ouvrir la commande de réservation. Elle a peut-être été terminée ou annulée.';

  @override
  String get couldNotReachServer =>
      'Impossible de joindre le serveur. Vérifiez votre connexion Internet.';

  @override
  String get currencyDeleted => 'Devise supprimée';

  @override
  String get endTimeAfterStartTime =>
      'L\'heure de fin doit être postérieure à l\'heure de début.';

  @override
  String failedToSaveField(String field) {
    return 'Échec de l\'enregistrement de $field';
  }

  @override
  String importFailed(String message) {
    return 'Échec de l\'importation : $message';
  }

  @override
  String get licenseInvalidBody =>
      'La licence de ce terminal n\'a pas pu être vérifiée. Contactez le support pour rétablir le service.';

  @override
  String get licenseInvalidContactSupport =>
      'La licence est invalide. Veuillez contacter le support.';

  @override
  String get licenseInvalidTitle => 'Licence invalide';

  @override
  String get orderNotFoundCompletedOrVoided =>
      'Commande introuvable. Elle a peut-être été terminée ou annulée.';

  @override
  String pendingTapForStatus(num count) {
    return '$count en attente — appuyez pour l’état de synchronisation';
  }

  @override
  String printFailed(String message) {
    return 'Échec de l\'impression : $message';
  }

  @override
  String get reservationNoLongerActive =>
      'Cette réservation n\'est plus active.';

  @override
  String get selectAtLeastOneTable =>
      'Veuillez sélectionner au moins une table.';

  @override
  String get selectCompanyFirst => 'Sélectionnez d\'abord une société';

  @override
  String get staffMemberLower => 'membre du personnel';

  @override
  String get subscriptionInactiveBody =>
      'Votre abonnement n\'est pas actif. Contactez votre prestataire pour le renouveler, puis réessayez la connexion pour continuer à vendre.';

  @override
  String get subscriptionInactiveTitle => 'Abonnement inactif';

  @override
  String get subscriptionStillInactive =>
      'L\'abonnement est toujours inactif. Veuillez contacter votre prestataire.';

  @override
  String get syncComplete => 'Synchronisation terminée';

  @override
  String get syncFailed => 'Échec de la synchronisation';

  @override
  String syncFinishedWithFailures(String entities) {
    return 'Synchronisation terminée, mais ces éléments ont échoué : $entities';
  }

  @override
  String get syncStatusTooltip => 'État de synchronisation';

  @override
  String get tableNeedsBooking =>
      'Cette table nécessite une réservation. Créez-en une, puis démarrez le service depuis celle-ci.';

  @override
  String get terminalNotLinked =>
      'Ce terminal n\'est pas associé. Réassociez l\'appareil.';

  @override
  String get testMessageSent => 'Message de test envoyé.';

  @override
  String get testSignalSentToDrawer => 'Signal de test envoyé au tiroir-caisse';

  @override
  String get urlCopied => 'URL copiée';

  @override
  String get accessRulesNotSynced =>
      'Les règles d\'accès ne sont pas encore arrivées sur cet appareil. Connectez-vous au réseau et synchronisez, puis réessayez.';

  @override
  String get updateSectionTitle => 'Mise à jour du logiciel';

  @override
  String get updateAutoCheckLabel =>
      'Rechercher les mises à jour automatiquement';

  @override
  String get updateCheckNow => 'Vérifier maintenant';

  @override
  String get updateChecking => 'Vérification…';

  @override
  String get updateUpToDate => 'Vous utilisez la dernière version';

  @override
  String updateAvailableLabel(String version) {
    return 'La version $version est disponible';
  }

  @override
  String get updateDownloadAction => 'Télécharger la mise à jour';

  @override
  String updateDownloadingLabel(String percent) {
    return 'Téléchargement… $percent %';
  }

  @override
  String get updateInstallAction => 'Installer et redémarrer';

  @override
  String get updateCancelAction => 'Annuler le téléchargement';

  @override
  String get updateFailedLabel => 'Impossible de vérifier les mises à jour';

  @override
  String get updateBlockedByCart =>
      'Terminez ou videz la vente en cours avant la mise à jour.';

  @override
  String updatePendingWarning(int count) {
    return '$count élément(s) en attente de synchronisation. Synchronisez d’abord si possible.';
  }

  @override
  String get updateRestartNotice =>
      'L\'application se fermera pour installer la mise à jour.';

  @override
  String get updateUnsupportedPlatform =>
      'Les mises à jour intégrées sont disponibles uniquement sous Windows.';

  @override
  String updateAvailableSnackbar(String version) {
    return 'La version $version est disponible — ouvrez Réglages › À propos pour l’installer.';
  }

  @override
  String get setDocuments => 'Documents';

  @override
  String get resetDatabaseTitle => 'RÉINITIALISER LA BASE';

  @override
  String get resetDatabaseAction => 'Réinitialiser la base';

  @override
  String get resetWarningBanner =>
      'Opération destructive. Elle supprime les données sélectionnées pour TOUTE votre société — chaque terminal les perdra à sa prochaine synchronisation. Irréversible.';

  @override
  String get resetStepBackupTitle => 'Chemin de sauvegarde';

  @override
  String get resetStepBackupSubtitle =>
      'Emplacement où la sauvegarde sera enregistrée';

  @override
  String get resetStepBackupHint =>
      'Une sauvegarde de cet appareil est effectuée avant la réinitialisation. Si elle échoue, la réinitialisation est annulée.';

  @override
  String get resetBackupManagedHint =>
      'Stockage géré de l’application (cet appareil)';

  @override
  String get resetStepEntitiesTitle => 'Sélectionner les entités';

  @override
  String get resetStepEntitiesSubtitle =>
      'Les entités sélectionnées seront supprimées de la base';

  @override
  String get resetStepConfirmTitle => 'Confirmation';

  @override
  String get resetStepConfirmSubtitle =>
      'Autoriser et exécuter la réinitialisation';

  @override
  String get resetAdminPin => 'Saisir le code administrateur';

  @override
  String get resetAlsoClearsDocuments =>
      'Efface aussi les Documents — les ventes y font référence.';

  @override
  String get resetDocumentsNote =>
      'Ventes, commandes, paiements, annulations, rapports Z, sessions de caisse et mouvements d’espèces. Les réservations et les pointages sont conservés.';

  @override
  String get resetEverything => 'Tout';

  @override
  String get resetEverythingNote =>
      'Toutes les données. Les utilisateurs et vos paramètres sont conservés.';

  @override
  String get resetWrongPin => 'Code incorrect.';

  @override
  String get resetConfirmTitle => 'Réinitialiser la base ?';

  @override
  String get resetConfirmBody =>
      'Ceci supprime définitivement les données sélectionnées pour toute la société, sur tous les terminaux. Seule la sauvegarde locale permet de les récupérer.';

  @override
  String get resetConfirmAction => 'Oui, réinitialiser';

  @override
  String get resetNoCompany => 'Aucune société sélectionnée sur cet appareil.';

  @override
  String get resetPhaseBackup => 'Sauvegarde de cet appareil…';

  @override
  String get resetPhaseServer => 'Effacement des données du compte…';

  @override
  String get resetPhaseLocal => 'Effacement de cet appareil…';

  @override
  String get resetDoneTitle => 'Réinitialisation terminée';

  @override
  String get resetRestartManually =>
      'Veuillez fermer et rouvrir l’application.';

  @override
  String get resetOnlyAdmins =>
      'Seuls les administrateurs peuvent réinitialiser la base.';

  @override
  String resetRestartingIn(int seconds) {
    return 'Redémarrage dans $seconds…';
  }

  @override
  String resetBackupSavedTo(String path) {
    return 'Sauvegarde enregistrée dans $path';
  }

  @override
  String get restoreDatabaseTitle => 'Restaurer depuis une sauvegarde';

  @override
  String get restoreDatabaseAction => 'Restaurer une sauvegarde…';

  @override
  String get restoreDatabaseHint =>
      'Remplace tout sur ce terminal par un fichier de sauvegarde. L’application redémarre pour terminer.';

  @override
  String get restorePickTitle => 'Sélectionner une sauvegarde (.sqlite)';

  @override
  String get restoreRejectedTitle => 'Ce fichier ne peut pas être restauré';

  @override
  String get restoreConfirmTitle => 'Restaurer cette sauvegarde ?';

  @override
  String get restoreConfirmBody =>
      'Tout ce qui se trouve sur ce terminal sera remplacé par la sauvegarde. Votre base actuelle est conservée sous pos_app.superseded.sqlite au cas où.';

  @override
  String get restoreConfirmAction => 'Restaurer et redémarrer';

  @override
  String get restoreStagedTitle => 'Sauvegarde prête';

  @override
  String get restoreStagedBody =>
      'L’application va redémarrer pour installer la base. Reconnectez-vous ensuite — le travail de la sauvegarde qui n’a jamais atteint le cloud sera envoyé à la prochaine synchronisation.';

  @override
  String get restoreErrMissing => 'Le fichier n’existe plus.';

  @override
  String get restoreErrNotSqlite =>
      'Ce n’est pas un fichier de base de données.';

  @override
  String get restoreErrEncrypted =>
      'Cette sauvegarde est chiffrée pour un autre appareil et ne peut pas être ouverte ici. Restaurez-la sur le terminal qui l’a créée, ou repartez de zéro depuis le cloud.';

  @override
  String get restoreErrNotPosBackup =>
      'C’est une base de données, mais pas une sauvegarde POS.';

  @override
  String restoreErrNewerSchema(int found, int supported) {
    return 'Sauvegarde créée par une version plus récente (base v$found, cette version comprend v$supported). Mettez d’abord l’application à jour.';
  }

  @override
  String get dbMissingTitle => 'Base de données locale introuvable';

  @override
  String get dbMissingBody =>
      'Le fichier de base de ce terminal est manquant — supprimé, déplacé, ou sur un disque non connecté.\n\nRepartir de zéro télécharge vos données du cloud, mais rien de ce qui n’a jamais été synchronisé ne pourra être récupéré ainsi.';

  @override
  String get dbMissingRestore => 'Restaurer depuis une sauvegarde';

  @override
  String get dbMissingFresh => 'Repartir de zéro depuis le cloud';

  @override
  String get dbMissingFreshConfirm =>
      'Repartir de zéro ? Tout ce qui n’a pas atteint le cloud sera perdu.';

  @override
  String get onboardingDataTitle => 'Configurer ce terminal';

  @override
  String get onboardingDataSubtitle =>
      'Comment ce terminal doit-il obtenir ses données ?';

  @override
  String get onboardingCloudTitle => 'Synchroniser avec le cloud';

  @override
  String get onboardingCloudBody =>
      'Connectez-vous et téléchargez les données. À choisir pour un nouveau terminal.';

  @override
  String get onboardingRestoreTitle => 'Restaurer une sauvegarde';

  @override
  String get onboardingRestoreBody =>
      'Utiliser une sauvegarde .sqlite d’un autre terminal — pour remplacer une machine, y compris le travail non synchronisé.';

  @override
  String get balanceDue => 'Solde dû';

  @override
  String get telLabel => 'Tél';

  @override
  String get itemsLabel => 'Articles';

  @override
  String get timeLabel => 'Heure';

  @override
  String get unitPriceLabel => 'Prix unitaire';

  @override
  String get taxInvoiceUpper => 'FACTURE';

  @override
  String get billTo => 'Facturé à';

  @override
  String get invoicesUpper => 'FACTURES';

  @override
  String get saveReceiptTitle => 'Enregistrer le reçu';

  @override
  String get saveGuestCheckTitle => 'Enregistrer l’addition';

  @override
  String get saveInvoicePdfTitle => 'Enregistrer la facture PDF';

  @override
  String get zReportUpper => 'RAPPORT Z';

  @override
  String get endOfReport => '*** FIN DU RAPPORT ***';

  @override
  String get totalQty => 'Qté totale';

  @override
  String get pointsBalance => 'Solde de points';

  @override
  String get ptsShort => 'pts';

  @override
  String get invoiceNoLabel => 'Facture n°';

  @override
  String get pointsUsed => 'Points utilisés';

  @override
  String get paymentStatus => 'Statut du paiement';

  @override
  String pageNumberLabel(String number) {
    return 'Page $number';
  }

  @override
  String get createdWith => 'Créé avec';

  @override
  String get backupPathRequiredTitle => 'Choisissez un dossier de sauvegarde';

  @override
  String get backupPathRequiredBody =>
      'Les sauvegardes automatiques ont besoin d\'un dossier. Choisissez-en un maintenant, sinon elles seront écrites dans un emplacement que vous n\'avez pas choisi.';

  @override
  String get backupPathNotSet =>
      'Les sauvegardes automatiques restent désactivées tant qu\'aucun dossier n\'est défini.';

  @override
  String get posSession => 'Session POS';

  @override
  String get sessionNoneTitle => 'Aucune session ouverte';

  @override
  String get sessionNoneBody =>
      'Cette caisse n\'est pas encore ouverte. Ouvrez une session pour commencer la journée.';

  @override
  String get openRegister => 'Ouvrir la caisse';

  @override
  String get continueSelling => 'Continuer la vente';

  @override
  String get sessionNumber => 'Session';

  @override
  String get sessionDevice => 'Appareil';

  @override
  String get sessionOpenedAt => 'Ouverte à';

  @override
  String get sessionOpenedBy => 'Ouverte par';

  @override
  String get sessionClosedBy => 'Fermée par';

  @override
  String get sessionStatusLabel => 'Statut';

  @override
  String get sessionOpeningCash => 'Fonds de caisse';

  @override
  String get sessionExpectedCash => 'Espèces attendues';

  @override
  String get sessionCountedCash => 'Espèces comptées';

  @override
  String get sessionDifference => 'Différence';

  @override
  String get sessionOrders => 'Commandes';

  @override
  String get sessionPaymentTotals => 'Totaux par paiement';

  @override
  String get sessionSyncStatus => 'Synchronisation';

  @override
  String get sessionSynced => 'Tout est synchronisé';

  @override
  String get sessionNotSyncedYet => 'Pas encore envoyée au cloud';

  @override
  String sessionUnsyncedSales(int count) {
    return '$count vente(s) encore sur cet appareil';
  }

  @override
  String sessionOpenOrders(int count) {
    return '$count commande(s) encore en attente';
  }

  @override
  String get sessionCannotClose => 'Fermeture impossible';

  @override
  String get sessionForceClosed => 'Fermée de force';

  @override
  String get sessionLateArrivals =>
      'Des ventes tardives sont arrivées après la fermeture — à réconcilier';

  @override
  String get sessionCashInferred =>
      'Modes espèces déduits — définissez-les dans Paramètres → Commande et paiement.';

  @override
  String get sessionOpeningCashPrompt => 'Combien d\'espèces au départ ?';

  @override
  String get sessionHistory => 'Historique des sessions';

  @override
  String get sessionNoHistory => 'Aucune session.';

  @override
  String get sessionConfirmOpening => 'Confirmer l\'ouverture';

  @override
  String get sessionInProgress => 'En cours';

  @override
  String get sessionClosingControl => 'Contrôle de fermeture';

  @override
  String get sessionClosedPosted => 'Fermée et comptabilisée';

  @override
  String get showKeypad => 'Clavier';

  @override
  String get hideKeypad => 'Masquer le clavier';

  @override
  String get removeLogo => 'Supprimer le logo';

  @override
  String get removeLogoConfirm =>
      'Le ticket imprimera le nom de la societe a la place. Vous pouvez televerser un nouveau logo a tout moment.';

  @override
  String get logoRemoved => 'Logo supprime';

  @override
  String get openingControl => 'Contrôle d\'ouverture';

  @override
  String get openingNote => 'Note d\'ouverture';

  @override
  String get openingNoteHint => 'Ajouter une note d\'ouverture…';

  @override
  String get closingRegister => 'Fermeture de caisse';

  @override
  String get closingNote => 'Note de fermeture';

  @override
  String get closingNoteHint => 'Ajouter une note de fermeture…';

  @override
  String sessionOrdersTotal(int count, String total) {
    return '$count documents : $total';
  }

  @override
  String get sessionExpected => 'Attendu';

  @override
  String get sessionCounted => 'Compté';

  @override
  String get sessionOpeningRow => 'Ouverture';

  @override
  String get sessionCashInOutRow => 'Entrée / Sortie';

  @override
  String get sessionCashPaymentsRow => 'Paiements en espèces';

  @override
  String get cashCount => 'Comptage des espèces';

  @override
  String get dailySale => 'Vente du jour';

  @override
  String get actionDiscard => 'Annuler';

  @override
  String managerAuthRequired(String diff, String max) {
    return 'L\'écart de $diff dépasse la limite de $max. Une autorisation du responsable est requise.';
  }

  @override
  String get managerAuthorise => 'Autorisation du responsable';

  @override
  String get managerPinPrompt =>
      'Saisissez le code PIN d\'un administrateur pour autoriser cet écart.';

  @override
  String get managerPinWrong =>
      'Ce code PIN n\'est pas celui d\'un administrateur.';

  @override
  String get sessionRequiredTitle => 'Ouvrez d\'abord la caisse';

  @override
  String get sessionRequiredBody =>
      'Les ventes, remboursements et mouvements de caisse appartiennent à une session. Ouvrez la caisse pour commencer.';

  @override
  String get sessionNotTradingBody =>
      'Cette caisse est en cours de fermeture. Terminez le comptage, puis ouvrez une nouvelle session.';

  @override
  String get setRequireOpenSession => 'Exiger une session ouverte pour vendre';

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionColId => 'ID de session';

  @override
  String get sessionColPos => 'Point de vente';

  @override
  String get sessionColOpenedBy => 'Ouverte par';

  @override
  String get sessionColOpening => 'Date d\'ouverture';

  @override
  String get sessionColClosing => 'Date de fermeture';

  @override
  String get sessionColStarting => 'Solde initial';

  @override
  String get sessionColEnding => 'Solde final';

  @override
  String get sessionColTheoretical => 'Fermeture théorique';

  @override
  String get sessionColStatus => 'Statut';

  @override
  String get sessionSearchHint => 'Rechercher…';

  @override
  String sessionCountOf(int shown, int total) {
    return '$shown / $total';
  }

  @override
  String get sessionDetails => 'Détails de la session';

  @override
  String get sessionCurrentOnThisDevice => 'Session en cours sur cet appareil';

  @override
  String get sessionClosedAt => 'Fermée le';

  @override
  String get sessionDuration => 'Durée';

  @override
  String get sessionTotalTaken => 'Total encaissé';

  @override
  String get sessionCashMovements => 'Mouvements de caisse';

  @override
  String get sessionNotes => 'Notes';

  @override
  String get cashDrawer => 'Caisse';

  @override
  String get sessionRemoteFiguresOffline =>
      'Serveur injoignable — voici uniquement les chiffres de ce terminal. Les encaissements complets de la caisse viennent du serveur.';

  @override
  String get sessionDocuments => 'Documents';

  @override
  String get sessionOverviewTab => 'Aperçu';

  @override
  String get sessionPaymentsTab => 'Paiements';

  @override
  String get sessionNoPayments => 'Aucun paiement encaissé dans cette session.';

  @override
  String get sessionNoDocuments =>
      'Aucun document enregistré dans cette session.';

  @override
  String get sessionDocumentsHint => 'Touchez un document pour l\'ouvrir';

  @override
  String get sessionOpenDocumentHint =>
      'Touchez un paiement pour ouvrir son document';

  @override
  String get sessionDocumentUnavailable =>
      'Ce document n\'est pas sur cet appareil.';

  @override
  String get developerModeHint =>
      'Affiche un bouton de débogage flottant sur ce terminal, avec un simulateur de codes-barres prix et poids.';

  @override
  String get generateScaleBarcode => 'Étiquette balance';

  @override
  String scaleBarcodeRuleUnusable(String pattern) {
    return 'La règle $pattern ne peut pas générer un code produit.';
  }

  @override
  String barcodeAlreadyUsedBy(String code, String product) {
    return '$code appartient déjà à $product.';
  }

  @override
  String get setPosSession => 'Session POS';

  @override
  String get setCashMethods => 'Modes espèces';

  @override
  String get cashMethodsHint =>
      'Les modes de paiement qui sortent du tiroir-caisse et sont comptés physiquement à la clôture. Tout décocher revient à les deviner.';

  @override
  String get cashMethodsInferredHint =>
      'Non défini — déduit de « rendu de monnaie autorisé ».';

  @override
  String get cashMethodsConfirm => 'Utiliser ceux-ci';

  @override
  String get noPaymentMethodsDefined => 'Aucun mode de paiement défini.';

  @override
  String get setMaxCashDifference => 'Écart de caisse autorisé';

  @override
  String get maxCashDifferenceHint =>
      'Au-delà, la clôture exige le code PIN d’un administrateur.';

  @override
  String get cashDrawerTransport => 'Comment le tiroir est raccordé';

  @override
  String get cashDrawerTransportPrinter => 'Via l’imprimante de tickets (RJ11)';

  @override
  String get cashDrawerTransportNetwork =>
      'Réseau — IP de l’imprimante ou du tiroir';

  @override
  String get cashDrawerTransportSerial => 'Port série (COM)';

  @override
  String get cashDrawerTransportHint =>
      'Où le signal d’ouverture est envoyé. La plupart des tiroirs se branchent sur le port RJ11 de l’imprimante de tickets.';

  @override
  String get cashDrawerHost => 'Adresse IP';

  @override
  String get cashDrawerTcpPort => 'Port';

  @override
  String get cashDrawerSerialPortLabel => 'Port COM';

  @override
  String get cashDrawerBaudRate => 'Débit (bauds)';

  @override
  String get cashDrawerOpenedOk => 'Signal envoyé au tiroir-caisse';

  @override
  String cashDrawerFailed(String error) {
    return 'Impossible d’ouvrir le tiroir-caisse : $error';
  }

  @override
  String get cashDrawerTransportUnavailable =>
      'Cette connexion n’est pas disponible sur cet appareil.';

  @override
  String get cashDrawerNotConfigured =>
      'Aucun tiroir-caisse n\'est configuré sur ce terminal. Activez-en un dans Réglages → Imprimantes → Tiroir-caisse.';

  @override
  String get posOpenDrawer => 'Ouvrir le tiroir';

  @override
  String get setSounds => 'Sons';

  @override
  String get setSoundsEnabled => 'Activer les sons';

  @override
  String get setSoundVolume => 'Volume';

  @override
  String get setSoundScanOk => 'Scan accepté';

  @override
  String get setSoundScanFail => 'Scan refusé';

  @override
  String get setSoundCheckout => 'Vente terminée';

  @override
  String get setSoundError => 'Message d’erreur';

  @override
  String get soundsHint =>
      'Brefs signaux sonores à la caisse. Appuyez sur lecture pour en écouter un.';

  @override
  String get playSound => 'Écouter ce son';

  @override
  String get printZReport => 'Imprimer rapport Z';

  @override
  String get zReportPreview => 'Rapport Z — aperçu';

  @override
  String get nothingToReport =>
      'Rien à déclarer — aucun paiement n’a été encaissé.';

  @override
  String get modifierGroups => 'Groupes d\'options';

  @override
  String get modifierGroupsHint =>
      'Un groupe est un ensemble de choix — « Garnitures », « Cuisson ». Créez-le une fois ici, puis rattachez-le à autant de produits que vous voulez depuis l\'onglet Options du produit.';

  @override
  String get addModifierGroup => 'Nouveau groupe';

  @override
  String get editModifierGroup => 'Modifier le groupe';

  @override
  String get noModifierGroupsYet => 'Aucun groupe d\'options';

  @override
  String get modifierGroupNameHint => 'Garnitures';

  @override
  String get modifierOptionsTitle => 'Choix';

  @override
  String get addModifierOption => 'Ajouter un choix';

  @override
  String get optionNameHint => 'Supplément fromage';

  @override
  String get extraPrice => 'Prix en plus';

  @override
  String get minSelections => 'Doit choisir au moins';

  @override
  String get maxSelections => 'Peut choisir au plus';

  @override
  String get selectionRuleOptionalOne => 'Facultatif · un seul';

  @override
  String selectionRuleOptionalMany(int max) {
    return 'Facultatif · jusqu\'à $max';
  }

  @override
  String get selectionRuleExactlyOne => 'Obligatoire · un seul';

  @override
  String selectionRuleRange(int min, int max) {
    return 'Obligatoire · de $min à $max';
  }

  @override
  String get allowFreeText => 'Autoriser une note libre';

  @override
  String get allowFreeTextHint =>
      'Ajoute un champ libre à cette section, pour « sans glace » ou « allergique aux noix ».';

  @override
  String get groupIsDisabled => 'Désactivé';

  @override
  String get groupEnabled => 'Disponible en caisse';

  @override
  String optionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count choix',
      one: '1 choix',
      zero: 'aucun choix',
    );
    return '$_temp0';
  }

  @override
  String deleteModifierGroupQ(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteModifierGroupBody =>
      'Il sera retiré de tous les produits qui le proposent. Les ventes passées gardent leur propre copie et ne changent pas.';

  @override
  String get disableRatherThanDelete =>
      'Désactiver un groupe vaut souvent mieux que le supprimer : le changement atteint toutes les caisses à la prochaine synchro, alors qu\'une suppression n\'arrive qu\'à une synchro complète.';

  @override
  String get modifierGroupSaved => 'Groupe enregistré';

  @override
  String get aGroupNeedsAName => 'Le groupe a besoin d\'un nom';

  @override
  String get mandatoryNeedsOptions =>
      'Un groupe obligatoire a besoin d\'au moins un choix, sinon le produit ne pourrait jamais être vendu.';

  @override
  String minCannotExceedChoices(int min, int count) {
    return 'Vous demandez $min choix mais n\'en avez listé que $count.';
  }

  @override
  String get productModifierGroups => 'Groupes d\'options';

  @override
  String get productModifierGroupsHint =>
      'En caisse, toucher ce produit demandera ceci, dans cet ordre.';

  @override
  String get noGroupsAttached =>
      'Aucun groupe rattaché — le produit part directement au panier.';

  @override
  String get attachModifierGroup => 'Rattacher un groupe';

  @override
  String get moveUp => 'Monter';

  @override
  String get moveDown => 'Descendre';

  @override
  String get chooseAModifierGroup => 'Choisir un groupe';

  @override
  String get noModifierGroupsExistYet =>
      'Vous n\'avez encore créé aucun groupe d\'options. Créez-en un dans Gestion → Groupes d\'options, puis revenez le rattacher ici.';

  @override
  String get allModifierGroupsAttached =>
      'Tous les groupes sont déjà rattachés';

  @override
  String get dragToReorderGroups =>
      'Glissez pour changer l\'ordre des questions en caisse.';

  @override
  String get dragToReorderColumns =>
      'Faites glisser pour changer l\'ordre des colonnes';

  @override
  String get noResultsForFilters => 'Aucun résultat pour ces filtres';

  @override
  String get colSelectionRule => 'Règle de sélection';

  @override
  String get posModifiers => 'Options';

  @override
  String get setModifiersButton => 'Bouton Options';

  @override
  String customizeItem(String name) {
    return 'Personnaliser $name';
  }

  @override
  String get addToOrder => 'Ajouter à la commande';

  @override
  String chooseAtLeastN(int min) {
    return 'Choisissez au moins $min';
  }

  @override
  String get aNoteForTheKitchen => 'Note pour la cuisine';

  @override
  String get aNoteHint => 'sans glace, allergique aux noix…';

  @override
  String get maxReachedForGroup => 'Limite atteinte';

  @override
  String get editChoices => 'Modifier les choix';

  @override
  String get tagRequired => 'Obligatoire';

  @override
  String get tagDone => 'Fait';

  @override
  String get tagOptional => 'Facultatif';

  @override
  String get customizeEyebrow => 'PERSONNALISER';

  @override
  String get groupIcon => 'Icône';

  @override
  String get groupIconHint =>
      'Affichée à côté du groupe en caisse. Facultatif.';

  @override
  String get iconNone => 'Aucune';

  @override
  String get iconBurger => 'Burger';

  @override
  String get iconPizza => 'Pizza';

  @override
  String get iconMeal => 'Plat';

  @override
  String get iconSide => 'Accompagnement';

  @override
  String get iconSauce => 'Sauce';

  @override
  String get iconDrink => 'Boisson';

  @override
  String get iconDessert => 'Dessert';

  @override
  String get iconSpice => 'Piquant';

  @override
  String get rptTitleSalesByProduct => 'VENTES PAR PRODUIT';

  @override
  String get rptTitleSalesByGroup => 'VENTES PAR GROUPE DE PRODUITS';

  @override
  String get rptTitleSalesTax => 'TAXES SUR LES VENTES';

  @override
  String get rptTitleSalesByCustomer => 'VENTES PAR CLIENT';

  @override
  String get rptTitlePaymentByCustomer => 'MODES DE PAIEMENT PAR CLIENT';

  @override
  String get rptTitlePaymentByUser => 'MODES DE PAIEMENT PAR UTILISATEUR';

  @override
  String get rptTitlePaymentTypes => 'VENTES PAR MODE DE PAIEMENT';

  @override
  String get rptTitleItemList => 'LISTE DES ARTICLES VENDUS';

  @override
  String get rptTitleProfit => 'BÉNÉFICE';

  @override
  String get rptTitleStockMovement => 'MOUVEMENT DE STOCK';

  @override
  String get rptTitleItemDiscounts => 'REMISES SUR ARTICLES';

  @override
  String get rptTitleDiscountsBySource => 'REMISES PAR ORIGINE';

  @override
  String get rptTitleDiscountsGranted => 'REMISES ACCORDÉES (TTC)';

  @override
  String get rptTitleVoidedItems => 'ARTICLES ANNULÉS';

  @override
  String get rptTitleStartingCash => 'ENTRÉES DE FONDS DE CAISSE';

  @override
  String get rptTitleUnpaidSales => 'VENTES IMPAYÉES';

  @override
  String get rptTitleHourlyByGroup => 'VENTES HORAIRES PAR GROUPE DE PRODUITS';

  @override
  String get rptTitleByTable => 'VENTES PAR TABLE / N° DE COMMANDE';

  @override
  String get rptTitleHourlySales => 'VENTES HORAIRES';

  @override
  String get rptTitleDailySales => 'VENTES QUOTIDIENNES';

  @override
  String get rptTitleInvoices => 'FACTURES';

  @override
  String get rptTitleRefunds => 'REMBOURSEMENTS';

  @override
  String get rptTitleSalesByUsers => 'VENTES PAR UTILISATEUR';

  @override
  String get rptTitleUnpaidPurchase => 'ACHATS IMPAYÉS';

  @override
  String get rptTitlePurchaseBySupplier => 'ACHATS PAR FOURNISSEUR';

  @override
  String get rptTitlePurchaseByProduct => 'ACHATS PAR PRODUIT';

  @override
  String get rptTitleExpirationDate => 'DATES D\'EXPIRATION';

  @override
  String get rptTitlePurchaseTax => 'TAXES SUR LES ACHATS';

  @override
  String get rptTitlePurchaseInvoices => 'FACTURES D\'ACHAT';

  @override
  String get rptTitlePurchasedItemDiscounts => 'REMISES SUR ARTICLES ACHETÉS';

  @override
  String get rptTitlePurchaseDiscounts => 'REMISES SUR ACHATS';

  @override
  String get rptTitleStockReturns => 'RETOURS DE STOCK PAR PRODUIT';

  @override
  String get rptTitleLossAndDamage => 'PERTES ET CASSE PAR PRODUIT';

  @override
  String get rptTitleReorderList => 'LISTE DE RÉAPPROVISIONNEMENT';

  @override
  String get rptTitleLowStock => 'ALERTE DE STOCK BAS';

  @override
  String get rptTitleTransactionHistory => 'HISTORIQUE DES TRANSACTIONS';

  @override
  String get rptTitleStockReport => 'RAPPORT DE STOCK';

  @override
  String get rptColUom => 'UdM';

  @override
  String get rptColTaxName => 'Nom de la taxe';

  @override
  String get rptColRefNumber => 'N° de réf.';

  @override
  String get rptColRefShort => 'N° réf.';

  @override
  String get rptColDocument => 'Document';

  @override
  String get rptColDocumentShort => 'N° document';

  @override
  String get rptColCustomerCode => 'Code client';

  @override
  String get rptColTotalTax => 'Total des taxes';

  @override
  String get rptColCreateDate => 'Date de création';

  @override
  String get rptColProfit => 'Bénéfice';

  @override
  String get rptColMargin => 'Marge';

  @override
  String get rptColNumSales => 'Nb de ventes';

  @override
  String get rptColNumberOfSales => 'Nombre de ventes';

  @override
  String get rptColSalesCount => 'Nombre de ventes';

  @override
  String get rptColAverageSale => 'Vente moyenne';

  @override
  String get rptColTotalSales => 'Total des ventes';

  @override
  String get rptColHours => 'Heures';

  @override
  String get rptColTotalDiscount => 'Total des remises';

  @override
  String get rptColDiscountSource => 'Origine de la remise';

  @override
  String get rptColTotalBeforeDisc => 'Total avant remise';

  @override
  String get rptColTotalAfterDisc => 'Total après remise';

  @override
  String get rptColDiscountGranted => 'Remise accordée';

  @override
  String get rptColBeforeDisc => 'Avant remise';

  @override
  String get rptColAfterDisc => 'Après remise';

  @override
  String get rptColTotalDisc => 'Total remise';

  @override
  String get rptColTotalPaid => 'Total payé';

  @override
  String get rptColTotalUnpaid => 'Total impayé';

  @override
  String get rptColDueDate => 'Date d\'échéance';

  @override
  String get rptColVoidedBy => 'Annulé par';

  @override
  String get rptColVoided => 'Annulé le';

  @override
  String get rptColCreated => 'Créé le';

  @override
  String get rptColReason => 'Motif';

  @override
  String get rptColQtyShort => 'Qté';

  @override
  String get rptColOrderNo => 'N° commande';

  @override
  String get rptColPaymentMethod => 'Mode de paiement';

  @override
  String get rptColPurchaseNumber => 'Numéro d\'achat';

  @override
  String get rptColExpirationDate => 'Date d\'expiration';

  @override
  String get rptColProductName => 'Nom du produit';

  @override
  String get rptColOrderQty => 'Qté à commander';

  @override
  String get rptColCurrentStock => 'Stock actuel';

  @override
  String get rptColWarningQty => 'Seuil d\'alerte';

  @override
  String get rptColTransactionType => 'Type de transaction';

  @override
  String get rptColCredit => 'Crédit';

  @override
  String get rptColDebit => 'Débit';

  @override
  String get rptColTableOrOrder => 'Table / n° de commande';

  @override
  String get rptColZReportNo => 'N° rapport Z';

  @override
  String get rptColCompany => 'Société';

  @override
  String get rptColCostPrice => 'Prix de revient';

  @override
  String get rptColCostBeforeTax => 'Coût HT';

  @override
  String get rptColCostInclTax => 'Coût TTC';

  @override
  String get rptFastMoving => 'Rotation rapide';

  @override
  String get rptSlowMoving => 'Rotation lente';

  @override
  String get rptStatusConfirmed => 'Confirmé';

  @override
  String get rptStatusPending => 'En attente';

  @override
  String get rptBusinessPartner => 'Partenaire commercial';

  @override
  String get rptNetTotal => 'Total net';

  @override
  String get rptTotalsRow => 'TOTAUX';

  @override
  String get rptNoGroup => '(aucun)';

  @override
  String get rptNoDiscountsInPeriod => 'Aucune remise sur cette période.';

  @override
  String rptTotalNumberOfSales(String count) {
    return 'Nombre total de ventes : $count';
  }

  @override
  String rptAverageSalesPerItem(String count) {
    return 'Nombre moyen de ventes par article : $count';
  }

  @override
  String rptOrdersDiscounted(String count) {
    return 'Nombre de commandes remisées : $count';
  }

  @override
  String rptTotalDiscounted(String amount) {
    return 'Total remisé : $amount';
  }

  @override
  String rptPageOf(String page, String total) {
    return 'Page $page / $total';
  }

  @override
  String rptProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits',
      one: '1 produit',
    );
    return '$_temp0';
  }

  @override
  String get rptColHourStart => 'Heure de début';

  @override
  String get rptColHourEnd => 'Heure de fin';

  @override
  String get rptFavorites => 'Favoris';

  @override
  String get rptColTotalBefTax => 'Total HT';

  @override
  String get saveStockReportTitle => 'Enregistrer le rapport de stock';
}
