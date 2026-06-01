# Adyen Animal Shelter - Presentation Guide

## Interview Structure (as per case study)

```
Total Time: 90 minutes

├─ 5 minutes  : Introduction (you)
├─ 15 minutes : Case presentation (Part 1 + Part 2)
├─ 60 minutes : Q&A and technical deep-dives
└─ 10 minutes : Questions from candidate
```

---

## Part 1: Assignment 1 Presentation (5-7 minutes)

### Opening Statement

> "I've designed and implemented a Salesforce-based dog adoption platform for the Adyen Animal Shelter. The solution focuses on three core capabilities: automated dog onboarding with external image fetching, adoption lifecycle management, and a user-friendly interface for discovery and adoption requests. The architecture emphasizes scalability through configuration-driven endpoints, allowing future expansion to multiple regional shelters without code deployments."

### Key Points to Cover (in order)

#### 1. **The Problem** (30 seconds)
- Adyen wants to digitize dog adoption process
- Multiple shelters need to be managed from one Salesforce org
- Images must be sourced automatically from public APIs
- Adoption workflow must track dogs from available to adopted

#### 2. **Data Model** (1 minute)
- Show diagram or describe 3 core objects:
  - **Dog__c**: Represents a dog with breed, age, image, status
  - **Adoption_Request__c**: Tracks adoption lifecycle (submitted → approved → rejected)
  - **Shelter_Facility__c**: Regional shelter configuration with API endpoints
- Emphasize: Master-Detail relationships ensure data integrity

#### 3. **Architecture Highlights** (2 minutes)

**Show your slides/diagram**:

```
User submits adoption → Salesforce validates → Creates Adoption_Request
                                             ↓
                        AdoptionRequestTrigger fires
                                             ↓
                        Updates Dog status (Pending Adoption)
                                             ↓
                        UI refreshes automatically (dog removed from list)
```

**Async Processing**:
```
New dog created → DogTrigger fires → Enqueue DogImageFetchQueueable
                                             ↓
                  Fetches image from Dog CEO API (public, free)
                                             ↓
                  Updates Dog.Image_URL__c with fetched image
                                             ↓
                  Chains to ShelterNotificationQueueable
                                             ↓
                  Sends dog metadata to regional shelter endpoints
```

**Key Design Pattern**: 
- **Configuration over Code**: Shelter endpoints stored in database records, not hardcoded
- **Async Processing**: Queueables ensure dog creation completes immediately
- **Error Resilience**: Failed image fetches don't block dog creation

#### 4. **Technology Stack** (1 minute)

| Component | Technology | Why |
|-----------|-----------|-----|
| Backend | Apex + Triggers | Salesforce native, tight integration |
| UI | Lightning Web Components | Modern, cached, responsive |
| Async Jobs | Queueables | Chainable, better monitoring than @future |
| Image Service | Dog CEO API (public) | Free, no auth, reliable |
| External Integration | HTTP callouts + Named Credentials | Secure, environment-agnostic |
| Framework | TriggerHandler pattern | Kevin O'Hara best practice |

#### 5. **Live Demo / Screenshots** (1-2 minutes)

**Walk through the UI**:
1. Show the Dogs tab with adoption list
2. Click on a dog card (show details: breed, age, shelter, image)
3. Click "Adopt" button → modal opens
4. Fill in adopter info (name, email, phone)
5. Submit → success toast → dog disappears from list
6. Show that Adoption_Request__c and updated Dog__c status in backend

**If demo doesn't work**: 
- Show screenshots of:
  - Dogs tab with populated dog list
  - Dog card components
  - Adoption request form
  - Successful submission toast
  - Backend records (Dog, Adoption_Request with updated status)

### Closing: Assignment 1

> "The implementation is production-ready with proper error handling, audit logging, and scalability built in. The configuration-driven architecture means adding a new regional shelter facility is a matter of creating one Salesforce record—zero code deployments required."

---

## Part 2: Assignment 2 Presentation (5-8 minutes)

### Context Setting

> "As Adyen Animal Shelter expands globally, they plan to open a facility in India. India has strict data residency laws that require all personally identifiable information—names, emails, phone numbers—to remain on infrastructure physically located within India. The global Salesforce org cannot store this PII. My task was to design an architecture that allows global users to manage the India shelter while maintaining full compliance with data residency requirements."

### Architecture Overview (2-3 minutes)

**Show your diagram**:

```
Global Salesforce Org (US/EU)
    ↓ (REST API + JWT)
India Middleware (Spring Boot, Java)
    ↓ (Encrypted connections)
India Local Database
```

**Key Principle**: 
- SF stores **metadata only** (dog ID, breed, age, image URL, status)
- Middleware stores **sensitive data** (adopter names, emails, phones)
- **Zero PII in Salesforce**, even encrypted

### Three-Tier Architecture (3-4 minutes)

#### Tier 1: Global Salesforce Org (US/EU hosted)

**Data Stored**:
```
✓ Dog metadata (breed, age, image URL, status)
✓ Adoption request metadata (request number, status, timestamps)
✗ Adopter names, emails, phone numbers (NEVER stored)
```

**Components**:
- LWC components for user interface
- Apex controllers calling middleware APIs
- Named Credential for middleware authentication (JWT-based)

#### Tier 2: India Middleware (Gateway)

**Tech Stack**: Spring Boot 3.x + Java 17

**Key Responsibilities**:
1. **Authentication**: Issue JWT tokens to Salesforce users
2. **Authorization**: Enforce shelter isolation (user can only access India data)
3. **Encryption**: Encrypt PII before storing in India DB
4. **API Gateway**: RESTful endpoints for:
   - GET /api/v1/dogs (return dogs without PII)
   - GET /api/v1/dogs/:id (return dog details)
   - POST /api/v1/adoptions (create adoption with PII)
   - PATCH /api/v1/adoptions/:id/approve (update adoption status)
5. **Audit Logging**: Log every API call for compliance

**Security Features**:
- JwtTokenProvider (RS256 signing with India-specific keys)
- DataEncryptionService (AES-256-GCM)
- ShelterIsolationFilter (prevent cross-shelter data leakage)
- Spring Security filters (validate all requests)

#### Tier 3: India Local Database

**PII Stored Encrypted**:
```
Dogs Table:
  - id, name, breed, age, image_url, status, shelter_id
  
Adoptions Table:
  - id, dog_id, adopter_name_ENCRYPTED, adopter_email_ENCRYPTED,
    adopter_phone_ENCRYPTED, sf_adoption_id, status, shelter_id
    
AuditLog Table (immutable):
  - timestamp, user_id, action, resource_type, http_status, shelter_id
```

### Why This Architecture? (1 minute)

| Requirement | How Solved |
|-----------|-----------|
| **PII stays in India** | All sensitive data stored in India DB only, encrypted |
| **Global users manage shelter** | Middleware APIs allow SF users to interact without accessing PII directly |
| **Compliance proof** | Immutable audit logs show PII never left India |
| **Scalable for other regions** | Same middleware pattern (US, EU, China, etc.) with region-specific databases |
| **Secure in transit** | TLS 1.3 + JWT authentication + encrypted payloads |

### Data Flow Example (2 minutes)

**Scenario**: Global user (US) submits adoption request for India dog

```
Timeline:
T=0s   Global SF user clicks "Adopt" on India dog
T=1s   LWC calls Apex which gets JWT from middleware
T=2s   Calls middleware: POST /api/v1/adoptions with PII
       {
         "dogId": "ind-dog-001",
         "adopterName": "Rajesh Kumar",      ← PII
         "adopterEmail": "rajesh@example.com" ← PII
         "adopterPhone": "+91-9876543210"    ← PII
       }
T=3s   Middleware (in India) receives request
       - Validates JWT
       - Encrypts PII: adopterName → AES-256 ciphertext
       - Stores in India DB (encrypted)
       - Returns confirmation (NO PII in response)
T=4s   SF receives: {"adoptionId": "IND-001", "status": "submitted"}
T=5s   User sees: "Request submitted!" (PII NEVER touched SF)
```

**Compliance Guarantee**:
- Adopter name "Rajesh Kumar" stored ONLY in India (encrypted)
- NEVER transmitted back to SF
- NEVER appears in SF logs or backups
- Audit trail proves full compliance

### Presentation Closing

> "This architecture demonstrates how to build globally scalable SaaS while respecting local data residency laws. The middleware pattern is production-proven (similar to how Stripe, Twilio, and others handle regional compliance). By using Spring Boot and Java, the middleware is maintainable and can be extended to support other regions with the same codebase."

---

## Anticipated Q&A (Based on Case Study)

### Question 1: "Why Queueables instead of scheduled batch jobs?"

**Answer**:
> "Queueables offer two advantages here:
> 
> 1. **Job Chaining**: After fetching images, I immediately enqueue the shelter notification job. Scheduled jobs can't depend on each other.
> 2. **Better Monitoring**: I can query AsyncApexJob to track status; @future methods offer limited visibility.
> 
> For bulk operations >100 dogs, I'd implement chunking (split into batches of 50) to respect the 100-callout-per-transaction limit."

### Question 2: "How do you prevent duplicate adoption requests?"

**Answer**:
> "In DogAdoptionController.requestAdoption(), before creating a request, I query:
> ```
> SELECT Id FROM Adoption_Request__c
> WHERE Dog__c = :dogId AND Status__c != 'Rejected'
> ```
> If found, I throw AuraHandledException. This prevents multiple active requests for one dog.
> 
> Trigger-based status sync ensures the dog status is updated immediately, so the UI refreshes and the dog is no longer available for another request."

### Question 3: "What happens if the Dog CEO API is down?"

**Answer**:
> "The image fetch fails gracefully:
> - DogImageService returns null
> - DogImageFetchQueueable skips that dog and continues
> - Dog is created successfully WITHOUT an image
> - Image_URL__c remains null
> 
> **Future improvement**: Publish Platform Event on failure → Flow can retry after delay, or alert admin to manually fetch image."

### Question 4: "How do you ensure shelter isolation (one shelter can't see another's data)?"

**Answer**:
> "For Assignment 1 (current state), it's handled via role-based sharing rules. The Adoption_Request__c inherits sharing from parent Dog__c, which is a child of Shelter_Facility__c.
> 
> For Assignment 2 (India expansion), the middleware enforces isolation at the database query level:
> ```java
> WHERE shelter_id = :userShelterContext
> ```
> No user can query data from another shelter, even with valid JWT, because the middleware filter adds this WHERE clause."

### Question 5: "Why use a Named Credential instead of hardcoding the API endpoint?"

**Answer**:
> "Named Credentials separate configuration from code:
> - **No secrets in code**: The Dog CEO API endpoint is stored securely in SF
> - **Environment flexibility**: Sandbox and production can point to different endpoints
> - **Audit trail**: Changes to credentials are logged and tracked
> - **Rotation**: If Dog CEO API changes URLs, I update one record instead of redeploying
> 
> This is Salesforce best practice, especially for production."

### Question 6: "Describe the adoption lifecycle. What statuses can a dog have?"

**Answer**:
> "Dog__c.Status__c has four values:
> - **Available** (default): Dog ready for adoption
> - **Pending Adoption**: Active adoption request submitted
> - **Adopted**: Adoption request approved
> - **On Hold** (future): Temporary hold
> 
> Status transitions are trigger-driven based on Adoption_Request__c:
> ```
> Request Status "Submitted" → Dog Status "Pending Adoption"
> Request Status "Approved" → Dog Status "Adopted"
> Request Status "Rejected" → Dog Status reverts to "Available"
> ```
> 
> This keeps the two objects in sync without manual intervention."

### Question 7: "How do you handle the India expansion from a Java perspective?"

**Answer**:
> "From a Java/Spring Boot perspective, the middleware is a standard REST API:
> 
> **Core Components**:
> 1. **JwtTokenProvider**: Generate/validate JWT tokens (RS256 algorithm with India-specific private key)
> 2. **REST Controllers**: @RestController classes for /dogs, /adoptions endpoints
> 3. **Services**: Business logic (encrypt PII, enforce shelter isolation, validate requests)
> 4. **Repositories**: Spring Data JPA for database access (ORM)
> 5. **Security Configuration**: Spring Security + custom filters
> 
> **Deployment**: Docker container on AWS ECS (India region) or GCP Cloud Run (India region).
> 
> **Key Security**:
> - All endpoints require Bearer JWT token
> - Custom filter adds shelter_id to all queries
> - Encryption key stored in AWS Secrets Manager (India region only)"

### Question 8: "What are the scalability limits you've identified?"

**Answer**:
> "Two main constraints:
> 
> **1. Image Fetching (Salesforce)**
> - Dog CEO API: ~100 calls/minute rate limit
> - Salesforce: 100 callouts per transaction
> - Solution: Chunk dogs into batches of 50-75, enqueue separate Queueables
> 
> **2. Middleware Database (India)**
> - Single RDS instance can handle ~10k requests/second (Aurora PostgreSQL)
> - For high load: Read replicas for queries, write goes to primary
> - Horizontal scaling: Multiple middleware instances behind AWS load balancer
> 
> **Future Improvements**:
> - Cache dog lists in Redis (India region) for faster reads
> - Use CloudFront CDN for image URLs
> - Implement async adoption notifications (don't block user)"

### Question 9: "How do you test this in a sandbox?"

**Answer**:
> "I've provided loadTestData.apex script that:
> 1. Creates 2 test Shelter_Facility__c records (Amsterdam, Rotterdam)
> 2. Creates 6 Dog__c records with valid Dog CEO API breeds
> 3. Uses httpbin.org as mock shelter endpoint
> 
> **Manual testing**:
> - Insert dog → verify Image_URL__c populated after ~30 seconds
> - Submit adoption request → verify Dog status changes, dog disappears from list
> - Rejection flow → verify dog reverts to Available
> 
> **Automated testing** (future):
> - Unit tests for trigger handlers (bypass, status transitions)
> - Mock callouts to Dog CEO API
> - Test error scenarios (network timeout, invalid breed)"

### Question 10: "Why did you choose this approach over [alternative]?"

**Answer** (adapt based on their suggestion):

*If they ask about serverless (Lambda instead of Spring Boot)*:
> "Spring Boot gives us better local testing, easier debugging, and cleaner code structure. Lambda would work for simple APIs, but middleware needs state management (token validation, encryption key caching). Spring Boot's dependency injection and autoconfiguration make it cleaner for a production middleware layer."

*If they ask about replicating data to SF (sync via Platform Events)*:
> "That would violate India's data residency requirement. Platform Event logs could leave India's infrastructure. The middleware approach ensures PII is processed and stored entirely in-country."

*If they ask about using Salesforce Data Cloud*:
> "Data Cloud is great for analytics, but it would require replicating PII to Salesforce's cloud. For compliance reasons, we need zero PII in the global org. Middleware maintains that boundary."

---

## Slides Outline (if presenting slides)

### Slide 1: Title
```
Adyen Animal Shelter
Salesforce + Java Solution for Adoption Workflow

Rohit Manethiya
May 29, 2026
```

### Slide 2: Problem Statement
```
Challenge: Build scalable adoption platform for Adyen Animal Shelter
Scope:
  ✓ Multi-shelter support
  ✓ Automated image fetching
  ✓ Adoption lifecycle management
  ✓ Global + regional expansion (India compliance)
```

### Slide 3: Assignment 1 Architecture
```
[Show component diagram]
LWC UI → Apex Controllers → Triggers & Handlers → Queueables → External APIs
```

### Slide 4: Data Model
```
Shelter_Facility__c (1) ←→ (Many) Dog__c (1) ←→ (Many) Adoption_Request__c
- Master-Detail relationships ensure referential integrity
- Status fields track adoption lifecycle
```

### Slide 5: Key Design Decisions
```
1. Queueables for async processing (job chaining, monitoring)
2. Configuration-driven endpoints (no code deployments for new shelters)
3. Graceful error handling (failed image fetch doesn't block dog creation)
4. Trigger handler pattern (clean separation of concerns)
```

### Slide 6: Assignment 2 Overview
```
India Expansion Challenge:
  - Adyen wants to operate India facility
  - India law: All PII must stay in India
  - Global users must manage India shelter
  
Solution: Middleware gateway + local database
```

### Slide 7: India Architecture
```
[Show three-tier diagram]
Global Salesforce (metadata only)
    ↓
India Middleware (Java/Spring Boot, gateway + encryption)
    ↓
India Database (PII encrypted at rest)
```

### Slide 8: Why This Architecture?
```
✓ Zero PII in Salesforce (compliance guarantee)
✓ Middleware provides encryption, audit logs, shelter isolation
✓ TLS 1.3 + JWT = secure in-flight
✓ Scalable to other regions (same middleware, different configs)
✓ Production-proven pattern (Stripe, Twilio, etc.)
```

### Slide 9: Demo (or Screenshots)
```
Live demo:
1. Dogs tab with adoption list
2. Click dog → shows details + Adopt button
3. Submit adoption → modal fills, form submits
4. Success! Dog removed from list (status updated)
```

### Slide 10: Q&A
```
Questions?

Contact:
Rohit Manethiya
rohitand07@gmail.com
```

---

## Pre-Interview Checklist

- [ ] **Deployment**: Deploy force-app to sandbox
  ```bash
  sf org login web --set-default
  sf project deploy start --manifest force-app/main/default
  ```

- [ ] **Test Data**: Load test dogs
  ```bash
  sf apex run --file scripts/apex/loadTestData.apex
  ```

- [ ] **Verify Setup**:
  - [ ] DogCeoApi named credential exists
  - [ ] 2 Shelter_Facility__c records exist
  - [ ] 6 Dog__c records created (wait 1-2 min for async image fetch)
  - [ ] dogAdoptionList component displays dogs with images

- [ ] **Admin User**: Create salesforcedev@adyen.com
  ```bash
  sf user create --target-org <alias> \
    --firstname Adyen --lastname Dev \
    --email salesforcedev@adyen.com
  ```

- [ ] **Documentation**: Ensure these files are in repo
  - [x] IMPLEMENTATION_GUIDE.md
  - [x] ARCHITECTURE_AND_EXPANSION.md
  - [x] PRESENTATION_GUIDE.md (this file)
  - [x] loadTestData.apex

- [ ] **Slides/Diagrams**: Prepare presentation
  - [ ] Create slides (PowerPoint, Google Slides, or Figma)
  - [ ] Export architecture diagrams as images
  - [ ] Prepare 2-3 screenshot examples

- [ ] **Submission**: Send to salesforcedev@adyen.com
  - Submit at least 2 days before interview
  - Include: slides/demo link, documentation, sandbox credentials

---

## Day-of-Interview Tips

### 5-Minute Introduction
- Introduce yourself (name, background, experience)
- Why you're interested in this role at Adyen
- Brief summary of your solution approach

### 15-Minute Presentation
- **Pace**: Speak clearly, not too fast
- **Show, Don't Tell**: Live demo if confident; screenshots if safer
- **Highlight Decisions**: Explain WHY (not just WHAT)
- **Time Management**: 5 min Part 1, 5 min Part 2, 5 min buffer

### 60-Minute Q&A
- **Listen carefully**: Answer the exact question asked
- **Admit unknowns**: "I haven't considered that—here's how I'd approach it..."
- **Deep dives**: Be ready to explain code in detail
- **Trade-offs**: Show awareness of alternatives

### 10-Minute Close
- Ask intelligent questions:
  - "How does the India expansion roadmap look?"
  - "What security compliance does Adyen require?"
  - "What does the team look like on the Salesforce side?"
  - "What's the typical on-call rotation?"

---

## Key Phrases to Use

1. **"Configuration over code"** - When discussing endpoint management
2. **"Trigger-driven architecture"** - For lifecycle management
3. **"Queueable job chaining"** - For async processing
4. **"Compliance by design"** - For data residency in India
5. **"Graceful degradation"** - For error handling
6. **"Master-Detail relationships"** - For data integrity
7. **"Spring Boot microservice gateway"** - For middleware
8. **"End-to-end encryption"** - For India security
9. **"Production-ready implementation"** - For polishing your answer

---

## Post-Interview Follow-up

If they ask for more info:
- Offer to write Apex unit tests
- Offer to implement retry logic for shelter notifications
- Offer to build middleware proof-of-concept
- Offer to document database schema (India middleware)

---

## Good luck! 🎯

You've built a solid solution. The key is confidently explaining **why** you made each choice, not just **what** you built.

Remember: Interviewers want to see:
1. **Problem-solving** (how you approached the challenge)
2. **Best practices** (scalability, security, maintainability)
3. **Communication** (explaining technical concepts clearly)
4. **Passion** (interest in the role and the problem domain)

Go make them impressed! 💪
