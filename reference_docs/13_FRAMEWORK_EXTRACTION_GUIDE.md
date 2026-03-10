# 📦 13. 독립 프레임워크 추출 및 1P 패키징 가이드 (Extraction & Packaging Pipeline)

본 문서는 현재 복잡하게 얽혀있는 로컬 Org 환경에서 오직 **Security SOAR 프레임워크 코어 엔진만을 분리(Extract)** 한 뒤, 새로운 퍼블리싱용 Dev Org (또는 GitHub Repo)에서 이를 **패키지화(Packaging)** 하고, 다시 본진 Org에 **설치(Install)** 하여 향후 **관리 포인트를 오직 신규 Org/Repo 단일화**하기 위한 마스터 가이드라인입니다.

---

## 🚀 Phase 1: SFDX 기반 신규 Org/Repo 분리 및 일괄 리네이밍
현재 코드베이스에서 불필요한 비즈니스 로직(AccountController 등)을 버리고, SOAR 필수 자산만 복사하여 이름 변경 부채(10번 문서 참조)까지 일괄 해결하는 단계입니다.

### 1-1. 신규 SFDX 프로젝트 생성
명령 프롬프트(또는 터미널)를 열고 별도의 디렉토리에 새로운 프레임워크 전용 프로젝트를 생성합니다.
```bash
# 1. 완전히 독립된 신규 SFDX 프로젝트 생성
sf project generate -n SOAR-Framework-Core

# 2. 신규 디렉토리로 이동
cd SOAR-Framework-Core
```

### 1-2. 핵심 패키지 모듈 분리 및 리네이밍 맵핑 규칙 (Modular Extraction)
기존 프로젝트(`SFDC-SOAR-ORG`) 폴더에서 필수 파일들만 복사하되, **19번 문서(모듈형 패키지 쪼개기)** 전략에 따라 물리적인 2개의 폴더(`package-base-interface`, `package-security-soar`)로 각각 나누어 이관합니다.

**[복사 및 리네이밍 규칙 적용]**
*아래와 같이 파일명을 To-Be로 변경하여 신규 프로젝트의 각 패키지 경로에 넣습니다.*

**[📦 패키지 A: `package-base-interface/main/default/`]**
* `objects/InterfaceConfig__mdt` ➡️ `objects/HttpCalloutConfig__mdt`
* `objects/InterfaceLog__c` ➡️ `objects/HttpCalloutLog__c`
* `classes/InterfaceRealTime.cls` ➡️ `classes/HttpCalloutRealTime.cls` (범용 API 호출 클래스)
* `Util_*` 관련 문자열 모듈 및 공통 함수

**[📦 패키지 B: `package-security-soar/main/default/`]**
* `objects/SecurityInboundConfig__mdt` ➡️ `objects/SecurityGlobalConfig__mdt`
* `objects/SecurityIntegration__mdt` ➡️ `objects/SecurityActionRoute__mdt`
* `objects/SecurityAuditLog__c` ➡️ `objects/SecurityUserState__c`
* `classes/SecurityGuard.cls` ➡️ `classes/SecurityPolicyEvaluator.cls`
* `classes/SecurityValidator.cls` ➡️ `classes/SecurityAccessChecker.cls`
* `classes/SecurityInterfaceBridge.cls` ➡️ `classes/SecurityActionDispatcher.cls`
* `classes/SecurityActionFactory.cls` ➡️ `classes/SecurityActionBuilder.cls`
* 🔥 **코어 엔진 파일 복사**: `EM_` 인터셉터 파일, `SecurityAlertHandler`, 모든 실제 구현 액션(`SecurityFreezeUserAction` 등) 클래스는 100% 이 폴더로 복사합니다.

### 1-3. 전역 문자열 치환 및 인증 (Find & Replace)
파일들의 껍데기 이름은 변경되었으므로, 내부 소스코드(Apex, SOQL)에 박혀있는 문자열 참조를 전역으로 일괄 치환합니다.
* VSCode의 돋보기(`Ctrl+Shift+F`) 기능을 사용하여 `SecurityInboundConfig__mdt`를 `SecurityGlobalConfig__mdt`로 모두 다 Replace 합니다.
* 치환이 완료되면 새로운 Dev Hub(또는 스크래치 오그)를 타겟으로 연결하고 소스를 배포하여 컴파일 에러가 없는지 체크합니다.
```bash
# 새로운 Dev Hub / 배포 타겟 Org 연동
sf org login web -a SoarDevHub -d

# 소스코드 전체 배포를 통한 의존성/에러 검증
sf project deploy start --target-org SoarDevHub
```
*(배포 중 `Util_*` 관련 에러가 나면 해당 에러 라인을 `SecurityEngineUtil` 등으로 묶은 프레임워크 내장 유틸리티 코드로 자체 교체합니다.)*

---

## 📦 Phase 2: Unlocked/Unlisted Managed Package 생성
단순한 소스코드 복사가 아니라, Salesforce의 공식 패키징 포맷으로 생성하여 관리 포인트를 일원화합니다. 
(참고: 내부망용은 무료인 `Unlocked`를, 코드 은닉이 필요하면 `Managed`(Unlisted) 타입을 사용합니다. - 18번 문서 참조)

### 2-1. 패키지 의존성 설정 (`sfdx-project.json`)
CLI 명령어 실행 전, `sfdx-project.json`에 `Base-Interface` 패키지와 `Security-SOAR` 패키지(Base에 의존성 가짐)를 설정해야만 합니다. (세부 JSON 구조는 19번 가이드라인 참조)

### 2-2. 2개의 패키지 껍데기 각각 생성
```bash
# 1. Base 통신 패키지 생성
sf package create --name "Base-Interface-Package" --path package-base-interface --package-type Unlocked --target-dev-hub SoarDevHub

# 2. SOAR 보안 패키지 생성
sf package create --name "Security-SOAR-Package" --path package-security-soar --package-type Unlocked --target-dev-hub SoarDevHub
```

### 2-3. 패키지 버전 빌드 (의존성 순서대로)
Base 패키지를 먼저 빌드한 후, SOAR 패키지를 빌드해야 컴파일이 성공합니다.
```bash
# 1. Base 패키지 버전 굽기
sf package version create -p "Base-Interface-Package" -x -c --wait 10 --target-dev-hub SoarDevHub

# 2. SOAR 코어 엔진 버전 굽기
sf package version create -p "Security-SOAR-Package" -x -c --wait 10 --target-dev-hub SoarDevHub
```
➡️ **결과**: 각각 `04t...` 로 시작하는 **설치용 패키지 ID (Subscriber Package Version Id)** 2개가 CLI 콘솔에 출력됩니다.

---

## 🔧 Phase 3: 본진(작업) Org에 패키지 설치 및 원본 찌꺼기 삭제
가장 중요하고 쾌감있는 최종 단계입니다. 이제 **관리 포인트는 오직 신규 레파지토리 1곳(SOAR-Framework-Core)** 에만 존재하며, 기존 본진 Org에서는 거추장스러운 SOAR 원본 클래스 코드를 버블 패키지 앱 하나로 추상화합니다.

### 3-1. 본진 Org 접속 및 패키지 설치
이전에 개발하던 원래의 무거운 조직(본진)으로 쉘 타겟을 전환하여 순서대로 의존성 주입을 진행합니다.
```bash
# 1. Base 통신 패키지 설치
sf package install --package "04t_BASE_PKG_ID" --target-org MyMainOrg --wait 10

# 2. SOAR 엔진 패키지 설치
sf package install --package "04t_SOAR_PKG_ID" --target-org MyMainOrg --wait 10
```

### 3-2. 기존 레거시(부채) 소스코드 제거 (Destructive Changes)
본진 Org에 이미 설치되어 있는 (패키징 되기 전 구 버전의) 하드코딩된 `Security*` 클래스, 오브젝트들을 완전히 삭제합니다.
패키지가 설치되면서 "잘 정돈된 To-Be 네이밍" 객체들로 교체되었으므로, 옛날 흔적인 `SecurityIntegration__mdt`, `SecurityGuard.cls` 같은 쓰레기 코드는 이제 Org 공간만 차지하게 됩니다.
* 본진 레파지토리에서 `destructiveChanges.xml` 을 작성하거나, Org의 설정(Setup) 화면에 들어가서 구버전 클래스/메타데이터를 수작업으로 지워버립니다.

### 🎉 최종 결과 (Architecture Win!)
* **본진 Org의 관점**: 
  - 지저분한 보안 프레임워크 클래스들 수백 개가 보이지 않습니다. 
  - 오직 "SOAR-Core-Engine" 이라는 앱(패키지) 1개가 설치되어 있을 뿐입니다. (블랙박스화 성공)
* **유지보수 관점**: 
  - 앞으로 보안 액션을 추가하거나 버그를 고치려면 **신규 Org/Repo**의 Vscode만 엽니다. 
  - 수정 후 Phase 2 명령어를 통해 버전을 `1.1.0` 으로 펌핑합니다. 
  - 전체 본진 Org나 클라이언트 Org들에 버전을 일괄 업그레이드(설치)하여 뿌립니다. (마치 AppExchange 앱 퍼블리셔와 같은 아키텍처 달성!)

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
