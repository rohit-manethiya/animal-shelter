// ─── Run this script AFTER createTestUsers.apex ──────────────────────────────
// Creates shelter facilities, dogs, and adoption requests.
// Transfers shelter ownership to the shelter owner users created earlier.

// ─── Look up shelter owner users ─────────────────────────────────────────────
String orgSuffix = UserInfo.getOrganizationId().substring(0, 8).toLowerCase();

Map<String, Id> userIdByUsername = new Map<String, Id>();
for (User u : [
    SELECT Id, Username
    FROM   User
    WHERE  Username IN (
        :('amsterdam.owner.' + orgSuffix + '@animalshelter.dev'),
        :('rotterdam.owner.' + orgSuffix + '@animalshelter.dev')
    )
]) {
    userIdByUsername.put(u.Username, u.Id);
}

Id amsterdamOwnerId = userIdByUsername.get('amsterdam.owner.' + orgSuffix + '@animalshelter.dev');
Id rotterdamOwnerId = userIdByUsername.get('rotterdam.owner.' + orgSuffix + '@animalshelter.dev');

if (amsterdamOwnerId == null || rotterdamOwnerId == null) {
    throw new IllegalArgumentException('Shelter owner users not found. Run createTestUsers.apex first.');
}

// ─── Shelter Facilities ───────────────────────────────────────────────────────
List<Shelter_Facility__c> facilities = new List<Shelter_Facility__c>{
    new Shelter_Facility__c(
        Name            = 'Amsterdam Shelter',
        Region__c       = 'Netherlands',
        Endpoint_URL__c = 'https://httpbin.org/post',
        Active__c       = true,
        OwnerId         = amsterdamOwnerId
    ),
    new Shelter_Facility__c(
        Name            = 'Rotterdam Shelter',
        Region__c       = 'Netherlands',
        Endpoint_URL__c = 'https://httpbin.org/post',
        Active__c       = true,
        OwnerId         = rotterdamOwnerId
    )
};
insert facilities;

Id amsterdamId = facilities[0].Id;
Id rotterdamId = facilities[1].Id;

System.debug('✔ Facilities inserted: ' + facilities.size());

// ─── Dogs ─────────────────────────────────────────────────────────────────────
List<Dog__c> dogs = new List<Dog__c>{
    new Dog__c(
        Name                = 'Buddy',
        Breed__c            = 'labrador',
        Age__c              = 3,
        Status__c           = 'Available',
        Shelter_Facility__c = amsterdamId,
        Description__c      = 'Friendly and energetic. Loves fetch and swimming.'
    ),
    new Dog__c(
        Name                = 'Bella',
        Breed__c            = 'beagle',
        Age__c              = 2,
        Status__c           = 'Available',
        Shelter_Facility__c = amsterdamId,
        Description__c      = 'Curious and gentle. Great with kids.'
    ),
    new Dog__c(
        Name                = 'Max',
        Breed__c            = 'husky',
        Age__c              = 4,
        Status__c           = 'Available',
        Shelter_Facility__c = amsterdamId,
        Description__c      = 'Playful and loyal. Needs daily exercise.'
    ),
    new Dog__c(
        Name                = 'Luna',
        Breed__c            = 'poodle',
        Age__c              = 1,
        Status__c           = 'Available',
        Shelter_Facility__c = rotterdamId,
        Description__c      = 'Smart and affectionate. Easy to train.'
    ),
    new Dog__c(
        Name                = 'Charlie',
        Breed__c            = 'boxer',
        Age__c              = 5,
        Status__c           = 'Available',
        Shelter_Facility__c = rotterdamId,
        Description__c      = 'Calm and protective. Good guard dog.'
    ),
    new Dog__c(
        Name                = 'Daisy',
        Breed__c            = 'dalmatian',
        Age__c              = 3,
        Status__c           = 'Available',
        Shelter_Facility__c = rotterdamId,
        Description__c      = 'Active and social. Loves long walks.'
    )
};
insert dogs;

System.debug('✔ Dogs inserted: ' + dogs.size());
System.debug('  → DogImageFetchQueueable will populate Image_URL__c asynchronously.');

// ─── Adoption Requests ────────────────────────────────────────────────────────
// Shelter_Owner__c must be set so the approval process routes to the right approver.
List<Adoption_Request__c> requests = new List<Adoption_Request__c>{
    new Adoption_Request__c(
        Dog__c           = dogs[0].Id,    // Buddy – Amsterdam
        Adopter_Name__c  = 'John Doe',
        Adopter_Email__c = 'johndoe@example.com',
        Adopter_Phone__c = '+31-612345678',
        Status__c        = 'Submitted',
        Request_Date__c  = Date.today(),
        Notes__c         = 'Interested in Buddy for a family with two kids.',
        Shelter_Owner__c = amsterdamOwnerId
    ),
    new Adoption_Request__c(
        Dog__c           = dogs[3].Id,    // Luna – Rotterdam
        Adopter_Name__c  = 'Jane Smith',
        Adopter_Email__c = 'janesmith@example.com',
        Adopter_Phone__c = '+31-698765432',
        Status__c        = 'Submitted',
        Request_Date__c  = Date.today(),
        Notes__c         = 'Looking for a small easy-to-train dog for an apartment.',
        Shelter_Owner__c = rotterdamOwnerId
    )
};
insert requests;

System.debug('✔ Adoption requests inserted: ' + requests.size());
System.debug('  → Buddy and Luna status is now: Pending Adoption');

// Submit to Salesforce Approval Process — creates ProcessInstance + ProcessInstanceWorkitem
// so the LWC approval inbox and the standard Approval History panel both work.
for (Adoption_Request__c req : requests) {
    Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();
    submitReq.setObjectId(req.Id);
    submitReq.setComments('Test data: adoption request submitted via data loader.');
    Approval.process(submitReq);
}
System.debug('  → Both requests submitted to Approval Process.');

// ─── Summary ─────────────────────────────────────────────────────────────────
System.debug('');
System.debug('════════════════════════════════════════════════════════');
System.debug('TEST SCENARIO READY');
System.debug('════════════════════════════════════════════════════════');
System.debug('System Admin    : use your current org login');
System.debug('Amsterdam Owner : amsterdam.owner.' + orgSuffix + '@animalshelter.dev  /  Shelter@12345');
System.debug('Rotterdam Owner : rotterdam.owner.' + orgSuffix + '@animalshelter.dev  /  Shelter@12345');
System.debug('');
System.debug('CURRENT DATA');
System.debug('Amsterdam Shelter → Buddy (Pending), Bella (Available), Max (Available)');
System.debug('Rotterdam Shelter → Luna (Pending), Charlie (Available), Daisy (Available)');
System.debug('');
System.debug('NOTE: Set Shelter_Facility__c OWD to Private in Sharing Settings');
System.debug('      to enforce shelter-level record visibility for owners.');
System.debug('════════════════════════════════════════════════════════');
