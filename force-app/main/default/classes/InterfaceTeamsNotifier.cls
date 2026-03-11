/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-19      jh.jung           Created
*/

/**
 * [보안 액션 → 팀즈 알림 → 인바운드 → 실제 얼리기] 흐름 중 [1단계: 팀즈로 물어보기]
 *
 * @description 보안 액션(인터셉터) 발생 시 SecurityInterfaceBridge를 통해 호출됨.
 *              Teams 워크플로로 보안 알림 카드를 전송하며, "계정 얼릴건지" 확인용 버튼을 제공.
 *              - 사용자 상세 보기: SF 로그인 필요
 *              - 세션 즉시 종료: 로그인 없이 클릭만으로 인바운드 REST 호출 → 실제 계정 동결(UserLogin.IsFrozen)
 * @context SecurityTypes.SecurityEventContext 기반으로 동적 알림 생성
 */
public without sharing class InterfaceTeamsNotifier extends InterfaceRealTime {

    public InterfaceTeamsNotifier() {
        // 응답 본문 파싱을 위해 기본 Map 설정
        super.setResponseType(Map<String, Object>.class);
    }

    /**
     * [1단계] SecurityEventContext를 Teams Adaptive Card로 변환.
     * 공통 Payload Builder(SecurityTeamsPayloadBuilder)를 사용하여 생성합니다.
     */
    public override Object before() {
        String rawRequest = (String)this.request;
        String jsonPayload = SecurityTeamsPayloadBuilder.buildPayload(rawRequest);
        
        if (String.isBlank(jsonPayload)) return null;

        SecuritySoarTrace.log('InterfaceTeamsNotifier.before', new Map<String, Object>{
            'status' => 'Payload Generated'
        });
        
        addHeader('Content-Type', 'application/json; charset=utf-8');
        
        // InterfaceRealTime은 리턴된 Object를 JSON으로 직렬화하므로 Map 형태로 파싱해서 넘겨줌
        return JSON.deserializeUntyped(jsonPayload);
    }

    public override void after(InterfaceHandler.ReturnCls rc) {
        // Teams 202 응답 처리
        if (rc.statusCode == 202 || rc.statusCode == 200) {
            INF.successList.add('Teams Alert Dispatched: ' + rc.statusCode);
        } else {
            INF.failList.add('Teams Alert Failed: ' + rc.statusCode);
        }
    }

    public override void finish() {
        SecuritySoarTrace.log('InterfaceTeamsNotifier.finish');
    }


}