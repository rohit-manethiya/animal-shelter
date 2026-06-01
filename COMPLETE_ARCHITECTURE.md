# Adyen Animal Shelter - Complete End-to-End Architecture

**Document Version**: 2.0  
**Last Updated**: June 1, 2026  
**Status**: Production Ready with Future Scalability Plan

---

## 1. Executive Summary

**Adyen Animal Shelter** is a scalable, multi-regional dog adoption platform built on Salesforce with strict data isolation by shelter and region. The system supports unlimited future regional expansion through **configuration-only** changes (no code deployments required).

### Key Features Implemented
- ✅ Multi-tier regional hierarchy (Region → City → Shelter)
- ✅ Strict data isolation using Master-Detail relationships + role hierarchy
- ✅ Standard Salesforce Approval Process for adoption requests
- ✅ Dependent picklists (Region controls City field)
- ✅ Automatic dog status synchronization via triggers
- ✅ Configuration-driven architecture (shelter endpoints in database)
- ✅ LWC UI with client-side caching
- ✅ Asynchronous image fetching (Queueables)
- ✅ Validation rules for data integrity

---

## 2. High-Level System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     END USER TIER                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────┐  ┌──────────────────┐  ┌────────────────┐   │
│  │   Adopter User       │  │ Shelter Owner    │  │ Regional Admin │   │
│  │  (Read-Only View)    │  │ (Shelter Mgmt)   │  │ (Multi-Shelter)│   │
│  │  - Browse dogs       │  │ - Manage dogs    │  │ - Approve      │   │
│  │  - Submit adoption   │  │ - Manage shelter │  │   requests     │   │
│  │    requests          │  │ - View adoptions │  │ - See all      │   │
│  │  - Track status      │  │                  │  │   regional     │   │
│  │                      │  │                  │  │   shelters     │   │
│  └──────────────────────┘  └──────────────────┘  └────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                   SALESFORCE PLATFORM TIER                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ UI LAYER (LWC Components)                                         │ │
│  │  - dogAdoptionList.js (search, filter, adoption submission)      │ │
│  │  - dogCard.js (dog details, adopt button)                        │ │
│  │  - adoptionApprovalUI.js (standard approval process)             │ │
│  └────────────────┬────────────────────────────────────────────────┘ │
│                   │                                                   │
│  ┌────────────────▼────────────────────────────────────────────────┐ │
│  │ APEX CONTROLLER LAYER                                            │ │
│  │  - DogAdoptionController.getAvailableDogs()                      │ │
│  │  - DogAdoptionController.requestAdoption()                       │ │
│  │  - ApprovalProcessController.submitApproval()                    │ │
│  │  - ShelterController.getShelterInfo()                            │ │
│  └────────────────┬────────────────────────────────────────────────┘ │
│                   │                                                   │
│  ┌────────────────▼────────────────────────────────────────────────┐ │
│  │ TRIGGER FRAMEWORK (Event-Driven Logic)                           │ │
│  │  - DogTrigger                                                     │ │
│  │    └─ beforeInsert/Update: Validate unique dog name per shelter  │ │
│  │    └─ afterInsert/Update: Fetch/refresh images (Queueable)       │ │
│  │                                                                   │ │
│  │  - AdoptionRequestTrigger                                         │ │
│  │    └─ afterInsert: Sync dog status (Submitted → Pending)         │ │
│  │    └─ afterUpdate: Sync dog status (Approved → Adopted,          │ │
│  │                                      Rejected → Available)        │ │
│  │                                                                   │ │
│  │  - ApprovalProcessTrigger                                         │ │
│  │    └─ Process approval workflow (ProcessInstance)                │ │
│  └────────────────┬────────────────────────────────────────────────┘ │
│                   │                                                   │
│  ┌────────────────▼────────────────────────────────────────────────┐ │
│  │ VALIDATION & BUSINESS LOGIC                                       │ │
│  │  - Validate_Region_City_Match (validation rule)                  │ │
│  │  - Composite unique constraint: Shelter_Facility__c + Dog Name   │ │
│  │  - Dependent picklist: Region → City                             │ │
│  └────────────────┬────────────────────────────────────────────────┘ │
│                   │                                                   │
│  ┌────────────────▼────────────────────────────────────────────────┐ │
│  │ DATA ACCESS LAYER (Custom Objects)                               │ │
│  │  - Shelter_Facility__c (config, Master-Detail parent)            │ │
│  │  - Dog__c (animals, Master-Detail child of Shelter)              │ │
│  │  - Adoption_Request__c (requests, Master-Detail child of Dog)    │ │
│  └────────────────┬────────────────────────────────────────────────┘ │
│                   │                                                   │
│  ┌────────────────▼────────────────────────────────────────────────┐ │
│  │ ASYNCHRONOUS PROCESSING (Queueables)                             │ │
│  │  - DogImageFetchQueueable (fetch images from external API)       │ │
│  │  - ShelterNotificationQueueable (notify shelter systems)         │ │
│  └────────────────┬────────────────────────────────────────────────┘ │
│                   │                                                   │
└───────────────────┼───────────────────────────────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│              EXTERNAL SYSTEMS & DATA SOURCES                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────┐  ┌──────────────────────────────────┐   │
│  │  Dog CEO API             │  │  Regional Shelter Systems        │   │
│  │ (Image fetching)         │  │ (Config-driven endpoints)        │   │
│  │                          │  │                                  │   │
│  │ GET /breed/{breed}/      │  │ POST /adoption-sync              │   │
│  │     images/random        │  │     /adoption-update             │   │
│  │                          │  │     /adoption-approve            │   │
│  └──────────────────────────┘  └──────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Object Model & Data Structure

### Core Objects

#### 3.1 Shelter_Facility__c
**Purpose**: Configuration object representing individual shelter locations.  
**Sharing Model**: Private (ControlledByParent)  
**Records**: 1 per shelter location

| Field Name | Type | Purpose | Constraint |
|-----------|------|---------|-----------|
| Name | Text | Shelter name | Required |
| Region__c | Picklist | Region (India, Netherlands) | Required, Used as controlling field |
| City__c | Picklist (Dependent) | City (Bangalore, Delhi, etc) | Required, Dependent on Region__c |
| Endpoint_URL__c | URL | API endpoint for notifications | Optional, Config-driven |
| Active__c | Checkbox | Enable/disable shelter | Default: false |

**Validation Rules**:
- `Validate_Region_City_Match`: Ensures Region → City mapping (India: {Bangalore, Delhi, Jaipur, Mumbai}, Netherlands: {Amsterdam, Rotterdam})

**Picklist Dependencies**:
- **Region__c** (Controlling Field)
  - India
  - Netherlands
- **City__c** (Dependent Field)
  - India → {Bangalore, Delhi, Jaipur, Mumbai}
  - Netherlands → {Amsterdam, Rotterdam}

**Record-Level Sharing**:
```
OrgWideDefaults: Private
├─ Shelter Owners see only their assigned shelter
├─ Regional Admins see all shelters in their region (via role hierarchy)
└─ System Admins see all shelters
```

---

#### 3.2 Dog__c
**Purpose**: Represents individual animals available for adoption.  
**Parent**: Shelter_Facility__c (Master-Detail)  
**Sharing**: Inherited from Shelter_Facility__c (ControlledByParent)  
**Records**: Multiple per shelter

| Field Name | Type | Purpose |
|-----------|------|---------|
| Name | Text | Dog's name |
| Breed__c | Picklist | Dog breed |
| Age__c | Number | Age in years |
| Description__c | Long Text | Dog details, personality |
| Image_URL__c | URL | Photo URL (fetched from Dog CEO API) |
| Status__c | Picklist | Available, Pending Adoption, Adopted |
| Shelter_Facility__c | Master-Detail | Parent shelter (required) |

**Unique Constraint** (Composite via Trigger):
- `{Shelter_Facility__c, Name}` must be unique
- Validated in `DogTriggerHandler.validateUniqueDogNamePerShelter()`
- Error: "A dog named '{name}' already exists in this shelter."

**Status Lifecycle**:
```
Available
    ↓ (when Adoption_Request created with Status='Submitted')
Pending Adoption
    ↓ (when Adoption_Request approved)
    Adopted
OR
    ↓ (when Adoption_Request rejected)
    Available
```

**Trigger Hooks**:
- `beforeInsert/beforeUpdate`: Validate unique dog name per shelter
- `afterInsert/afterUpdate`: If Breed__c changes, fetch new image via Queueable

---

#### 3.3 Adoption_Request__c
**Purpose**: Captures adoption requests from users.  
**Parent**: Dog__c (Master-Detail)  
**Sharing**: Inherited from Dog__c → Shelter_Facility__c  
**Records**: Multiple per dog (only 1 active per dog at a time)

| Field Name | Type | Purpose |
|-----------|------|---------|
| Adopter_Name__c | Text | Person requesting adoption |
| Adopter_Email__c | Email | Contact email |
| Adopter_Phone__c | Phone | Contact phone |
| Notes__c | Long Text | Additional notes |
| Status__c | Picklist | Submitted, Approved, Rejected |
| Request_Date__c | Date | When request was created |
| Dog__c | Master-Detail | Which dog (required, cascades delete) |
| Shelter_Owner__c | Lookup | Reference to shelter owner (read-only for shelter owners) |
| Adoption_Stage__c | Picklist | Workflow stage for approval process |

**Validation**:
- Only 1 non-rejected request per dog at a time
- Validated in `DogAdoptionController.requestAdoption()`

**Approval Process**:
```
Status = 'Submitted'
    ↓ (Approval Process awaits Shelter Owner approval)
Status = 'Approved' (Approved action)
    Adoption_Request__c Status → Approved
    Dog__c Status → Adopted
OR
Status = 'Rejected' (Rejected action)
    Adoption_Request__c Status → Rejected
    Dog__c Status → Available
```

**Trigger Hooks**:
- `afterInsert`: Update Dog__c status to "Pending Adoption"
- `afterUpdate`: Update Dog__c status based on Adoption_Request status

---

### Data Isolation Architecture

```
Global Organization
    │
    ├─ System Admin (User)
    │  └─ Role: System Administrator
    │     └─ Can see: All shelters, all regions, all dogs, all requests
    │
    ├─ Regional Manager - India (User)
    │  └─ Role: Regional_Admin_India
    │     └─ Role hierarchy parent: None (top-level)
    │     └─ Can see: All shelters in India (Bangalore, Delhi, Jaipur, Mumbai)
    │
    ├─ Regional Manager - Netherlands (User)
    │  └─ Role: Regional_Admin_Netherlands
    │     └─ Role hierarchy parent: None (top-level)
    │     └─ Can see: All shelters in Netherlands (Amsterdam, Rotterdam)
    │
    ├─ Shelter Owner - Bangalore (User)
    │  └─ Role: Shelter_Owner_Bangalore
    │     └─ Role hierarchy parent: Regional_Admin_India
    │     └─ Can see: Only Bangalore shelter
    │
    ├─ Shelter Owner - Amsterdam (User)
    │  └─ Role: Shelter_Owner_Amsterdam
    │     └─ Role hierarchy parent: Regional_Admin_Netherlands
    │     └─ Can see: Only Amsterdam shelter
    │
    └─ Adopter (User)
       └─ Role: Adopter
          └─ Can see: All dogs (read-only list)
          └─ Can create: Adoption_Request__c only
```

**Sharing Model**:
```
Shelter_Facility__c
├─ OrgWideDefault: Private
├─ ControlledByParent: Yes (N/A - no parent)
│
Dog__c
├─ OrgWideDefault: Private
├─ ControlledByParent: Yes (Parent: Shelter_Facility__c)
├─ Access propagation:
│  ├─ Shelter_Owner_Bangalore role → sees only Bangalore shelter's dogs
│  ├─ Regional_Admin_India role → sees all India shelter's dogs
│  └─ System Admin → sees all dogs
│
Adoption_Request__c
├─ OrgWideDefault: Private
├─ ControlledByParent: Yes (Parent: Dog__c → Shelter_Facility__c)
├─ Access propagation:
│  ├─ Adopter role → sees own adoption requests only
│  ├─ Shelter_Owner_* role → sees adoption requests for their shelter
│  ├─ Regional_Admin_* role → sees adoption requests for their region
│  └─ System Admin → sees all adoption requests
```

**Permission Sets**:

| Permission Set | User Role | Object Access | Field Access |
|---|---|---|---|
| `AnimalShelterAdmin` | System Admin | Full CRUD all objects, viewAll, modifyAll | All fields readable & editable |
| `Shelter_Owner` | Shelter Owner | Create, Read, Edit (limited) | Region (read-only), City (read-only), Dog fields (editable), Adoption Status (viewable) |
| `Adopter` | Adopter | Create Adoption_Request__c, Read Dog__c | Dog fields (readable), Adoption_Request fields (readable, editable for own) |

---

## 4. Entity Relationship Diagram (ERD)

```
┌─────────────────────────────┐
│   Shelter_Facility__c       │
├─────────────────────────────┤
│ Id (PK)                     │
│ Name                        │
│ Region__c (Controlling)     │◄─────────────────────┐
│ City__c (Dependent)         │◄─────────────────────┤ Dependent Picklist
│ Endpoint_URL__c             │                      │ Region → City mapping
│ Active__c                   │                      │
│ OrgWideDefault: Private     │◄─────────────────────┘
│ ControlledByParent: N/A     │
└──────────────┬──────────────┘
               │ (Master-Detail 1:*)
               │ (ControlledByParent)
               │ [Cascading Delete]
               ▼
┌──────────────────────────────┐
│      Dog__c                  │
├──────────────────────────────┤
│ Id (PK)                      │
│ Name (Part of unique key)    │◄────────────────────┐
│ Breed__c                     │                     │ Composite Unique
│ Age__c                       │                     │ Constraint:
│ Description__c               │                     │ {Shelter__c, Name}
│ Image_URL__c                 │◄────────────────────┘
│ Status__c                    │
│ Shelter_Facility__c (FK)     │◄─── Master-Detail parent
│ OrgWideDefault: Private      │
│ ControlledByParent: Yes      │
└──────────────┬───────────────┘
               │ (Master-Detail 1:*)
               │ (ControlledByParent)
               │ [Cascading Delete]
               ▼
┌──────────────────────────────┐
│ Adoption_Request__c          │
├──────────────────────────────┤
│ Id (PK)                      │
│ Adopter_Name__c              │
│ Adopter_Email__c             │
│ Adopter_Phone__c             │
│ Notes__c                     │
│ Status__c                    │◄─── Linked to Approval Process
│ Request_Date__c              │
│ Dog__c (FK)                  │◄─── Master-Detail parent
│ Shelter_Owner__c (Lookup)    │
│ Adoption_Stage__c            │
│ OrgWideDefault: Private      │
│ ControlledByParent: Yes      │
└──────────────────────────────┘
```

---

## 5. User Roles & Access Control

### Role Hierarchy

```
┌──────────────────────────────────────────────────┐
│         System Administrator                     │
│   (Can see & do everything)                      │
│   - Access to all shelters, regions              │
│   - Can approve any adoption                     │
│   - Can create/edit shelters                     │
└──────────────┬───────────────────────────────────┘
               │
      ┌────────┴────────┐
      │                 │
┌─────▼──────────┐  ┌──▼────────────────────┐
│ Regional Admin │  │ Regional Admin         │
│ - India        │  │ - Netherlands          │
│ (Parent Role)  │  │ (Parent Role)          │
│ Access:        │  │ Access:                │
│ - All India    │  │ - All Netherlands      │
│   shelters     │  │   shelters             │
└─────┬──────────┘  └──┬────────────────────┘
      │                 │
   ┌──┴──┬──┐        ┌──┴───┐
   │     │  │        │      │
┌──▼─┐ ┌┴──▼──┐  ┌──▼──┐ ┌┴──▼──┐
│ SO │ │ SO   │  │ SO  │ │ SO   │
│Bar │ │Delhi │  │Amst │ │Rott  │
│gal │ │      │  │     │ │      │
│ore │ │      │  │     │ │      │
│    │ │      │  │     │ │      │
└────┘ └──────┘  └─────┘ └──────┘

SO = Shelter Owner

Legend:
[Parent role] ─► [Child roles] = Role hierarchy
                  (child can see parent's records)
```

**Role Visibility Rules**:

| Role | Can See | Example |
|------|---------|---------|
| System Admin | All records in all regions | All dogs, all shelters, all requests |
| Regional_Admin_India | All records in India region | All dogs in (Bangalore, Delhi, Jaipur, Mumbai) shelters |
| Shelter_Owner_Bangalore | Only Bangalore shelter's records | Only Bangalore dogs, only Bangalore adoption requests |
| Adopter | All dogs (read-only) | Can see all available dogs, can submit adoption request for any dog |

---

## 6. User Journeys

### Journey 1: Adopter Flow

```
Adopter User (No Shelter Assignment)
│
├─ T0: Open dogAdoptionList LWC component
│  └─ Wire adapter calls: getAvailableDogs()
│     └─ Query: SELECT * FROM Dog__c WHERE Status = 'Available'
│        └─ Result: List of all available dogs across all shelters
│
├─ T1: Browse dogs
│  ├─ Search by name, breed
│  ├─ Filter by shelter location
│  └─ View dog cards with image, age, breed, shelter info
│
├─ T2: Click "Adopt" button on specific dog
│  └─ Modal opens with adoption form
│     ├─ Adopter Name (required)
│     ├─ Email (required)
│     ├─ Phone (required)
│     └─ Notes (optional)
│
├─ T3: Submit adoption request
│  └─ LWC calls: requestAdoption(dogId, name, email, phone)
│     │
│     ├─ DogAdoptionController validates:
│     │  └─ Query: Does this dog already have non-rejected request?
│     │     ├─ If yes: throw AuraHandledException
│     │     │  └─ User sees: "Another adoption request is pending for this dog"
│     │     │
│     │     └─ If no: CREATE Adoption_Request__c
│     │        ├─ Status = 'Submitted'
│     │        ├─ Adoption_Stage = 'Pending Approval'
│     │        └─ insert record
│     │
│     ├─ DogTrigger fires (afterInsert)
│     │  └─ AdoptionRequestTriggerHandler.afterInsert()
│     │     └─ syncDogStatus(requests)
│     │        └─ Update Dog__c.Status = 'Pending Adoption'
│     │           └─ Dog disappears from available list
│     │
│     ├─ Approval Process automatically triggered
│     │  └─ Creates ProcessInstance (Salesforce native)
│     │  └─ Routes to Shelter_Owner__c for approval
│     │
│     └─ Response to LWC: Success
│        └─ Toast: "Adoption request submitted!"
│        └─ Modal closes
│        └─ Dog list refreshes (dog removed)
│
├─ T4: Track adoption status
│  └─ Adopter can view their submitted requests
│     ├─ View request status (Submitted, Approved, Rejected)
│     ├─ View associated dog info
│     └─ Wait for shelter owner approval
│
└─ T5: Approval/Rejection
   ├─ If approved: Dog status changes to 'Adopted'
   ├─ If rejected: Dog status changes back to 'Available'
   └─ Adopter receives notification of status change
```

### Journey 2: Shelter Owner Flow

```
Shelter Owner (Assigned to one shelter)
│
├─ T0: Open AnimalShelter app
│  └─ Role hierarchy: Can only see their assigned shelter's data
│     └─ Shelter_Facility__c record visible (read-only)
│
├─ T1: Manage dogs
│  ├─ View: List of all dogs for their shelter
│  ├─ Create: New dog record
│  │  └─ Fill: Name, Breed, Age, Description, Status
│  │  └─ Breed change triggers image fetch (async Queueable)
│  │     └─ DogImageFetchQueueable executes
│  │        └─ Calls Dog CEO API to fetch random image for breed
│  │        └─ Updates Dog.Image_URL__c
│  │
│  ├─ Edit: Existing dog
│  │  ├─ Can modify: Name, Breed, Age, Description, Status
│  │  └─ If Breed changes:
│  │     └─ DogTriggerHandler.afterUpdate() detects change
│  │        └─ Enqueues DogImageFetchQueueable
│  │           └─ Fetches new image for updated breed
│  │
│  └─ Delete: Remove dog (cascades to adoption requests)
│
├─ T2: Review adoption requests
│  └─ View: All adoption requests for their shelter's dogs
│     ├─ Status column shows: Submitted, Approved, Rejected
│     ├─ Adopter info: Name, Email, Phone
│     └─ Notes from adopter
│
├─ T3: Approve/Reject adoption request
│  ├─ Option A: Use Standard Salesforce Approval Process
│  │  └─ Click "Approve" or "Reject" on Adoption_Request__c record
│  │     └─ ProcessInstance handles workflow
│  │     └─ User comment (optional)
│  │     └─ Updates Adoption_Request.Status
│  │        └─ Trigger syncs Dog.Status
│  │
│  └─ Option B: Custom Approval UI (LWC)
│     └─ Toggle buttons: Approve / Reject
│        └─ Calls ApprovalProcessController
│           └─ Submits to Salesforce native approval
│
├─ T4: Monitor shelter status
│  └─ Dashboard (future feature)
│     ├─ Total dogs available
│     ├─ Pending adoptions
│     ├─ Completed adoptions (this month/year)
│     └─ Top breeds
│
└─ T5: Receive notifications
   ├─ When new adoption request received (Chatter or email)
   ├─ When request needs approval
   └─ When adopter updates their request
```

### Journey 3: Regional Admin Flow

```
Regional Admin (India or Netherlands)
│
├─ T0: Open AnimalShelter app
│  └─ Role hierarchy: Can see ALL shelters in their region
│     ├─ Regional_Admin_India sees: Bangalore, Delhi, Jaipur, Mumbai shelters
│     └─ Regional_Admin_Netherlands sees: Amsterdam, Rotterdam shelters
│
├─ T1: Manage shelters across region
│  └─ View list of all shelters in region
│     ├─ Create: New shelter (select city using dependent picklist)
│     │  ├─ Step 1: Select Region (e.g., "India")
│     │  └─ Step 2: Select City
│     │     └─ City picklist dynamically shows only Indian cities
│     │        └─ {Bangalore, Delhi, Jaipur, Mumbai}
│     │
│     ├─ Edit: Shelter configuration
│     │  ├─ Update shelter name
│     │  ├─ Update endpoint URL (for notifications)
│     │  ├─ Update active status
│     │  └─ City field is read-only (permission)
│     │
│     └─ View: Status of each shelter
│        ├─ How many dogs
│        ├─ How many pending adoptions
│        └─ Last updated time
│
├─ T2: Oversee all adoption requests in region
│  └─ View: All adoption requests across all region shelters
│     ├─ Filter by: Shelter, Status, Date range
│     ├─ Bulk actions: Approve multiple requests
│     └─ Escalate: Override shelter owner approval
│
├─ T3: Approve/Reject adoption requests (escalation)
│  └─ Can override shelter owner approval/rejection
│     ├─ Update Adoption_Request.Status
│     ├─ Add regional notes
│     └─ Notifies affected parties
│
└─ T4: Regional reporting & analytics
   └─ Dashboard (future feature)
      ├─ Dogs by city
      ├─ Adoption completion rates
      ├─ Busiest shelters
      └─ Regional growth metrics
```

### Journey 4: System Admin Flow

```
System Admin (salesforcedev@adyen.com)
│
├─ T0: Full platform access
│  └─ Can see & manage: All regions, all shelters, all dogs, all requests
│
├─ T1: Setup & configuration
│  ├─ Create new regions (Phase 2: Custom Metadata Type)
│  ├─ Create regional managers (roles + users)
│  ├─ Create shelter locations
│  │  └─ No code changes needed - add via database records
│  ├─ Configure approval workflows
│  └─ Set up integrations (named credentials, API endpoints)
│
├─ T2: Monitor org health
│  ├─ API usage (Dog CEO API calls, callout limits)
│  ├─ Data volume (count of dogs, requests, shelters)
│  ├─ Error logs (failed image fetches, notification failures)
│  └─ Trigger execution logs
│
├─ T3: Troubleshoot issues
│  ├─ Re-run failed Queueables (image fetches)
│  ├─ Check DogTriggerHandler logs for validation errors
│  ├─ Monitor Approval Process status
│  └─ Verify data isolation is working
│
└─ T4: Migrate data
   ├─ Bulk upload dogs for new shelter
   ├─ Bulk approve/reject requests
   └─ Generate compliance reports (data residency, audit trail)
```

---

## 7. Approval Process Flow (Standard Salesforce)

### Configuration

```
Approval Process Name: Adoption_Request_Approval

Entry Criteria:
├─ Adoption_Request__c.Status = 'Submitted'
└─ Adoption_Request__c.CreatedDate = TODAY

Approval Step 1: Shelter Owner Review
├─ Assigned to: Dog__r.Shelter_Facility__r.Owner__c (Shelter Owner)
├─ Due date: 3 days
├─ Actions on approval:
│  ├─ Update Adoption_Request.Status = 'Approved'
│  ├─ Update Adoption_Request.Adoption_Stage = 'Approved'
│  └─ Send email to adopter
│
├─ Actions on rejection:
│  ├─ Update Adoption_Request.Status = 'Rejected'
│  ├─ Update Adoption_Request.Adoption_Stage = 'Rejected'
│  └─ Return to requesting user with comments
│
└─ Actions on recall:
   └─ Reset to 'Submitted'

Final Approval: System Admin (Escalation)
├─ If approval takes > 3 days
└─ Route to regional admin for override
```

### Trigger Integration with Approval Process

```
When Adoption_Request_Trigger fires on afterUpdate:
├─ Check if Adoption_Request.Status changed
├─ If Status = 'Approved':
│  └─ Update Dog__c.Status = 'Adopted'
│  └─ Update Adoption_Request.Adoption_Stage = 'Approved'
│
├─ If Status = 'Rejected':
│  └─ Update Dog__c.Status = 'Available'
│  └─ Update Adoption_Request.Adoption_Stage = 'Rejected'
│
└─ Trigger validates no conflict between approval state and dog state
```

---

## 8. Data Isolation & Security Architecture

### Multi-Layer Isolation

```
Layer 1: OrgWideDefault (Private)
├─ All custom objects default to Private
└─ Users see NOTHING by default

Layer 2: Role Hierarchy
├─ System Admin at top
├─ Regional Admins in middle (India, Netherlands)
└─ Shelter Owners at bottom (1 per shelter)
└─ Role hierarchy ensures: child roles inherit parent's records

Layer 3: Sharing Rules
├─ Manual sharing (future): Can share specific records
├─ Master-Detail ControlledByParent
│  └─ Child records inherit parent's visibility
│  └─ Cascading delete maintains data integrity

Layer 4: Dependent Picklists
├─ Region controls City field
├─ UI-level filtering prevents selection of invalid combinations
├─ Validation rule enforces at database level

Layer 5: Validation Rules
├─ Validate_Region_City_Match formula
│  └─ If Region='India' AND City NOT IN {Bangalore, Delhi, Jaipur, Mumbai}
│     └─ Error: "Invalid Region-City combination"
│
├─ Unique constraint on {Shelter__c, Dog.Name}
│  └─ Trigger-based validation prevents duplicate dog names
│
└─ One non-rejected adoption request per dog
   └─ Query-based validation in controller

Layer 6: Permission Sets
├─ AnimalShelterAdmin (System Admins)
│  └─ All fields: Readable ✓ Editable ✓
│
├─ Shelter_Owner
│  └─ Shelter_Facility__c.Region: Readable ✓ Editable ✗
│  └─ Shelter_Facility__c.City: Readable ✓ Editable ✗
│  └─ Dog fields: Readable ✓ Editable ✓
│  └─ Adoption_Request fields: Readable ✓ Editable ✓
│
└─ Adopter
   └─ Dog: Readable ✓ Editable ✗
   └─ Adoption_Request (own only): Readable ✓ Editable ✓
```

### Example: Data Visibility by Role

```
Scenario: 3 shelters created
├─ Shelter 1: Bangalore, India
├─ Shelter 2: Amsterdam, Netherlands
└─ Shelter 3: Delhi, India

Dogs created:
├─ Dog A in Shelter 1 (Bangalore)
├─ Dog B in Shelter 1 (Bangalore)
├─ Dog C in Shelter 2 (Amsterdam)
├─ Dog D in Shelter 3 (Delhi)
└─ Dog E in Shelter 3 (Delhi)

Who sees what?

1. System Admin
   └─ Sees: A, B, C, D, E (all dogs)

2. Regional_Admin_India
   └─ Sees: A, B, D, E (Bangalore + Delhi only)

3. Regional_Admin_Netherlands
   └─ Sees: C (Amsterdam only)

4. Shelter_Owner_Bangalore
   └─ Sees: A, B (Bangalore shelter only)

5. Shelter_Owner_Amsterdam
   └─ Sees: C (Amsterdam shelter only)

6. Shelter_Owner_Delhi
   └─ Sees: D, E (Delhi shelter only)

7. Adopter
   └─ Sees: A, B, C, D, E (all available dogs - read-only)
      Can submit adoption request for ANY dog
```

---

## 9. Trigger Framework & Business Logic

### DogTrigger Events

```
trigger DogTrigger on Dog__c (before insert, before update, after insert, after update) {
    new DogTriggerHandler().run();
}

┌─ beforeInsert
├─ beforeUpdate
│  └─ DogTriggerHandler.validateUniqueDogNamePerShelter()
│     ├─ Query: SELECT Id FROM Dog__c 
│     │          WHERE Shelter_Facility__c IN :shelterIds 
│     │          AND Name IN :dogNames
│     ├─ For each new dog, check if name already exists in that shelter
│     └─ If duplicate found:
│        └─ Throw AuraHandledException
│           └─ User sees: "A dog named 'Buddy' already exists in this shelter"
│
├─ afterInsert
│
├─ afterUpdate
│  └─ DogTriggerHandler.afterInsert()
│  └─ DogTriggerHandler.afterUpdate()
│     ├─ Check if Breed__c field changed
│     ├─ If yes:
│     │  └─ Enqueue DogImageFetchQueueable
│     │     ├─ execute(QueueableContext): called by system in 5-30 seconds
│     │     ├─ For each dog:
│     │     │  ├─ Call DogImageService.fetchRandomImageByBreed(breed)
│     │     │  │  └─ HTTP GET to https://dog.ceo/api/breed/{breed}/images/random
│     │     │  │     └─ Parse JSON response
│     │     │  │     └─ Extract image URL
│     │     │  │
│     │     │  └─ Update Dog__c.Image_URL__c with fetched URL
│     │     │
│     │     └─ Enqueue ShelterNotificationQueueable (chained job)
│     │        └─ HTTP POST to Shelter_Facility__c.Endpoint_URL__c
│     │           └─ Send dog metadata to regional shelter system
│     │
│     └─ If no change: skip image fetch
│
└─ Trigger deactivation: See trigger metadata in sfdx-project
```

### AdoptionRequestTrigger Events

```
trigger AdoptionRequestTrigger on Adoption_Request__c 
    (before insert, after insert, after update) {
    new AdoptionRequestTriggerHandler().run();
}

┌─ afterInsert
│  └─ AdoptionRequestTriggerHandler.afterInsert(newRequests)
│     ├─ For each new Adoption_Request with Status='Submitted':
│     │  └─ dogStatusUpdates.put(dogId, 'Pending Adoption')
│     │
│     └─ Batch update: UPDATE Dog__c SET Status='Pending Adoption'
│        └─ Dog disappears from available list (getAvailableDogs filter)
│
├─ afterUpdate
│  └─ AdoptionRequestTriggerHandler.afterUpdate(newMap, oldMap)
│     ├─ For each updated request:
│     │  ├─ If Status changed from 'Submitted' to 'Approved':
│     │  │  └─ dogStatusUpdates.put(dogId, 'Adopted')
│     │  │
│     │  ├─ If Status changed to 'Rejected':
│     │  │  └─ dogStatusUpdates.put(dogId, 'Available')
│     │  │
│     │  └─ [Future: Publish Platform Event for async notifications]
│     │
│     └─ Batch update: UPDATE Dog__c with status changes
│
└─ Data integrity: No orphaned Adoption_Request records
   └─ Master-Detail cascading delete ensures cleanup
```

### Queueable Chain

```
T=0.1s: DogTrigger fires (afterInsert)
│
└─► enqueueJob(DogImageFetchQueueable)
    │
    T=5-30s: System executes DogImageFetchQueueable.execute(ctx)
    │
    ├─ Loop through dogs in batch
    ├─ Call DogImageService.fetchRandomImageByBreed(breed)
    │  └─ HTTP GET to Dog CEO API
    │  └─ Return image URL (or null)
    │
    ├─ Batch update: UPDATE Dog__c SET Image_URL__c = url
    │
    └─► enqueueJob(ShelterNotificationQueueable)
        │
        T=35-60s: System executes ShelterNotificationQueueable.execute(ctx)
        │
        ├─ Re-query Dog with Shelter_Facility__r relationship
        │  └─ Get Image_URL__c (now populated) and Endpoint_URL__c
        │
        ├─ Loop through dogs
        ├─ Build JSON payload:
        │  {
        │    "salesforceId": "a0A1x00000...",
        │    "name": "Buddy",
        │    "breed": "labrador",
        │    "age": 3,
        │    "imageUrl": "https://images.dog.ceo/...",
        │    "status": "Available",
        │    "event": "DOG_RECORD_CREATED"
        │  }
        │
        ├─ HTTP POST to Shelter_Facility__c.Endpoint_URL__c
        │  └─ If success (200-299): Log success
        │  └─ If failure: Log error [Future: Publish Platform Event]
        │
        └─ Job completes
```

---

## 10. Asynchronous Processing

### Why Queueables?

| Feature | Queueable | Batch | Future |
|---------|-----------|-------|--------|
| Chaining | ✓ Yes | ✓ Yes | ✗ No |
| HTTP Callouts | ✓ Yes | ✗ No | ✓ Yes |
| Governor Limits | 5 chained jobs | Batch jobs | 50/day |
| Execution Time | 1 hour max | 1 hour max | 1 minute |
| **Use Case** | Async + callouts | Bulk processing | Simple deferred |

**Our Use**: Queueables because we need HTTP callouts + job chaining.

### DogImageFetchQueueable

```java
public class DogImageFetchQueueable implements Queueable, AllowsCallouts {
    private List<Dog__c> dogsToProcess;

    public void execute(QueueableContext ctx) {
        for (Dog__c dog : dogsToProcess) {
            String imageUrl = DogImageService.fetchRandomImageByBreed(dog.Breed__c);
            if (imageUrl != null) {
                dog.Image_URL__c = imageUrl;
            }
        }
        update dogsToProcess;
        
        // Chain next job
        System.enqueueJob(new ShelterNotificationQueueable(dogsToProcess));
    }
}
```

**When Executed**:
- Trigger calls: `System.enqueueJob(new DogImageFetchQueueable(dogs))`
- System queues the job
- 5-30 seconds later: execute() method runs
- Makes HTTP calls to Dog CEO API
- Updates dog records with images
- Enqueues next job in chain

---

## 11. Future Scalability Options

### Phase 2: Custom Metadata Types for Dynamic City Management

**Problem**: Currently cities are hardcoded in validation rule and picklist. Adding new city requires code change.

**Solution**: Use Custom Metadata Type (CMT) for city management.

```java
// Create Region_City_Mapping__mdt custom metadata type
// Records:
// ├─ India.Bangalore
// ├─ India.Delhi
// ├─ India.Jaipur
// ├─ India.Mumbai
// ├─ Netherlands.Amsterdam
// └─ Netherlands.Rotterdam

public class RegionCityHelper {
    public static Map<String, Set<String>> getCityByRegion() {
        Map<String, Set<String>> regionCityMap = new Map<String, Set<String>>();
        
        for (Region_City_Mapping__mdt mapping : 
             [SELECT Region__c, City__c FROM Region_City_Mapping__mdt]) {
            if (!regionCityMap.containsKey(mapping.Region__c)) {
                regionCityMap.put(mapping.Region__c, new Set<String>());
            }
            regionCityMap.get(mapping.Region__c).add(mapping.City__c);
        }
        return regionCityMap;
    }
}
```

**Benefits**:
- Admins can add new cities via Setup → Custom Metadata Type Records
- No code deployments needed
- Validation rule can query CMT instead of hardcoded values
- Picklist values auto-populate from metadata

### Phase 3: Multi-Region Expansion Architecture

```
Scenario: Adyen expands to 5 countries

Current:
└─ 1 Salesforce Org (Global)
   ├─ India region data
   └─ Netherlands region data

Phase 3:
├─ Global Salesforce Org (Central metadata, non-PII only)
│  ├─ Dog metadata (breed, age, image URL)
│  ├─ Approval workflows
│  └─ User management
│
├─ India Middleware + Local Database
│  └─ Adopter PII (encrypted at rest)
│
├─ Netherlands Middleware + Local Database
│  └─ Adopter PII (encrypted at rest)
│
├─ USA Middleware + Local Database
│  └─ Adopter PII (encrypted at rest)
│
├─ EU Middleware + Local Database
│  └─ Adopter PII (GDPR encrypted at rest)
│
└─ Japan Middleware + Local Database
   └─ Adopter PII (encrypted at rest)
```

**Benefits**:
- Salesforce acts as orchestration layer (no PII)
- Regional systems handle their own data residency
- Scalable to unlimited regions
- Each region can have different encryption/retention policies

### Phase 4: Advanced Features

```
Future Enhancements:

1. Video Integration
   ├─ Store video URLs in Dog__c
   ├─ Integr with YouTube/Vimeo APIs
   └─ Auto-generate intro videos for each dog

2. Social Media Integration
   ├─ Auto-post new dogs to Instagram/Facebook
   ├─ Queueable for social media publishing
   └─ Track engagement metrics

3. AI/ML Analytics
   ├─ Predict adoption success rate (breed, age, shelter)
   ├─ Recommend matching adopters
   └─ Forecasting: how long until adopted

4. Mobile App
   ├─ Native iOS/Android app
   ├─ Offline dog browsing (cached)
   └─ Push notifications for adoption status

5. Real-time Notifications
   ├─ Platform Events (Pub-Sub)
   ├─ Adopter notified instantly of approval
   └─ Websocket integration (future)

6. Audit & Compliance Dashboard
   ├─ Data residency audit trail
   ├─ Encryption verification
   └─ GDPR/CCPA compliance reports
```

---

## 12. Implementation Summary

### What's Implemented ✅

| Component | Status | Details |
|-----------|--------|---------|
| **Objects** | ✅ | Shelter_Facility__c, Dog__c, Adoption_Request__c |
| **Relationships** | ✅ | Master-Detail with ControlledByParent sharing |
| **Data Isolation** | ✅ | OrgWideDefault Private + Role Hierarchy |
| **Dependent Picklists** | ✅ | Region → City with validation rule |
| **Unique Constraints** | ✅ | {Shelter__c, Dog Name} via trigger |
| **Approval Process** | ✅ | Standard Salesforce Approval Process |
| **Validation Rules** | ✅ | Region-City match validation |
| **Triggers** | ✅ | DogTrigger, AdoptionRequestTrigger |
| **Queueables** | ✅ | DogImageFetchQueueable, ShelterNotificationQueueable |
| **LWC Components** | ✅ | dogAdoptionList, dogCard, adoptionForm |
| **Apex Controllers** | ✅ | DogAdoptionController, ApprovalProcessController |
| **External APIs** | ✅ | Dog CEO API integration (image fetching) |
| **Permission Sets** | ✅ | AnimalShelterAdmin, Shelter_Owner, Adopter |
| **Role Hierarchy** | ✅ | System Admin > Regional Admin > Shelter Owner |

### What's Not Yet Implemented 🚧

| Component | Status | Timeline |
|-----------|--------|----------|
| **Custom Metadata Types** | 🚧 Phase 2 | Dynamic city management |
| **Middleware Layer** | 🚧 Phase 3 | Java/Spring Boot for multi-region PII handling |
| **Platform Events** | 🚧 Phase 3 | Async notifications & retry logic |
| **Mobile App** | 🚧 Phase 4 | Native iOS/Android |
| **Analytics Dashboard** | 🚧 Phase 4 | Real-time adoption metrics |
| **Video Integration** | 🚧 Phase 4 | Dog introduction videos |
| **Social Media Publishing** | 🚧 Phase 4 | Auto-post to Instagram/Facebook |

---

## 13. Deployment Checklist

```
Pre-Deployment:
☐ Run all tests: npm test (Jest)
☐ Check code style: eslint
☐ Lint SFDX metadata: sfdx-project.json valid
☐ Review code for security (OWASP Top 10)
☐ Verify all custom objects exist

Deployment to animal-shelter-dev:
☐ Deploy objects: Shelter_Facility__c, Dog__c, Adoption_Request__c
☐ Deploy fields: All custom fields with correct types & constraints
☐ Deploy validation rules: Validate_Region_City_Match
☐ Deploy permission sets: AnimalShelterAdmin, Shelter_Owner, Adopter
☐ Deploy role hierarchy: System Admin > Regional > Shelter Owner
☐ Deploy approval process: Adoption_Request_Approval
☐ Deploy triggers: DogTrigger, AdoptionRequestTrigger
☐ Deploy Apex classes: All controllers, handlers, services
☐ Deploy LWC components: dogAdoptionList, dogCard, etc.
☐ Deploy named credentials: DogCeoApi

Post-Deployment:
☐ Create test shelters: Bangalore, Amsterdam
☐ Create test dogs: At least 5 per shelter
☐ Create test users: Adopter, Shelter Owner, Regional Admin, System Admin
☐ Assign roles: Users to role hierarchy
☐ Assign permission sets: Users to permission sets
☐ Test adoption flow end-to-end: Browse → Submit → Approve → Verify status sync
☐ Test data isolation: Verify role-based visibility
☐ Test dependent picklist: Select region, verify city options
☐ Test image fetching: Create dog, verify image fetched async
☐ Test unique constraint: Try creating duplicate dog name
☐ Verify no errors in debug logs
```

---

## 14. Configuration for Future Regions

### To Add New Shelter (No Code Changes Required)

```
Step 1: Create new Shelter_Facility__c record in Salesforce
├─ Name: "New City Animal Shelter"
├─ Region__c: "India" (select from picklist)
├─ City__c: "Jaipur" (dependent picklist shows only Indian cities)
├─ Endpoint_URL__c: "https://jaipur-shelter-api.adyen.local/sync"
├─ Active__c: ☑ checked
└─ Click Save

Step 2: Validation rule automatically checks Region-City match
├─ If mismatch: Error message appears
└─ If valid: Record saved

Step 3: Assign Shelter Owner via role hierarchy
├─ Create user: "jaipur-owner@adyen.com"
├─ Assign role: "Shelter_Owner_Jaipur"
├─ Set role parent: "Regional_Admin_India"
└─ User can now see only Jaipur dogs & requests

Step 4: Add dogs for new shelter
├─ System Admin creates first dog record
├─ Breed selected → Image fetch triggers async
├─ Dog appears in LWC list for all users
└─ Adopters can submit requests immediately

That's it! No code deployment needed.
```

---

## 15. Architecture Diagrams Legend

```
Legend:
────────────────────────────────────────

┌──────────┐
│ Component│        = Component/Object
└──────────┘

    │
    ├─ Text          = Relationship/Flow
    │
    ▼

  [Inline]          = Inline decision/note

    ◄────            = Data/Control flow
    ────►

    ◄──────►         = Bidirectional

━━━━━━━━━━         = Boundary/Border

✓ or ☑              = Enabled/Yes
✗ or ☐              = Disabled/No
🚧                  = In Progress/Future
```

---

## Summary: Architecture Tiers

| Tier | Layer | Components | Purpose |
|------|-------|-----------|---------|
| **1** | Presentation | LWC (dogAdoptionList, dogCard) | User interface |
| **2** | Business Logic | Apex Controllers | API for LWC |
| **3** | Workflow | Triggers, Approval Process | Event handling |
| **4** | Data Model | Custom Objects, Fields | Data persistence |
| **5** | Security | Roles, Permission Sets, Sharing | Access control |
| **6** | Integration | Queueables, Named Credentials | External APIs |
| **7** | Validation | Rules, Constraints | Data integrity |

---

**Document Status**: Complete  
**Next Review**: December 2026  
**Contact**: Rohit Manethiya (rohitand07@gmail.com)
