/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-03      jh.jung           Created
*/
global class SecurityTypes {

    // 실행 방식
    global enum ActionExecutionMode {
        SYNC,
        ASYNC
    }

    // [추가] 액션 발생 출처 고정 상수 (Hardcoding 방지)
    global static final String SOURCE_TEAMS_INBOUND = 'TEAMS_INBOUND';
    global static final String SOURCE_LWC_DASHBOARD = 'LWC_DASHBOARD';
    global static final String SOURCE_MANUAL_OVERRIDE = 'MANUAL_OVERRIDE';
    global static final String SOURCE_SYSTEM_ACTION = 'SYSTEM_ACTION';
    global static final String SOURCE_INBOUND_COMMAND = 'INBOUND_COMMAND';

    // [추가] 인바운드 결과 래퍼 (InboundRestHandler 의존성 제거용 global 타입)
    global class InboundResult {
        global Integer statusCode;
        global String body;
        global InboundResult(Integer code, String b) {
            this.statusCode = code;
            this.body = b;
        }
    }

    // Action + 실행 정책 묶음
    global class ActionDescriptor {
        global ISecurityAction action;
        global ActionExecutionMode mode;

        global ActionDescriptor(
            ISecurityAction action,
            ActionExecutionMode mode
        ) {
            this.action = action;
            this.mode = mode;
        }
    }

    /**
     * @description 퍼블리셔(SecurityAlertPublisher)에서 생성된 모든 페이로드를 수용하는 슈퍼 클래스
     */
    public class SecurityEventContext {
        // [Base Payload Fields]
        public String userId;       // 대상 사용자 ID
        public String userName;     // 대상 사용자 이름
        public String userEmail;    // 사용자 이메일
        public String profile;      // 사용자 프로필명
        public String policyCode;   // 정책 코드 (예: SENSITIVE_LISTVIEW_MFA)
        public String severity;     // 위험도 (HIGH, CRITICAL 등)
        public String source;       // 출처 인터셉터 (예: EM_SecurityMFAInterceptor)
        public String actionName;   // 수행된 동작 (예: Opportunity, Query)
        public String timestamp;    // 발생 시각
        public String eventKey;     // 중복 방지 키

        // [Resource Info Fields] - ResourceInfo 클래스 데이터
        public String resourceId;   // 리소스 ID (ReportId, LoginHistoryId 등)
        public String resourceName; // 리소스 이름 (보고서명, 쿼리문 등)
        public String resourceType; // 리소스 타입 (ApiEvent, ReportEvent 등)

        // [Extended Event Fields] - 이벤트 타입별 동적 필드
        public String format;       // ReportEvent: 엑셀, CSV 등
        public String query;        // ApiEvent: SOQL 쿼리문
        public Integer rows;        // ApiEvent: 처리된 로우 수
        public String sourceIp;     // LoginEvent: 접속 IP
        public String status;       // LoginEvent: 성공/실패 여부

        // [Action Processing Fields]
        public String actionStatus;     // 액션 처리 상태 (SUCCESS, ALREADY_FROZEN 등)
        public String actionMessage;    // 액션 처리 결과 메시지
        public String actionButtons;    // [추가] 동적 노출 허용된 버튼 (예: FREEZE_USER;KILL_SESSION)

        // [UI 가공용 필드]
        public String alertTitle;   // 팀즈 카드 제목용
        public String description;  // 팀즈 카드 설명용

        // [팀즈 동적 업데이트] Bot Framework 응답의 messageId/threadId. 동일 카드 업데이트 시 사용.
        public String messageId;    // Teams 메시지 ID (업데이트 요청 시 필요)
        public String threadId;     // Teams 스레드/대화 ID

        // 기타 정해지지 않은 모든 필드 (Future-proof)
        public Map<String, Object> extraData;
    }

    // (확장 여지)
    public enum EnforcementLevel {
        NONE,
        WARN,
        BLOCK
    }
}