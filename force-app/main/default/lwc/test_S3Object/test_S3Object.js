import { LightningElement, api, track } from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getS3FileList from '@salesforce/apex/S3ObjectController.getS3FileList';
import saveFileByS3 from '@salesforce/apex/S3ObjectController.saveFileByS3';
import deleteFileByS3 from '@salesforce/apex/S3ObjectController.deleteFileByS3';
import downloadFileByS3 from '@salesforce/apex/S3ObjectController.downloadFileByS3';

const actions = [
    { label: 'Download', name: 'download' },
    { label: 'Delete', name: 'delete' },
];

const columns = [
    { label: 'File Name', fieldName: 'Name'},
    { label: 'File Extention', fieldName: 'Extention__c'},
    { label: 'CreatedDate', fieldName: 'CreatedDate' },
    {
        type: 'action',
        typeAttributes: { rowActions: actions },
    },
];


export default class Test_S3Object extends LightningElement {

    @api recordId;
    data = [];
    columns = columns;
    fileUrl;

    // load 될때 실행되는 함수
    connectedCallback() {
        console.log("connectedCallback@@@@@@@@@@@@@@@@@@@@@@@@@");
        getS3FileList({
            recordId : this.recordId
        }).then(response => {
            // console.log(response)
            if(response == null) {
                console.log('파일 없음');
                // 파일 없을때 뭐 할지?
            } else {
                const s3_object_list = [];
                response.forEach(el => {
                    s3_object_list.push(el);
                });
                this.data = s3_object_list;
            }
        })
        .catch(error => {
            console.log('S3에서 데이터 못받아옴')
        })
    }

    // 파일 업로드
    uploadFile(file, fileContents) {
        console.log('uploadFile..............', file);
        saveFileByS3({
            recordId: this.recordId,
            fileName: file.name,
            base64Data: fileContents, 
            contentType: file.type
        })
        // 오래 걸려서 아마 타임아웃으로 catch로 넘어가는듯? , 데이터 업로드는 성공
        // -> http callout에 대한 처리가 안되서 catch 구간으로 넘어가는듯
        .then((res) => {
            if(res === 'fail') {
                // console.log('이름이 같은 파일 존재');
                this.showToast('warning', '이름이 같은 파일 존재')
                return;
            }
            // 업로드 완료 -> 데이터 reload
            this.connectedCallback();
            // console.log('업로드 성공');
                this.showToast('success', '업로드 성공')

        })
        .catch(error => {
            // 업로드 실패
            console.log('업로드 실패');
            console.log(JSON.stringify(error));
            console.log(error.message);
        })
    }


    // 파일 선택
    handleFilesChange(event) {
        console.log('handleFilesChange')
        
        // 리스트로 변환하는 두가지 방법
        const uploadFiles = Array.from(event.target.files);
        // const uploadFiles = [...event.target.files];

        // 업로드 파일 체크
        for(let i=0; i<uploadFiles.length; i++) {
            let file = uploadFiles[i];
            // 업로드 용량 제한
            if(file.size > 1024*1024*5) {
                this.showToast('warning', '5MB 이하만 업로드 가능 합니다.')
                return;
            }   
            // 확장자 제한
            let ext = file.name.substring(file.name.lastIndexOf('.')+1);
            console.log(ext)
            if(!(ext==='docx' || ext==='pptx' || ext==='xlsx' || ext==='txt' || ext==='pdf')) {
                this.showToast('warning', '문서만 업로드 할 수 있습니다.')
                return;
            }
        }

        // forEach -> return이 안먹힘, 이후 동작 계속 진행
        // 업로드 파일 체크
        // uploadFiles.forEach(file => {
        //     // 업로드 용량 제한
        //     if(file.size > 1024*1024*5) {
        //         this.showToast('warning', '5MB 이하만 업로드 가능 합니다.')
        //         return;
        //     }   
        //     // 확장자 제한
        //     let ext = file.name.substring(file.name.lastIndexOf('.')+1);
        //     console.log(ext)
        //     if(!(ext==='docx' || ext==='pptx' || ext==='xlsx' || ext==='txt' || ext==='pdf')) {
        //         this.showToast('warning', '문서만 업로드 할 수 있습니다.')
        //         return;
        //     }
        // })

        uploadFiles.forEach(file => {
            const fr = new FileReader();
            // FileReader로 읽으면 기본적으로 Base64로 인코딩 된다.
            // 인코딩 결과, data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/... 
            fr.onload = () => {
                var fileContents = fr.result;
                var base64Mark = 'base64,';
                var dataStart = fileContents.indexOf(base64Mark) + base64Mark.length;
                fileContents = fileContents.substring(dataStart);
            
                this.uploadFile(file, fileContents);
            };
            // 파일 데이터 읽기 -> onload 실행
            fr.readAsDataURL(file);
        })        
    }

    // record 이벤트 관리
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'delete':
                this.deleteFile(row);
                break;
            case 'download':
                this.downloadFile(row);
                break;
            default:
        }
    }

    // 다운로드
    downloadFile(row) {
        console.log('downloadFile')
        downloadFileByS3({
            recordId: this.recordId,
            fileName: row.Name + '.' + row.Extention__c,
        }).then((res) => {
            console.log('res.length: ', res.length)
            // 1. base64 디코딩 : 8비트 ascii -> 바이너리 데이터
            const byteArray = atob(res);
            // 2. 바이너리 -> unicode로 변환 후 byte배열에 할당
            const byteNumbers = new Array(byteArray.length);
            for (let i = 0; i < byteArray.length; i++) {
                byteNumbers[i] = byteArray.charCodeAt(i);
            }
            
            // 1바이트(8비트)로 view -> Blob로 변환
            const uint8Array = new Uint8Array(byteNumbers);
            // type 기본값은 '' -> image/png, 등등 줄 수 있음 // application/octet-stream
            const blob = new Blob([uint8Array], {type : 'application/octet-stream'});


            // Blob을 URL로 변환하여 파일 다운로드 경로 생성
            const downloadUrl = URL.createObjectURL(blob);

            // 다운로드 버튼에 링크 달아주기
            const downloadLink = document.createElement('a');
            downloadLink.href = downloadUrl;
            downloadLink.download = row.Name + '.' + row.Extention__c;
            downloadLink.click();

        })
    }

    // 삭제
    deleteFile(row) {
        console.log('deleteFile')
        console.log('row: ', row)
        console.log('row: ', row.Name)
        console.log('row: ', row.Extention__c)
        deleteFileByS3({
            recordId: this.recordId,
            Name: row.Name,
            Extention: row.Extention__c,
            // fileName: row.Name + '.' + row.Extention__c,
        }).then((res) => {
            this.connectedCallback();    // reload
        })
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