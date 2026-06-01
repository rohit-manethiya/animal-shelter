public class DogTriggerHandler extends TriggerHandler {

    private List<Dog__c> newDogs;
    private Map<Id, Dog__c> oldMap;

    public DogTriggerHandler() {
        this.newDogs = (List<Dog__c>) Trigger.new;
        this.oldMap  = (Map<Id, Dog__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        validateUniqueDogNamePerShelter(newDogs, null);
    }

    protected override void beforeUpdate() {
        validateUniqueDogNamePerShelter(newDogs, oldMap);
    }

    protected override void afterInsert() {
        // Async: fetch dog image then notify shelter (chained Queueables)
        System.enqueueJob(new DogImageFetchQueueable(newDogs));
    }

    protected override void afterUpdate() {
        // Re-fetch image if breed changed
        List<Dog__c> dogsWithBreedChange = new List<Dog__c>();
        for (Dog__c dog : newDogs) {
            Dog__c oldDog = oldMap.get(dog.Id);
            if (dog.Breed__c != oldDog.Breed__c) {
                dogsWithBreedChange.add(dog);
            }
        }

        if (!dogsWithBreedChange.isEmpty()) {
            System.enqueueJob(new DogImageFetchQueueable(dogsWithBreedChange));
        }
    }

    /**
     * Enforces composite unique constraint: (Shelter_Facility__c, Name)
     * No two dogs with the same name can exist in the same shelter.
     */
    private void validateUniqueDogNamePerShelter(List<Dog__c> dogs, Map<Id, Dog__c> oldMap) {
        Set<Id> shelterIds = new Set<Id>();
        Set<String> dogNames = new Set<String>();

        for (Dog__c dog : dogs) {
            shelterIds.add(dog.Shelter_Facility__c);
            dogNames.add(dog.Name);
        }

        // Query existing dogs in these shelters with these names
        Map<String, Dog__c> existingDogs = new Map<String, Dog__c>();
        for (Dog__c existing : [
            SELECT Id, Shelter_Facility__c, Name
            FROM   Dog__c
            WHERE  Shelter_Facility__c IN :shelterIds
            AND    Name IN :dogNames
        ]) {
            existingDogs.put(existing.Shelter_Facility__c + '-' + existing.Name, existing);
        }

        // Validate: each (Shelter, Name) combination should be unique
        for (Dog__c dog : dogs) {
            String key = dog.Shelter_Facility__c + '-' + dog.Name;

            // Skip validation if this is an update and only the name hasn't changed
            if (oldMap != null && oldMap.containsKey(dog.Id)) {
                Dog__c old = oldMap.get(dog.Id);
                if (old.Shelter_Facility__c == dog.Shelter_Facility__c && old.Name == dog.Name) {
                    continue; // No change, skip validation
                }
            }

            // Check if a different dog with this shelter+name already exists
            if (existingDogs.containsKey(key)) {
                Dog__c existing = existingDogs.get(key);
                if (existing.Id != dog.Id) { // Only error if it's a different dog
                    dog.addError('A dog named "' + dog.Name + '" already exists in this shelter. Dog names must be unique within each shelter.');
                }
            }
        }
    }
}
