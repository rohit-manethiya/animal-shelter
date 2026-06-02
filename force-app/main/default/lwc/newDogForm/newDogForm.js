import { LightningElement, wire, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { createRecord } from 'lightning/uiRecordApi';
import getBreeds from '@salesforce/apex/DogBreedService.getBreeds';
import DOG_OBJECT from '@salesforce/schema/Dog__c';
import NAME_FIELD from '@salesforce/schema/Dog__c.Name';
import BREED_FIELD from '@salesforce/schema/Dog__c.Breed__c';
import AGE_FIELD from '@salesforce/schema/Dog__c.Age__c';
import STATUS_FIELD from '@salesforce/schema/Dog__c.Status__c';
import IMAGE_URL_FIELD from '@salesforce/schema/Dog__c.Image_URL__c';
import DESCRIPTION_FIELD from '@salesforce/schema/Dog__c.Description__c';
import SHELTER_FIELD from '@salesforce/schema/Dog__c.Shelter_Facility__c';

export default class NewDogForm extends LightningElement {

    @track name = '';
    @track breed = '';
    @track age = null;
    @track status = 'Available';
    @track imageUrl = '';
    @track description = '';
    @track shelterFacilityId = null;
    @track isLoading = false;
    @track breedOptions = [];

    statusOptions = [
        { label: 'Available', value: 'Available' },
        { label: 'Adopted', value: 'Adopted' },
        { label: 'Pending', value: 'Pending' }
    ];

    @wire(getBreeds)
    wiredBreeds({ data, error }) {
        if (data) {
            this.breedOptions = data;
        } else if (error) {
            this.showToast('Error', 'Failed to load breeds.', 'error');
        }
    }

    handleChange(event) {
        this[event.target.dataset.field] = event.target.value;
    }

    handleBreedChange(event) {
        this.breed = event.detail.value;
    }

    handleStatusChange(event) {
        this.status = event.detail.value;
    }

    handleShelterChange(event) {
        this.shelterFacilityId = event.detail.recordId;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSave() {
        if (!this.name?.trim() || !this.breed || !this.shelterFacilityId) {
            this.showToast('Validation Error', 'Name, Breed, and Shelter are required.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const fields = {
                [NAME_FIELD.fieldApiName]: this.name.trim(),
                [BREED_FIELD.fieldApiName]: this.breed,
                [STATUS_FIELD.fieldApiName]: this.status,
                [SHELTER_FIELD.fieldApiName]: this.shelterFacilityId
            };
            if (this.age) fields[AGE_FIELD.fieldApiName] = Number(this.age);
            if (this.imageUrl?.trim()) fields[IMAGE_URL_FIELD.fieldApiName] = this.imageUrl.trim();
            if (this.description?.trim()) fields[DESCRIPTION_FIELD.fieldApiName] = this.description.trim();

            await createRecord({ apiName: DOG_OBJECT.objectApiName, fields });

            this.showToast('Success', `${this.name} has been added!`, 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showToast('Error', error.body?.message ?? 'Failed to save dog.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get isSaveDisabled() {
        return !this.name?.trim() || !this.breed || !this.shelterFacilityId;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
