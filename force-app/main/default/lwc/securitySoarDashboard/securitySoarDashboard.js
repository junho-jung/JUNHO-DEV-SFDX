import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAuditLogs from '@salesforce/apex/SecurityDashboardController.getAuditLogs';
import getActionLogs from '@salesforce/apex/SecurityDashboardController.getActionLogs';
import executeManualAction from '@salesforce/apex/SecurityDashboardController.executeManualAction';

const AUDIT_COLUMNS = [
    { label: '심각도', fieldName: 'MaxSeverity__c', type: 'text', initialWidth: 100 },
    { label: '사용자', fieldName: 'UserName', type: 'text' },
    { label: '탐지 정책', fieldName: 'PolicyCode__c', type: 'text' },
    { label: '발생 횟수', fieldName: 'AlertCount__c', type: 'text', initialWidth: 100 },
    { label: '최근 감지 시간', fieldName: 'LastOccurredAt', type: 'date', typeAttributes: {
        year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit'
    }},
    {
        type: 'action',
        typeAttributes: { rowActions: [
            { label: '계정 즉시 동결 (Kill Session)', name: 'KILL_SESSION' },
            { label: '시스템 권한 축소', name: 'RESTRICT_PERMISSION' }
        ]}
    }
];

const ACTION_COLUMNS = [
    { label: '액션', fieldName: 'ActionName__c', type: 'text', initialWidth: 160 },
    { label: '상태', fieldName: 'Status__c', type: 'text', initialWidth: 100 },
    { label: '동기/비동기', fieldName: 'SyncLabel', type: 'text', initialWidth: 90 },
    { label: '대상(AuditKey)', fieldName: 'AuditKey', type: 'text' },
    { label: '실행 시각', fieldName: 'ExecutedAt', type: 'date', typeAttributes: {
        year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit'
    }}
];

export default class SecuritySoarDashboard extends LightningElement {
    columns = AUDIT_COLUMNS;
    actionColumns = ACTION_COLUMNS;
    @track auditLogs = [];
    @track actionLogs = [];
    error;
    isLoading = false;
    wiredLogsResult;
    wiredActionLogsResult;
    dataLoaded = false;
    actionDataLoaded = false;

    get hasAuditLogs() {
        return this.auditLogs && this.auditLogs.length > 0;
    }

    get hasActionLogs() {
        return this.actionLogs && this.actionLogs.length > 0;
    }

    @wire(getAuditLogs)
    wiredLogs(result) {
        this.wiredLogsResult = result;
        const { data, error } = result;

        if (data) {
            const mappedData = data.map(log => ({
                ...log,
                UserName: log.User__r ? log.User__r.Name : (log.UserName ? log.UserName : log.User__c),
                LastOccurredAt: log.LastOccurredAt__c ? new Date(log.LastOccurredAt__c).getTime() : null
            }));
            this.auditLogs = [...mappedData];
            this.error = undefined;
            this.dataLoaded = true;
        } else if (error) {
            this.error = error;
            this.auditLogs = [];
        }
    }

    @wire(getActionLogs)
    wiredActionLogs(result) {
        this.wiredActionLogsResult = result;
        const { data, error } = result;

        if (data) {
            this.actionLogs = data.map(log => ({
                ...log,
                AuditKey: log.SecurityAuditLog__r ? log.SecurityAuditLog__r.AuditKey__c : '',
                SyncLabel: log.Is_Sync__c ? '동기' : '비동기',
                ExecutedAt: log.ExecutedAt__c ? new Date(log.ExecutedAt__c).getTime() : null
            }));
            this.actionDataLoaded = true;
        } else if (error) {
            this.actionLogs = [];
            this.actionDataLoaded = true;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await Promise.all([
                refreshApex(this.wiredLogsResult),
                refreshApex(this.wiredActionLogsResult)
            ]);
        } finally {
            this.isLoading = false;
        }
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        const payload = JSON.stringify({
            userId: row.User__c,
            policyCode: row.PolicyCode__c,
            source: 'LWC_DASHBOARD'
        });

        this.isLoading = true;
        try {
            await executeManualAction({ actionType: actionName, payload: payload });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '조치 완료',
                    message: `[${row.UserName}] 님에 대한 [${actionName}] 수동 제어 조치가 성공적으로 실행되었습니다.`,
                    variant: 'success'
                })
            );
            await this.handleRefresh();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '조치 실패',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
}