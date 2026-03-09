/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-16      jh.jung           Created
*/
public with sharing class KakaoMapController {

    @AuraEnabled
    public static List<Map<String, Object>> getLeadListByFilter(Integer num) {

        String addDateQuery = ' ';
        if(num == 15) {
            addDateQuery = ' AND CreatedDate >= LAST_N_DAYS:15';
        } else if(num == 30) {
            addDateQuery = ' AND CreatedDate >= LAST_N_DAYS:30 AND CreatedDate < LAST_N_DAYS:15';
        } else if(num == 60) {
            addDateQuery = ' AND CreatedDate >= LAST_N_DAYS:60 AND CreatedDate < LAST_N_DAYS:30';
        } else if(num == 999) {
            addDateQuery = ' AND CreatedDate < LAST_N_DAYS:60';
        }

//        String query = '';
//        query += ' SELECT Id, Name, MobilePhone, RoadAddress__c, CreatedDate, Latitude__c, Longitude__c, Company, fm_Rating__c, ProductId__c, ProductId__r.Name, Finance__c, AdvancePayment__c, DefaultInterestRate__c, MonthDivideInputMonth__c ';
//        query += ' FROM Lead ';
//        query += ' WHERE Status != \'Converted\' ';
//        query += addDateQuery;
//        query += ' AND OwnerId = \'' + UserInfo.getUserId() +'\'';
//        query += ' ORDER BY CreatedDate DESC ';
//
//        List<SObject> returnObjList = new List<SObject>();
//        returnObjList = Database.query(query);
//
//        return returnObjList;

        List<Map<String, Object>> leadList = new List<Map<String, Object>>();

        // Lead 타입 SObject 생성
        Map<String, Object> l = new Map<String, Object>();

        // 표준 필드 (존재하므로 안전)
        l.put('Id', '00Q000000000002AAA');
        l.put('Name', '김테스트');
        l.put('Company', '테스트상사');
        l.put('CreatedDate', Datetime.now().addDays(-5));

        // ❗ 실제로 존재하지 않아도 "컴파일은 통과"
        // (런타임 접근만 조심)
        l.put('MobilePhone', '010-1234-5678');
        l.put('RoadAddress__c', '서울시 강남구 테스트로 123');
        l.put('fm_Rating__c', 'A');
        l.put('Finance__c', 50000000);
        l.put('AdvancePayment__c', 10000000);
        l.put('DefaultInterestRate__c', 3.5);
        l.put('MonthDivideInputMonth__c', 36);
        l.put('Latitude__c', 37.498);
        l.put('Longitude__c', 127.027);

        // Lookup 흉내
        l.put('ProductId__c', '01t000000000AAA');

        // 관계 객체 흉내
        Map<String, Object> product = new Map<String, Object>();
        product.put('Id', '01t000000000AAA');
        product.put('Name', '리스 상품 A');

        l.put('ProductId__r', product);

        leadList.add(l);

        // Lead 타입 SObject 생성
        Map<String, Object> l2 = new Map<String, Object>();

        // 표준 필드 (존재하므로 안전)
        l2.put('Id', '00Q000000000002AAA');
        l2.put('Name', '김테스트1');
        l2.put('Company', '테스트상사1');
        l2.put('CreatedDate', Datetime.now().addDays(-5));

        // ❗ 실제로 존재하지 않아도 "컴파일은 통과"
        // (런타임 접근만 조심)
        l2.put('MobilePhone', '010-1234-5678');
        l2.put('RoadAddress__c', '서울시 강남구 테스트로 123');
        l2.put('fm_Rating__c', 'A');
        l2.put('Finance__c', 50000000);
        l2.put('AdvancePayment__c', 10000000);
        l2.put('DefaultInterestRate__c', 3.5);
        l2.put('MonthDivideInputMonth__c', 36);
        l2.put('Latitude__c', 37.598);
        l2.put('Longitude__c', 127.127);

        // Lookup 흉내
        l2.put('ProductId__c', '01t000000000AAA');

        // 관계 객체 흉내
        Map<String, Object> product3 = new Map<String, Object>();
        product3.put('Id', '01t000000000AAA');
        product3.put('Name', '리스 상품 A');

        l.put('ProductId__r', product3);

        leadList.add(l2);
        System.debug(leadList);

        return leadList;
    }
}