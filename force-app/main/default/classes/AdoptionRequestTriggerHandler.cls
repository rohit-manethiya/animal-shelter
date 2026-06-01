public class AdoptionRequestTriggerHandler extends TriggerHandler {

    private List<Adoption_Request__c> newRequests;
    private Map<Id, Adoption_Request__c> oldMap;

    public AdoptionRequestTriggerHandler() {
        this.newRequests = (List<Adoption_Request__c>) Trigger.new;
        this.oldMap      = (Map<Id, Adoption_Request__c>) Trigger.oldMap;
    }

    protected override void afterInsert() {
        syncDogStatus(newRequests, null);
        AdoptionEmailService.sendOnSubmission(newRequests);
    }

    protected override void afterUpdate() {
        syncDogStatus(newRequests, oldMap);
        updateAdoptionStage(newRequests, oldMap);
        AdoptionEmailService.sendOnStatusChange(newRequests, oldMap);
    }

    /**
     * Keeps Dog__c.Status__c in sync with the lifecycle of its adoption request.
     *
     * Lifecycle transitions driven here:
     *   Submitted  → Dog becomes "Pending Adoption"
     *   Approved   → Dog becomes "Adopted"
     *   Rejected   → Dog becomes "Available" again
     *
     * Note: if multiple requests exist for one dog (shouldn't happen with current
     * validation, but defensive), Approved always wins over Rejected in the same batch.
     */
    private void syncDogStatus(
        List<Adoption_Request__c> requests,
        Map<Id, Adoption_Request__c> oldMap
    ) {
        Map<Id, String> dogStatusUpdates = new Map<Id, String>();

        for (Adoption_Request__c req : requests) {
            String oldStatus = oldMap != null ? oldMap.get(req.Id).Status__c : null;

            if (statusChanged(req.Status__c, oldStatus, 'Submitted')) {
                dogStatusUpdates.put(req.Dog__c, 'Pending Adoption');
            }
            if (statusChanged(req.Status__c, oldStatus, 'Approved')) {
                dogStatusUpdates.put(req.Dog__c, 'Adopted');
            }
            if (statusChanged(req.Status__c, oldStatus, 'Rejected')) {
                // Don't overwrite an Approved transition in same batch
                if (!dogStatusUpdates.containsKey(req.Dog__c)) {
                    dogStatusUpdates.put(req.Dog__c, 'Available');
                }
            }
        }

        if (dogStatusUpdates.isEmpty()) return;

        List<Dog__c> dogsToUpdate = new List<Dog__c>();
        for (Id dogId : dogStatusUpdates.keySet()) {
            dogsToUpdate.add(new Dog__c(Id = dogId, Status__c = dogStatusUpdates.get(dogId)));
        }
        update dogsToUpdate;
    }

    private Boolean statusChanged(String newStatus, String oldStatus, String target) {
        return newStatus == target && (oldStatus == null || oldStatus != target);
    }

    /**
     * Updates Adoption_Stage__c based on Status__c transitions.
     * Stage field tracks the visible lifecycle: Submitted → Approved/Rejected.
     * Default value "Submitted" is set on creation.
     * Must perform DML update separately since this is an AFTER trigger.
     */
    private void updateAdoptionStage(
        List<Adoption_Request__c> requests,
        Map<Id, Adoption_Request__c> oldMap
    ) {
        List<Adoption_Request__c> recordsToUpdate = new List<Adoption_Request__c>();

        for (Adoption_Request__c req : requests) {
            String oldStatus = oldMap.get(req.Id).Status__c;

            if (statusChanged(req.Status__c, oldStatus, 'Approved')) {
                recordsToUpdate.add(new Adoption_Request__c(
                    Id = req.Id,
                    Adoption_Stage__c = 'Approved'
                ));
            } else if (statusChanged(req.Status__c, oldStatus, 'Rejected')) {
                recordsToUpdate.add(new Adoption_Request__c(
                    Id = req.Id,
                    Adoption_Stage__c = 'Rejected'
                ));
            }
        }

        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }
    }
}
