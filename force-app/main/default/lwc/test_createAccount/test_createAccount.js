import { LightningElement, api } from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getContactListByEqualAccount from '@salesforce/apex/AccountController.getContactListByEqualAccount';
import createContact from '@salesforce/apex/AccountController.createContact';

const actions = [
    { label: 'Show details', name: 'show_details' },
    { label: 'Delete', name: 'delete' },
];

const columns = [
    { label: 'FirstName', fieldName: 'FirstName'},
    { label: 'LastName', fieldName: 'LastName'},
    { label: 'Email', fieldName: 'Email' },
    { label: 'accountName', fieldName: 'accountName'},
    {
        type: 'action',
        typeAttributes: { rowActions: actions },
    },
];


export default class Test_createAccount extends LightningElement {

    // datatable
    data = [];
    columns = columns;

    // modal
    inputFormFlag = false;

    // contact
    AccountId=null;
    FirstName=null;
    LastName=null;
    Email=null;

    @api recordId;

    // load 될때 실행되는 함수
    connectedCallback() {
        getContactListByEqualAccount({recordId : this.recordId})
        .then(response => {
            console.log("@@@@@@@@@@@@@@@@@@@@@@@@@@api call");
            
            const contactListEqualAccount = [];
            response.forEach(el => {
                console.log(el);
                el.accountName = el.Account.Name;
                contactListEqualAccount.push(el);
            });
            this.data = contactListEqualAccount;
        })
    }

    // 저장 버튼 onclick event
    saveContactClick() {
        console.log("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ save button click")
        createContact({
            'accountId':this.AccountId, 
            'FirstName':this.FirstName, 
            'LastName':this.LastName, 
            'Email':this.Email
        }).then(response => {
            console.log("@@@@@@@@@@@@@@@@@@ createContect");
            if(response === '성공') {
                // 모달창 끄기
                this.reverseinputFormFlag();
                // 데이터 업데이트
                this.connectedCallback();
                this.showToast("success", response);
            } else {
                this.showToast("warning", response);
            }
        });
    }

    // 필드 변화 감지 이벤트
    changeCheck(e) {
        const field = e.target.fieldName;
        if(field === 'AccountId') {
            this.AccountId = e.target.value;
        } else if(field === 'FirstName') {
            this.FirstName = e.target.value;
        } else if(field === 'LastName') {
            this.LastName = e.target.value;
        } else if(field === 'Email') {
            this.Email = e.target.value;
        }
    }

    // 모달창 on/off
    reverseinputFormFlag() {
        console.log("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ toggleFlag: " + this.inputFormFlag + " -> " + !this.inputFormFlag);
        this.inputFormFlag = !this.inputFormFlag;
    }

    // 경고창
    showToast(type, message) {
        const event = new ShowToastEvent({
            title: type,
            message: message,
            variant: type,
        });
        this.dispatchEvent(event);
    }
}