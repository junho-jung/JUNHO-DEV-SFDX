# 🗺️ 14. 통합 구현 로드맵 및 작업 순서 (Implementation Roadmap)

본 문서는 지금까지 작성된 방대한 기술 분석 문서(05 리팩토링, 09 이벤트 소싱, 10 네이밍 부채, 12 보안 감사, 13 프레임워크 추출)의 실행을 위해 **"어떤 순서로 코딩과 마이그레이션을 진행해야 하는가"** 에 대한 가장 안전하고 논리적인 **단계별 실행 로드맵(Execution Roadmap)** 입니다.

동시에 병행(Parallel) 가능한 작업과 반드시 선행되어야 하는 순차적(Sequential) 작업을 명확히 구분하여, 시스템 중단(Downtime)이나 코드 꼬임 현상을 방지합니다.

---

## 🎯 [개요] 전체 작업 페이즈 (Phases)

전체 작업은 크게 4가지 Phase로 구성됩니다. **결론부터 말씀드리면, "이름을 먼저 바꾸고 신규 Org로 이사 간 뒤에 ➡️ 신규 Org 안에서 느긋하게 리팩토링과 단위 테스트를 진행"** 하는 것이 가장 안전한 전략입니다.

1. **Phase 1 (준비 및 추출)**: 네이밍 부채 청산과 신규 Org(레파지토리)로의 물리적 이사 (제일 먼저 해야 함)
2. **Phase 2 (보안 및 유틸 정리)**: 신규 Org 내에서 불필요한 찌꺼기 정리 및 이메일 마스킹 (13번 연계)
3. **Phase 3 (코어 엔진 리팩토링)**: 패턴(리플렉션, 파사드, 레지스트리)을 적용하여 코드 다이어트 (05번 연계)
4. **Phase 4 (패키징 및 아키텍처 진화)**: 패키징 배포 후, 궁극의 이벤트 소싱 기반 상태 머신 적용 (09번 연계)

---

## 📅 상세 작업 순서 (Step-by-Step)

### 🚀 Phase 1: 기반 추출 및 네이밍 치환 (Extraction & Renaming)
> 기존 거대한 본진 Org에서 작업하면 에러 트래킹이 어려우므로 **무조건 1순위로 진행**합니다. 리팩토링(로직 변경)은 절대 하지 않고 파일명과 문자열만 바꿉니다.

* **[Step 1.1] 신규 SFDX 프로젝트 뼈대 생성** (문서 13 가이드) 
  ```bash
  # 1. 터미널을 열고 본진 폴더 바깥(상위 디렉토리)으로 이동
  cd ..
  
  # 2. SOAR 코어 전용 독립 프로젝트 생성
  sf project generate -n SOAR-Framework-Core
  
  # 3. 신규 프로젝트 폴더로 이동하여 Git 초기화
  cd SOAR-Framework-Core
  git init
  ```
* **[Step 1.2] 컴포넌트 복사 및 모듈형 디렉토리 분할** (문서 13 & 19 가이드) 
  - `force-app` 단일 폴더 대신, `package-base-interface`와 `package-security-soar` 두 개의 폴더를 생성하고 알맞게 컴포넌트 이관.
  - 이 과정에서 `SecurityInboundConfig` ➡️ `SecurityGlobalConfig`, `Interface` ➡️ `HttpCallout` 등으로 물리적 파일명 변경 동시 진행.
* **[Step 1.3] 전역 문자열 치환 매핑 (Global Find & Replace)** 
  - 클래스 내부 SOQL이나 변수 타입 명시에서 구 이름으로 참조된 텍스트 코드를 VSCode에서 전역 치환.
* **[Step 1.4] 첫 번째 스크래치 오그(Scratch Org) 배포 컴파일 테스트**
  ```bash
  # 1. Dev Hub 역할의 기반 오그 연결 (웹 브라우저 로그인)
  sf org login web -a MyDevHub -d
  
  # 2. 빈 Scratch Org(개발/테스트용 일회용 오그) 생성 (ex: 7일 유지)
  sf org create scratch -d -f config/project-scratch-def.json -a SoarCoreScratchOrg -y 7
  
  # 3. 소스코드 전체를 스크래치 오그로 1차 배포 (의존성 컴파일 에러 체크용)
  sf project deploy start --target-org SoarCoreScratchOrg
  ```

---

### 🧹 Phase 2: 격리 및 클렌징 (Cleansing & Masking)
> 신규 폴더 내부의 소스코드를 깔끔히 다듬는 단계입니다. **이 단계까지는 기존 본진 Org에 어떤 영향도 주지 않습니다.**

* **[Step 2.1] 범용 유틸리티 병합 (Utility Merge)**
  - 본진에서 딸려온 파편화된 `Util_*` 찌꺼기 코드 중 SOAR 프레임워크가 진짜 사용하는 메서드(JSON 직렬화 등)만 남기고 `SecurityEngineUtil.cls` 1개로 통합.
* **[Step 2.2] 보안 감사 조치 (Security Scrubbing)** (문서 12 가이드)
  - `CommonUtil*`, `EmailConfig*` 등 클래스 헤더 주석에 남은 개발자 실제 이메일(`@solomontech.net` 등) 삭제 및 `[Developer Name]` 처리.

---

### 🔨 Phase 3: 코어 아키텍처 리팩토링 (Core Refactoring)
> 이제 신규 Org 내에서 소스가 완벽히 빌드되고 격리되었습니다. 여기서부터 본격적인 객체지향 패턴 코드 다이어트(로직 변경)를 시작합니다. **이 단계의 세부 Step들은 팀원들과 병렬(Parallel)로 나누어 코딩이 가능합니다.**

* **[병렬 1. 팩토리 동적 로딩화]** (문서 05-Tier 1)
  - `SecurityActionBuilder.cls`(구 Factory) 내부의 수많은 `switch` 하드코딩 문을 **Reflection(Type.forName)** 메커니즘으로 교체하여 OCP 달성.
* **[병렬 2. 메타데이터 레지스트리 도입]** (문서 05-Tier 2)
  - 이곳저곳 흩어져서 SOQL로 메타데이터를 긁어오던 것을 `SecurityMetadataRegistry.cls` 싱글톤 패턴으로 일원화하여 성능 펌핑.
* **[병렬 3. 메인 정책 엔진(Brain) 분해]** (문서 05-Tier 2)
  - 덩치가 너무 큰 `SecurityPolicyEvaluator.cls`(구 Guard)의 역할을 Façade 패턴을 통해 `~AuthValidator`, `~TimeThreshold`, `~ProfileChecker` 등의 작은 헬퍼 클래스로 역할 분리(SRP).
* **[병렬 4. 단위 테스트(Unit Test) 완벽 검증]**
  ```bash
  # 로컬 소스코드 수정 후 Scratch Org로 변경분 푸시
  sf project deploy start
  
  # 전체 Apex 단위 테스트 실행 및 코드 커버리지 확인 (최소 75% 이상)
  sf apex test run --code-coverage --result-format human --wait 10
  ```

---

### 👑 Phase 4: 마이그레이션과 상태 머신 진화 (Migration & Evolution)
> 리팩토링된 신규 코드를 패키지로 묶어 본진에 덮어씌우고, 차세대 기획을 준비하는 최종 단계입니다.

* **[Step 4.1] 모듈형 패키지 2종 버전 빌드** (문서 13 & 19 가이드) 
  - `sfdx-project.json`에 의존성을 설정한 뒤, Base 패키지부터 굽고 SOAR 패키지를 굽습니다.
  - (사내망 배포면 `Unlocked`, 외부 블랙박스 배포면 `Managed` 타입 사용 - 문서 18 참조)
  ```bash
  sf package version create -p "Base-Interface-Package" -x -c -w 10 -v MyDevHub
  sf package version create -p "Security-SOAR-Package" -x -c -w 10 -v MyDevHub
  ```
* **[Step 4.2] 본진 Org 인스톨 및 원본 파괴 (Destructive Deployment)** 
  ```bash
  # 1. 원래 접속하던 본진 Org 연결
  sf org login web -a MyMainOrg
  
  # 2. 의존성 순서에 따라 차례대로 인스톨
  sf package install -p "04t_BASE_PKG" -o MyMainOrg -w 10
  sf package install -p "04t_SOAR_PKG" -o MyMainOrg -w 10
  ```
  - 설치 완료 후, 기존 본진 Org에 남아있는 구버전 찌꺼기 코드(수 백 개의 구 `Security*` 파일들) 일괄 파괴(Delete).
* **[Step 4.3] 차세대 상태 머신(Event Sourcing) 데이터 마이그레이션 착수** (문서 09 가이드)
  - 기존 `SecurityAuditLog__c` 데이터를 차세대 `SecurityUserState__c` (State Entity)의 "초기 상태(Genesis State)"로 활용하기 위해 AlertCount 필드 등을 데이터베이스 레벨에서 마이그레이션 배치 가동.

---

## 📝 팁 요약
* **Phase 1, 2**는 단순 '파일 복사 / 치환 / 텍스트 삭제'이므로 하루(Day 1) 만에 끝낼 수 있는 가장 급선무입니다.
* **Phase 3(리팩토링)** 에 며칠의 개발 및 단위 테스트(Unit Test) 기간을 충분히 할당하십시오. 신규 Org 안에서 작업하므로 본진 장애 우려 없이 편하게 테스트할 수 있습니다.

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
