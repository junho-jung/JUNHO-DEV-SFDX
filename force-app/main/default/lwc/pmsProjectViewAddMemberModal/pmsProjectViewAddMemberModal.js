/**
 * @Author            : jh.jung
 * @Description     :
 * @Target            :
 * @Modification Log
 Ver      Date            Author           Modification
 ===================================================================================
 1.0      2026-01-12      jh.jung           Created
 1.1      2026-01-27      jh.jung           Refactoring / Commenting
 */

import { api, track, wire } from 'lwc';
import LightningModal from 'lightning/modal';
import getMemberAllocations from '@salesforce/apex/PMS_ResourceManagementController.getMemberAllocations';
import getPicklistOptions from '@salesforce/apex/PMS_ResourceManagementController.getPicklistOptions';

/**
 * @description 프로젝트 멤버를 신규 추가하거나 기존 멤버를 교체하는 팝업 모달
 */
export default class PmsProjectViewAddMemberModal extends LightningModal {
  // -------------------------------------------------------------------------
  // [1] Properties & State: 부모로부터 전달받는 API 속성 및 내부 상태
  // -------------------------------------------------------------------------

  @api projectId;    // 대상 프로젝트 ID
  @api projectName;  // 대상 프로젝트명
  @api currentYear;  // 배정 계획 조회 연도

  /** 교체(Swap) 모드 전용 속성 */
  @api isSwapMode = false;
  @api oldPmKey;       // 교체 대상의 고유 식별자
  @api pmName;         // 교체 대상 멤버 이름
  @api oldRole;        // 교체 대상의 기존 역할
  @api oldGrade;       // 교체 대상의 기존 등급
  @api oldEmployeeId;  // 교체 대상의 기존 직원 ID

  @track selectedEmployeeId;
  @track memberAllocations = []; // 선택된 직원의 연간 가동률 데이터
  @track selectedRole = '';
  @track selectedGrade = '';
  @track roleOptions = [];
  @track gradeOptions = [];
  @track isLoading = false;

  // -------------------------------------------------------------------------
  // [2] Lifecycle: 초기화
  // -------------------------------------------------------------------------

  connectedCallback() {
    // 교체 모드일 경우 기존 멤버의 정보를 초기값으로 세팅
    if (this.isSwapMode) {
      this.initializeSwapMode();
    }
  }

  /** @description 교체 모드 초기 데이터 바인딩 및 가동률 조회 */
  initializeSwapMode() {
    this.selectedRole = this.oldRole;
    this.selectedGrade = this.oldGrade;
    this.selectedEmployeeId = this.oldEmployeeId;
    this.loadMemberAllocationData(this.selectedEmployeeId);
  }

  // -------------------------------------------------------------------------
  // [3] Wire Services: 공통 픽리스트 옵션 로드
  // -------------------------------------------------------------------------

  @wire(getPicklistOptions, { objectName: 'ProjectMember__c', fieldName: 'Role__c' })
  wiredRoles({ data }) {
    if (data) {
      this.roleOptions = data;
      // 추가 모드일 때만 첫 번째 옵션을 기본값으로 선택
      if (!this.isSwapMode && data.length > 0) this.selectedRole = data[0].value;
    }
  }

  @wire(getPicklistOptions, { objectName: 'ProjectMember__c', fieldName: 'Grade__c' })
  wiredGrades({ data }) {
    if (data) {
      this.gradeOptions = data;
      if (!this.isSwapMode && data.length > 0) this.selectedGrade = data[0].value;
    }
  }

  // -------------------------------------------------------------------------
  // [4] Getters: UI 텍스트 및 상태 제어
  // -------------------------------------------------------------------------

  /** @description 모달 상단 타이틀 결정 */
  get modalHeader() {
    return this.isSwapMode
      ? `멤버 교체 | 프로젝트: ${this.projectName} · 대상: ${this.pmName}`
      : `멤버 추가 | 프로젝트: ${this.projectName}`;
  }

  /** @description 하단 실행 버튼 라벨 및 아이콘 */
  get actionLabel() { return this.isSwapMode ? '교체하기' : '추가하기'; }
  get actionIcon() { return this.isSwapMode ? 'utility:replace' : 'utility:add'; }

  /** @description 가배정(Placeholder) 리소스 선택 시 경고 노출 여부 */
  get isPlaceholderSelected() {
    return this.memberAllocations?.[0]?.IsPlaceholder === true;
  }

  /** @description 가배정 리소스에 대한 안내 메시지 */
  get placeholderWarningMessage() {
    if (!this.isPlaceholderSelected) return '';
    const gradeName = this.memberAllocations[0].MemberName;
    return `현재 선택하신 항목은 [${gradeName}] 가배정 리소스입니다. 확정된 인력이 없을 때 임시 투입 계획용으로 사용하세요.`;
  }

  /** @description 실행 버튼 비활성화 조건 */
  get isAddDisabled() { return !this.selectedEmployeeId || this.isLoading; }

  // -------------------------------------------------------------------------
  // [5] Lookup Configuration: 직원 검색 피커 설정
  // -------------------------------------------------------------------------

  get displayInfo() {
    return { primaryField: 'Name', additionalFields: ['Department__r.Name', 'JobLevel__c'] };
  }

  get matchingInfo() {
    return { primaryField: { fieldPath: 'Name' }, additionalFields: [{ fieldPath: 'Department__r.Name' }] };
  }

  get filterInfo() {
    return { criteria: [{ fieldPath: 'IsActive__c', operator: 'eq', value: true }] };
  }

  // -------------------------------------------------------------------------
  // [6] Event Handlers: 사용자 입력 처리
  // -------------------------------------------------------------------------

  /** @description 직원 검색 피커 변경 핸들러 */
  handleEmployeeChange(event) {
    this.selectedEmployeeId = event.detail.recordId;
    if (this.selectedEmployeeId) {
      this.loadMemberAllocationData(this.selectedEmployeeId);
    } else {
      this.memberAllocations = [];
    }
  }

  handleRoleChange(event) { this.selectedRole = event.detail.value; }
  handleGradeChange(event) { this.selectedGrade = event.detail.value; }

  /** @description 서버로부터 선택된 직원의 연간 가동률 및 팀 정보 조회 */
  async loadMemberAllocationData(employeeId) {
    this.isLoading = true;
    try {
      this.memberAllocations = await getMemberAllocations({
        memberId: employeeId,
        year: this.currentYear
      });
    } catch (error) {
      console.error('멤버 데이터 로드 실패:', error);
    } finally {
      this.isLoading = false;
    }
  }

  // -------------------------------------------------------------------------
  // [7] Action Handlers: 최종 실행 및 모달 닫기
  // -------------------------------------------------------------------------

  /** @description 실행 버튼 클릭 시 부모(Grid)에게 데이터 전달하며 종료 */
  handleAction() {
    const payload = this.constructPayload();

    this.close({
      status: 'success',
      type: this.isSwapMode ? 'SWAP' : 'ADD',
      payload: payload
    });
  }

  /** @description 부모 컴포넌트의 가상 DTO 생성에 필요한 재료 패키징 */
  constructPayload() {
    const info = this.memberAllocations?.[0] || {};

    const data = {
      employeeId: this.selectedEmployeeId,
      employeeName: info.MemberName,
      projectId: this.projectId,
      projectName: this.projectName,
      teamId: info.TeamId,
      teamName: info.TeamName,
      role: this.selectedRole,
      grade: this.selectedGrade,
      jobDesc: info.JobDesc,
      isPlaceholder: info.IsPlaceholder,
    };

    // 교체 모드일 경우에만 타겟 식별자 추가
    if (this.isSwapMode) {
      data.oldPmKey = this.oldPmKey;
    }

    return data;
  }

  handleCancel() {
    this.close({ status: 'cancel' });
  }
}