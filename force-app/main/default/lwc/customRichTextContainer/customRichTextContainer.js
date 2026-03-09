import { LightningElement, api } from 'lwc';

export default class CustomRichTextContainer extends LightningElement {
    @api objectApiName;
    @api recordId;
    @api sectionLabel;
    @api isOpen = false;
    @api fieldApiNames;
    @api hideChildSaveButtons = false;

    get fields() {
        if (!this.fieldApiNames) {
            return [];
        }

        const sectionLabel = this.sectionLabel;

        return this.fieldApiNames
            .split(/[;,]/)
            .map((f) => f.trim())
            .filter((f) => !!f)
            .map((fieldApiName) => ({
                fieldApiName,
                sectionLabel
            }));
    }

    handleSaveAll() {
        const children = this.template.querySelectorAll('c-custom-rich-text');
        if (!children || children.length === 0) {
            return;
        }

        children.forEach((child) => {
            if (typeof child.save === 'function') {
                child.save();
            }
        });
    }
}