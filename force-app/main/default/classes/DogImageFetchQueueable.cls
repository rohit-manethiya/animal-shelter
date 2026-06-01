/**
 * Queueable job: fetches a random image from Dog CEO API for each new dog,
 * persists the URL back to Dog__c.Image_URL__c, then chains to shelter notification.
 *
 * Why Queueable (not @future)?
 *   - Supports chaining — we can enqueue ShelterNotificationQueueable once images are saved
 *   - Accepts SObject parameters directly (no JSON serialisation workaround)
 *   - Better error monitoring via AsyncApexJob
 *
 * Bulk note: one callout per dog. SF governor allows 100 callouts/transaction,
 * so batches > 100 need chunking — flagged as a future improvement.
 */
public class DogImageFetchQueueable implements Queueable, Database.AllowsCallouts {

    private final List<Dog__c> dogs;

    public DogImageFetchQueueable(List<Dog__c> dogs) {
        this.dogs = dogs;
    }

    public void execute(QueueableContext ctx) {
        List<Dog__c> toUpdate = new List<Dog__c>();

        for (Dog__c dog : dogs) {
            String imageUrl = DogImageService.fetchRandomImageByBreed(dog.Breed__c);
            if (imageUrl != null) {
                toUpdate.add(new Dog__c(Id = dog.Id, Image_URL__c = imageUrl));
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        // Chain: notify shelter regardless of image fetch success
        System.enqueueJob(new ShelterNotificationQueueable(dogs));
    }
}
