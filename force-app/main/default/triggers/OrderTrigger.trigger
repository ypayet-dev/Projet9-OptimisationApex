trigger OrderTrigger on Order(before insert, before update, after update) {
//Délégue la logique métier au handler    
  OrderTriggerHandler h = new OrderTriggerHandler();
// Traitement avant insert ou update 
  if (Trigger.isBefore) {
    if (Trigger.isInsert || Trigger.isUpdate) {
      h.beforeUpsert(Trigger.new);
    }
  }
// Traitement apres update
  if (Trigger.isAfter && Trigger.isUpdate) {
    h.afterUpdate(Trigger.new, Trigger.oldMap);
  }

// Traitment apres delete  
  if (Trigger.isAfter && Trigger.isDelete) {
    h.afterDelete(Trigger.old);
  }
}
