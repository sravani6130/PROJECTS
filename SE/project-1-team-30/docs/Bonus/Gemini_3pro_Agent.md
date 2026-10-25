

## Phase 1: Analysis (Smell Identification)

### 1. God Class / Service Locator Pattern
**Severity**: High
**Location**: 
- `app/src/main/java/org/apache/roller/weblogger/business/WebloggerImpl.java`
- `app/src/main/java/org/apache/roller/weblogger/business/Weblogger.java`

**Why it’s a problem**: 
The `WebloggerImpl` class acts as a central registry for all system managers (18+ dependencies injected). This violates the **Interface Segregation Principle (ISP)** because clients that depend on `Weblogger` get access to every manager, even if they only need one. It creates high coupling and makes testing difficult because mocking `Weblogger` often requires mocking its entire hierarchy of returned managers. It encourages a "Service Locator" anti-pattern where dependencies are pulled rather than injected.

### 2. Single Responsibility Principle (SRP) Violation
**Severity**: Medium-High
**Location**: 
- `app/src/main/java/org/apache/roller/weblogger/business/WeblogEntryManager.java`

**Why it’s a problem**: 
The `WeblogEntryManager` interface handles disparate domain concepts:
1.  **Weblog Entries** (CRUD, Searching)
2.  **Categories** (Groupings for entries)
3.  **Comments** (User feedback on entries)
4.  **Statistics/Hit Counts**

By bunching these responsibilities together, the class becomes cohesive only by "association to a blog entry", not by behavior. Changes to comment moderation logic require rebuilding the entire entry management module. This violates **Single Responsibility Principle**.

### 3. Anemic Domain Model with Hidden Static Dependencies
**Severity**: Medium
**Location**: 
- `app/src/main/java/org/apache/roller/weblogger/pojos/WeblogEntry.java`

**Why it’s a problem**: 
The `WeblogEntry` POJO contains hidden dependencies on the static `WebloggerFactory` and `WebloggerRuntimeConfig` classes (e.g., inside `getCreator()` and `getCommentsStillAllowed()`). 
- **Hidden Dependencies**: It makes the POJO impossible to test in isolation without starting the entire application context or mocking static factories.
- **Tight Coupling**: The domain object knows about the container/factory mechanism.

---

## Phase 2: Refactoring Plan

### Strategy 1: Decompose `WebloggerImpl` (Shift to Direct Injection)
Instead of injecting `Weblogger` into consumers, we should inject the specific managers they need. 
*   **Action**: Deprecate `Weblogger` as a dependency.
*   **Refactoring**: Update Guice modules to bind managers directly (which is likely already done). The primary refactoring in the `WebloggerImpl` is to recognize it as a legacy artifact and stop adding to it.
*   *Note: For this exercise, we will focus on demonstrating the decomposition of the Manager interfaces themselves, as removing `Weblogger` requires touching hundreds of files.*

### Strategy 2: Split `WeblogEntryManager`
We will break `WeblogEntryManager` into three distinct services:
1.  `WeblogEntryService`: Strictly for Entry CRUD and search.
2.  `WeblogCategoryService`: For Category management.
3.  `CommentService`: For Comment management.

This improves cohesion. `WeblogEntryManager` can remain as a **Facade** for backward compatibility, but implementation should be delegated to the new services.

### Strategy 3: Purify `WebloggerEntry` POJO
We will remove the static calls from `WeblogEntry`.
1.  **For `getCreator()`**: The `User` object should be hydrated by the Service/Repository when fetching the Entry, or the method should act on a passed `UserManager` if lazy loading is absolutely required (though eager fetching or Proxy usage is better). We will change it to return the `creator` object which must be set by the caller.
2.  **For `getCommentsStillAllowed()`**: The configuration logic belongs in a Service or Strategy, not the POJO. We will move this logic to a `CommentPolicy` or `CommentService`.

---

## Phase 3: Refactored Code

Here are the refactored components.

### 1. New Service Interfaces (Split `WeblogEntryManager`)

#### `app/src/main/java/org/apache/roller/weblogger/business/WeblogEntryService.java`
```java
package org.apache.roller.weblogger.business;

import java.util.Date;
import java.util.List;
import java.util.Map;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.pojos.WeblogEntrySearchCriteria;
import org.apache.roller.weblogger.pojos.StatCount;

/**
 * Service specifically for managing Weblog Entries.
 * Refactored from WeblogEntryManager.
 */
public interface WeblogEntryService {

    void saveWeblogEntry(WeblogEntry entry) throws WebloggerException;

    void removeWeblogEntry(WeblogEntry entry) throws WebloggerException;

    WeblogEntry getWeblogEntry(String id) throws WebloggerException;

    WeblogEntry getWeblogEntryByAnchor(Weblog website, String anchor) throws WebloggerException;

    List<WeblogEntry> getWeblogEntries(WeblogEntrySearchCriteria wesc) throws WebloggerException;

    Map<Date, List<WeblogEntry>> getWeblogEntryObjectMap(WeblogEntrySearchCriteria wesc) throws WebloggerException;

    Map<Date, String> getWeblogEntryStringMap(WeblogEntrySearchCriteria wesc) throws WebloggerException;
    
    List<StatCount> getMostCommentedWeblogEntries(
            Weblog website,             
            Date startDate,
            Date endDate,
            int offset, 
            int length) throws WebloggerException;
            
    WeblogEntry getNextEntry(WeblogEntry current, String catName, String locale) throws WebloggerException;    
    
    WeblogEntry getPreviousEntry(WeblogEntry current, String catName, String locale) throws WebloggerException;
      
    List<WeblogEntry> getWeblogEntriesPinnedToMain(Integer max) throws WebloggerException;

    void removeWeblogEntryAttribute(String name, WeblogEntry entry) throws WebloggerException;

    String createAnchor(WeblogEntry data) throws WebloggerException;
}
```

#### `app/src/main/java/org/apache/roller/weblogger/business/WeblogCategoryService.java`
```java
package org.apache.roller.weblogger.business;

import java.util.List;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogCategory;

/**
 * Service specifically for managing Weblog Categories.
 * Refactored from WeblogEntryManager.
 */
public interface WeblogCategoryService {

    void saveWeblogCategory(WeblogCategory cat) throws WebloggerException;
    
    void removeWeblogCategory(WeblogCategory cat) throws WebloggerException;
        
    WeblogCategory getWeblogCategory(String id) throws WebloggerException;
    
    void moveWeblogCategoryContents(WeblogCategory srcCat, WeblogCategory destCat) throws WebloggerException;
    
    WeblogCategory getWeblogCategoryByName(Weblog website, String categoryName) throws WebloggerException;

    List<WeblogCategory> getWeblogCategories(Weblog website) throws WebloggerException;
    
    boolean isDuplicateWeblogCategoryName(WeblogCategory data) throws WebloggerException;  
    
    boolean isWeblogCategoryInUse(WeblogCategory data) throws WebloggerException;    
}
```

#### `app/src/main/java/org/apache/roller/weblogger/business/CommentService.java`
```java
package org.apache.roller.weblogger.business;

import java.util.Date;
import java.util.List;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.CommentSearchCriteria;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.pojos.WeblogEntryComment;
import org.apache.roller.weblogger.pojos.WeblogEntryComment.ApprovalStatus;

/**
 * Service specifically for managing Comments.
 * Refactored from WeblogEntryManager.
 */
public interface CommentService {

    void saveComment(WeblogEntryComment comment) throws WebloggerException;
    
    void removeComment(WeblogEntryComment comment) throws WebloggerException;
   
    WeblogEntryComment getComment(String id) throws WebloggerException;
       
    List<WeblogEntryComment> getComments(CommentSearchCriteria csc) throws WebloggerException;

    int removeMatchingComments(
            Weblog          website,
            WeblogEntry     entry,
            String          searchString,
            Date            startDate,
            Date            endDate,
            ApprovalStatus  status
            ) throws WebloggerException;
            
     void applyCommentDefaultsToEntries(Weblog website) throws WebloggerException;
}
```

### 2. Refactored POJO (`WeblogEntry`)

We remove the static dependency on `WebloggerFactory` and `WebloggerRuntimeConfig`.

#### `app/src/main/java/org/apache/roller/weblogger/pojos/WeblogEntryRefactored.java`
(Intended to replace `WeblogEntry.java`)

```java
package org.apache.roller.weblogger.pojos;

import java.io.Serializable;
import java.sql.Timestamp;
import java.util.*;
import org.apache.commons.lang3.builder.EqualsBuilder;
import org.apache.commons.lang3.builder.HashCodeBuilder;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.roller.util.UUIDGenerator;
// Removed: org.apache.roller.weblogger.business.WebloggerFactory;
// Removed: org.apache.roller.weblogger.config.WebloggerRuntimeConfig;

public class WeblogEntryRefactored implements Serializable {
    private static final Log mLogger = LogFactory.getFactory().getInstance(WeblogEntry.class);
    
    // ... (Other fields omitted for brevity) ...

    private String    creatorUserName = null;      
    
    // Explicit association. Must be set by the service layer or ORM.
    private User      creator = null;

    // ... (Other fields omitted) ...

    // Refactored: No longer calls static factory. 
    // The Service Layer is responsible for setting this object.
    public User getCreator() {
        return this.creator;
    }   
    
    public void setCreator(User creator) {
        this.creator = creator;
        if (creator != null) {
            this.creatorUserName = creator.getUserName();
        }
    }

    public String getCreatorUserName() {
        return creatorUserName;
    }

    public void setCreatorUserName(String creatorUserName) {
        this.creatorUserName = creatorUserName;
    }   

    // ... (Other standard getters/setters omitted) ...

    /**
     * Refactored: Logic moved out or simplified.
     * This method previously checked global config statically.
     * Now it only checks local object state. 
     * The Service layer should check global config before calling this or 
     * use a Policy object.
     */
    public boolean getCommentsStillAllowed() {
        // Global config check removed. 
        // This method now answers: "Does this specific entry allow comments based on its own settings?"
        
        if (getWebsite() != null && getWebsite().getAllowComments() != null && !getWebsite().getAllowComments()) {
            return false;
        }
        if (getAllowComments() != null && !getAllowComments()) {
            return false;
        }
        
        if (getCommentDays() == null || getCommentDays() == 0) {
            return true;
        }

        // Expiration logic
        Date inPubTime = getPubTime();
        if (inPubTime == null) {
            inPubTime = getUpdateTime();
        }
        
        Calendar expireCal = Calendar.getInstance(
                getWebsite().getLocaleInstance());
        expireCal.setTime(inPubTime);
        expireCal.add(Calendar.DATE, getCommentDays());
        Date expireDay = expireCal.getTime();
        Date today = new Date();
        
        return today.before(expireDay);
    }
}
```

### 3. Implementation Facade (Optional Transition Step)

To maintain backward compatibility while we refactor, `JPAWeblogEntryManagerImpl` can implement the old interface but delegate to new implementations.

```java
// Example of how the implementation would be split
public class JPAWeblogEntryServiceImpl implements WeblogEntryService {
    // Implementation of Entry methods...
}

public class JPAWeblogCategoryServiceImpl implements WeblogCategoryService {
    // Implementation of Category methods...
}

// The old manager can become a facade or simple aggregator
public class JPAWeblogEntryManagerImpl implements WeblogEntryManager {
    @Inject
    private WeblogEntryService entryService;
    @Inject
    private WeblogCategoryService categoryService;
    @Inject
    private CommentService commentService;

    // Delegates
    public void saveWeblogEntry(WeblogEntry entry) throws WebloggerException {
        entryService.saveWeblogEntry(entry);
    }
    
    // ... delegation for all other methods
}
```
