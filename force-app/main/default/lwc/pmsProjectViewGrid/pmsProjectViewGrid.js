/**
 * @Author            : jh.jung
 * @Description     :
 * @Target            :
 * @Modification Log
 Ver      Date            Author           Modification
 ===================================================================================
 1.0      2026-01-06      jh.jung           Created
 1.1      2026-01-27      jh.jung           Refactoring / Commenting
 */

import { LightningElement, api, track } from 'lwc';
import AddMemberModal from 'c/pmsProjectViewAddMemberModal';

/**
 * @description 프로젝트별/멤버별 리소스 공수(M/M)를 관리하는 그리드 컴포넌트
 * @features 스마트 동기화(계약=실제), 입력값 정제, 소수점 오차 방지, 수동 수정 이력 관리
 */
export default class PmsProjectViewGrid extends LightningElement {

  // -------------------------------------------------------------------------
  // [1] Properties & State: 외부 데이터 및 내부 상태 관리
  // -------------------------------------------------------------------------

  _allocations = [];

  /** @description 부모로부터 전달받는 원본 할당 데이터 리스트 */
  @api
  get allocations() { return this._allocations; }
  set allocations(value) { this._allocations = value ? [...value] : []; }

  @api currentHalf;      // 조회 기간 구분 (상/하반기)
  @api isReadOnly;       // 전체 그리드 수정 가능 여부
  @api draftValues = {}; // 부모 Dashboard가 들고 있는 수정 중인 데이터 (최종 진실)
  @api currentYear;      // 현재 조회 연도

  /** @description 효율적인 데이터 접근을 위한 Map 구조 */
  cellMap = new Map();   // CompositeKey -> 해당 월의 셀 데이터 (판단 로직용)
  memberMap = new Map(); // pmKey -> 멤버 정보 (행 단위 렌더링용)

  /** * @description [핵심 상태] 타이핑 중인 미확정 문자열 및 수동 수정 상태 기록
   * - @track: Map 내부의 값 변화를 감지하여 UI를 업데이트함
   * - _isManual: 실제공수를 직접 건드린 셀을 식별하여 '동기화'를 영구 해제함
   */
  @track inputCache = new Map();

  // -------------------------------------------------------------------------
  // [2] Getters: UI 렌더링 및 구조 결정을 위한 계산된 속성
  // -------------------------------------------------------------------------

  /** @description 현재 반기에 따라 화면에 노출할 월 배열 (H1: 1~12, H2: 1~6) */
  get monthNums() {
    return this.currentHalf === 'H1' ? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] : [1, 2, 3, 4, 5, 6];
  }

  /** @description 그리드 상단 헤더에 표시될 월 라벨 배열 */
  get monthLabels() {
    return this.monthNums.map(m => `${m}월`);
  }

  /** * @description [데이터 관제탑] 원본 배열을 UI용 트리 구조로 변환하는 메인 로직
   * 1) 트리 확보 2) 셀 상태 결정 3) 소계 합산 4) UI 최종 변환 순으로 진행
   */
  get formattedData() {
    if (!this._allocations?.length) return [];

    const projectMap = {}; // 프로젝트별 그룹화 저장소
    this.cellMap.clear();
    this.memberMap.clear();

    this._allocations.forEach(item => {
      const month = item.Month;
      if (!this.monthNums.includes(month)) return; // 화면 표시 범위 외 월 필터링

      const pmKey = this.extractPmKey(item.CompositeKey);
      const cKey = item.CompositeKey;

      // 1. 트리 구조 확보 (Project -> Member)
      const proj = this.initializeProject(projectMap, item);
      const member = this.initializeMember(proj, item, pmKey);

      // 2. 셀의 최종 데이터 및 동기화 활성화 여부 계산
      const cellData = this.calculateCellState(item, cKey);

      // 3. 빠른 검색을 위해 Map에 등록 및 멤버 객체에 할당
      this.cellMap.set(cKey, cellData);
      member.monthly[month] = cellData;

      // 4. 월별 하단 소계(Totals) 누적 계산
      this.accumulateTotals(proj, cellData, month);
    });

    // 5. 취소선 클래스 및 캐시 우선순위가 반영된 최종 배열 반환
    return this.finalizeProjectData(projectMap);
  }

  // -------------------------------------------------------------------------
  // [3] Event Handlers: 사용자 입력 및 인터랙션 제어
  // -------------------------------------------------------------------------

  /** @description 인풋 포커스 시 텍스트 전체 선택 (기존 '0'을 즉시 덮어쓰기 위해) */
  handleInputClick(event) {
    event.target.select();
  }

  /** @description 입력값 실시간 정제 및 부모 전송, 스마트 동기화 수행 */
  handleInputChange(event) {
    const { key, type } = event.target.dataset;
    const rawValue = this.validateAndCleanInput(event.target.value);

    event.target.value = rawValue; // 정제된 값으로 화면 Input 강제 보정

    // 1. 실제공수(Actual)를 직접 수정했다면, 동기화 해제 증표(_isManual) 남김
    if (type === 'actual') {
      this.inputCache.set(`${key}_isManual`, true);
    }

    // 2. 현재 입력값을 캐싱하고 부모 Dashboard로 전송
    this.updateValue(`${key}_${type}`, rawValue);

    // 3. 스마트 동기화: 계약 수정 시 조건에 맞으면 실제공수도 자동 변경
    if (type === 'contract') {
      this.handleSmartSync(key, rawValue);
    }

    this.refreshCache(); // 반응형 업데이트 트리거
  }

  /** @description 포커스 아웃 시 임시 캐시(문자열 상태)를 삭제하고 데이터 정제 */
  handleBlur(event) {
    const { key, type } = event.target.dataset;
    const cacheKey = `${key}_${type}`;

    // 마침표만 있거나 빈 값으로 나갈 경우 0으로 보정하여 부모에 전송
    if (!event.target.value?.trim() || event.target.value === '.') {
      this.dispatchDashboardAction('CELL_UPDATE', { draftKey: cacheKey, value: 0 });
    }

    // 입력 중이던 임시 값만 캐시에서 삭제 (수동 수정 증표는 유지)
    this.inputCache.delete(cacheKey);
    if (type === 'contract') this.inputCache.delete(`${key}_actual`);
    this.refreshCache();
  }

  /** @description 키보드 입력 제어 및 방향키(Step) 가감 처리 */
  handleKeyDown(event) {
    if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
      event.preventDefault();
      this.processStepChange(event);
    } else if (!this.isKeyAllowed(event)) {
      event.preventDefault(); // 허용되지 않은 문자(문자열 등) 원천 차단
    }
  }

  // -------------------------------------------------------------------------
  // [4] 핵심 비즈니스 로직 헬퍼 (FormattedData 용)
  // -------------------------------------------------------------------------

  /** @description CompositeKey(OppId_Stamp_Month)에서 멤버 식별 키만 추출 */
  extractPmKey(cKey) {
    return cKey.substring(0, cKey.lastIndexOf('_'));
  }

  /** @description 프로젝트 그룹이 없으면 생성하여 트리 구조 확보 */
  initializeProject(map, item) {
    if (!map[item.ProjectId]) {
      map[item.ProjectId] = {
        id: item.ProjectId,
        name: item.ProjectName,
        members: {},
        monthlyTotals: this.monthNums.map(m => ({ month: m, contractTotal: 0, actualTotal: 0 })),
      };
    }
    return map[item.ProjectId];
  }

  /** @description 멤버 행(Row)이 없으면 생성하고 멤버 맵에 등록 */
  initializeMember(proj, item, pmKey) {
    if (!proj.members[pmKey]) {
      proj.members[pmKey] = {
        pmKey, pmId: item.ProjectMemberId, memberId: item.MemberId,
        name: item.MemberName, role: item.Role, team: item.TeamName,
        grade: item.Grade, isDeleted: item.isDeleted, monthly: {},
      };
      this.memberMap.set(pmKey, proj.members[pmKey]);
    }
    return proj.members[pmKey];
  }

  /** @description 셀의 표시 데이터 결정 (Draft 우선) 및 동기화 가능 상태 판단 */
  calculateCellState(item, cKey) {
    const dC = this.draftValues[`${cKey}_contract`];
    const dA = this.draftValues[`${cKey}_actual`];

    // 캐시에 수동 수정 기록(_isManual)이 있는지 확인하여 동기화 여부 결정
    const isManualBreak = this.inputCache.has(`${cKey}_isManual`);

    return {
      compositeKey: cKey,
      contract: dC ?? item.ContractMM, // 수정 중인 값이 있으면 그것을 표시
      actual: dA ?? item.ActualMM,     // 수정 중인 값이 있으면 그것을 표시
      isDirty: dC !== undefined || dA !== undefined,
      // 동기화 조건: 초기 DB 값이 동일하고 사용자가 실제공수를 직접 건드리지 않았을 때
      isSyncEnabled: (item.ActualMM === item.ContractMM) && !isManualBreak,
    };
  }

  /** @description JS 부동 소수점 오차 방지를 위해 정수 변환 후 소계 합산 */
  accumulateTotals(proj, cellData, month) {
    const idx = this.monthNums.indexOf(month);
    if (idx === -1) return;

    const totals = proj.monthlyTotals[idx];
    const cVal = cellData.contract || 0;
    const aVal = cellData.actual || 0;

    // 0.1 + 0.2 문제를 해결하기 위해 100을 곱해 반올림 처리
    totals.contractTotal = Math.round((totals.contractTotal + cVal) * 100) / 100;
    totals.actualTotal = Math.round((totals.actualTotal + aVal) * 100) / 100;
  }

  // -------------------------------------------------------------------------
  // [5] 입력 처리 및 통신 헬퍼
  // -------------------------------------------------------------------------

  /** @description 개별 셀의 값을 캐시에 담고 부모 Dashboard에 데이터 업데이트 요청 */
  updateValue(cacheKey, rawValue) {
    this.inputCache.set(cacheKey, rawValue);
    const numValue = parseFloat(rawValue) || 0;
    this.dispatchDashboardAction('CELL_UPDATE', { draftKey: cacheKey, value: numValue });
  }

  /** @description 계약 변경 시 동기화 조건 만족 시 실제공수 셀도 함께 업데이트 */
  handleSmartSync(key, rawValue) {
    const targetCell = this.findCellByKey(key);
    const isManual = this.inputCache.has(`${key}_isManual`);

    if (targetCell?.isSyncEnabled && !isManual) {
      this.updateValue(`${key}_actual`, rawValue);

      // LWC의 비동기 렌더링을 기다리지 않고 즉시 실제공수 인풋 DOM의 value 보정
      const actualInput = this.template.querySelector(`input[data-key="${key}"][data-type="actual"]`);
      if (actualInput) actualInput.value = rawValue;
    }
  }

  /** @description @track이 선언된 Map의 참조 주소를 바꿔 LWC 리렌더링 트리거 */
  refreshCache() {
    this.inputCache = new Map(this.inputCache);
  }

  /** @description 입력 허용 키 검사 (숫자, 소수점, 제어키) */
  isKeyAllowed(event) {
    const allowed = ['Backspace', 'Delete', 'Tab', 'Escape', 'Enter', 'ArrowLeft', 'ArrowRight', '.'];
    return /^[0-9]$/.test(event.key) || allowed.includes(event.key);
  }

  /** @description DashboardAction 커스텀 이벤트를 발생시켜 부모와 통신 */
  dispatchDashboardAction(type, payload) {
    this.dispatchEvent(new CustomEvent('dashboardaction', {
      detail: { type, payload }, bubbles: true, composed: true
    }));
  }

  // -------------------------------------------------------------------------
  // [6] 유틸리티: 문자열 정제 및 데이터 매핑
  // -------------------------------------------------------------------------

  /** * @description 입력 문자열 강력 정제 규칙:
   * 1) 50->5 등 불필요한 0 제거 2) 1.0 초과 방지 3) 소수점 첫째자리 제한 4) 3글자 제한
   */
  validateAndCleanInput(val) {
    let clean = val.replace(/[^0-9.]/g, ''); // 숫자/마침표 외 제거

    // 선행 0 처리: 05 -> 5 (커서 앞에 5를 넣었을 때 50이 되는 것 방지)
    if (clean.length > 1 && clean.startsWith('0') && clean[1] !== '.') {
      clean = clean.substring(1);
    }

    // 1.0 초과 방지: 첫 자리가 2~9면 즉시 1로 고정
    if (clean.length > 0 && !['0', '1', '.'].includes(clean[0])) {
      clean = '1';
    }

    // 1 뒤에 숫자가 오면 소수점 입력 유도: 12 -> 1.
    if (clean.length > 1 && clean.startsWith('1') && clean[1] !== '.') {
      clean = '1.';
    }

    const parts = clean.split('.');
    if (parts.length > 2) clean = parts[0] + '.' + parts[1]; // 소수점 중복 방지
    if (parts.length === 2 && parts[1].length > 1) clean = parts[0] + '.' + parts[1].substring(0, 1);

    return clean.length > 3 ? clean.substring(0, 3) : clean;
  }

  /** @description 트리 구조의 맵을 최종 UI용 배열로 변환 (CSS 클래스 및 캐시값 최종 매핑) */
  finalizeProjectData(projectMap) {
    return Object.values(projectMap).map(p => ({
      ...p,
      memberList: Object.values(p.members)
        .filter(m => m.memberId !== 'NONE')
        .map(m => ({
          ...m,
          rowClass: m.isDeleted ? 'row-deleted' : '',
          nameWrapperClass: m.isDeleted ? 'name-strikethrough' : '',
          cells: this.monthNums.map(n => {
            const cell = m.monthly[n] || { contract: 0, actual: 0 };
            return {
              ...cell,
              // 입력 중인 임시 캐시가 있다면 그것을 우선 표시 (0. 등을 보존하기 위해)
              contract: this.inputCache.get(`${cell.compositeKey}_contract`) ?? cell.contract,
              actual: this.inputCache.get(`${cell.compositeKey}_actual`) ?? cell.actual,
              month: n,
              isReadOnly: this.isReadOnly || m.isDeleted
            };
          })
        })),
      monthlyTotals: p.monthlyTotals.map(t => ({
        ...t,
        contractTotal: t.contractTotal.toFixed(1), // 합계는 소수점 한자리 고정 표시
        actualTotal: t.actualTotal.toFixed(1)
      }))
    }));
  }

  /** @description 방향키 조작 시 0.1 단위 가감 (정밀도 유지) */
  processStepChange(event) {
    let val = parseFloat(event.target.value) || 0;
    const step = 0.1;
    val = event.key === 'ArrowUp'
      ? Math.min(1, parseFloat((val + step).toFixed(1)))
      : Math.max(0, parseFloat((val - step).toFixed(1)));

    event.target.value = val;
    this.handleInputChange(event);
  }

  findCellByKey(key) { return this.cellMap.get(key) || null; }
  findMemberByKey(pmKey) { return this.memberMap.get(pmKey) || null; }

  // -------------------------------------------------------------------------
  // [7] 모달 및 외부 인터랙션
  // -------------------------------------------------------------------------

  /** @description 멤버 추가 모달 오픈 */
  async handleAddMemberClick(event) {
    const { projectId, projectName } = event.target.dataset;
    const result = await AddMemberModal.open({
      size: 'large',
      projectId: projectId,
      projectName: projectName,
      currentYear: this.currentYear,
    });
    if (result?.status === 'success') this.dispatchDashboardAction('MEMBER_ADD', result.payload);
  }

  /** @description 기존 멤버 클릭 시 교체(Swap) 모달 오픈 */
  async handleMemberClick(event) {
    const { pmKey, projectId, projectName } = event.currentTarget.dataset;
    const member = this.findMemberByKey(pmKey);
    if (!member) return;

    const result = await AddMemberModal.open({
      size: 'large',
      projectId: projectId,
      projectName: projectName,
      currentYear: this.currentYear,
      isSwapMode: true,
      oldPmKey: pmKey,
      pmName: member.name,
      oldRole: member.role,
      oldGrade: member.grade,
      oldEmployeeId: member.memberId
    });
    if (result?.status === 'success') this.dispatchDashboardAction('MEMBER_SWAP', { ...result.payload, oldPmKey: pmKey });
  }

  /** @description 멤버 삭제 예약 처리 (취소선 발생) */
  handleDeleteMemberClick(event) {
    const { pmKey, projectId } = event.target.dataset;
    if (confirm('이 멤버를 프로젝트에서 제외하시겠습니까?\n(저장 버튼을 눌러야 최종 반영됩니다.)')) {
      this.dispatchDashboardAction('MEMBER_DELETE', { pmKey, projectId });
    }
  }

  /** @description 삭제 예약된 멤버 복구 */
  handleRestoreMemberClick(event) {
    const { pmKey, projectId } = event.target.dataset;
    this.dispatchDashboardAction('MEMBER_RESTORE', { pmKey, projectId });
  }
}