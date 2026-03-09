/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-03      jh.jung           Created
*/
public without sharing class InterfaceBizInfo extends InterfaceRealTime {

    // =================================================================
    // 1. 응답 데이터 래퍼 클래스 (API Response Wrappers)
    // =================================================================

    /**
     * @description 외부 API의 메인 응답 래퍼 클래스입니다.
     */
    public class BizInfoResponse {
        @AuraEnabled public Integer request_cnt;
        @AuraEnabled public Integer match_cnt;
        @AuraEnabled public String status_code;
        @AuraEnabled public List<DataCls> data;
    }

    /**
     * @description 사업자 상태 상세 정보 래퍼 클래스입니다. (응답의 data 요소)
     */
    private class DataCls {
        @AuraEnabled public String b_no;
        @AuraEnabled public String b_stt;
        @AuraEnabled public String b_stt_cd;
        @AuraEnabled public String tax_type;
        @AuraEnabled public String tax_type_cd;
        @AuraEnabled public String end_dt;
        @AuraEnabled public String utcc_yn;
        @AuraEnabled public String tax_type_change_dt;
        @AuraEnabled public String invoice_apply_dt;
        @AuraEnabled public String rbf_tax_type;
        @AuraEnabled public String rbf_tax_type_cd;
    }

    // =================================================================
    // 2. 요청 데이터 래퍼 클래스 (API Request Wrapper)
    // =================================================================
    /**
     * @description 외부 API로 전송할 요청 데이터 구조입니다. (b_no 리스트 형태)
     */
    public class BizInfoRequest {
        public List<String> b_no; // API 명세에 따른 요청 필드명

        public BizInfoRequest(String b_no){
            this.b_no = new List<String>{b_no}; // 단일 사업자번호를 리스트에 담아 생성
        }
    }

    // =================================================================
    // 3. 생성자 및 설정
    // =================================================================

    public InterfaceBizInfo() {
        // 응답 객체 타입을 설정하여, InterfaceHandler가 JSON을 BizInfoResponse 클래스로 자동 파싱하도록 지시합니다.
        super.setResponseType(BizInfoResponse.class);
    }

    // =================================================================
    // 4. Template Method 구현
    // =================================================================

    /**
     * @description [Abstract Method 구현] 통신 전, 요청 데이터를 가공하고 유효성을 검사합니다.
     * (InterfaceRealTime.execute(requestData) 호출 시, requestData가 this.request에 이미 할당되어 있음)
     * @return 전송할 데이터 객체 (BizInfoRequest)
     */
    public override Object before() {

        // 1. Object 타입인 this.request를 BizInfoRequest로 형 변환합니다.
        BizInfoRequest req = (BizInfoRequest)this.request;

        // 2. [로그 키 설정] RequestObj Property가 제거되었으므로, 여기서 로그 키를 설정합니다.
        if (req != null && !req.b_no.isEmpty()) {
            INF.keyList.clear();
            INF.keyList.add(req.b_no[0]);
        }

        // 3. 유효성 검사: 필수 데이터 누락 여부를 확인합니다.
        if (req == null || req.b_no == null || req.b_no.isEmpty() || String.isBlank(req.b_no[0])) {
            INF.error(new CalloutException('요청할 사업자번호 데이터가 유효하지 않습니다.'));
            return null;
        }

        System.debug(LoggingLevel.INFO, '전송 준비된 사업자번호: ' + req.b_no[0]);

        // 요청 객체(req)를 반환하면 INF.send()가 이를 JSON으로 직렬화하여 전송합니다.
        return req;
    }

    /**
     * @description [Abstract Method 구현] 통신 성공 후, 응답 데이터를 처리합니다. (DML 등)
     * @param rc InterfaceHandler의 결과 객체 (rc.responseObject에 파싱된 BizInfoResponse 객체가 들어있어야 함)
     */
    public override void after(InterfaceHandler.ReturnCls rc) {
        System.debug(LoggingLevel.INFO, 'InterfaceBizInfo.after() - 응답 데이터 처리 시작');

        // rc.responseBody 대신 rc.responseObject를 사용해야 하지만,
        // 현재는 JSON 파싱 로직을 유지하여 robustness를 높입니다.
        String jsonString = rc.responseBody;
        BizInfoResponse response = null;
        String requestedb_no = INF.keyList.isEmpty() ? 'N/A' : INF.keyList[0];

        // 1. JSON 파싱 (수동 파싱으로 파싱 에러에 대응)
        try {
            if (String.isNotBlank(jsonString)) {
                response = (BizInfoResponse)JSON.deserialize(jsonString, BizInfoResponse.class);
            }
        } catch (Exception e) {
            INF.failList.add(requestedb_no + ': 응답 JSON 파싱 실패');
            System.debug(LoggingLevel.ERROR, 'JSON 파싱 에러: ' + e.getMessage());
            return;
        }

        // 2. API 응답 상태 검증
        if (response == null || !'OK'.equalsIgnoreCase(response.status_code)) {
            String failMessage = 'API 응답 실패/데이터 없음: Status=' + (response != null ? response.status_code : 'NULL');
            INF.failList.add(requestedb_no + ' (' + failMessage + ')');
            System.debug(LoggingLevel.WARN, '❌ ' + failMessage);
            return;
        }

        // 3. 데이터 처리 (성공 케이스)
        if (response.match_cnt > 0 && response.data != null && !response.data.isEmpty()) {

            DataCls data = response.data[0];
            String status = data.b_stt;

            System.debug(LoggingLevel.INFO, '✅ 조회 성공 (' + data.b_no + '): 상태=' + status);
            INF.successList.add(data.b_no + ' (' + status + ')');

            // [DML 예시] Account acc = ...; update acc;

        } else {
            // match_cnt = 0 이거나 data가 비어있을 경우 (등록 정보 없음)
            INF.failList.add(requestedb_no + ' (등록 정보 없음)');
        }
    }

    /**
     * @description [Virtual Method 구현] 모든 처리가 끝난 후 마무리 작업을 수행합니다.
     */
    public override void finish() {
        System.debug(LoggingLevel.INFO, 'InterfaceBizInfo.finish() - 마무리 작업 완료');
    }
}