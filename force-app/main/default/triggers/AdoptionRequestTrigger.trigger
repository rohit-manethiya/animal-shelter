trigger AdoptionRequestTrigger on Adoption_Request__c (after insert, after update) {
    new AdoptionRequestTriggerHandler().run();
}
