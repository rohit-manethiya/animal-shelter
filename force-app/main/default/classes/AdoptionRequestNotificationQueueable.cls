/**
 * Queueable job: forwards a new adoption request to the shelter's external database.
 * Triggered on Adoption_Request__c insert, parallel to the email notification.
 *
 * Re-queries records here (not in the trigger) to resolve cross-object fields:
 *   Dog__r.Image_URL__c and Dog__r.Shelter_Facility__r.Endpoint_URL__c
 */
public class AdoptionRequestNotificationQueueable implements Queueable, Database.AllowsCallouts {

    private final Set<Id> requestIds;

    public AdoptionRequestNotificationQueueable(List<Adoption_Request__c> requests) {
        this.requestIds = new Map<Id, Adoption_Request__c>(requests).keySet();
    }

    public void execute(QueueableContext ctx) {
        List<Adoption_Request__c> requests = [
            SELECT Id, Name, Status__c, Request_Date__c, Notes__c,
                   Adopter_Name__c, Adopter_Email__c, Adopter_Phone__c,
                   Dog__r.Id, Dog__r.Name, Dog__r.Breed__c, Dog__r.Image_URL__c,
                   Dog__r.Shelter_Facility__r.Endpoint_URL__c,
                   Dog__r.Shelter_Facility__r.Active__c,
                   Dog__r.Shelter_Facility__r.Name
            FROM   Adoption_Request__c
            WHERE  Id IN :requestIds
        ];

        for (Adoption_Request__c req : requests) {
            if (req.Dog__r?.Shelter_Facility__r == null) continue;
            if (!req.Dog__r.Shelter_Facility__r.Active__c) continue;
            ShelterNotificationService.notifyShelterOfAdoptionRequest(
                req,
                req.Dog__r.Shelter_Facility__r.Endpoint_URL__c
            );
        }
    }
}
