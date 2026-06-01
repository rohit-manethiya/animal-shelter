/**
 * Generic trigger handler base class (Kevin O'Hara pattern).
 * Each object gets one trigger that delegates to one handler class.
 * Supports bypass per handler name (useful in tests and data migrations).
 */
public virtual class TriggerHandler {

    @TestVisible private static Set<String> bypassedHandlers = new Set<String>();
    @TestVisible private static Map<String, Integer> loopCountMap = new Map<String, Integer>();
    private static final Integer MAX_LOOP_COUNT = 5;

    private String handlerName;
    private TriggerContext context;

    public TriggerHandler() {
        this.handlerName = getHandlerName();
        this.setTriggerContext();
    }

    public void run() {
        if (!validateRun()) return;
        incrementLoopCount();

        switch on context {
            when BEFORE_INSERT  { beforeInsert(); }
            when BEFORE_UPDATE  { beforeUpdate(); }
            when BEFORE_DELETE  { beforeDelete(); }
            when AFTER_INSERT   { afterInsert(); }
            when AFTER_UPDATE   { afterUpdate(); }
            when AFTER_DELETE   { afterDelete(); }
            when AFTER_UNDELETE { afterUndelete(); }
        }
    }

    public static void bypass(String handlerName) {
        bypassedHandlers.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        bypassedHandlers.remove(handlerName);
    }

    public static Boolean isBypassed(String handlerName) {
        return bypassedHandlers.contains(handlerName);
    }

    private Boolean validateRun() {
        if (!Trigger.isExecuting) {
            throw new TriggerHandlerException('Trigger handler called outside of trigger context');
        }
        if (bypassedHandlers.contains(handlerName)) return false;
        if (loopCountMap.containsKey(handlerName) &&
            loopCountMap.get(handlerName) >= MAX_LOOP_COUNT) {
            throw new TriggerHandlerException('Maximum loop count exceeded for: ' + handlerName);
        }
        return true;
    }

    private void incrementLoopCount() {
        Integer count = loopCountMap.containsKey(handlerName)
            ? loopCountMap.get(handlerName) : 0;
        loopCountMap.put(handlerName, count + 1);
    }

    private String getHandlerName() {
        return String.valueOf(this).substringBefore(':');
    }

    private void setTriggerContext() {
        if (!Trigger.isExecuting) return;
        if      (Trigger.isBefore && Trigger.isInsert)   context = TriggerContext.BEFORE_INSERT;
        else if (Trigger.isBefore && Trigger.isUpdate)   context = TriggerContext.BEFORE_UPDATE;
        else if (Trigger.isBefore && Trigger.isDelete)   context = TriggerContext.BEFORE_DELETE;
        else if (Trigger.isAfter  && Trigger.isInsert)   context = TriggerContext.AFTER_INSERT;
        else if (Trigger.isAfter  && Trigger.isUpdate)   context = TriggerContext.AFTER_UPDATE;
        else if (Trigger.isAfter  && Trigger.isDelete)   context = TriggerContext.AFTER_DELETE;
        else if (Trigger.isAfter  && Trigger.isUndelete) context = TriggerContext.AFTER_UNDELETE;
    }

    protected virtual void beforeInsert()  {}
    protected virtual void beforeUpdate()  {}
    protected virtual void beforeDelete()  {}
    protected virtual void afterInsert()   {}
    protected virtual void afterUpdate()   {}
    protected virtual void afterDelete()   {}
    protected virtual void afterUndelete() {}

    public enum TriggerContext {
        BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
        AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE, AFTER_UNDELETE
    }

    public class TriggerHandlerException extends Exception {}
}
