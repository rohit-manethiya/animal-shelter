import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

const ADOPTION_STAGE_FIELD = 'Adoption_Request__c.Adoption_Stage__c';

const STAGES = [
    { name: 'Submitted', label: 'Submitted', order: 1 },
    { name: 'Under Review', label: 'Under Review', order: 2 },
    { name: 'Approved', label: 'Approved', order: 3 },
    { name: 'Rejected', label: 'Rejected', order: 4 }
];

export default class AdoptionProgressIndicator extends LightningElement {

    @api recordId;
    currentStage;

    @wire(getRecord, { recordId: '$recordId', fields: [ADOPTION_STAGE_FIELD] })
    wiredRecord({ data, error }) {
        if (data) {
            this.currentStage = data.fields.Adoption_Stage__c.value || 'Submitted';
        } else if (error) {
            console.error('Error loading record:', error);
        }
    }

    get stages() {
        return STAGES.map(stage => ({
            ...stage,
            isCurrent: stage.name === this.currentStage,
            isComplete: this.isStageComplete(stage.name),
            isRejected: this.currentStage === 'Rejected' && stage.name === 'Rejected'
        }));
    }

    isStageComplete(stageName) {
        const stageOrder = STAGES.find(s => s.name === stageName)?.order || 0;
        const currentOrder = STAGES.find(s => s.name === this.currentStage)?.order || 0;
        return stageOrder < currentOrder && this.currentStage !== 'Rejected';
    }

    get statusClass() {
        if (this.currentStage === 'Rejected') return 'slds-text-color_error';
        if (this.currentStage === 'Approved') return 'slds-text-color_success';
        return 'slds-text-color_default';
    }

    get statusIcon() {
        if (this.currentStage === 'Rejected') return 'utility:close';
        if (this.currentStage === 'Approved') return 'utility:check';
        return 'utility:process';
    }
}
