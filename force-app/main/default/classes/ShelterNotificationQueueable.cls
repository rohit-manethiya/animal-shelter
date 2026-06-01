/**
 * Queueable job: forwards each new dog record to its associated shelter's external system.
 *
 * Dogs are re-queried here to pick up the Image_URL__c written by DogImageFetchQueueable
 * and to resolve Shelter_Facility__r.Endpoint_URL__c for dynamic routing.
 *
 * Scalability: the endpoint comes from the Shelter_Facility__c record, not code.
 * Adding a new regional shelter = one new Salesforce record, zero deployments.
 */
public class ShelterNotificationQueueable implements Queueable, Database.AllowsCallouts {

    private final Set<Id> dogIds;

    public ShelterNotificationQueueable(List<Dog__c> dogs) {
        this.dogIds = new Map<Id, Dog__c>(dogs).keySet();
    }

    public void execute(QueueableContext ctx) {
        List<Dog__c> dogs = [
            SELECT Id, Name, Breed__c, Age__c, Image_URL__c, Status__c,
                   Shelter_Facility__r.Endpoint_URL__c,
                   Shelter_Facility__r.Active__c
            FROM   Dog__c
            WHERE  Id IN :dogIds
        ];

        for (Dog__c dog : dogs) {
            if (dog.Shelter_Facility__r == null || !dog.Shelter_Facility__r.Active__c) continue;
            ShelterNotificationService.notifyShelter(dog, dog.Shelter_Facility__r.Endpoint_URL__c);
        }
    }
}
