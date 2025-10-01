public with sharing class OrderTriggerHandler {
  // Avant insert/update : calcul du NetAmount__c
  public void beforeUpsert(List<Order> newList) {
    for (Order o : newList) {
      if (o.TotalAmount != null && o.ShipmentCost__c != null) {
        o.NetAmount__c = o.TotalAmount - o.ShipmentCost__c;
      } else {
        o.NetAmount__c = null;
      }
    }
  }

  // Après update : gérer transitions de statut et changements de compte
  public void afterUpdate(List<Order> newList, Map<Id, Order> oldMap) {
    Set<Id> accIds = new Set<Id>();

    for (Order o : newList) {
      Order oldO = oldMap.get(o.Id);

      // entrée dans Activated
      if (
        o.AccountId != null &&
        o.Status == 'Activated' &&
        (oldO == null ||
        oldO.Status != 'Activated')
      ) {
        accIds.add(o.AccountId);
      }

      // sortie d’Activated ou changement de compte
      if (
        oldO != null &&
        oldO.Status == 'Activated' &&
        (o.Status != 'Activated' ||
        o.AccountId != oldO.AccountId)
      ) {
        if (oldO.AccountId != null)
          accIds.add(oldO.AccountId);
        if (o.Status == 'Activated' && o.AccountId != null)
          accIds.add(o.AccountId);
      }
    }

    if (!accIds.isEmpty()) {
      ChiffreAffaireService.updateChiffreAffaireForAccounts(accIds);
    }
  }

  // Après suppression : si une commande Activated disparaît
  public void afterDelete(List<Order> oldList) {
    Set<Id> accIds = new Set<Id>();
    for (Order o : oldList) {
      if (o.Status == 'Activated' && o.AccountId != null) {
        accIds.add(o.AccountId);
      }
    }
    if (!accIds.isEmpty()) {
      ChiffreAffaireService.updateChiffreAffaireForAccounts(accIds);
    }
  }
}
