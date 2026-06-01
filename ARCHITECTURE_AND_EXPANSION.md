# Adyen Animal Shelter - Architecture Diagrams & India Expansion Strategy

## Part 1: Assignment 1 - Current Architecture Deep Dive

### System Architecture - Component Interaction Diagram

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                          END USER INTERACTIONS                                   │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────┐     ┌──────────────────────────────────┐  │
│  │   1. ADOPTION LIST VIEW          │     │  2. ADOPTION REQUEST SUBMISSION  │  │
│  │                                  │     │                                  │  │
│  │  1.1 User visits Dogs tab        │     │  2.1 User clicks "Adopt" button  │  │
│  │  1.2 Browser loads LWC           │     │  2.2 Form modal opens            │  │
│  │  1.3 Wire adapter fires          │     │  2.3 User fills form             │  │
│  │  1.4 Client-side caching enabled │     │  2.4 Submit button → Apex call   │  │
│  │  1.5 Grid displays dogs with     │     │  2.5 Validation on server       │  │
│  │      search/filter               │     │  2.6 Record created             │  │
│  │  1.6 Click dog card              │     │  2.7 Trigger fires              │  │
│  │                                  │     │  2.8 UI refreshes               │  │
│  └─────────────────────────────────┘     └──────────────────────────────────┘  │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────────────────────────────────────────┐
│                      SALESFORCE ORG (Data & Logic Tier)                         │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │ LWC COMPONENTS (User Interaction Layer)                                   │ │
│  │                                                                            │ │
│  │  ┌──────────────────────┐         ┌──────────────────────────────────┐   │ │
│  │  │ dogAdoptionList.js   │◄────────┤ getAvailableDogs() API           │   │ │
│  │  │ - Search filtering   │         │ @AuraEnabled(cacheable=true)     │   │ │
│  │  │ - Modal control      │         └──────────────────────────────────┘   │ │
│  │  │ - Async submission   │                                                │ │
│  │  └──────────┬───────────┘                                                │ │
│  │             │                                                             │ │
│  │             └──────────► requestAdoption(dogId, adopterInfo)             │ │
│  │                         @AuraEnabled                                      │ │
│  │                                                                            │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐   │ │
│  │  │ dogCard.js                                                       │   │ │
│  │  │ - Displays dog info (name, breed, age, image, shelter)          │   │ │
│  │  │ - Dispatch requestadoption custom event                         │   │ │
│  │  │ - Image error handling                                          │   │ │
│  │  └──────────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │ APEX CONTROLLERS (Business Logic & Data Access)                           │ │
│  │                                                                            │ │
│  │  ┌──────────────────────────────────────────────────────────────────────┐ │ │
│  │  │ DogAdoptionController                                               │ │ │
│  │  │                                                                      │ │ │
│  │  │ getAvailableDogs():                                                 │ │ │
│  │  │   SELECT * FROM Dog__c                                             │ │ │
│  │  │   WHERE Status = 'Available'                                       │ │ │
│  │  │   ORDER BY CreatedDate DESC                                        │ │ │
│  │  │   (Includes shelter relationship for display)                      │ │ │
│  │  │                                                                      │ │ │
│  │  │ requestAdoption(dogId, name, email, phone):                        │ │ │
│  │  │   1. Check for existing non-rejected request                       │ │ │
│  │  │   2. If found: throw AuraHandledException                          │ │ │
│  │  │   3. Else: create Adoption_Request__c (Status = Submitted)         │ │ │
│  │  │   4. insert record → TRIGGER FIRES                                 │ │ │
│  │  └──────────────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │ TRIGGER FRAMEWORK (Event-Driven Logic)                                    │ │
│  │                                                                            │ │
│  │  ┌─────────────────────────────────────┐                                │ │
│  │  │ DogTrigger (after insert)           │                                │ │
│  │  │                                     │                                │ │
│  │  │ new DogTriggerHandler().run()       │                                │ │
│  │  │   └─► afterInsert():                │                                │ │
│  │  │       - Enqueue DogImageFetch       │                                │ │
│  │  │         Queueable                   │                                │ │
│  │  └─────────────────────────────────────┘                                │ │
│  │                                                                            │ │
│  │  ┌────────────────────────────────────────────────┐                      │ │
│  │  │ AdoptionRequestTrigger (after insert/update)   │                      │ │
│  │  │                                                │                      │ │
│  │  │ new AdoptionRequestTriggerHandler().run()      │                      │ │
│  │  │   └─► afterInsert():                           │                      │ │
│  │  │       syncDogStatus(newRequests)               │                      │ │
│  │  │       If Status='Submitted': Dog='Pending'     │                      │ │
│  │  │                                                │                      │ │
│  │  │   └─► afterUpdate():                           │                      │ │
│  │  │       syncDogStatus(newRequests, oldMap)       │                      │ │
│  │  │       If Status='Approved': Dog='Adopted'      │                      │ │
│  │  │       If Status='Rejected': Dog='Available'    │                      │ │
│  │  └────────────────────────────────────────────────┘                      │ │
│  │                                                                            │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │ ASYNCHRONOUS PROCESSING (Queueable Jobs)                                  │ │
│  │                                                                            │ │
│  │  ┌──────────────────────────────────────────────────────────────────────┐ │ │
│  │  │ DogImageFetchQueueable (implements Queueable, AllowsCallouts)        │ │ │
│  │  │                                                                      │ │ │
│  │  │ execute(ctx):                                                       │ │ │
│  │  │   For each dog:                                                     │ │ │
│  │  │     imageUrl = DogImageService.fetchRandomImageByBreed(breed)       │ │ │
│  │  │     If imageUrl != null:                                            │ │ │
│  │  │       update Dog__c set Image_URL__c = imageUrl                     │ │ │
│  │  │                                                                      │ │ │
│  │  │   System.enqueueJob(new ShelterNotificationQueueable(dogs))          │ │ │
│  │  │   └─► CHAIN next job                                                │ │ │
│  │  └──────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                            │ │
│  │  ┌──────────────────────────────────────────────────────────────────────┐ │ │
│  │  │ ShelterNotificationQueueable (implements Queueable, AllowsCallouts)  │ │ │
│  │  │                                                                      │ │ │
│  │  │ execute(ctx):                                                       │ │ │
│  │  │   Re-query Dog with Shelter_Facility__r relationship                │ │ │
│  │  │   For each dog:                                                     │ │ │
│  │  │     If Shelter is Active:                                           │ │ │
│  │  │       ShelterNotificationService.notifyShelter(dog, endpoint)        │ │ │
│  │  │       └─► HTTP POST to shelter with dog metadata                    │ │ │
│  │  │                                                                      │ │ │
│  │  │   [Future: Publish Platform Event on failure for retry queue]       │ │ │
│  │  └──────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                            │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │ EXTERNAL API INTEGRATION (Service Layer)                                  │ │
│  │                                                                            │ │
│  │  ┌──────────────────────────────────────────┐                            │ │
│  │  │ DogImageService                          │                            │ │
│  │  │                                          │                            │ │
│  │  │ fetchRandomImageByBreed(breed):          │                            │ │
│  │  │   - URL encode breed name                │                            │ │
│  │  │   - Build endpoint: callout:DogCeoApi +  │                            │ │
│  │  │     /breed/{breed}/images/random         │                            │ │
│  │  │   - HTTP GET request                     │                            │ │
│  │  │   - Parse JSON response                  │                            │ │
│  │  │   - Return image URL or null             │                            │ │
│  │  │   - Error logging on failure             │                            │ │
│  │  └──────────────────────────────────────────┘                            │ │
│  │                                                                            │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐   │ │
│  │  │ ShelterNotificationService                                      │   │ │
│  │  │                                                                  │   │ │
│  │  │ notifyShelter(dog, endpoint):                                   │   │ │
│  │  │   - Build JSON payload:                                         │   │ │
│  │  │     {                                                           │   │ │
│  │  │       salesforceId, name, breed, age,                           │   │ │
│  │  │       imageUrl, status, event: DOG_RECORD_CREATED              │   │ │
│  │  │     }                                                           │   │ │
│  │  │   - HTTP POST to endpoint (config-driven)                       │   │ │
│  │  │   - Log success/failure                                         │   │ │
│  │  │   - [Future: Publish platform event on failure]                 │   │ │
│  │  └──────────────────────────────────────────────────────────────────┘   │ │
│  │                                                                            │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │ CONFIGURATION METADATA                                                    │ │
│  │                                                                            │ │
│  │  Named Credential: DogCeoApi                                              │ │
│  │  └─► Base URL: https://dog.ceo/api                                        │ │
│  │      No authentication (public API)                                        │ │
│  │                                                                            │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │ DATA MODEL (Custom Objects & Fields)                                      │ │
│  │                                                                            │ │
│  │  Shelter_Facility__c (Config - 1 record per shelter)                      │ │
│  │  ├─ Name, Region, Endpoint_URL, Active flag                              │ │
│  │  │                                                                         │ │
│  │  ├─► Dog__c (Master-Detail, 1..* relationship)                            │ │
│  │  │   ├─ Name, Breed, Age, Description, Image_URL, Status                 │ │
│  │  │   │                                                                    │ │
│  │  │   ├─► Adoption_Request__c (Master-Detail, 1..* relationship)           │ │
│  │  │       ├─ Adopter_Name, Adopter_Email, Adopter_Phone                   │ │
│  │  │       ├─ Status (Submitted/Approved/Rejected), Request_Date            │ │
│  │  │       └─ Notes                                                         │ │
│  │  │                                                                         │ │
│  │  └─ Indexes on Status fields for efficient querying                       │ │
│  │                                                                            │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────────────────────────────────────────┐
│               EXTERNAL SYSTEMS (Asynchronous, Non-Blocking)                      │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────┐    ┌──────────────────────────────┐   │
│  │ Dog CEO Public API                  │    │ Regional Shelter Databases   │   │
│  │ https://dog.ceo/api                 │    │ (Config-Driven Endpoints)    │   │
│  │                                     │    │                              │   │
│  │ GET /breed/{breed}/images/random    │    │ POST /adoption-sync          │   │
│  │                                     │    │      /adoption-update        │   │
│  │ Returns:                            │    │      /adoption-approve       │   │
│  │ {                                   │    │                              │   │
│  │   "message": "https://img...",      │    │ Accepts:                     │   │
│  │   "status": "success"               │    │ {                            │   │
│  │ }                                   │    │   "salesforceId": "a0A1...", │   │
│  │                                     │    │   "name": "Buddy",           │   │
│  │ ~100+ calls/minute (rate limit)     │    │   "breed": "labrador",       │   │
│  │ No authentication required          │    │   "age": 3,                  │   │
│  │                                     │    │   "imageUrl": "https://...", │   │
│  │ Used by: DogImageService            │    │   "status": "Available",     │   │
│  │                                     │    │   "event": "DOG_CREATED"     │   │
│  │                                     │    │ }                            │   │
│  │                                     │    │                              │   │
│  │                                     │    │ Used by: ShelterNotification │   │
│  │                                     │    │ Service (via Queueable)      │   │
│  │                                     │    │                              │   │
│  │                                     │    │ Examples:                    │   │
│  │                                     │    │ - https://httpbin.org/post   │   │
│  │                                     │    │ - https://api.shelter.nl/... │   │
│  │                                     │    │ - https://api.shelter.de/... │   │
│  │                                     │    │                              │   │
│  │ Resilience: Null return, logged     │    │ Resilience: Log errors,      │   │
│  │            image still created      │    │             publish event    │   │
│  └─────────────────────────────────────┘    │             for retry        │   │
│  │                                          └──────────────────────────────┘   │
│  │                                                                              │
│  └──────────────────────────────────────────────────────────────────────────────┘
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow Sequence Diagram

#### Scenario 1: New Dog Creation with Async Image Fetch

```
Timeline:
T=0s     ├─ Agent submits new Dog via UI/API
         │
T=0.1s   ├─ DogTrigger fires (after insert)
         │  └─ DogTriggerHandler.afterInsert()
         │     └─ System.enqueueJob(DogImageFetchQueueable)
         │        └─ Returns to user: "Dog created successfully"
         │
T=5-30s  ├─ DogImageFetchQueueable executes
         │  ├─ For dog[0]:
         │  │  └─ DogImageService.fetchRandomImageByBreed("labrador")
         │  │     ├─ HTTP GET to dog.ceo/api/breed/labrador/images/random
         │  │     ├─ Response: {"message": "https://images.dog.ceo/...", "status": "success"}
         │  │     └─ Return image URL
         │  │
         │  ├─ For dog[1..n]:
         │  │  └─ [Repeat for all dogs]
         │  │
         │  ├─ update Dog__c set Image_URL__c where Id in (...) [batch update]
         │  │  └─ Persists image URLs to database
         │  │
         │  └─ System.enqueueJob(ShelterNotificationQueueable(dogs))
         │     └─ Chain next job
         │
T=35-60s ├─ ShelterNotificationQueueable executes
         │  ├─ Re-query: SELECT * FROM Dog WHERE Id IN (:dogIds)
         │  │            WITH Shelter_Facility__r
         │  │  └─ Fetch Image_URL__c (now populated) and Endpoint_URL__c
         │  │
         │  ├─ For each dog with active shelter:
         │  │  └─ ShelterNotificationService.notifyShelter(dog, endpoint)
         │  │     ├─ Build JSON:
         │  │     │  {
         │  │     │    "salesforceId": "a0A1x00000...",
         │  │     │    "name": "Buddy",
         │  │     │    "breed": "labrador",
         │  │     │    "age": 3,
         │  │     │    "imageUrl": "https://images.dog.ceo/...",
         │  │     │    "status": "Available",
         │  │     │    "event": "DOG_RECORD_CREATED"
         │  │     │  }
         │  │     │
         │  │     └─ HTTP POST to Shelter_Facility__c.Endpoint_URL__c
         │  │        ├─ If status 200-299: Log SUCCESS
         │  │        └─ Else: Log ERROR (later: publish event for retry)
         │  │
         │  └─ Job completes
         │
T=65s    └─ Dog record fully hydrated (image, notification sent)
```

#### Scenario 2: Adoption Request with Status Sync

```
Timeline:
T=0s     ├─ User fills adoption form (name, email, phone)
         │  └─ Calls dogAdoptionList.submitAdoptionRequest()
         │
T=0.1s   ├─ LWC calls: DogAdoptionController.requestAdoption(dogId, ...)
         │  ├─ Server-side validation:
         │  │  └─ Query: SELECT * FROM Adoption_Request__c
         │  │           WHERE Dog__c = :dogId AND Status != 'Rejected'
         │  │  └─ If found: throw AuraHandledException
         │  │     └─ User sees: "Active request already exists"
         │  │
         │  ├─ Else: CREATE Adoption_Request__c
         │  │  └─ insert request (Status = 'Submitted')
         │  │
         │  └─ TRIGGER FIRES: AdoptionRequestTrigger (after insert)
         │
T=0.2s   ├─ AdoptionRequestTriggerHandler.afterInsert()
         │  └─ syncDogStatus(newRequests, null)
         │     ├─ For each request with Status='Submitted':
         │     │  └─ dogStatusUpdates.put(dogId, 'Pending Adoption')
         │     │
         │     └─ update Dog__c in batch
         │        └─ Dog.Status changes: 'Available' → 'Pending Adoption'
         │
T=0.3s   ├─ Response to LWC: Request created successfully
         │  └─ LWC shows: "Adoption request submitted!"
         │
T=0.4s   ├─ LWC calls: refreshApex(wiredDogsResult)
         │  └─ Clears client-side cache
         │
T=0.5s   ├─ Wire adapter re-executes: getAvailableDogs()
         │  └─ Query: SELECT * FROM Dog__c WHERE Status = 'Available'
         │     (Dog no longer matches filter due to status change)
         │
T=0.6s   ├─ Response to LWC: Updated dog list (dog removed)
         │  └─ Component re-renders
         │     └─ Dog card disappears from UI
         │
T=0.7s   └─ User sees: Dog no longer in adoption list (now "Pending Adoption")
```

---

## Part 2: Assignment 2 - India Expansion & Data Residency Architecture

### Business Problem

**Scenario**: Adyen Animal Shelter expands to India, opening a regional facility.

**Regulatory Requirement**: Due to India's data residency regulations (similar to GDPR), all personally identifiable information (PII) related to animals and adopters must be stored on infrastructure physically located within India. This data **cannot** be replicated to the global Salesforce org.

**Challenge**: 
- Global Salesforce users (admins, shelter managers) need to manage India shelter operations
- But sensitive data (adopter names, emails, phone numbers, animal health records) must stay in India
- Need a seamless user experience without data leaving India

### Proposed Architecture

#### High-Level Diagram

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                              GLOBAL SALESFORCE ORG                            │
│                            (US/EU hosted, primary)                            │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ Users: Global Admins, Shelter Managers                                  │ │
│  │                                                                         │ │
│  │ Data Stored:                                                            │ │
│  │  ✓ Non-PII metadata (dog breed, age, image URL, status)               │ │
│  │  ✓ Adoption workflow metadata (request ID, status, timestamps)        │ │
│  │  ✗ PII NEVER stored here (adopter names, emails, phones, addresses)   │ │
│  │                                                                         │ │
│  │ ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │ │ UI Layer (LWC Components)                                       │   │ │
│  │ │  dogAdoptionList, dogCard, adoption forms                       │   │ │
│  │ │  All searches filtered by shelter context                       │   │ │
│  │ └──────────────────┬──────────────────────────────────────────────┘   │ │
│  │                    │                                                   │ │
│  │ ┌──────────────────▼──────────────────────────────────────────────┐   │ │
│  │ │ Apex Controllers                                                │   │ │
│  │ │  DogAdoptionController                                          │   │ │
│  │ │  - getAvailableDogs() → calls middleware API                    │   │ │
│  │ │  - requestAdoption() → calls middleware API                     │   │ │
│  │ │                                                                 │   │ │
│  │ │ AuthenticationService                                           │   │ │
│  │ │  - obtainJWT() → authenticate to middleware                     │   │ │
│  │ │  - refreshToken() → handle token expiry                         │   │ │
│  │ └──────────────────┬──────────────────────────────────────────────┘   │ │
│  │                    │                                                   │ │
│  │ ┌──────────────────▼──────────────────────────────────────────────┐   │ │
│  │ │ Middleware Integration (Rest Templates, HTTP Callouts)          │   │ │
│  │ │                                                                 │   │ │
│  │ │  MiddlewareCalloutService                                       │   │ │
│  │ │  - getDogsFromIndia() → REST GET /dogs                          │   │ │
│  │ │  - getDogDetailsFromIndia(id) → REST GET /dogs/:id              │   │ │
│  │ │  - submitAdoptionToIndia(...) → REST POST /adoptions            │   │ │
│  │ │                                                                 │   │ │
│  │ │  Error handling:                                                │   │ │
│  │ │  - Network failures logged                                       │   │ │
│  │ │  - Timeout handling (10s)                                        │   │ │
│  │ │  - Retry logic with exponential backoff                          │   │ │
│  │ └──────────────────┬──────────────────────────────────────────────┘   │ │
│  │                    │                                                   │ │
│  │ Named Credential:  │                                                   │ │
│  │  IndiaShelterMiddleware                                               │ │
│  │  └─ Base URL: https://india-shelter-api.adyen.local                   │ │
│  │     (AWS India region or equivalent)                                   │ │
│  └────────────────────┼───────────────────────────────────────────────────┘ │
│                       │ HTTPS (TLS 1.3)                                     │
│                       │ JWT token in Authorization header                   │
│                       │ (signed with regional private key)                  │
│                       │                                                     │
└───────────────────────┼─────────────────────────────────────────────────────┘
                        │
                        │ Encrypted Data Flow
                        │ ┌─────────────────────────────────┐
                        │ │ Request/Response Encryption:    │
                        │ │ - TLS 1.3 in transit            │
                        │ │ - Payload AES-256 at rest       │
                        │ │ - PII fields encrypted end-end  │
                        │ └─────────────────────────────────┘
                        ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                    INDIA MIDDLEWARE (Gateway/Proxy)                           │
│                 (AWS/Azure/GCP India Region, self-managed)                   │
│                                                                               │
│  Technology Stack: Java 17 + Spring Boot 3.x + Spring Security                │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ API Gateway (REST Endpoints)                                            │ │
│  │                                                                         │ │
│  │  POST /api/v1/auth/authenticate                                         │ │
│  │  └─ Input: {username, password}                                         │ │
│  │     Output: {jwt: "eyJhbGc...", expiresIn: 3600}                        │ │
│  │     Logic: Validate credentials, issue JWT signed with India key        │ │
│  │                                                                         │ │
│  │  GET /api/v1/dogs?shelterId=india-1                                     │ │
│  │  ├─ Validates JWT token                                                 │ │
│  │  ├─ Enforces shelter isolation (only return India dogs)                 │ │
│  │  ├─ Query: SELECT id, name, breed, age, status FROM Dogs               │ │
│  │  │         WHERE shelter_id = 'india-1' AND status = 'available'       │ │
│  │  ├─ Strip PII from response (no adopter data)                           │ │
│  │  └─ Return: [{ id, name, breed, age, image_url, status, shelter }]     │ │
│  │                                                                         │ │
│  │  GET /api/v1/dogs/:id?shelterId=india-1                                │ │
│  │  ├─ Validates JWT + shelter isolation                                   │ │
│  │  ├─ Query: SELECT * FROM Dogs WHERE id = :id AND shelter_id = :id      │ │
│  │  ├─ Response includes full dog details (but NOT adopter PII)            │ │
│  │  └─ Return: { id, name, breed, age, description, image_url, status }   │ │
│  │                                                                         │ │
│  │  POST /api/v1/adoptions                                                 │ │
│  │  ├─ Input:                                                              │ │
│  │  │  {                                                                   │ │
│  │  │    dogId: "india-dog-123",                                           │ │
│  │  │    adopterName: "John Doe",    ◄── PII                              │ │
│  │  │    adopterEmail: "john@...",   ◄── PII                              │ │
│  │  │    adopterPhone: "+91...",     ◄── PII                              │ │
│  │  │    sfAdoptionRequestId: "AR-0001",  ◄── non-PII reference            │ │
│  │  │    shelterId: "india-1"        ◄── context                          │ │
│  │  │  }                                                                   │ │
│  │  │                                                                     │ │
│  │  ├─ Validates JWT + shelter isolation                                   │ │
│  │  ├─ Encrypts PII fields (AES-256) before storing locally               │ │
│  │  ├─ Creates Adoption record locally:                                    │ │
│  │  │  INSERT INTO Adoptions (                                             │ │
│  │  │    dog_id, adopter_name_encrypted, adopter_email_encrypted,         │ │
│  │  │    adopter_phone_encrypted, sf_request_id, shelter_id, status       │ │
│  │  │  ) VALUES (...)                                                      │ │
│  │  │                                                                     │ │
│  │  ├─ Logs event: "Adoption created for SF request AR-0001"              │ │
│  │  ├─ Audit: who (SF user ID), when, what (adoption), where (India)     │ │
│  │  │                                                                     │ │
│  │  └─ Response: { adoptionId: "IND-ADO-001", status: "submitted" }       │ │
│  │                                                                         │ │
│  │  PATCH /api/v1/adoptions/:id/approve                                    │ │
│  │  ├─ Input: {shelterId, approverNotes}                                   │ │
│  │  ├─ Updates: adoption.status = 'approved'                               │ │
│  │  ├─ Notifies back to SF (non-blocking)                                  │ │
│  │  └─ Does NOT return PII to SF (only confirmation)                       │ │
│  │                                                                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ Security & Authentication Layer                                         │ │
│  │                                                                         │ │
│  │  JwtTokenProvider                                                       │ │
│  │  ├─ generateToken(user) → signed JWT (RSA private key in India)        │ │
│  │  ├─ validateToken(token) → verify signature, check expiry               │ │
│  │  └─ Token claims: {sub: user_id, org: "india", iat, exp}              │ │
│  │                                                                         │ │
│  │  Spring Security Configuration                                          │ │
│  │  ├─ BearerTokenAuthenticationFilter                                     │ │
│  │  ├─ All /api endpoints require valid JWT                                │ │
│  │  └─ Invalid/expired tokens → 401 Unauthorized response                 │ │
│  │                                                                         │ │
│  │  ShelterIsolationFilter                                                 │ │
│  │  ├─ Extract shelter_id from request context                             │ │
│  │  ├─ Add WHERE shelter_id = :shelterContext to all queries              │ │
│  │  └─ Prevent cross-shelter data leakage                                  │ │
│  │                                                                         │ │
│  │  DataEncryptionService                                                  │ │
│  │  ├─ encrypt(pii, key) → AES-256-GCM ciphertext                         │ │
│  │  ├─ decrypt(ciphertext, key) → plaintext PII                           │ │
│  │  └─ Master key stored in AWS Secrets Manager (India region)            │ │
│  │                                                                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ Logging & Compliance                                                    │ │
│  │                                                                         │ │
│  │  AuditLogger                                                            │ │
│  │  └─ Every API call logged:                                              │ │
│  │     { timestamp, user_id, action, resource, shelter_id, ip, status }   │ │
│  │     └─ Stored in encrypted India database                              │ │
│  │     └─ Immutable for compliance audits                                  │ │
│  │                                                                         │ │
│  │  Monitoring (CloudWatch/DataDog)                                        │ │
│  │  ├─ Track API latency, error rates, unauthorized attempts              │ │
│  │  ├─ Alert on suspicious patterns (brute force, data exfiltration)      │ │
│  │  └─ Logs stored in India region (NOT US/EU)                             │ │
│  │                                                                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
                        │
                        │ Database Queries (encrypted)
                        │ All communication stays in-country
                        ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                      INDIA LOCAL DATABASE                                     │
│                  (AWS RDS India / Azure SQL India)                            │
│                     Physically in India region                                │
│                                                                               │
│  Schema:                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ Dogs Table                                                              │ │
│  │  ├─ id (UUID)                                                           │ │
│  │  ├─ sf_dog_id (foreign key to SF)                                       │ │
│  │  ├─ name                                                                │ │
│  │  ├─ breed                                                               │ │
│  │  ├─ age                                                                 │ │
│  │  ├─ health_records (encrypted blob)    ◄── PII                         │ │
│  │  ├─ image_url                                                           │ │
│  │  ├─ status (available, pending, adopted)                               │ │
│  │  ├─ shelter_id (fk to Shelters)                                        │ │
│  │  ├─ created_at                                                          │ │
│  │  └─ updated_at                                                          │ │
│  │                                                                         │ │
│  │ Adoptions Table                                                         │ │
│  │  ├─ id (UUID)                                                           │ │
│  │  ├─ sf_adoption_request_id (fk to SF)                                   │ │
│  │  ├─ dog_id (fk)                                                         │ │
│  │  ├─ adopter_name_encrypted (AES-256)   ◄── PII (encrypted at rest)     │ │
│  │  ├─ adopter_email_encrypted (AES-256)  ◄── PII (encrypted at rest)     │ │
│  │  ├─ adopter_phone_encrypted (AES-256)  ◄── PII (encrypted at rest)     │ │
│  │  ├─ adopter_address_encrypted (AES-256)◄── PII (encrypted at rest)     │ │
│  │  ├─ status (submitted, approved, rejected)                             │ │
│  │  ├─ shelter_id (fk)                                                     │ │
│  │  ├─ created_at                                                          │ │
│  │  ├─ updated_at                                                          │ │
│  │  └─ approved_at                                                         │ │
│  │                                                                         │ │
│  │ Shelters Table                                                          │ │
│  │  ├─ id                                                                  │ │
│  │  ├─ name                                                                │ │
│  │  ├─ region (e.g., "India-Mumbai")                                       │ │
│  │  └─ active                                                              │ │
│  │                                                                         │ │
│  │ AuditLog Table (immutable)                                              │ │
│  │  ├─ id                                                                  │ │
│  │  ├─ timestamp                                                           │ │
│  │  ├─ user_id                                                             │ │
│  │  ├─ action (read, create, update)                                       │ │
│  │  ├─ resource_type (dog, adoption)                                       │ │
│  │  ├─ resource_id                                                         │ │
│  │  ├─ ip_address                                                          │ │
│  │  ├─ http_status                                                         │ │
│  │  └─ details (sensitive logs encrypted)                                  │ │
│  │                                                                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  Security:                                                                    │
│  ├─ Database encryption at rest (AWS KMS India keys)                         │ │
│  ├─ Encrypted backups (stored in India region only)                          │ │
│  ├─ Network isolation (VPC, no public internet access)                       │ │
│  ├─ Row-level security (users can only see their shelter's data)            │ │
│  └─ 2-factor authentication for administrative access                        │ │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

### Data Flow Sequence: India-Specific Adoption Request

```
Timeline: Global User submitting adoption request for India dog

T=0s     ├─ Global Salesforce user (US-based admin) opens dogAdoptionList
         │  └─ Component mounts (shelter context: "india-1")
         │
T=0.5s   ├─ LWC calls getAvailableDogs() with shelter filter
         │  └─ DogAdoptionController.getAvailableDogsForIndia(shelterId="india-1")
         │
T=1s     ├─ Apex Controller calls middleware:
         │  └─ MiddlewareCalloutService.getDogsFromIndia(shelterId="india-1")
         │     ├─ Uses JwtTokenProvider.obtainToken() to get fresh JWT
         │     ├─ Makes HTTPS GET to:
         │     │  https://india-shelter-api.adyen.local/api/v1/dogs?shelterId=india-1
         │     │
         │     ├─ Middleware Spring Boot handler:
         │     │  POST /api/v1/dogs
         │     │  ├─ Validates JWT signature (India private key)
         │     │  ├─ Checks token claims (exp, sub, org="india")
         │     │  ├─ Enforces shelter isolation (where shelter_id = 'india-1')
         │     │  ├─ Queries India database:
         │     │  │  SELECT id, name, breed, age, image_url, status
         │     │  │  FROM dogs WHERE shelter_id = 'india-1' AND status = 'available'
         │     │  │
         │     │  ├─ Builds response (NO PII):
         │     │  │  [
         │     │  │    { id: "ind-dog-001", name: "Priya", breed: "labrador", ... },
         │     │  │    { id: "ind-dog-002", name: "Simba", breed: "german-shepherd", ... }
         │     │  │  ]
         │     │  │
         │     │  ├─ Logs audit: "GET /dogs user=sf-admin-001 shelter=india-1 status=200"
         │     │  └─ Returns HTTP 200 JSON
         │     │
         │     └─ Salesforce receives response (no PII visible)
         │
T=2s     ├─ LWC renders dog list in browser
         │  └─ Dog cards display without any adopter information
         │
T=10s    ├─ User selects "Priya" dog and clicks "Adopt"
         │  └─ Modal opens with adoption form
         │
T=11s    ├─ User fills form:
         │  ├─ Name: "Rajesh Kumar"        ◄── Will be PII
         │  ├─ Email: "rajesh@example.com" ◄── Will be PII
         │  └─ Phone: "+91-9876543210"     ◄── Will be PII
         │
T=12s    ├─ User clicks "Submit Request"
         │  └─ LWC calls:
         │     DogAdoptionController.requestAdoptionForIndia(
         │       dogId: "ind-dog-001",
         │       adopterName: "Rajesh Kumar",
         │       adopterEmail: "rajesh@example.com",
         │       adopterPhone: "+91-9876543210",
         │       shelterId: "india-1"
         │     )
         │
T=12.5s  ├─ Apex Controller DOES NOT store PII locally
         │  └─ Instead:
         │     ├─ Creates local record in SF (NO adopter names):
         │     │  Adoption_Request__c {
         │     │    Shelter_ID__c: "india-1",
         │     │    External_Adoption_ID__c: null (will be filled later),
         │     │    Status__c: "Submitted",
         │     │    SF_Request_Number__c: "AR-0001"
         │     │  }
         │     │
         │     └─ Calls middleware API (sends PII securely over HTTPS):
         │        MiddlewareCalloutService.submitAdoptionToIndia(
         │          dogId: "ind-dog-001",
         │          adopterName: "Rajesh Kumar",
         │          adopterEmail: "rajesh@example.com",
         │          adopterPhone: "+91-9876543210",
         │          sfAdoptionRequestId: "AR-0001",
         │          shelterId: "india-1"
         │        )
         │
T=13s    ├─ HTTPS POST to middleware (TLS 1.3 encrypted):
         │  https://india-shelter-api.adyen.local/api/v1/adoptions
         │  │
         │  │ Request Payload:
         │  │ {
         │  │   "dogId": "ind-dog-001",
         │  │   "adopterName": "Rajesh Kumar",          ◄── PII in transit
         │  │   "adopterEmail": "rajesh@example.com",   ◄── PII in transit
         │  │   "adopterPhone": "+91-9876543210",       ◄── PII in transit
         │  │   "sfAdoptionRequestId": "AR-0001",
         │  │   "shelterId": "india-1"
         │  │ }
         │  │
         │  └─ ┌─ Middleware Spring Boot Handler
         │     │  POST /api/v1/adoptions
         │     │
         │     ├─ Validates JWT (India key)
         │     ├─ Verifies payload signature (optional additional security)
         │     │
         │     ├─ CRITICAL: Encrypt PII before storing
         │     │  ├─ adopterName_encrypted = AES256.encrypt("Rajesh Kumar", masterKey)
         │     │  ├─ adopterEmail_encrypted = AES256.encrypt("rajesh@...", masterKey)
         │     │  └─ adopterPhone_encrypted = AES256.encrypt("+91-...", masterKey)
         │     │
         │     ├─ Insert into India database (no plaintext PII stored):
         │     │  INSERT INTO adoptions (
         │     │    dog_id, adopter_name_encrypted, adopter_email_encrypted,
         │     │    adopter_phone_encrypted, sf_request_id, shelter_id, status
         │     │  ) VALUES (
         │     │    'ind-dog-001',
         │     │    x'A1B2C3D4...encrypted...',
         │     │    x'E5F6G7H8...encrypted...',
         │     │    x'I9J0K1L2...encrypted...',
         │     │    'AR-0001',
         │     │    'india-1',
         │     │    'submitted'
         │     │  )
         │     │
         │     ├─ Audit log:
         │     │  INSERT INTO audit_logs (
         │     │    timestamp, user_id, action, resource_type, resource_id,
         │     │    http_status, ip_address, shelter_id
         │     │  ) VALUES (
         │     │    NOW(), 'sf-admin-001', 'CREATE_ADOPTION', 'adoption', 'IND-ADO-001',
         │     │    '201', '203.0.113.5', 'india-1'
         │     │  )
         │     │
         │     ├─ Update dog status:
         │     │  UPDATE dogs SET status = 'pending_adoption'
         │     │  WHERE id = 'ind-dog-001'
         │     │
         │     ├─ Return response (no PII sent back):
         │     │  {
         │     │    "adoptionId": "IND-ADO-001",
         │     │    "dogId": "ind-dog-001",
         │     │    "status": "submitted",
         │     │    "createdAt": "2026-05-29T12:00:00Z"
         │     │  }
         │     │
         │     └─ HTTP 201 Created
         │
T=14s    ├─ Salesforce receives response
         │  ├─ Updates local Adoption_Request__c:
         │  │  ├─ Status: "Submitted" → remains
         │  │  ├─ External_Adoption_ID__c: "IND-ADO-001" (link to India system)
         │  │  └─ Sync_Status__c: "Synced to India DB"
         │  │
         │  └─ Trigger AdoptionRequestTrigger fires
         │     └─ Update related Dog__c metadata:
         │        └─ SF_Status__c: "Pending Adoption" (metadata only, not real status)
         │
T=14.5s  ├─ LWC receives success response
         │  └─ Shows toast: "Adoption request submitted to India shelter!"
         │  └─ Modal closes
         │  └─ Calls refreshApex() → re-fetches dog list from middleware
         │     └─ Dog now marked as "pending_adoption" in India DB
         │        (removed from available list)
         │
T=15s    └─ SECURITY GUARANTEE:
            ├─ Adopter name "Rajesh Kumar" NEVER stored in SF
            ├─ Email NEVER stored in SF
            ├─ Phone NEVER stored in SF
            ├─ Only encrypted in India DB
            ├─ Audit trail proves SF never touched PII
            ├─ Full compliance with India data residency laws
            └─ TLS 1.3 + encryption at rest = defense in depth
```

---

### Technical Decisions: Why This Architecture?

#### 1. **Middleware Tier Instead of Direct Database Access**

**Alternative**: Have Salesforce connect directly to India database via VPN.

**Why Middleware is Better**:
- **Encryption**: Middleware handles data encryption/decryption (not Salesforce)
- **Audit Trail**: All API calls logged in India (compliance requirement)
- **Authentication**: Regional token signing with India-specific keys
- **Scalability**: Multiple instances behind load balancer (easy to scale)
- **Separation of Concerns**: SF admins don't need India DB credentials
- **Disaster Recovery**: Middleware is failover-friendly (can swap servers)

#### 2. **Java/Spring Boot for Middleware**

**Why**:
- **Alignment**: Job posting emphasizes Java skills
- **Ecosystem**: Spring Security, Spring Data JPA for rapid development
- **Maturity**: Battle-tested for enterprise middleware patterns
- **Hosting**: Easy deployment on AWS India, Azure India, GCP India
- **Standards**: RESTful APIs, OpenAPI documentation, well-known patterns
- **Security**: Spring Security + Spring Vault for encryption key management

**Tech Stack**:
```
Framework:    Spring Boot 3.x (latest LTS)
Language:     Java 17
Database:     PostgreSQL (AWS RDS India) or SQL Server (Azure India)
Authentication: Spring Security + JWT (RS256 RSA signing)
Encryption:   Spring Vault + AWS Secrets Manager (India region)
Monitoring:   CloudWatch + DataDog (India endpoints)
```

#### 3. **Why Encrypt at Rest + In Transit**

**Data Residency + Encryption = Defense in Depth**

| Layer | Protection | Tool |
|-------|-----------|------|
| **In Transit** | TLS 1.3 (HTTPS) | AWS NLB + ACM certs |
| **At Rest** | AES-256-GCM | Spring Vault + AWS KMS (India keys) |
| **In Code** | No plaintext PII fields | Spring Data + converter annotations |
| **Audit** | Immutable logs | PostgreSQL append-only audit table |

**Example**: Even if someone steals the India database backup, PII is encrypted.

#### 4. **Why NOT Replicate Data to Global Org**

**Alternative**: Sync India PII to SF via Platform Events.

**Why This Won't Work**:
- **Violates Compliance**: PII leaves India borders
- **Liability**: Adyen liable if data breached in SF
- **Legal**: Violates India personal data protection laws
- **Audit Failure**: Can't prove PII never left India

**Instead**:
- SF stores only **metadata** (dog ID, breed, status, image URL)
- **Pointers** to India system (External_Adoption_ID__c)
- API calls to retrieve **details** on-demand (with encryption)

---

### Scalability: Adding More Regions

**Easy**: Deploy same middleware in other countries.

```
US/Global Salesforce Org
│
├─► USA Middleware (Spring Boot, AWS US)
│   └─ USA Database (AWS US region, no encryption required)
│
├─► India Middleware (Spring Boot, AWS India)
│   └─ India Database (AWS India region, AES-256 encrypted)
│
├─► EU Middleware (Spring Boot, AWS EU)
│   └─ EU Database (AWS EU region, GDPR encryption + anonymization)
│
└─► China Middleware (Spring Boot, Alibaba Cloud China)
    └─ China Database (isolated, Great Firewall compliant)
```

**Code Reuse**: Same middleware codebase, different deployment configurations.

```java
// application-india.properties
app.region=INDIA
app.encryption.enabled=true
app.kms.key-id=arn:aws:kms:ap-south-1:...
app.database.url=jdbc:postgresql://india-db.amazonaws.com

// application-us.properties
app.region=US
app.encryption.enabled=false
app.database.url=jdbc:postgresql://us-db.amazonaws.com
```

---

### Compliance & Audit Trail

**Requirement**: Proof that PII never left India.

**How Middleware Provides It**:

```sql
-- Audit table (immutable, append-only)
SELECT timestamp, user_id, action, resource_type, http_status
FROM audit_logs
WHERE action IN ('READ', 'CREATE_ADOPTION', 'UPDATE')
AND timestamp BETWEEN '2026-05-01' AND '2026-05-31'
AND shelter_id = 'india-1'
ORDER BY timestamp;

-- Result shows:
-- [All API calls logged with HTTP 200-299 = success]
-- [NO 'SYNC_TO_SALESFORCE' action = PII never left India]
-- [NO data exfiltration attempts (large payloads, bulk reads)]
-- [All calls use valid JWT from Indian users]

-- Report: "All PII access restricted to India. Zero compliance violations."
```

---

## Summary: Which Architecture to Present

### For Interview Presentation

**Part 1 (Assignment 1): Current Architecture**
- Present the component interaction diagram (first diagram in this section)
- Walk through dog creation flow (image fetch → notification) 
- Explain design decisions (Queueables, config-driven endpoints)
- Demo the working UI in sandbox

**Part 2 (Assignment 2): India Expansion**
- Present the high-level India architecture diagram
- Explain the middleware gateway pattern
- Show data flow sequence (adoption request with PII handling)
- Discuss scalability (adding more regions)
- Emphasize compliance (audit trail, encryption, data residency)

**Why This Impresses**:
- Shows you understand **enterprise architecture** (not just CRUD apps)
- Demonstrates **data compliance** thinking (India PII regulations)
- Proves **scalability mindset** (config-driven, multi-region)
- Aligns with **Java + Salesforce** job requirements
- Shows real-world **security patterns** (middleware, encryption, audit logs)

---

## Appendix: Implementation Checklist

- [x] Assignment 1: Core functionality implemented (dogs, adoption requests, image fetching)
- [x] Assignment 1: LWC UI components (list, cards, adoption form)
- [x] Assignment 1: Data model (3 objects, relationships, workflows)
- [ ] Assignment 1: Write test data loading script (done: loadTestData.apex)
- [ ] Assignment 2: Architecture diagram (provided above)
- [ ] Assignment 2: Technical explanation (in this document)
- [ ] Create admin user (salesforcedev@adyen.com) before interview
- [ ] Prepare presentation slides or demo video
- [ ] Deploy to sandbox and test end-to-end
- [ ] Review assumptions section and be ready to discuss
- [ ] Prepare mock middleware API for demo (or use httpbin.org like current setup)

---

**Document Version**: 1.0  
**Last Updated**: May 29, 2026
