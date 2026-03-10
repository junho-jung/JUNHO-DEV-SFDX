# 📦 18. 패키징 스코프와 코드 가시성 제어 (Package Scope & Visibility)

*"패키지화 할 때 공개할 부분(정책 추가의 경우)랑 개별 액션 추가만 열어두고, 핵심 로직은 비공개해서 패키지를 올릴 수 있어?"*

**네, 완벽하게 가능합니다.** 이것이 바로 독립된 프레임워크를 Salesforce의 **패키지(Package)** 모델로 분리하려는 핵심 목적입니다.

Salesforce에서는 접근 제어자(`public`, `global`)와 패키징 타입(Unlocked 패키지 vs Managed 패키지)을 조합하여 **"사용자(구독자 Org)가 코드를 확장할 수는 있지만, 코어 엔진의 내부 코드는 볼 수도, 수정할 수도 없게(Black-box)"** 만드는 강력한 가시성 제어를 제공합니다.

---

## 🔒 1. 패키지 모델의 선택 (Unlocked vs Managed)

기존 본진 Org에 SOAR를 어떻게 주입할 것인가에 따라 두 가지 모델 중 하나를 선택해야 합니다. "비공개"의 목적에 따라 방식이 다릅니다.

### 🏢 옵션 A: 내부망 배포용 - Unlocked Package (현재 로드맵 13번 타겟)
* **특징**: 같은 회사 내의 여러 Org(Sandbox, Production)로 배포할 때 사용하는 "1P(1st Party)" 패키지 모델.
* **비공개성**: 코드가 완전히 숨겨지지는 않습니다. 구독자 Org(본진)에 설치하면 소스 코드가 **View(구독)** 는 가능합니다. 단, 잠겨있기 때문에 **수정(Edit/Delete)은 불가능**합니다.
* **확장성**: `public`으로 열어둔 컴포넌트들을 자유롭게 상속하고 조회할 수 있습니다.

### 🌍 옵션 B: 외부 판매용 (AppExchange) - Managed Package
* **특징**: 외부 고객사(B2B)나 AppExchange에 판매(배포)하기 위해 네임스페이스(Namespace, 예: `solomon_soar__`)를 강제 부여하는 "2P(2nd Party)" 패키지 모델.
* **비공개성 (완벽한 Black-box)**: 패키지 내부에 포함된 모든 Apex 클래스의 코드는 고객사 Org에서 **[Hidden]** 처리되어 절대 볼 수 없으며, 다운로드(Retrieve)도 원천 차단됩니다.
* **확장성**: 오직 `global` 예약어로 선언된 인터페이스와 클래스만 외부(고객사 Org)에서 접근 및 상속이 가능합니다.

*(💡 결론: 만약 정말 "코드 유출 자체"를 막고 싶다면 네임스페이스 기반의 **Managed Package**로 빌드해야 합니다.)*

---

## 🛡️ 2. 코드 접근 제어자 전략 (`public` vs `global`)

어떤 패키지를 고르든(특히 Managed Package 배포 시), 외부에서 마음대로 확장(Extension)은 하되 코어 엔진은 건드리지 못하게 하려면 Apex 클래스의 **접근 제어자(Access Modifier)** 를 철저히 분리해야 합니다.

### 🔑 2-1. 외부로 열어줄 확장 지점 (`global` 선언)
사용자(구독자 개발팀)가 새로운 "커스텀 액션(Action)"이나 "외부 API 모듈"을 만들려면 반드시 접근해야 하는 뼈대 클래스와 인터페이스들은 `global` (또는 Managed를 안 쓴다면 `public`)로 활짝 열어주어야 합니다.

```apex
// 1. 액션 클래스를 만들려면 무조건 상속받아야 하는 Base 클래스 (열어줌)
global abstract class SecurityBaseAction {
    global abstract void execute(Map<String, Object> params);
}

// 2. 외부에서 킬스위치를 껐다 켰다 할 수 있게 제공하는 유틸리티 (열어줌)
global class SecurityKillSwitch {
    global static void bypassSecurity(Boolean isBypass) { ... }
}
```

### ⬛ 2-2. 꼭꼭 숨겨야 할 프레임워크 코어 심장부 (`public` + `@namespaceAccessible`)
트랜잭션 이벤트를 감지하고, 캐시를 돌리고, 라우팅을 쏴주는 **엔진 부품들(Engine Internals)** 은 `public`으로만 둡니다. Managed 패키지로 배포될 시 이 클래스들은 외부 Org에서 그 존재조차 알 수 없는 투명 인간(Hidden)이 됩니다.

```apex
// [코어 1] 이벤트를 감지하는 실제 인터셉터 로직 (외부 접근 차단)
public class EM_SecurityReportInterceptor implements TxnSecurity.EventCondition { ... }

// [코어 2] 메타데이터를 파싱하고 캐싱하는 핵심 두뇌 (외부 접근 차단)
public class SecurityPolicyEvaluator { ... }

// [코어 3] 다이나믹 객체를 찍어내는 팩토리 빌더 (외부 접근 차단)
public class SecurityActionBuilder { ... }
```

---

## 🏗️ 3. "신규 커스텀 기능 추가" 프로세스 (구독자 Org 입장)

패키지가 설치된 고객사(본진) Org의 개발자와 어드민은 프레임워크 내부 소스가 숨겨져 있더라도 아무 불편함 없이 16번 문서에서 증명했던 **OCP 원리**에 따라 무한 확장이 가능합니다.

1. **[구독자 Org 로컬 개발]**: 고객사 개발자는 열려있는 `global class SecurityBaseAction`을 상속받아 자신만의 로컬 Apex 클래스(`LocalCustomErpAction.cls`)를 새로 짭니다.
2. **[메타데이터 등록]**: 어드민은 Setup 메뉴로 가서 `SecurityActionRoute__mdt` 메타데이터에 새 레코드를 만듭니다. 이때 `ActionClassName__c` 칸에 방금 개발자가 로컬에 만든 `LocalCustomErpAction`이라고 적어줍니다.
3. **[프레임워크의 동적 감지]**: 숨겨져 있는 패키지 내부 코어 엔진(`SecurityActionBuilder`)은 **리플렉션(`Type.forName()`)** 메커니즘을 돌립니다. 이때 패키지 내부 소스가 아니더라도, 로컬 Org에 존재하는 클래스 이름을 찾아내 동적으로 Instance를 찍어내어 실행시켜 줍니다.

---

## 🏆 결론: 완벽한 블랙박스 & 플러그인 생태계

* 핵심 질문: **"정책 등록이나 개별 액션을 로직 비공개로 패키지화해서 올릴 수 있어?"**
* 답변: **네, "Managed Package + Global/Public 분리 + Reflection" 3박자 콤보로 완벽히 가능합니다.**

1. **코어 비공개**: 프레임워크 내부 인터셉터 로직과 라우팅 엔진은 외부에서 절대 열어볼 수 없는 단단한 블랙박스(Black-box)가 됩니다.
2. **플러그인 확장 (Plug-in Extensibility)**: 고객은 제공된 `global` 인터페이스(`SecurityBaseAction`)만 사용하여 플러그인(Plug-in) 코드를 로컬로 짜고, 메타데이터에 플러그인 이름만 등록하면 됩니다. 
3. 프레임워크 코어는 이 로컬 플러그인을 자동으로 찾아 비동기 큐에 태우고 콜아웃을 발사합니다.

이것이 글로벌 시장에 AppExchange 솔루션을 판매하는 ISV(Independent Software Vendor)들의 표준 아키텍처 디자인 패턴입니다.

---

## 📋 [체크리스트] 패키징(2P)을 위한 접근 제어자 수정 대상 클래스

AppExchange용 Managed Package를 빌드하기 전, 현재 개발된 소스코드에서 필수로 수정해야 할 `public` ↔ `global` 전환 목록입니다.

### 🟢 1. `global` 로 변경해야 할 부분 (외부 확장 플러그인용)
고객사가 직접 상속받거나 호출해야 하는 기반(Base) 클래스 및 유틸리티입니다.

1. **`SecurityBaseAction.cls`** (현재 `public abstract`) ➡️ `global abstract` 로 변경
   * 고객이 커스텀 액션을 만들 때 상속받아야 합니다.
   * 내부의 `execute` 메서드도 `global abstract void execute` 로 변경해야 합니다.
2. **`ISecurityAction.cls`** ➡️ `global interface` 로 변경
3. **`SecuritySoarTrace.cls`** (현재 `public`) ➡️ `global` 로 변경
   * 고객사 커스텀 액션에서도 공용 SOAR 로그(AuditLog)를 남길 수 있어야 합니다.
   * `log()` 메서드도 `global static` 으로 열어줍니다.
4. **`SecurityKillSwitch.cls`** ➡️ `global` 로 변경
   * 고객사가 자체 단위 테스트(`@IsTest`)를 작성할 때 킬스위치를 쓸 수 있어야 합니다.

### 🔴 2. `public` 으로 유지/격하해야 할 부분 (코어 엔진 은닉용)
외부 확장이 불필요하며, 트랜잭션 라우팅과 로직을 담당하여 절대 노출되지 말아야 할 엔진 부품들입니다. (현재 혹시라도 `global`로 되어 있다면 `public`으로 내려야 합니다.)

1. **`EM_Security*Interceptor.cls` 시리즈 전반**
   * (주의! 현재 `global with sharing class EM_SecurityMonitorInterceptor` 로 선언된 부분들이 있습니다. 이를 전부 `public`으로 내려야 외부에서 인터셉터 구현부를 훔쳐볼 수 없습니다.)
2. **`SecurityPolicyEvaluator.cls`** (`public` 유지)
3. **`SecurityActionBuilder.cls`** (`public` 유지)
4. **`SecurityActionExecutor.cls`** (`public` 유지)
5. **`SecurityAlertHandler.cls`** (`public` 유지)

### ⚠️ 3. 기타 패키징(Packaging) 필수 사전 작업
1. **`@namespaceAccessible` 어노테이션 검토**: 
   * 만약 Managed 패키지 내 `public` 클래스들끼리 서로를 호출하다가 네임스페이스 장벽에 막히는 경우가 발생하면(특히 메타데이터 동적 참조 시), 이 어노테이션을 제한적으로 붙여 내부망 통신을 허용해야 합니다.
2. **테스트 커버리지 (Test Coverage)**: Managed Package로 묶으려면 전체 Apex 대상 최소 75% 이상의 커버리지가 강제됩니다. `SecurityZeroCodeTest.cls`, `SecurityKillSwitchTest.cls` 등 프레임워크 전용 테스트 코드를 완비해야 합니다.
3. **이름 충돌 방지**: 이미 10번 문서에서 `Security*` 접두사로 통일하기로 합의했으므로, 향후 어떤 네임스페이스(`xyz_soar__`)가 붙든 객체명 충돌은 일어나지 않습니다.

---

## 💡 [FAQ] AppExchange 배포가 아니라면 패키지화는 돈이 들거나 번거롭지 않나요?

결론부터 말씀드리면 **전혀 돈이 들지 않으며, 개발 과정도 생각보다 매우 간단합니다.**

이 부분을 명확히 이해하려면 Salesforce 패키지의 두 가지 방향성(목적)을 완전히 분리해서 생각하셔야 합니다.

### 1️⃣ 내부망 공통 모듈용: Unlocked Package (강력 추천 ⭐️)
AppExchange 판매 목적이 아니라 "우리 회사(계열사)의 다른 샌드박스나 프로덕션 오그에 편하게 배포하고 플러그인을 붙이겠다"는 목적이라면 **Unlocked Package**가 정답입니다.

* **비용(Cost)**: 완전히 **무료(Free)** 입니다. Developer Hub(Dev Hub)가 켜진 엔터프라이즈 오그만 있으면 무제한으로 공짜 빌드가 가능합니다.
* **수고(Effort)**: AppExchange 보안 심사(Security Review)를 받을 필요가 전혀 없습니다. `sfdx force:package:create` 명령어 한두 줄만 치면 1분 만에 `04t...` 버전 코드가 포함된 URL(설치 링크)이 뚝딱 튀어나옵니다. (15번 CLI 치트시트 참조)
* **관리 편의성**: 오히려 앤트(Ant) 스크립트나 Change Set(변경 세트)으로 끙끙대며 배포하는 것보다 수백 배 깔끔합니다. 코어가 업데이트되면 버전 번호(예: `1.2.0`)만 올려서 설치 링크를 내부 개발자들에게 공지하면 끝입니다.

### 2️⃣ 상업용 벤더 판매용: AppExchange Managed Package (주의)
* **비용(Cost)**: 매년 파트너십 비용과 함께 보안 심사 티켓(수백만 원 수준)을 지불해야 합니다.
* **수고(Effort)**: Salesforce 보안팀의 끔찍할 정도로 깐깐한 수동 코드 뷰(Security Review)를 통과해야 합니다. (SOQL Injection 방지, XSS 방어, CRUD 권한 체크 등 모든 보안 룰을 100% 지켰는지 사람이 검수함)
* **목적**: 전 세계 불특정 다수에게 "유료"로 팔기 위한 용도입니다.

**✅ 최종 요약 결론**
아키텍처의 개방-폐쇄 원칙(Extensibility)과 깔끔한 배포 관리를 원하신다면, 단순히 내부 Dev Hub를 이용해 **'무료 Unlocked Package(잠금 해제 패키지)'** 로 빌드하시는 것이 가장 적은 비용(0원)과 최고의 효율을 가져다줄 것입니다.

---

## 🕵️‍♂️ [FAQ 2] "돈은 안 받을 건데, 코드가 남들에게 보이는 건 싫습니다! 방법이 없나요?"

**네, 완벽히 원하시는 방법이 있습니다! (Unlisted Managed Package)**

앱 익스체인지(AppExchange)에 정식으로 올리지 않으면서도, **"돈/심사 걱정 없이 소스코드만 완벽하게 블랙박스(Hidden) 처리"** 하여 배포하는 강력한 우회로입니다. 이를 **2GP (2nd Generation) Managed Package의 링크 직접 배포(Unlisted) 방식**이라고 부릅니다.

### 💼 Unlisted Managed Package (코드 숨김 + 무료 배포)
* **어떻게 하나요?**: SFDX CLI에서 패키지를 생성할 때 타입(Type)을 `Unlocked`가 아니라 **`Managed`** 로 지정해서 빌드(`sfdx force:package:create --packagetype Managed`)하기만 하면 됩니다.
* **비용(Cost)**: **0원 (무료)** 입니다. Salesforce에 파트너 등록비나 보안 심사비를 전혀 내지 않아도 빌드가 가능합니다.
* **보안 심사(Security Review)**: **안 해도 됩니다.** (AppExchange 공용 스토어에 검색되게 올릴 때만 심사가 필수입니다.)
* **코드 가시성**: 완벽한 블랙박스입니다. 설치자(구독자)는 설치 링크(`04t...`)를 받아 설치할 수 있지만 안의 코드는 절대로 열어볼 수 없습니다.
* **제약 사항**: 유일한 단점은 "설치하는 고객사의 Org"의 리미트(API Callout 제한 등)를 그대로 깎아먹는다는 점입니다. (정식 리뷰를 통과한 패키지는 독자적인 리미트를 부여받지만, 비공개 패키지는 고객사 시스템의 한도를 같이 씁니다. 코어 SOAR 로직에서는 크게 문제될 것이 없습니다.)

**[💡 결론]** 
고객이나 파트너사에게 "무료로 제공하되 코어 IP(지적재산권)는 보호하고 싶다"면, **[AppExchange에 올리지 않는 2GP Managed Package]** 로 빌드해서 **설치 링크(`04t...`)만 이메일/메신저로 직배포**하는 것이 100점짜리 정답입니다!

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
