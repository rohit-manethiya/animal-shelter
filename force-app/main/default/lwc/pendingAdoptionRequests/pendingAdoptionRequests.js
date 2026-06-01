import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getPendingRequests     from '@salesforce/apex/DogAdoptionController.getPendingRequests';
import processAdoptionRequest from '@salesforce/apex/DogAdoptionController.processAdoptionRequest';

export default class PendingAdoptionRequests extends LightningElement {

    @track pendingRequests = [];
    isLoading = true;
    wiredResult;

    @wire(getPendingRequests)
    wiredRequests(result) {
        this.wiredResult = result;
        this.isLoading   = false;
        if (result.data) {
            // Wrapper already has flat fields — just add UI state
            this.pendingRequests = result.data.map(r => ({
                ...r,
                isProcessing: false
            }));
        }
    }

    get hasPending() {
        return this.pendingRequests.length > 0;
    }

    get pendingCount() {
        return String(this.pendingRequests.length);
    }

    async handleAction(event) {
        const workItemId = event.target.dataset.id;
        const action     = event.target.dataset.action; // 'Approve' or 'Reject'

        this.pendingRequests = this.pendingRequests.map(r =>
            r.workItemId === workItemId ? { ...r, isProcessing: true } : r
        );

        try {
            await processAdoptionRequest({ workItemId, action });
            this.dispatchEvent(new ShowToastEvent({
                title   : action === 'Approve' ? 'Approved!' : 'Rejected',
                message : `Adoption request has been ${action.toLowerCase()}d.`,
                variant : action === 'Approve' ? 'success' : 'warning'
            }));
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title   : 'Error',
                message : error.body?.message ?? 'Something went wrong.',
                variant : 'error'
            }));
            this.pendingRequests = this.pendingRequests.map(r =>
                r.workItemId === workItemId ? { ...r, isProcessing: false } : r
            );
        }
    }
}
