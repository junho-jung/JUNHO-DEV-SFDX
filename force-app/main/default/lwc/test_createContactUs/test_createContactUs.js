import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getCategoryList from '@salesforce/apex/ContactUsController.getCategoryList';
import insertContactUs from '@salesforce/apex/ContactUsController.insertContactUs';


// const emailRegex = new RegExp('[a-z0-9]+@[a-z]+\.[a-z]{2,3}');
const emailRegex = /^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$/;

// navigation을 사용하려면 NavigationMixin 상속
export default class Test_createContactUs extends NavigationMixin(LightningElement) {
    
    // 동적으로 Picklist 값 받아오기
    @wire(getCategoryList)
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.categoryOptions = data;
        } else if (error) {
            console.error(error);
        }
    }

    @track categoryOptions;
    @track CCList = [];
    @track fileList = [];
    
    category = '';
    email = '';
    subject = '';
    description = '';
    CCInput;
    emailValidateFlag = true;

    // 콤보박스 이벤트 값 추적
    handleComboBox(event) {
        this.category = event.detail.value;
    }

    // Input 값 체크
    handleInput(event) {
        const field = event.target.name;
        if(field == "Email") this.email = event.target.value;
        else if(field == "Subject") this.subject = event.target.value;
        else if(field == "Description") this.description = event.target.value;
        else if(field == "Colaborators") this.CCInput = event.target.value;
    }
    
    // KeyDown 이벤트 추적
    handleKeyDown(event) {
        let keyCode = event.keyCode;
        let duplicateCCFlag;           // 중복되면 true
        let validateCCFlag = true;     // 유효하면 true

        // 엔터 눌렸을 때, CC등록
        if(keyCode === 13) {

            // 이메일 유효 체크
            if(!emailRegex.test(this.CCInput)) {
                this.showToast("warning", "유효한 이메일이 아닙니다.")
                validateCCFlag = false;
            }
            
            // 이메일 중복 체크
            this.CCList.forEach((email) => {
                if(email === this.CCInput) {
                    this.showToast("warning", "이메일 중복입니다.")
                    duplicateCCFlag = true;
                } 
            });

            // 체크 다 통과하면 CCList에 등록
            if(!duplicateCCFlag && validateCCFlag) {
                this.CCList.push(this.CCInput);
                this.CCInput = null;
            }
        }
    }

    // 선택한 CC 지우기
    handleRemoveCC(event) {
        console.log('remove CC');
        console.log(event.target.label);
        
        // 다른애들만 필터로 찾기.
        this.CCList = this.CCList.filter((email) => email != event.target.label)
    }

    // 클릭한 file 지우기
    handleRemoveFile(event) {
        console.log('remove File');
        console.log(event.target.label);
        
        // 다른애들만 필터로 찾기.
        this.fileList = this.fileList.filter((file) => file.name != event.target.label)
    }

    // contactUs 정보 담아서 저장
    submitEvent() {
        
        let flag = false;
        
        // email 체크
        if(!this.emailValidateFlag) {
            this.showToast("warning", "your Email을 확인하세요")
            return;
        }

        // 필수 필드 확인
        if(this.category && 
        this.email && 
        this.subject &&
        this.description) {
            flag = true;
        }

        if(flag) {
            const contactUsInfo = {
                recordId : this.recordId,
                category : this.category,
                email : this.email,
                subject : this.subject,
                description : this.description,
                CCList : this.CCList.join('; '),    // CC 묶어서 보내기
                fileList : this.fileList,
            };
            console.log(JSON.stringify(contactUsInfo));
            insertContactUs({
                contactUsInfo : contactUsInfo,
            })
            .then(response => {
                console.log('response.....................' + response);
                // contactUs record page로 redirect
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: response,
                        objectApiName: 'ContactUs__c',
                        actionName: 'view',
                    }
                });
            })
            .catch(error => {
                this.showToast("error", "실패, 관리자에게 문의하세요.")
            });
            
        } else {
            this.showToast("warning", "필수값을 입력하세요.")
        }
    }
    
    // 이메일 정규식 체크
    checkInputVelidate(event) {
        if(!emailRegex.test(event.target.value)) {
            this.emailValidateFlag = false;
        } else {
            this.emailValidateFlag = true;
        }

        // 비어있으면 유효성 에러 꺼주기
        if(!event.target.value)    this.emailValidateFlag = true;
        
    }
    
    // 업로드 완료시 -> 파일리스트에 보관
    handleUploadFinished(event) {
        const files = event.detail.files;
        console.log(files);
        files.forEach(file => {
            console.log(file)
            this.fileList.push(file)
        });
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