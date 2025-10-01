// Planifie l’exécution du batch global de recalcul du CA
global with sharing class AccountRevenueScheduler implements Schedulable {
  global void execute(SchedulableContext sc) {
    // Taille de batch à 200
    Database.executeBatch(new AccountRevenueRecalcAllBatch(), 200);
  }
}
