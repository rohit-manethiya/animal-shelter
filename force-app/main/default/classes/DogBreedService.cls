public with sharing class DogBreedService {

    @AuraEnabled(cacheable=true)
    public static List<BreedOption> getBreeds() {
        List<BreedOption> options = new List<BreedOption>();
        for (Dog_Breed__mdt breed : [
            SELECT Label, Sub_Breeds__c
            FROM   Dog_Breed__mdt
            ORDER BY Label ASC
        ]) {
            options.add(new BreedOption(breed.Label));
        }
        return options;
    }

    public class BreedOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public BreedOption(String name) {
            this.label = name;
            this.value = name;
        }
    }
}
