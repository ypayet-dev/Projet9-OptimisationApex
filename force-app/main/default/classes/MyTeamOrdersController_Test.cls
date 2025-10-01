@IsTest
private class MyTeamOrdersController_Test {
  // Utilitaire : crée un user standard (optionnellement avec un manager)
  private static User newUser(String alias, Id managerId) {
    Profile p = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
    User u = new User(
      FirstName = 'T',
      LastName = 'User' + alias,
      Email = 'tuser.' + alias + '@example.com',
      Username = 'tuser.' +
        alias +
        '@example.com.' +
        System.currentTimeMillis(),
      Alias = alias,
      TimeZoneSidKey = 'Europe/Paris',
      LocaleSidKey = 'fr_FR',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'fr',
      ProfileId = p.Id
    );
    if (managerId != null)
      u.ManagerId = managerId;
    return u;
  }

  // Utilitaire : prépare un produit vendable dans le pricebook standard
  private static PricebookEntry ensureStandardPbe() {
    Id stdPbId = Test.getStandardPricebookId(); // active le PB standard en test si besoin
    Product2 prod = new Product2(Name = 'Produit Test', IsActive = true);
    insert prod;
    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = stdPbId,
      Product2Id = prod.Id,
      UnitPrice = 50, // prix arbitraire
      IsActive = true
    );
    insert pbe;
    return pbe;
  }

  // Utilitaire : crée un Order + 1 OrderItem pour alimenter TotalAmount
  private static Order createOrderWithItem(
    Id ownerId,
    Id accountId,
    PricebookEntry pbe,
    Decimal qty,
    Decimal unitPriceOverride
  ) {
    Order ord = new Order(
      Name = 'Test Order',
      AccountId = accountId,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      OwnerId = ownerId,
      Pricebook2Id = pbe.Pricebook2Id
    );
    insert ord;

    // Crée une ligne pour que TotalAmount soit valorisé
    OrderItem oi = new OrderItem(
      OrderId = ord.Id,
      PricebookEntryId = pbe.Id,
      Quantity = qty,
      UnitPrice = unitPriceOverride // on fixe le prix pour un total maîtrisé
    );
    insert oi;

    // Recharger l’order pour récupérer TotalAmount (rollup)
    ord = [SELECT Id, TotalAmount FROM Order WHERE Id = :ord.Id];
    System.assertNotEquals(
      null,
      ord.TotalAmount,
      'TotalAmount doit être valorisé après insertion d’un OrderItem.'
    );
    return ord;
  }

  @IsTest
  static void test_getTeamOrders_noFilter() {
    // 1) Préparer l’organisation : manager courant + 2 subordonnés
    User manager = newUser('mgr', null);
    insert manager;

    User u1 = newUser('u1', manager.Id);
    insert u1;
    User u2 = newUser('u2', manager.Id);
    insert u2;

    // 2) Données communes
    Account acc = new Account(Name = 'Compte Test');
    insert acc;
    PricebookEntry pbe = ensureStandardPbe();

    // 3) Exécuter sous le manager (UserInfo.getUserId() = manager.Id)
    System.runAs(manager) {
      // Orders pour u1 et u2 (dans l’équipe), et un hors équipe pour contrôle
      Order o1 = createOrderWithItem(u1.Id, acc.Id, pbe, 2, 80); // 160
      Order o2 = createOrderWithItem(u2.Id, acc.Id, pbe, 1, 120); // 120

      User outsider = newUser('out', null);
      insert outsider;
      Order oOut = createOrderWithItem(outsider.Id, acc.Id, pbe, 3, 200); // hors équipe

      // 4) Appel du contrôleur sans filtre selectedOwnerId
      MyTeamOrdersController ctrl = new MyTeamOrdersController();
      List<Order> teamOrders = ctrl.getTeamOrders();

      // 5) Vérifs
      
      Set<Id> returnedIds = new Set<Id>();
      for (Order o : teamOrders)
        returnedIds.add(o.Id);

      System.assert(
        returnedIds.contains(o1.Id),
        'o1 (u1) doit être dans la liste.'
      );
      System.assert(
        returnedIds.contains(o2.Id),
        'o2 (u2) doit être dans la liste.'
      );
      System.assert(
        !returnedIds.contains(oOut.Id),
        'L’order hors équipe ne doit PAS être renvoyé.'
      );

      
      Decimal expected = o1.TotalAmount + o2.TotalAmount;
      System.assertEquals(
        expected,
        ctrl.teamTotal,
        'teamTotal doit sommer les TotalAmount de l’équipe.'
      );
    }
  }

  @IsTest
  static void test_getTeamOrders_withSelectedOwnerFilter() {
    // 1) Manager + 2 subordonnés
    User manager = newUser('mgr2', null);
    insert manager;
    User u1 = newUser('u1b', manager.Id);
    insert u1;
    User u2 = newUser('u2b', manager.Id);
    insert u2;

    // 2) Données
    Account acc = new Account(Name = 'Compte Test B');
    insert acc;
    PricebookEntry pbe = ensureStandardPbe();

    System.runAs(manager) {
      Order o1 = createOrderWithItem(u1.Id, acc.Id, pbe, 4, 25); // 100
      Order o2 = createOrderWithItem(u2.Id, acc.Id, pbe, 5, 30); // 150

      // 3) Contrôleur avec filtre sur u1
      MyTeamOrdersController ctrl = new MyTeamOrdersController();
      ctrl.selectedOwnerId = u1.Id;
      List<Order> teamOrders = ctrl.getTeamOrders();

      // 4) Vérifs 
      System.assertEquals(
        1,
        teamOrders.size(),
        'Avec selectedOwnerId, on ne doit retourner que les orders de ce Owner.'
      );
      System.assertEquals(
        u1.Id,
        teamOrders[0].OwnerId,
        'Le seul order renvoyé doit appartenir à u1.'
      );

      
      Decimal expectedTeamTotal = o1.TotalAmount + o2.TotalAmount;
      System.assertEquals(
        expectedTeamTotal,
        ctrl.teamTotal,
        'teamTotal additionne actuellement tous les orders de l’équipe (non filtré par selectedOwnerId).'
      );
    }
  }

  @IsTest
  static void test_getTeamOrders_emptyTeamHasZeroTotal() {
    // Cas limite : aucun subordonné, aucun order
    User manager = newUser('mgr3', null);
    insert manager;
    System.runAs(manager) {
      MyTeamOrdersController ctrl = new MyTeamOrdersController();
      List<Order> teamOrders = ctrl.getTeamOrders();
      System.assertEquals(
        0,
        teamOrders.size(),
        'Sans données, la liste doit être vide.'
      );
      System.assertEquals(
        0,
        ctrl.teamTotal,
        'Sans données, le total d’équipe doit être 0.'
      );
    }
  }
}
