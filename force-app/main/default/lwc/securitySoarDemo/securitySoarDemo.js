import { LightningElement, track } from 'lwc';
import simulateAlert from '@salesforce/apex/SecurityDemoController.simulateAlert';
import simulateDirectAction from '@salesforce/apex/SecurityDemoController.simulateDirectAction';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';

export default class SecuritySoarDemo extends LightningElement {
    @track targetUserId = USER_ID;
    @track isExecuting = false;

    // Action Simulation State
    @track selectedAction = 'KILL_SESSION';
    @track selectedSource = 'TEAMS_INBOUND';

    get actionOptions() {
        return [
            { label: 'KILL_SESSION (계정 동결)', value: 'KILL_SESSION' },
            { label: 'RESTRICT_PERMISSION (권한 축소)', value: 'RESTRICT_PERMISSION' },
            { label: 'NOTIFY_TEAMS (팀즈 알림)', value: 'NOTIFY_TEAMS' }
        ];
    }

    get sourceOptions() {
        return [
            { label: 'TEAMS_INBOUND (팀즈에서 수락)', value: 'TEAMS_INBOUND' },
            { label: 'LWC_DASHBOARD (대시보드 강제 타격)', value: 'LWC_DASHBOARD' },
            { label: 'SYSTEM_ACTION (코어 엔진 탐지)', value: 'SYSTEM_ACTION' },
            { label: 'MANUAL_OVERRIDE (기타 수동)', value: 'MANUAL_OVERRIDE' }
        ];
    }

    handleUserIdChange(event) {
        this.targetUserId = event.detail.recordId;
    }

    handleActionChange(event) {
        this.selectedAction = event.detail.value;
    }

    handleSourceChange(event) {
        this.selectedSource = event.detail.value;
    }

    // [경고 테스트] 단 1회의 이벤트만 발생
    handleSimulateLow() {
        this.fireSimulation('DATA_EXPORT', 1, 'info', '모의 이벤트(1회) 발행이 시작되었습니다.');
    }

    // [치명적 공격 테스트] 5회를 쏟아부어 임계치 ThresholdCritical__c 돌파 유도
    handleSimulateCritical() {
        this.fireSimulation('DATA_EXPORT', 5, 'error', '치명적 스파이크(5연사) 모의 발행이 시작되었습니다.');
    }

    fireSimulation(policyCode, repeatCount, toastVariant, toastMessage) {
        if (!this.targetUserId) {
            this.showToast('오류', 'Target User ID를 입력해주세요.', 'error');
            return;
        }

        this.isExecuting = true;

        simulateAlert({
            targetUserId: this.targetUserId,
            policyCode: policyCode,
            repeatCount: repeatCount
        })
            .then(() => {
                this.showToast('이벤트 모의 투발 완료', toastMessage + ' 관제 대시보드(AuditLog)에서 수치를 확인하세요.', 'success');
            })
            .catch(error => {
                let errorMsg = error.body ? error.body.message : error.message;
                this.showToast('시뮬레이션 실패', errorMsg, 'error');
            })
            .finally(() => {
                this.isExecuting = false;
            });
    }

    // [액션 직접 실행] 선택한 액션과 소스로 이벤트 발행
    handleSimulateAction() {
        if (!this.targetUserId || !this.selectedAction || !this.selectedSource) {
            this.showToast('오류', '대상 사용자, 액션, 그리고 출처를 모두 선택해주세요.', 'error');
            return;
        }

        this.isExecuting = true;

        simulateDirectAction({
            targetUserId: this.targetUserId,
            actionName: this.selectedAction,
            source: this.selectedSource
        })
            .then(() => {
                this.showToast(
                    '액션 실행 완료',
                    `[${this.selectedSource}] 출처로 [${this.selectedAction}] 명령이 성공적으로 전달되었습니다.`,
                    'success'
                );
            })
            .catch(error => {
                let errorMsg = error.body ? error.body.message : error.message;
                this.showToast('액션 실행 실패', errorMsg, 'error');
            })
            .finally(() => {
                this.isExecuting = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}