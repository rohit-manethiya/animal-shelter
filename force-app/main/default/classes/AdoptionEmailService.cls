public without sharing class AdoptionEmailService {

    // ─── Public entry points (called from trigger handler) ────────────────────

    /** After insert: confirm to adopter + notify shelter owner. */
    public static void sendOnSubmission(List<Adoption_Request__c> newRequests) {
        List<Id> ids = new List<Id>();
        for (Adoption_Request__c req : newRequests) {
            if (req.Status__c == 'Submitted') ids.add(req.Id);
        }
        if (ids.isEmpty()) return;

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Adoption_Request__c req : queryEnriched(ids)) {
            if (String.isNotBlank(req.Adopter_Email__c)) {
                emails.add(adopterConfirmation(req));
            }
            // Shelter owner notification on submission is handled by the
            // Salesforce Approval Process — no duplicate email sent here.
        }
        send(emails);
    }

    /** After update: email adopter when request is Approved or Rejected. */
    public static void sendOnStatusChange(
        List<Adoption_Request__c> newList,
        Map<Id, Adoption_Request__c> oldMap
    ) {
        List<Id> ids = new List<Id>();
        for (Adoption_Request__c req : newList) {
            String prev = oldMap.get(req.Id).Status__c;
            if (req.Status__c != prev &&
                (req.Status__c == 'Approved' || req.Status__c == 'Rejected')) {
                ids.add(req.Id);
            }
        }
        if (ids.isEmpty()) return;

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Adoption_Request__c req : queryEnriched(ids)) {
            if (String.isNotBlank(req.Adopter_Email__c)) {
                emails.add(adopterDecision(req));
            }
        }
        send(emails);
    }

    // ─── Query ────────────────────────────────────────────────────────────────

    private static List<Adoption_Request__c> queryEnriched(List<Id> ids) {
        return [
            SELECT Id, Name, Status__c, Request_Date__c,
                   Adopter_Name__c, Adopter_Email__c, Adopter_Phone__c,
                   Dog__r.Name, Dog__r.Breed__c,
                   Dog__r.Shelter_Facility__r.Name,
                   Dog__r.Shelter_Facility__r.Owner.Email
            FROM   Adoption_Request__c
            WHERE  Id IN :ids
        ];
    }

    // ─── Email builders ───────────────────────────────────────────────────────

    private static Messaging.SingleEmailMessage adopterConfirmation(Adoption_Request__c req) {
        String dog         = safe(req.Dog__r?.Name);
        String shelter     = safe(req.Dog__r?.Shelter_Facility__r?.Name);
        String requestDate = req.Request_Date__c?.format();

        String body =
              '<p>Dear ' + enc(req.Adopter_Name__c) + ',</p>'
            + '<p>Thank you! We have received your adoption request for '
            + '<strong>' + enc(dog) + '</strong> at <strong>' + enc(shelter) + '</strong>.</p>'
            + '<table style="border-collapse:collapse;margin:8px 0;">'
            + row('Request Reference', req.Name)
            + row('Dog',               dog)
            + row('Date Submitted',    requestDate)
            + '</table>'
            + '<p>Our team will review your request shortly and be in touch.</p>'
            + '<p>Best regards,<br/><strong>' + enc(shelter) + '</strong></p>';

        return build(req.Adopter_Email__c,
                     'Adoption Request Received – ' + dog,
                     body);
    }

    private static Messaging.SingleEmailMessage shelterOwnerAlert(
        Adoption_Request__c req, String ownerEmail
    ) {
        String dog = safe(req.Dog__r?.Name);
        String breed = req.Dog__r?.Breed__c;

        String body =
              '<p>A new adoption request has been submitted for one of your dogs.</p>'
            + '<table style="border-collapse:collapse;margin:8px 0;">'
            + row('Request',       req.Name)
            + row('Dog',           dog + (breed != null ? ' (' + breed + ')' : ''))
            + row('Adopter Name',  req.Adopter_Name__c)
            + row('Adopter Email', req.Adopter_Email__c)
            + row('Adopter Phone', req.Adopter_Phone__c ?? '–')
            + row('Date',          req.Request_Date__c?.format())
            + '</table>'
            + '<p>Log in to Salesforce to review and approve or reject this request.</p>';

        return build(ownerEmail,
                     'New Adoption Request: ' + dog + ' – ' + req.Name,
                     body);
    }

    private static Messaging.SingleEmailMessage adopterDecision(Adoption_Request__c req) {
        String dog     = safe(req.Dog__r?.Name);
        String shelter = safe(req.Dog__r?.Shelter_Facility__r?.Name);
        Boolean approved = (req.Status__c == 'Approved');

        String subject = approved
            ? 'Great News! Your Adoption of ' + dog + ' is Approved'
            : 'Update on Your Adoption Request for ' + dog;

        String body = '<p>Dear ' + enc(req.Adopter_Name__c) + ',</p>';
        if (approved) {
            body += '<p>We\'re thrilled to confirm that your adoption request for '
                 +  '<strong>' + enc(dog) + '</strong> has been <strong>approved</strong>!</p>'
                 +  '<p>Please contact <strong>' + enc(shelter) + '</strong> to arrange a pickup time.</p>'
                 +  '<p>Welcome to the family! 🐾</p>';
        } else {
            body += '<p>Thank you for your interest in adopting <strong>' + enc(dog) + '</strong>.</p>'
                 +  '<p>After careful review, we are unable to proceed with your request at this time. '
                 +  enc(dog) + ' is now available for other adoption applications.</p>'
                 +  '<p>We encourage you to browse our other available dogs — we hope to find you the perfect match soon.</p>';
        }
        body += '<p>Best regards,<br/><strong>' + enc(shelter) + '</strong></p>';

        return build(req.Adopter_Email__c, subject, body);
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static Messaging.SingleEmailMessage build(
        String toAddress, String subject, String htmlBody
    ) {
        Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
        m.setToAddresses(new List<String>{ toAddress });
        m.setSubject(subject);
        m.setHtmlBody(htmlBody);
        m.setSaveAsActivity(false);
        return m;
    }

    /**
     * Sends emails using a verified Org-Wide Email Address when available.
     * OWA makes the FROM domain match your organisation's domain instead of
     * salesforce.com, which is the primary reason emails land in spam.
     * Fallback: setSenderDisplayName if no OWA is configured yet.
     */
    private static void send(List<Messaging.SingleEmailMessage> emails) {
        if (emails.isEmpty()) return;

        Id owaId = getOrgWideEmailAddressId();
        for (Messaging.SingleEmailMessage m : emails) {
            if (owaId != null) {
                m.setOrgWideEmailAddressId(owaId);
            } else {
                m.setSenderDisplayName('Animal Shelter');
            }
        }

        Messaging.sendEmail(emails, false);
    }

    /**
     * Returns the Id of the first active Org-Wide Email Address.
     * Returns null if none is configured — callers fall back gracefully.
     */
    @TestVisible
    private static Id getOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> owas = [
            SELECT Id
            FROM   OrgWideEmailAddress
            WHERE  IsAllowAllProfiles = true
            LIMIT  1
        ];
        return owas.isEmpty() ? null : owas[0].Id;
    }

    private static String row(String label, String value) {
        return '<tr>'
             + '<td style="padding:4px 12px 4px 0;font-weight:bold;color:#444;">' + enc(label) + ':</td>'
             + '<td style="padding:4px 0;">' + enc(value ?? '–') + '</td>'
             + '</tr>';
    }

    /** Null-safe field value. */
    private static String safe(String s) {
        return String.isNotBlank(s) ? s : '–';
    }

    /** HTML-encode to prevent injection in email body. */
    private static String enc(String s) {
        return s != null ? s.escapeHtml4() : '';
    }
}
