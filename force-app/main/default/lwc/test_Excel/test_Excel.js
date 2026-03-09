import { LightningElement, track } from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import sheetjs from '@salesforce/resourceUrl/sheetJS';
import { loadScript } from 'lightning/platformResourceLoader'

export default class Test_Excel extends LightningElement {

    @track isShowDefaultData;
    isShowUploadModal = false;
    dummydata = [];
    dummy_html_string;
    upload_html_string;
    

    async connectedCallback() {
        await Promise.all([loadScript(this, sheetjs)])
        .then(() => {
            console.log("success");
            this.initData();
            this.showDefaultData();
        }).catch(err => {
            console.log("error message => " + err);
        })
    }

    initData() {
        console.log('initData................................')
        const header = []
        for(let i=0; i<10; i++) {
            header.push('temp'+i);
        }
        this.dummydata.push(header);

        for(let i=0; i<20; i++) {
            this.dummydata.push(Array(10).fill('temp_data'+i));
        }

        var ws = XLSX.utils.aoa_to_sheet(this.dummydata);
        this.dummy_html_string = XLSX.utils.sheet_to_html(ws, { id: "data-table", editable: true });
        this.template.querySelector('[class="excel-table"]').innerHTML = this.dummy_html_string;
        this.tableStyle()
    }
    
    // innerHTML 값에 스타일 적용
    tableStyle() {
        let style = document.createElement("style");
          style.type = "text/css";
          style.innerHTML = `
                      .excel-table table {
                          font-family: arial, sans-serif;
                          border-collapse: collapse;
                          width: 100%;
                      }
                      
                      .excel-table td, th {
                          border: 1px solid #dddddd;
                          text-align: left;
                          padding: 8px;
                      }
                      
                      .excel-table tr:nth-child(even) {
                          background-color: #dddddd;
                      }`;
          document.head.appendChild(style);
    }

    // 토글값에 따라 나타낼 데이터 변경
    showDefaultData() {
        this.isShowDefaultData = !this.isShowDefaultData;
        if(this.isShowDefaultData) {
            this.template.querySelector('.excel-table').innerHTML = this.dummy_html_string;
        } else {
            this.uploadDataLoad()
        }
    }

    // 다운로드
    excelDownload() {
        console.log('download button')
        // 빈엑셀 다운로드 막을지?
        console.log()
        if(this.upload_html_string === undefined && !this.isShowUploadModal) {
            this.showToast('warning', '저장할 테이블이 없습니다.')
            return;
        }

        var excel_table = this.template.querySelector('[class="excel-table"]')
        var elt = excel_table.querySelector('table');
        var wb = XLSX.utils.table_to_book(elt, {sheet:"Sheet JS"});
        XLSX.writeFile(wb,('SalesForceExport.xlsx'));
    }

    // 업로드 모달 on/off
    isUploadModal() {
        console.log('isUploadModal')
        this.isShowUploadModal = !this.isShowUploadModal;
    }

    excelFileLoad(event) {
        console.log('excelFileLoad..........')
        const uploadFile = event.target.files[0];
        // 엑셀인지 확인
        console.log(uploadFile.name)
        if(uploadFile.name.slice(-4) !== 'xlsx') {
            this.showToast('warning', 'xlsx 파일만 업로드할 수 있습니다.')
            return;
        } 

        const fr = new FileReader();
        fr.onload = function(e) {
            const data = e.target.result;
            const workbook = XLSX.read(data, { type: 'binary' });
            const sheetName = workbook.SheetNames[0];
            const worksheet = workbook.Sheets[sheetName];
            
            this.upload_html_string = XLSX.utils.sheet_to_html(worksheet, {header: ''}).slice(0, -14);
        }.bind(this);
        fr.readAsBinaryString(uploadFile);
    }
    
    refreshTable() {
        console.log('refreshTable..........')

        console.log(this.upload_html_string)
        if(this.upload_html_string === undefined) {
            this.showToast('warning', '파일을 입력하지 않으셨습니다.')
            return;
        }

        // 업로드 모달창 끄기
        this.isUploadModal();
        // 토글 켜져있으면 끄기
        if(this.isShowDefaultData) {
            this.showDefaultData();
        } else {
            // 데이터만 바꿔주기
            this.uploadDataLoad()
        }
    }

    // 화면에 보여주기
    uploadDataLoad() {
        if(this.upload_html_string === undefined) {
            this.template.querySelector('[class="excel-table"]').innerHTML = '<h2>업로드 된 파일이 없습니다.</h2>';    
        } else {
            this.template.querySelector('[class="excel-table"]').innerHTML = this.upload_html_string;
        }
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