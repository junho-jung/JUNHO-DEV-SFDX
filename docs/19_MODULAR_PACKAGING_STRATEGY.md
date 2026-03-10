# 🧩 19. 모듈형 패키지 분리 가이드 (Modular Packaging & Dependency)

*"지금 인터페이스(API 연동) 부분이랑 SOAR가 같이 있는데, 인터페이스만 쓰는 프로젝트가 있고 SOAR까지 쓰는게 있어서 패키지를 나눠야할 것 같아. 여기에 대한 가이드라인을 줘."*

이것은 진정한 엔터프라이즈급 Salesforce DX 아키텍처로 넘어가기 위한 궁극적인 고민입니다. 시스템을 거대한 원통(Monolithic)으로 묶는 대신, **레고 블록(Modular Architecture)** 처럼 쪼개는 방식입니다.

이 가이드는 현재 혼재되어 있는 코드를 **[Base-Interface 패키지]** 와 그 위에 얹히는 **[Security-SOAR 패키지]** 로 분리하고, 두 패키지 간의 **종속성(Dependency)** 을 맵핑하는 전략을 다룹니다.

---

## 🏗️ 1. 패키지 분할 구조도 (The Split Architecture)

전체 소스코드를 역할에 따라 2개의 독립된 기능 단위(Package)로 칼같이 찢어냅니다.

### 📦 패키지 A: `Base-Interface-Package` (공통 코어)
* **목적**: SOAR 프레임워크가 설치되지 않은 가벼운 영업/서비스 프로젝트에서도 범용적으로 사용할 수 있는 **순수 API 통신 및 유틸리티 뼈대**입니다.
* **포함 요소 (Components)**:
  * 통신 설정 메타데이터 (`HttpCalloutConfig__mdt`)
  * 범용 HTTP Callout 유틸리티 클래스 (`Util_HttpCallout.cls` 등 통신 모듈)
  * 기초 공통 유틸리티 (`Util_String`, `Util_User` 등 다른 곳에서도 쓰는 함수 모음)

### 📦 패키지 B: `Security-SOAR-Package` (확장 모듈)
* **목적**: 오직 고급 보안 모니터링이 필요한 프로젝트에만 선택적으로 설치하는 확장팩입니다.
* **포함 요소 (Components)**:
  * 모든 이벤트 인터셉터 (`EM_Security*Interceptor`)
  * 정책 관리 메타데이터 (`SecurityPolicy__mdt`)
  * 아키텍처 코어 엔진 (`SecurityAlertHandler`, `SecurityActionBuilder`)
* **특이사항**: 패키지 B는 컴파일되고 작동하기 위해 반드시 패키지 A의 통신 메타데이터(`HttpCalloutConfig__mdt`)가 존재해야 합니다. **👉 (패키지 종속성 발생)**

---

## ⚙️ 2. SFDX 프로젝트 구조 및 의존성 주입 (Dependency Injection)

패키지를 나누기 위해 GitHub 레포지토리를 2개로 찢을 필요는 없습니다. 하나의 폴더 구조(Monorepo) 안에서 `sfdx-project.json` 파일 하나로 다중 패키지 빌드를 한 번에 통제할 수 있습니다.

### [Step 1] 폴더 구조(디렉토리) 물리적 분리
`force-app/main/default` 아래에 뭉쳐있던 코드들을 두 개의 폴더로 강제 분리합니다.

```text
SFDC-SOAR-ORG (Root)
 ┣ 📂 sfdx-project.json
 ┣ 📂 package-base-interface/  <-- (🔥 패키지 A용 소스코드 폴더)
 ┃  ┣ 📂 main/default/classes/ (Util, Base 연동 클래스들)
 ┃  ┗ 📂 main/default/customMetadata/ (HttpCalloutConfig__mdt)
 ┗ 📂 package-security-soar/   <-- (🔥 패키지 B용 소스코드 폴더)
    ┣ 📂 main/default/classes/ (EM_, Security* 코어 엔진들)
    ┗ 📂 main/default/customMetadata/ (SecurityPolicy__mdt)
```

### [Step 2] `sfdx-project.json` 패키지 구성 (핵심)
이 파일이 Salesforce CLI에게 패키지를 어떻게 쪼개서 빌드할지 알려주는 "설계도"입니다.
**패키지 B가 패키지 A에 의존한다(dependencies)** 고 명시해 줍시다.

```json
{
  "packageDirectories": [
    {
        "path": "package-base-interface",
        "package": "Base-Interface-Package",
        "versionName": "ver 1.0",
        "versionNumber": "1.0.0.NEXT",
        "default": true
    },
    {
        "path": "package-security-soar",
        "package": "Security-SOAR-Package",
        "versionName": "ver 1.0",
        "versionNumber": "1.0.0.NEXT",
        "default": false,
        "dependencies": [
            {
                "package": "Base-Interface-Package",
                "versionNumber": "1.0.0.LATEST"
            }
        ]
    }
  ],
  "name": "SFDC-SOAR-ORG",
  "namespace": "",
  "sfdcLoginUrl": "https://login.salesforce.com",
  "sourceApiVersion": "59.0"
}
```

---

## 🚀 3. 분할 패키지 빌드 및 배포 사이클 (Life Cycle)

이제 패키지가 2개가 되었으므로, 빌드(버전 생성)도 2번 해야 합니다. CLI 명령어 순서는 다음과 같습니다.

### 상황 1. 인터페이스(Base)만 살짝 고쳤을 때
1. `sfdx force:package:version:create -p "Base-Interface-Package" -x -c`
2. 생성된 Base 패키지 URL(`04t...`)만 뽑아서 일반 영업 프로젝트 Org에 배포합니다.

### 상황 2. SOAR 쪽 코드(또는 둘 다)를 고쳤을 때
1. **(필수)** Base 패키지 버전이 올라갔다면 SOAR 빌드 전에 Base부터 먼저 버전을 굽습니다.
2. `sfdx force:package:version:create -p "Security-SOAR-Package" -x -c`
3. 이때 CLI가 `sfdx-project.json`을 읽고 "앗! SOAR 패키지를 구우려면 Base 패키지가 먼저 필요하네?" 하고 종속성 검사를 자동으로 통과시킨 뒤 `04t...` 링크를 줍니다.

### 상황 3. 고객사(구독자 Org)에 배포할 때 (설치 과정)
* **일반 프로젝트**: Base 패키지 1개만 설치. (통신 유틸리티 사용 완료)
* **보안 프로젝트**: Base 패키지를 먼저 설치한 뒤, SOAR 패키지 설치. (만약 Base 설치 안 하고 SOAR를 치면 "의존성(Dependency)이 없습니다" 라는 에러와 함께 튕겨냅니다.)

---

## 💡 결론 및 아키텍트 조언 (Architect's Advice)

**"하나의 레포지토리(Monorepo)에서 여러 모듈(Packages)을 각각 빌드하는 SFDX 의존성 주입 기법"** 을 사용하면 고객/프로젝트의 요건에 따라 레고 블록을 골라 꽂아줄 수 있습니다.

**주의할 점**: 이 방식으로 넘어갈 때는 14번 구현 로드맵의 `Phase 1(추출)` 과정에서 소스코드를 `force-app` 1개에 다 때려넣지 말고, 처음부터 디렉토리를 `package-base-interface`, `package-security-soar` 두 개로 만들어 놓고 코드를 정교하게 드래그 앤 드랍으로 물리적 분리부터 해야 합니다. 이후 컴파일이 성공하는지 확인하는 것이 가장 중요합니다!

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
