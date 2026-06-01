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

        Map<String, Object> payload = new Map<String, Object>{
            'salesforceId' => dog.Id,
            'name'         => dog.Name,
            'breed'        => dog.Breed__c,
            'age'          => dog.Age__c,
            'imageUrl'     => dog.Image_URL__c,
            'status'       => dog.Status__c,
            'event'        => 'DOG_RECORD_CREATED'
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpointUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
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
