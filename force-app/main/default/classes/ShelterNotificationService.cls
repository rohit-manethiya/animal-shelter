/**
 * Forwards a new dog record to the associated shelter facility's external database.
 *
 * The endpoint is read from Shelter_Facility__c.Endpoint_URL__c — this is the
 * key to horizontal scalability: adding a new regional shelter requires only a
 * new record, not a code change.
 *
 * Future improvement: replace direct HTTP with Platform Events or an ESB
 * (e.g. MuleSoft) to decouple Salesforce from individual shelter availability.
 */
public class ShelterNotificationService {

    public static void notifyShelter(Dog__c dog, String endpointUrl) {
        if (String.isBlank(endpointUrl)) return;

        String payload = JSON.serialize(new Map<String, Object>{
            'salesforceDogId' => dog.Id,
            'name' => dog.Name,
            'breed' => dog.Breed__c,
            'age' => (Integer) dog.Age__c,
            'imageUrl' => dog.Image_URL__c,
            'status' => dog.Status__c,
            'originShelter' => dog.Shelter_Facility__r?.Name
        });

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpointUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            System.debug(LoggingLevel.ERROR,
                'ShelterNotificationService: failed for dog ' + dog.Id +
                ' → endpoint=' + endpointUrl + ' status=' + res.getStatusCode());
            // TODO: publish a Platform Event here for a retry / dead-letter queue
        }
    }
}
