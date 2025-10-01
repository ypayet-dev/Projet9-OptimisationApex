@isTest
public class AccountRevenueRecalcAllBatch_Test {
  @isTest
  static void testBatchExecution() {
    // Setup : compte + produit + order Draft puis Activated
    Account acc = new Account(Name = 'Batch Test Account');
    insert acc;

    Product2 prod = new Product2(Name = 'ProdBatch', IsActive = true);
    insert prod;

    // IMPORTANT : utiliser Test.getStandardPricebookId() en test
    Id pbId = Test.getStandardPricebookId();
    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = pbId,
      Product2Id = prod.Id,
      UnitPrice = 50,
      IsActive = true
    );
    insert pbe;

    // Créer la commande en Draft
    Order ord = new Order(
      AccountId = acc.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      ShipmentCost__c = 10,
      Pricebook2Id = pbId,
      Name = 'Batch Order'
    );
    insert ord;

    // Ajouter une ligne (TotalAmount = 2 * 50 = 100)
    OrderItem oi = new OrderItem(
      OrderId = ord.Id,
      Quantity = 2,
      UnitPrice = 50,
      PricebookEntryId = pbe.Id
    );
    insert oi;

    // Activer la commande après ajout des lignes
    ord = [SELECT Id, Status FROM Order WHERE Id = :ord.Id];
    ord.Status = 'Activated';
    update ord;

    // Exécution du batch
    Test.startTest();
    Database.executeBatch(new AccountRevenueRecalcAllBatch(), 200);
    Test.stopTest();

    // Vérif : Chiffre d’affaire = NetAmount__c de la commande (100 - 10 = 90)
    acc = [SELECT Chiffre_d_affaire__c FROM Account WHERE Id = :acc.Id];
    System.assertEquals(
      90,
      acc.Chiffre_d_affaire__c,
      'Le batch doit recalculer le CA correctement'
    );
  }
}
