/**
 * Callout service for the Dog CEO public API.
 * Named Credential "DogCeoApi" stores the base URL, keeping this class
 * environment-agnostic and free of hardcoded secrets.
 *
 * API contract: GET /breed/{breed}/images/random
 * Response:     {"message": "<img_url>", "status": "success"}
 */
public class DogImageService {

    private static final String BREED_IMAGE_PATH = '/breed/{0}/images/random';

    public static String fetchRandomImageByBreed(String breed) {
        if (String.isBlank(breed)) return null;

        String path = String.format(BREED_IMAGE_PATH,
                        new List<String>{ EncodingUtil.urlEncode(breed.toLowerCase().trim(), 'UTF-8') });

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:DogCeoApi' + path);
        req.setMethod('GET');
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            System.debug(LoggingLevel.WARN,
                'DogImageService: unexpected status ' + res.getStatusCode() + ' for breed=' + breed);
            return null;
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return 'success'.equals(body.get('status')) ? (String) body.get('message') : null;
    }
}
