# 💻 15. SFDX (sf) CLI 필수 명령어 가이드 및 치트 시트 (Cheat Sheet)

Salesforce DX(`sf` CLI)를 활용하여 프로젝트 마이그레이션, 패키징, 오그 권한 관리, 소스 배포 등을 수행할 때 자주 사용되는 명령어들을 **기능별, 사용 빈도순**으로 정리한 별첨 문서입니다.

프레임워크 적출 및 1P 패키징 작업(13, 14번 문서)을 수행할 때 참고하여 활용하십시오.

---

## 🔑 1. 인증 및 조직(Org) 관리 (가장 많이 씀)
Salesforce 환경에 로그인하고, 로컬 디렉토리와 Org를 연결하는 필수 명령어입니다.

| 기능 | CLI 명령어 | 설명 및 예시 |
| :--- | :--- | :--- |
| **운영/개발 오그 로그인** | `sf org login web -a MyDevHub`<br>`sf org login web -a MySandbox -r https://test.salesforce.com` | `-a` (Alias): 별칭 지정<br>`-r` (URL): 샌드박스는 test 지정 필수<br>웹 브라우저가 열리며 OAuth 로그인 수행 |
| **연결된 Org 목록 보기** | `sf org list` | 현재 로컬 PC에 인증된 모든 오그(Dev Hub, Sandbox, Scratch 등)의 별칭과 상태 출력 |
| **기본 대상(Target) 지정** | `sf config set target-org MySandbox` | 이후 명령어에서 `-o` 옵션을 생략하면 이 Org로 기본 배포/조인됨 |
| **스크래치 오그 생성** | `sf org create scratch -d -f config/project-scratch-def.json -a MyScratch -y 7` | `-d`: 디폴트 오그로 설정<br>`-a`: 별칭<br>`-y 7`: 7일 후 자동 삭제 |
| **특정 Org 브라우저로 열기** | `sf org open -o MyScratch` | 패스워드 입력 없이 즉시 해당 오그의 UI 뷰 띄우기 |
| **로그아웃 (연결 해제)** | `sf org logout -o MyDevHub` | 지정한 오그의 연결 토큰 삭제 및 로그아웃 |

---

## 🚀 2. 소스 배포 및 가져오기 (Deploy & Retrieve)
로컬 VSCode의 소스코드를 Org에 올리거나, Org에서 개발한 내용을 로컬로 다운받는 명령어입니다.

| 기능 | CLI 명령어 | 설명 및 예시 |
| :--- | :--- | :--- |
| **전체 소스 배포 (Push)** | `sf project deploy start -o MySandbox` | `force-app` 하위의 모든 소스 코드를 서버(Org)에 밀어넣음 |
| **특정 파일만 배포** | `sf project deploy start -m ApexClass:SecurityGuard -o MySandbox` | 클래스나 트리거 하나만 콕 집어서 배포할 때 사용 |
| **서버 소스 가져오기 (Pull)** | `sf project retrieve start -o MySandbox` | Org에서 변경된 메타데이터를 로컬 VSCode로 다운로드 (동기화) |
| **특정 패키지(XML) 기준 배포**| `sf project deploy start -x manifest/package.xml -o MySandbox` | 배포할 목록이 담긴 `package.xml` 기반으로 배포 (가장 안전하고 전통적인 방식) |
| **파괴 배포 (Delete)** | `sf project deploy start --manifest manifest/destructiveChanges.xml --post-destructive-changes` | 본진 Org의 찌꺼기 레거시 코드를 삭제할 때 사용하는 파괴적 배포 명령어 |

---

## 📦 3. 패키지(Unlocked Package) 생성 및 설치
SOAR 프레임워크를 1P 기반 앱으로 묶고, 본진 Org에 설치하기 위한 배포/버저닝 명령어입니다.

| 기능 | CLI 명령어 | 설명 및 예시 |
| :--- | :--- | :--- |
| **패키지 껍데기 생성** | `sf package create -n "SOAR-Core" -t Unlocked -r force-app -v MyDevHub` | 네임스페이스가 없는 Unlocked Package의 기본 틀 생성 (sfdx-project.json 자동 수정됨) |
| **패키지 버전 굽기 (Build)** | `sf package version create -p "SOAR-Core" -k "1234" -w 10 -v MyDevHub` | 코드를 압축하여 고유 설치 ID(`04t...`)를 생성. `-k`: 설치 패스워드 지정 |
| **패키지 버전 조회** | `sf package version list -v MyDevHub` | 지금까지 빌드한 패키지들의 Version Number 및 패키지 ID 목록 출력 |
| **패키지 설치 (Install)** | `sf package install -p "04tXXXXXXXXXXXXXXX" -k "1234" -o MyMainOrg -w 10` | 생성된 패키지를 실제 본진 Org에 설치. 완료 알림(`-w`) 최대 10분 대기 |
| **설치된 패키지 확인** | `sf package installed list -o MyMainOrg` | 대상 오그에 무사히 1.0.1 버전이 설치되었는지 확인 |

---

## 💡 4. 데이터/테스트 및 특정 상활별(Edge Cases) 치트

### 👨‍💻 [상황 1] 스크래치 오그 만들었는데 Admin 권한이 없어 파일이 안 보일 때
스크래치 오그를 처음 만들면 표준 유저일 수 있습니다. 직접 만든 `SOAR_Admin` 같은 권한셋(Permission Set)을 커맨드로 즉시 부여할 수 있습니다.
```bash
# 지정한 유저(또는 본인)에게 Security_Admin 권한셋 할당
sf org assign permset -n Security_Admin -o MyScratch
```

### 🧪 [상황 2] 로컬에서 손쉽게 전체 단위 테스트(Unit Test) 돌리기
배포하기 전에 코드 커버리지(75% 이상)를 체크하고 싶을 때 사용합니다.
```bash
# 전체 테스트 코드 수행하고 커버리지를 Human Readable(보기 좋게) 표기
sf apex test run --code-coverage --result-format human -o MySandbox -w 10

# 특정 테스트 클래스 단 1개만 돌리기 (빠른 검증)
sf apex test run -t SecurityActionBuilderTest -o MySandbox
```

### 🗄️ [상황 3] SOQL 쿼리를 터미널에서 쳐서 데이터/메타데이터 뽑아오기
굳이 Developer Console을 열지 않아도, 터미널에서 즉각적으로 데이터(AuditLog 등)를 조회해 볼 수 있습니다.
```bash
# AuditLog의 최근 10개 레코드를 표(Table) 형태로 출력
sf data query -q "SELECT Id, ActionType__c, TargetUserId__c FROM SecurityAuditLog__c LIMIT 10" -o MySandbox
```

### 🗑️ [상황 4] 치명적 구버전(레거시) 클래스 강제 삭제가 꼬일 때
종종 `SecurityGuard`를 지우고 싶은데 트리거에서 참조해서 삭제(Destructive) 배포가 실패하는 꼬임 현상이 발생합니다.
* **해결책**:
  1. `SecurityGuard`의 클래스 내용을 싹 비우고 껍데기만 남긴(`public class SecurityGuard {}`) 코드를 1차로 로컬에서 Push 합니다. (의존성 끊기)
  2. 그런 다음 정상적으로 파괴 배포(`destructiveChanges.xml`)를 돌리면 말끔하게 지워집니다.

---
[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
