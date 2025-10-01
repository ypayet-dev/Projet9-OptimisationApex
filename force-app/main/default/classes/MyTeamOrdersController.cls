public with sharing class MyTeamOrdersController {
  public Id selectedOwnerId { get; set; }
  public Decimal teamTotal { get; private set; } // (anciennement SumOders)

  public List<Order> getTeamOrders() {
    Set<Id> teamUserIds = new Set<Id>();
    // Exemple simple: l’équipe = les users dont ManagerId = UserInfo.getUserId(), + moi
    for (User u : [
      SELECT Id
      FROM User
      WHERE ManagerId = :UserInfo.getUserId() OR Id = :UserInfo.getUserId()
    ]) {
      teamUserIds.add(u.Id);
    }
    String cond = (selectedOwnerId != null)
      ? ' AND OwnerId = :selectedOwnerId'
      : '';
    List<Order> orders = Database.query(
      'SELECT Id, Name, Status, TotalAmount, OwnerId ' +
        'FROM Order WHERE OwnerId IN :teamUserIds' +
        cond +
        ' ORDER BY CreatedDate DESC'
    );

    // total d’équipe (sur les mêmes users, éventuellement filtré Status)
    AggregateResult[] ar = [
      SELECT SUM(TotalAmount) s
      FROM Order
      WHERE OwnerId IN :teamUserIds
    ];
    teamTotal = (ar.isEmpty() || ar[0].get('s') == null)
      ? 0
      : (Decimal) ar[0].get('s');

    return orders;
  }
}
