# Apache Roller Design Smell Analysis & Refactoring Documentation

# Phase 1: Design Smell Identification

## Design Smell #1: God Class / Single Responsibility Principle Violation

### **Location**
- **File**: `roller/app/src/main/java/org/apache/roller/weblogger/business/jpa/JPAWeblogEntryManagerImpl.java`
- **Lines**: 1-1394 (entire file, ~1400 lines)
- **Class**: `JPAWeblogEntryManagerImpl`

### **Why It's a Problem**

The `JPAWeblogEntryManagerImpl` class has **too many responsibilities**, violating the Single Responsibility Principle (SRP):

1. **Weblog Entry Management** - CRUD operations for entries
2. **Comment Management** - CRUD operations for comments  
3. **Category Management** - CRUD operations for categories
4. **Tag Management** - Tag CRUD, tag aggregates, tag statistics
5. **Hit Count Tracking** - Managing view counts
6. **Query Building** - Complex dynamic query construction
7. **Cache Management** - Entry anchor-to-ID mapping
8. **Business Logic** - Publishing, scheduling, anchor generation

**Consequences:**
- **Hard to Test**: One class requires mocking many dependencies
- **High Coupling**: Changes to one feature affect others
- **Poor Maintainability**: 1400 lines is too much cognitive load
- **Difficult to Extend**: Adding new features requires modifying this massive class
- **Violation of OCP**: Class is open for modification, not extension

### **Code Example Demonstrating the Problem**

```java
@com.google.inject.Singleton
public class JPAWeblogEntryManagerImpl implements WeblogEntryManager {
    
    private static final Log LOG = LogFactory.getLog(JPAWeblogEntryManagerImpl.class);
    
    private final Weblogger roller;
    private final JPAPersistenceStrategy strategy;
    
    // cached mapping of entryAnchors -> entryIds
    private final Map<String, String> entryAnchorToIdMap = 
        Collections.synchronizedMap(new HashMap<String, String>());
    
    // Methods for Entry Management (lines 180-300)
    public void saveWeblogEntry(WeblogEntry entry) { /* ... */ }
    public void removeWeblogEntry(WeblogEntry entry) { /* ... */ }
    
    // Methods for Category Management (lines 90-160)
    public void saveWeblogCategory(WeblogCategory cat) { /* ... */ }
    public void removeWeblogCategory(WeblogCategory cat) { /* ... */ }
    
    // Methods for Comment Management (lines 150-180, 630-750)
    public void saveComment(WeblogEntryComment comment) { /* ... */ }
    public void removeComment(WeblogEntryComment comment) { /* ... */ }
    public List<WeblogEntryComment> getComments(CommentSearchCriteria csc) { /* ... */ }
    
    // Methods for Tag Management (lines 1000-1200)
    public List<TagStat> getTags(Weblog website, String sortBy, ...) { /* ... */ }
    public boolean getTagComboExists(List<String> tags, Weblog weblog) { /* ... */ }
    private void updateTagCount(String name, Weblog website, int amount) { /* ... */ }
    
    // Methods for Hit Count (lines 1300-1394)
    public void incrementHitCount(Weblog weblog, int amount) { /* ... */ }
    
    // MANY MORE METHODS...
}
```

---

## Design Smell #2: Utility Class Anti-Pattern / Static Method Abuse

### **Location**
- **File**: `roller/app/src/main/java/org/apache/roller/weblogger/util/Utilities.java`
- **Lines**: 1-1066 (entire file, ~1100 lines)
- **Class**: `Utilities`

### **Why It's a Problem**

The `Utilities` class is a **dumping ground for unrelated static methods**, containing:

1. **HTML Processing** - escapeHTML, removeHTML, autoformat, addNofollow
2. **String Manipulation** - replaceNonAlphanumeric, removeNonAlphanumeric
3. **Array/List Conversions** - stringArrayToString, stringToIntArray, etc.
4. **File I/O Operations** - copyFile, copyInputToOutput, streamToString
5. **Security Functions** - encodePassword
6. **URL Utilities** - stripJsessionId
7. **Regular Expression Patterns** - 15+ compiled Pattern objects

**Consequences:**
- **Hard to Test**: Static methods difficult to mock
- **No Polymorphism**: Can't use interfaces or inheritance
- **No Dependency Injection**: Tight coupling to implementation
- **Poor Cohesion**: Unrelated functionality grouped together
- **Memory Waste**: All Pattern objects loaded even if never used
- **Violates OOP Principles**: Procedural programming in an OO language

### **Code Example Demonstrating the Problem**

```java
public class Utilities {
    private static final Log mLogger = LogFactory.getLog(Utilities.class);

    // 15+ static Pattern fields (lines 45-90)
    private static final Pattern mLinkPattern = Pattern.compile("<a href=.*?>", 
        Pattern.CASE_INSENSITIVE);
    private static final Pattern OPENING_B_TAG_PATTERN = Pattern.compile(
        "&lt;b&gt;", Pattern.CASE_INSENSITIVE);
    // ... 13 more patterns ...

    // HTML Processing (lines 100-280)
    public static String escapeHTML(String s) { /* ... */ }
    public static String removeHTML(String str) { /* ... */ }
    public static String autoformat(String s) { /* ... */ }
    public static String addNofollow(String html) { /* ... */ }

    // String Manipulation (lines 280-320)
    public static String replaceNonAlphanumeric(String str) { /* ... */ }
    public static String removeNonAlphanumeric(String str) { /* ... */ }

    // Array/List Conversions (lines 320-400)
    public static String stringArrayToString(String[] stringArray, String delim) { /* ... */ }
    public static String[] stringToStringArray(String instr, String delim) { /* ... */ }
    public static int[] stringToIntArray(String instr, String delim) { /* ... */ }

    // File I/O (lines 400-550)
    public static void copyFile(File from, File to) throws IOException { /* ... */ }
    public static String streamToString(InputStream is) throws IOException { /* ... */ }
    public static void copyInputToOutput(InputStream input, OutputStream output) { /* ... */ }

    // Security (lines 550-600)
    public static String encodePassword(String password, String algorithm) { /* ... */ }
    
    // ... MANY MORE unrelated static methods ...
}
```

---

## Design Smell #3: Feature Envy / Law of Demeter Violation

### **Location**
- **File**: `roller/app/src/main/java/org/apache/roller/weblogger/business/jpa/JPAWeblogEntryManagerImpl.java`
- **Lines**: 180-280 (specifically in `saveWeblogEntry` and related methods)
- **Multiple files** exhibiting this pattern

### **Why It's a Problem**

Multiple classes exhibit **Feature Envy** and violate the **Law of Demeter** (Don't Talk to Strangers):

**Examples of Method Chaining:**
- `entry.getWebsite().getBloggerCategory()`
- `entry.getWebsite().getWeblogCategories().iterator().next()`
- `entry.getWebsite().getHandle()`
- `roller.getWeblogManager().saveWeblog(entry.getWebsite())`
- `roller.getAutopingManager().queueApplicableAutoPings(entry)`

**Consequences:**
- **Tight Coupling**: Classes know too much about each other's structure
- **Brittle Code**: Changes to intermediate objects break calling code
- **Testing Difficulty**: Must mock entire object graphs
- **Reduced Encapsulation**: Business logic leaks across boundaries
- **Poor Readability**: "Train wreck" code is hard to understand

### **Code Example Demonstrating the Problem**

```java
@Override
public void saveWeblogEntry(WeblogEntry entry) throws WebloggerException {
    
    // SMELL: Feature Envy - reaching deep into entry's collaborators
    if (entry.getCategory() == null) {
        // Chaining through multiple objects (Law of Demeter violation)
        WeblogCategory cat = entry.getWebsite().getBloggerCategory();
        if (cat == null) {
            // Even more chaining!
            cat = entry.getWebsite().getWeblogCategories().iterator().next();
        }
        entry.setCategory(cat);
    }

    // SMELL: Feature Envy - should entry.setDefaultLocale() instead
    if (entry.getLocale() == null) {
        entry.setLocale(entry.getWebsite().getLocale());
    }
    
    // ... business logic ...
    
    // SMELL: Calling through roller to get another manager
    if(entry.isPublished()) {
        roller.getWeblogManager().saveWeblog(entry.getWebsite());
    }
    
    // SMELL: More manager chain calls
    if(entry.isPublished()) {
        roller.getAutopingManager().queueApplicableAutoPings(entry);
    }
}

@Override
public void removeWeblogEntry(WeblogEntry entry) throws WebloggerException {
    // SMELL: Method chaining for cache key
    this.entryAnchorToIdMap.remove(
        entry.getWebsite().getHandle() + ":" + entry.getAnchor()
    );
}
```

---

# Phase 2: Refactoring Strategy

## Strategy for Design Smell #1: God Class Decomposition

### **Approach**: Extract Class + Interface Segregation

**Break down `JPAWeblogEntryManagerImpl` into focused classes:**

1. **`WeblogEntryService`** - Entry CRUD and lifecycle
2. **`WeblogCategoryService`** - Category management
3. **`WeblogCommentService`** - Comment operations
4. **`WeblogTagService`** - Tag management and aggregation
5. **`WeblogHitCountService`** - View count tracking
6. **`QueryBuilder`** - Dynamic query construction (utility)

**Benefits:**
- Each class has a single, well-defined responsibility
- Easier to test in isolation
- Lower coupling between features
- Simpler to understand and modify
- Follows Open/Closed Principle

---

## Strategy for Design Smell #2: Replace Static Utilities with Services

### **Approach**: Strategy Pattern + Dependency Injection

**Transform static utility methods into injectable services:**

1. **`HtmlProcessor`** - HTML escaping, removal, sanitization
2. **`StringTransformer`** - String manipulation operations
3. **`FileOperations`** - File I/O operations
4. **`PasswordEncoder`** - Security functions
5. **`ConverterService`** - Array/List conversions

**Benefits:**
- Testable via mocking/stubbing
- Can be swapped via DI (e.g., different password algorithms)
- Lazy loading of Pattern objects
- Follows Dependency Inversion Principle
- Enables polymorphic behavior

---

## Strategy for Design Smell #3: Reduce Coupling via Tell, Don't Ask

### **Approach**: Move Behavior to Data + Facade Pattern

**Refactoring techniques:**

1. **Move Methods**: Logic using object data → move to that object
2. **Introduce Facades**: Simplify manager interactions
3. **Create Value Objects**: Reduce chattiness
4. **Apply Tell, Don't Ask**: Objects do their own work

**Benefits:**
- Reduced coupling between classes
- Better encapsulation
- More maintainable code
- Easier to test

---

# Phase 3: Refactored Code

## Refactoring #1: Decompose God Class

### **Before**: Single Monolithic Manager (1400 lines)

```java
// BEFORE: Everything in one class
@com.google.inject.Singleton
public class JPAWeblogEntryManagerImpl implements WeblogEntryManager {
    
    private final Weblogger roller;
    private final JPAPersistenceStrategy strategy;
    private final Map<String, String> entryAnchorToIdMap = 
        Collections.synchronizedMap(new HashMap<>());
    
    // 40+ methods handling entries, comments, categories, tags, hits...
    
    public void saveWeblogEntry(WeblogEntry entry) { /* ... */ }
    public void saveComment(WeblogEntryComment comment) { /* ... */ }
    public void saveWeblogCategory(WeblogCategory cat) { /* ... */ }
    public List<TagStat> getTags(Weblog website, ...) { /* ... */ }
    public void incrementHitCount(Weblog weblog, int amount) { /* ... */ }
    // ... 35+ more methods
}
```

### **After**: Separated Concerns

#### **File**: `WeblogEntryService.java`

```java
package org.apache.roller.weblogger.business.jpa;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.roller.util.RollerConstants;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.Weblogger;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.pojos.WeblogEntry.PubStatus;
import org.apache.roller.weblogger.pojos.WeblogEntryAttribute;
import org.apache.roller.weblogger.pojos.WeblogEntrySearchCriteria;
import org.apache.roller.weblogger.pojos.WeblogEntryTag;

import java.sql.Timestamp;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Focused service for managing WeblogEntry entities.
 * Handles entry CRUD operations, publishing, scheduling, and anchor management.
 */
@Singleton
public class WeblogEntryService {
    
    private static final Log LOG = LogFactory.getLog(WeblogEntryService.class);
    
    private final JPAPersistenceStrategy strategy;
    private final WeblogTagService tagService;
    private final WeblogCommentService commentService;
    private final WeblogService weblogService;
    private final AutoPingService autoPingService;
    private final EntryAnchorGenerator anchorGenerator;
    
    // Cached mapping of entryAnchors -> entryIds
    private final Map<String, String> entryAnchorToIdMap = 
        Collections.synchronizedMap(new HashMap<>());
    
    @Inject
    public WeblogEntryService(
            JPAPersistenceStrategy strategy,
            WeblogTagService tagService,
            WeblogCommentService commentService,
            WeblogService weblogService,
            AutoPingService autoPingService,
            EntryAnchorGenerator anchorGenerator) {
        
        LOG.debug("Initializing WeblogEntryService");
        this.strategy = strategy;
        this.tagService = tagService;
        this.commentService = commentService;
        this.weblogService = weblogService;
        this.autoPingService = autoPingService;
        this.anchorGenerator = anchorGenerator;
    }
    
    /**
     * Save a weblog entry.
     * Handles validation, tag updates, scheduling, and notifications.
     */
    public void saveWeblogEntry(WeblogEntry entry) throws WebloggerException {
        
        // Validate and set defaults
        entry.ensureDefaultCategoryIsSet();
        entry.ensureDefaultLocaleIsSet();
        
        if (entry.isAnchorBlank()) {
            entry.setAnchor(anchorGenerator.generateAnchor(entry));
        }
        
        // Update tag aggregates based on publishing status
        tagService.handleTagAggregatesForEntry(entry);
        
        // Handle scheduling logic
        handleSchedulingLogic(entry);
        
        // Persist the entry
        entry.setUpdateTime(new Timestamp(new Date().getTime()));
        strategy.store(entry);
        
        // Update weblog last modified time if published
        if (entry.isPublished()) {
            weblogService.touchWeblog(entry.getWebsite());
            autoPingService.queueApplicableAutoPings(entry);
        }
    }
    
    /**
     * Remove a weblog entry and all associated data.
     */
    public void removeWeblogEntry(WeblogEntry entry) throws WebloggerException {
        
        // Remove associated comments
        commentService.removeCommentsForEntry(entry);
        
        // Remove tags
        tagService.removeTagsForEntry(entry);
        
        // Remove attributes
        removeEntryAttributes(entry);
        
        // Remove the entry itself
        strategy.remove(entry);
        
        // Update weblog last modified time if was published
        if (entry.isPublished()) {
            weblogService.touchWeblog(entry.getWebsite());
        }
        
        // Invalidate cache
        String cacheKey = entry.buildCacheKey();
        entryAnchorToIdMap.remove(cacheKey);
    }
    
    /**
     * Get weblog entries matching search criteria.
     */
    public List<WeblogEntry> getWeblogEntries(WeblogEntrySearchCriteria criteria) 
            throws WebloggerException {
        
        WeblogEntryQueryBuilder queryBuilder = new WeblogEntryQueryBuilder(strategy);
        return queryBuilder.buildAndExecuteQuery(criteria);
    }
    
    /**
     * Get entry by ID.
     */
    public WeblogEntry getWeblogEntry(String id) throws WebloggerException {
        return strategy.load(WeblogEntry.class, id);
    }
    
    /**
     * Get entry by anchor.
     */
    public WeblogEntry getWeblogEntryByAnchor(String weblogHandle, String anchor) 
            throws WebloggerException {
        
        // Check cache first
        String cacheKey = weblogHandle + ":" + anchor;
        String entryId = entryAnchorToIdMap.get(cacheKey);
        
        if (entryId != null) {
            WeblogEntry entry = getWeblogEntry(entryId);
            if (entry != null) {
                LOG.debug("entryAnchorToId CACHE HIT - " + anchor);
                return entry;
            } else {
                entryAnchorToIdMap.remove(cacheKey);
            }
        }
        
        // Query database
        WeblogEntryQueryBuilder queryBuilder = new WeblogEntryQueryBuilder(strategy);
        WeblogEntry entry = queryBuilder.getByWeblogHandleAndAnchor(weblogHandle, anchor);
        
        // Update cache
        if (entry != null) {
            entryAnchorToIdMap.put(cacheKey, entry.getId());
        }
        
        return entry;
    }
    
    // ---- Private Helper Methods ----
    
    private void handleSchedulingLogic(WeblogEntry entry) {
        // If entry published to future, set status as SCHEDULED
        if (PubStatus.PUBLISHED.equals(entry.getStatus()) &&
                entry.getPubTime().after(new Date(System.currentTimeMillis() + RollerConstants.MIN_IN_MS))) {
            entry.setStatus(PubStatus.SCHEDULED);
        }
    }
    
    private void removeEntryAttributes(WeblogEntry entry) throws WebloggerException {
        if (entry.getEntryAttributes() != null) {
            Iterator<WeblogEntryAttribute> it = entry.getEntryAttributes().iterator();
            while (it.hasNext()) {
                WeblogEntryAttribute attribute = it.next();
                it.remove();
                strategy.remove(attribute);
            }
        }
    }
}
```

#### **File**: `WeblogCategoryService.java`

```java
package org.apache.roller.weblogger.business.jpa;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import jakarta.persistence.TypedQuery;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogCategory;
import org.apache.roller.weblogger.pojos.WeblogEntry;

import java.util.List;

/**
 * Focused service for managing WeblogCategory entities.
 */
@Singleton
public class WeblogCategoryService {
    
    private static final Log LOG = LogFactory.getLog(WeblogCategoryService.class);
    
    private final JPAPersistenceStrategy strategy;
    private final WeblogService weblogService;
    
    @Inject
    public WeblogCategoryService(
            JPAPersistenceStrategy strategy,
            WeblogService weblogService) {
        
        LOG.debug("Initializing WeblogCategoryService");
        this.strategy = strategy;
        this.weblogService = weblogService;
    }
    
    /**
     * Save a weblog category.
     */
    public void saveWeblogCategory(WeblogCategory category) throws WebloggerException {
        
        validateCategory(category);
        
        boolean exists = getWeblogCategoryById(category.getId()) != null;
        if (!exists && isDuplicateCategoryName(category)) {
            throw new WebloggerException("Duplicate category name: " + category.getName());
        }
        
        strategy.store(category);
        weblogService.touchWeblog(category.getWeblog());
    }
    
    /**
     * Remove a weblog category.
     */
    public void removeWeblogCategory(WeblogCategory category) throws WebloggerException {
        
        if (!category.retrieveWeblogEntries(false).isEmpty()) {
            throw new WebloggerException("Cannot remove category with entries");
        }
        
        Weblog weblog = category.getWeblog();
        weblog.getWeblogCategories().remove(category);
        
        strategy.remove(category);
        
        // If this was the blogger API category, clear it
        if (category.equals(weblog.getBloggerCategory())) {
            weblog.setBloggerCategory(null);
            strategy.store(weblog);
        }
        
        weblogService.touchWeblog(weblog);
    }
    
    /**
     * Move all entries from source category to destination category.
     */
    public void moveWeblogCategoryContents(WeblogCategory sourceCategory, 
            WeblogCategory destinationCategory) throws WebloggerException {
        
        List<WeblogEntry> entries = sourceCategory.retrieveWeblogEntries(false);
        Weblog weblog = destinationCategory.getWeblog();
        
        for (WeblogEntry entry : entries) {
            entry.setCategory(destinationCategory);
            entry.setWebsite(weblog);
            strategy.store(entry);
        }
        
        // Update Blogger API category if needed
        updateBloggerApiCategory(sourceCategory, destinationCategory);
    }
    
    /**
     * Get all categories for a weblog.
     */
    public List<WeblogCategory> getWeblogCategories(Weblog weblog) throws WebloggerException {
        
        if (weblog == null) {
            throw new WebloggerException("Weblog cannot be null");
        }
        
        TypedQuery<WeblogCategory> query = strategy.getNamedQuery(
            "WeblogCategory.getByWeblog", WeblogCategory.class);
        query.setParameter(1, weblog);
        
        return query.getResultList();
    }
    
    /**
     * Get category by ID.
     */
    public WeblogCategory getWeblogCategoryById(String id) throws WebloggerException {
        return strategy.load(WeblogCategory.class, id);
    }
    
    /**
     * Get category by name.
     */
    public WeblogCategory getWeblogCategoryByName(Weblog weblog, String name) 
            throws WebloggerException {
        
        TypedQuery<WeblogCategory> query = strategy.getNamedQuery(
            "WeblogCategory.getByWeblog&Name", WeblogCategory.class);
        query.setParameter(1, weblog);
        query.setParameter(2, name);
        
        try {
            return query.getSingleResult();
        } catch (jakarta.persistence.NoResultException e) {
            return null;
        }
    }
    
    /**
     * Check if category name is duplicate.
     */
    public boolean isDuplicateCategoryName(WeblogCategory category) throws WebloggerException {
        WeblogCategory existing = getWeblogCategoryByName(
            category.getWeblog(), category.getName());
        return existing != null && !existing.getId().equals(category.getId());
    }
    
    /**
     * Check if category is in use.
     */
    public boolean isCategoryInUse(WeblogCategory category) throws WebloggerException {
        
        if (category.getWeblog().getBloggerCategory().equals(category)) {
            return true;
        }
        
        TypedQuery<WeblogEntry> query = strategy.getNamedQuery(
            "WeblogEntry.getByCategory", WeblogEntry.class);
        query.setParameter(1, category);
        
        return !query.getResultList().isEmpty();
    }
    
    // ---- Private Helper Methods ----
    
    private void validateCategory(WeblogCategory category) throws WebloggerException {
        if (category == null) {
            throw new WebloggerException("Category cannot be null");
        }
        if (category.getWeblog() == null) {
            throw new WebloggerException("Category must have an associated weblog");
        }
        if (category.getName() == null || category.getName().isBlank()) {
            throw new WebloggerException("Category name cannot be blank");
        }
    }
    
    private void updateBloggerApiCategory(WeblogCategory source, WeblogCategory destination) 
            throws WebloggerException {
        
        Weblog weblog = source.getWeblog();
        WeblogCategory bloggerCategory = weblog.getBloggerCategory();
        
        if (bloggerCategory != null && bloggerCategory.getId().equals(source.getId())) {
            weblog.setBloggerCategory(destination);
            strategy.store(weblog);
        }
    }
}
```

#### **File**: `WeblogTagService.java`

```java
package org.apache.roller.weblogger.business.jpa;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import jakarta.persistence.Query;
import jakarta.persistence.TypedQuery;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.*;

import java.util.*;

/**
 * Focused service for managing weblog tags and tag aggregations.
 */
@Singleton
public class WeblogTagService {
    
    private static final Log LOG = LogFactory.getLog(WeblogTagService.class);
    
    private final JPAPersistenceStrategy strategy;
    
    private static final Comparator<TagStat> TAG_STAT_NAME_COMPARATOR = 
        new TagStatComparator();
    
    private static final Comparator<TagStat> TAG_STAT_COUNT_REVERSE_COMPARATOR =
        Collections.reverseOrder(TagStatCountComparator.getInstance());
    
    @Inject
    public WeblogTagService(JPAPersistenceStrategy strategy) {
        LOG.debug("Initializing WeblogTagService");
        this.strategy = strategy;
    }
    
    /**
     * Handle tag aggregate updates when an entry is saved.
     */
    public void handleTagAggregatesForEntry(WeblogEntry entry) throws WebloggerException {
        
        if (entry.isPublished()) {
            // Tag aggregates updated only when entry published
            if (entry.getRefreshAggregates()) {
                // Entry wasn't published before, increment all tags
                for (WeblogEntryTag tag : entry.getTags()) {
                    updateTagCount(tag.getName(), entry.getWebsite(), 1);
                }
            } else {
                // Only increment new tags
                for (WeblogEntryTag tag : entry.getAddedTags()) {
                    updateTagCount(tag.getName(), entry.getWebsite(), 1);
                }
            }
        } else {
            if (entry.getRefreshAggregates()) {
                // Entry no longer published, decrement aggregate count
                for (WeblogEntryTag tag : entry.getTags()) {
                    updateTagCount(tag.getName(), entry.getWebsite(), -1);
                }
            }
        }
        
        // Remove tags that were deleted
        for (WeblogEntryTag tag : entry.getRemovedTags()) {
            removeWeblogEntryTag(tag);
        }
    }
    
    /**
     * Remove all tags for an entry.
     */
    public void removeTagsForEntry(WeblogEntry entry) throws WebloggerException {
        if (entry.getTags() != null) {
            for (WeblogEntryTag tag : entry.getTags()) {
                removeWeblogEntryTag(tag);
            }
        }
    }
    
    /**
     * Get tag statistics for a weblog.
     */
    public List<TagStat> getTags(Weblog website, String sortBy, 
            String startsWith, int offset, int limit) throws WebloggerException {
        
        boolean sortByName = sortBy == null || !sortBy.equals("count");
        
        List<Object> params = new ArrayList<>();
        int size = 0;
        StringBuilder queryString = new StringBuilder();
        queryString.append("SELECT w.name, SUM(w.total) FROM WeblogEntryTagAggregate w WHERE ");
        
        if (website != null) {
            params.add(size++, website.getId());
            queryString.append(" w.weblog.id = ?").append(size);
        } else {
            queryString.append(" w.weblog IS NULL");
        }
        
        if (startsWith != null && !startsWith.isEmpty()) {
            params.add(size++, startsWith + '%');
            queryString.append(" AND w.name LIKE ?").append(size);
        }
        
        String orderBy = sortBy != null && sortBy.equals("count") ? 
            "w.total DESC" : "w.name";
        queryString.append(" GROUP BY w.name, w.total ORDER BY ").append(orderBy);
        
        Query query = strategy.getDynamicQuery(queryString.toString());
        for (int i = 0; i < params.size(); i++) {
            query.setParameter(i + 1, params.get(i));
        }
        
        if (offset > 0) {
            query.setFirstResult(offset);
        }
        if (limit > 0) {
            query.setMaxResults(limit);
        }
        
        List<?> queryResults = query.getResultList();
        List<TagStat> results = convertToTagStats(queryResults);
        
        // Sort results
        if (sortByName) {
            results.sort(TAG_STAT_NAME_COMPARATOR);
        } else {
            results.sort(TAG_STAT_COUNT_REVERSE_COMPARATOR);
        }
        
        return results;
    }
    
    /**
     * Check if a combination of tags exists.
     */
    public boolean tagComboExists(List<String> tags, Weblog weblog) 
            throws WebloggerException {
        
        if (tags == null || tags.isEmpty()) {
            return false;
        }
        
        StringBuilder queryString = new StringBuilder();
        queryString.append("SELECT DISTINCT w.name ");
        queryString.append("FROM WeblogEntryTagAggregate w WHERE w.name IN (");
        
        List<Object> params = new ArrayList<>(tags.size() + 1);
        for (int i = 0; i < tags.size(); i++) {
            if (i > 0) {
                queryString.append(", ");
            }
            queryString.append('?').append(i + 1);
            params.add(tags.get(i));
        }
        queryString.append(')');
        
        if (weblog != null) {
            queryString.append(" AND w.weblog = ?").append(tags.size() + 1);
            params.add(weblog);
        } else {
            queryString.append(" AND w.weblog IS NULL");
        }
        
        TypedQuery<String> query = strategy.getDynamicQuery(
            queryString.toString(), String.class);
        for (int i = 0; i < params.size(); i++) {
            query.setParameter(i + 1, params.get(i));
        }
        
        List<String> results = query.getResultList();
        return results != null && results.size() == tags.size();
    }
    
    // ---- Private Helper Methods ----
    
    private void updateTagCount(String tagName, Weblog weblog, int incrementAmount) 
            throws WebloggerException {
        
        TypedQuery<WeblogEntryTagAggregate> query = strategy.getNamedQueryCommitFirst(
            "WeblogEntryTagAggregate.getByName&Weblog", WeblogEntryTagAggregate.class);
        query.setParameter(1, tagName);
        query.setParameter(2, weblog);
        
        WeblogEntryTagAggregate aggregate;
        try {
            aggregate = query.getSingleResult();
        } catch (jakarta.persistence.NoResultException e) {
            aggregate = new WeblogEntryTagAggregate(null, weblog, tagName, 0);
        }
        
        aggregate.setTotal(aggregate.getTotal() + incrementAmount);
        aggregate.setLastUsed(new Date());
        strategy.store(aggregate);
    }
    
    private void removeWeblogEntryTag(WeblogEntryTag tag) throws WebloggerException {
        if (tag.getWeblogEntry() != null) {
            WeblogEntry entry = tag.getWeblogEntry();
            if (entry.isPublished()) {
                updateTagCount(tag.getName(), entry.getWebsite(), -1);
            }
            entry.getTags().remove(tag);
        }
        strategy.remove(tag);
    }
    
    private List<TagStat> convertToTagStats(List<?> queryResults) {
        List<TagStat> results = new ArrayList<>();
        if (queryResults != null) {
            for (Object obj : queryResults) {
                Object[] row = (Object[]) obj;
                TagStat stat = new TagStat();
                stat.setName((String) row[0]);
                stat.setCount(((Long) row[1]).intValue());
                results.add(stat);
            }
        }
        return results;
    }
}
```

#### **File**: `WeblogCommentService.java`

```java
package org.apache.roller.weblogger.business.jpa;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import jakarta.persistence.TypedQuery;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.CommentSearchCriteria;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.pojos.WeblogEntryComment;

import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

/**
 * Focused service for managing weblog comments.
 */
@Singleton
public class WeblogCommentService {
    
    private static final Log LOG = LogFactory.getLog(WeblogCommentService.class);
    
    private final JPAPersistenceStrategy strategy;
    private final WeblogService weblogService;
    
    @Inject
    public WeblogCommentService(
            JPAPersistenceStrategy strategy, 
            WeblogService weblogService) {
        
        LOG.debug("Initializing WeblogCommentService");
        this.strategy = strategy;
        this.weblogService = weblogService;
    }
    
    /**
     * Save a comment.
     */
    public void saveComment(WeblogEntryComment comment) throws WebloggerException {
        strategy.store(comment);
        weblogService.touchWeblog(comment.getWeblogEntry().getWebsite());
    }
    
    /**
     * Remove a comment.
     */
    public void removeComment(WeblogEntryComment comment) throws WebloggerException {
        strategy.remove(comment);
        weblogService.touchWeblog(comment.getWeblogEntry().getWebsite());
    }
    
    /**
     * Remove all comments for a specific entry.
     */
    public void removeCommentsForEntry(WeblogEntry entry) throws WebloggerException {
        CommentSearchCriteria criteria = new CommentSearchCriteria();
        criteria.setEntry(entry);
        
        List<WeblogEntryComment> comments = getComments(criteria);
        for (WeblogEntryComment comment : comments) {
            strategy.remove(comment);
        }
    }
    
    /**
     * Get comments matching search criteria.
     */
    public List<WeblogEntryComment> getComments(CommentSearchCriteria criteria) 
            throws WebloggerException {
        
        List<Object> params = new ArrayList<>();
        int size = 0;
        StringBuilder queryString = new StringBuilder();
        queryString.append("SELECT c FROM WeblogEntryComment c ");
        
        StringBuilder whereClause = new StringBuilder();
        
        if (criteria.getEntry() != null) {
            params.add(size++, criteria.getEntry());
            whereClause.append("c.weblogEntry = ?").append(size);
        } else if (criteria.getWeblog() != null) {
            params.add(size++, criteria.getWeblog());
            whereClause.append("c.weblogEntry.website = ?").append(size);
        }
        
        if (criteria.getSearchText() != null) {
            params.add(size++, "%" + criteria.getSearchText().toUpperCase() + "%");
            appendConjunction(whereClause, "upper(c.content) LIKE ?").append(size);
        }
        
        if (criteria.getStartDate() != null) {
            params.add(size++, new Timestamp(criteria.getStartDate().getTime()));
            appendConjunction(whereClause, "c.postTime >= ?").append(size);
        }
        
        if (criteria.getEndDate() != null) {
            params.add(size++, new Timestamp(criteria.getEndDate().getTime()));
            appendConjunction(whereClause, "c.postTime <= ?").append(size);
        }
        
        if (criteria.getStatus() != null) {
            params.add(size++, criteria.getStatus());
            appendConjunction(whereClause, "c.status = ?").append(size);
        }
        
        if (whereClause.length() > 0) {
            queryString.append(" WHERE ").append(whereClause);
        }
        
        queryString.append(criteria.isReverseChrono() ? 
            " ORDER BY c.postTime DESC" : " ORDER BY c.postTime ASC");
        
        TypedQuery<WeblogEntryComment> query = strategy.getDynamicQuery(
            queryString.toString(), WeblogEntryComment.class);
        
        if (criteria.getOffset() > 0) {
            query.setFirstResult(criteria.getOffset());
        }
        if (criteria.getMaxResults() > 0) {
            query.setMaxResults(criteria.getMaxResults());
        }
        
        for (int i = 0; i < params.size(); i++) {
            query.setParameter(i + 1, params.get(i));
        }
        
        return query.getResultList();
    }
    
    /**
     * Get comment by ID.
     */
    public WeblogEntryComment getComment(String id) throws WebloggerException {
        return strategy.load(WeblogEntryComment.class, id);
    }
    
    // ---- Private Helper Methods ----
    
    private StringBuilder appendConjunction(StringBuilder sb, String condition) {
        if (sb.length() > 0) {
            sb.append(" AND ");
        }
        return sb.append(condition);
    }
}
```

#### **New Helper Classes**

**File**: `EntryAnchorGenerator.java`

```java
package org.apache.roller.weblogger.business.jpa;

import com.google.inject.Singleton;
import org.apache.commons.lang3.StringUtils;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.util.Utilities;

import java.text.SimpleDateFormat;

/**
 * Generates unique anchors for weblog entries.
 */
@Singleton
public class EntryAnchorGenerator {
    
    private static final int MAX_ANCHOR_LENGTH = 255;
    
    /**
     * Generate an anchor from entry title and publish time.
     */
    public String generateAnchor(WeblogEntry entry) {
        
        String title = entry.getTitle();
        if (title == null || title.isBlank()) {
            title = "entry";
        }
        
        // Remove non-alphanumeric characters and replace with hyphens
        String anchor = Utilities.replaceNonAlphanumeric(title.toLowerCase(), '-');
        
        // Add timestamp to ensure uniqueness
        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyyMMdd");
        String dateStamp = dateFormat.format(entry.getPubTime());
        anchor = dateStamp + "-" + anchor;
        
        // Truncate if too long
        if (anchor.length() > MAX_ANCHOR_LENGTH) {
            anchor = anchor.substring(0, MAX_ANCHOR_LENGTH);
        }
        
        // Remove trailing hyphens
        anchor = StringUtils.stripEnd(anchor, "-");
        
        return anchor;
    }
}
```

**File**: `WeblogService.java`

```java
package org.apache.roller.weblogger.business.jpa;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.Weblog;

import java.util.Date;

/**
 * Service for managing Weblog entities.
 */
@Singleton
public class WeblogService {
    
    private final JPAPersistenceStrategy strategy;
    
    @Inject
    public WeblogService(JPAPersistenceStrategy strategy) {
        this.strategy = strategy;
    }
    
    /**
     * Update weblog's last modified timestamp.
     */
    public void touchWeblog(Weblog weblog) throws WebloggerException {
        weblog.setLastModified(new Date());
        strategy.store(weblog);
    }
    
    /**
     * Save a weblog.
     */
    public void saveWeblog(Weblog weblog) throws WebloggerException {
        touchWeblog(weblog);
    }
    
    /**
     * Get weblog by ID.
     */
    public Weblog getWeblog(String id) throws WebloggerException {
        return strategy.load(Weblog.class, id);
    }
}
```

---

## Refactoring #2: Replace Utility Class with Services

### **Before**: Static Utility Dumping Ground

```java
// BEFORE: Massive static utility class
public class Utilities {
    
    // 15+ compiled regex patterns
    private static final Pattern mLinkPattern = Pattern.compile("<a href=.*?>", ...);
    private static final Pattern OPENING_B_TAG_PATTERN = Pattern.compile("&lt;b&gt;", ...);
    // ... 13 more patterns ...
    
    // Static HTML methods
    public static String escapeHTML(String s) { /* ... */ }
    public static String removeHTML(String str) { /* ... */ }
    public static String addNofollow(String html) { /* ... */ }
    
    // Static string methods
    public static String replaceNonAlphanumeric(String str) { /* ... */ }
    
    // Static file methods
    public static void copyFile(File from, File to) throws IOException { /* ... */ }
    
    // Static security methods
    public static String encodePassword(String password, String algorithm) { /* ... */ }
    
    // ... 40+ more static methods
}
```

### **After**: Focused, Injectable Services

#### **File**: `HtmlProcessor.java`

```java
package org.apache.roller.weblogger.util;

import com.google.inject.Singleton;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.text.StringEscapeUtils;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Service for HTML processing operations.
 * Thread-safe singleton with lazy pattern compilation.
 */
@Singleton
public class HtmlProcessor {
    
    // Lazy-initialized patterns (only created when needed)
    private volatile Pattern linkPattern;
    private volatile Pattern openingBTagPattern;
    private volatile Pattern closingBTagPattern;
    
    /**
     * Escape HTML special characters.
     */
    public String escapeHtml(String input) {
        return escapeHtml(input, true);
    }
    
    /**
     * Escape HTML special characters.
     * 
     * @param input The string to escape
     * @param escapeAmpersand Whether to escape ampersands
     * @return Escaped HTML string
     */
    public String escapeHtml(String input, boolean escapeAmpersand) {
        if (input == null) {
            return "";
        }
        
        String result = input;
        if (escapeAmpersand) {
            result = StringUtils.replace(result, "&", "&amp;");
        }
        result = StringUtils.replace(result, "&nbsp;", " ");
        result = StringUtils.replace(result, "\"", "&quot;");
        result = StringUtils.replace(result, "<", "&lt;");
        result = StringUtils.replace(result, ">", "&gt;");
        
        return result;
    }
    
    /**
     * Unescape HTML entities.
     */
    public String unescapeHtml(String input) {
        if (input == null) {
            return "";
        }
        return StringEscapeUtils.unescapeHtml4(input);
    }
    
    /**
     * Remove all HTML tags from a string.
     */
    public String removeHtml(String input) {
        return removeHtml(input, true);
    }
    
    /**
     * Remove all HTML tags from a string.
     * 
     * @param input The string to process
     * @param addSpace Whether to replace tags with spaces
     * @return String with HTML removed
     */
    public String removeHtml(String input, boolean addSpace) {
        if (input == null || input.isEmpty()) {
            return "";
        }
        
        StringBuilder result = new StringBuilder(input.length());
        int start = 0;
        int beginTag = input.indexOf('<');
        int endTag;
        
        if (beginTag == -1) {
            return input;
        }
        
        while (beginTag >= start) {
            if (beginTag > 0) {
                result.append(input.substring(start, beginTag));
                if (addSpace) {
                    result.append(" ");
                }
            }
            
            endTag = input.indexOf('>', beginTag);
            
            if (endTag > -1) {
                start = endTag + 1;
                beginTag = input.indexOf('<', start);
            } else {
                result.append(input.substring(beginTag));
                break;
            }
        }
        
        if (endTag > -1 && endTag + 1 < input.length()) {
            result.append(input.substring(endTag + 1));
        }
        
        return result.toString().trim();
    }
    
    /**
     * Remove HTML and then escape special characters.
     */
    public String removeAndEscapeHtml(String input) {
        if (input == null) {
            return "";
        }
        return escapeHtml(removeHtml(input));
    }
    
    /**
     * Add rel="nofollow" to all links in HTML.
     */
    public String addNofollow(String html) {
        if (html == null || html.isEmpty()) {
            return html;
        }
        
        Pattern pattern = getLinkPattern();
        Matcher matcher = pattern.matcher(html);
        StringBuilder buffer = new StringBuilder();
        
        while (matcher.find()) {
            int start = matcher.start();
            int end = matcher.end();
            String link = html.substring(start, end);
            
            buffer.append(html, 0, start);
            
            if (!link.contains("rel=\"nofollow\"")) {
                buffer.append(link, 0, link.length() - 1).append(" rel=\"nofollow\">");
            } else {
                buffer.append(link);
            }
            
            html = html.substring(end);
            matcher = pattern.matcher(html);
        }
        
        buffer.append(html);
        return buffer.toString();
    }
    
    /**
     * Convert newlines to HTML line breaks.
     */
    public String autoformat(String input) {
        if (input == null) {
            return "";
        }
        return StringUtils.replace(input, "\n", "<br />");
    }
    
    // ---- Private Helper Methods with Lazy Pattern Initialization ----
    
    private Pattern getLinkPattern() {
        if (linkPattern == null) {
            synchronized (this) {
                if (linkPattern == null) {
                    linkPattern = Pattern.compile("<a href=.*?>", Pattern.CASE_INSENSITIVE);
                }
            }
        }
        return linkPattern;
    }
}
```

#### **File**: `StringTransformer.java`

```java
package org.apache.roller.weblogger.util;

import com.google.inject.Singleton;

/**
 * Service for string transformation operations.
 */
@Singleton
public class StringTransformer {
    
    /**
     * Replace non-alphanumeric characters with underscores.
     */
    public String replaceNonAlphanumeric(String input) {
        return replaceNonAlphanumeric(input, '_');
    }
    
    /**
     * Replace non-alphanumeric characters with a specified character.
     */
    public String replaceNonAlphanumeric(String input, char replacement) {
        if (input == null || input.isEmpty()) {
            return "";
        }
        
        StringBuilder result = new StringBuilder(input.length());
        char[] chars = input.toCharArray();
        
        for (char c : chars) {
            if (Character.isLetterOrDigit(c)) {
                result.append(c);
            } else {
                result.append(replacement);
            }
        }
        
        return result.toString();
    }
    
    /**
     * Remove all non-alphanumeric characters.
     */
    public String removeNonAlphanumeric(String input) {
        if (input == null || input.isEmpty()) {
            return "";
        }
        
        StringBuilder result = new StringBuilder(input.length());
        char[] chars = input.toCharArray();
        
        for (char c : chars) {
            // Allow periods in addition to letters and digits
            if (Character.isLetterOrDigit(c) || c == '.') {
                result.append(c);
            }
        }
        
        return result.toString();
    }
    
    /**
     * Strip jsessionid from URL.
     */
    public String stripJsessionId(String url) {
        if (url == null) {
            return null;
        }
        
        int startPos = url.indexOf(";jsessionid=");
        if (startPos == -1) {
            return url;
        }
        
        int endPos = url.indexOf('?', startPos);
        if (endPos == -1) {
            return url.substring(0, startPos);
        } else {
            return url.substring(0, startPos) + url.substring(endPos);
        }
    }
}
```

#### **File**: `PasswordEncoder.java`

```java
package org.apache.roller.weblogger.util;

import com.google.inject.Singleton;
import org.apache.commons.codec.binary.Base64;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

/**
 * Service for password encoding operations.
 * Supports multiple hashing algorithms.
 */
@Singleton
public class PasswordEncoder {
    
    private static final Log LOG = LogFactory.getLog(PasswordEncoder.class);
    
    /**
     * Encode a password using the specified algorithm.
     * 
     * @param password The password to encode
     * @param algorithm The MessageDigest algorithm (e.g., "SHA-256", "SHA-512", "MD5")
     * @return Base64-encoded hash of the password
     * @throws PasswordEncodingException if algorithm is not available
     */
    public String encodePassword(String password, String algorithm) 
            throws PasswordEncodingException {
        
        if (password == null || password.isEmpty()) {
            throw new IllegalArgumentException("Password cannot be null or empty");
        }
        
        if (algorithm == null || algorithm.isEmpty()) {
            throw new IllegalArgumentException("Algorithm cannot be null or empty");
        }
        
        try {
            MessageDigest md = MessageDigest.getInstance(algorithm);
            byte[] passwordBytes = password.getBytes();
            byte[] hash = md.digest(passwordBytes);
            
            return Base64.encodeBase64String(hash);
            
        } catch (NoSuchAlgorithmException e) {
            LOG.error("Password encoding algorithm not available: " + algorithm, e);
            throw new PasswordEncodingException(
                "Algorithm not available: " + algorithm, e);
        }
    }
    
    /**
     * Encode a password using SHA-256 (recommended default).
     */
    public String encodePassword(String password) throws PasswordEncodingException {
        return encodePassword(password, "SHA-256");
    }
    
    /**
     * Verify a password against an encoded hash.
     * 
     * @param plainPassword The plain text password
     * @param encodedPassword The previously encoded password
     * @param algorithm The algorithm used for encoding
     * @return true if passwords match
     */
    public boolean verifyPassword(String plainPassword, String encodedPassword, 
            String algorithm) throws PasswordEncodingException {
        
        String newHash = encodePassword(plainPassword, algorithm);
        return newHash.equals(encodedPassword);
    }
    
    /**
     * Exception thrown when password encoding fails.
     */
    public static class PasswordEncodingException extends Exception {
        public PasswordEncodingException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
```

#### **File**: `FileOperations.java`

```java
package org.apache.roller.weblogger.util;

import com.google.inject.Singleton;
import org.apache.roller.util.RollerConstants;

import java.io.*;

/**
 * Service for file I/O operations.
 */
@Singleton
public class FileOperations {
    
    /**
     * Copy a file from source to destination.
     * 
     * @param source Source file
     * @param destination Destination file
     * @throws IOException if I/O error occurs
     */
    public void copyFile(File source, File destination) throws IOException {
        
        if (source == null || destination == null) {
            throw new IllegalArgumentException("Source and destination cannot be null");
        }
        
        if (!source.exists()) {
            throw new FileNotFoundException("Source file does not exist: " + source.getPath());
        }
        
        try (InputStream in = new FileInputStream(source);
             OutputStream out = new FileOutputStream(destination)) {
            
            copyInputToOutput(in, out, source.length());
        }
    }
    
    /**
     * Read an input stream into a string.
     * 
     * @param inputStream The input stream to read
     * @return String content
     * @throws IOException if I/O error occurs
     */
    public String streamToString(InputStream inputStream) throws IOException {
        
        if (inputStream == null) {
            throw new IllegalArgumentException("InputStream cannot be null");
        }
        
        StringBuilder sb = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {
            String line;
            String lineSeparator = System.getProperty("line.separator");
            
            while ((line = reader.readLine()) != null) {
                sb.append(line).append(lineSeparator);
            }
        }
        
        return sb.toString();
    }
    
    /**
     * Copy data from input stream to output stream.
     * 
     * @param input Input stream
     * @param output Output stream
     * @param byteCount Number of bytes to copy
     * @throws IOException if I/O error occurs
     */
    public void copyInputToOutput(InputStream input, OutputStream output, long byteCount) 
            throws IOException {
        
        if (input == null || output == null) {
            throw new IllegalArgumentException("Input and output streams cannot be null");
        }
        
        try (BufferedInputStream in = new BufferedInputStream(input);
             BufferedOutputStream out = new BufferedOutputStream(output)) {
            
            byte[] buffer = new byte[RollerConstants.EIGHT_KB_IN_BYTES];
            long remaining = byteCount;
            
            while (remaining > 0) {
                int bytesToRead = (int) Math.min(RollerConstants.EIGHT_KB_IN_BYTES, remaining);
                int bytesRead = in.read(buffer, 0, bytesToRead);
                
                if (bytesRead < 0) {
                    break;
                }
                
                out.write(buffer, 0, bytesRead);
                remaining -= bytesRead;
            }
        }
    }
    
    /**
     * Copy all data from input stream to output stream.
     * 
     * @param input Input stream
     * @param output Output stream
     * @throws IOException if I/O error occurs
     */
    public void copyInputToOutput(InputStream input, OutputStream output) 
            throws IOException {
        
        if (input == null || output == null) {
            throw new IllegalArgumentException("Input and output streams cannot be null");
        }
        
        try (BufferedInputStream in = new BufferedInputStream(input);
             BufferedOutputStream out = new BufferedOutputStream(output)) {
            
            byte[] buffer = new byte[RollerConstants.EIGHT_KB_IN_BYTES];
            int bytesRead;
            
            while ((bytesRead = in.read(buffer)) != -1) {
                out.write(buffer, 0, bytesRead);
            }
        }
    }
}
```

#### **Usage Example: Dependency Injection**

```java
package org.apache.roller.weblogger.ui.struts2.editor;

import com.google.inject.Inject;
import org.apache.roller.weblogger.util.HtmlProcessor;
import org.apache.roller.weblogger.util.StringTransformer;

/**
 * Example action class using injected services instead of static utilities.
 */
public class EntryEditAction {
    
    private final HtmlProcessor htmlProcessor;
    private final StringTransformer stringTransformer;
    
    @Inject
    public EntryEditAction(
            HtmlProcessor htmlProcessor,
            StringTransformer stringTransformer) {
        
        this.htmlProcessor = htmlProcessor;
        this.stringTransformer = stringTransformer;
    }
    
    public String sanitizeInput(String userInput) {
        // BEFORE: Utilities.removeAndEscapeHTML(userInput)
        // AFTER: Use injected service
        return htmlProcessor.removeAndEscapeHtml(userInput);
    }
    
    public String createSlug(String title) {
        // BEFORE: Utilities.replaceNonAlphanumeric(title, '-')
        // AFTER: Use injected service
        return stringTransformer.replaceNonAlphanumeric(title, '-');
    }
}
```

---

## Refactoring #3: Reduce Coupling via Tell, Don't Ask

### **Before**: Feature Envy and Chain Calls

```java
// BEFORE: Reaching deep into object graphs
@Override
public void saveWeblogEntry(WeblogEntry entry) throws WebloggerException {
    
    // SMELL: Feature Envy - method knows too much about entry's internals
    if (entry.getCategory() == null) {
        WeblogCategory cat = entry.getWebsite().getBloggerCategory();
        if (cat == null) {
            cat = entry.getWebsite().getWeblogCategories().iterator().next();
        }
        entry.setCategory(cat);
    }

    // SMELL: Feature Envy
    if (entry.getLocale() == null) {
        entry.setLocale(entry.getWebsite().getLocale());
    }
    
    // ... more logic ...
    
    // SMELL: Calling through multiple managers
    if(entry.isPublished()) {
        roller.getWeblogManager().saveWeblog(entry.getWebsite());
    }
    
    if(entry.isPublished()) {
        roller.getAutopingManager().queueApplicableAutoPings(entry);
    }
}

@Override
public void removeWeblogEntry(WeblogEntry entry) throws WebloggerException {
    // SMELL: Building cache key from entry's internals
    this.entryAnchorToIdMap.remove(
        entry.getWebsite().getHandle() + ":" + entry.getAnchor()
    );
}
```

### **After**: Tell, Don't Ask + Encapsulation

#### **Moved Behavior to WeblogEntry.java**

```java
package org.apache.roller.weblogger.pojos;

import java.util.Iterator;

/**
 * Represents a Weblog Entry with improved encapsulation.
 */
public class WeblogEntry implements Serializable {
    
    // ... existing fields ...
    
    /**
     * Ensure entry has a default category set.
     * Uses weblog's blogger category or first available category.
     */
    public void ensureDefaultCategoryIsSet() {
        if (this.category != null) {
            return;
        }
        
        // Try blogger category first
        WeblogCategory defaultCat = this.website.getBloggerCategory();
        
        // Fall back to first available category
        if (defaultCat == null && !this.website.getWeblogCategories().isEmpty()) {
            Iterator<WeblogCategory> it = this.website.getWeblogCategories().iterator();
            if (it.hasNext()) {
                defaultCat = it.next();
            }
        }
        
        this.category = defaultCat;
    }
    
    /**
     * Ensure entry has a default locale set.
     * Uses weblog's locale if entry locale is null.
     */
    public void ensureDefaultLocaleIsSet() {
        if (this.locale == null) {
            this.locale = this.website.getLocale();
        }
    }
    
    /**
     * Check if anchor is blank.
     */
    public boolean isAnchorBlank() {
        return this.anchor == null || this.anchor.isBlank();
    }
    
    /**
     * Build cache key for this entry.
     * Format: "weblogHandle:entryAnchor"
     */
    public String buildCacheKey() {
        return this.website.getHandle() + ":" + this.anchor;
    }
    
    /**
     * Check if entry is currently published.
     */
    public boolean isPublished() {
        return PubStatus.PUBLISHED.equals(this.status);
    }
    
    // ... rest of class ...
}
```

#### **Simplified Service Using Tell, Don't Ask**

```java
package org.apache.roller.weblogger.business.jpa;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.WeblogEntry;

/**
 * Refactored WeblogEntryService with reduced coupling.
 */
@Singleton
public class WeblogEntryService {
    
    private final JPAPersistenceStrategy strategy;
    private final WeblogTagService tagService;
    private final WeblogCommentService commentService;
    private final WeblogPublishingFacade publishingFacade;  // NEW: Facade pattern
    private final EntryAnchorGenerator anchorGenerator;
    private final Map<String, String> entryAnchorToIdMap;
    
    @Inject
    public WeblogEntryService(
            JPAPersistenceStrategy strategy,
            WeblogTagService tagService,
            WeblogCommentService commentService,
            WeblogPublishingFacade publishingFacade,  // NEW
            EntryAnchorGenerator anchorGenerator) {
        
        this.strategy = strategy;
        this.tagService = tagService;
        this.commentService = commentService;
        this.publishingFacade = publishingFacade;
        this.anchorGenerator = anchorGenerator;
        this.entryAnchorToIdMap = Collections.synchronizedMap(new HashMap<>());
    }
    
    /**
     * Save a weblog entry.
     * Much simpler now with Tell, Don't Ask.
     */
    public void saveWeblogEntry(WeblogEntry entry) throws WebloggerException {
        
        // AFTER: Tell the entry to ensure its defaults are set
        entry.ensureDefaultCategoryIsSet();
        entry.ensureDefaultLocaleIsSet();
        
        if (entry.isAnchorBlank()) {
            entry.setAnchor(anchorGenerator.generateAnchor(entry));
        }
        
        // Delegate to specialized services
        tagService.handleTagAggregatesForEntry(entry);
        handleSchedulingLogic(entry);
        
        // Persist
        entry.setUpdateTime(new Timestamp(new Date().getTime()));
        strategy.store(entry);
        
        // AFTER: Use facade instead of calling multiple managers
        if (entry.isPublished()) {
            publishingFacade.handleEntryPublication(entry);
        }
    }
    
    /**
     * Remove a weblog entry.
     */
    public void removeWeblogEntry(WeblogEntry entry) throws WebloggerException {
        
        commentService.removeCommentsForEntry(entry);
        tagService.removeTagsForEntry(entry);
        removeEntryAttributes(entry);
        
        strategy.remove(entry);
        
        if (entry.isPublished()) {
            publishingFacade.handleEntryRemoval(entry);
        }
        
        // AFTER: Tell the entry to build its own cache key
        String cacheKey = entry.buildCacheKey();
        entryAnchorToIdMap.remove(cacheKey);
    }
    
    // ... rest of methods ...
}
```

#### **New Facade: WeblogPublishingFacade.java**

```java
package org.apache.roller.weblogger.business.jpa;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.pings.AutoPingManager;
import org.apache.roller.weblogger.pojos.WeblogEntry;

/**
 * Facade to simplify interactions with publishing-related managers.
 * Reduces coupling by providing a single point of interaction.
 */
@Singleton
public class WeblogPublishingFacade {
    
    private final WeblogService weblogService;
    private final AutoPingManager autoPingManager;
    
    @Inject
    public WeblogPublishingFacade(
            WeblogService weblogService,
            AutoPingManager autoPingManager) {
        
        this.weblogService = weblogService;
        this.autoPingManager = autoPingManager;
    }
    
    /**
     * Handle all publication tasks when an entry is published.
     */
    public void handleEntryPublication(WeblogEntry entry) throws WebloggerException {
        // Update weblog last modified time
        weblogService.touchWeblog(entry.getWebsite());
        
        // Queue auto-pings
        autoPingManager.queueApplicableAutoPings(entry);
    }
    
    /**
     * Handle all tasks when an entry is removed.
     */
    public void handleEntryRemoval(WeblogEntry entry) throws WebloggerException {
        // Just update weblog last modified time
        weblogService.touchWeblog(entry.getWebsite());
    }
}
```

