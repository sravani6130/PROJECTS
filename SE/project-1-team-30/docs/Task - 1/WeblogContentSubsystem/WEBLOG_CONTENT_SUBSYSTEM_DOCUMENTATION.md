# Weblog and Content Subsystem - Documentation

We covered the Weblog and Content Subsystem of Apache Roller as part of sub-system 1. We split it into 5 areas based on what each part does:

1. **Blog Management**
2. **Entries Management**
3. **Comment Management**
4. **Rendering Engine**
5. **Content Fetching & Serving**

---

## 1. Blog Management

### Classes in Blog Management

1. **Weblog** [Class]
2. **WeblogManager** [Interface]
3. **JPAWeblogManagerImpl** [Class]
4. **WeblogCategory** [Class]
5. **WeblogTheme** [Abstract Class]
6. **User** [Class]

---

### 1.1 Weblog [Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`Weblog` is the main class that represents a blog. Every blog in Apache Roller is a `Weblog` object. It has all the settings, content links, and user info that a blog needs to work.

**Purpose:**  
- Acts as the central object for a blog
- Stores blog settings like name, handle, theme, locale, and timezone
- Keeps track of comment, feed, and plugin settings
- Links to categories, media directories, and users
- Handles permission checks for access control

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | UUID - Primary key |
| `handle` | String | Unique URL-friendly identifier for the blog |
| `name` | String | Display name of the blog |
| `creatorUserName` | String | Username of blog creator |
| `editorTheme` | String | Name of the theme being used |

**Key Methods:**

```java
public String getId()
public String getHandle()
public String getName()
public void setName(String name)

// Settings
public String getLocale()
public String getTimeZone()
public WeblogTheme getTheme()

// Category & Content Access
public List<WeblogCategory> getWeblogCategories()
public List<WeblogEntry> getRecentWeblogEntries(String cat, int length)
```

**Interactions & Relations:**

1. **WeblogManager** - Manages lifecycle (CRUD operations) of Weblog instances
2. **User** - Each Weblog has a creator (User) and can have multiple users with permissions
3. **WeblogCategory** - One-to-many relationship; a Weblog contains multiple categories
4. **MediaFileDirectory** - One-to-many; manages media file organization
5. **WeblogEntry** - One-to-many; Weblog contains many blog entries
6. **WeblogTheme** - Weblog uses a theme for rendering  
7. **WeblogEntryComment** - Indirectly related through entries
8. **UserManager** - Used to retrieve User objects for permission checking

---

### 1.2 WeblogManager [Interface]

**Package:** `org.apache.roller.weblogger.business`

**Description:**  
`WeblogManager` is an interface that lists all the operations you can do with blogs — creating, reading, updating, and deleting them. It is between the UI layer and the database so that the rest of the code doesn't need to know how data is stored.

**Purpose:**  
- Lists all the business operations for managing blogs
- Gives a clean API so the UI code doesn't talk to the database directly
- Makes sure all blog operations work the same way regardless of implementation
- Handles blog templates and themes
- Supports blog queries and statistics

**Key Methods:**

```java
// Weblog CRUD Operations
public void addWeblog(Weblog newWeblog) throws WebloggerException
public void saveWeblog(Weblog weblog) throws WebloggerException
public void removeWeblog(Weblog weblog) throws WebloggerException

// Weblog Retrieval
public Weblog getWeblog(String id) throws WebloggerException
public Weblog getWeblogByHandle(String handle) throws WebloggerException
public List<Weblog> getUserWeblogs(User user, boolean enabledOnly) throws WebloggerException

// User Management
public List<User> getWeblogUsers(Weblog weblog, boolean enabledOnly) throws WebloggerException


```

**Interactions & Relations:**

1. **Weblog** - Primary entity being managed
2. **JPAWeblogManagerImpl** - Concrete implementation of this interface
3. **User** - Retrieves users associated with weblogs
4. **ThemeTemplate** - Manages custom templates for weblogs
5. **UserManager** - Coordinates with user management
6. **WeblogEntryManager** - Coordinates with entry management during weblog operations
7. **MediaFileManager** - Coordinates with media file management
8. **WebloggerFactory** - Provides access to WeblogManager instance

---

### 1.3 JPAWeblogManagerImpl [Class]

**Package:** `org.apache.roller.weblogger.business.jpa`

**Description:**  
`JPAWeblogManagerImpl` is the actual implementation of `WeblogManager` that talks to the database using JPA (Java Persistence API) and Hibernate. This is where all the SQL queries and database saves happen for blogs.

**Purpose:**  
- Does the database work for all blog operations
- Saves and loads blog data using JPA
- Handles cascading operations — when you create a blog it sets up defaults, when you delete one it removes everything related
- Caches blog handle lookups so it doesn't hit the database every time
- Sets up default categories, folders, and permissions for new blogs

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `strategy` | JPAPersistenceStrategy | JPA persistence strategy for database operations |
| `weblogHandleToIdMap` | Map\<String, String\> | Cache mapping weblog handles to IDs |

**Key Methods:**

```java
// Constructor
@Inject
protected JPAWeblogManagerImpl(Weblogger roller, JPAPersistenceStrategy strat)

// Weblog CRUD Operations
public void saveWeblog(Weblog weblog) throws WebloggerException
public void removeWeblog(Weblog weblog) throws WebloggerException
public Weblog getWeblog(String id) throws WebloggerException

// Template Management
public void saveTemplate(WeblogTemplate template) throws WebloggerException
public WeblogTemplate getTemplate(String id) throws WebloggerException

// Theme & Validation
public WeblogTheme getTheme(Weblog weblog) throws WebloggerException
```

**Interactions & Relations:**

1. **WeblogManager** - Implements this interface
2. **Weblog** - Primary entity being persisted
3. **JPAPersistenceStrategy** - Uses for all database operations
4. **Weblogger** - Accesses other managers (MediaFileManager, UserManager, etc.)
5. **MediaFileManager** - Called to create default media directory
6. **UserManager** - Grants permissions to weblog creator
7. **WeblogEntryManager** - Coordinates during weblog deletion
8. **Database** - Executes JPQL queries and JPA operations

---

### 1.4 WeblogCategory [Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`WeblogCategory` is a category that you use to group blog posts. For example, a blog might have categories like "Tech", "Travel", or "General". Each post goes into one category.

**Purpose:**  
- Groups blog posts into categories
- Lets users browse and filter entries by category
- Gives the blog an organized structure
- Supports category-specific pages and feeds

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | UUID - Primary key |
| `name` | String | Category name (unique within weblog) |
| `position` | int | Sort order position |
| `weblog` | Weblog | Reference to parent weblog |

**Key Methods:**

```java
// Identity & Core Properties
public String getId()
public String getName()
public int getPosition()

// Association
public Weblog getWeblog()

// Content Access
public List<WeblogEntry> retrieveWeblogEntries(boolean publishedOnly) throws WebloggerException
```

**Interactions & Relations:**

1. **Weblog** - Many-to-one relationship; each category belongs to one weblog
2. **WeblogEntry** - One-to-many; category contains multiple entries
3. **WeblogEntryManager** - Manages categories and checks usage
4. **URLStrategy** - Generates category-specific URLs
5. **WeblogEntriesPager** - Filters entries by category for display

---

### 1.5 WeblogTheme [Abstract Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`WeblogTheme` is an abstract class that represents the look and feel of a blog. It controls what templates are used when rendering blog pages. Since it's abstract, you can't use it directly — it has to be extended by a concrete theme class.

**Purpose:**  
- Provides a base class for all blog themes
- Links a theme to a specific blog
- Defines what methods a theme must have (like getting templates)
- Supports both shared themes (used by many blogs) and custom themes (unique to one blog)

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `weblog` | Weblog | Reference to the weblog using this theme |

**Constants:**

```java
public static final String CUSTOM = "custom"
```

**Key Methods:**

```java
// WeblogTheme specific
public Weblog getWeblog()

// Abstract methods (from Theme interface) - must be implemented by subclasses
public abstract String getName()
public abstract String getDescription()
public abstract WeblogTemplate getTemplate(String name)
public abstract WeblogTemplate getDefaultTemplate()
public abstract WeblogTemplate getTemplateByAction(ComponentType action)

```

**Interactions & Relations:**

1. **Weblog** - Each weblog has one theme
2. **ThemeTemplate** - Theme provides templates for rendering
3. **ThemeManager** - Manages theme loading and retrieval
4. **RendererManager** - Uses theme templates for rendering
5. **PageServlet** - Retrieves templates from weblog theme for page rendering

---

### 1.6 User [Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`User` represents a person who uses Apache Roller. A user can create blogs, write posts, and moderate comments. This class stores their login info, profile, and preferences.

**Purpose:**  
- Stores login credentials (username, password)
- Keeps profile info like email and screen name
- Tracks preferences like language and timezone
- Manages whether the account is active or disabled
- Works with the permission system to control what users can do

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | UUID - Primary key |
| `userName` | String | Unique username for login |
| `emailAddress` | String | Email address |
| `enabled` | Boolean | Whether account is enabled |

**Key Methods:**

```java
// Identity  
public String getId()

// Authentication
public String getUserName()
public String getPassword()

// Profile
public String getEmailAddress()

// Status & Permissions
public Boolean getEnabled()
```

**Interactions & Relations:**

1. **Weblog** - Users create and manage weblogs
2. **WeblogManager** - Retrieves weblogs for a user
3. **UserManager** - Manages user lifecycle and permissions
4. **WeblogEntry** - Users author entries (as creators)
5. **WeblogEntryComment** - Users can comment on entries
6. **WeblogPermission** - Many-to-many relationship defining user permissions on weblogs
7. **Spring Security** - Integrates with authentication/authorization framework

---

## 2. Entries Management

### Classes in Entries Management

1. **WeblogEntry** [Class]
2. **WeblogEntryManager** [Interface]
3. **JPAWeblogEntryManagerImpl** [Class]
4. **EntryEdit** [Class]
5. **EntryBean** [Class]
6. **WeblogEntryTag** [Class]
7. **WeblogEntryAttribute** [Class]
8. **MediaFile** [Class]
9. **MediaFileManager** [Interface]
10. **JPAMediaFileManagerImpl** [Class]
11. **MediaFileDirectory** [Class]
12. **MediaFileTag** [Class]
13. **MediaFileAdd** [Class]

---

### 2.1 WeblogEntry [Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`WeblogEntry` is a blog post. This class holds everything about a single post — its title, body text, tags, status (draft/published), and when it was posted.

**Purpose:**  
- Stores the post content (title, text, summary)
- Tracks whether it's a draft, published, pending, or scheduled
- Links the post to a category and tags
- Controls comment settings for that particular post
- Supports media attachments through entry attributes
- Keeps track of who wrote it, when, and the URL anchor

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|------------|
| `id` | String | UUID - Primary key |
| `title` | String | Entry title |
| `text` | Text | Main content body |
| `status` | PubStatus | Publication status (DRAFT, PUBLISHED, PENDING, SCHEDULED) |
| `website` | Weblog | Parent weblog |

**Nested Enum:**

```java
public enum PubStatus {DRAFT, PUBLISHED, PENDING, SCHEDULED}
```

**Key Methods:**

```java
// Core Content
public String getTitle()
public void setTitle(String title)
public String getText()
public void setText(String text)

// Status & Timing
public PubStatus getStatus()
public void setStatus(PubStatus status)
public Timestamp getPubTime()
public void setPubTime(Timestamp pubTime)

// Associations
public Weblog getWebsite()
public void setWebsite(Weblog website)
```

**Interactions & Relations:**

1. **Weblog** - Many-to-one; each entry belongs to one weblog
2. **WeblogCategory** - Many-to-one; entry is in one primary category
3. **User** - Creator relationship via creatorUserName
4. **WeblogEntryManager** - Manages entry lifecycle (CRUD, queries)
5. **WeblogEntryTag** - One-to-many; entry can have multiple tags
6. **WeblogEntryAttribute** - One-to-many; stores metadata like media enclosures
7. **WeblogEntryComment** - One-to-many; entry can have multiple comments
8. **IndexManager** - Indexes entry for search
9. **AutoPingManager** - Sends pings when entry is published
10. **RendererManager** - Renders entry content for display

---

### 2.2 WeblogEntryManager [Interface]

**Package:** `org.apache.roller.weblogger.business`

**Description:**  
`WeblogEntryManager` is an interface that defines all the operations for working with blog posts, categories, comments, and tags. It's the go-to API for anything related to blog content.

**Purpose:**  
- Lists all the operations you can do with blog entries
- Keeps the database logic hidden behind a clean API
- Supports complex search queries (by date, status, category, etc.)
- Manages categories and comments along with entries
- Handles tag counts and statistics
- Generates unique URL anchors for entries

**Key Methods:**

```java
// Entry CRUD
public void saveWeblogEntry(WeblogEntry entry) throws WebloggerException
public void removeWeblogEntry(WeblogEntry entry) throws WebloggerException
public WeblogEntry getWeblogEntry(String id) throws WebloggerException

// Category CRUD
public void saveWeblogCategory(WeblogCategory cat) throws WebloggerException
public WeblogCategory getWeblogCategory(String id) throws WebloggerException

// Comment CRUD
public void saveComment(WeblogEntryComment comment) throws WebloggerException
public WeblogEntryComment getComment(String id) throws WebloggerException
```

**Interactions & Relations:**

1. **WeblogEntry** - Primary entity being managed
2. **JPAWeblogEntryManagerImpl** - Concrete JPA implementation
3. **WeblogCategory** - Manages categories for organizing entries
4. **WeblogEntryComment** - Manages comments on entries
5. **WeblogEntryTag** - Manages tags for entries
6. **WeblogEntrySearchCriteria** - Used for complex entry queries
7. **CommentSearchCriteria** - Used for comment queries
8. **IndexManager** - Coordinates with search indexing
9. **AutoPingManager** - Coordinates with ping notifications

---

### 2.3 JPAWeblogEntryManagerImpl [Class]

**Package:** `org.apache.roller.weblogger.business.jpa`

**Description:**  
`JPAWeblogEntryManagerImpl` is the actual database implementation of `WeblogEntryManager`. It uses JPA/Hibernate to save, load, update, and delete blog posts, comments, categories, and tags.

**Purpose:**  
- Does all the database work for blog entries using JPA
- Saves and loads entries, comments, categories, and tags
- Keeps track of tag counts and updates them when entries change
- Caches entry anchor-to-ID lookups for faster access
- Builds complex JPQL queries for searching entries
- When you delete an entry, it also removes its comments, tags, and attributes

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `strategy` | JPAPersistenceStrategy | JPA persistence strategy |
| `entryAnchorToIdMap` | Map\<String, String\> | Cache mapping entry anchors to IDs |



**Key Methods:**

```java
// Entry CRUD
@Override
public void saveWeblogEntry(WeblogEntry entry) throws WebloggerException
@Override
public void removeWeblogEntry(WeblogEntry entry) throws WebloggerException
@Override
public WeblogEntry getWeblogEntry(String id) throws WebloggerException
@Override
public List<WeblogEntry> getWeblogEntries(WeblogEntrySearchCriteria wesc) throws WebloggerException

// Category & Comment Operations
@Override
public void saveWeblogCategory(WeblogCategory cat) throws WebloggerException
@Override
public void saveComment(WeblogEntryComment comment) throws WebloggerException

// Tag Operations
@Override
public List<TagStat> getPopularTags(Weblog website, Date startDate, int offset, int limit) throws WebloggerException
```

**Interactions & Relations:**

1. **WeblogEntryManager** - Implements this interface
2. **WeblogEntry** - Primary entity being persisted
3. **JPAPersistenceStrategy** - Uses for all database operations
4. **Weblogger** - Accesses other managers (WeblogManager, AutoPingManager, IndexManager)
5. **IndexManager** - Updates search index when entries change
6. **AutoPingManager** - Queues pings when entries published
7. **WeblogManager** - Updates weblog lastModified timestamp
8. **Database** - Executes JPQL queries

---

### 2.4 EntryEdit [Class]

**Package:** `org.apache.roller.weblogger.ui.struts2.editor`

**Description:**  
`EntryEdit` is a Struts2 action class — it's what runs when a user creates or edits a blog post through the web UI. It handles the form, validates the input, and calls the backend to save the entry.

**Purpose:**  
- Runs the create/edit blog post page
- Handles switching between draft and published status
- Validates the entry before saving
- Calls `WeblogEntryManager` to save the entry to the database
- Supports post preview before publishing
- Handles trackback pings
- Provides data the UI needs like categories, plugins, and recent entries

**Key Methods:**

```java
// Action Methods
@Override
public String execute()
public String saveDraft()
public String publish()

// UI Support
public String getPreviewURL()
public List<WeblogCategory> getCategories()
public List<WeblogEntry> getRecentPublishedEntries()

// Accessors
public EntryBean getBean()
public WeblogEntry getEntry()
```

**Interactions & Relations:**

1. **EntryBean** - Form bean for data transfer
2. **WeblogEntry** - Domain object being edited
3. **WeblogEntryManager** - Saves/retrieves entries
4. **WeblogManager** - Retrieves weblog context
5. **UserManager** - Checks user permissions
6. **IndexManager** - Triggers search index updates
7. **AutoPingManager** - Sends trackback pings
8. **Struts2 Framework** - Action execution and validation

---

### 2.5 EntryBean [Class]

**Package:** `org.apache.roller.weblogger.ui.struts2.editor`

**Description:**  
`EntryBean` is a data transfer object (DTO) that sits between the web form and the `WeblogEntry` domain object. It takes form input, converts it into the right format, and copies it to/from the actual entry object.

**Purpose:**  
- Bridges the gap between what the form sends and what `WeblogEntry` expects
- Handles date and time separately (date picker + time picker in the UI)
- Converts data between how it's displayed and how it's stored
- Makes it easier to manage plugin selections
- Provides helper methods to check if an entry is a draft or published

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | Entry ID |
| `title` | String | Entry title |
| `text` | String | Entry content |
| `status` | String | Publication status |
| `tagsAsString` | String | Space-separated tags |

**Key Methods:**

```java
// Publication Time Handling
public String getDateString()
public void setDateString(String date)
public Timestamp getPubTime(Locale locale, TimeZone timezone)

// Status Checks
public boolean isDraft()
public boolean isPublished()

// Data Transfer
public void copyTo(WeblogEntry entry) throws WebloggerException
public void copyFrom(WeblogEntry entry, Locale locale)
```

**Interactions & Relations:**

1. **WeblogEntry** - Copies data to/from domain object
2. **EntryEdit** - Used by action for form binding
3. **Struts2 Framework** - Form data binding
4. **Locale/TimeZone** - Handles time zone conversions

---

### 2.6 WeblogEntryTag [Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`WeblogEntryTag` is a tag on a blog post (like "java", "tutorial", "news"). Tags are converted to lowercase so searching works consistently.

**Purpose:**  
- Attaches tags to blog entries
- Lets users browse posts by tag
- Used to build tag clouds (showing popular tags)
- Tracks who added the tag and when

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | UUID - Primary key |
| `name` | String | Tag name (normalized lowercase) |
| `weblogEntry` | WeblogEntry | Entry this tag is on |
| `weblog` | Weblog | Parent weblog |

**Key Methods:**

```java
public String getId()
public String getName()
public void setName(String name)
public Timestamp getTime()
public WeblogEntry getWeblogEntry()
public void setWeblogEntry(WeblogEntry entry)
public Weblog getWeblog()
public void setWeblog(Weblog weblog)
public String getCreatorUserName()
public User getCreator()
```

**Interactions & Relations:**

1. **WeblogEntry** - Many-to-one; tag belongs to one entry
2. **Weblog** - Many-to-one; tag belongs to weblog
3. **User** - Creator via creatorUserName
4. **WeblogEntryTagAggregate** - Aggregated counts for tag clouds
5. **WeblogEntryManager** - Manages tags and aggregates

---

### 2.7 WeblogEntryAttribute [Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`WeblogEntryAttribute` is a key-value pair attached to a blog entry. It's mostly used to store podcast/media enclosure info (like a media URL, file size, and MIME type), but it's flexible enough for any extra data.

**Purpose:**  
- Stores extra metadata on entries as key-value pairs
- Handles podcast/MediaCast enclosures (URL, length, type)
- Lets plugins add their own data to entries without changing the database schema
- Acts as a general-purpose extension point

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | UUID - Primary key |
| `entry` | WeblogEntry | Parent entry |
| `name` | String | Attribute name/key |
| `value` | String | Attribute value |

**Key Methods:**

```java
// Identity & Properties
public String getId()
public String getName()

// Association
public WeblogEntry getEntry()
public Weblog getWeblog()

```


**Interactions & Relations:**

1. **WeblogEntry** - Many-to-one; attribute belongs to one entry
2. **WeblogEntryManager** - Provides removeWeblogEntryAttribute() method
3. **EntryEdit** - Manages enclosure URL via attributes

---

### 2.8 MediaFile [Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`MediaFile` represents an uploaded file — could be an image, video, audio file, or document. It stores the file's metadata (name, size, type) and for images, it also tracks dimensions and thumbnails.

**Purpose:**  
- Represents any uploaded media file in the system
- Stores file info like name, MIME type, size, and timestamps
- Tracks image dimensions and generates thumbnails for images
- Supports tagging media files for organization
- Provides URLs so media can be accessed from the web
- Can be linked to blog entries as inline media or podcast enclosures

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | UUID - Primary key |
| `name` | String | Filename |
| `contentType` | String | MIME type (e.g., "image/jpeg") |
| `length` | long | File size in bytes |
| `directory` | MediaFileDirectory | Directory containing file |

**Key Methods:**

```java
// Identity & Core Properties
public String getId()
public String getName()
public String getContentType()
public long getLength()

// Associations
public MediaFileDirectory getDirectory()
public Weblog getWeblog()

// Content & URLs
public InputStream getInputStream()
public String getPermalink()
```

**Interactions & Relations:**

1. **Weblog** - Many-to-one; file belongs to one weblog
2. **MediaFileDirectory** - Many-to-one; organized in directories
3. **User** - Creator via creatorUserName
4. **MediaFileManager** - Manages lifecycle and queries
5. **MediaFileTag** - One-to-many; file can have multiple tags
6. **FileContent** - Stores actual binary content (JPA entity)
7. **WeblogEntry** - Can be referenced in entry content or as enclosure
8. **URLStrategy** - Generates media file URLs

---

### 2.9 MediaFileManager [Interface]

**Package:** `org.apache.roller.weblogger.business`

**Description:**  
`MediaFileManager` is an interface that defines all the operations for handling uploaded files — uploading, updating, deleting, searching, and organizing them into directories.

**Purpose:**  
- Lists all the operations for working with media files
- Handles file uploads and storage
- Manages directories where files are organized
- Supports searching and filtering media files
- Handles moving files between directories
- Manages tags on media files

**Constants:**

```java
public static final int MAX_WIDTH = 120
public static final int MAX_HEIGHT = 120
```

**Key Methods:**

```java
// Media File CRUD
public void createMediaFile(Weblog weblog, MediaFile mediaFile, RollerMessages errors) throws WebloggerException
public void updateMediaFile(Weblog weblog, MediaFile mediaFile) throws WebloggerException
public void removeMediaFile(Weblog weblog, MediaFile mediaFile) throws WebloggerException
public MediaFile getMediaFile(String id) throws WebloggerException
public List<MediaFile> searchMediaFiles(Weblog weblog, MediaFileFilter filter) throws WebloggerException

// Directory Management
public MediaFileDirectory createDefaultMediaFileDirectory(Weblog weblog) throws WebloggerException
public MediaFileDirectory getMediaFileDirectory(String id) throws WebloggerException
public List<MediaFileDirectory> getMediaFileDirectories(Weblog weblog) throws WebloggerException
```

**Interactions & Relations:**

1. **MediaFile** - Primary entity being managed
2. **JPAMediaFileManagerImpl** - Concrete JPA implementation
3. **MediaFileDirectory** - Manages directory structure
4. **MediaFileFilter** - Used for search queries
5. **FileContentManager** - Handles binary file storage
6. **Weblog** - Media files belong to weblogs
7. **WeblogManager** - Coordinates during weblog operations
8. **RollerMessages** - Reports validation errors

---

### 2.10 JPAMediaFileManagerImpl [Class]

**Package:** `org.apache.roller.weblogger.business.jpa`

**Description:**  
`JPAMediaFileManagerImpl` is the database implementation of `MediaFileManager`. It saves file metadata to the database via JPA and uses `FileContentManager` to store the actual binary files on disk.

**Purpose:**  
- Does the database work for media files using JPA
- Saves file metadata (name, size, type) and loads it back
- Creates thumbnails for uploaded images
- Validates uploads (checks if uploads are enabled, file size limits, disk quota)
- Stores actual file content through `FileContentManager`
- Organizes files into directories

**Implementation Details:**

1. **createMediaFile()** - Handles:
   - Upload validation (disabled check, quota, file size)
   - Content type validation
   - Image dimension extraction
   - Thumbnail generation for images
   - Binary content storage via FileContentManager
   - Database persistence

**Key Methods:**

```java
@Override
public void createMediaFile(Weblog weblog, MediaFile mediaFile, RollerMessages errors) throws WebloggerException
@Override
public void updateMediaFile(Weblog weblog, MediaFile mediaFile) throws WebloggerException
@Override
public void removeMediaFile(Weblog weblog, MediaFile mediaFile) throws WebloggerException
@Override
public MediaFile getMediaFile(String id) throws WebloggerException
@Override
public List<MediaFile> searchMediaFiles(Weblog weblog, MediaFileFilter filter) throws WebloggerException
@Override
public MediaFileDirectory createDefaultMediaFileDirectory(Weblog weblog) throws WebloggerException
@Override
public List<MediaFileDirectory> getMediaFileDirectories(Weblog weblog) throws WebloggerException
```

**Interactions & Relations:**

1. **MediaFileManager** - Implements this interface
2. **MediaFile** - Primary entity being persisted
3. **JPAPersistenceStrategy** - Database operations
4. **FileContentManager** - Binary file storage
5. **Weblogger** - Accesses WeblogManager
6. **PropertiesManager** - Checks quotas and file size limits
7. **WeblogManager** - Updates weblog lastModified
8. **ImageIO** - Extracts image dimensions and generates thumbnails

---

### 2.11 MediaFileDirectory [Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`MediaFileDirectory` is a folder for organizing media files within a blog. It's like a directory on your computer — you can group related files together.

**Purpose:**  
- Groups media files into folders
- Keeps uploaded files organized
- Each file name is unique within a directory
- Users can browse files by directory

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | UUID - Primary key |
| `name` | String | Directory name |
| `weblog` | Weblog | Parent weblog |

**Key Methods:**

```java
public String getId()
public String getName()
public void setName(String name)
public Weblog getWeblog()
public void setWeblog(Weblog weblog)
public Set<MediaFile> getMediaFiles()
```

**Interactions & Relations:**

1. **Weblog** - Many-to-one; directory belongs to one weblog
2. **MediaFile** - One-to-many; directory contains multiple files
3. **MediaFileManager** - Manages directory lifecycle
4. **WeblogManager** - Creates default directory during weblog creation

---

### 2.12 MediaFileTag [Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`MediaFileTag` is a tag on a media file, similar to how `WeblogEntryTag` works for blog posts. You can tag an image as "vacation" or "logo" to find it more easily later.

**Purpose:**  
- Lets users tag their media files
- Supports searching media files by tag
- Gives another way to organize files besides directories
- Useful for building media galleries or filters

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | UUID - Primary key |
| `name` | String | Tag name (normalized lowercase) |
| `mediaFile` | MediaFile | Media file this tag is on |

**Key Methods:**

```java
public String getId()
public String getName()
public void setName(String name)
public MediaFile getMediaFile()
public void setMediaFile(MediaFile mediaFile)
public Weblog getWeblog()
```

**Interactions & Relations:**

1. **MediaFile** - Many-to-one; tag belongs to one media file
2. **Weblog** - Accessed via mediaFile.getWeblog()
3. **MediaFileManager** - Manages tags via removeMediaFileTag()

---

### 2.13 MediaFileAdd [Class]

**Package:** `org.apache.roller.weblogger.ui.struts2.editor`

**Description:**  
`MediaFileAdd` is the Struts2 action class for the "Insert Media File" button in the blog editor. When a user uploads an image or file, this class handles the upload, validates it, and creates the `MediaFile` object.

**Purpose:**  
- Runs the media file upload page
- Processes uploaded files from the form
- Validates that the files are acceptable (size, type, etc.)
- Creates `MediaFile` objects from the uploaded data
- Puts files into the right directory
- Shows success/error messages to the user

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `uploadedFiles` | File[] | Uploaded file objects (Struts2) |
| `directory` | MediaFileDirectory | Target directory for uploads |
| `newImages` | List\<MediaFile\> | Successfully uploaded images |

**Key Methods:**

```java
// Actions
@Override
public String execute()
public String save()

// Validation
public void myValidate()

// Accessors
public MediaFileBean getBean()
public MediaFileDirectory getDirectory()
public File[] getUploadedFiles()
public List<MediaFile> getNewImages()
```


**Interactions & Relations:**

1. **MediaFileBean** - Form bean for file metadata
2. **MediaFile** - Creates domain objects
3. **MediaFileManager** - Persists uploaded files
4. **MediaFileDirectory** - Organizes files
5. **Weblog** - Files belong to weblog
6. **Struts2 Framework** - File upload handling
7. **RollerMessages** - Validation error reporting

---

## 3. Comment Management

### Classes in Comment Management

1. **WeblogEntryComment** [Class]
2. **CommentSearchCriteria** [Class]
3. **CommentServlet** [Class]

---

### 3.1 WeblogEntryComment [Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`WeblogEntryComment` is a comment on a blog post. It stores the comment text, the commenter's name/email/URL, whether it's approved or spam, and notification preferences.

**Purpose:**  
- Stores the comment content and who posted it
- Tracks the commenter's name, email, and website URL
- Manages the approval workflow (pending, approved, disapproved, spam)
- Supports comment moderation by blog owners
- Collects metadata for spam detection (IP address, user agent, etc.)
- Handles email notification preferences ("notify me of replies")
- Can support threaded/reply-to comments

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | UUID - Primary key |
| `content` | Text | Comment content/text |
| `status` | ApprovalStatus | Approval status (APPROVED, PENDING, DISAPPROVED, SPAM) |
| `weblogEntry` | WeblogEntry | Entry this comment is on |

**Nested Enum:**

```java
public enum ApprovalStatus {APPROVED, PENDING, DISAPPROVED, SPAM}
```

**Key Methods:**

```java
// Identity & Commenter
public String getId()
public String getName()
public void setName(String name)
public String getEmail()
public void setEmail(String email)

// Content
public String getContent()
public void setContent(String content)

// Status & Association
public ApprovalStatus getStatus()
public void setStatus(ApprovalStatus status)
public WeblogEntry getWeblogEntry()
```

**Interactions & Relations:**

1. **WeblogEntry** - Many-to-one; comment belongs to one entry
2. **Weblog** - Accessed via weblogEntry.getWebsite()
3. **WeblogEntryManager** - Manages comment lifecycle (save, delete, query)
4. **CommentServlet** - Creates and processes comment submissions
5. **CommentSearchCriteria** - Used for querying comments
6. **CommentValidationManager** - Validates comments for spam
7. **MailUtil** - Sends email notifications
8. **CacheManager** - Invalidates cache when comments change
9. **IndexManager** - Updates search index when comments added

---

### 3.2 CommentSearchCriteria [Class]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`CommentSearchCriteria` is a search filter object for finding comments. Instead of passing a dozen parameters to a query method, you fill in this object with the filters you want (by blog, by entry, by status, etc.) and pass it to the manager.

**Purpose:**  
- Bundles all the search filters for comment queries into one object
- Supports filtering by blog, entry, status, date range, and text
- Handles pagination (offset and limit)
- Makes the `WeblogEntryManager` query methods cleaner
- Used in the admin comment moderation page

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `weblog` | Weblog | Filter by weblog (optional) |
| `entry` | WeblogEntry | Filter by specific entry (optional) |
| `status` | ApprovalStatus | Filter by approval status |
| `offset` | int | Pagination offset |

**Key Methods:**

```java
// Filter Criteria
public Weblog getWeblog()
public void setWeblog(Weblog weblog)
public WeblogEntry getEntry()
public void setEntry(WeblogEntry entry)

// Status & Pagination
public ApprovalStatus getStatus()
public void setStatus(ApprovalStatus status)
public int getOffset()
public void setOffset(int offset)
public int getMaxResults()
```


**Interactions & Relations:**

1. **WeblogEntryManager** - Uses this for getComments() queries
2. **WeblogEntry** - Filter by specific entry
3. **Weblog** - Filter by weblog
4. **ApprovalStatus** - Filter by moderation status
5. **Comment moderation UI** - Used in admin interface for filtering

---

### 3.3 CommentServlet [Class]

**Package:** `org.apache.roller.weblogger.ui.rendering.servlets`

**Description:**  
`CommentServlet` is the servlet that processes comment form submissions. When someone posts a comment on a blog, this servlet checks for spam, validates the data, applies moderation rules, saves the comment, sends emails, and updates the search index.

**Purpose:**  
- Handles the HTTP POST when someone submits a comment
- Checks the commenter's identity (CAPTCHA, etc.)
- Validates the comment data (email format, URL format, content)
- Runs spam detection on the comment
- Applies moderation rules (auto-approve vs. pending vs. spam)
- Saves valid comments to the database
- Sends email notifications to the blog owner and other commenters
- Updates the search index and clears cached pages
- Supports comment preview before posting
- Rate-limits comment submissions to stop spam floods

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `commentValidationManager` | CommentValidationManager | Spam detection and validation |
| `commentThrottle` | GenericThrottle | Rate limiting to prevent spam floods |

**Constants & Configuration:**

- `comment.authenticator.classname` - Configurable authenticator class
- `comment.throttle.enabled` - Enable/disable throttling
- `comment.throttle.threshold` - Max comments per interval
- `comment.throttle.interval` - Throttling time window
- `users.comments.htmlenabled` - Allow HTML in comments
- `users.comments.plugins` - Comment content plugins
- `comments.ignoreSpam.enabled` - Don't save spam comments

**Key Methods:**

```java
// Servlet Lifecycle
@Override
public void init(ServletConfig servletConfig) throws ServletException

// HTTP Methods
@Override
public void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException
```

**Comment Processing Workflow (doPost):**

1. **Parse Request:**
   - Extract method parameter (preview vs. post)
   - Create WeblogCommentRequest from HTTP request
   - Lookup weblog and entry

2. **Throttling Check:**
   - Check if IP address is making too many requests
   - Ban IP if threshold exceeded
   - Return 404 for banned IPs

3. **Collect Comment Data:**
   - Extract name, email, URL, content, notify flag
   - Validate and normalize URL (add http:// if missing)
   - Set content type (text/html or text/plain based on config)
   - Set plugins configuration
   - Capture spam detection metadata (remoteHost, referrer, userAgent)

4. **Validation:**
   - Check if comments are allowed (site, weblog, entry settings)
   - Check if entry is published
   - Validate email address (required and format)
   - Validate URL format (optional but must be valid if provided)
   - Authenticate request (CAPTCHA, etc.) - skipped for preview

5. **Spam Detection:**
   - Run CommentValidationManager.validateComment()
   - Returns validation score (0-100%)
   - Score < 100% indicates potential spam

6. **Status Assignment:**
   - **100% + moderation required** → PENDING
   - **100% + no moderation** → APPROVED
   - **< 100%** → SPAM

7. **Save Comment (if not preview and not ignored spam):**
   - Call WeblogEntryManager.saveComment()
   - Flush changes to database

8. **Email Notifications:**
   - Send notifications to blog owner
   - Send notifications to other commenters (if opted in)
   - Only for approved comments (100% validation score)

9. **Search Index & Cache:**
   - Remove old entry from index
   - Re-add entry to index (with new comment)
   - Invalidate page cache
   - Only if comment not moderated

10. **Response:**
    - Set success/error message
    - Forward back to entry page with comment form
    - Comment form shows success, error, or preview

**Interactions & Relations:**

1. **WeblogEntryComment** - Creates and saves comment objects
2. **WeblogEntry** - Comments belong to entries
3. **Weblog** - Checks comment settings
4. **WeblogCommentRequest** - Parses HTTP request
5. **WeblogEntryCommentForm** - View model for comment form
6. **CommentAuthenticator** - Pluggable authentication (CAPTCHA)
7. **CommentValidationManager** - Spam detection
8. **WeblogEntryManager** - Saves comments to database
9. **IndexManager** - Updates search index
10. **CacheManager** - Invalidates page cache
11. **MailUtil** - Sends email notifications
12. **IPBanList** - Manages banned IP addresses
13. **GenericThrottle** - Rate limiting/throttling
14. **I18nMessages** - Internationalized messages
15. **RollerMessages** - Error/success message handling

---

## 4. Rendering Engine

### Classes in Rendering Engine

1. **Renderer** [Interface]
2. **VelocityRenderer** [Class] 
3. **RendererManager** [Class] 
4. **PageServlet** [Class]
5. **WeblogPageRequest** [Class] 
6. **PageModel** [Class]
7. **WeblogPageCache** [Class]
8. **Template** [Interface]

---

### 4.1 Renderer [Interface]

**Package:** `org.apache.roller.weblogger.ui.rendering`

**Description:**  
`Renderer` is an interface that any rendering engine has to implement. A renderer takes a template and some data, and produces HTML output. This keeps the rest of the code from caring about which template engine is actually being used.

**Purpose:**  
- Defines a common way to render templates
- Allows different template engines to be plugged in
- Takes a template + data model and produces HTML
- Makes it easy to swap template engines if needed

**Key Methods:**

```java
/**
 * @param template The template to render
 * @param model The data model to use during rendering
 * @return The rendered output as a String
 * @throws RenderingException if rendering fails
 */
public String render(Template template, Map<String, Object> model) throws RenderingException
```

**Interactions & Relations:**

1. **Template** - Receives template to render
2. **RendererManager** - Creates renderer instances
3. **VelocityRenderer** - Concrete Velocity implementation
4. **PageModel** - Provides model data for rendering
5. **PageServlet** - Uses renderer to generate output
6. **RenderingException** - Thrown on rendering errors

---

### 4.2 VelocityRenderer [Class]

**Package:** `org.apache.roller.weblogger.ui.rendering.velocity`

**Description:**  
`VelocityRenderer` is the class that actually renders templates using Apache Velocity. When a blog page needs to be displayed, this class takes the Velocity template (.vm file), fills in the data (blog name, entries, categories, etc.), and produces the final HTML.

**Purpose:**  
- Renders templates using the Apache Velocity engine
- Processes .vm template files and fills in data
- Sets up the Velocity context with all the model data
- Handles Velocity-specific configuration
- Supports Velocity tools, macros, and template inheritance
- Wraps Velocity errors into rendering exceptions

**Key Implementation Details:**

1. **Velocity Context** - Populates VelocityContext with model data
2. **Tool Support** - Integrates Velocity tools (UtilityBelt, UrlHelper, etc.)
3. **Template Loading** - Loads templates from database or theme
4. **Macro Support** - Supports Velocity macros and includes
5. **Error Handling** - Catches and wraps Velocity exceptions

**Key Methods:**

```java
// Implementation
@Override
public String render(Template template, Map<String, Object> model) throws RenderingException

// Velocity-specific
protected VelocityContext createContext(Map<String, Object> model)
```

**Velocity Tools Provided in Context:**

- `$url` - URL generation utilities
- `$text` - i18n message resources
- `$utilities` - General utility methods
- `$config` - Configuration properties
- `$display` - Display/formatting helpers
- Custom velocity tools configured per installation

**Interactions & Relations:**

1. **Renderer** - Implements this interface
2. **Template** - Renders Velocity templates
3. **VelocityEngine** - Uses Velocity for template processing
4. **VelocityContext** - Populates with model data
5. **PageModel** - Model data provided to templates
6. **Weblog** - Accessed from model for context
7. **RenderingException** - Wraps Velocity errors

---

### 4.3 RendererManager [Class]

**Package:** `org.apache.roller.weblogger.ui.rendering`

**Description:**  
`RendererManager` is a factory that picks the right renderer for a given template. It has a list of renderer factories and goes through them in order until one says "I can handle this template." This way, you can add new rendering engines without changing existing code.

**Purpose:**  
- Sits between the code that needs rendering and the actual renderers
- Supports pluggable rendering engines through factories
- Picks the right renderer based on the template type
- Makes it easy to add new template engines later

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `rendererFactories` | List\<RendererFactory\> | Configured renderer factories |

**Configuration Properties:**

- `rendering.userRendererFactories` - User-defined renderer factories
- `rendering.rollerRendererFactories` - Built-in Roller renderer factories

**Key Methods:**

```java
/** 
 * @param template The template to render
 * @param deviceType The device type (mobile, desktop, tablet)
 * @return A Renderer capable of rendering this template
 * @throws RenderingException if no suitable renderer found
 */
public static Renderer getRenderer(Template template, MobileDeviceRepository.DeviceType deviceType) throws RenderingException
```

**Renderer Selection Process:**

1. Iterate through configured renderer factories in order
2. Ask each factory if it can render the template
3. Return first renderer that accepts the template
4. Throw exception if no renderer found

**Typical Factory Order:**

1. **User-defined factories** (custom rendering)
2. **Velocity factory** (standard .vm templates)
3. **Fallback factory** (default renderer)

**Interactions & Relations:**

1. **Renderer** - Returns renderer instances
2. **RendererFactory** - Uses factories to create renderers
3. **Template** - Determines which renderer to use
4. **PageServlet** - Calls to get renderer
5. **VelocityRenderer** - Typically returned for Velocity templates
6. **MobileDeviceRepository** - Supports device-specific rendering
7. **WebloggerConfig** - Reads factory configuration

---

### 4.4 PageServlet [Class]

**Package:** `org.apache.roller.weblogger.ui.rendering.servlets`

**Description:**  
`PageServlet` is the main servlet that serves blog pages. When someone visits a blog URL, this servlet figures out which blog and page they want, loads the right template, gets the data, renders the page, caches it, and sends the HTML back. It handles everything from the homepage to individual entry pages to category archives.

**Purpose:**  
- Handles all HTTP requests for blog pages
- Parses blog URLs (permalinks, date archives, categories, tags)
- Loads the right template for whatever page was requested
- Builds the data model (`PageModel`) for the template
- Renders pages through `RendererManager`
- Implements page caching so the same page doesn't get re-rendered every time
- Returns 404 for pages that don't exist
- Detects mobile devices for responsive rendering
- Can also serve RSS/Atom feeds

**Key Workflow (doGet):**

1. **Parse Request:**
   - Create WeblogPageRequest from HTTP request
   - Extract weblog handle, locale, context (entry/date/category/tags/page)
   - Determine page type and parameters

2. **Load Weblog & Template:**
   - Lookup weblog by handle
   - Determine which template to use based on context
   - Load template from weblog's theme

3. **Check Cache:**
   - Generate cache key based on request parameters
   - Check WeblogPageCache for cached output
   - Return cached page if available and fresh

4. **Build Model:**
   - Create PageModel with request context
   - Populate model with weblog data, entries, categories, etc.
   - Add utility objects ($url, $text, etc.)

5. **Render Page:**
   - Get appropriate Renderer from RendererManager
   - Render template with model data
   - Generate HTML output

6. **Cache Output:**
   - Store rendered output in WeblogPageCache
   - Set cache headers (ETag, Last-Modified, Expires)

7. **Send Response:**
   - Set content type and character encoding
   - Write rendered output to response
   - Set HTTP status code

**Key Methods:**

```java
// Servlet lifecycle
@Override
public void init(ServletConfig config) throws ServletException

// HTTP request handling
@Override
public void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException

// Helper methods
protected Template getTemplate(WeblogPageRequest pageRequest)
protected PageModel buildModel(WeblogPageRequest pageRequest, HttpServletRequest request, HttpServletResponse response)
```

**Caching Strategy:**

1. **Cache Key** - Based on: weblog handle, locale, context, parameters, device type
2. **Cache Validation** - ETag and Last-Modified headers
3. **Cache Expiration** - Configurable TTL per weblog
4. **Cache Invalidation** - On content changes (new entry, comment, etc.)
5. **Conditional GET** - Supports If-None-Match and If-Modified-Since


**Interactions & Relations:**

1. **WeblogPageRequest** - Parses incoming requests
2. **Weblog** - Loads weblog for request
3. **Template** - Loads template to render
4. **PageModel** - Builds model data for rendering
5. **RendererManager** - Gets renderer for template
6. **Renderer** - Renders template with model
7. **WeblogPageCache** - Caches rendered output
8. **WeblogEntryManager** - Loads entries for display
9. **CacheManager** - Manages cache invalidation
10. **MobileDeviceRepository** - Detects mobile devices
11. **URLStrategy** - Generates URLs

---

### 4.5 WeblogPageRequest [Class]

**Package:** `org.apache.roller.weblogger.ui.rendering.util`

**Description:**  
`WeblogPageRequest` parses blog page URLs and pulls out all the information needed to serve the page. For example, from `/myblog/entry/my-first-post` it extracts the blog handle (`myblog`), the context (`entry`), and the anchor (`my-first-post`). It also lazy-loads expensive objects (like the actual `WeblogEntry`) only when they're needed.

**Purpose:**  
- Parses blog page URLs into their components
- Extracts context, anchor, date, category, tags, and page name from the URL
- Also handles old-style query parameter URLs for backward compatibility
- Lazy-loads heavy objects (entry, category, template) so they're only fetched when needed
- Validates that the URL structure is correct
- Supports multiple URL formats
- Helps the servlet figure out what content to show

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `context` | String | URL context (entry/date/category/tags/page) |
| `weblogAnchor` | String | Entry anchor (for permalinks) |
| `weblogPageName` | String | Custom page link |
| `tags` | List\<String\> | Tag list |
| `weblogEntry` | WeblogEntry | Lazy-loaded entry object |

**URL Parsing Examples:**

1. **Homepage:**
   - URL: `/myblog/`
   - context: null, websitePageHit: true

2. **Entry Permalink:**
   - URL: `/myblog/entry/my-first-post`
   - context: "entry", weblogAnchor: "my-first-post"

3. **Date Archive:**
   - URL: `/myblog/date/20260202`
   - context: "date", weblogDate: "20260202"

4. **Category Archive:**
   - URL: `/myblog/category/technology`
   - context: "category", weblogCategoryName: "technology"

5. **Tag Archive:**
   - URL: `/myblog/tags/java+velocity`
   - context: "tags", tags: ["java", "velocity"]

6. **Custom Page:**
   - URL: `/myblog/page/about`
   - context: "page", weblogPageName: "about"

**Key Methods:**

```java
// Constructor
public WeblogPageRequest(HttpServletRequest request) throws InvalidRequestException

// Accessors
public String getContext()
public String getWeblogAnchor()
public String getWeblogPageName()
public List<String> getTags()

// Lazy-loaded objects
public WeblogEntry getWeblogEntry()
public WeblogCategory getWeblogCategory()
```

**Backward Compatibility:**

Supports legacy query parameter format:
- `?entry=anchor` → weblogAnchor
- `?anchor=anchor` → weblogAnchor
- `?date=YYYYMMDD` → weblogDate
- `?cat=category` → weblogCategoryName
- `?page=N` → pageNum

**Interactions & Relations:**

1. **WeblogRequest** - Extends to inherit weblog/locale parsing
2. **HttpServletRequest** - Parses HTTP request
3. **PageServlet** - Creates request object for each page request
4. **WeblogEntry** - Lazy-loads entry by anchor
5. **ThemeTemplate** - Lazy-loads custom page template
6. **WeblogCategory** - Lazy-loads category by name
7. **WeblogEntryManager** - Used to load entry and category
8. **URLUtilities** - URL encoding/decoding
9. **InvalidRequestException** - Thrown for malformed URLs

---

### 4.6 PageModel [Class]

**Package:** `org.apache.roller.weblogger.ui.rendering.models`

**Description:**  
`PageModel` is the data object that templates use to get their content. It acts as a bridge between the database and the Velocity templates — templates call things like `$model.weblog.name` or `$model.weblogEntries` and this class does the work to fetch that data.

**Purpose:**  
- Gives templates access to all the data they need
- Exposes blog entries, categories, tags, and weblog info to the template engine
- Supports common template operations like getting recent entries or popular tags
- Keeps business logic out of templates
- Lazy-loads data so only what's actually needed gets fetched
- Caches data that gets accessed multiple times

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `weblog` | Weblog | Current weblog being rendered |
| `pageRequest` | WeblogPageRequest | Parsed request information |
| `weblogEntryManager` | WeblogEntryManager | For loading entries |

**Key Methods:**

```java
// Weblog & Entry Access
public Weblog getWeblog()
public WeblogEntry getWeblogEntry()
public List<WeblogEntry> getWeblogEntries()

// Category & Tag Access
public WeblogCategory getWeblogCategory()
public List<WeblogCategory> getWeblogCategories()
public List<TagStat> getPopularTags(int limit)

// Pagination
public boolean hasMoreEntries()
public String getNextPageUrl()
```

**Interactions & Relations:**

1. **PageServlet** - Creates PageModel for each request
2. **WeblogPageRequest** - Provides request context
3. **Weblog** - Current weblog
4. **WeblogEntry** - Loads and provides entries
5. **WeblogCategory** - Provides category data
6. **WeblogEntryManager** - Used to query entries
7. **URLStrategy** - Generates URLs
8. **Velocity templates** - Consumes model data
9. **WeblogEntrySearchCriteria** - Builds entry queries

---

### 4.7 WeblogPageCache [Class]

**Package:** `org.apache.roller.weblogger.util.cache`

**Description:**  
`WeblogPageCache` stores already-rendered HTML pages in memory. If someone visits a blog page that was recently rendered, the cache serves the saved HTML instead of re-doing all the database queries and template rendering. This makes pages load much faster.

**Purpose:**  
- Caches rendered HTML so pages don't get re-rendered every time
- Cuts down on database queries and rendering work
- Significantly improves page load times
- Clears cached pages when content changes (new post, new comment, etc.)
- Handles cache expiration (pages eventually go stale)
- Generates ETags for HTTP conditional GET requests (304 Not Modified)

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `cache` | Map\<String, CachedPage\> | In-memory cache of rendered pages |


**Cached Page Object:**

```java
class CachedPage {
    String content;        // Rendered HTML
    String contentType;    // Content type (text/html, application/xml)
    long timestamp;        // When page was cached
    String eTag;           // ETag for conditional GET
}
```

**Key Methods:**

```java
// Cache Operations
public CachedPage get(String key)
public void put(String key, CachedPage page)
public void clear()

// Cache Management
public void invalidate(Weblog weblog)
public void invalidate(WeblogEntry entry)
```

**Cache Invalidation Events:**

1. **New Entry** - Invalidate weblog homepage and archive pages
2. **Edit Entry** - Invalidate entry permalink and archive pages
3. **Delete Entry** - Invalidate entry permalink and archive pages
4. **New Comment** - Invalidate entry permalink
5. **Edit Comment** - Invalidate entry permalink
6. **Weblog Settings Change** - Invalidate entire weblog cache
7. **Theme Change** - Invalidate entire weblog cache

**Cache Expiration:**

- **Time-based** - Pages expire after configurable TTL
- **Size-based** - LRU eviction when cache full
- **Event-based** - Manual invalidation on content changes

**ETag Generation:**

```java
eTag = MD5(weblogHandle + templateId + lastModified + locale + deviceType)
```

**Interactions & Relations:**

1. **PageServlet** - Uses cache for GET requests
2. **CacheManager** - Coordinates cache invalidation
3. **Weblog** - Cache key component
4. **WeblogEntry** - Triggers cache invalidation
5. **WeblogEntryComment** - Triggers cache invalidation
6. **WeblogPageRequest** - Used to generate cache key
7. **HTTPServletResponse** - Sets cache headers (ETag, Expires)

---

### 4.8 Template [Interface]

**Package:** `org.apache.roller.weblogger.pojos`

**Description:**  
`Template` is an interface for anything that can be rendered (like a Velocity .vm file). It gives you the template's name, content, and metadata. There are two main implementations: `WeblogTemplate` (custom templates stored in the database) and `ThemeTemplate` (shared templates from a theme).

**Purpose:**  
- Provides a common interface for all template types
- Works for both custom (per-blog) and shared (theme) templates
- Gives access to template content and metadata
- Supports different template types (page, feed, stylesheet, etc.)
- Tracks when templates were last modified

**Template Types:**

- **Weblog** - Main weblog page template
- **Permalink** - Single entry page
- **Search** - Search results page
- **Custom page** - User-defined page
- **Stylesheet** - CSS stylesheet
- **Feed** - RSS/Atom feed template

**Key Methods:**

```java
// Identity & Content
public String getId()
public String getName()
public String getContents()
public void setContents(String contents)

// Metadata
public Date getLastModified()
public String getTemplateLanguage()

// Association
public Weblog getWeblog()
```

**Implementations:**

1. **WeblogTemplate** [Class]
   - Database-stored custom template
   - Owned by specific weblog
   - Can override theme template
   - Supports template editing

2. **ThemeTemplate** [Class]
   - File-based shared template
   - Part of a theme
   - Read-only
   - Reusable across weblogs

**Interactions & Relations:**

1. **Weblog** - Templates belong to weblogs
2. **Theme** - ThemeTemplate templates are part of themes
3. **Renderer** - Renders template to produce output
4. **RendererManager** - Determines which renderer to use for template
5. **PageServlet** - Loads template for request
6. **WeblogPageRequest** - Identifies which template to load
7. **PageModel** - Data provided to template during rendering

---

## Summary of Rendering Engine

**Rendering Engine** has 8 classes that handle the full pipeline from URL to HTML page:

### Workflow:

1. **Page Rendering:**
   - User requests page → PageServlet
   - Parse URL → WeblogPageRequest
   - Load template → Template
   - Check cache → WeblogPageCache
   - Build model → PageModel
   - Get renderer → RendererManager
   - Render → VelocityRenderer
   - Cache output → WeblogPageCache
   - Send response → HTTP

---

## 5. Content Fetching & Serving

### Classes in Content Fetching & Serving

1. **FeedServlet** [Class]
2. **WeblogFeedRequest** [Class]
3. **WeblogFeedCache** [Class]
4. **MediaResourceServlet** [Class]
5. **WeblogMediaResourceRequest** [Class]

---

### 5.1 FeedServlet [Class]

**Package:** `org.apache.roller.weblogger.ui.rendering.servlets`

**Description:**  
`FeedServlet` generates RSS and Atom feeds for blogs. It supports individual blog feeds and site-wide feeds that aggregate content from all blogs. It also caches feeds and supports conditional GET (304 Not Modified) so feed readers don't re-download unchanged feeds.

**Purpose:**  
- Generates RSS and Atom feeds for blog entries and comments
- Supports site-wide feeds that combine entries from all blogs
- Allows filtering feeds by category, tags, or search term
- Caches generated feeds so they don't get re-rendered for every request
- Handles conditional GET (sends 304 if nothing has changed)
- Supports styled feeds that look nice in browsers vs. raw XML for feed readers

**Feed Types:**

1. **Entry Feeds** - Main weblog entries feed
2. **Comment Feeds** - Comments feed
3. **Search Feeds** - Entry search results
4. **Category Feeds** - Filtered by category
5. **Tag Feeds** - Filtered by tags
6. **Site-wide Feeds** - Aggregated across all weblogs


**Key Workflow (doGet):**

1. **Parse Request:**
   - Create WeblogFeedRequest from HTTP request
   - Extract weblog handle, feed type, format, filters
   - Determine if site-wide or weblog-specific feed

2. **Validation:**
   - Check if weblog exists
   - Validate locale (if multi-language disabled)
   - Validate category exists (if specified)
   - Validate tags exist (if specified)
   - Return 404 for invalid requests

3. **Last Modified Check:**
   - Determine last modification time
   - Use site-wide last modified for site-wide feeds
   - Use weblog last modified for weblog feeds
   - Check If-Modified-Since header
   - Return 304 if not modified

4. **Cache Check:**
   - Generate cache key from request parameters
   - Check WeblogFeedCache or SiteWideCache
   - Return cached feed if available and fresh
   - Skip rendering if cache hit

5. **Content Rendering:**
   - Determine feed template (e.g., "weblog-entries-rss.vm")
   - Build model with feed data (entries, weblog metadata)
   - Load appropriate models (FeedModel, SearchResultsFeedModel)
   - Get renderer from RendererManager
   - Render feed template to XML

6. **Response:**
   - Set content type (RSS or Atom)
   - Set Last-Modified header
   - Write feed XML to response
   - Cache rendered feed
   - Support styled feeds for browsers


**Feed Templates:**

- `weblog-entries-rss.vm` - RSS entries template
- `weblog-entries-atom.vm` - Atom entries template
- `weblog-comments-rss.vm` - RSS comments template
- `weblog-comments-atom.vm` - Atom comments template
- `weblog-search-atom.vm` - Search results template
- `site-entries-atom.vm` - Site-wide entries template

**Key Methods:**

```java
// Servlet lifecycle
@Override
public void init(ServletConfig servletConfig) throws ServletException

// HTTP request handling
@Override
public void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException
```

**Caching Strategy:**

1. **Cache Key** - Based on: weblog, type, format, locale, category, tags, term
2. **Separate Caches** - WeblogFeedCache for weblogs, SiteWideCache for site-wide
3. **Cache Validation** - Last-Modified header for conditional GET
4. **Cache Invalidation** - On new entries, edited entries, new comments

**Styled Feeds:**

- Enabled via `site.newsfeeds.styledFeeds` configuration
- Detects browser via User-Agent header
- Serves as `text/xml` to browsers (displays in browser)
- Serves as `application/rss+xml` or `application/atom+xml` to feed readers

**Interactions & Relations:**

1. **WeblogFeedRequest** - Parses feed request URLs
2. **Weblog** - Loads weblog for feed
3. **WeblogFeedCache** - Caches weblog feeds
4. **SiteWideCache** - Caches site-wide feeds
5. **RendererManager** - Gets renderer for feed template
6. **Renderer** - Renders feed XML
7. **ModelLoader** - Loads feed models
8. **WeblogEntryManager** - Validates tags and categories
9. **ModDateHeaderUtil** - Handles conditional GET
10. **StaticTemplate** - Creates template for feed rendering

---

### 5.2 WeblogFeedRequest [Class]

**Package:** `org.apache.roller.weblogger.ui.rendering.util`

**Description:**  
`WeblogFeedRequest` parses feed URLs and extracts what kind of feed is being requested — entries or comments, RSS or Atom, filtered by category or tags, etc. It extends `WeblogRequest` so it inherits the blog handle and locale parsing.

**Purpose:**  
- Parses feed URLs into their components
- Figures out the feed type (entries or comments)
- Figures out the format (RSS or Atom)
- Extracts any filters (category, tags, search term)
- Validates that the feed URL makes sense
- Supports both path-based and query-parameter URLs

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `type` | String | Feed type ("entries" or "comments") |
| `format` | String | Feed format ("rss" or "atom") |
| `weblogCategoryName` | String | Category filter |
| `tags` | List\<String\> | Tag filters |



**Key Methods:**

```java
// Constructor
public WeblogFeedRequest(HttpServletRequest request) throws InvalidRequestException

// Accessors
public String getType()
public String getFormat()
public String getWeblogCategoryName()
public WeblogCategory getWeblogCategory()
public List<String> getTags()
```

**Feed Type Constants:**

- `entries` - Entry feed
- `comments` - Comment feed

**Feed Format Constants:**

- `rss` - RSS 2.0 format
- `atom` - Atom 1.0 format

**Interactions & Relations:**

1. **WeblogRequest** - Extends for weblog/locale parsing
2. **FeedServlet** - Creates request object
3. **WeblogCategory** - Lazy-loads category
4. **WeblogEntryManager** - Used to load category
5. **WeblogFeedCache** - Used in cache key generation
6. **InvalidRequestException** - Thrown for malformed URLs

---

### 5.3 WeblogFeedCache [Class]

**Package:** `org.apache.roller.weblogger.ui.rendering.util.cache`

**Description:**  
`WeblogFeedCache` stores rendered feed XML in memory, similar to how `WeblogPageCache` works for HTML pages. This way, when a feed reader polls a blog's RSS feed, the server can return the cached XML instead of re-generating it from scratch.

**Purpose:**  
- Caches rendered RSS/Atom XML so feeds aren't re-generated every time
- Reduces database queries and rendering work
- Makes feeds faster for subscribers who poll frequently
- Clears cached feeds when blog content changes
- Keeps feeds separated by blog
- Uses Last-Modified headers for cache validation

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `cache` | Map\<String, CachedContent\> | In-memory cache of feeds |

**Cache Key Structure:**

```
{weblogHandle}/feed/{type}/{format}/{locale}/{category}/{tags}/{term}
```

**Key Methods:**

```java
// Cache Operations
public CachedContent get(String key, long lastModified)
public void put(String key, CachedContent content)
public void clear()

// Cache Management
public void invalidate(Weblog weblog)
public void invalidate(WeblogEntry entry)

// Key Generation
public String generateKey(WeblogFeedRequest request)
```

**Cache Invalidation Events:**

1. **New Entry** - Invalidate all feeds for weblog
2. **Edit Entry** - Invalidate all feeds for weblog
3. **Delete Entry** - Invalidate all feeds for weblog
4. **New Comment** - Invalidate comment feeds for weblog
5. **Entry Status Change** - Invalidate entry feeds for weblog

**Singleton Pattern:**

```java
public static WeblogFeedCache getInstance()
```

**Interactions & Relations:**

1. **FeedServlet** - Uses cache for GET requests
2. **CacheManager** - Coordinates global cache operations
3. **Weblog** - Feeds cached per weblog
4. **WeblogEntry** - Triggers cache invalidation
5. **WeblogFeedRequest** - Used to generate cache key
6. **CachedContent** - Stores rendered feed XML

---

### 5.4 MediaResourceServlet [Class]

**Package:** `org.apache.roller.weblogger.ui.rendering.servlets`

**Description:**  
`MediaResourceServlet` serves uploaded files (images, videos, audio, documents) over HTTP. Since media files are stored outside the web app directory (for security reasons), this servlet acts as the gateway to access them through a URL.

**Purpose:**  
- Serves uploaded media files over HTTP
- Supports both full-size images and thumbnails
- Handles conditional GET (304 Not Modified) so browsers can cache files
- Sets the right content type (image/jpeg, video/mp4, etc.)
- Streams file content efficiently in chunks
- Keeps media files secure by controlling access through the servlet

**Key Workflow (doGet):**

1. **Parse Request:**
   - Create WeblogMediaResourceRequest from HTTP request
   - Extract weblog handle and resource ID
   - Determine if thumbnail or full-size requested

2. **Load Media File:**
   - Use MediaFileManager to load MediaFile by ID
   - Return 404 if file not found
   - Get last modified timestamp

3. **Conditional GET:**
   - Check If-Modified-Since header
   - Return 304 if not modified since request date
   - Set Last-Modified header

4. **Stream Content:**
   - Determine content type (from media file)
   - For thumbnails: serve PNG thumbnail
   - For full-size: serve original file
   - Stream file content to response in 8KB chunks

5. **Response:**
   - Set appropriate content type
   - Set Last-Modified header
   - Write binary content to output stream
   - Close file input stream

**Key Methods:**

```java
// Servlet lifecycle
@Override
public void init(ServletConfig config) throws ServletException

// HTTP request handling
@Override
public void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException
```



**Interactions & Relations:**

1. **WeblogMediaResourceRequest** - Parses media request URLs
2. **MediaFileManager** - Loads media file metadata
3. **MediaFile** - Provides file content and metadata
4. **Weblog** - Validates weblog context
5. **FileContentManager** - Manages file storage
6. **ModDateHeaderUtil** - Handles conditional GET
7. **HttpServletResponse** - Streams binary content

---

### 5.5 WeblogMediaResourceRequest [Class]

**Package:** `org.apache.roller.weblogger.ui.rendering.util`

**Description:**  
`WeblogMediaResourceRequest` parses media file URLs and extracts the resource ID and whether a thumbnail is being requested. It extends `WeblogRequest` for the basic blog handle parsing.

**Purpose:**  
- Parses media file request URLs
- Extracts the media file ID from the URL
- Figures out if the request is for a thumbnail or the full file
- Validates the request URL
- Controls secure access to media files

**Key Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `resourceId` | String | Media file ID |
| `thumbnail` | boolean | True if thumbnail requested |

**Key Methods:**

```java
// Constructor
public WeblogMediaResourceRequest(HttpServletRequest request) throws InvalidRequestException

// Accessors
public String getResourceId()
public boolean isThumbnail()
```

**Interactions & Relations:**

1. **WeblogRequest** - Extends for weblog parsing
2. **MediaResourceServlet** - Creates request object
3. **HttpServletRequest** - Parses HTTP request
4. **MediaFile** - Resource ID maps to media file
5. **InvalidRequestException** - Thrown for malformed URLs

---

# SUMMARY

## 1. Blog Management (6 classes)
Handles creating, configuring, and managing blogs and their lifecycle.

## 2. Entries Management (13 classes)
Handles blog post creation, editing, media file uploads, and tagging.

## 3. Comment Management (3 classes)
Handles comment submissions, moderation, and spam protection.

## 4. Rendering Engine (8 classes)
Handles template rendering, URL parsing, page caching, and generating the final HTML/XML output.

## 5. Content Fetching & Serving (5 classes)
Handles RSS/Atom feed generation and serving uploaded media files.

---

# OBSERVATIONS

## Strengths

### 1. **Clear Organization**
This subsystem divides work clearly into different parts. Blog creation is separate from entry management, which is separate from comments. Which makes the code easier to understand and change.

### 2. **Good Patterns**
- **Manager Pattern**: Uses manager classes (like `WeblogManager`, `WeblogEntryManager`) to handle all database work in one place
- **Separate Data and Display**: Keeps the data classes (like `Weblog`, `WeblogEntry`) separate from the web pages (like `PageServlet`)
- **Flexible Templates**: Uses Velocity templates so we can change how pages look without changing the code

### 3. **Performance**
- **Caching**: Saves already-rendered pages (`WeblogPageCache`) and feeds (`WeblogFeedCache`) so it doesn't have to create them over and over
- **Smart Loading**: Only loads data when needed instead of loading everything at once

### 4. **Flexible Content**
- **Tags and Categories**: Entries can be organized in multiple ways
- **Custom Attributes**: Can add extra information to entries without changing the database
- **Media Support**: Handles images, videos, and other files with tags and directories

---

## Weaknesses

### 1. **Complex Delete Operations**
When you delete a blog, the code has to manually delete entries, comments, categories, media files, etc. If someone adds a new relationship later, they might forget to update the delete code, leaving orphaned data in the database.

### 2. **Tight Dependencies**
The Rendering Engine needs to know about entries and categories, which creates connections between different parts of the subsystem. This makes changes harder because editing one part might break another.

### 3. **Old Architecture**
This application uses servlets. Current applications use REST APIs which are easier to test and maintain.

### 4. **Hard to Switch Template Engine**
The system uses Velocity for templates. Even though there's a `Renderer` interface, actually switching to a different template engine (like Thymeleaf or FreeMarker) would be very difficult.

---

## Assumptions

### 1. **Single Database**
We assumed all data is in one database. We didn't consider scenarios where blogs might be in different databases.

### 2. **Files Stored Locally**
We assumed media files are stored on the server's file system, not in cloud storage like Amazon S3 or Google Cloud.

### 3. **One Language Per Blog**
We assumed each blog has one language. We didn't model blogs that publish entries in multiple languages.

### 4. **Users Already Logged In**
We assumed users are authenticated before they reach the entry creation or blog management screens. Login/authentication is not part of this subsystem.

### 5. **Web Application**
We assumed this runs as a traditional web application on a server. We didn't consider mobile apps or microservices architecture.

---
