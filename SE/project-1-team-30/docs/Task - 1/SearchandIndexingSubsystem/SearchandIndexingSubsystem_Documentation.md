# Apache Roller - Search and Indexing Subsystem Report

## Overview

This report describes the Search and Indexing Subsystem of Apache Roller. This subsystem allows users to search through blog posts and comments using full-text search powered by Apache Lucene.

**Total Classes in Subsystem**: 15 classes
- 1 Interface
- 1 Main Implementation
- 3 Abstract Base Classes
- 6 Concrete Operation Classes
- 2 Result Container Classes
- 2 Utility Classes

---

## Class-by-Class Documentation

---

## Class 1: IndexManager

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/IndexManager.java
Package: org.apache.roller.weblogger.business.search
```

### Type
Interface

### Role
This is the main interface that defines all search and indexing operations in Apache Roller. It acts as a contract that any search implementation must follow. Currently, the only implementation is `LuceneIndexManager`.

### Methods

| Method Name | Parameters | Return Type | What It Does |
|-------------|------------|-------------|--------------|
| `initialize()` | None | `void` | Starts up the search system when application starts |
| `shutdown()` | None | `void` | Closes the search system when application stops |
| `release()` | None | `void` | Releases resources being used |
| `isInconsistentAtStartup()` | None | `boolean` | Checks if index was corrupted when app started |
| `addEntryIndexOperation()` | `WeblogEntry entry` | `void` | Adds a new blog post to the search index |
| `addEntryReIndexOperation()` | `WeblogEntry entry` | `void` | Updates an existing blog post in the search index |
| `removeEntryIndexOperation()` | `WeblogEntry entry` | `void` | Removes a blog post from the search index |
| `rebuildWeblogIndex()` | `Weblog weblog` | `void` | Rebuilds the search index for one blog |
| `rebuildWeblogIndex()` | None | `void` | Rebuilds the search index for all blogs |
| `removeWeblogIndex()` | `Weblog weblog` | `void` | Removes all posts of a blog from search index |
| `search()` | `String term`<br>`String weblogHandle`<br>`String category`<br>`String locale`<br>`int pageNum`<br>`int entryCount`<br>`URLStrategy urlStrategy` | `SearchResultList` | Searches for blog posts matching the search term |

### Attributes
None (interfaces don't have attributes)

### Interactions with System
- **Implemented by**: `LuceneIndexManager` class
- **Used by**: UI layer and business layer to perform search operations
- **Returns**: `SearchResultList` containing search results

### Important Notes
- This interface is the entry point for all search functionality
- All methods can throw `WebloggerException` if something goes wrong
- Methods run in background except `search()` which runs immediately
- `initialize()` can throw `InitializationException` at startup

---

## Class 2: LuceneIndexManager

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/LuceneIndexManager.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Concrete Class (marked as `@Singleton`)

### Role
This is the main implementation of the IndexManager interface. It uses Apache Lucene library to create and manage the search index. This class coordinates all indexing and searching activities.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `reader` | `IndexReader` | The reader used to search the index |
| `roller` | `Weblogger` | Reference to main application instance |
| `logger` | `Log` | For logging messages |
| `searchEnabled` | `boolean` | Whether search feature is turned on |
| `indexDir` | `String` | File path where index is stored |
| `indexConsistencyMarker` | `File` | A marker file to detect if index is corrupted |
| `inconsistentAtStartup` | `boolean` | True if index was corrupted at startup |
| `rwl` | `ReadWriteLock` | Lock to control concurrent access to index |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `initialize()` | `void` | Sets up the index, checks if it's valid, creates new one if needed |
| `shutdown()` | `void` | Closes the index properly |
| `release()` | `void` | Releases the index reader |
| `isInconsistentAtStartup()` | `boolean` | Returns true if index was corrupted |
| `addEntryIndexOperation()` | `void` | Creates an AddEntryOperation and runs it in background |
| `addEntryReIndexOperation()` | `void` | Creates a ReIndexEntryOperation and runs it in background |
| `removeEntryIndexOperation()` | `void` | Creates a RemoveEntryOperation and runs it immediately |
| `rebuildWeblogIndex()` | `void` | Creates a RebuildWebsiteIndexOperation |
| `removeWeblogIndex()` | `void` | Creates a RemoveWebsiteIndexOperation |
| `search()` | `SearchResultList` | Creates a SearchOperation and executes it |
| `getReadWriteLock()` | `ReadWriteLock` | Returns the lock used for thread safety |
| `getAnalyzer()` | `Analyzer` | Returns the text analyzer used for indexing |
| `resetSharedReader()` | `void` | Invalidates the cached reader |
| `getSharedIndexReader()` | `IndexReader` | Returns a cached reader for searching |
| `getIndexDirectory()` | `Directory` | Returns the directory where index files are stored |

### Interactions with System
- **Implements**: `IndexManager` interface
- **Creates**: All operation classes (AddEntryOperation, RemoveEntryOperation, etc.)
- **Uses**: Apache Lucene classes (IndexReader, IndexWriter, Directory, Analyzer)
- **Called by**: Business layer when blog posts are created/updated/deleted
- **Returns**: `SearchResultList` to UI layer

### Important Notes
- Only one instance exists in the application (Singleton pattern)
- Uses locks to prevent conflicts when multiple users search or update at same time
- Runs heavy operations (add, rebuild) in background so users don't have to wait
- Runs light operations (remove, search) immediately
- Creates a marker file to detect if application crashed during indexing
- If index is corrupted at startup, automatically rebuilds it

---

## Class 3: IndexOperation

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/IndexOperation.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Abstract Class (implements `Runnable`)

### Role
This is the base class for all indexing operations. It provides common functionality that all operations need, like converting blog posts to search documents and managing the index writer.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `manager` | `LuceneIndexManager` | Reference to the index manager |
| `writer` | `IndexWriter` | The writer used to modify the index |
| `logger` | `Log` | For logging messages |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `run()` | `void` | Executes the operation (calls doRun) |
| `doRun()` | `void` | Abstract method - subclasses implement the actual work |
| `getDocument()` | `Document` | Converts a blog post to a searchable document |
| `beginWriting()` | `IndexWriter` | Opens the index for writing |
| `endWriting()` | `void` | Closes the index writer |

### Interactions with System
- **Extended by**: `WriteToIndexOperation` and `ReadFromIndexOperation`
- **Uses**: `LuceneIndexManager` to access the index
- **Creates**: Lucene `Document` objects from `WeblogEntry` objects
- **Uses**: `FieldConstants` for field names

### Important Notes
- This is an abstract class - you cannot create objects of this class directly
- The `getDocument()` method is very important - it decides what information gets indexed
- Indexed information includes: title, content, author, category, publish date, comments
- Comments are only indexed if `search.index.comments` setting is true
- Uses `Runnable` interface so operations can run in background threads

---

## Class 4: WriteToIndexOperation

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/WriteToIndexOperation.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Abstract Class (extends `IndexOperation`)

### Role
Base class for all operations that change the index (add, remove, update). It makes sure only one write operation happens at a time by using locks.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `logger` | `Log` | For logging messages |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `run()` | `void` | Acquires write lock, runs operation, releases lock |

### Interactions with System
- **Extends**: `IndexOperation`
- **Extended by**: AddEntryOperation, RemoveEntryOperation, ReIndexEntryOperation, RebuildWebsiteIndexOperation, RemoveWebsiteIndexOperation
- **Uses**: `ReadWriteLock` to prevent conflicts

### Important Notes
- Uses a "write lock" which means only one write can happen at a time
- When a write is happening, no one can search (they have to wait)
- After writing, it invalidates the cached reader so next search sees new data
- This prevents data corruption when multiple operations try to update index

---

## Class 5: ReadFromIndexOperation

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/ReadFromIndexOperation.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Abstract Class (extends `IndexOperation`)

### Role
Base class for operations that only read from the index (like search). It uses locks to allow multiple searches at the same time, but blocks searches when someone is writing.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `logger` | `Log` | For logging messages |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `run()` | `void` | Acquires read lock, runs operation, releases lock |

### Interactions with System
- **Extends**: `IndexOperation`
- **Extended by**: `SearchOperation`
- **Uses**: `ReadWriteLock` for thread safety

### Important Notes
- Uses a "read lock" which allows multiple people to search at the same time
- Multiple searches can happen together without blocking each other
- Searches are blocked only when someone is writing to the index
- This makes search fast when many users search at the same time

---

## Class 6: AddEntryOperation

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/AddEntryOperation.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Concrete Class (extends `WriteToIndexOperation`)

### Role
Adds a newly published blog post to the search index so users can find it when searching.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `logger` | `Log` | For logging messages |
| `data` | `WeblogEntry` | The blog post to be added |
| `roller` | `Weblogger` | Application instance for database access |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| Constructor | - | Creates the operation with a blog post to add |
| `doRun()` | `void` | Gets fresh blog post data, converts to document, adds to index |

### Interactions with System
- **Extends**: `WriteToIndexOperation`
- **Created by**: `LuceneIndexManager` when new post is published
- **Processes**: `WeblogEntry` (blog post)
- **Updates**: Search index

### Important Notes
- Runs in background so publishing a post is fast
- Re-fetches the blog post from database to ensure fresh data
- If blog post was deleted before this runs, operation is skipped
- Uses inherited `getDocument()` method to convert post to searchable format

---

## Class 7: RemoveEntryOperation

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/RemoveEntryOperation.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Concrete Class (extends `WriteToIndexOperation`)

### Role
Removes a deleted blog post from the search index so it no longer appears in search results.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `logger` | `Log` | For logging messages |
| `data` | `WeblogEntry` | The blog post to be removed |
| `roller` | `Weblogger` | Application instance |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| Constructor | - | Creates the operation with a blog post to remove |
| `doRun()` | `void` | Finds the post in index by ID and deletes it |

### Interactions with System
- **Extends**: `WriteToIndexOperation`
- **Created by**: `LuceneIndexManager` when post is deleted
- **Processes**: `WeblogEntry` (blog post)
- **Uses**: `IndexUtil.getTerm()` to create delete query

### Important Notes
- Runs immediately (not in background) to ensure post disappears from search quickly
- Deletes by post ID to ensure correct post is removed
- If post doesn't exist in index, operation completes without error

---

## Class 8: ReIndexEntryOperation

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/ReIndexEntryOperation.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Concrete Class (extends `WriteToIndexOperation`)

### Role
Updates an existing blog post in the search index after it has been edited. It first removes the old version, then adds the new version.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `logger` | `Log` | For logging messages |
| `data` | `WeblogEntry` | The blog post to be re-indexed |
| `roller` | `Weblogger` | Application instance |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| Constructor | - | Creates the operation with a blog post to update |
| `doRun()` | `void` | Deletes old version, adds new version to index |

### Interactions with System
- **Extends**: `WriteToIndexOperation`
- **Created by**: `LuceneIndexManager` when post is edited
- **Processes**: `WeblogEntry` (blog post)
- **Updates**: Search index

### Important Notes
- Runs in background so editing posts is fast
- Uses delete-then-add approach to ensure index stays consistent
- Triggered when post title, content, or category is changed
- Also triggered when comments are added (if comment indexing is enabled)

---

## Class 9: RebuildWebsiteIndexOperation

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/RebuildWebsiteIndexOperation.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Concrete Class (extends `WriteToIndexOperation`)

### Role
Rebuilds the entire search index for one blog or all blogs. This is used when index gets corrupted or after major upgrades.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `logger` | `Log` | For logging messages |
| `website` | `Weblog` | The blog to rebuild (null means rebuild all blogs) |
| `roller` | `Weblogger` | Application instance |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| Constructor | - | Creates the operation with blog to rebuild |
| `doRun()` | `void` | Deletes old index, fetches all posts, re-adds them |

### Interactions with System
- **Extends**: `WriteToIndexOperation`
- **Created by**: `LuceneIndexManager` at startup if index is corrupted, or by admin request
- **Processes**: `Weblog` and all its `WeblogEntry` objects
- **Updates**: Entire search index

### Important Notes
- Can take a long time for blogs with many posts
- Runs in background so doesn't block the application
- Logs the time taken to complete for monitoring
- If `website` is null, rebuilds index for all blogs in the system
- Only indexes posts with status = PUBLISHED

---

## Class 10: RemoveWebsiteIndexOperation

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/RemoveWebsiteIndexOperation.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Concrete Class (extends `WriteToIndexOperation`)

### Role
Removes all blog posts of a specific blog from the search index. Used when a blog is deleted.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `logger` | `Log` | For logging messages |
| `website` | `Weblog` | The blog whose posts should be removed |
| `roller` | `Weblogger` | Application instance |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| Constructor | - | Creates the operation with blog to remove |
| `doRun()` | `void` | Finds all posts of the blog and deletes them from index |

### Interactions with System
- **Extends**: `WriteToIndexOperation`
- **Created by**: `LuceneIndexManager` when a blog is deleted
- **Processes**: `Weblog`
- **Uses**: `IndexUtil.getTerm()` to create delete query by blog handle

### Important Notes
- Deletes all posts in one operation (efficient)
- Uses blog handle to find all posts belonging to that blog
- Logs completion time for monitoring

---

## Class 11: SearchOperation

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/SearchOperation.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Concrete Class (extends `ReadFromIndexOperation`)

### Role
Executes search queries. Takes user's search terms and finds matching blog posts from the index.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `logger` | `Log` | For logging messages |
| `SEARCH_FIELDS` | `String[]` | Fields to search: content, title, comments |
| `SORTER` | `Sort` | Sort results by publish date (newest first) |
| `searcher` | `IndexSearcher` | Lucene searcher for executing queries |
| `searchresults` | `TopFieldDocs` | Raw search results from Lucene |
| `term` | `String` | The search words entered by user |
| `weblogHandle` | `String` | Optional: search only in this blog |
| `category` | `String` | Optional: search only in this category |
| `locale` | `String` | Optional: search only in this language |
| `parseError` | `String` | Error message if search query is invalid |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| Constructor | - | Creates search operation |
| `setTerm()` | `void` | Sets the search words |
| `setWeblogHandle()` | `void` | Sets blog filter |
| `setCategory()` | `void` | Sets category filter |
| `setLocale()` | `void` | Sets language filter |
| `getSearcher()` | `IndexSearcher` | Returns the searcher |
| `setSearcher()` | `void` | Sets the searcher |
| `getResults()` | `TopFieldDocs` | Returns the raw results |
| `getResultsCount()` | `int` | Returns number of matches found |
| `getParseError()` | `String` | Returns error message if query failed |
| `doRun()` | `void` | Executes the search |

### Interactions with System
- **Extends**: `ReadFromIndexOperation`
- **Created by**: `LuceneIndexManager` when user searches
- **Uses**: `IndexSearcher`, `MultiFieldQueryParser`, `BooleanQuery`
- **Uses**: `FieldConstants` for field names
- **Uses**: `IndexUtil.getTerm()` for creating filter queries
- **Returns**: `TopFieldDocs` which is converted to `SearchResultList`

### Important Notes
- Searches in multiple fields: title, content, and comments
- Uses AND operator by default (all search words must be present)
- Can filter by blog, category, and language
- Returns maximum 500 results
- Results sorted by publish date (newest first)
- If query syntax is wrong, stores error message instead of crashing
- Runs immediately (not background) so user gets instant results

---

## Class 12: FieldConstants

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/FieldConstants.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Final Class (Utility class with constants)

### Role
Defines the names of all fields used in the search index. This ensures everyone uses the same field names and prevents typos.

### Attributes (All are `public static final String`)

| Name | Value | What It Represents |
|------|-------|-------------------|
| `ANCHOR` | "anchor" | Blog post permalink |
| `UPDATED` | "updated" | Last update time of post |
| `ID` | "id" | Unique post identifier |
| `USERNAME` | "username" | Author's username |
| `CATEGORY` | "cat" | Post category name |
| `TITLE` | "title" | Post title |
| `PUBLISHED` | "published" | Publish date and time |
| `CONTENT` | "content" | Post text (searchable, not stored) |
| `CONTENT_STORED` | "content_stored" | Post text (stored in index) |
| `C_CONTENT` | "comment" | Comment text |
| `C_EMAIL` | "email" | Commenter's email |
| `C_NAME` | "name" | Commenter's name |
| `CONSTANT` | "constant" | Field present in all documents |
| `CONSTANT_V` | "v" | Value of constant field |
| `WEBSITE_HANDLE` | "handle" | Blog identifier |
| `LOCALE` | "locale" | Language code |

### Methods
None (this is just a constants class)

### Interactions with System
- **Used by**: All operation classes and SearchOperation
- **Used in**: `IndexOperation.getDocument()` to create documents
- **Used in**: Search queries and delete operations

### Important Notes
- This is a utility class with only constant values
- Cannot create objects of this class
- Provides single source of truth for field names
- If field names need to change, only this file needs updating

---

## Class 13: IndexUtil

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/lucene/IndexUtil.java
Package: org.apache.roller.weblogger.business.search.lucene
```

### Type
Final Class (Utility class)

### Role
Provides helper methods for index operations. Currently has one method to create Lucene Terms correctly.

### Attributes
None (utility class)

### Methods

| Method Name | Parameters | Return Type | What It Does |
|-------------|------------|-------------|--------------|
| `getTerm()` | `String field`<br>`String input` | `Term` | Creates a Lucene Term by analyzing input text |

### Interactions with System
- **Used by**: Delete and search operations
- **Uses**: `LuceneIndexManager.getAnalyzer()` to tokenize text
- **Creates**: Lucene `Term` objects

### Important Notes
- Private constructor prevents creating objects of this class
- The `getTerm()` method is very important because it ensures search and index use same analysis
- For example: if you index "HELLO", it stores "hello" (lowercase)
- When deleting, `getTerm()` converts "HELLO" to "hello" so deletion works
- Returns null if input is null or empty
- Extracts only the first token from analyzed text

---

## Class 14: SearchResultList

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/SearchResultList.java
Package: org.apache.roller.weblogger.business.search
```

### Type
Data Container Class

### Role
Holds search results in a list format with pagination information. This is what gets returned to the user interface to display search results.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `limit` | `int` | Maximum number of results per page |
| `offset` | `int` | Starting position in result set |
| `categories` | `Set<String>` | All categories found in results |
| `results` | `List<WeblogEntryWrapper>` | The actual blog posts found |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| Constructor | - | Creates result list with all data |
| `getLimit()` | `int` | Returns the limit |
| `getOffset()` | `int` | Returns the offset |
| `getCategories()` | `Set<String>` | Returns categories found |
| `getResults()` | `List<WeblogEntryWrapper>` | Returns the blog posts |

### Interactions with System
- **Created by**: `LuceneIndexManager.convertHitsToEntryList()`
- **Returned by**: `IndexManager.search()` method
- **Contains**: Multiple `WeblogEntryWrapper` objects
- **Used by**: UI layer to display search results

### Important Notes
- Simple data container with no business logic
- All blog posts are wrapped in `WeblogEntryWrapper` for security
- Categories can be used to show filters in UI
- Offset and limit enable pagination (showing page 1, 2, 3, etc.)

---

## Class 15: SearchResultMap

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/search/SearchResultMap.java
Package: org.apache.roller.weblogger.business.search
```

### Type
Data Container Class

### Role
Alternative way to hold search results, grouped by date. This could be used for calendar-style result display.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `limit` | `int` | Maximum number of results |
| `offset` | `int` | Starting position in result set |
| `categories` | `Set<String>` | All categories found in results |
| `results` | `Map<Date, Set<WeblogEntryWrapper>>` | Blog posts grouped by publish date |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| Constructor | - | Creates result map with all data |
| `getLimit()` | `int` | Returns the limit |
| `getOffset()` | `int` | Returns the offset |
| `getCategories()` | `Set<String>` | Returns categories found |
| `getResults()` | `Map<Date, Set<WeblogEntryWrapper>>` | Returns the grouped blog posts |

### Interactions with System
- **Similar to**: `SearchResultList` but with different organization
- **Contains**: Multiple `WeblogEntryWrapper` objects grouped by date
- **Defined in**: Interface but not currently used in implementation

### Important Notes
- Similar to SearchResultList but groups results by publication date
- Not currently used - SearchResultList is preferred
- Could be useful for timeline or calendar views
- Kept for potential future use

---

## Related Domain Classes

These classes are not part of the search subsystem but are processed by it.

---

## WeblogEntry (Domain Object)

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/pojos/WeblogEntry.java
Package: org.apache.roller.weblogger.pojos
```

### Type
JPA Entity (Database Table)

### Role
Represents a blog post with all its information. This is what gets indexed and searched.

### Key Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `id` | `String` | Unique identifier |
| `title` | `String` | Post title |
| `text` | `String` | Post content (HTML) |
| `anchor` | `String` | URL-friendly permalink |
| `pubTime` | `Timestamp` | When post was published |
| `updateTime` | `Timestamp` | When post was last edited |
| `locale` | `String` | Language (e.g., "en", "fr") |
| `status` | `PubStatus` | PUBLISHED, DRAFT, PENDING, or SCHEDULED |
| `website` | `Weblog` | Which blog this post belongs to |
| `category` | `WeblogCategory` | Post category |

### Interactions with System
- **Processed by**: All write operations (Add, Remove, ReIndex)
- **Converted to**: Lucene Document in `IndexOperation.getDocument()`
- **Indexed fields**: title, text, category, locale, publish date

### Important Notes
- Only PUBLISHED posts are indexed
- Posts in DRAFT, PENDING, or SCHEDULED status are not searchable
- When post changes from PUBLISHED to DRAFT, it's removed from index
- When post changes from DRAFT to PUBLISHED, it's added to index

---

## Weblog (Domain Object)

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/pojos/Weblog.java
Package: org.apache.roller.weblogger.pojos
```

### Type
JPA Entity (Database Table)

### Role
Represents a blog site. Each blog can have many posts.

### Key Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `id` | `String` | Unique identifier |
| `handle` | `String` | Unique blog name (URL-safe) |
| `name` | `String` | Display name of blog |

### Interactions with System
- **Used by**: RebuildWebsiteIndexOperation, RemoveWebsiteIndexOperation
- **Used for**: Filtering searches to specific blog
- **Indexed in**: Every post document (via handle field)

### Important Notes
- Handle is used to scope searches to one blog
- When blog is deleted, all its posts are removed from index
- Each post stores its blog's handle for filtering

---

## WeblogEntryWrapper (Security Wrapper)

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/pojos/wrapper/WeblogEntryWrapper.java
Package: org.apache.roller.weblogger.pojos.wrapper
```

### Type
Wrapper Class

### Role
Wraps blog posts before showing them to users. It sanitizes HTML and prevents security issues.

### Key Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `pojo` | `WeblogEntry` | The actual blog post |
| `urlStrategy` | `URLStrategy` | How to generate URLs |

### Interactions with System
- **Wraps**: `WeblogEntry` objects
- **Created by**: `LuceneIndexManager.convertHitsToEntryList()`
- **Returned in**: `SearchResultList`
- **Used by**: UI layer

### Important Notes
- All search results are wrapped before being returned to UI
- Prevents XSS (cross-site scripting) attacks by sanitizing HTML
- Generates proper URLs for each post
- If post author is disabled/deleted, wrapper returns null (filters them out)

---

## How Classes Work Together

### When User Publishes a Post:
1. User creates and publishes post → `WeblogEntry` saved to database
2. Application calls `IndexManager.addEntryIndexOperation(entry)`
3. `LuceneIndexManager` creates `AddEntryOperation`
4. Operation runs in background thread
5. `AddEntryOperation` converts post to Lucene `Document`
6. Document added to search index
7. Post now appears in search results

### When User Searches:
1. User types search words and clicks search
2. Application calls `IndexManager.search(term, ...)`
3. `LuceneIndexManager` creates `SearchOperation`
4. `SearchOperation` builds query using search term
5. Query executed against Lucene index
6. Matching documents found
7. Documents converted to `WeblogEntryWrapper` objects
8. Wrapped objects packaged in `SearchResultList`
9. Results displayed to user

### When Index Gets Corrupted:
1. Application starts up
2. `LuceneIndexManager.initialize()` runs
3. Checks for corruption marker file
4. If found, sets `inconsistentAtStartup = true`
5. Creates `RebuildWebsiteIndexOperation` with null (all blogs)
6. Operation runs in background
7. Deletes old index
8. Fetches all published posts from database
9. Re-adds each post to index
10. Index is now healthy again

---

## Thread Safety

### How It Prevents Conflicts:

**Write Lock** (Used by Add, Remove, ReIndex, Rebuild operations):
- Only ONE write operation can run at a time
- While writing is happening, searches must wait
- This prevents data corruption

**Read Lock** (Used by Search operation):
- MULTIPLE searches can run at the same time
- Searches don't block each other
- Searches are blocked only when writing is happening

**Example**: If 10 users search at the same time, all 10 searches run together. But if someone publishes a post during those searches, the publish operation waits until all searches finish before updating the index.

---

## Important Files and Paths

All classes are located under the main application module:

```
project-1-team-30/
└── app/
    └── src/
        └── main/
            └── java/
                └── org/apache                    └── roller/
                        └── weblogger/
                            ├── business/
                            │   └── search/
                            │       ├── IndexManager.java
                            │       ├── SearchResultList.java
                            │       ├── SearchResultMap.java
                            │       └── lucene/
                            │           ├── LuceneIndexManager.java
                            │           ├── IndexOperation.java
                            │           ├── WriteToIndexOperation.java
                            │           ├── ReadFromIndexOperation.java
                            │           ├── AddEntryOperation.java
                            │           ├── RemoveEntryOperation.java
                            │           ├── ReIndexEntryOperation.java
                            │           ├── RebuildWebsiteIndexOperation.java
                            │           ├── RemoveWebsiteIndexOperation.java
                            │           ├── SearchOperation.java
                            │           ├── FieldConstants.java
                            │           └── IndexUtil.java
                            └── pojos/
                                ├── WeblogEntry.java
                                ├── Weblog.java
                                └── wrapper/
                                    └── WeblogEntryWrapper.java
```

---

---

## Strengths and Weaknesses of the Current Design

### Strengths

| Strength | Description |
|----------|-------------|
| **Clean Operation Pattern** | Abstract `IndexOperation` base class with `WriteToIndexOperation` and `ReadFromIndexOperation` provides clear separation between read and write operations, ensuring proper Lucene reader/writer lifecycle management. |
| **Thread-Safe Queuing System** | Background queue (`LinkedBlockingQueue`) with dedicated worker thread ensures non-blocking indexing operations. Write operations don't block user requests. |
| **Interface-Based Abstraction** | `IndexManager` interface decouples search functionality from Lucene implementation details, allowing potential swap to ElasticSearch or Solr without changing higher layers. |
| **Security Wrapper Pattern** | `WeblogEntryWrapper` prevents XSS attacks by sanitizing HTML content before display while keeping original content intact for indexing. |
| **Lazy Initialization** | Index initialization only happens on first search or indexing operation, reducing application startup time. |
| **Incremental Indexing** | Individual operations (`AddEntryOperation`, `RemoveEntryOperation`, `ReIndexEntryOperation`) allow efficient updates without full index rebuilds. |
| **Scheduled Rebuilds** | Automatic nightly index rebuild ensures consistency and fixes any corruption from failed operations. |

---

### Weaknesses

| Weakness | Description | Potential Improvement |
|----------|-------------|----------------------|
| **Single-Threaded Queue** | Only one background thread processes indexing operations. Under high load, indexing queue can grow unbounded. | Implement thread pool with configurable size for parallel operation processing. |
| **No Error Recovery** | Failed indexing operations are logged but not retried. Entries that fail to index remain unsearchable until next rebuild. | Add retry mechanism with exponential backoff and dead-letter queue for persistently failing operations. |
| **Tight Lucene Coupling** | All operation classes directly use Lucene APIs (`IndexWriter`, `IndexReader`, `IndexSearcher`). Migrating to different search engine would require rewriting all operations. | Create internal abstraction layer (`DocumentBuilder`, `QueryBuilder`, `SearchExecutor`) hiding Lucene specifics. |
| **File-Based Index Storage** | Lucene index stored on filesystem limits horizontal scalability. Shared filesystem required for multi-server deployments. | Migrate to distributed search (ElasticSearch, Solr) or use Lucene with remote storage (S3, NFS). |
| **No Search Analytics** | No tracking of search queries, result counts, or performance metrics. Cannot identify popular searches or optimize accordingly. | Add search analytics logging and dashboard for query patterns and performance monitoring. |
| **Limited Query Capabilities** | Only supports basic text search with category filtering. No support for faceting, autocomplete, or fuzzy matching. | Enhance search with advanced Lucene features: facets, suggestions, spell correction, relevance boosting. |
| **Blocking Index Rebuild** | `RebuildWebsiteIndexOperation` locks index for entire rebuild duration, blocking all searches for that weblog. | Implement double-buffering: rebuild into new index, then atomically swap after completion. |
| **No Index Monitoring** | No visibility into index size, document count, queue depth, or operation performance. Issues detected only when searches fail. | Add JMX beans exposing index health metrics, queue statistics, and operation timings. |

---

## Assumptions

The following simplifications were made while modeling this subsystem:

1. **Lucene Framework**: Apache Lucene classes (`IndexWriter`, `IndexReader`, `IndexSearcher`, `Document`, `Query`) are treated as external dependencies with internal implementation details omitted.

2. **WeblogEntry and Weblog Entities**: Treated as external references from the Content Management Subsystem. Only attributes relevant to indexing (title, text, category, locale, status) are shown.

3. **Scheduled Job Infrastructure**: The nightly rebuild scheduling mechanism assumes an external job scheduler (likely Quartz or Spring Scheduler) that triggers `RebuildWebsiteIndexOperation` but is not modeled in detail.

4. **File System Access**: Index storage location, file permissions, disk space management, and backup strategies are assumed to be handled by external configuration and operations but not detailed.

5. **Concurrency Control**: How Lucene handles concurrent readers/writers, lock file management, and index corruption prevention are abstracted as Lucene framework responsibilities.

6. **Configuration Management**: Properties for index directory paths, rebuild schedules, queue sizes, and Lucene analyzer settings are assumed to exist in external configuration files (`roller.properties`).

7. **WeblogManager Integration**: How `LuceneIndexManager` obtains the `WeblogManager` reference and retrieves weblog entries for indexing is simplified.

8. **Exception Handling**: Error handling, retry logic, and exception propagation details are omitted for clarity. Assumes operations handle Lucene exceptions (`IOException`, `CorruptIndexException`).

---

## UML Diagram Reference

This report corresponds to the PlantUML diagram in: `search_indexing_uml_diagram.puml`

![alt text](image.png)

The diagram shows:
- **Inheritance**: Arrows with hollow triangles (e.g., AddEntryOperation extends WriteToIndexOperation)
- **Interface Implementation**: Dotted arrows (e.g., LuceneIndexManager implements IndexManager)
- **Associations**: Solid arrows (e.g., LuceneIndexManager creates IndexOperation)
- **Dependencies**: Dotted arrows (e.g., Operations use FieldConstants)

---


