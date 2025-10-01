@IsTest
public class OrderTrigger_Test {
  // Utilitaire pour créer un produit + PricebookEntry actif
  private static PricebookEntry createActivePbe(Decimal unitPrice) {
    Product2 prod = new Product2(Name = 'Test Prod', IsActive = true);
    insert prod;
    Id stdPbId = Test.getStandardPricebookId();
    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = stdPbId,
      Product2Id = prod.Id,
      UnitPrice = unitPrice,
      IsActive = true
    );
    insert pbe;
    return pbe;
  }

  @IsTest
  static void test_NetAmount_And_CA_On_Activated() {
    // Arrange
    Account acc = new Account(Name = 'ACC A');
    insert acc;
    PricebookEntry pbe = createActivePbe(100);
    Order ord = new Order(
      AccountId = acc.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      ShipmentCost__c = 20,
      Pricebook2Id = pbe.Pricebook2Id,
      Name = 'Cmd A1'
    );
    insert ord;
    insert new OrderItem(
      OrderId = ord.Id,
      Quantity = 2,
      UnitPrice = 100,
      PricebookEntryId = pbe.Id
    ); // Total=200

    // Act (passage en Activated)
    Test.startTest();
    ord = [SELECT Id, Status FROM Order WHERE Id = :ord.Id];
    ord.Status = 'Activated';
    update ord;
    Test.stopTest();

    // Assert
    Order ordAfter = [SELECT NetAmount__c FROM Order WHERE Id = :ord.Id];
    System.assertEquals(
      180,
      ordAfter.NetAmount__c,
      'NetAmount doit être calculé'
    );
    Account accAfter = [
      SELECT Chiffre_d_affaire__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    System.assertEquals(
      180,
      accAfter.Chiffre_d_affaire__c,
      'CA compte doit être mis à jour'
    );
  }

  @IsTest
  static void test_No_CA_Update_If_Not_Activated() {
    // Arrange
    Account acc = new Account(Name = 'ACC B');
    insert acc;
    PricebookEntry pbe = createActivePbe(50);
    Order ord = new Order(
      AccountId = acc.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      ShipmentCost__c = 10,
      Pricebook2Id = pbe.Pricebook2Id,
      Name = 'Cmd B1'
    );
    insert ord;
    insert new OrderItem(
      OrderId = ord.Id,
      Quantity = 2,
      UnitPrice = 50,
      PricebookEntryId = pbe.Id
    );

    // Act (update sans changer le statut)
    Test.startTest();
    ord = [SELECT Id, Name FROM Order WHERE Id = :ord.Id];
    ord.Name = 'Cmd B1 modifiée';
    update ord;
    Test.stopTest();

    // Assert (pas de CA car pas de commande Activated)
    Account accAfter = [
      SELECT Chiffre_d_affaire__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    System.assertEquals(
      null,
      accAfter.Chiffre_d_affaire__c,
      'Pas de MAJ du CA sans Activated'
    );
  }

  @IsTest
  static void test_Bulk_Multiple_Accounts() {
    // Arrange : deux comptes avec plusieurs commandes
    Account a1 = new Account(Name = 'ACC C1');
    Account a2 = new Account(Name = 'ACC C2');
    insert new List<Account>{ a1, a2 };
    PricebookEntry pbe = createActivePbe(100);

    // A1 : 2 commandes (Net = 190 chacune → total 380)
    Order a1o1 = new Order(
      AccountId = a1.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      ShipmentCost__c = 10,
      Pricebook2Id = pbe.Pricebook2Id,
      Name = 'A1-1'
    );
    Order a1o2 = new Order(
      AccountId = a1.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      ShipmentCost__c = 10,
      Pricebook2Id = pbe.Pricebook2Id,
      Name = 'A1-2'
    );
    // A2 : 2 commandes (Net = 180 chacune → total 360)
    Order a2o1 = new Order(
      AccountId = a2.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      ShipmentCost__c = 20,
      Pricebook2Id = pbe.Pricebook2Id,
      Name = 'A2-1'
    );
    Order a2o2 = new Order(
      AccountId = a2.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      ShipmentCost__c = 20,
      Pricebook2Id = pbe.Pricebook2Id,
      Name = 'A2-2'
    );
    insert new List<Order>{ a1o1, a1o2, a2o1, a2o2 };
    insert new List<OrderItem>{
      new OrderItem(
        OrderId = a1o1.Id,
        Quantity = 2,
        UnitPrice = 100,
        PricebookEntryId = pbe.Id
      ),
      new OrderItem(
        OrderId = a1o2.Id,
        Quantity = 2,
        UnitPrice = 100,
        PricebookEntryId = pbe.Id
      ),
      new OrderItem(
        OrderId = a2o1.Id,
        Quantity = 2,
        UnitPrice = 100,
        PricebookEntryId = pbe.Id
      ),
      new OrderItem(
        OrderId = a2o2.Id,
        Quantity = 2,
        UnitPrice = 100,
        PricebookEntryId = pbe.Id
      )
    };

    // Act (activation en bulk)
    Test.startTest();
    for (Order o : new List<Order>{ a1o1, a1o2, a2o1, a2o2 })
      o.Status = 'Activated';
    update new List<Order>{ a1o1, a1o2, a2o1, a2o2 };
    Test.stopTest();

    // Assert
    Account a1After = [
      SELECT Chiffre_d_affaire__c
      FROM Account
      WHERE Id = :a1.Id
    ];
    Account a2After = [
      SELECT Chiffre_d_affaire__c
      FROM Account
      WHERE Id = :a2.Id
    ];
    System.assertEquals(
      380,
      a1After.Chiffre_d_affaire__c,
      'CA attendu pour A1'
    );
    System.assertEquals(
      360,
      a2After.Chiffre_d_affaire__c,
      'CA attendu pour A2'
    );
  }

  @IsTest
  static void test_StatusChange_To_Draft_Resets_CA() {
    // Arrange
    Account acc = new Account(Name = 'ACC D');
    insert acc;
    PricebookEntry pbe = createActivePbe(100);
    Order ord = new Order(
      AccountId = acc.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      ShipmentCost__c = 10,
      Pricebook2Id = pbe.Pricebook2Id,
      Name = 'Cmd D1'
    );
    insert ord;
    insert new OrderItem(
      OrderId = ord.Id,
      Quantity = 1,
      UnitPrice = 100,
      PricebookEntryId = pbe.Id
    );

    // Act : passer Activated puis revenir Draft
    ord = [SELECT Id, Status FROM Order WHERE Id = :ord.Id];
    ord.Status = 'Activated';
    update ord;
    ord = [SELECT Id, Status FROM Order WHERE Id = :ord.Id];
    ord.Status = 'Draft';
    Test.startTest();
    update ord;
    Test.stopTest();

    // Assert : CA doit revenir à 0
    Account accAfter = [
      SELECT Chiffre_d_affaire__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    System.assertEquals(
      0,
      accAfter.Chiffre_d_affaire__c,
      'CA doit être remis à zéro quand plus Activated'
    );
  }
}
