public with sharing class ChiffreAffaireService {
  // Recalcule le CA (Chiffre_d_affaire__c) pour un ensemble de comptes.
  public static void updateChiffreAffaireForAccounts(Set<Id> accountIds) {
    if (accountIds == null || accountIds.isEmpty())
      return;

    // 1) Somme des NetAmount__c des Orders ACTIVATED par compte
    Map<Id, Decimal> mapCA = new Map<Id, Decimal>();
    for (AggregateResult ar : [
      SELECT AccountId a, SUM(NetAmount__c) t
      FROM Order
      WHERE Status = 'Activated' AND AccountId IN :accountIds
      GROUP BY AccountId
    ]) {
      mapCA.put((Id) ar.get('a'), (Decimal) ar.get('t'));
    }

    // 2) Comptes sans ligne (donc plus aucune Activated) → forcer 0
    for (Id accId : accountIds) {
      if (!mapCA.containsKey(accId)) {
        mapCA.put(accId, 0);
      }
    }

    // 3) DML unique
    List<Account> accountToUpdate = new List<Account>();
    for (Id accId : mapCA.keySet()) {
      accountToUpdate.add(
        new Account(Id = accId, Chiffre_d_affaire__c = mapCA.get(accId))
      );
    }
    if (!accountToUpdate.isEmpty()) {
      update accountToUpdate;
    }
  }
}
