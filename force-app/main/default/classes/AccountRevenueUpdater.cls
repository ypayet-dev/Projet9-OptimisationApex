public with sharing class AccountRevenueUpdater {
  public static void updateForAccount(Id accountId) {
    if (accountId == null)
      return;
    ChiffreAffaireService.updateChiffreAffaireForAccounts(
      new Set<Id>{ accountId }
    );
  }

  public static void updateForAccounts(Set<Id> accountIds) {
    if (accountIds == null || accountIds.isEmpty())
      return;
    ChiffreAffaireService.updateChiffreAffaireForAccounts(accountIds);
  }
}
