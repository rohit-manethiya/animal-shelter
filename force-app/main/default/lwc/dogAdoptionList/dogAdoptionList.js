import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAvailableDogs from '@salesforce/apex/DogAdoptionController.getAvailableDogs';
import requestAdoption  from '@salesforce/apex/DogAdoptionController.requestAdoption';

const PAGE_SIZE = 12;

export default class DogAdoptionList extends LightningElement {

    @track dogs       = [];
    @track showModal  = false;
    @track isSubmitting = false;

    hasError   = false;
    errorMessage = '';

    // Pagination state
    @track currentPage = 1;
    totalCount  = 0;
    hasNext     = false;
    hasPrev     = false;

    // Search
    @track searchTerm = '';
    _searchTimer;

    selectedDogId   = null;
    selectedDogName = '';
    adopterName     = '';
    adopterEmail    = '';
    adopterPhone    = '';

    // Wire result to invalidate cache on adoption request
    wiredDogsResult;

    // ─── Wire adapter ─────────────────────────────────────────────────────────
    // Each (searchTerm, pageNumber) combination is cached separately.
    // Changing searchTerm or currentPage triggers a new wire call.
    // Revisiting the same page hits the cache without a server call.

    @wire(getAvailableDogs, {
        searchTerm: '$searchTerm',
        pageNumber: '$currentPage',
        pageSize: PAGE_SIZE
    })
    wiredDogs(result) {
        this.wiredDogsResult = result;
        if (result.data) {
            this.dogs       = result.data.dogs;
            this.totalCount = result.data.total;
            this.hasNext    = result.data.hasNext;
            this.hasPrev    = result.data.hasPrev;
            this.hasError   = false;
        } else if (result.error) {
            this.hasError     = true;
            this.errorMessage = result.error.body?.message ?? 'Failed to load dogs.';
        }
    }

    get isLoading() {
        return this.wiredDogsResult?.data === undefined && !this.hasError;
    }

    // ─── Search with 300ms debounce — one server call after typing stops ──────

    handleSearch(event) {
        const term = event.target.value.toLowerCase().trim();
        clearTimeout(this._searchTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimer = setTimeout(() => {
            this.searchTerm  = term;
            this.currentPage = 1;
            // Wire adapter automatically fires when searchTerm changes
        }, 300);
    }

    // ─── Pagination ───────────────────────────────────────────────────────────

    handlePrevPage() {
        if (this.hasPrev) {
            this.currentPage -= 1;
            // Wire adapter automatically fires when currentPage changes
        }
    }

    handleNextPage() {
        if (this.hasNext) {
            this.currentPage += 1;
            // Wire adapter automatically fires when currentPage changes
        }
    }

    // ─── Computed labels ──────────────────────────────────────────────────────

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
        if (!this.totalCount) return 'No dogs available';
        const start = (this.currentPage - 1) * PAGE_SIZE + 1;
        const end   = Math.min(this.currentPage * PAGE_SIZE, this.totalCount);
        return `${start}–${end} of ${this.totalCount} dog${this.totalCount === 1 ? '' : 's'}`;
    }

    // ─── Adoption request ─────────────────────────────────────────────────────

    handleAdoptionRequest(event) {
        this.selectedDogId   = event.detail.dogId;
        this.selectedDogName = event.detail.dogName;
        this.showModal       = true;
    }

    closeModal() {
        this.showModal = false;
        this.resetForm();
    }

    handleFieldChange(event) {
        this[event.target.dataset.field] = event.target.value;
    }

    async submitAdoptionRequest() {
        if (!this.adopterName?.trim() || !this.adopterEmail?.trim()) {
            this.showToast('Validation Error', 'Name and email are required.', 'error');
            return;
        }

        this.isSubmitting = true;
        try {
            await requestAdoption({
                dogId       : this.selectedDogId,
                adopterName : this.adopterName,
                adopterEmail: this.adopterEmail,
                adopterPhone: this.adopterPhone
            });
            this.showToast('Request Submitted!',
                `Your adoption request for ${this.selectedDogName} has been submitted.`,
                'success');
            this.closeModal();
            // Refresh current page cache — the adopted dog will be gone from results
            await refreshApex(this.wiredDogsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message ?? 'Something went wrong.', 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    resetForm() {
        this.adopterName = this.adopterEmail = this.adopterPhone = '';
        this.selectedDogId = null;
        this.selectedDogName = '';
    }
}
