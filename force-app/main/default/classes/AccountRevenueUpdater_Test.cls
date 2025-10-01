@isTest
public class AccountRevenueUpdater_Test {
  @isTest
  static void testUpdateForAccounts() {
    Account acc = new Account(Name = 'Updater Test Account');
    insert acc;

    Product2 prod = new Product2(Name = 'ProdUpdater', IsActive = true);
    insert prod;

    // IMPORTANT : utiliser Test.getStandardPricebookId() en test
    Id pbId = Test.getStandardPricebookId();
    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = pbId,
      Product2Id = prod.Id,
      UnitPrice = 100,
      IsActive = true
    );
    insert pbe;

    // Créer la commande en Draft
    Order ord = new Order(
      AccountId = acc.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      ShipmentCost__c = 20,
      Pricebook2Id = pbId,
      Name = 'Updater Order'
    );
    insert ord;

    // Ajouter une ligne (TotalAmount = 1 * 100 = 100)
    OrderItem oi = new OrderItem(
      OrderId = ord.Id,
      Quantity = 1,
      UnitPrice = 100,
      PricebookEntryId = pbe.Id
    );
    insert oi;

    // Activer la commande après ajout des lignes
    ord = [SELECT Id, Status FROM Order WHERE Id = :ord.Id];
    ord.Status = 'Activated';
    update ord;

    // Exécution via la façade
    Test.startTest();
    AccountRevenueUpdater.updateForAccounts(new Set<Id>{ acc.Id });
    Test.stopTest();

    // Vérif : Net = 100 - 20 = 80
    acc = [SELECT Chiffre_d_affaire__c FROM Account WHERE Id = :acc.Id];
    System.assertEquals(
      80,
      acc.Chiffre_d_affaire__c,
      'La façade doit recalculer le CA du compte correctement'
    );
  }
}
