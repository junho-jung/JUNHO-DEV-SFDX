# 🛡️ Security SOAR Framework (Salesforce)

이 프로젝트는 Salesforce Event Monitoring(TxnSecurity)을 기반으로 동작하는 `EM_` 인터셉터 패턴과 `Security*` SOAR (Security Orchestration, Automation, and Response) 프레임워크의 구조를 정의합니다.

방대한 규모의 보안 아키텍처와 시나리오, 개발 메커니즘을 보다 쉽게 읽을 수 있도록 각 목적별로 **독립된 문서(Document)** 로 분리하여 관리하고 있습니다. 아래의 파트별 가이드를 통해 원하시는 상세 내용으로 접근하실 수 있습니다.

---

## 📑 프로젝트 문서 목차 (Documentation Index)

### [⚡ 00. SOAR 프레임워크 퀵 치트 시트 (Quick Cheat Sheet)](reference_docs/00_SOAR_QUICK_CHEAT_SHEET.md)
* **주요 내용**: 개발자와 관리자가 즉각적으로 복사해서 붙여넣을 수 있는 Apex 활용 패턴(정책 검증, 이벤트 발행, 테스트 코드 우회)과 메타데이터 설정 방법을 압축한 핵심 백서입니다.방대한 아키텍처 문서를 읽기 전 가장 먼저 봐야 할 필수 가이드입니다.
* **유용한 대상**: 실무 개발팀, 운영/관리 담당자

### [🎯 01. 기획 파트 (Functional Planning)](reference_docs/01_FUNCTIONAL_PLANNING.md)
* **주요 내용**: 비즈니스 및 보안 운영 담당자가 어떤 위협 시나리오를 방어하고, 정책(Policy)이 어떤 기준으로 자동 대응(Action)하는지 기획적 배경 지식을 설명합니다.
* **유용한 대상**: 프로젝트 매니저, 보안 담당자, 솔루션 아키텍트

### [🏰 02. 설계 파트 (Architecture Design)](reference_docs/02_ARCHITECTURE_DESIGN.md)
* **주요 내용**: 프레임워크의 레이어별 조립(Orchestration) 다이어그램(Mermaid)과 시스템을 런타임에서 유연하게 통제하는 `Custom Metadata Types` 4종의 스키마와 역할(매핑 구조)을 해설합니다.
* **유용한 대상**: 테크니컬 아키텍트, 메타데이터 관리자, 수퍼유저

### [💻 03. 개발 파트 (Technical Development)](reference_docs/03_TECHNICAL_DEVELOPMENT.md)
* **주요 내용**: 백엔드 시스템 심층 코어에서 이벤트가 어떤 클래스 파이프라인(Factory ➞ Executor ➞ Inbound)을 타는지 1단계(이벤트 캡처)부터 4단계(수동 개입)까지 메소드 호출 단위로 추적합니다.
* **유용한 대상**: 백엔드/Apex 개발자, 커스텀 액션 모듈 확장 담당자

### [🎨 04. 디자인 패턴 파트 (Design Patterns)](reference_docs/04_DESIGN_PATTERNS.md)
* **주요 내용**: `EM_` 및 `Security` 프레임워크 내부에서 사용된 6가지 핵심 객체지향 디자인 패턴(Factory, Template Method, Strategy, Interceptor, Pub/Sub, Singleton)의 딥다이브 코드 구조를 해설합니다.
* **유용한 대상**: 시스템 아키텍트, 백엔드/Apex 리드 개발자, 소스 분석 및 리팩토링 담당자

### [🛠️ 05. 리팩토링 제안 파트 (Refactoring Opportunities)](reference_docs/05_REFACTORING_OPPORTUNITIES.md)
* **주요 내용**: 기존 프레임워크 코드의 개방-폐쇄 원칙(OCP)과 다형성(Polymorphism)을 강화하여, 코드를 극단적으로 줄이고 확장성을 높이는 디자인 패턴 기반의 차세대 리팩토링 방향성 3가지를 제안합니다.
* **유용한 대상**: 시스템 아키텍트, 리팩토링 기획 및 구현 담당자

### [⚙️ 06. 외부 구성 및 메타데이터 설계 구조 (External Configurations & Metadata)](reference_docs/06_EXTERNAL_CONFIGURATIONS.md)
* **주요 내용**: 프레임워크의 유연한 확장과 관리를 위한 외부 구성 요소 및 메타데이터(Custom Metadata Types, Custom Settings 등)의 설계 구조와 활용 방안을 설명합니다.
* **유용한 대상**: 메타데이터 관리자, 시스템 관리자, 솔루션 아키텍트

### [❓ 07. 예상 Q&A (Expected Questions & Answers)](reference_docs/07_EXPECTED_QA.md)
* **주요 내용**: SOAR 프레임워크 도입 및 운영 시 예상되는 질문들을 기획/비즈니스 측면과 기술/개발 측면으로 나누어 상세히 답변합니다.
* **유용한 대상**: 프로젝트 도입 검토자, 신규 투입 개발자, 운영 관리자

### [🎤 08. 면접 대비 질의응답 (Interview Preparation Q&A)](reference_docs/08_INTERVIEW_PREPARATION.md)
* **주요 내용**: 프레임워크 설계자/리드 개발자 포지션 면접 시 예상되는 심층 기술 질문과 아키텍처 방어 논리, 꼬리 질문(Follow-up)에 대한 모범 답변을 제공합니다.
* **유용한 대상**: 아키텍트, 기술 면접 준비자

### [🔄 09. 차세대 아키텍처: 이벤트 소싱과 상태 머신 (Event Sourcing & State Machine)](reference_docs/09_EVENT_SOURCING_ARCHITECTURE.md)
* **주요 내용**: 단일 Salesforce Org 내에서의 마이크로서비스(Modular Monolith) 개념을 명확히 정의하고, 현재의 선형 파이프라인 구조를 넘어서는 차세대 '이벤트 소싱 기반 상태 머신' 구조를 기획합니다.
* **유용한 대상**: 시스템 아키텍트, 차세대 프레임워크 설계자

### [🏷️ 10. 네이밍 기스매치 및 역할 불일치 (Naming and Role Mismatches)](reference_docs/10_NAMING_AND_ROLE_MISMATCHES.md)
* **주요 내용**: 초기 설계 의도와 다르게 확장되면서 발생한 클래스 및 커스텀 메타데이터의 '이름과 실제 역할 간의 불일치' 사례를 기술 부채 관점에서 분석하고 변경(Rename) 표적을 제시합니다.
* **유용한 대상**: 리팩토링 담당 개발자, 유지보수 조직

### [📚 11. 전체 컴포넌트 사전 및 네이밍 감사 (Component Dictionary & Audit)](reference_docs/11_COMPONENT_DICTIONARY_AND_AUDIT.md)
* **주요 내용**: 프레임워크를 구성하는 수십 여 개의 모든 Apex 클래스, 인터페이스, 커스텀 오브젝트, 메타데이터를 전수 조사하여 역할과 네이밍의 일치 여부(정상/변경 필요)를 판별한 총망라 인덱스입니다.
* **유용한 대상**: 아키텍트, 전체 시스템 파악이 필요한 신규 개발자

### [🔐 12. 오픈소스를 위한 보안 감사 리포트 (Security Audit for Open Source)](reference_docs/12_SECURITY_AUDIT_FOR_OPENSOURCE.md)
* **주요 내용**: 레파지토리를 외부(GitHub Public 등)에 공개하기 전, 하드코딩된 비밀번호나 내부망 엔드포인트, 민감한 개인정보가 소스 코드에 누출되었는지 검증한 감사 결과 및 조치 권고사항입니다.
* **유용한 대상**: 오픈소스 메인테이너, 관리자

### [📦 13. 독립 프레임워크 추출 가이드 (Standalone Framework Extraction Guide)](reference_docs/13_FRAMEWORK_EXTRACTION_GUIDE.md)
* **주요 내용**: 복합적인 비즈니스 로직(AccountController, PMS 등)이 섞어있는 현재 Org에서 순수하게 SOAR 코어 프레임워크만을 적출하여 새로운 클린 Org(SFDX)로 마이그레이션하기 위한 대상 파일 목록(Rename 규칙 포함)과 이관 절차입니다.
* **유용한 대상**: 프레임워크 퍼블리싱 담당자, 시스템 아키텍트

### [🗺️ 14. 통합 구현 로드맵 및 작업 순서 (Implementation Roadmap)](reference_docs/14_IMPLEMENTATION_ROADMAP.md)
* **주요 내용**: 리팩토링, 네이밍 변경, 컴포넌트 적출, 신규 아키텍처 도입 등 지금까지 작성한 모든 기술 부채 청산 및 개선 작업을 어떤 순서(Phase 1~4)로 안전하게 진행해야 하는지 타임라인을 제시합니다.
* **유용한 대상**: 프로젝트 매니저, 테크니컬 리드 개발자

### [🚀 01. 리팩토링 및 팩토리 확장성 구축 로그 (Tier 1 Refactoring Log)](docs/01_TIER1_REFACTORING_LOG.md)
* **주요 내용**: 05번 문서에서 제안된 Tier 1 우수성 확보 과제(Action Factory, Handler, Publisher 분리 및 패턴 탑재)가 코드 레벨에서 어떻게 구현되었는지 증명하는 완료 리포트입니다.
* **유용한 대상**: 시스템 아키텍트, 코드 검수자

### [💻 15. SFDX (sf) CLI 필수 명령어 가이드 및 치트 시트 (Cheat Sheet)](reference_docs/15_SFDX_CLI_CHEAT_SHEET.md)
* **주요 내용**: 프레임워크 마이그레이션 및 패키징에 필요한 핵심 SFDX(`sf`) CLI 명령어 모음집 및 특수 상황(트리거 꼬임 해결 등)의 해결책을 담은 백서입니다.
* **유용한 대상**: 배포 담당자, 전체 개발자

### [✅ 16. 신규 기능 추가(확장성) 완벽 검증 시뮬레이션 (Extensibility Verification)](reference_docs/16_EXTENSIBILITY_VERIFICATION.md)
* **주요 내용**: 리팩토링 후 OCP(개방-폐쇄 원칙)가 완벽히 적용됨을 증명하기 위해, 신규 액션(ERP 잠금)을 추가할 때 기존 프레임워크 클래스의 수정이 어떻게 0건으로 제어되는가에 대한 엔드-투-엔드 시뮬레이션 리포트입니다.
* **유용한 대상**: 시스템 아키텍트, 프레임워크 도입 검열자

### [🌟 17. 궁극의 확장성: Zero-Code 정책 및 액션 등록 (Tier 3 Refactoring)](reference_docs/17_ZERO_CODE_EXTENSIBILITY_DESIGN.md)
* **주요 내용**: OCP 팩토리를 넘어, 관리자가 **동적 룰(조건 판단 엔진)** 과 **JSON 페이로드 템플릿**을 메타데이터에 입력하는 것만으로 신규 정책(Policy)과 외부 API 연동(Action)을 개발자 0명으로 완성하는 Tier 3 노코드 아키텍처를 제시합니다.
* **유용한 대상**: 아키텍트 리더, CTO, 보안 운영 총괄

### [📦 18. 패키징 스코프와 코드 가시성 제어 (Package Scope & Visibility)](reference_docs/18_PACKAGE_SCOPE_AND_VISIBILITY.md)
* **주요 내용**: SOAR 프레임워크를 외부 파트너/고객사에 배포(AppExchange ISV 등)할 때 핵심 엔진 소스코드를 어떻게 블랙박스(Hidden) 처리하고, 어떻게 `global` 접근 제어자로 커스텀 액션 확장 로직만 오픈할 수 있는지 패키지 배포 구조를 해설합니다.
* **유용한 대상**: 솔루션 배포 담당자, ISV 아키텍트

### [🧩 19. 모듈형 패키지 분리 가이드 (Modular Packaging & Dependency)](reference_docs/19_MODULAR_PACKAGING_STRATEGY.md)
* **주요 내용**: 전체 소스 코드를 단일 덩어리(Monolithic)가 아닌, 공통 API 통신 뼈대인 `Base-Interface` 패키지와 보안 특화 `Security-SOAR` 패키지로 수평 분할(Split)하고 `sfdx-project.json`으로 의존성을 주입하는 모듈형 아키텍처 전략을 다룹니다.
* **유용한 대상**: 시스템 아키텍트, 배포 관리자, 테크 리드

### [🛠️ 20. 패키지 설치 후 필수 설정 가이드 (Post-Install Configuration)](reference_docs/20_POST_INSTALL_CONFIGURATION_GUIDE.md)
* **주요 내용**: 패키지에 포함되지 않는 도메인 인증(Named Credentials), 아웃바운드 허용(Remote Site Settings) 및 인바운드 웹훅 수신용 공개 포트(Public Site) 설정 가이드를 제공합니다.
* **유용한 대상**: 시스템 관리자, 배포 스페셜리스트

---

## 🚀 빠른 시작 (Quick Start)

SOAR 프레임워크는 배포 시 기본 설정으로 구성된 메타데이터를 포함하고 있습니다.
1. Salesforce 조직에 본 패키지를 배포(Deploy)합니다.
2. `SecurityPolicy__mdt` 메타데이터에 진입하여 활성화된 시나리오와 Threshold 임계치를 조직 환경에 맞게 조정합니다.
3. Event Monitoring 대시보드 또는 LWC 보안 대시보드에서 `SecurityActionLog__c` 가 트레이스 되는 것을 확인합니다.
