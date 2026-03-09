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
     *         "세션 즉시 종료" 버튼에 인바운드 URL(서명+만료시간 포함)을 붙여 관리자가 클릭 시 바로 동작하도록 함.
     */
    public override Object before() {
        String rawRequest = (String)this.request;
        SecurityTypes.SecurityEventContext ctx = (SecurityTypes.SecurityEventContext)JSON.deserialize(rawRequest, SecurityTypes.SecurityEventContext.class);

        if (ctx == null) return null;
        SecuritySoarTrace.log('InterfaceTeamsNotifier.before', new Map<String, Object>{
            'policyCode' => ctx.policyCode,
            'severity' => ctx.severity,
            'userId' => ctx.userId
        });
        addHeader('Content-Type', 'application/json; charset=utf-8');

        Map<String, Object> adaptiveCard = new Map<String, Object>();
        adaptiveCard.put('type', 'AdaptiveCard');
        adaptiveCard.put('version', '1.4');

        List<Object> bodyElements = new List<Object>();

        // [ACTION_COMPLETE] 액션 처리 결과 알림 (팀즈 인바운드 콜백 결과 등): 간단한 메시지 카드 (버튼 없음)
        if (String.isNotBlank(ctx.actionStatus)) {
            String titleEmoji = (ctx.actionStatus == 'SUCCESS') ? '✅ ' : '⚠️ ';
            bodyElements.add(new Map<String, Object>{
                'type' => 'TextBlock', 'text' => titleEmoji + (String.isNotBlank(ctx.alertTitle) ? ctx.alertTitle : '보안 조치 처리 결과'),
                'weight' => 'Bolder', 'size' => 'Medium', 'color' => 'Accent'
            });
            bodyElements.add(new Map<String, Object>{
                'type' => 'TextBlock', 'text' => (String.isNotBlank(ctx.actionMessage) ? ctx.actionMessage : '요청하신 작업이 처리되었습니다.'),
                'wrap' => true
            });
            adaptiveCard.put('body', bodyElements);
            return buildFinalPayload(adaptiveCard);
        }

        // --- 보안 경보 카드: 제목 및 컬러 세팅 ---
        String statusEmoji = (ctx.severity == 'CRITICAL') ? '🚨' : '🛡️';
        String color = (ctx.severity == 'CRITICAL' || ctx.severity == 'HIGH') ? 'Attention' : 'Accent';

        // 1. 헤더
        bodyElements.add(new Map<String, Object>{
            'type' => 'TextBlock', 'text' => statusEmoji + ' 보안 경보: ' + ctx.policyCode,
            'weight' => 'Bolder', 'size' => 'Medium', 'color' => color
        });

        // 2. 공통 정보 FactSet
        List<Object> facts = new List<Object>();
        facts.add(new Map<String, Object>{'title' => '사용자:', 'value' => ctx.userName + ' (' + ctx.profile + ')'});
        facts.add(new Map<String, Object>{'title' => '동작:', 'value' => ctx.actionName});
        facts.add(new Map<String, Object>{'title' => '리소스 타입:', 'value' => ctx.resourceType});

        // 3. [조건부 렌더링] 이벤트 타입별 상세 정보 추가
        if (ctx.resourceType == 'ApiEvent' && String.isNotBlank(ctx.query)) {
            facts.add(new Map<String, Object>{'title' => '쿼리:', 'value' => ctx.query.left(100) + '...'});
            facts.add(new Map<String, Object>{'title' => 'Rows:', 'value' => String.valueOf(ctx.rows)});
        } else if (ctx.resourceType == 'LoginEvent') {
            facts.add(new Map<String, Object>{'title' => '접속 IP:', 'value' => ctx.sourceIp});
            facts.add(new Map<String, Object>{'title' => '상태:', 'value' => ctx.status});
        }

        bodyElements.add(new Map<String, Object>{ 'type' => 'FactSet', 'facts' => facts });

        adaptiveCard.put('body', bodyElements);

        // 관리자용 URL (로그인 필요)
        String adminBase = URL.getOrgDomainUrl().toExternalForm();

        // 세션 종료/계정 동결용 Site URL (Public)
        String siteBase = getSiteBaseUrl();
        String freezeUserUrl = buildInboundUrl(siteBase, ctx, 'FREEZE_USER');
        String killSessionUrl = buildInboundUrl(siteBase, ctx, 'KILL_SESSION');

        List<Object> actions = new List<Object>{
            new Map<String, Object>{
                'type' => 'Action.OpenUrl',
                'title' => '사용자 상세 보기',
                'url' => adminBase + '/' + ctx.userId
            },
            new Map<String, Object>{
                'type' => 'Action.OpenUrl',
                'title' => '🔒 대상 계정 강제 동결',
                'url' => freezeUserUrl
            },
            new Map<String, Object>{
                'type' => 'Action.OpenUrl',
                'title' => '🔌 현재 접속 세션 일괄 종료',
                'url' => killSessionUrl
            }
        };
        adaptiveCard.put('actions', actions);

        return buildFinalPayload(adaptiveCard);
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

    /**
     * [1→2단계 연결] 팀즈 카드 버튼에 붙을 인바운드 처리용 단일 URL 생성.
     *               로그인 없이 GET만으로 호출 가능. 내부 데이터 노출 없이 단일 암호화 문자열 전송.
     */
    private String buildInboundUrl(String orgBase, SecurityTypes.SecurityEventContext ctx, String actionType) {
        String eventKey = String.isNotBlank(ctx.eventKey) ? ctx.eventKey : '';
        String userId = String.isNotBlank(ctx.userId) ? ctx.userId : '';
        String policyCode = String.isNotBlank(ctx.policyCode) ? ctx.policyCode : '';
        Long t = System.currentTimeMillis() / 1000;
        
        String token = SecurityInboundToken.generateEncryptedToken(actionType, eventKey, userId, policyCode, t);
        
        String path = orgBase + '/services/apexrest/api/security/action';
        path += '?token=' + EncodingUtil.urlEncode(token, 'UTF-8');
        return path;
    }

    /**
     * @description 생성된 Adaptive Card 객체를 Teams 표준 페이로드 형식으로 패키징합니다.
     */
    private Map<String, Object> buildFinalPayload(Map<String, Object> adaptiveCard) {
        Map<String, Object> payload = new Map<String, Object>();

        // Teams Workflow는 기본적으로 'message' 타입과 'attachments' 구조를 기대합니다.
        payload.put('type', 'message');
        payload.put('attachments', new List<Object>{
            new Map<String, Object>{
                'contentType' => 'application/vnd.microsoft.card.adaptive',
                'content' => adaptiveCard
            }
        });

        return payload;
    }

    /**
     * @description Salesforce Site의 Base URL을 안전하게 가져옵니다.
     */
    private String getSiteBaseUrl() {
        // 실제 운영 시에는 Custom Metadata Type에 저장된 'Site_Domain__c'를 조회하는 것이 가장 정석입니다.
        // 임시로 하드코딩하거나 CMDT 조회를 통해 'https://solomontech-dev-ed.my.site.com' 형태를 반환하세요.
        try {
            // 예: CMDT 조회 로직
            // Inbound_Security_Config__mdt config = Inbound_Security_Config__mdt.getInstance('Default');
            // return config.Site_URL__c;
            return 'https://solomontech-1f-dev-ed.develop.my.salesforce-sites.com'; // 사이트 주소로 교체 필수
        } catch (Exception e) {
            return URL.getOrgDomainUrl().toExternalForm(); // 폴백
        }
    }
}