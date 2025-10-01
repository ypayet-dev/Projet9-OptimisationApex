global with sharing class AccountRevenueRecalcAllBatch implements Database.Batchable<SObject> {
  global Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      'SELECT Id FROM Account ' +
      'WHERE Id IN (SELECT AccountId FROM Order WHERE Status = \'Activated\')'
    );
  }
  global void execute(Database.BatchableContext bc, List<Account> scope) {
    if (scope == null || scope.isEmpty())
      return;
    Set<Id> ids = new Map<Id, Account>(scope).keySet();
    ChiffreAffaireService.updateChiffreAffaireForAccounts(ids);
  }
  global void finish(Database.BatchableContext bc) {
    System.debug('AccountRevenueRecalcAllBatch terminé.');
  }
}
