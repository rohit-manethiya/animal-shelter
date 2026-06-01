import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAvailableDogs from '@salesforce/apex/DogAdoptionController.getAvailableDogs';
import getPendingRequests from '@salesforce/apex/DogAdoptionController.getPendingRequests';

const PAGE_SIZE = 12;

export default class ShelterStaffDashboard extends LightningElement {

    @track dogs = [];
    @track pendingRequests = [];
    @track activeTab = 'dogs';
    @track searchTerm = '';
    @track currentPage = 1;

    hasError = false;
    errorMessage = '';
    totalCount = 0;
    hasNext = false;
    hasPrev = false;

    wiredDogsResult;
    wiredRequestsResult;
    _searchTimer;

    // ─── Wire dogs (with sharing enforced) ─────────────────────────────────

    @wire(getAvailableDogs, {
        searchTerm: '$searchTerm',
        pageNumber: '$currentPage',
        pageSize: PAGE_SIZE
    })
    wiredDogs(result) {
        this.wiredDogsResult = result;
        if (result.data) {
            this.dogs = result.data.dogs;
            this.totalCount = result.data.total;
            this.hasNext = result.data.hasNext;
            this.hasPrev = result.data.hasPrev;
            this.hasError = false;
        } else if (result.error) {
            this.hasError = true;
            this.errorMessage = result.error.body?.message ?? 'Failed to load dogs.';
        }
    }

    // ─── Wire pending requests (with sharing enforced) ───────────────────────

    @wire(getPendingRequests)
    wiredRequests(result) {
        this.wiredRequestsResult = result;
        if (result.data) {
            this.pendingRequests = result.data;
        } else if (result.error) {
            console.error('Error fetching pending requests:', result.error);
        }
    }

    // ─── Tab switching ────────────────────────────────────────────────────────

    handleTabChange(event) {
        this.activeTab = event.detail.value;
    }

    // ─── Search with debounce ────────────────────────────────────────────────

    handleSearch(event) {
        const term = event.target.value.toLowerCase().trim();
        clearTimeout(this._searchTimer);
        this._searchTimer = setTimeout(() => {
            this.searchTerm = term;
            this.currentPage = 1;
        }, 300);
    }

    // ─── Pagination ──────────────────────────────────────────────────────────

    handlePrevPage() {
        if (this.hasPrev) {
            this.currentPage -= 1;
        }
    }

    handleNextPage() {
        if (this.hasNext) {
            this.currentPage += 1;
        }
    }

    // ─── Computed properties ─────────────────────────────────────────────────

    get isLoading() {
        return this.wiredDogsResult?.data === undefined && !this.hasError;
    }

    get hasDogs() {
        return this.dogs?.length > 0;
    }

    get isPrevDisabled() {
        return !this.hasPrev;
    }

    get isNextDisabled() {
        return !this.hasNext;
    }

    get resultLabel() {
        if (!this.totalCount) return 'No dogs for your shelter';
        const start = (this.currentPage - 1) * PAGE_SIZE + 1;
        const end = Math.min(this.currentPage * PAGE_SIZE, this.totalCount);
        return `${start}–${end} of ${this.totalCount} dog${this.totalCount === 1 ? '' : 's'}`;
    }

    get hasPendingRequests() {
        return this.pendingRequests?.length > 0;
    }

    get requestsLabel() {
        const count = this.pendingRequests?.length ?? 0;
        return `📋 Pending Approval${count === 1 ? '' : 's'} (${count})`;
    }

    get isDogsTab() {
        return this.activeTab === 'dogs';
    }

    get isRequestsTab() {
        return this.activeTab === 'requests';
    }

    // ─── Show toast ───────────────────────────────────────────────────────────

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ─── View request details ─────────────────────────────────────────────────

    handleViewRequest(event) {
        event.preventDefault();
        const requestId = event.target.dataset.requestId;
        window.open(`/${requestId}`, '_blank');
    }
}
