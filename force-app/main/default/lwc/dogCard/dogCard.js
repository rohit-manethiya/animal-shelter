import { LightningElement, api } from 'lwc';

export default class DogCard extends LightningElement {

    @api dog;

    get ageLabel() {
        if (!this.dog?.Age__c && this.dog?.Age__c !== 0) return 'Age unknown';
        return `${this.dog.Age__c} year${this.dog.Age__c === 1 ? '' : 's'} old`;
    }

    get hasFacility() {
        return !!this.dog?.Shelter_Facility__r?.Name;
    }

    get facilityLabel() {
        const f = this.dog?.Shelter_Facility__r;
        return f?.Region__c ? `${f.Name} (${f.Region__c})` : f?.Name ?? '';
    }

    handleAdoptClick() {
        // Bubble the event up so dogAdoptionList can open its modal
        this.dispatchEvent(new CustomEvent('requestadoption', {
            detail  : { dogId: this.dog.Id, dogName: this.dog.Name },
            bubbles : true,
            composed: true
        }));
    }

    handleImageError(event) {
        // Gracefully hide broken images — placeholder shown via lwc:else in template
        event.target.style.display = 'none';
    }
}
