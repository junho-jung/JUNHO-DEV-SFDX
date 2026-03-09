/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-04      jh.jung           Created
*/
public without sharing class InterfaceQueueableBizInfo extends InterfaceQueueable {

    // =================================================================
    // 1. 요청/응답 데이터 래퍼 클래스 정의
    // =================================================================
    // 🚨 BizInfoRequest는 InterfaceBizInfo.BizInfoRequest와 동일하다고 가정합니다.
    // 여기서는 InterfaceBizInfo의 내부 클래스를 public static으로 정의했다고 가정합니다.

    // (InterfaceBizInfo.BizInfoRequest, InterfaceBizInfo.BizInfoResponse 클래스가
    //  다른 파일에 public static으로 정의되어 있거나, 이 클래스에 재정의되어 있다고 가정)
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


    // =================================================================
    // 2. 생성자 및 설정
    // =================================================================

    public InterfaceQueueableBizInfo() {
        // 응답 객체 타입을 설정합니다.
        super.setResponseType(BizInfoResponse.class);
    }

    // =================================================================
    // 3. Template Method 구현
    // =================================================================

    /**
     * @description [Abstract Method 구현] 통신 전, 요청 데이터를 가공하고 유효성을 검사합니다.
     * @return 전송할 데이터 객체 (BizInfoRequest)
     */
    public override Object before() {

        // 1. Object 타입인 this.request를 BizInfoRequest로 형 변환합니다.
        BizInfoRequest req = (BizInfoRequest)this.request;

        // 2. [로그 키 설정] 여기서 로그 키를 설정합니다.
        if (req != null && !req.b_no.isEmpty()) {
            INF.keyList.clear();
            INF.keyList.add(req.b_no[0]);
        }

        // 3. 유효성 검사
        if (req == null || req.b_no.isEmpty() || String.isBlank(req.b_no[0])) {
            INF.error(new CalloutException('요청할 사업자번호가 누락되었습니다.'));
            return null;
        }

        System.debug(LoggingLevel.INFO, '비동기 전송 준비된 사업자번호: ' + req.b_no[0]);
        return req;
    }

    /**
     * @description [Abstract Method 구현] 통신 성공 후, 응답 데이터를 처리합니다.
     * @param rc InterfaceHandler의 결과 객체
     */
    public override void after(InterfaceHandler.ReturnCls rc) {
        System.debug(LoggingLevel.INFO, 'InterfaceQueueableBizInfo.after() - 응답 데이터 처리 시작');

        // rc.responseObject를 사용하는 것이 더 안전하지만, robustness를 위해 JSON String을 사용
        BizInfoResponse response = (BizInfoResponse)JSON.deserialize(rc.responseBody, BizInfoResponse.class);

        if (response != null && 'OK'.equalsIgnoreCase(response.status_code) && !response.data.isEmpty()) {

            DataCls data = response.data[0];
            System.debug(LoggingLevel.INFO, '✅ 비동기 조회 성공: 상태=' + data.b_stt);
            INF.successList.add(data.b_no + ' (' + data.b_stt + ')');

            // [DML 예시: 비동기 작업] Account acc = ...; update acc;

        } else {
            INF.failList.add(INF.keyList[0] + ' (API 응답 실패)');
        }
    }

    /**
     * @description Finalizer에서 호출될 종료 훅 (Queueable Job 완료 후 최종 처리)
     */
    public override void finish(InterfaceHandler.ReturnCls rc) {
        // [후처리 로직] 예: 사용자에게 알림 전송, 최종 Audit 로그 기록
        System.debug(LoggingLevel.INFO, '비동기 잡 완료 및 Finalizer finish 실행됨.');
        System.debug(LoggingLevel.INFO, 'Job Status: ' + (rc.log != null ? rc.log.Status__c : 'N/A'));
    }
}