/**
* @Author            : jh.jung
* @Description 		 : 보안 액션의 실행 엔진.
* 동기(SYNC) 실행 시 즉시 처리하며, 비동기(ASYNC) 실행 시 Queueable Job으로 위임함.
* startAsyncContext() ~ flushAsyncContext() 사용 시 ASYNC 액션을 한 번에 수집해
* 단일 BulkAsyncActionJob으로 일괄 Enqueue하여 트랜잭션 당 50개 Queueable 한도를 회피함.
* 모든 실행 결과는 SecurityActionLog__c에 기록됨.
* @Target            :
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-03      jh.jung           Created
  1.1      2026-03-xx      (Refactor)       startAsyncContext / flushAsyncContext 및 BulkAsyncActionJob 추가 (06_권한_상향_리팩토링_요약)
*/
public class SecurityActionExecutor {

    /** 벌크 비동기 컨텍스트: null이면 미개방, 리스트가 있으면 ASYNC 액션을 수집 중 */
    private static List<AsyncWorkItem> asyncQueue = null;

    /**
     * @description 벌크 비동기 컨텍스트 개방. 루프 시작 전 호출.
     *              이후 execute(ASYNC)는 즉시 Enqueue하지 않고 asyncQueue에 적재됨.
     */
    public static void startAsyncContext() {
        asyncQueue = new List<AsyncWorkItem>();
    }

    /**
     * @description 벌크 비동기 컨텍스트 플러시. 루프 종료 직후 호출.
     *              수집된 ASYNC 액션을 단일 BulkAsyncActionJob으로 일괄 Enqueue하여 Queueable 한도(50/트랜잭션) 회피.
     */
    public static void flushAsyncContext() {
        if (asyncQueue != null && !asyncQueue.isEmpty()) {
            System.enqueueJob(new BulkAsyncActionJob(asyncQueue));
        }
        asyncQueue = null;
    }

    /**
     * @description 컨텍스트가 열려 있는지 여부 (테스트/디버그용)
     */
    @TestVisible
    private static Boolean isAsyncContextOpen() {
        return asyncQueue != null;
    }

    /**
     * @description 액션 실행 진입점
     * @param action 실행할 액션 인스턴스 (ISecurityAction 구현체)
     * @param payload JSON 형태의 데이터
     * @param mode 실행 모드 (SYNC/ASYNC)
     */
    public static void execute(
        ISecurityAction action,
        String payload,
        SecurityTypes.ActionExecutionMode mode
    ) {
        // 인스턴스로부터 클래스명 추출 (로그 기록용)
        String actionName = String.valueOf(action).substringBefore(':');
        SecuritySoarTrace.log('SecurityActionExecutor.execute', new Map<String, Object>{
            'actionName' => actionName,
            'mode' => String.valueOf(mode)
        });

        if (mode == SecurityTypes.ActionExecutionMode.SYNC) {
            // [동기 실행] 즉시 실행 및 로깅
            executeWithLogging(action, payload, true);
        } else {
            // [비동기 실행] 벌크 컨텍스트가 열려 있으면 큐에 적재, 아니면 기존처럼 단일 Job Enqueue
            if (asyncQueue != null) {
                String actionClassName = String.valueOf(action).substringBefore(':');
                asyncQueue.add(new AsyncWorkItem(actionClassName, payload));
                SecuritySoarTrace.log('SecurityActionExecutor.execute.enqueued_bulk', new Map<String, Object>{ 'actionName' => actionClassName });
            } else {
                Id jobId = System.enqueueJob(new AsyncActionJob(action, payload));
                SecuritySoarTrace.log('SecurityActionExecutor.execute.enqueued_single', new Map<String, Object>{ 'jobId' => jobId });
            }
        }
    }

    /**
     * @description 액션 실행 및 예외 처리, 로깅을 통합 수행하는 Wrapper 메서드
     */
    public static void executeWithLogging(ISecurityAction action, String payload, Boolean isSync) {
        String actionName = String.valueOf(action).substringBefore(':');
        String status = 'SUCCESS';
        String errorMsg = '';
        String stackTrace = '';

        SecuritySoarTrace.log('SecurityActionExecutor.executeWithLogging.start', new Map<String, Object>{
            'actionName' => actionName,
            'isSync' => isSync
        });

        try {
            // 실제 비즈니스 로직 실행
            action.execute(payload);
        } catch (Exception e) {
            status = 'FAIL';
            errorMsg = e.getMessage();
            stackTrace = e.getStackTraceString();
            
            SecuritySoarTrace.log('SecurityActionExecutor.executeWithLogging.error', new Map<String, Object>{
                'actionName' => actionName,
                'errorMsg' => errorMsg
            });
            // 비동기일 때는 에러를 던지지 않고 로그만 남기며, 동기일 때는 필요 시 호출자에게 전파
            if (isSync) throw e;
        } finally {
            // 성공/실패 여부와 관계없이 실행 이력 저장 (에러 시 ErrorStack__c에 스택 트레이스 별도 저장)
            saveActionLog(actionName, payload, status, errorMsg, stackTrace, isSync);
            
            SecuritySoarTrace.log('SecurityActionExecutor.executeWithLogging.end', new Map<String, Object>{
                'actionName' => actionName,
                'status' => status
            });
        }
    }

    /**
     * @description DB에 액션 실행 이력 저장.
     * 꿀팁: 관계 필드에 External ID가 포함된 SObject 인스턴스를 할당하여 SOQL 없이 부모 연결.
     */
    private static void saveActionLog(String actionName, String payload, String status, String errorMsg, String stackTrace, Boolean isSync) {
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(payload);

            // 상위 감사 로그(Audit Log)를 찾기 위한 키 생성
            String todayStr = Datetime.now().format('yyyyMMdd');
            String userId = (String)data.get('userId');
            String policyCode = (String)data.get('policyCode');
            String auditKey = userId + '_' + policyCode + '_' + todayStr;

            // 상위 감사 로그가 미존재 시 외래 키 참조 에러 방지를 위해 Upsert로 부모 레코드 보장
            SecurityAuditLog__c parentAudit = new SecurityAuditLog__c(
                AuditKey__c = auditKey,
                User__c = userId,
                PolicyCode__c = policyCode
            );
            upsert parentAudit AuditKey__c;

            SecurityActionLog__c log = new SecurityActionLog__c(
                SecurityAuditLog__c = parentAudit.Id,
                ActionName__c = actionName,
                Status__c = status,
                ErrorMessage__c = truncate(errorMsg, 131072),
                ErrorStack__c = truncate(stackTrace, 131072),
                ExecutedAt__c = System.now(),
                Is_Sync__c = isSync,
                Payload__c = payload
            );

            insert log;
        } catch (Exception e) {
            SecuritySoarTrace.log('SecurityActionExecutor.saveActionLog.error', new Map<String, Object>{
                'errorMsg' => e.getMessage()
            });
        }
    }

    private static String truncate(String s, Integer maxLen) {
        if (s == null) return null;
        return s.length() > maxLen ? s.substring(0, maxLen) : s;
    }

    /**
     * @description 비동기 실행을 위한 내부 Queueable 클래스 (단건 Enqueue 시 사용)
     */
    private class AsyncActionJob implements Queueable, Database.AllowsCallouts {
        private ISecurityAction action;
        private String payload;

        public AsyncActionJob(ISecurityAction action, String payload) {
            this.action = action;
            this.payload = payload;
        }

        public void execute(QueueableContext ctx) {
            SecurityActionExecutor.executeWithLogging(this.action, this.payload, false);
        }
    }

    /**
     * @description 벌크 비동기 수집 시 큐에 담는 항목. Queueable 직렬화를 위해 클래스명·페이로드만 보관.
     */
    public class AsyncWorkItem {
        public String actionClassName;
        public String payload;
        public AsyncWorkItem(String actionClassName, String payload) {
            this.actionClassName = actionClassName;
            this.payload = payload;
        }
    }

    /**
     * @description 수집된 ASYNC 액션을 한 번에 실행하는 묶음형 Queueable. 트랜잭션 당 50개 한도 회피용.
     */
    private class BulkAsyncActionJob implements Queueable, Database.AllowsCallouts {
        private List<AsyncWorkItem> items;

        public BulkAsyncActionJob(List<AsyncWorkItem> items) {
            this.items = items != null ? items : new List<AsyncWorkItem>();
        }

        public void execute(QueueableContext ctx) {
            for (AsyncWorkItem item : this.items) {
                try {
                    Type t = Type.forName(item.actionClassName);
                    if (t != null) {
                        Object o = t.newInstance();
                        if (o instanceof ISecurityAction) {
                            SecurityActionExecutor.executeWithLogging((ISecurityAction) o, item.payload, false);
                        }
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'BulkAsyncActionJob item failed: ' + item.actionClassName + ' - ' + e.getMessage());
                }
            }
        }
    }
}