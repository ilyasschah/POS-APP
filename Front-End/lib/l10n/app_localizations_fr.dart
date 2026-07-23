// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

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
  String get saveAndRestart => 'Enregistrer et redémarrer';

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
  String get setCommentButton => 'Bouton Commentaire';

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
  String get setCustomerDisplay => 'AFFICHEUR CLIENT';

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
  String get setDefaultSearch => 'Recherche par défaut';

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
  String get setShowSearchOptions => 'Afficher les options de recherche';

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
  String get noCommentsYet => 'Aucun commentaire ajouté.';

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
  String get posComment => 'Commentaire';

  @override
  String get posTransfer => 'Transférer';

  @override
  String get posRefund => 'Remboursement';

  @override
  String get posKitchen => 'Cuisine';

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
  String get enterQuantity => 'Saisir la quantité';

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
  String commentsForProduct(String product) {
    return 'Commentaires : $product';
  }

  @override
  String get customComment => 'Commentaire personnalisé';

  @override
  String get addANoteHint => 'Ajouter une note...';

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
}
