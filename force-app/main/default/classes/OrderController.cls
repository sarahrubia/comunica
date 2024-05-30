public with sharing class OrderController {
  @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> getProducts(){
      List<ProductWrapper> products = new List<ProductWrapper>();

      // produtos e preços
      List<PricebookEntry> pricebookEntries = [
        SELECT Id, Product2Id, Product2.Name, Product2.Family, UnitPrice
        FROM PricebookEntry
        WHERE Pricebook2.IsStandard = true
        ORDER BY Product2.Name
    ];

    for (PricebookEntry pbentries : pricebookEntries) {
      products.add(new ProductWrapper(pbentries.Product2Id, pbentries.Product2.Name, pbentries.Product2.Family, pbentries.UnitPrice));
    }

    return products;
  }

  @AuraEnabled
public static Order createOrder(Id accountId) {
    try {
        // Criar a ordem
        Order order = new Order(
            AccountId = accountId,
            Status = 'Aberto',
            EffectiveDate = Date.today(),
            Pricebook2Id = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id 
        );
        insert order;

        return order;
    } catch (Exception e) {
        System.debug('Exception: ' + e.getMessage());
        throw new AuraHandledException(e.getMessage());
    }
}
  

  @AuraEnabled
  public static void createOrderItems(Order order, List<String> selectedProducts) {

    try {
        // criar produtos do pedido
        List<OrderItem> orderItems = new List<OrderItem>();
        for (String sp : selectedProducts) {

          Map<String, Object> spMap = (Map<String, Object>) JSON.deserializeUntyped(sp);

          Id productId = (Id) spMap.get('productId');
          Decimal unitPrice = Decimal.valueOf(String.valueOf(spMap.get('unitPrice')));

            PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :productId AND Pricebook2Id = :order.Pricebook2Id LIMIT 1];

            OrderItem oi = new OrderItem(
                OrderId = order.Id,
                Product2Id = productId,
                UnitPrice = unitPrice,
                Quantity = 1,
                PricebookEntryId = pbe.Id
            );
            orderItems.add(oi);
        }
        insert orderItems;

        // Atualizar a ordem com o desconto e o número de itens
        updateOrder(order.Id, selectedProducts.size());

    } catch (Exception e) {
        System.debug('Exception: ' + e.getMessage());
        throw new AuraHandledException(e.getMessage());
    }
  }

  // Método para calcular o desconto com base no número de itens
  @AuraEnabled
  public static Decimal calculateDiscount(Integer itemCount) {
      switch on itemCount {
          when 1 { return 0; }
          when 2 { return 10; }
          when 3 { return 22; }
          when 4 { return 38; }
          when else {return 0; }
      }
  }

  // Método auxiliar para atualizar a ordem com o desconto e o número de itens
  private static void updateOrder(Id orderId, Integer itemCount) {
      Decimal discount = calculateDiscount(itemCount);

      Order orderToUpdate = new Order(Id = orderId);
      orderToUpdate.Discount__c = discount;
      orderToUpdate.OrderItems__c = itemCount;
      update orderToUpdate;
  }

  public class ProductWrapper {
    @AuraEnabled public Id productId;
    @AuraEnabled public String productName;
    @AuraEnabled public String family;
    @AuraEnabled public Decimal unitPrice;

    public ProductWrapper(Id productId, String productName, String family, Decimal unitPrice) {
      this.productId = productId;
      this.productName = productName;
      this.family = family;
      this.unitPrice = unitPrice;
    }
}


  public class SelectedProduct {
    @AuraEnabled public Id productId;
    @AuraEnabled public Decimal unitPrice;

    public SelectedProduct(Id productId, Decimal unitPrice) {
      this.productId = productId;
      this.unitPrice = unitPrice;
    }
}


}
