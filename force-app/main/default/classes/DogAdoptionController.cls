public with sharing class DogAdoptionController {

    // ─── Available dogs (paginated + server-side search) ─────────────────────

    static final Integer DEFAULT_PAGE_SIZE = 12;

    /**
     * Returns one page of available dogs with a total count for pagination UI.
     * Search is performed on the server so only matching records cross the wire.
     * Debounce the search input on the LWC side to avoid per-keystroke callouts.
     * Cacheable: each (searchTerm, pageNumber) combination is cached, so revisiting
     * the same page hits the cache without a server round-trip.
     */
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
        result.dogs      = dogs;
        result.total     = total;
        result.pageNumber= pn;
        result.pageSize  = ps;
        result.hasNext   = (offset + ps) < total;
        result.hasPrev   = pn > 1;
        return result;
    }

    public class DogPageResult {
        @AuraEnabled public List<Dog__c> dogs;
        @AuraEnabled public Integer      total;
        @AuraEnabled public Integer      pageNumber;
        @AuraEnabled public Integer      pageSize;
        @AuraEnabled public Boolean      hasNext;
        @AuraEnabled public Boolean      hasPrev;
    }

    // ─── Submit adoption request ──────────────────────────────────────────────

    /**
     * Creates an Adoption_Request__c and immediately submits it to the
     * standard Salesforce Approval Process.
     *
     * Shelter_Owner__c is populated here so the approval process can route
     * directly to the correct shelter owner via relatedUserField.
     */
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
        submitReq.setSubmitterId(UserInfo.getUserId());
        submitReq.setComments('Adoption request submitted via portal.');
        Approval.process(submitReq);

        return request.Id;
    }

    // ─── Pending requests (approval inbox) ───────────────────────────────────

    /**
     * Returns adoption requests currently awaiting the logged-in user's approval.
     * Queries ProcessInstanceWorkitem so only genuine approval queue items are shown.
     * with sharing ensures shelter owners only see their own shelter's requests.
     */
    @AuraEnabled(cacheable=true)
    public static List<PendingRequest> getPendingRequests() {
        Map<Id, Id> requestToWorkItem = new Map<Id, Id>();
        for (ProcessInstanceWorkitem wi : [
            SELECT Id, ProcessInstance.TargetObjectId
            FROM   ProcessInstanceWorkitem
            WHERE  ActorId = :UserInfo.getUserId()
              AND  ProcessInstance.Status = 'Pending'
        ]) {
            requestToWorkItem.put((Id) wi.ProcessInstance.TargetObjectId, wi.Id);
        }

        List<PendingRequest> result = new List<PendingRequest>();
        if (requestToWorkItem.isEmpty()) return result;

        for (Adoption_Request__c req : [
            SELECT Id, Name, Request_Date__c,
                   Adopter_Name__c, Adopter_Email__c, Adopter_Phone__c,
                   Dog__r.Name, Dog__r.Breed__c
            FROM   Adoption_Request__c
            WHERE  Id IN :requestToWorkItem.keySet()
            ORDER BY Request_Date__c ASC
        ]) {
            result.add(new PendingRequest(req, requestToWorkItem.get(req.Id)));
        }
        return result;
    }

    // ─── Approve / reject via standard approval process ───────────────────────

    /**
     * Approves or rejects an adoption request through the Salesforce Approval Process.
     * action: 'Approve' or 'Reject' (Approval API values).
     *
     * The approval process field-update actions set Status__c, which fires
     * AdoptionRequestTrigger → syncDogStatus() + AdoptionEmailService.
     */
    @AuraEnabled
    public static void processAdoptionRequest(Id workItemId, String action) {
        if (action != 'Approve' && action != 'Reject') {
            throw new AuraHandledException('Invalid action: ' + action);
        }

        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
        req.setWorkitemId(workItemId);
        req.setAction(action);
        req.setComments(action + 'd via Adoption Portal');

        Approval.ProcessResult result = Approval.process(req);
        if (!result.isSuccess()) {
            throw new AuraHandledException(result.getErrors()[0].getMessage());
        }
    }

    // ─── Wrapper ──────────────────────────────────────────────────────────────

    public class PendingRequest {
        @AuraEnabled public Id     requestId;
        @AuraEnabled public Id     workItemId;
        @AuraEnabled public String name;
        @AuraEnabled public String adopterName;
        @AuraEnabled public String adopterEmail;
        @AuraEnabled public String adopterPhone;
        @AuraEnabled public Date   requestDate;
        @AuraEnabled public String dogName;
        @AuraEnabled public String breed;

        public PendingRequest(Adoption_Request__c req, Id workItemId) {
            this.requestId    = req.Id;
            this.workItemId   = workItemId;
            this.name         = req.Name;
            this.adopterName  = req.Adopter_Name__c;
            this.adopterEmail = req.Adopter_Email__c;
            this.adopterPhone = req.Adopter_Phone__c;
            this.requestDate  = req.Request_Date__c;
            this.dogName      = req.Dog__r?.Name;
            this.breed        = req.Dog__r?.Breed__c;
        }
    }
}
