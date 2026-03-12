/**
* @Author            : jh.jung
* @Description 		 : Teams Adaptive Card Payload 생성 유틸리티.
*                      SOAR 순수 웹훅(SecurityNotifyTeamsAction)과 레거시 인터페이스(InterfaceTeamsNotifier) 양쪽에서 공통으로 사용됩니다.
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-03-11      jh.jung           Created - Tier 2 Payload Builder Pattern
*/
public with sharing class SecurityTeamsPayloadBuilder {
    
    public static String buildPayload(String rawRequest) {
        SecurityTypes.SecurityEventContext ctx = (SecurityTypes.SecurityEventContext)JSON.deserialize(rawRequest, SecurityTypes.SecurityEventContext.class);
        if (ctx == null) return null;

        Map<String, Object> adaptiveCard = new Map<String, Object>();
        adaptiveCard.put('type', 'AdaptiveCard');
        adaptiveCard.put('version', '1.4');

        List<Object> bodyElements = new List<Object>();

        // [ACTION_COMPLETE] 액션 처리 결과 알림
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
            return JSON.serialize(buildFinalPayload(adaptiveCard));
        }

        // --- 보안 경보 카드 ---
        String statusEmoji = (ctx.severity == 'CRITICAL') ? '🚨' : '🛡️';
        String color = (ctx.severity == 'CRITICAL' || ctx.severity == 'HIGH') ? 'Attention' : 'Accent';

        bodyElements.add(new Map<String, Object>{
            'type' => 'TextBlock', 'text' => statusEmoji + ' 보안 경보: ' + ctx.policyCode,
            'weight' => 'Bolder', 'size' => 'Medium', 'color' => color
        });

        List<Object> facts = new List<Object>();
        facts.add(new Map<String, Object>{'title' => '사용자:', 'value' => ctx.userName + ' (' + ctx.profile + ')'});
        facts.add(new Map<String, Object>{'title' => '동작:', 'value' => ctx.actionName});
        facts.add(new Map<String, Object>{'title' => '리소스 타입:', 'value' => ctx.resourceType});

        if (ctx.resourceType == 'ApiEvent' && String.isNotBlank(ctx.query)) {
            facts.add(new Map<String, Object>{'title' => '쿼리:', 'value' => ctx.query.left(100) + '...'});
            facts.add(new Map<String, Object>{'title' => 'Rows:', 'value' => String.valueOf(ctx.rows)});
        } else if (ctx.resourceType == 'LoginEvent') {
            facts.add(new Map<String, Object>{'title' => '접속 IP:', 'value' => ctx.sourceIp});
            facts.add(new Map<String, Object>{'title' => '상태:', 'value' => ctx.status});
        }

        bodyElements.add(new Map<String, Object>{ 'type' => 'FactSet', 'facts' => facts });
        adaptiveCard.put('body', bodyElements);

        String adminBase = URL.getOrgDomainUrl().toExternalForm();
        String siteBase = getSiteBaseUrl();
        
        List<Object> actions = new List<Object>();
        
        // 1. 공통: 사용자 상세 보기 (항상 노출)
        actions.add(new Map<String, Object>{
            'type' => 'Action.OpenUrl',
            'title' => '사용자 상세 보기',
            'url' => adminBase + '/' + ctx.userId
        });

        // 2. 동적 버튼 렌더링: actionStatus(완료 상태)가 없고, actionButtons에 텍스트가 명시되어 있을 때
        if (String.isBlank(ctx.actionStatus)) {
            String allowedButtons = ctx.actionButtons;
            
            // 지정된 버튼이 없을 경우 기본 노출 (기존 스크립트 역호환성)
            if (String.isBlank(allowedButtons)) {
                allowedButtons = 'FREEZE_USER;KILL_SESSION';
            }

            for (String actionStr : allowedButtons.split(';')) {
                String btnAction = actionStr.trim().toUpperCase();
                if (String.isNotBlank(btnAction)) {
                    String url = buildInboundUrl(siteBase, ctx, btnAction);
                    actions.add(new Map<String, Object>{
                        'type' => 'Action.OpenUrl',
                        'title' => getButtonTitle(btnAction),
                        'url' => url
                    });
                }
            }
        }

        adaptiveCard.put('actions', actions);

        return JSON.serialize(buildFinalPayload(adaptiveCard));
    }

    private static String getButtonTitle(String actionType) {
        switch on actionType {
            when 'FREEZE_USER' { return '🔒 계정 강제 동결'; }
            when 'KILL_SESSION' { return '🔌 접속 세션 종료'; }
            when 'REVOKE_TOKEN' { return '🔑 OAUTH 토큰 회수'; }
            when 'REQUIRE_MFA' { return '📱 MFA 재인증 요구'; }
            when 'CREATE_CASE' { return '📝 보안 케이스 생성'; }
            when 'RESTRICT_PERMISSION' { return '🛡️ 권한 임시 회수'; }
            when else { return '⚙️ 실행: ' + actionType; }
        }
    }

    private static String buildInboundUrl(String orgBase, SecurityTypes.SecurityEventContext ctx, String actionType) {
        String eventKey = String.isNotBlank(ctx.eventKey) ? ctx.eventKey : '';
        String userId = String.isNotBlank(ctx.userId) ? ctx.userId : '';
        String policyCode = String.isNotBlank(ctx.policyCode) ? ctx.policyCode : '';
        Long t = System.currentTimeMillis() / 1000;
        
        String token = SecurityInboundToken.generateEncryptedToken(actionType, eventKey, userId, policyCode, t);
        
        String path = orgBase + '/services/apexrest/api/security/action';
        path += '?token=' + EncodingUtil.urlEncode(token, 'UTF-8');
        return path;
    }

    private static Map<String, Object> buildFinalPayload(Map<String, Object> adaptiveCard) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('type', 'message');
        payload.put('attachments', new List<Object>{
            new Map<String, Object>{
                'contentType' => 'application/vnd.microsoft.card.adaptive',
                'content' => adaptiveCard
            }
        });
        return payload;
    }

    private static String getSiteBaseUrl() {
        try {
            return 'https://solomontech-1f-dev-ed.develop.my.salesforce-sites.com';
        } catch (Exception e) {
            return URL.getOrgDomainUrl().toExternalForm();
        }
    }
}