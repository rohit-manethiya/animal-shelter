import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getPendingRequests from '@salesforce/apex/DogAdoptionController.getPendingRequests';
import processAdoptionRequest from '@salesforce/apex/DogAdoptionController.processAdoptionRequest';

export default class PendingAdoptionRequests extends LightningElement {

    @track pendingRequests = [];
    @track sortOrder = 'asc';
    isLoading = true;
    wiredResult;

    @wire(getPendingRequests)
    wiredRequests(result) {
        this.wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.pendingRequests = result.data.map(r => ({
                ...r,
                isProcessing: false,
                ...this._computeWaiting(r.requestDate)
            }));
        }
    }

    _computeWaiting(requestDate) {
        if (!requestDate) {
            return { daysWaiting: 0, daysWaitingLabel: 'Unknown', daysBadgeClass: 'days-badge days-badge-normal', rowClass: '' };
        }
        const days = Math.floor((Date.now() - new Date(requestDate).getTime()) / 86400000);
        let daysBadgeClass = 'days-badge days-badge-normal';
        let rowClass = '';
        if (days >= 7) {
            daysBadgeClass = 'days-badge days-badge-critical';
            rowClass = 'request-row-critical';
        } else if (days >= 3) {
            daysBadgeClass = 'days-badge days-badge-warning';
            rowClass = 'request-row-warning';
        }
        const label = days === 0 ? 'Today' : days === 1 ? '1 day' : `${days} days`;
        return { daysWaiting: days, daysWaitingLabel: label, daysBadgeClass, rowClass };
    }

    get hasPending() {
        return this.pendingRequests.length > 0;
    }

    get pendingCount() {
        return String(this.pendingRequests.length);
    }

    get sortedRequests() {
        return [...this.pendingRequests].sort((a, b) => {
            const diff = new Date(a.requestDate) - new Date(b.requestDate);
            return this.sortOrder === 'asc' ? diff : -diff;
        });
    }

    get oldestVariant() {
        return this.sortOrder === 'asc' ? 'brand' : 'neutral';
    }

    get newestVariant() {
        return this.sortOrder === 'desc' ? 'brand' : 'neutral';
    }

    handleSortChange(event) {
        this.sortOrder = event.target.dataset.sort;
    }

    async handleAction(event) {
        const workItemId = event.target.dataset.id;
        const action = event.target.dataset.action;

        this.pendingRequests = this.pendingRequests.map(r =>
            r.workItemId === workItemId ? { ...r, isProcessing: true } : r
        );

        try {
            await processAdoptionRequest({ workItemId, action });
            this.dispatchEvent(new ShowToastEvent({
                title: action === 'Approve' ? 'Approved!' : 'Rejected',
                message: `Adoption request has been ${action.toLowerCase()}d.`,
                variant: action === 'Approve' ? 'success' : 'warning'
            }));
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message ?? 'Something went wrong.',
                variant: 'error'
            }));
            this.pendingRequests = this.pendingRequests.map(r =>
                r.workItemId === workItemId ? { ...r, isProcessing: false } : r
            );
        }
    }
}
