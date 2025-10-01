public class MassOrderGenerator {
  public static void createTestOrders() {
    // 1. Créer un compte
    Account acc = new Account(Name = 'Compte Test Généré');
    insert acc;

    // 2. Récupérer un produit standard actif
    Product2 prod = [
      SELECT Id, Name, IsActive
      FROM Product2
      WHERE IsActive = TRUE
      LIMIT 1
    ];

    // 3. Récupérer un prix standard actif
    Pricebook2 standardPB = [
      SELECT Id
      FROM Pricebook2
      WHERE IsStandard = TRUE
      LIMIT 1
    ];
    PricebookEntry pbe = [
      SELECT Id, UnitPrice
      FROM PricebookEntry
      WHERE Pricebook2Id = :standardPB.Id AND Product2Id = :prod.Id
      LIMIT 1
    ];

    // 4. Créer les commandes
    List<Order> orders = new List<Order>();
    for (Integer i = 0; i < 100; i++) {
      orders.add(
        new Order(
          Name = 'Commande ' + i,
          AccountId = acc.Id,
          Status = 'Draft',
          EffectiveDate = Date.today(),
          Pricebook2Id = standardPB.Id
        )
      );
    }
    insert orders;

    // 5. Créer 1 ligne par commande pour générer le TotalAmount
    List<OrderItem> items = new List<OrderItem>();
    for (Order ord : orders) {
      items.add(
        new OrderItem(
          OrderId = ord.Id,
          Quantity = 1,
          UnitPrice = 100,
          PricebookEntryId = pbe.Id
        )
      );
    }
    insert items;
  }
}
