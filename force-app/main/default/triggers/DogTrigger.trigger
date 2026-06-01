trigger DogTrigger on Dog__c (before insert, before update, after insert, after update) {
    new DogTriggerHandler().run();
}
