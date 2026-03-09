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

import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/** Apex Methods */
import getInitMetadata from '@salesforce/apex/PMS_ResourceManagementController.getInitMetadata';
import getProjectOptions from '@salesforce/apex/PMS_ResourceManagementController.getProjectOptions';
import getDepartmentOptions from '@salesforce/apex/PMS_ResourceManagementController.getDepartmentOptions';
import getAllocations from '@salesforce/apex/PMS_ResourceManagementController.getAllocations';
import saveAllChanges from '@salesforce/apex/PMS_ResourceManagementController.saveAllChanges';

export default class PmsResourceDashboard extends LightningElement {

  //-------------------------------------------------------------------------
  // [1] State & UI 제어 변수
  //-------------------------------------------------------------------------
  @track viewMode = 'team';         // 'team', 'project', 'teamRollup'
  @track projectMode = 'read';       // 'read', 'edit'
  @track isLoading = false;

  //-------------------------------------------------------------------------
  // [2] 데이터 저장소
  //-------------------------------------------------------------------------
  @track originalData = [];          // 서버에서 로드된 실시간 MM 데이터 (그리드 원본)
  @track buSummaryData = [];         // 본부 전체 가동률 요약 데이터 (상단 대시보드용)
  @track draftValues = {};              // 사용자 수정 MM 값 (Key: CompositeKey_Field)
  @track selectedProjectIds = [];    // 선택된 프로젝트 ID 리스트
  @track deletedMemberIds = [];      // 삭제(Soft Delete) 예정인 멤버 ID 리스트

  //-------------------------------------------------------------------------
  // [3] 필터 옵션 및 선택값
  //-------------------------------------------------------------------------
  @track yearOptions = [];
  @track probabilityOptions = [];
  @track divisionOptions = [];
  @track businessUnitOptions = [];
  @track teamOptions = [];

  selectedYear;
  selectedProbability = 'ALL';
  selectedDivision;
  selectedBusinessUnit;
  selectedTeam;
  selectedHalf = 'H1';

  // 데이터 로딩 시퀀스 제어용 플래그
  isInitialDataLoaded = false;

  //-------------------------------------------------------------------------
  // [4] Wire Service (Initial Data Loading)
  //-------------------------------------------------------------------------

  /** 1. 통합 메타데이터 로드: 연도, 확도, 최상위 부서 옵션을 한 번에 가져옴 */
  @wire(getInitMetadata)
  wiredMeta({ error, data }) {
    if (data) {
      this.yearOptions = data.years;
      // this.probabilityOptions = [{ label: '전체', value: 'ALL' }, ...data.probabilities];
      this.probabilityOptions = data.probabilities;
      this.divisionOptions = data.divisions;

      // 초기 기본값 세팅 (2025년 및 첫 번째 본부)
      this.selectedYear = '2025';
      this.selectedProbability = 'ALL'
      this.selectedDivision = data.divisions[0]?.value;

      // 계층형 부서 필터 연쇄 조회 시작 (Division -> BU -> Team)
      this.updateFilterCascade('division', this.selectedDivision);
    } else if (error) {
      this.showToast('Error', '메타데이터 로드 실패', 'error');
    }
  }

  /** 2. 프로젝트 목록 조회: 연도 또는 확도 변경 시 리액티브하게 호출 */
  @wire(getProjectOptions, { year: '$selectedYear', probability: '$selectedProbability' })
  wiredProjs({ error, data }) {
    if (data) {
      this.resetEditState(); // 목록 변경 시 편집 내용 초기화
      this.rawProjectOptions = data;
      this.validateSelectedProjects();

      // 연도, 수주확도 변경시 데이터 점검
      this.fetchData();
    } else if (error) {
      this.showToast('Error', '기회 목록 로드 실패', 'error');
    }
  }

  //-------------------------------------------------------------------------
  // [5] Getters (Computed Properties)
  //-------------------------------------------------------------------------

  get isTeamView()        { return this.viewMode === 'team'; }
  get isProjectView()     { return this.viewMode === 'project'; }
  get isTeamRollupView()  { return this.viewMode === 'teamRollup'; }
  get showTeamRelatedView()       { return this.viewMode === 'team' || this.viewMode === 'teamRollup'; }
  get isReadOnlyMode()    { return this.projectMode === 'read'; }
  get showEditActions()           { return this.isProjectView && this.projectMode === 'edit'; }
  get viewModeVariant()     { return this.projectMode === 'read' ? 'brand' : 'neutral'; }
  get editModeVariant()     { return this.projectMode === 'edit' ? 'brand' : 'neutral'; }
  get projectLabel()        { return this.selectedProjectIds.length > 0 ? `프로젝트 (${this.selectedProjectIds.length})` : '프로젝트 선택'; }

  // get projectOptions() {
  //   return this.rawProjectOptions.map(opt => ({
  //     ...opt,
  //     checked: this.selectedProjectIds.includes(opt.value)
  //   }));
  // }

  get projectOptions() {
    if (!this.rawProjectOptions) return [];

    return this.rawProjectOptions
      .map((opt, index) => ({
        ...opt,
        checked: this.selectedProjectIds.includes(opt.value),
        originalIndex: index
      }))
      .sort((a, b) => {
        // 1. 체크된 항목을 최상단으로
        if (a.checked && !b.checked) return -1;
        if (!a.checked && b.checked) return 1;

        // 2. 체크 상태가 같다면 Apex가 준 원래 순서(originalIndex)대로 정렬
        return a.originalIndex - b.originalIndex;
      });
  }

  /** 변경사항 존재 여부 (저장/취소 버튼 활성화 제어) */
  get isDirty() {
    const hasDrafts = Object.keys(this.draftValues).length > 0;
    const hasDeletes = this.deletedMemberIds.length > 0;
    const hasAdditions = this.originalData.some(item => !item.ProjectMemberId && item.MemberId !== 'NONE' && !item.isDeleted);
    return hasDrafts || hasDeletes || hasAdditions;
  }

  /** 가동률 프로그래스바 */
  //** 1. 본부 전체 단순 가동률 (ActualMM 합계) */
  get totalUtilization() {
    return this.calculateUtil('ActualMM');
  }

  /** 2. 본부 전체 가중 가동률 (Fm_WeightedActualMM 합계) */
  get weightedUtilization() {
    return this.calculateUtil('WeightedActualMM');
  }

  /** 공통 계산 헬퍼 */
  calculateUtil(fieldKey) {
    if (this.buSummaryData.length === 0) return 0;

    const totalMM = this.buSummaryData.reduce((sum, item) => {
      if (item.isDeleted) return sum;
      return sum + (item[fieldKey] || 0);
    }, 0);

    const totalMembers = new Set(
      this.buSummaryData
        .filter(item => item.MemberId && item.MemberId !== 'NONE')
        .map(item => item.MemberId)
    ).size;

    if (totalMembers === 0) return 0;
    const rawUtilization = (totalMM / (totalMembers * 12)) * 100;

    // 소수점 1자리까지 반올림
    return Math.round(rawUtilization * 10) / 10;
  }

  /** 프로그래스바 스타일 */
  get totalProgressStyle() {
    return `width: ${this.totalUtilization}%; background: #0070d2;`;
  }

  get weightedProgressStyle() {
    return `width: ${this.weightedUtilization}%; background: #2ecc71;`;
  }

  get selectedBusinessUnitLabel() {
    const found = this.businessUnitOptions.find(opt => opt.value === this.selectedBusinessUnit);
    const buName = found ? found.label : '';

    // 연도와 본부명을 결합 (예: 2025년 솔루션사업실)
    return this.selectedYear ? `${this.selectedYear}년 ${buName}` : buName;
  }

  //-------------------------------------------------------------------------
  // [6] Filter & Mode Event Handlers
  //-------------------------------------------------------------------------

  /** 탭 전환: 모드 초기화 및 데이터 재조회 */
  handleTabActive(event) {
    if (this.projectMode === 'edit' && this.isDirty) {
      if (!confirm('수정 중인 내용이 초기화됩니다. 계속하시겠습니까?')) return;
      this.resetEditState();
    }
    this.viewMode = event.target.value;
    this.projectMode = 'read';

    // 유효성 검사 및 기본값 세팅 통합 호출
    if (this.isProjectView) { this.validateSelectedProjects(); }
    this.fetchData();
  }

  /** 통합 필터 변경: 연쇄 필터 적용 및 데이터 로드 */
  async handleFilterChange(event) {
    const { name } = event.target.dataset;
    const { value } = event.detail;

    if (this.projectMode === 'edit' && this.isDirty) {
      if (!confirm('수정 중인 데이터가 초기화됩니다. 계속하시겠습니까?')) {
        const combo = this.template.querySelector(`lightning-combobox[data-name="${name}"]`);
        if (combo) { combo.value = this.getPreviousValue(name); }
        return;
      }
      this.resetEditState();
    }

    try {
      await this.updateFilterCascade(name, value); // 연쇄 옵션 업데이트 대기
      // 연도, 수주확도는 wire에서 처리
      if (name !== 'year' && name !== 'probability') {
        await this.fetchData(); // 필터 완성 후 데이터 호출
      }
    } catch (e) {
      console.error(e);
      this.isLoading = false;
    }
  }

  /** 부서 계층형 필터 연쇄 업데이트 로직 */
  async updateFilterCascade(name, value) {
    if (!value) return;

    switch (name) {

      case 'division':
        this.selectedDivision = value;
        this.businessUnitOptions = await getDepartmentOptions({ parentDeptId: value, includeAll: false });
        this.selectedBusinessUnit = this.businessUnitOptions[0]?.value || '';
        await this.updateFilterCascade('businessUnit', this.selectedBusinessUnit);
        break;

      case 'businessUnit':
        this.selectedBusinessUnit = value;
        this.buSummaryData = []; // 본부 변경 시 요약 캐시 리셋
        // const teams = await getDepartmentOptions({ parentDeptId: value, includeAll: true });
        // this.teamOptions = teams.length > 0 ? [{ label: '전체', value: value }, ...teams] : [];
        this.teamOptions = await getDepartmentOptions({ parentDeptId: value, includeAll: true });
        this.selectedTeam = value;

        // 최초 로드 시점
        if (!this.isInitialDataLoaded) {
          this.isInitialDataLoaded = true;
          this.fetchData();
        }
        break;

      case 'year':
        this.buSummaryData = []; // 연도가 바뀌면 요약 캐시 초기화
        // this.selectedProjectIds = []; // 선택값 초기화
        this.selectedYear = value;
        break;

      case 'team':
        this.selectedTeam = value;
        break;

      case 'probability':
        // this.selectedProjectIds = []; // 선택값 초기화
        this.selectedProbability = value;
        break;

      case 'half':
        this.selectedHalf = value;
        break;
    }
  }

  /** 프로젝트 다중 선택 (CheckBox) */
  handleProjectSelect(event) {
    const val = event.detail.value;
    this.selectedProjectIds = this.selectedProjectIds.includes(val)
      ? this.selectedProjectIds.filter(id => id !== val)
      : [...this.selectedProjectIds, val];
    this.fetchData();
  }

  /** 편집/조회 모드 토글 */
  handleModeChange(event) {
    const newMode = event.target.dataset.mode;
    if (this.projectMode === 'edit' && newMode === 'read' && this.isDirty) {
      if (!confirm('수정 중인 내용이 저장되지 않았습니다. 취소하시겠습니까?')) return;
      this.resetEditState();
      this.fetchData();
    }
    this.projectMode = newMode;
  }

  //-------------------------------------------------------------------------
  // [7] Data Fetching
  //-------------------------------------------------------------------------

  /** 핵심 데이터 조회: 병렬 처리를 통해 요약 데이터와 메인 데이터를 동시 로드 */
  async fetchData() {

    this.originalData = [];

    // 필수 파라미터 방어 로직
    if (!this.selectedYear || !this.selectedBusinessUnit || !this.selectedTeam || !this.selectedProbability) return;
    if (this.isProjectView && this.selectedProjectIds.length === 0) return;

    this.isLoading = true;
    try {
      const promises = [];

      // 1. 본부 요약 (캐시가 비어 있을 때만 조회)
      if (this.buSummaryData.length === 0) {
        promises.push(getAllocations({
          viewMode: 'team',
          teamId: this.selectedBusinessUnit,
          year: this.selectedYear,
          probability: 'ALL'
        }));
      } else {
        promises.push(Promise.resolve(null)); // 순서를 맞추기 위한 빈 값
      }

      // 2. 메인 리스트 데이터
      promises.push(getAllocations({
        viewMode: this.viewMode,
        teamId: this.showTeamRelatedView ? this.selectedTeam : '',
        projectIds: this.isProjectView ? this.selectedProjectIds : [],
        year: this.selectedYear,
        probability: this.selectedProbability,
      }));

      const [summaryResult, mainData] = await Promise.all(promises);

      if (summaryResult) this.buSummaryData = summaryResult;
      this.originalData = mainData;
    } catch (e) {
      console.error('Fetch Data Error:', e);
    } finally {
      this.isLoading = false;
    }
  }

  //-------------------------------------------------------------------------
  // [8] CRUD Actions (Child Component Events)
  //-------------------------------------------------------------------------

  handleDashboardAction(event) {
    const { type, payload } = event.detail;
    if (type === 'CELL_UPDATE')         this.processCellUpdate(payload);
    else if (type === 'MEMBER_ADD')     this.processMemberAdd(payload);
    else if (type === 'MEMBER_DELETE')  this.processMemberDelete(payload);
    else if (type === 'MEMBER_RESTORE') this.processMemberRestore(payload);
    else if (type === 'MEMBER_SWAP')    this.processMemberSwap(payload);
  }

  /** [Update] 셀 MM 값 변경 기록 */
  processCellUpdate(payload) {
    const { draftKey, value } = payload;
    this.draftValues = { ...this.draftValues, [draftKey]: value };
  }

  /** [Create] 가상 행 추가 (신규 멤버) */
  processMemberAdd(payload) {
    const { employeeId, employeeName, projectId, projectName, teamId, teamName, role, isPlaceholder, grade } = payload;

    // 1. 실제 직원 중복 체크 (가배정은 통과)
    if (!isPlaceholder) {
      // isDeleted 상관없이 해당 프로젝트에 해당 멤버가 있는지 확인
      const existingMember = this.originalData.find(item =>
        item.ProjectId === projectId &&
        item.MemberId === employeeId
      );

      if (existingMember) {
        if (existingMember.isDeleted) {
          // 삭제된 상태라면 되돌리기 안내
          this.showToast('안내', `${employeeName}님은 삭제 대기 상태입니다. 되돌리기 버튼(↺)을 이용해 주세요.`, 'info');
        } else {
          // 이미 활성화된 상태라면 중복 안내
          this.showToast('경고', `${employeeName}님은 이미 이 프로젝트에 배정되어 있습니다.`, 'warning');
        }
        return;
      }
    }

    // 2. 고유 키 생성 (가배정은 무조건 새로 생성하므로 위 체크를 타지 않음)
    const typeTag = isPlaceholder ? 'RAND' : 'REAL';
    const uniqueStamp = `${Date.now()}${typeTag}${Math.floor(1000 + Math.random() * 9000)}`;
    const pmKey = `${projectId}_${uniqueStamp}`;

    // 3. 12개월 가상 행 생성
    const newRows = [];
    for (let m = 1; m <= 12; m++) {
      const strMonth = String(m).padStart(2, '0');
      const cKey = `${pmKey}_${this.selectedYear}${strMonth}`;

      newRows.push({
        Id: `virtual_projmem_${cKey}`,
        CompositeKey: cKey,
        MemberId: employeeId,
        MemberName: employeeName,
        ProjectId: projectId,
        ProjectName: projectName,
        TeamId: teamId,
        TeamName: teamName,
        Year: this.selectedYear,
        Month: m,
        ContractMM: 0,
        ActualMM: 0,
        Role: role,
        Grade: grade,
        ProjectMemberId: null,
        IsPlaceholder: isPlaceholder,
        isDeleted: false
      });
    }

    this.originalData = [...this.originalData, ...newRows];
  }

  /** [Delete] 멤버 삭제 처리 (플래그 처리로 통일) */
  processMemberDelete(payload) {
    const { pmKey, projectId } = payload;

    this.originalData = this.originalData.map(item => {
      // pmKey 일치 여부 확인 (12개월 전체 행 대상)
      const itemPmKey = item.CompositeKey.substring(0, item.CompositeKey.lastIndexOf('_'));

      if (itemPmKey === pmKey && item.ProjectId === projectId) {

        // DB에 실제 레코드 ID(ProjectMemberId)가 있다면 무조건 삭제 리스트에 추가
        if (item.ProjectMemberId) {
          if (!this.deletedMemberIds.includes(item.ProjectMemberId)) {
            this.deletedMemberIds = [...this.deletedMemberIds, item.ProjectMemberId];
          }
        }

        // 화면에서는 취소선/흐리게 처리
        return { ...item, isDeleted: true };
      }
      return item;
    });
  }

  /** [Restore] 멤버 복구 처리 (플래그 처리로 통일) */
  processMemberRestore(payload) {
    const { pmKey, projectId } = payload;

    const isTarget = (item) =>
      item.CompositeKey.substring(0, item.CompositeKey.lastIndexOf('_')) === pmKey &&
      item.ProjectId === projectId;

    this.originalData = this.originalData.map(item => {
      if (isTarget(item)) {
        // 삭제 대기 리스트(서버 전송용)에서 제외
        if (item.ProjectMemberId) {
          this.deletedMemberIds = this.deletedMemberIds.filter(id => id !== item.ProjectMemberId);
        }
        return { ...item, isDeleted: false };
      }
      return item;
    });
  }

  /** [Swap] 멤버 교체 처리 */
  processMemberSwap(payload) {
    const { oldPmKey, employeeId, employeeName, teamId, teamName, role, jobDesc, grade, isPlaceholder, projectId } = payload;

    // 1. 실제 직원 중복 체크 (가배정은 통과)
    if (!isPlaceholder) {
      // isDeleted 상관없이 해당 프로젝트에 해당 멤버가 있는지 확인
      const existingMember = this.originalData.find(item =>
        item.ProjectId === projectId &&
        item.MemberId === employeeId
      );

      if (existingMember) {
        if (existingMember.isDeleted) {
          // 삭제된 상태라면 되돌리기 안내
          this.showToast('안내', `${employeeName}님은 삭제 대기 상태입니다. 되돌리기 버튼(↺)을 이용해 주세요.`, 'info');
        } else {
          // 이미 활성화된 상태라면 중복 안내
          this.showToast('경고', `${employeeName}님은 이미 이 프로젝트에 배정되어 있습니다.`, 'warning');
        }
        return;
      }
    }

    // 1. 기존 데이터에서 해당 pmKey를 가진 모든 행(12개월)을 찾아 정보 교체
    this.originalData = this.originalData.map(item => {
      const itemPmKey = item.CompositeKey.substring(0, item.CompositeKey.lastIndexOf('_'));

      if (itemPmKey === oldPmKey) {
        return {
          ...item,
          MemberId: employeeId,
          MemberName: employeeName,
          TeamId: teamId,
          TeamName: teamName,
          Role: role,
          Grade: grade,
          JobDesc: jobDesc,
          Id: `virtual_swap_${item.CompositeKey}`
        };
      }
      return item;
    });

    this.showToast('성공', '멤버가 교체되었습니다. 저장 시 반영됩니다.', 'success');
  }

  //-------------------------------------------------------------------------
  // [9] DML (Save & Cancel)
  //-------------------------------------------------------------------------

  async handleSave() {
    // 1. 유효성 검사: M/M 입력 범위(0~1) 확인
    const invalidEntries = Object.entries(this.draftValues).filter(([key, value]) => {
      const num = parseFloat(value);
      return num < 0 || num > 1;
    });

    if (invalidEntries.length > 0) {
      this.showToast(
        '입력 오류',
        '공수(M/M) 값은 0에서 1 사이의 숫자여야 합니다. 잘못된 값을 수정해 주세요.',
        'error'
      );
      return;
    }

    this.isLoading = true;
    try {
      // ---------------------------------------------------------
      // 2. 신규 멤버 배정 데이터 수집 (ProjectMember__c)
      // ---------------------------------------------------------
      const membersToInsert = [];
      const memberKeys = new Set(); // 12개월 데이터를 한 명의 멤버로 그룹화하기 위한 Set

      this.originalData.forEach(item => {
        // 삭제 대기 중인 행은 제외
        if (item.isDeleted) return;

        const fullKey = item.CompositeKey;
        const pmKey = fullKey.substring(0, fullKey.lastIndexOf('_'));

        // virtual_projmem_(완전 신규) 또는 virtual_swap_(멤버 교체) 태그 확인
        const isNewOrSwapped = item.Id.startsWith('virtual_projmem_') || item.Id.startsWith('virtual_swap_');

        // 신규 행이면서 아직 수집되지 않은 멤버(pmKey)인 경우에만 추가
        if (isNewOrSwapped && !memberKeys.has(pmKey)) {
          membersToInsert.push({
            ProjectId: item.ProjectId,
            MemberId: item.MemberId,
            Role: item.Role,
            Grade: item.Grade,
            PMKey: pmKey // Apex에서 ProjectMember ExternalKey로 사용될 고유 키
          });
          memberKeys.add(pmKey);
        }
      });

      // ---------------------------------------------------------
      // 3. 월별 공수 수정 데이터 수집 (MonthlyEstimation__c)
      // ---------------------------------------------------------
      const mmUpdates = [];
      const processedKeys = new Set();  // 중복 수집 방지

      Object.keys(this.draftValues).forEach(dKey => {
        // Field명(_contract, _actual)을 제외한 CompositeKey 추출
        const cKey = dKey.substring(0, dKey.lastIndexOf('_'));

        if (processedKeys.has(cKey)) return;

        const original = this.originalData.find(a => a.CompositeKey === cKey);
        // 삭제되지 않은 행에 대해서만 변경된 값 수집 (없을 경우 원본값 유지)
        if (original && !original.isDeleted) {
          mmUpdates.push({
            CompositeKey: cKey,
            ContractMM: this.draftValues[`${cKey}_contract`] ?? original.ContractMM,
            ActualMM: this.draftValues[`${cKey}_actual`] ?? original.ActualMM,
            Year: original.Year, Month: original.Month
          });
          processedKeys.add(cKey);
        }
      });

      // ---------------------------------------------------------
      // 4. 서버 통신 및 후속 처리
      // ---------------------------------------------------------
      // Apex saveAllChanges 호출 (멤버 추가/삭제 및 공수 업데이트 통합 처리)
      await saveAllChanges({
        membersToInsert,
        deleteMemberIds: this.deletedMemberIds,
        mmList: mmUpdates
      });

      // 데이터 동기화 지연 대기 (Salesforce 인덱싱 시간 고려)
      await new Promise(resolve => setTimeout(resolve, 500));

      this.showToast('성공', '변경사항이 저장되었습니다.', 'success');

      // UI 상태 초기화 및 최신 데이터 재조회
      this.resetEditState();
      this.projectMode = 'read';
      await this.fetchData();
    } catch (error) {
      // Apex에서 던진 AuraHandledException 메시지 추출
      let message = '알 수 없는 오류가 발생했습니다.';
      if (error && error.body && error.body.message) {
        message = error.body.message;
      }

      this.showToast('저장 실패', message, 'error');
      console.error('Save Error:', error);
    } finally { this.isLoading = false; }
  }

  handleCancel() {
    if (confirm('수정사항이 초기화됩니다. 계속하시겠습니까?')) {
      this.resetEditState();
      this.projectMode = 'read';
      this.fetchData();
    }
  }

  async handleRefreshData() {
    this.resetEditState(); // 편집 상태 초기화
    await this.fetchData(); // 서버에서 다시 로드
    this.showToast('성공', '최신 데이터를 불러왔습니다.', 'success');
  }


  //-------------------------------------------------------------------------
  // [10] Utilities & Helpers
  //-------------------------------------------------------------------------
  validateSelectedProjects() {
    if (this.selectedProjectIds.length > 0) {
      const validIds = this.rawProjectOptions.map(opt => opt.value);
      this.selectedProjectIds = this.selectedProjectIds.filter(id => validIds.includes(id));
    }

    // 프로젝트 뷰인데 아무것도 선택 안된 경우 기본값 세팅
    if (this.isProjectView && this.selectedProjectIds.length === 0 && this.rawProjectOptions.length > 0) {
      this.selectedProjectIds = [this.rawProjectOptions[0].value];
    }
  }

  /** 현재 저장된 필터 값을 반환하는 헬퍼 함수 */
  getPreviousValue(name) {
    switch (name) {
      case 'division':      return this.selectedDivision;
      case 'businessUnit':  return this.selectedBusinessUnit;
      case 'team':          return this.selectedTeam;
      case 'year':          return this.selectedYear;
      case 'probability':   return this.selectedProbability;
      case 'half':          return this.selectedHalf;
      default:              return '';
    }
  }
  resetEditState() { this.draftValues = {}; this.deletedMemberIds = []; }
  showToast(t, m, v) { this.dispatchEvent(new ShowToastEvent({ title: t, message: m, variant: v })); }
}