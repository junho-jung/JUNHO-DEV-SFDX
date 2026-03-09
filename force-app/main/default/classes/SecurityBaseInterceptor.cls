/**
* @Author            : jh.jung
* @Description 		 : 모든 TxnSecurity.EventCondition 의 부모가 되는 추상 클래스.
* 공통 유저 획득, Alert 판단, 그리고 횟수 기반 동적 Smart Block 여부를 제공함 (Template Method Pattern).
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-03-06      jh.jung           Created for Smart Block Architecture
*/
global abstract inherited sharing class SecurityBaseInterceptor implements TxnSecurity.EventCondition {
    
    /**
     * @description 자식 클래스들이 반드시 구현해야 하는 순수 비즈니스 로직.
     * 이벤트를 평가하여 위반사항이 있으면 맵을 반환 (key: policyCode, severity 등). 
     * 위반하지 않았으면 null 반환.
     * @param event Transaction Event
     * @param user 현재 유저(캐싱 처리됨)
     */
    global abstract InterceptorResult doEvaluate(SObject event, User user);

    /** 자식 클래스가 반환하는 결과 래퍼 */
    global class InterceptorResult {
        public String policyCode;
        public String severity; // 'CRITICAL', 'HIGH', etc.
        public String overrideActions; // 만약 명시할 게 있다면
        
        global InterceptorResult(String policyCode, String severity) {
            this.policyCode = policyCode;
            this.severity = severity;
            this.overrideActions = '';
        }
    }

    /**
     * @description TSP가 호출하는 진입점 (Template Method).
     * 로직 실행 -> 위반 시 이벤트 발행 -> 카운트 기반 리턴값 판단
     */
    global Boolean evaluate(SObject event) {
        if (event == null) return false;

        String className = String.valueOf(this).substringBefore(':');
        
        SecuritySoarTrace.log(className + '.evaluate_Start', new Map<String, Object>{
            'eventType' => event.getSObjectType().getDescribe().getName()
        });

        Id userId = (Id)event.get('UserId');
        User user = SecurityGuard.getCurrentUser(userId);

        try {
            // 1. 자식 클래스의 순수 위반 판별 로직 실행
            InterceptorResult result = doEvaluate(event, user);
            
            // 위반 아님 (정상 허용)
            if (result == null || String.isBlank(result.policyCode)) {
                return false;
            }

            // 2. 위반 판별됨 -> 보안 이벤트(Platform Event) 무조건 발행
            SecurityAlertPublisher.publish(
                className, 
                result.policyCode, 
                result.severity, 
                result.overrideActions, 
                event, 
                user
            );

            // 3. Smart Block 로직: 현재 누적 위반 횟수 조회 (Unique Key Index 쿼리)
            Decimal currentCount = SecurityGuard.getCurrentAlertCount(userId, result.policyCode);
            SecurityPolicy__mdt policy = SecurityGuard.getPolicy(result.policyCode);

            SecuritySoarTrace.log(className + '.evaluate_SmartBlock_Check', new Map<String, Object>{
                'policyCode' => result.policyCode,
                'currentCount' => currentCount,
                'isPolicyNull' => (policy == null)
            });

            // 4. 차단 여부 결정 (ThresholdCritical__c 도달 시 true 리턴하여 Native Block 발생)
            if (policy != null && policy.ThresholdCritical__c != null) {
                // 방금 1회 위반했으므로 (현카운트 + 1)을 기준으로 삼아야 안전하게 차단됨.
                if ((currentCount + 1) >= policy.ThresholdCritical__c) {
                    SecuritySoarTrace.log(className + '.evaluate_SmartBlock_Activated', new Map<String, Object>{
                        'reason' => 'Threshold Met',
                        'threshold' => policy.ThresholdCritical__c
                    });
                    return true;
                }
            } else {
                // 정책에 임계치가 없으면 옛날처럼 CRITICAL or HIGH 일 때 무조건 즉각 차단할지 판단하기 위함
                // 하지만 안전하게 가기 위해, Threshold 정의가 없을때는 기본 false를 허용하고 Handler에 맡길 수도 있음.
                // 여기선 기존 레거시 방어를 위해 Critical이면 무조건 막는 룰을 한시적으로 제공
                if (result.severity == 'CRITICAL') {
                    return true;
                }
            }

            // 아직 임계점을 넘지 않았으므로 화면은 정상으로 냅둔다 (Monitor to Block 패턴)
            return false;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, className + ' ::: evaluate error: ' + e.getMessage());
            SecuritySoarTrace.log(className + '.evaluate_Error', new Map<String, Object>{
                'error' => e.getMessage(), 'trace' => e.getStackTraceString()
            });
            return false; 
        }
    }
}