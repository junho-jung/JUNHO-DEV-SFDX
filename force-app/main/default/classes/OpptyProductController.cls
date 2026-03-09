/*************************************************************
 * @author : jh.jung
 * @date : 2024-05-24
 * @description : 
 * @target : 
==============================================================
 * Ver          Date            Author          Modification
 * 1.0          2024-05-24      jh.jung         Initial Version
**************************************************************/
public with sharing class OpptyProductController {
    public void postOpptyProductJsonData(String jsonData) {

        List<Map<String, String>> inputDataList = (List<Map<String, String>>) JSON.deserialize(jsonData, List<Map<String, String>>.class);

        Set<String> setId = new Set<String>();
        for(Map<String, String> inputData : inputDataList) {
            setId.add(inputData.get('OpptyId'));
        }
        List<AggregateResult> listOLI = (List<AggregateResult>) [
                select OpportunityId, ProductCode , COUNT(Id) num
                from OpportunityLineItem
                where OpportunityId in :setId
                group by OpportunityId, ProductCode
        ];

        boolean dupliCheck = true;
        for(AggregateResult oliData : listOLI) {
            System.debug(oliData);
            for(Map<String, String> input : inputDataList) {
                if(oliData.get('OpportunityId') == input.get('OpptyId') && oliData.get('ProductCode') != input.get('ProductCode')) {
                    dupliCheck = false;
                }
            }
        }

        System.debug(dupliCheck);



//            String opptyId = inputData.get('OpptyId');
//            String productCode = inputData.get('ProductCode');
//
//            // Todo 1 : 겹치는지 확인, 있다면 continue?
//            List<OpportunityLineItem> OLIList = [
//                    select Id
//                    from OpportunityLineItem
//                    where OpportunityId = :opptyId
//                        and ProductCode != :productCode
//            ];
//
//            if(OLIList.isEmpty()) {
//                // Todo 2 : ProductCode가 진짜 있는 건지?
//                List<Product2> ProductList = [
//                        SELECT Id
//                        FROM Product2
//                        WHERE ProductCode =:productCode
//                ];
//                if(ProductList.isEmpty()) {
//                    // ProductCode 동일한거 존재X
//                    System.debug('없는 제품코드');
//                    continue;
//                } else {
//                    System.debug('INSERT');
////                    insert new OpportunityLineItem(OpportunityId = opptyId, Product2Id = ProductList[0].Id);
//                }
//            } else {
//                // 막기
//                System.debug('다른 제품 이미 등록');
//                continue;
//            }
    }
}