/**
 * PUBLIC PORTAL CONTROLLER - No row-level security
 * Used by guest users on the adoption portal
 * Returns ALL available dogs regardless of shelter assignment
 */
public without sharing class PublicDogAdoptionController {

    static final Integer DEFAULT_PAGE_SIZE = 12;

    @AuraEnabled(cacheable=true)
    public static DogPageResult getAvailableDogs(
        String  searchTerm,
        Integer pageNumber,
        Integer pageSize
    ) {
        Integer ps     = (pageSize   != null && pageSize   > 0) ? pageSize   : DEFAULT_PAGE_SIZE;
        Integer pn     = (pageNumber != null && pageNumber > 0) ? pageNumber : 1;
        Integer offset = (pn - 1) * ps;

        Integer      total;
        List<Dog__c> dogs;

        if (String.isBlank(searchTerm)) {
            total = [SELECT COUNT() FROM Dog__c WHERE Status__c = 'Available'];
            dogs  = [
                SELECT Id, Name, Breed__c, Age__c, Image_URL__c,
                       Description__c, Status__c,
                       Shelter_Facility__r.Name, Shelter_Facility__r.Region__c
                FROM   Dog__c
                WHERE  Status__c = 'Available'
                ORDER BY CreatedDate DESC
                LIMIT  :ps OFFSET :offset
            ];
        } else {
            String sp = '%' + searchTerm.trim() + '%';
            total = [
                SELECT COUNT() FROM Dog__c
                WHERE  Status__c = 'Available'
                AND    (Name LIKE :sp OR Breed__c LIKE :sp)
            ];
            dogs  = [
                SELECT Id, Name, Breed__c, Age__c, Image_URL__c,
                       Description__c, Status__c,
                       Shelter_Facility__r.Name, Shelter_Facility__r.Region__c
                FROM   Dog__c
                WHERE  Status__c = 'Available'
                AND    (Name LIKE :sp OR Breed__c LIKE :sp)
                ORDER BY CreatedDate DESC
                LIMIT  :ps OFFSET :offset
            ];
        }

        DogPageResult result = new DogPageResult();
        result.dogs       = dogs;
        result.total      = total;
        result.pageNumber = pn;
        result.pageSize   = ps;
        result.hasNext    = (offset + ps) < total;
        result.hasPrev    = pn > 1;
        return result;
    }

    @AuraEnabled
    public static Id requestAdoption(
        Id dogId, String adopterName, String adopterEmail, String adopterPhone
    ) {
        List<Adoption_Request__c> active = [
            SELECT Id FROM Adoption_Request__c
            WHERE  Dog__c = :dogId AND Status__c != 'Rejected'
            LIMIT  1
        ];
        if (!active.isEmpty()) {
            throw new AuraHandledException(
                'An active adoption request already exists for this dog.'
            );
        }

        Dog__c dog = [
            SELECT Shelter_Facility__r.OwnerId
            FROM   Dog__c
            WHERE  Id = :dogId
            LIMIT  1
        ];

        Adoption_Request__c request = new Adoption_Request__c(
            Dog__c           = dogId,
            Adopter_Name__c  = adopterName,
            Adopter_Email__c = adopterEmail,
            Adopter_Phone__c = adopterPhone,
            Status__c        = 'Submitted',
            Request_Date__c  = Date.today(),
            Shelter_Owner__c = dog.Shelter_Facility__r.OwnerId
        );
        insert request;

        Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();
        submitReq.setObjectId(request.Id);
        submitReq.setSubmitterId(dog.Shelter_Facility__r.OwnerId);
        submitReq.setComments('Adoption request submitted via portal.');
        Approval.process(submitReq);

        return request.Id;
    }

    public class DogPageResult {
        @AuraEnabled public List<Dog__c> dogs;
        @AuraEnabled public Integer      total;
        @AuraEnabled public Integer      pageNumber;
        @AuraEnabled public Integer      pageSize;
        @AuraEnabled public Boolean      hasNext;
        @AuraEnabled public Boolean      hasPrev;
    }
}
