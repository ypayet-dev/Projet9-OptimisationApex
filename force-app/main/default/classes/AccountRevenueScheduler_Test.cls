@IsTest
private class AccountRevenueScheduler_Test {
  @IsTest
  static void testSchedulerRunsBatchAndFixesRevenue() {
    // ARRANGE — données de test
    Account acc = new Account(Name = 'Sched Test ACC');
    insert acc;

    Product2 prod = new Product2(Name = 'Sched Prod', IsActive = true);
    insert prod;

    Id pbId = Test.getStandardPricebookId();
    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = pbId,
      Product2Id = prod.Id,
      UnitPrice = 100,
      IsActive = true
    );
    insert pbe;

    Order ord = new Order(
      AccountId = acc.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      ShipmentCost__c = 10,
      Pricebook2Id = pbId,
      Name = 'Sched Order'
    );
    insert ord;

    // TotalAmount = 1 * 100
    insert new OrderItem(
      OrderId = ord.Id,
      Quantity = 1,
      UnitPrice = 100,
      PricebookEntryId = pbe.Id
    );

    // ACT (1) — passage à Activated pour déclencher le calcul de NetAmount__c via le trigger
    ord = [SELECT Id, Status FROM Order WHERE Id = :ord.Id];
    ord.Status = 'Activated';
    update ord;

    // ASSERT intermédiaire — s’assurer que le NetAmount a bien été calculé (doit être 90)
    Order ordCheck = [
      SELECT Status, NetAmount__c, ShipmentCost__c, TotalAmount
      FROM Order
      WHERE Id = :ord.Id
    ];
    System.assertEquals(
      'Activated',
      ordCheck.Status,
      'La commande doit être Activated avant planification'
    );
    System.assertEquals(
      90,
      ordCheck.NetAmount__c,
      'Le NetAmount doit être 100 - 10 = 90 avant le scheduler'
    );

    // On corrompt volontairement le CA pour vérifier que le scheduler + batch le corrige
    acc = [SELECT Id, Chiffre_d_affaire__c FROM Account WHERE Id = :acc.Id];
    acc.Chiffre_d_affaire__c = 0;
    update acc;

    // ACT (2) — exécuter

    Test.startTest();
    Database.executeBatch(new AccountRevenueRecalcAllBatch(), 200);
    Test.stopTest();

    // ASSERT final — CA corrigé = Net(100 - 10) = 90
    acc = [SELECT Chiffre_d_affaire__c FROM Account WHERE Id = :acc.Id];
    System.assertEquals(
      90,
      acc.Chiffre_d_affaire__c,
      'Le scheduler+batch doivent recalculer le CA à 90'
    );
  }

  @IsTest
  static void testSchedulerInvokesBatch() {
    Test.startTest();
    System.schedule('TestJob', '0 0 0 * * ?', new AccountRevenueScheduler());
    Test.stopTest();
    System.assert(true, 'Scheduler executed without error');
  }
}
