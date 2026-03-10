# 🎯 01. 기획 파트 (Functional Planning)

본 문서는 Security SOAR 프레임워크가 **비즈니스와 보안 운영 측면에서 어떤 위협을 방어하고, 어떻게 반응하도록 설계되었는지** 기획적 맥락을 설명합니다.

---

## 1. SOAR 프레임워크 도입 배경

기존 시스템 환경에서는 의심스러운 행위(예: 대량의 데이터 엑스포트, 비정상적인 새벽 시간대 접근)가 발생했을 때, 사후 관리자 감사(Audit)에 의존하여 실시간 차단이나 능동적인 전파가 어려웠습니다. SOAR(Security Orchestration, Automation, and Response) 프레임워크는 이를 해결하기 위해 다음 세 가지 목표를 가집니다.

1. **Orchestration (조정):** Salesforce Event Monitoring을 통해 여러 보안 이벤트를 하나의 파이프라인으로 모읍니다.
2. **Automation (자동화):** 사전에 정의된 임계치(Threshold)와 룰렛(Policy)에 따라 사람의 개입 없이 즉각적으로 세션 킬, 계정 동결 등의 조치를 취합니다.
3. **Response (대응):** 슬랙(Slack), 팀즈(Teams), SIEM 시스템 등 기업 보안 생태계로 경고를 전파하여 사후 대응을 돕습니다.

---

## 2. 위협 탐지 시나리오 (Threat Scenarios)

어떤 행위가 시스템에서 보안 위협으로 간주되는지, 그 위험도와 방어 목적을 정의합니다.

| 분류 | 위협 시나리오 | 탐지 조건 (Trigger Condition) | 위험도 (Severity) | 방어 목적 (Objective) |
|---|---|---|---|---|
| **권한 상승** | 해커의 권한 상승 시도 (Privilege Escalation) | 비관리자 유저가 `PermissionSet`, `Profile` 등의 시스템 메타데이터 쿼리 시도 | `CRITICAL` | 시스템 권한 탈취 및 횡적 이동 차단 |
| **데이터 유출** | 대량 데이터 엑스포트 (Mass Data Leakage) | `ReportEvent`에서 1,000건 이상의 데이터 Export 시도 | `CRITICAL` | 대규모 고객/영업 데이터 외부 유출 즉시 차단 |
| **정보 탈취** | 심야의 데이터 탈취 (Midnight Data Heist) | 영업/서비스 사원이 심야 시간대(Off-Hours)에 100건 이상의 API 대량 열람 시도 | `HIGH` | 퇴사 의심자 혹은 해킹된 계정의 업무 외 시간 악용 통제 |
| **민감 정보** | VIP 기밀 데이터 스니핑 (VIP Sneak Peek) | `ListView` 또는 `Report` 이름에 '임원', '기밀' 등 포함 시, 또는 중소규모(100~999건) Export 시 | `HIGH` | 기밀 데이터 열람 전 추가 본인 인증(MFA)으로 합법성 검증 |
| **이상 행위** | 은밀한 문서 호더 (The Hoarder) | 차단 기준을 넘지 않는 잦은 파일 다운로드나 민감도가 낮은 일반 데이터 열람 | `LOW` | 즉각 차단 없이 섀도우 모니터링하여 대시보드에서 이상 징후 파악 |

---

## 3. 보안 정책 및 자동 조치 사항 (Policies & Actions)

탐지된 위협 시나리오별로(Policy Code 기준) 시스템이 자동으로 수행하거나 보안팀에 알림을 보내는 조치 사항들입니다. 이 정책들은 소스 코드가 아닌 *관리자 메타데이터*로 유연하게 제어됩니다.

| 정책 코드 (Policy Code) | 매핑된 위협 시나리오 | 동작 방식 (Actions) | 비고 |
|---|---|---|---|
| `PRIVILEGE_ESCALATION` | 권한 상승 | 1. **슬랙 알림 발송** (`NOTIFY_SLACK`)<br>2. **세션 강제 종료** (`KILL_SESSION`)<br>3. **프로필 격리** (`QUARANTINE_PROFILE`) | 최고 수준의 격리 방어. 해커가 더 이상 시스템에 머물지 못하게 즉시 쫓아냅니다. |
| `MASS_DATA_EXPORT` | 데이터 유출 | 1. **데이터 유출 알림** (`NOTIFY_TEAMS`)<br>2. **외부 SIEM 전송** (`SEND_TO_SIEM`)<br>3. (필요 시) 보안 Case 생성 (`CREATE_CASE`) | 데이터 유출 사실을 조직 내 전파하고 기업 보안 관제망에 사고를 기록합니다. |
| `VIP_DATA_ACCESS` | 민감 정보 | 1. **다팩터 인증 유도** (MFA 팝업 조치)<br>2. **MFA 실패 시 이메일 알림** (`NOTIFY_MANAGER`) | 정상적인 업무 목적인지 관리자 개입 전 1차적으로 사용자 본인에게 증명을 요구합니다. |
| `REPORT_MONITORING` | 이상 행위 | - 별도 즉각 조치 없음<br>- 내부적으로 이벤트 카운트 누적 로깅 (`Trace Log`) | 며칠 동안 누적된 `LOW` 이벤트를 종합 분석하여 추후 수동 동결 조치 여부를 판단합니다. |

---

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
