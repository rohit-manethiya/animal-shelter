# Adyen Animal Shelter - Complete Implementation Guide

## Executive Summary

This document provides a comprehensive overview of the **Adyen Animal Shelter** solution—a Salesforce-based platform designed to facilitate dog adoption management with a scalable, enterprise-grade architecture. The solution follows Salesforce best practices, emphasizing configuration-driven scalability, asynchronous processing, and maintainability.

**Key Capabilities:**
- Automated dog record creation with external image sourcing
- Adoption lifecycle management with status synchronization
- Multi-shelter support with dynamic endpoint routing
- Future-proof architecture for regional expansion
- Real-time UI with search and filtering capabilities

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Data Model](#data-model)
3. [System Flows & Processes](#system-flows--processes)
4. [Technical Components](#technical-components)
5. [Design Decisions & Rationale](#design-decisions--rationale)
6. [Scalability & Future Improvements](#scalability--future-improvements)
7. [Setup & Deployment](#setup--deployment)
8. [Assumptions](#assumptions)

---

## Architecture Overview

### High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SALESFORCE ORG                               │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  UI Layer (LWC)                          │  │
│  │  ┌──────────────────────┐  ┌──────────────────────────┐ │  │
│  │  │  dogAdoptionList     │  │     dogCard Component   │ │  │
│  │  │  - Search & Filter   │  │   - Display dog info    │ │  │
│  │  │  - Modal for requests│  │   - Adoption button     │ │  │
│  │  └──────────────────────┘  └──────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            ↓                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Business Logic Layer (Apex)                │  │
│  │                                                          │  │
│  │  DogAdoptionController  ← Exposes APIs to LWC            │  │
│  │  │                                                        │  │
│  │  ├─ getAvailableDogs()        (wire cache enabled)       │  │
│  │  └─ requestAdoption()         (creates adoption request) │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            ↓                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Trigger & Handler Layer                    │  │
│  │  ┌──────────────────────────────────────────────────┐   │  │
│  │  │            DogTrigger (after insert)             │   │  │
│  │  │  → DogTriggerHandler                             │   │  │
│  │  │    → enqueue DogImageFetchQueueable              │   │  │
│  │  └──────────────────────────────────────────────────┘   │  │
│  │  ┌──────────────────────────────────────────────────┐   │  │
│  │  │    AdoptionRequestTrigger (after insert/update)  │   │  │
│  │  │  → AdoptionRequestTriggerHandler                 │   │  │
│  │  │    → syncDogStatus() [status lifecycle logic]    │   │  │
│  │  └──────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            ↓                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          Async Processing Layer (Queueables)           │  │
│  │                                                          │  │
│  │  DogImageFetchQueueable                                 │  │
│  │  ├─ Calls DogImageService.fetchRandomImageByBreed()    │  │
│  │  ├─ Updates Dog__c.Image_URL__c                        │  │
│  │  └─ Chains → ShelterNotificationQueueable               │  │
│  │                                                          │  │
│  │  ShelterNotificationQueueable                           │  │
│  │  ├─ Re-queries Dog with Shelter_Facility__r.Endpoint   │  │
│  │  └─ Calls ShelterNotificationService.notifyShelter()   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            ↓                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          Service Layer (Callout Services)               │  │
│  │                                                          │  │
│  │  DogImageService                                        │  │
│  │  └─ Uses Named Credential: DogCeoApi                    │  │
│  │                                                          │  │
│  │  ShelterNotificationService                             │  │
│  │  └─ Dynamic endpoints from Shelter_Facility records     │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│          External Systems (Asynchronous Integration)           │
├─────────────────────────────────────────────────────────────────┤
│  Dog CEO Public API          │     Regional Shelter Databases   │
│  (Image Fetching)            │     (Adoption Notifications)     │
│  https://dog.ceo/api/        │     Config-driven endpoints      │
└─────────────────────────────────────────────────────────────────┘
```

### Architecture Principles

| Principle | Implementation |
|-----------|-----------------|
| **Configuration Over Code** | Shelter endpoints stored in Shelter_Facility__c records; adding new shelters requires no code deployment |
| **Asynchronous Processing** | Queueables for image fetching and notifications to prevent blocking |
| **Separation of Concerns** | Distinct layers: UI (LWC), Business Logic (Apex), Triggers (Handlers), Services (Callouts) |
| **Error Resilience** | Graceful degradation; failed image fetches don't block dog creation; failed notifications logged for monitoring |
| **Scalability** | Chain-able Queueables, dynamic endpoint routing, multi-shelter support from day one |

---

## Data Model

### 3-Object Core Schema

#### 1. **Dog__c** - Core Dog Records

**Purpose**: Represents an abandoned dog available for adoption.

| Field Name | Type | Length | Required | Description |
|-----------|------|--------|----------|-------------|
| Name | Text | 255 | ✓ Yes | Dog's name (record name field) |
| Breed__c | Text | 255 | ✓ Yes | Breed (must match Dog CEO API breeds) |
| Age__c | Number | 18,0 | No | Age in years |
| Description__c | Long Text Area | 32000 | No | Personality/behavioral notes |
| Image_URL__c | URL | 255 | No | URL to dog photo (populated async) |
| Status__c | Picklist | — | ✓ Yes | Adoption status (see below) |
| Shelter_Facility__c | Lookup | — | ✓ Yes | Which shelter manages this dog |

**Status Field Values:**
- `Available` — Dog is ready for adoption (default)
- `Pending Adoption` — Active adoption request submitted
- `Adopted` — Adoption approved; dog no longer available
- `On Hold` — Temporary hold (future use)

**Relationships:**
- **Master-Detail**: Shelter_Facility__c (parent)
  - Deletion Cascade: If shelter is deleted, all associated dogs are deleted
  - Reparenting: Not allowed (dogs must have a shelter)

**Key Indexes**: Status__c (for filtering Available dogs)

---

#### 2. **Adoption_Request__c** - Adoption Lifecycle Records

**Purpose**: Tracks the lifecycle of a dog adoption from request submission to approval/rejection.

| Field Name | Type | Length | Required | Description |
|-----------|------|--------|----------|-------------|
| Request Number | Auto Number | {0000} | ✓ Auto | Formatted identifier (AR-0001, etc.) |
| Dog__c | Master-Detail | — | ✓ Yes | Which dog is being adopted |
| Adopter_Name__c | Text | 255 | ✓ Yes | Name of adoption applicant |
| Adopter_Email__c | Email | 255 | ✓ Yes | Contact email |
| Adopter_Phone__c | Phone | 255 | No | Contact phone |
| Status__c | Picklist | — | ✓ Yes | Adoption request status (see below) |
| Request_Date__c | Date | — | ✓ Yes | Date request was submitted |
| Notes__c | Long Text Area | 32000 | No | Internal notes from staff |

**Status Field Values:**
- `Submitted` — Initial state; pending shelter review
- `Approved` — Adoption approved; dog transitions to "Adopted"
- `Rejected` — Adoption declined; dog reverts to "Available"
- `Pending Additional Info` — Awaiting more info from applicant

**Relationships:**
- **Master-Detail**: Dog__c (parent)
  - Child records; cascade deletion if dog is deleted
  - Reparenting: Not allowed

**Key Logic:**
- Validation: Only one non-rejected request allowed per dog at a time
- Trigger-driven status sync: adoption request status changes drive dog status changes

---

#### 3. **Shelter_Facility__c** - Shelter Configuration Records

**Purpose**: Represents a regional shelter facility; acts as configuration hub for shelter-specific endpoints and settings.

| Field Name | Type | Length | Required | Description |
|-----------|------|--------|----------|-------------|
| Name | Text | 255 | ✓ Yes | Shelter name (record name field) |
| Region__c | Text | 255 | No | Geographic region/country |
| Endpoint_URL__c | URL | 255 | ✓ Yes | External API endpoint for adoption notifications |
| Active__c | Checkbox | — | ✓ Yes | Enables/disables notifications to this shelter |

**Relationships:**
- One-to-Many parent to Dog__c
  - Deletion: Dogs are cascade-deleted if shelter is deleted
  - One shelter can manage multiple dogs

**Key Design Pattern:**
- **Configuration-Driven Architecture**: No hardcoded shelter endpoints in code
- Adding a new regional shelter = create one Shelter_Facility__c record
- Changes to shelter URLs require no Apex deployment

---

### ER Diagram

```
┌──────────────────────────┐
│   Shelter_Facility__c    │
├──────────────────────────┤
│ Name (PK)                │
│ Region__c                │
│ Endpoint_URL__c          │
│ Active__c                │
└────────────┬─────────────┘
             │ 1
             │ (Master-Detail)
             │
        Many │
             │
┌────────────▼──────────────┐
│      Dog__c               │
├───────────────────────────┤
│ Id (PK)                   │
│ Name                      │
│ Breed__c                  │
│ Age__c                    │
│ Description__c            │
│ Image_URL__c              │
│ Status__c (index)         │
│ Shelter_Facility__c (FK)  │
└────────────┬──────────────┘
             │ 1
             │ (Master-Detail)
             │
        Many │
             │
┌────────────▼──────────────────┐
│ Adoption_Request__c           │
├───────────────────────────────┤
│ Id (PK)                       │
│ Request_Number (auto)         │
│ Dog__c (FK)                   │
│ Adopter_Name__c               │
│ Adopter_Email__c              │
│ Adopter_Phone__c              │
│ Status__c                     │
│ Request_Date__c               │
│ Notes__c                      │
└───────────────────────────────┘
```

### Field-Level Security & Sharing

- **Sharing Model**: 
  - Dog__c: ReadWrite (standard)
  - Adoption_Request__c: ControlledByParent (inherits parent dog's sharing)
  - Shelter_Facility__c: ReadWrite

- **Field-Level Security**: All fields visible to admin user (salesforcedev@adyen.com)

---

## System Flows & Processes

### Flow 1: New Dog Record Creation with Image Fetching

**Scenario**: A shelter agent creates a new Dog record in Salesforce.

```
┌─ SYNCHRONOUS (Immediate, within trigger context)
│
├─ Shelter Agent inserts Dog__c (with Name, Breed, Age, Status='Available')
│
├─ DogTrigger fires (after insert)
│  │
│  └─ DogTriggerHandler.afterInsert()
│     │
│     └─ System.enqueueJob(new DogImageFetchQueueable(newDogs))
│        └─ Returns immediately; Queueable enqueued
│
└─ Response sent to user: "Dog record created"

┌─ ASYNCHRONOUS (Seconds to minutes later)
│
├─ DogImageFetchQueueable executes
│  │
│  ├─ For each dog in batch:
│  │  │
│  │  └─ DogImageService.fetchRandomImageByBreed(breed)
│  │     ├─ URL-encodes breed name
│  │     ├─ Makes HTTP GET to callout:DogCeoApi/breed/{breed}/images/random
│  │     ├─ Named Credential "DogCeoApi" resolves to https://dog.ceo/api
│  │     ├─ Parses JSON response: {"message": "IMG_URL", "status": "success"}
│  │     └─ Returns image URL (or null if failed)
│  │
│  ├─ update toUpdate; [Dog__c records with populated Image_URL__c]
│  │
│  └─ System.enqueueJob(new ShelterNotificationQueueable(dogs))
│     └─ Chain next Queueable
│
├─ ShelterNotificationQueueable executes
│  │
│  ├─ Re-query Dog records to fetch Image_URL__c and Shelter_Facility__r.Endpoint_URL__c
│  │
│  ├─ For each dog:
│  │  │
│  │  └─ If Shelter_Facility__r is active:
│  │     │
│  │     └─ ShelterNotificationService.notifyShelter(dog, endpoint)
│  │        ├─ Build JSON payload:
│  │        │  {
│  │        │    "salesforceId": "dog.Id",
│  │        │    "name": "dog.Name",
│  │        │    "breed": "dog.Breed__c",
│  │        │    "age": "dog.Age__c",
│  │        │    "imageUrl": "dog.Image_URL__c",
│  │        │    "status": "dog.Status__c",
│  │        │    "event": "DOG_RECORD_CREATED"
│  │        │  }
│  │        │
│  │        ├─ POST to endpoint (Shelter_Facility__c.Endpoint_URL__c)
│  │        └─ Log response (200-299 = success, else ERROR log)
│  │
│  └─ Job completes
│
└─ Dog record is complete with image URL; shelter is notified
```

**Key Points:**
- Image fetching is **non-blocking** → dog creation completes immediately
- If image fetch fails → dog record still exists, Image_URL__c is null
- Shelter notification is **chained** → executes after image update

---

### Flow 2: Adoption Request Submission

**Scenario**: A user submits an adoption request for an available dog.

```
┌─ SYNCHRONOUS (Immediate, within LWC + Apex transaction)
│
├─ User selects a dog and fills adoption form (name, email, optional phone)
│
├─ LWC: dogAdoptionList.submitAdoptionRequest()
│  │
│  ├─ Client-side validation (name & email required)
│  │
│  └─ Call @AuraEnabled DogAdoptionController.requestAdoption()
│
├─ DogAdoptionController.requestAdoption(dogId, name, email, phone)
│  │
│  ├─ Query: "Check if non-rejected request already exists for this dog"
│  │  │
│  │  └─ If found → throw AuraHandledException ("Active request already exists")
│  │     └─ User sees error toast
│  │
│  ├─ If check passes:
│  │  │
│  │  ├─ Create Adoption_Request__c record:
│  │  │  {
│  │  │    Dog__c: dogId,
│  │  │    Adopter_Name__c: name,
│  │  │    Adopter_Email__c: email,
│  │  │    Adopter_Phone__c: phone,
│  │  │    Status__c: 'Submitted',
│  │  │    Request_Date__c: today
│  │  │  }
│  │  │
│  │  ├─ insert request
│  │  │
│  │  └─ Return request.Id
│  │
│  └─ Response sent to LWC
│
└─ User sees success toast: "Adoption request submitted"

┌─ TRIGGER PROCESSING (Immediate, after Adoption_Request__c insert)
│
├─ AdoptionRequestTrigger fires (after insert)
│  │
│  └─ AdoptionRequestTriggerHandler.afterInsert()
│     │
│     └─ syncDogStatus(newRequests, null)
│        │
│        ├─ For each new Adoption_Request__c:
│        │  │
│        │  └─ If Status__c == 'Submitted':
│        │     │
│        │     └─ dogStatusUpdates.put(req.Dog__c, 'Pending Adoption')
│        │
│        ├─ Build map of dog IDs to new statuses
│        │
│        └─ update Dog__c records in batch
│
└─ Dog record Status__c changes: 'Available' → 'Pending Adoption'

┌─ UI UPDATES (Client-side refresh)
│
├─ LWC: refreshApex(wiredDogsResult)
│  │
│  └─ Re-execute getAvailableDogs() wire adapter
│     │
│     └─ Query now returns only dogs with Status__c = 'Available'
│        (The dog with a pending request is filtered out)
│
└─ Component re-renders; dog no longer visible in list
```

**Key Points:**
- Duplicate adoption requests are **prevented** by validation query
- Dog status is **automatically synchronized** via trigger logic
- UI is **automatically refreshed** after successful submission
- Status transitions are **predictable** and centralized in one trigger handler

---

### Flow 3: Adoption Request Approval (Future Flow)

**Scenario**: A shelter administrator approves an adoption request (manual SF operation or future API).

```
┌─ SYNCHRONOUS (Manual update in Salesforce)
│
├─ Admin updates Adoption_Request__c.Status__c from 'Submitted' → 'Approved'
│
├─ save()
│
└─ AdoptionRequestTrigger fires (after update)
   │
   └─ AdoptionRequestTriggerHandler.afterUpdate()
      │
      ├─ oldMap contains Status__c = 'Submitted'
      ├─ newRequests contains Status__c = 'Approved'
      │
      └─ syncDogStatus(newRequests, oldMap)
         │
         ├─ Detect: statusChanged(req.Status__c='Approved', oldStatus='Submitted', 'Approved') = true
         │
         └─ dogStatusUpdates.put(req.Dog__c, 'Adopted')
            │
            └─ update Dog__c
               │
               └─ Dog.Status__c = 'Adopted'

┌─ UI Impact
│
└─ Dog no longer returns from getAvailableDogs() query (filters Status='Available')
   └─ Dog removed from list in UI
```

---

### Flow 4: Adoption Request Rejection (Future Flow)

**Scenario**: A shelter administrator rejects an adoption request.

```
┌─ Admin updates Adoption_Request__c.Status__c from 'Submitted' → 'Rejected'
│
├─ AdoptionRequestTrigger fires (after update)
│  │
│  └─ AdoptionRequestTriggerHandler.afterUpdate()
│     │
│     ├─ Detect: statusChanged('Rejected', 'Submitted', 'Rejected') = true
│     │
│     └─ dogStatusUpdates.put(req.Dog__c, 'Available')
│        │
│        └─ update Dog__c
│
└─ Dog.Status__c = 'Available'
   └─ Dog reappears in adoption list (status = 'Available' again)
      └─ Can accept new adoption requests
```

---

## Technical Components

### 1. Apex Classes

#### **TriggerHandler.cls** - Framework Base Class

**Purpose**: Generic trigger handler framework following Kevin O'Hara pattern.

**Key Features:**
- Centralized trigger dispatch (before/after insert/update/delete/undelete)
- Handler bypass mechanism for testing and data migrations
- Loop count prevention (max 5 loops per handler per transaction)
- Exception handling with custom TriggerHandlerException

**Usage Pattern**:
```apex
// In trigger:
trigger DogTrigger on Dog__c (after insert) {
    new DogTriggerHandler().run();
}

// In handler class:
public class DogTriggerHandler extends TriggerHandler {
    public DogTriggerHandler() {
        this.newDogs = (List<Dog__c>) Trigger.new;
    }
    protected override void afterInsert() {
        // Logic here
    }
}

// In test:
TriggerHandler.bypass('DogTriggerHandler');
insert dog;
TriggerHandler.clearBypass('DogTriggerHandler');
```

---

#### **DogTriggerHandler.cls** - Dog Insert Logic

**Purpose**: Orchestrates image fetching and shelter notification when a new dog is created.

**Trigger Context**: After Insert

**Flow**:
1. Receives list of newly inserted dogs
2. Enqueues `DogImageFetchQueueable` for async processing
3. Returns immediately (non-blocking)

**Code Excerpt**:
```apex
public class DogTriggerHandler extends TriggerHandler {
    private List<Dog__c> newDogs;
    
    public DogTriggerHandler() {
        this.newDogs = (List<Dog__c>) Trigger.new;
    }
    
    protected override void afterInsert() {
        System.enqueueJob(new DogImageFetchQueueable(newDogs));
    }
}
```

**Scalability**: No other logic here; handler remains minimal and focused.

---

#### **AdoptionRequestTriggerHandler.cls** - Adoption Lifecycle Logic

**Purpose**: Keeps Dog__c status in sync with Adoption_Request__c status changes.

**Trigger Context**: After Insert & After Update

**Status Transitions**:
| Request Status | Dog Status | Trigger |
|---|---|---|
| Submitted | Pending Adoption | After Insert or Status Change |
| Approved | Adopted | After Update (status changed) |
| Rejected | Available | After Update (reverts to available) |

**Key Logic**:
- Detects status changes using `oldMap` comparison
- Prevents overwriting "Approved" status with "Rejected" in same batch
- Batch updates dogs efficiently

**Code Excerpt**:
```apex
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
            if (!dogStatusUpdates.containsKey(req.Dog__c)) {
                dogStatusUpdates.put(req.Dog__c, 'Available');
            }
        }
    }
    
    if (!dogStatusUpdates.isEmpty()) {
        List<Dog__c> dogsToUpdate = new List<Dog__c>();
        for (Id dogId : dogStatusUpdates.keySet()) {
            dogsToUpdate.add(new Dog__c(Id = dogId, Status__c = dogStatusUpdates.get(dogId)));
        }
        update dogsToUpdate;
    }
}
```

---

#### **DogImageFetchQueueable.cls** - Async Image Fetching

**Purpose**: Asynchronously fetches dog images from external API and chains to notification job.

**Why Queueable Instead of @future**:
- Supports job chaining (can enqueue next Queueable after completion)
- Accepts SObject parameters directly (no JSON serialization workaround)
- Better monitoring via AsyncApexJob (can query job status)

**Process**:
1. Execute in async context (can make callouts)
2. For each dog, call `DogImageService.fetchRandomImageByBreed(breed)`
3. If successful, collect for batch update
4. `update toUpdate;` — persist Image_URL__c to database
5. Chain to `ShelterNotificationQueueable` for next step

**Code Excerpt**:
```apex
public class DogImageFetchQueueable implements Queueable, Database.AllowsCallouts {
    private final List<Dog__c> dogs;
    
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
        
        // Chain next job
        System.enqueueJob(new ShelterNotificationQueueable(dogs));
    }
}
```

**Governor Considerations**:
- One callout per dog (Dog CEO API rate limit: typically 100+ calls/minute)
- Salesforce callout limit: 100 per transaction
- For bulk inserts >100 dogs, would need chunking (future improvement)

---

#### **ShelterNotificationQueueable.cls** - Async Shelter Notification

**Purpose**: Forwards dog records to regional shelter database for syncing.

**Key Design**:
- **Configuration-Driven**: Endpoint URL comes from `Shelter_Facility__c.Endpoint_URL__c`, not hardcoded
- **Dynamic Routing**: Different shelters can receive notifications to different endpoints
- **Scalable**: Adding a new shelter = 1 SF record, zero code changes

**Process**:
1. Receive dog IDs from previous Queueable
2. Re-query dog records to get Image_URL__c (populated by previous step) and endpoint URL
3. For each active shelter, call `ShelterNotificationService.notifyShelter(dog, endpoint)`
4. Logs success/failure; failed notifications flagged for manual review or future retry mechanism

**Code Excerpt**:
```apex
public class ShelterNotificationQueueable implements Queueable, Database.AllowsCallouts {
    private final Set<Id> dogIds;
    
    public void execute(QueueableContext ctx) {
        List<Dog__c> dogs = [
            SELECT Id, Name, Breed__c, Age__c, Image_URL__c, Status__c,
                   Shelter_Facility__r.Endpoint_URL__c,
                   Shelter_Facility__r.Active__c
            FROM Dog__c
            WHERE Id IN :dogIds
        ];
        
        for (Dog__c dog : dogs) {
            if (dog.Shelter_Facility__r == null || !dog.Shelter_Facility__r.Active__c) 
                continue;
            ShelterNotificationService.notifyShelter(dog, dog.Shelter_Facility__r.Endpoint_URL__c);
        }
    }
}
```

---

#### **DogImageService.cls** - Dog CEO API Integration

**Purpose**: Fetches random dog images by breed from public Dog CEO API.

**External API Contract**:
- **Endpoint**: https://dog.ceo/api/breed/{breed}/images/random
- **Method**: GET
- **Response**: `{"message": "<image_url>", "status": "success"}`

**Key Features**:
- Named Credential (`DogCeoApi`) for secure endpoint management
- URL encoding for breed names (handles special characters)
- Error handling with graceful null return
- 10-second timeout to prevent hanging

**Code Excerpt**:
```apex
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
            System.debug(LoggingLevel.WARN, 'Unexpected status ' + res.getStatusCode());
            return null;
        }
        
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return 'success'.equals(body.get('status')) ? (String) body.get('message') : null;
    }
}
```

**Breeds Supported**: See https://dog.ceo/api/breeds/list/all

---

#### **ShelterNotificationService.cls** - Regional Shelter API Integration

**Purpose**: Sends dog record data to regional shelter facility systems.

**Design**: Service layer abstracts HTTP details from Queueable.

**Payload Structure**:
```json
{
    "salesforceId": "a0A1x00000XyZaBCDE",
    "name": "Buddy",
    "breed": "labrador",
    "age": 3,
    "imageUrl": "https://images.dog.ceo/breeds/labrador/...",
    "status": "Available",
    "event": "DOG_RECORD_CREATED"
}
```

**Error Handling**:
- Logs failed requests at ERROR level with endpoint and status code
- Future improvement: Publish Platform Event for asynchronous retry queue

**Code Excerpt**:
```apex
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
                'Failed for dog ' + dog.Id + ' → ' + endpointUrl + 
                ' status=' + res.getStatusCode());
        }
    }
}
```

---

#### **DogAdoptionController.cls** - UI API Layer

**Purpose**: Exposes @AuraEnabled methods for LWC components.

**Methods**:

**1. getAvailableDogs() - Cacheable Query**
```apex
@AuraEnabled(cacheable=true)
public static List<Dog__c> getAvailableDogs() {
    return [
        SELECT Id, Name, Breed__c, Age__c, Image_URL__c,
               Description__c, Status__c,
               Shelter_Facility__r.Name, Shelter_Facility__r.Region__c
        FROM   Dog__c
        WHERE  Status__c = 'Available'
        ORDER BY CreatedDate DESC
    ];
}
```
- **cacheable=true**: LWC wire adapter caches results client-side
- Reduces server round-trips when navigating back to component
- `refreshApex()` in LWC clears cache after adoption request submission

**2. requestAdoption() - Validation + Insert**
```apex
@AuraEnabled
public static Id requestAdoption(
    Id dogId, String adopterName, String adopterEmail, String adopterPhone
) {
    // Prevent duplicate requests
    List<Adoption_Request__c> active = [
        SELECT Id FROM Adoption_Request__c
        WHERE Dog__c = :dogId AND Status__c != 'Rejected'
        LIMIT 1
    ];
    if (!active.isEmpty()) {
        throw new AuraHandledException('Active request already exists.');
    }
    
    Adoption_Request__c request = new Adoption_Request__c(
        Dog__c          = dogId,
        Adopter_Name__c = adopterName,
        Adopter_Email__c = adopterEmail,
        Adopter_Phone__c = adopterPhone,
        Status__c       = 'Submitted',
        Request_Date__c = Date.today()
    );
    insert request;
    return request.Id;
}
```
- **Validation**: Checks for existing non-rejected requests to prevent duplicates
- **Trigger Integration**: Insertion triggers AdoptionRequestTrigger → dog status updates
- **Error Handling**: AuraHandledException for graceful user feedback

**Security**: `with sharing` enforces user's sharing rules.

---

### 2. Lightning Web Components (LWC)

#### **dogAdoptionList.js** - Master List Component

**Purpose**: Displays available dogs with search, filtering, and adoption request modal.

**Key Features:**
- Wire adapter with client-side caching
- Search/filter by name or breed
- Modal dialog for adoption request form
- Async submission with refreshApex
- Toast notifications for user feedback

**Template Elements**:
```html
<lightning-card>
  <!-- Search input in card actions slot -->
  <!-- Spinner while loading -->
  <!-- Error message display -->
  <!-- Dog grid (calls c-dog-card child component) -->
  <!-- Adoption request modal (form overlay) -->
</lightning-card>
```

**Lifecycle**:
1. Component mounts → `@wire(getAvailableDogs)` fires
2. Wire result cached by LWC framework
3. User searches → client-side filter (no server call)
4. User clicks "Adopt" on dog card → opens modal
5. User submits form → async `requestAdoption()` call
6. On success → `refreshApex(wiredDogsResult)` clears cache → re-query → dog removed from list
7. Toast notification confirms success

**Code Excerpt**:
```javascript
@track filteredDogs = [];
@track showModal = false;
@track isSubmitting = false;

@wire(getAvailableDogs)
wiredDogs(result) {
    this.wiredDogsResult = result;
    this.isLoading = false;
    if (result.data) {
        this.filteredDogs = result.data;
    } else if (result.error) {
        this.hasError = true;
    }
}

async submitAdoptionRequest() {
    this.isSubmitting = true;
    try {
        await requestAdoption({
            dogId: this.selectedDogId,
            adopterName: this.adopterName,
            adopterEmail: this.adopterEmail,
            adopterPhone: this.adopterPhone
        });
        this.showToast('Success', 'Request submitted!', 'success');
        await refreshApex(this.wiredDogsResult); // Clear cache & re-fetch
    } catch (error) {
        this.showToast('Error', error.body?.message, 'error');
    } finally {
        this.isSubmitting = false;
    }
}
```

---

#### **dogCard.js** - Child Card Component

**Purpose**: Reusable card displaying individual dog information.

**Props**:
- `@api dog` — Dog__c record with all fields

**Features**:
- Displays dog image with graceful error handling
- Shows all dog details (name, breed, age, description, shelter)
- Dispatch custom event for adoption request
- Responsive styling (SLDS classes)

**Code Excerpt**:
```javascript
@api dog;

get ageLabel() {
    if (!this.dog?.Age__c && this.dog?.Age__c !== 0) return 'Age unknown';
    return `${this.dog.Age__c} year${this.dog.Age__c === 1 ? '' : 's'} old`;
}

handleAdoptClick() {
    this.dispatchEvent(new CustomEvent('requestadoption', {
        detail: { dogId: this.dog.Id, dogName: this.dog.Name },
        bubbles: true,
        composed: true
    }));
}

handleImageError(event) {
    event.target.style.display = 'none'; // Hide broken image
}
```

**Styling**: SLDS (Salesforce Lightning Design System) for Salesforce-native appearance.

---

### 3. Named Credential

#### **DogCeoApi** - External API Configuration

**Purpose**: Securely stores and resolves external API endpoint.

**Configuration**:
```
Label: DogCeoApi
URL: https://dog.ceo/api
Authentication: None (public API)
```

**Benefits**:
- No hardcoded URLs in Apex code
- Can change endpoint by updating one record (admin UI)
- Environment-agnostic (same code works in sandbox and production)

**Usage**:
```apex
req.setEndpoint('callout:DogCeoApi' + '/breed/labrador/images/random');
```

Salesforce resolves `callout:DogCeoApi` to the named credential's URL.

---

### 4. Metadata Configuration

#### **Tab Objects** (UI Navigation)

Three custom object tabs created for admin navigation:
- **Dog__c** — Access dog records
- **Adoption_Request__c** — View adoption requests
- **Shelter_Facility__c** — Manage shelter facilities

#### **Application**

**AnimalShelter.app** — Custom application bundling all tabs for a cohesive interface.

#### **Layouts**

Standard record layouts for each object with sections for:
- Dog Layout: Basic info, image, status, shelter
- Adoption Request Layout: Adopter info, request date, status
- Shelter Facility Layout: Endpoint configuration, region

#### **Permission Set**

**AnimalShelterAdmin** — For user `salesforcedev@adyen.com`:
- Read/create/edit/delete on all custom objects
- Access to custom tabs and application
- Page layouts and record type access

---

## Design Decisions & Rationale

### 1. Why Queueables Over @future?

**Decision**: Use `Queueable` for async image fetching and shelter notification.

**Rationale**:
| Feature | Queueable | @future |
|---------|-----------|---------|
| Job Chaining | ✓ Yes | ✗ No |
| SObject Parameters | ✓ Direct | ✗ JSON string |
| Job Monitoring | ✓ AsyncApexJob query | ✗ Limited |
| Dependencies | ✓ Can chain jobs | ✗ Independent |
| Testing | ✓ Easier mocking | ✗ Force static |

**Impact**: Allows `DogImageFetchQueueable` → `ShelterNotificationQueueable` chaining, ensuring image is populated before notification.

---

### 2. Why Configuration-Driven Shelter Endpoints?

**Decision**: Store shelter endpoints in `Shelter_Facility__c.Endpoint_URL__c`, not hardcoded in code.

**Alternative**: Hardcode endpoints in a Map<String, String> in Apex.

**Rationale**:
- **Zero-Deployment Scaling**: Adding a new regional shelter = 1 SF record, zero code changes
- **Environment Agility**: Different sandboxes can point to different test endpoints
- **Admin Control**: Non-technical admins can update endpoints without Apex changes
- **Audit Trail**: SF tracks who changed which endpoint and when

**Example**:
```apex
// ❌ Hard to scale
private static final Map<String, String> SHELTER_ENDPOINTS = new Map<String, String>{
    'amsterdam' => 'https://shelter-api.nl/adoption-sync',
    'rotterdam' => 'https://shelter-api.nl/adoption-sync'
};

// ✓ Scalable
Shelter_Facility__r.Endpoint_URL__c // Config in database
```

---

### 3. Why Master-Detail for Adoption_Request → Dog?

**Decision**: Adoption_Request__c is child of Dog__c (Master-Detail relationship).

**Alternatives**:
- Lookup (no cascade delete, soft linkage)
- External ID (custom matching)

**Rationale**:
- **Cascade Delete**: If a dog is deleted, all associated adoption requests are cleaned up automatically
- **Orphan Prevention**: Can't exist without a parent dog
- **Sharing Inheritance**: Adoption_Request sharing inherits from Dog (admin control)
- **UI Hierarchy**: Related lists on dog record show all adoption requests at a glance

**Trade-off**: Cannot reparent (move adoption request to different dog). If needed for corrections, would require custom undelete logic.

---

### 4. Why Batch Status Updates in Trigger Handler?

**Decision**: AdoptionRequestTriggerHandler collects dog IDs in a map, then batch updates all at once.

**Alternative**: Update dog in a loop, one at a time.

**Rationale**:
```apex
// ❌ Inefficient: 10 dogs = 10 DML statements
for (Adoption_Request__c req : requests) {
    update new Dog__c(Id = req.Dog__c, Status__c = 'Pending Adoption');
}

// ✓ Efficient: 10 dogs = 1 DML statement
List<Dog__c> toUpdate = new List<Dog__c>();
for (Adoption_Request__c req : requests) {
    toUpdate.add(new Dog__c(Id = req.Dog__c, Status__c = newStatus));
}
update toUpdate;
```

**Benefit**: Respects DML statement governor limits (150 per transaction).

---

### 5. Why @wire with Cacheable?

**Decision**: DogAdoptionController.getAvailableDogs() is `@AuraEnabled(cacheable=true)`.

**Benefit**: LWC wire adapter caches results client-side.

**Example**:
1. User navigates to adoption list → wire fires → results cached
2. User searches (client-side filter) → no server call
3. User navigates away and back → cache still valid → instant load
4. After adoption request → `refreshApex()` clears cache → fresh query

**Trade-off**: Cache invalidates on browser refresh or 30 seconds (LWC default). Acceptable for a read-only list.

---

### 6. Why Separate Service Classes?

**Decision**: DogImageService and ShelterNotificationService are separate classes.

**Rationale**:
- **Testability**: Can mock each service independently
- **Reusability**: Other components can call these services
- **Single Responsibility**: One class = one external API integration
- **Maintenance**: Changes to Dog CEO API only affect DogImageService

---

## Scalability & Future Improvements

### Short-Term Improvements (For Production)

1. **Error Handling & Retries**
   - **Current**: Failed notifications are logged; manual review required
   - **Improvement**: Implement Platform Event publishing for failed notifications
   - **Pattern**: ShelterNotificationService publishes event → Flow/Process Builder retries after delay

   ```apex
   // Future improvement
   if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
       PublishShelterNotificationFailure(dog, endpointUrl, res.getStatusCode());
   }
   ```

2. **Bulk Image Fetching (>100 dogs)**
   - **Current**: One Queueable processes all dogs in one batch
   - **Limit**: 100 callouts per transaction
   - **Improvement**: Chunk dogs into batches of 50-75, enqueue separate Queueables

   ```apex
   // Chunk logic
   Integer chunkSize = 75;
   for (Integer i = 0; i < dogs.size(); i += chunkSize) {
       List<Dog__c> chunk = dogs.sublist(i, Math.min(i + chunkSize, dogs.size()));
       System.enqueueJob(new DogImageFetchQueueable(chunk));
   }
   ```

3. **Adoption Request Workflow**
   - **Current**: Manual status updates by admins
   - **Improvement**: Add approval workflow or Flow to automate transitions

4. **Search & Filtering**
   - **Current**: Client-side only (in-memory filtering)
   - **Improvement**: Server-side SOQL filtering for large datasets (>1000 dogs)

5. **Image Validation**
   - **Current**: No validation of image URLs
   - **Improvement**: Async image verification (check HTTP HEAD response before saving)

---

### Medium-Term Enhancements (Scalability for India Expansion)

1. **Data Residency Compliance (Assignment 2)**
   - **Problem**: Global Salesforce org can't store India PII
   - **Solution**: Java/Spring Boot middleware acting as gateway
   
   ```
   Global Salesforce
       ↓ (REST calls to middleware)
   India Middleware (Spring Boot, deployed to AWS India region)
       ├─ Authentication layer (JWT validation)
       ├─ Data proxy (intercepts PII fields)
       └─ Encryption/decryption of sensitive data
       ↓
   India Local Database
       └─ Stores all animal/adopter PII
   ```

   **Implementation**: 
   - Create REST endpoints in Java:
     - POST `/dogs` → receives dog metadata, stores locally
     - GET `/dogs/:id` → returns dog (filtered PII) to SF
     - PATCH `/adoptions/:id/approve` → local processing
   - SF stores only non-PII (dog ID, breed, age, image URL)
   - Middleware enforces encryption in transit (TLS 1.3)

2. **Multi-Tenant Isolation**
   - Each regional shelter gets isolated data silo in middleware
   - Query filters auto-include shelter context
   - No cross-shelter data leakage

3. **Audit Logging**
   - All API calls logged with timestamp, user, action, data touched
   - Compliance reports for regulatory audits

---

### Long-Term Roadmap

1. **Mobile Adoption App**
   - Native iOS/Android for adopters to browse and apply
   - Push notifications for status updates

2. **Shelter AI Matching**
   - ML model to match adopters to suitable dogs
   - Recommendations based on adopter questionnaire

3. **Global Shelter Network**
   - International partner shelter integrations
   - Cross-country dog transfers

---

## Setup & Deployment

### Prerequisites

- Salesforce Developer Sandbox or Org
- Salesforce CLI installed (`sf` or `sfdx`)
- Git repository access
- Node.js 18+ (for npm dependencies)

### Step 1: Clone Repository

```bash
git clone <repo-url>
cd animal-shelter
```

### Step 2: Authenticate to Salesforce

```bash
sf org login web --set-default
# Opens browser; log in as salesforcedev@adyen.com
# Returns org alias (e.g., "animal-shelter-sandbox")
```

### Step 3: Deploy Metadata

```bash
sf project deploy start --manifest force-app/main/default --target-org animal-shelter-sandbox
```

**What Gets Deployed**:
- Custom objects (Dog__c, Adoption_Request__c, Shelter_Facility__c)
- Apex classes (7 classes + 2 triggers)
- LWC components (2 components)
- Named Credential (DogCeoApi)
- Tabs, layouts, permission sets, application

### Step 4: Configure Named Credential

1. In Salesforce org, navigate to **Setup** → **Named Credentials**
2. Edit **DogCeoApi**:
   - URL: `https://dog.ceo/api`
   - Leave as "No Authentication" (public API)
   - Save

### Step 5: Create Test Shelters & Dogs

```bash
sf apex run --file scripts/apex/loadTestData.apex --target-org animal-shelter-sandbox
```

**What Gets Created**:
- 2 Shelter_Facility__c records (Amsterdam, Rotterdam) with test endpoints
- 6 Dog__c records (Buddy, Bella, Max, Luna, Charlie, Daisy) with breeds matching Dog CEO API

**Note**: Image fetching happens asynchronously. Monitor job status:
```bash
sf org get metadata --type AsyncApexJob --target-org animal-shelter-sandbox
```

### Step 6: Open UI

1. Log into org
2. Open **Animal Shelter** application
3. Click **Dogs** tab to see adoption list with dog images (after ~1 min)

### Step 7: Create Admin User

```bash
sf user create --target-org animal-shelter-sandbox \
    --firstname Adyen \
    --lastname Dev \
    --email salesforcedev@adyen.com \
    --definition-file config/user-def.json
```

(Provide password management details as requested by Adyen)

---

## Assumptions

### Functional Assumptions

1. **Dog Breed Names**: All breeds in Dog__c must exist in Dog CEO API (e.g., "labrador", "beagle", not "Labrador Retriever")

2. **Shelter Endpoints**: Regional shelter systems expose HTTP POST endpoints accepting JSON payloads in the specified format

3. **Image Availability**: Dog CEO API will always return valid image URLs (or null status, handled gracefully)

4. **No Custom Adoption Approval Workflow**: Admins manually change adoption request status (no automated approval rules in scope)

5. **Single Org Deployment**: All shelter facilities managed in one global Salesforce org (India expansion in Assignment 2 will change this)

### Technical Assumptions

1. **No Outbound IP Filtering**: Salesforce can make HTTP callouts to `dog.ceo` (no firewall blocking)

2. **Async Job Visibility**: Admins have access to Apex Jobs monitoring via Monitoring tab (standard SF feature)

3. **Storage Sufficient**: Org can store image URLs (URL field = 255 chars, max ~6000 dogs = ~1.5 MB)

4. **No Real-Time Sync Required**: Notifications to shelter are async (eventual consistency acceptable)

5. **No Custom Metadata Types**: Using standard Shelter_Facility__c records for configuration (no MDT usage)

### Regulatory Assumptions

1. **Data Residency (India Expansion)**: Assignment 2 assumes India compliance requires middleware layer (addressed in separate architecture doc)

2. **No PII Encryption at Rest**: Adopter PII (name, email, phone) stored in plain text in Salesforce (acceptable for US/EU orgs; India expansion will encrypt)

3. **Audit Logging**: SF native audit trail sufficient (not using custom event logging)

---

## Appendix: Testing the Solution

### Manual Test Case 1: Dog Creation with Image Fetch

**Steps**:
1. Log in to Salesforce
2. Open **Dogs** tab
3. Click **New**
4. Fill:
   - Name: "Buddy"
   - Breed: "labrador"
   - Age: 3
   - Shelter: Amsterdam Shelter
   - Status: Available
5. Click **Save**

**Expected Result**:
- Dog record created
- After ~5-30 seconds, Image_URL__c is populated with a dog image URL
- Image appears in card when viewing dog record

**Troubleshooting**:
- If image not populated after 5 min: Check AsyncApexJob for errors
- If error says "No named credential found": Verify DogCeoApi exists

---

### Manual Test Case 2: Adoption Request Submission

**Steps**:
1. On **Dogs** tab, find "Buddy" (or any dog with Status = Available)
2. Click **Adopt** button
3. Fill modal:
   - Name: "John Doe"
   - Email: "john@example.com"
   - Phone: "555-1234"
4. Click **Submit Request**

**Expected Result**:
- "Request Submitted" toast appears
- Modal closes
- Dog disappears from list (no longer Status = Available)
- Adoption_Request__c record created with status "Submitted"
- Dog__c.Status__c changed to "Pending Adoption"

**Troubleshooting**:
- If error "Active request already exists": Dog already has a pending request
- If dog still visible: Browser cache not cleared; refresh page

---

### Manual Test Case 3: Adoption Approval (Admin)

**Steps**:
1. Open **Adoption Requests** tab
2. Find a request with Status = "Submitted"
3. Open request
4. Change Status to "Approved"
5. Click **Save**

**Expected Result**:
- Request saved
- Dog record Status__c changes to "Adopted"
- Dog no longer appears in adoption list

---

## Final Checklist for Adyen Submission

- [x] Data model designed and implemented (3 objects, relationships)
- [x] Apex code follows best practices (trigger handlers, services, queueables)
- [x] LWC components functional (list, cards, adoption form)
- [x] External API integration (Dog CEO, regional shelters)
- [x] Test data script ready
- [x] Documentation complete (this file)
- [ ] Admin user created (salesforcedev@adyen.com)
- [ ] Org deployed and tested end-to-end
- [ ] Architecture diagram created (Assignment 2)
- [ ] Deployment guide provided to interviewers

---

## Contact & Questions

For any clarifications on this implementation, refer to the code comments and this documentation. All architectural decisions are documented in the "Design Decisions & Rationale" section above.

**Date Prepared**: May 29, 2026  
**Document Version**: 1.0
