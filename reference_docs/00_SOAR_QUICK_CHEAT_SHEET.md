# ⚡ 00. SOAR 프레임워크 퀵 치트 시트 (Master Cheat Sheet)

본 문서는 Security SOAR(Security Orchestration, Automation, and Response) 프레임워크를 조작하기 위해 알아야 할 **모든 핵심 지식(아키텍처 흐름, 메타데이터 설정, 핵심 Apex 코드 패턴, 트러블슈팅)** 을 단 한 장으로 압축한 **마스터 가이드**입니다.

이 문서 하나만 완벽히 숙지하면 나머지 15종의 세부 아키텍처/리팩토링 문서를 열어보지 않아도 실무(개발 및 운영)를 완벽하게 수행할 수 있습니다. 

*(주의: 아래 가이드는 10번 문서에서 도출된 **To-Be (리팩토링 이후) 클래스 및 메타데이터 네이밍**을 기준으로 작성되었습니다.)*

---

## 🏗️ 1. 아키텍처 1분 요약 (How it Works)

Salesforce Event Monitoring에서 위협이 감지되면 프레임워크는 다음 메타데이터 체인을 따라 자동으로 대응합니다. (하드코딩 0%)

1. **감지 (Detection)**: `EM_` 인터셉터가 이벤트를 캡처합니다.
2. **정책 평가 (SecurityPolicy__mdt)**: 위협 발생 횟수가 `Threshold(임계치)`를 넘었는지 평가하고, 넘었다면 `ActionType`(예: `NOTIFY_SLACK`)을 결정합니다.
3. **라우팅 (SecurityActionRoute__mdt)**: 해당 `ActionType`을 비동기 큐(`Queueable` 등)로 보낼지 즉각 실행할지 라우팅(`Mode__c`)을 결정합니다.
4. **연동 설정 (HttpCalloutConfig__mdt)**: 외부 API(슬랙, 팀즈 등) 전송 시 엔드포인트와 **Named Credential** 기반 인증 정보를 가져옵니다.
5. **실행 및 로깅 (Execution)**: Action 구현체(예: `SecurityNotifySlackAction.cls`)가 실행되고 결과를 고유 상태 로그(`SecurityUserState__c`)에 기록합니다.

---

## ⚙️ 2. 메타데이터(No-Code) 설정 가이드 (For Admins)

코드 수정 없이 Setup 메뉴의 **Custom Metadata Types** 설정만으로 보안 시나리오를 완성하는 방법입니다.

### 🛡️ [케이스 1] "대량 데이터 조회 시 3회 경고 후 슬랙 알림 + 5회 시 계정 잠금" 규칙 추가
1. `SecurityPolicy__mdt` 에 신규 레코드 생성
2. **PolicyCode__c**: `MASS_DATA_EXPORT` (Apex 인터셉터에서 넘길 고유 코드)
3. **ThresholdMedium__c**: `3` ➡️ **ActionMedium__c**: `NOTIFY_SLACK`
4. **ThresholdCritical__c**: `5` ➡️ **ActionCritical__c**: `FREEZE_USER, KILL_SESSION`

### 🔗 [케이스 2] 외부 인증(Named Credential) 매핑 포인트 변경
* "슬랙 대신 다른 보안 채널로 알람을 쏘고 싶을 때"
1. Salesforce 설정에서 새 대상 시스템용 **Named Credential** 생성 (예: `NC_New_Security_Channel`)
2. `HttpCalloutConfig__mdt` 에서 알림용 레코드를 열어 **NamedCredential__c** 필드값을 `NC_New_Security_Channel`로 치환. (코드 배포 없이 즉시 외부 전송 토큰 전환 완료)

### 🚪 [케이스 3] 인바운드 웹훅 액션 매핑 (Slack에서 돌아온 응답 처리)
* 관리자가 Slack 알림에서 '계정 차단 승인' 버튼을 눌렀을 때의 맵핑 경로
1. `SecurityInboundAction__mdt` 레코드 생성
2. **InboundActionType__c**: `APPROVE_BLOCK` (Slack 버튼의 Value)
3. **ActionClassName__c**: `SecurityFreezeUserAction` (프레임워크가 동적 리플렉션으로 생성할 대상 Apex 클래스 입력)

---

## 💻 3. 핵심 Apex 코드 스니펫 (For Developers)

새로운 시스템 로직 개발 시 즉각 복사해서 붙여넣을 수 있는 대응 패턴 5가지입니다.

### 🚫 (1) 동기 차단 (Synchronous Block)
비즈니스 로직(화면 진입 등) 시작 전에 정책(Policy) 위반 여부를 즉각 판단하여 Exception을 던집니다.
```apex
// 'NIGHT_MASS_API' 정책에 위배되는 접근인지 확인하고, 위배 시 즉각 AuraHandledException 등 Throw
SecurityAccessChecker.verifyActionAndThrow('NIGHT_MASS_API');
```

### 📡 (2) 비동기 보안 알람 발행 (Asynchronous Async Alert)
프로세스를 끊지 않고, 유저의 의심 행동을 프레임워크의 이벤트 버스로 던져 뒷단에서 은밀하게 처리되게 합니다. (가장 많이 씀)
```apex
// 정책코드, 타겟 유저, 사유 문자열을 Platform Event(SecurityAlert__e)로 발송
SecurityAlertPublisher.publishAlert('NIGHT_MASS_API', UserInfo.getUserId(), '퇴근 시간 이후 수동 API 호출 감지');
```

### 🔀 (3) 순수 boolean 상태 확인 (Policy Check)
시스템에 액션을 강제하지 않고, 현재 이 유저가 위험 상태인지 `true/false` 논리값만 리턴받아 개발자가 자체 UI 분기 등을 태울 때 씁니다.
```apex
Boolean isDanger = SecurityPolicyEvaluator.isPolicyViolated('FILE_DOWNLOAD_LIMIT', UserInfo.getUserId());
if(isDanger) { 
    // 화면에 캡차(CAPTCHA) 등 추가 인증 컴포넌트를 띄우는 로직
}
```

### 📝 (4) 커스텀 액션(Action) 모듈 신규 개발
프레임워크가 제공하지 않는 회사 고유의 보안 조치(예: "ERP 시스템 계정 동기화 락")를 새로 개발할 때의 뼈대입니다.
```apex
// ISecurityAction 인터페이스를 구현 (또는 SecurityBaseAction 상속)
public with sharing class CustomERPBlockAction extends SecurityBaseAction {
    public override void execute(Map<String, Object> params) {
        String targetUserId = (String)params.get('targetUserId');
        // 여기에 외부 시스템 연동 또는 자체 보안 로직 작성
        SecuritySoarTrace.log('CustomERPBlockAction.execute', new Map<String, Object>{ 'UserId' => targetUserId });
    }
}
```

### 🎚️ (5) 보안 우회 킬스위치 (테스트 및 배치용)
단위 테스트(`@IsTest`)나 심야 정기 데이터 마이그레이션 배치에서 방해받지 않기 위해 일시적으로 프레임워크 통제를 끕니다.
```apex
SecurityKillSwitch.bypassSecurity(true);
// ... 무거운 데이터 마이그레이션 또는 테스트 로직 ...
SecurityKillSwitch.bypassSecurity(false);
```

---

## 🚑 4. 트러블슈팅 및 엣지 케이스 (Troubleshooting)

**[QA 1] "특정 유저가 블랙리스트 예외 메시지 띄우고 로그인이 안 돼요!"**
* **해결**: 대상 유저의 `SecurityUserState__c`(오브젝트) 레코드에 들어가서 상태가 `Quarantined`(격리) 이거나 `AlertCount__c`가 임계치를 넘었는지 확인하세요. `0`으로 초기화해주면 즉각 차단이 풀립니다.

**[QA 2] "SI 외부 연동용 API 어카운트가 자꾸 차단당합니다."**
* **해결**: 코드 레벨에서 예외 처리할 필요가 없습니다. 해당 API 계정의 프로필 또는 권한셋(Permission Set)에 **`Bypass_Security_SOAR` Custom Permission**을 할당해 두면 인터셉터가 항상 `Safe` 로 패스시킵니다.

**[QA 3] 테스트 코드(`@IsTest`)를 짜는데 Callout 에러나 Security 차단이 터집니다.**
* **해결**: 테스트 메서드 최상단에 앞서 설명한 **킬스위치**(`bypassSecurity(true)`)를 활성화하시거나, Callout이 일어나는 경우 `Test.setMock(HttpCalloutMock.class, new SecurityActionHttpMock());` 형태로 프레임워크 전용 Mocking 클래스를 등록하시면 완벽히 통과됩니다.

---
[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
