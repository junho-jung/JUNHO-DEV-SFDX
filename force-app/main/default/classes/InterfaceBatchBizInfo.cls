/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-09      jh.jung           Created
*/
/**
 * @description InterfaceBatch 추상 클래스를 상속받아 특정 비즈니스 로직(예: 비즈니스 정보 전송)을 구현하는 배치 클래스입니다.
 * - 특정 SObject (예: Account)를 대상으로 데이터를 조회하고,
 * - Before 단계에서 전송할 데이터 구조로 변환하며,
 * - After 단계에서 응답을 처리하고 후속 작업을 수행합니다.
 */
public with sharing class InterfaceBatchBizInfo extends InterfaceBatch {

    // (선택 사항) 비즈니스 로직에 필요한 추가 상태 변수
    // Database.Stateful 덕분에 배치가 실행되는 동안 이 변수의 값이 유지됩니다.
    private Integer totalProcessedCount = 0;
    private List<String> successfulAccountIds = new List<String>();

    // =================================================================
    // 1. 생성자
    // =================================================================

    /**
     * @description Factory를 통한 설정을 위해 기본 생성자를 정의합니다.
     * InterfaceFactory.createBatch('BizInfo') 형태로 호출될 수 있습니다.
     */
    public InterfaceBatchBizInfo() {
        // Factory를 사용할 경우, configure() 메서드를 통해 설정이 주입됩니다.
        // Legacy 방식이나 테스트를 위해 기본 설정이 필요하다면 여기에 추가할 수 있습니다.
    }

    // =================================================================
    // 2. 추상 메서드 구현 (배치 라이프사이클)
    // =================================================================

    /**
     * @description [Start] 배치 대상 SObject를 정의하는 쿼리 로케이터를 반환합니다.
     * @param BC Database.BatchableContext
     * @return Database.QueryLocator
     */
    protected override Database.QueryLocator startBatch(Database.BatchableContext BC) {
        // 비즈니스 로직에 맞는 쿼리 작성 (예: 오늘 수정된 Account 레코드)
        String query = 'SELECT Id, Name, BusinessNumber__c FROM Account WHERE BusinessNumber__c != NULL ';
        if(request != null) {
            String accountId = (String)this.request;
            query += ' AND Id = \'' + String.escapeSingleQuotes(accountId) + '\'';
        }
        query += ' ORDER BY LastModifiedDate DESC LIMIT 1';
        return Database.getQueryLocator(query);
    }

    /**
     * @description [Execute - Before] 배치의 각 청크 실행 전, 전송할 요청 데이터를 준비합니다.
     * @param BC Database.BatchableContext
     * @param scope 현재 청크에 포함된 SObject 레코드 리스트
     * @return 외부 시스템으로 전송할 요청 데이터 객체 (Object 타입)
     */
    protected override Object before(Database.BatchableContext BC, List<SObject> scope) {
        // 1. 상태 변수 업데이트
        totalProcessedCount += scope.size();

        // 2. 외부 시스템이 요구하는 데이터 구조로 변환
//        List<BizInfoRequest> requests = new List<BizInfoRequest>();
        List<String> businessNumberList = new List<String>();
        for (SObject sobj : scope) {
            Account acc = (Account)sobj;

            // INF.keyList는 로그에 기록할 키 목록입니다.
            INF.keyList.add(acc.Id);
            businessNumberList.add(acc.BusinessNumber__c);
        }
        BizInfoRequest request = new BizInfoRequest(String.join(businessNumberList, ','));

        // InterfaceHandler의 send() 메서드로 전달될 최종 요청 데이터
        // InterfaceBatch에서는 이 객체를 JSON.serialize()를 통해 전송합니다.
        return request;
    }

    /**
     * @description [Execute - After] 외부 시스템으로부터의 응답을 처리하고 후속 작업을 수행합니다.
     * @param rc InterfaceHandler.ReturnCls (응답 결과 및 로그 정보 포함)
     */
    protected override void after(InterfaceHandler.ReturnCls rc) {
        // 응답 데이터는 rc.result에 Object 형태로 포함되어 있습니다.
        // 응답 타입을 지정했다면 (setResponseType 호출), 해당 타입으로 파싱됩니다.

        // 예: 응답 결과에서 성공/실패 목록을 추출하여 상태 변수에 기록
        if (rc.responseBody != null) {
            // 응답 처리 로직 (예: Response 객체로 캐스팅 후 성공한 ID 추출)
            // 성공한 ID를 successfulAccountIds 리스트에 추가합니다.
            // ...

            // INF.successList, INF.failList를 업데이트해야 updateLogData가 제대로 기록합니다.
            // 이 예시에서는 before에서 INF.keyList를 추가했으므로,
            // 응답에 따라 성공/실패 목록을 INF 객체에 직접 추가해야 합니다.
            // 예시: 성공한 ID는 성공 목록에 추가
            for(String id : successfulAccountIds) {
                if(!INF.successList.contains(id)) {
                    INF.successList.add(id);
                }
            }
        }

        System.debug(LoggingLevel.INFO, 'Processed successfully. Current Count: ' + totalProcessedCount);
    }

    /**
     * @description [Finish] 모든 청크 실행 후 최종 후속 작업을 수행합니다.
     * @param BC Database.BatchableContext
     */
    protected override void finishBatch(Database.BatchableContext BC) {
        System.debug(LoggingLevel.INFO, 'Batch completed for Job ID: ' + BC.getJobId());
        System.debug(LoggingLevel.INFO, 'Total Processed Records: ' + totalProcessedCount);

        if (HAS_FAIL) {
            System.debug(LoggingLevel.ERROR, 'The batch job encountered one or more failures.');
            // 실패 시 알림 로직 (이메일, Chatter 등)
        } else {
            System.debug(LoggingLevel.INFO, 'The batch job finished without any execution failures.');
            // 성공 시 알림 로직
        }

        // (선택 사항) 성공한 Account에 특정 필드를 업데이트하는 DML 작업 등
    }


    // =================================================================
    // 3. 내부 클래스 (Request/Response DTO)
    // =================================================================

    /**
     * @description 외부 시스템으로 전송할 요청 데이터 구조 (예시)
     */
    public class BizInfoRequest {
        public List<String> b_no;
        public BizInfoRequest(String b_no){
            this.b_no = new List<String>{b_no};
        }
    }
    public class BizInfoResponse {
        public String status_code;
        public List<DataCls> data;
    }
    private class DataCls {
        public String b_no;
        public String b_stt;
        public String tax_type;
    }
}