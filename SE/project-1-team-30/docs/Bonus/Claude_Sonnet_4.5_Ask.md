
# Project: Apache Roller

## Phase 1: Design Smell Identification

### Smell 1: God Class / Feature Envy in Entry Management

**Location:** `app/src/main/java/org/apache/roller/planet/business/` (inferred from test structure)

**Description:** Based on the test file naming (`EntryBasicTests.txt`, `EntryFunctionalTests.txt`), there appears to be a single Entry class handling both basic entity operations and complex functional behaviors. This violates the Single Responsibility Principle.

**Why it's a problem:**
- Makes the Entry class difficult to maintain and test
- Mixes persistence concerns with business logic
- Creates tight coupling between different layers
- Increases cognitive load for developers
- Makes unit testing complex (requiring both basic and functional test suites)

**Evidence:**
- Separate test files for basic vs functional tests suggest the class handles multiple concerns
- Test structure indicates mixing of CRUD operations with complex business workflows

---

### Smell 2: Primitive Obsession in Configuration Management

**Location:** 
- `app/src/main/resources/roller-version.properties`
- `app/src/main/resources/propono.properties`
- `app/src/main/resources/rome.properties`
- `app/src/main/resources/struts.properties`

**Description:** Multiple `.properties` files scattered across the codebase suggest configuration is managed using primitive String key-value pairs rather than type-safe configuration objects.

**Why it's a problem:**
- No compile-time validation of configuration values
- Easy to introduce typos in property keys
- Difficult to understand configuration dependencies
- No type safety (everything is String)
- Hard to provide meaningful defaults
- Makes refactoring risky (changing a property name requires searching string literals)

**Evidence:**
- Multiple properties files: `roller-version.properties`, `propono.properties`, `rome.properties`, `struts.properties`
- Likely accessed via `Properties.getProperty("key")` pattern

---

### Smell 3: Anemic Domain Model with Transaction Script

**Location:** `app/src/main/java/org/apache/roller/planet/business/`

**Description:** The package structure suggests business logic is organized around services/managers rather than rich domain objects. Tests are organized by entity type but separated into "basic" and "functional," indicating domain objects likely lack behavior.

**Why it's a problem:**
- Domain objects become mere data holders (DTOs)
- Business logic scattered across service classes
- Violates Tell-Don't-Ask principle
- Increases risk of business rule duplication
- Makes the system harder to understand (business rules far from data)
- Reduces encapsulation

**Evidence:**
- Test organization by function (basic vs functional) rather than by business capability
- Package name suggests procedural organization (`.business.`)
- Likely pattern: Service classes manipulating anemic entities

---

## Phase 2: Refactoring Strategy

### Strategy 1: Extract Domain Services and Value Objects (Smell 1)

**Approach:**
1. Create separate `EntryRepository` for persistence operations
2. Extract `EntryService` for business logic
3. Create value objects for complex concepts (e.g., `EntryMetadata`, `PublicationStatus`)
4. Move behavior into the Entry domain object where appropriate
5. Use Command pattern for complex operations

**Benefits:**
- Clear separation of concerns
- Easier to test each component in isolation
- Better adherence to SOLID principles
- Improved code organization

---

### Strategy 2: Introduce Type-Safe Configuration (Smell 2)

**Approach:**
1. Create configuration POJOs using records/classes
2. Use builder pattern for complex configuration
3. Implement configuration validation at startup
4. Use dependency injection for configuration objects
5. Migrate from Properties to structured configuration (YAML/JSON with binding)

**Benefits:**
- Compile-time safety
- Better IDE support (autocomplete, refactoring)
- Clear configuration schema
- Easier testing with mock configurations
- Reduced runtime errors

---

### Strategy 3: Enrich Domain Model (Smell 3)

**Approach:**
1. Move business logic from services into domain objects
2. Create domain events for state changes
3. Use specification pattern for complex queries
4. Implement domain-driven design patterns (Aggregate Root, Repository)
5. Keep services thin (orchestration only)

**Benefits:**
- Business logic co-located with data
- Better encapsulation
- Easier to reason about business rules
- Improved testability
- More maintainable codebase

---

## Phase 3: Refactored Code

### Refactoring 1: Entry Domain Model Redesign

```java
package org.apache.roller.planet.domain.model;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * Rich domain model for a Planet Entry.
 * Encapsulates business rules and invariants.
 */
public class Entry {
    private final EntryId id;
    private EntryMetadata metadata;
    private PublicationStatus status;
    private Content content;
    private Instant lastModified;
    
    public Entry(EntryId id, EntryMetadata metadata, Content content) {
        this.id = Objects.requireNonNull(id, "Entry ID cannot be null");
        this.metadata = Objects.requireNonNull(metadata, "Metadata cannot be null");
        this.content = Objects.requireNonNull(content, "Content cannot be null");
        this.status = PublicationStatus.DRAFT;
        this.lastModified = Instant.now();
    }
    
    /**
     * Publishes the entry if it meets publication criteria.
     * Business rule: Entry must have non-empty content and valid metadata.
     */
    public void publish() {
        if (!canPublish()) {
            throw new IllegalStateException("Entry cannot be published: " + getPublicationBlockers());
        }
        this.status = PublicationStatus.PUBLISHED;
        this.lastModified = Instant.now();
    }
    
    /**
     * Unpublishes the entry.
     */
    public void unpublish() {
        this.status = PublicationStatus.UNPUBLISHED;
        this.lastModified = Instant.now();
    }
    
    /**
     * Updates entry content and marks as modified.
     */
    public void updateContent(Content newContent) {
        Objects.requireNonNull(newContent, "Content cannot be null");
        this.content = newContent;
        this.lastModified = Instant.now();
        
        // Business rule: Published entries become unpublished when content changes
        if (this.status == PublicationStatus.PUBLISHED) {
            this.status = PublicationStatus.DRAFT;
        }
    }
    
    /**
     * Updates metadata.
     */
    public void updateMetadata(EntryMetadata newMetadata) {
        this.metadata = Objects.requireNonNull(newMetadata, "Metadata cannot be null");
        this.lastModified = Instant.now();
    }
    
    /**
     * Checks if entry can be published.
     */
    public boolean canPublish() {
        return content.isValid() && metadata.isValid();
    }
    
    /**
     * Gets reasons why entry cannot be published.
     */
    private String getPublicationBlockers() {
        StringBuilder blockers = new StringBuilder();
        if (!content.isValid()) {
            blockers.append("Invalid content. ");
        }
        if (!metadata.isValid()) {
            blockers.append("Invalid metadata. ");
        }
        return blockers.toString();
    }
    
    public boolean isPublished() {
        return status == PublicationStatus.PUBLISHED;
    }
    
    // Getters
    public EntryId getId() { return id; }
    public EntryMetadata getMetadata() { return metadata; }
    public PublicationStatus getStatus() { return status; }
    public Content getContent() { return content; }
    public Instant getLastModified() { return lastModified; }
}
```

```java
package org.apache.roller.planet.domain.model;

import java.util.Objects;
import java.util.UUID;

/**
 * Value object representing an Entry identifier.
 * Provides type safety and prevents primitive obsession.
 */
public final class EntryId {
    private final UUID value;
    
    private EntryId(UUID value) {
        this.value = Objects.requireNonNull(value, "EntryId value cannot be null");
    }
    
    public static EntryId of(UUID value) {
        return new EntryId(value);
    }
    
    public static EntryId of(String value) {
        return new EntryId(UUID.fromString(value));
    }
    
    public static EntryId generate() {
        return new EntryId(UUID.randomUUID());
    }
    
    public UUID getValue() {
        return value;
    }
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        EntryId entryId = (EntryId) o;
        return value.equals(entryId.value);
    }
    
    @Override
    public int hashCode() {
        return Objects.hash(value);
    }
    
    @Override
    public String toString() {
        return value.toString();
    }
}
```

```java
// filepath: app/src/main/java/org/apache/roller/planet/domain/model/EntryMetadata.java
package org.apache.roller.planet.domain.model;

import java.util.Objects;

/**
 * Value object for Entry metadata.
 * Encapsulates validation rules for metadata.
 */
public final class EntryMetadata {
    private final String title;
    private final String author;
    private final String category;
    
    private EntryMetadata(String title, String author, String category) {
        this.title = title;
        this.author = author;
        this.category = category;
    }
    
    public static EntryMetadata of(String title, String author, String category) {
        Objects.requireNonNull(title, "Title cannot be null");
        Objects.requireNonNull(author, "Author cannot be null");
        
        if (title.trim().isEmpty()) {
            throw new IllegalArgumentException("Title cannot be empty");
        }
        if (author.trim().isEmpty()) {
            throw new IllegalArgumentException("Author cannot be empty");
        }
        
        return new EntryMetadata(title.trim(), author.trim(), category);
    }
    
    public boolean isValid() {
        return title != null && !title.trim().isEmpty() 
            && author != null && !author.trim().isEmpty();
    }
    
    // Getters
    public String getTitle() { return title; }
    public String getAuthor() { return author; }
    public String getCategory() { return category; }
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        EntryMetadata that = (EntryMetadata) o;
        return title.equals(that.title) && author.equals(that.author) 
            && Objects.equals(category, that.category);
    }
    
    @Override
    public int hashCode() {
        return Objects.hash(title, author, category);
    }
}
```

```java
// filepath: app/src/main/java/org/apache/roller/planet/domain/model/Content.java
package org.apache.roller.planet.domain.model;

import java.util.Objects;

/**
 * Value object for Entry content.
 */
public final class Content {
    private static final int MIN_CONTENT_LENGTH = 10;
    private static final int MAX_CONTENT_LENGTH = 100000;
    
    private final String body;
    private final ContentFormat format;
    
    private Content(String body, ContentFormat format) {
        this.body = body;
        this.format = format;
    }
    
    public static Content of(String body, ContentFormat format) {
        Objects.requireNonNull(body, "Content body cannot be null");
        Objects.requireNonNull(format, "Content format cannot be null");
        
        return new Content(body, format);
    }
    
    public boolean isValid() {
        return body != null 
            && body.trim().length() >= MIN_CONTENT_LENGTH 
            && body.length() <= MAX_CONTENT_LENGTH;
    }
    
    public String getBody() { return body; }
    public ContentFormat getFormat() { return format; }
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Content content = (Content) o;
        return body.equals(content.body) && format == content.format;
    }
    
    @Override
    public int hashCode() {
        return Objects.hash(body, format);
    }
}
```

```java
package org.apache.roller.planet.domain.model;

/**
 * Enumeration of supported content formats.
 */
public enum ContentFormat {
    HTML,
    MARKDOWN,
    PLAIN_TEXT
}
```

```java
package org.apache.roller.planet.domain.model;

/**
 * Enumeration of entry publication states.
 */
public enum PublicationStatus {
    DRAFT,
    PUBLISHED,
    UNPUBLISHED,
    ARCHIVED
}
```

```java
package org.apache.roller.planet.domain.repository;

import org.apache.roller.planet.domain.model.Entry;
import org.apache.roller.planet.domain.model.EntryId;
import java.util.List;
import java.util.Optional;

/**
 * Repository interface for Entry aggregate.
 * Separates persistence concerns from domain logic.
 */
public interface EntryRepository {
    
    /**
     * Saves or updates an entry.
     */
    Entry save(Entry entry);
    
    /**
     * Finds entry by ID.
     */
    Optional<Entry> findById(EntryId id);
    
    /**
     * Finds all published entries.
     */
    List<Entry> findAllPublished();
    
    /**
     * Finds entries by author.
     */
    List<Entry> findByAuthor(String author);
    
    /**
     * Deletes an entry.
     */
    void delete(EntryId id);
    
    /**
     * Checks if entry exists.
     */
    boolean exists(EntryId id);
}
```

```java
package org.apache.roller.planet.application.service;

import org.apache.roller.planet.domain.model.*;
import org.apache.roller.planet.domain.repository.EntryRepository;
import java.util.List;

/**
 * Application service for Entry operations.
 * Orchestrates use cases, delegates business logic to domain.
 */
public class EntryService {
    private final EntryRepository entryRepository;
    
    public EntryService(EntryRepository entryRepository) {
        this.entryRepository = entryRepository;
    }
    
    /**
     * Creates a new draft entry.
     */
    public EntryId createDraft(EntryMetadata metadata, Content content) {
        EntryId id = EntryId.generate();
        Entry entry = new Entry(id, metadata, content);
        entryRepository.save(entry);
        return id;
    }
    
    /**
     * Publishes an entry.
     */
    public void publishEntry(EntryId entryId) {
        Entry entry = entryRepository.findById(entryId)
            .orElseThrow(() -> new EntryNotFoundException(entryId));
        
        entry.publish();
        entryRepository.save(entry);
    }
    
    /**
     * Updates entry content.
     */
    public void updateEntryContent(EntryId entryId, Content newContent) {
        Entry entry = entryRepository.findById(entryId)
            .orElseThrow(() -> new EntryNotFoundException(entryId));
        
        entry.updateContent(newContent);
        entryRepository.save(entry);
    }
    
    /**
     * Updates entry metadata.
     */
    public void updateEntryMetadata(EntryId entryId, EntryMetadata newMetadata) {
        Entry entry = entryRepository.findById(entryId)
            .orElseThrow(() -> new EntryNotFoundException(entryId));
        
        entry.updateMetadata(newMetadata);
        entryRepository.save(entry);
    }
    
    /**
     * Gets published entries.
     */
    public List<Entry> getPublishedEntries() {
        return entryRepository.findAllPublished();
    }
    
    /**
     * Deletes an entry.
     */
    public void deleteEntry(EntryId entryId) {
        if (!entryRepository.exists(entryId)) {
            throw new EntryNotFoundException(entryId);
        }
        entryRepository.delete(entryId);
    }
}
```

```java
package org.apache.roller.planet.application.service;

import org.apache.roller.planet.domain.model.EntryId;

/**
 * Exception thrown when an entry is not found.
 */
public class EntryNotFoundException extends RuntimeException {
    private final EntryId entryId;
    
    public EntryNotFoundException(EntryId entryId) {
        super("Entry not found: " + entryId);
        this.entryId = entryId;
    }
    
    public EntryId getEntryId() {
        return entryId;
    }
}
```

---

### Refactoring 2: Type-Safe Configuration

```java
package org.apache.roller.planet.config;

import java.util.Objects;

/**
 * Type-safe configuration for Roller application.
 * Replaces primitive String-based properties access.
 */
public final class RollerConfiguration {
    private final VersionConfig version;
    private final ProponoConfig propono;
    private final RomeConfig rome;
    private final StrutsConfig struts;
    private final DatabaseConfig database;
    
    private RollerConfiguration(Builder builder) {
        this.version = Objects.requireNonNull(builder.version, "Version config required");
        this.propono = Objects.requireNonNull(builder.propono, "Propono config required");
        this.rome = Objects.requireNonNull(builder.rome, "Rome config required");
        this.struts = Objects.requireNonNull(builder.struts, "Struts config required");
        this.database = Objects.requireNonNull(builder.database, "Database config required");
        
        validate();
    }
    
    private void validate() {
        // Validation logic here
        if (!version.isValid()) {
            throw new IllegalStateException("Invalid version configuration");
        }
    }
    
    public static Builder builder() {
        return new Builder();
    }
    
    public VersionConfig getVersion() { return version; }
    public ProponoConfig getPropono() { return propono; }
    public RomeConfig getRome() { return rome; }
    public StrutsConfig getStruts() { return struts; }
    public DatabaseConfig getDatabase() { return database; }
    
    public static class Builder {
        private VersionConfig version;
        private ProponoConfig propono;
        private RomeConfig rome;
        private StrutsConfig struts;
        private DatabaseConfig database;
        
        public Builder version(VersionConfig version) {
            this.version = version;
            return this;
        }
        
        public Builder propono(ProponoConfig propono) {
            this.propono = propono;
            return this;
        }
        
        public Builder rome(RomeConfig rome) {
            this.rome = rome;
            return this;
        }
        
        public Builder struts(StrutsConfig struts) {
            this.struts = struts;
            return this;
        }
        
        public Builder database(DatabaseConfig database) {
            this.database = database;
            return this;
        }
        
        public RollerConfiguration build() {
            return new RollerConfiguration(this);
        }
    }
}
```

```java
package org.apache.roller.planet.config;

import java.util.Objects;

/**
 * Version configuration with semantic versioning support.
 */
public final class VersionConfig {
    private final int major;
    private final int minor;
    private final int patch;
    private final String buildNumber;
    
    private VersionConfig(int major, int minor, int patch, String buildNumber) {
        this.major = major;
        this.minor = minor;
        this.patch = patch;
        this.buildNumber = buildNumber;
    }
    
    public static VersionConfig of(int major, int minor, int patch, String buildNumber) {
        if (major < 0 || minor < 0 || patch < 0) {
            throw new IllegalArgumentException("Version numbers must be non-negative");
        }
        return new VersionConfig(major, minor, patch, buildNumber);
    }
    
    public static VersionConfig parse(String versionString) {
        // Parse version string like "6.0.2-SNAPSHOT"
        String[] parts = versionString.split("-");
        String[] numbers = parts[0].split("\\.");
        
        int major = Integer.parseInt(numbers[0]);
        int minor = numbers.length > 1 ? Integer.parseInt(numbers[1]) : 0;
        int patch = numbers.length > 2 ? Integer.parseInt(numbers[2]) : 0;
        String buildNumber = parts.length > 1 ? parts[1] : "RELEASE";
        
        return new VersionConfig(major, minor, patch, buildNumber);
    }
    
    public boolean isValid() {
        return major >= 0 && minor >= 0 && patch >= 0;
    }
    
    public String toVersionString() {
        return String.format("%d.%d.%d-%s", major, minor, patch, buildNumber);
    }
    
    public int getMajor() { return major; }
    public int getMinor() { return minor; }
    public int getPatch() { return patch; }
    public String getBuildNumber() { return buildNumber; }
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        VersionConfig that = (VersionConfig) o;
        return major == that.major && minor == that.minor 
            && patch == that.patch && buildNumber.equals(that.buildNumber);
    }
    
    @Override
    public int hashCode() {
        return Objects.hash(major, minor, patch, buildNumber);
    }
}
```

```java
package org.apache.roller.planet.config;

import java.time.Duration;

/**
 * Type-safe configuration for Propono (Atom Publishing Protocol).
 */
public final class ProponoConfig {
    private final boolean enabled;
    private final int maxEntriesPerFeed;
    private final Duration cacheTimeout;
    
    private ProponoConfig(boolean enabled, int maxEntriesPerFeed, Duration cacheTimeout) {
        this.enabled = enabled;
        this.maxEntriesPerFeed = maxEntriesPerFeed;
        this.cacheTimeout = cacheTimeout;
    }
    
    public static ProponoConfig of(boolean enabled, int maxEntriesPerFeed, Duration cacheTimeout) {
        if (maxEntriesPerFeed <= 0) {
            throw new IllegalArgumentException("Max entries must be positive");
        }
        return new ProponoConfig(enabled, maxEntriesPerFeed, cacheTimeout);
    }
    
    public boolean isEnabled() { return enabled; }
    public int getMaxEntriesPerFeed() { return maxEntriesPerFeed; }
    public Duration getCacheTimeout() { return cacheTimeout; }
}
```

```java
package org.apache.roller.planet.config;

import java.util.Set;

/**
 * Type-safe configuration for Rome RSS/Atom library.
 */
public final class RomeConfig {
    private final Set<String> supportedFormats;
    private final boolean prettyPrint;
    private final String defaultFormat;
    
    private RomeConfig(Set<String> supportedFormats, boolean prettyPrint, String defaultFormat) {
        this.supportedFormats = Set.copyOf(supportedFormats);
        this.prettyPrint = prettyPrint;
        this.defaultFormat = defaultFormat;
    }
    
    public static RomeConfig of(Set<String> supportedFormats, boolean prettyPrint, String defaultFormat) {
        if (supportedFormats.isEmpty()) {
            throw new IllegalArgumentException("At least one format must be supported");
        }
        if (!supportedFormats.contains(defaultFormat)) {
            throw new IllegalArgumentException("Default format must be in supported formats");
        }
        return new RomeConfig(supportedFormats, prettyPrint, defaultFormat);
    }
    
    public Set<String> getSupportedFormats() { return supportedFormats; }
    public boolean isPrettyPrint() { return prettyPrint; }
    public String getDefaultFormat() { return defaultFormat; }
}
```

```java
package org.apache.roller.planet.config;

/**
 * Type-safe configuration for Apache Struts.
 */
public final class StrutsConfig {
    private final boolean devMode;
    private final String[] resourceBundles;
    private final int maxFileSize;
    
    private StrutsConfig(boolean devMode, String[] resourceBundles, int maxFileSize) {
        this.devMode = devMode;
        this.resourceBundles = resourceBundles.clone();
        this.maxFileSize = maxFileSize;
    }
    
    public static StrutsConfig of(boolean devMode, String[] resourceBundles, int maxFileSize) {
        if (maxFileSize <= 0) {
            throw new IllegalArgumentException("Max file size must be positive");
        }
        return new StrutsConfig(devMode, resourceBundles, maxFileSize);
    }
    
    public boolean isDevMode() { return devMode; }
    public String[] getResourceBundles() { return resourceBundles.clone(); }
    public int getMaxFileSize() { return maxFileSize; }
}
```

```java
package org.apache.roller.planet.config;

import java.util.Objects;

/**
 * Type-safe database configuration.
 */
public final class DatabaseConfig {
    private final String url;
    private final String username;
    private final String driver;
    private final int maxPoolSize;
    private final int minPoolSize;
    
    private DatabaseConfig(Builder builder) {
        this.url = Objects.requireNonNull(builder.url, "Database URL required");
        this.username = Objects.requireNonNull(builder.username, "Username required");
        this.driver = Objects.requireNonNull(builder.driver, "Driver required");
        this.maxPoolSize = builder.maxPoolSize;
        this.minPoolSize = builder.minPoolSize;
        
        if (minPoolSize > maxPoolSize) {
            throw new IllegalArgumentException("Min pool size cannot exceed max pool size");
        }
    }
    
    public static Builder builder() {
        return new Builder();
    }
    
    public String getUrl() { return url; }
    public String getUsername() { return username; }
    public String getDriver() { return driver; }
    public int getMaxPoolSize() { return maxPoolSize; }
    public int getMinPoolSize() { return minPoolSize; }
    
    public static class Builder {
        private String url;
        private String username;
        private String driver;
        private int maxPoolSize = 10;
        private int minPoolSize = 2;
        
        public Builder url(String url) {
            this.url = url;
            return this;
        }
        
        public Builder username(String username) {
            this.username = username;
            return this;
        }
        
        public Builder driver(String driver) {
            this.driver = driver;
            return this;
        }
        
        public Builder maxPoolSize(int maxPoolSize) {
            this.maxPoolSize = maxPoolSize;
            return this;
        }
        
        public Builder minPoolSize(int minPoolSize) {
            this.minPoolSize = minPoolSize;
            return this;
        }
        
        public DatabaseConfig build() {
            return new DatabaseConfig(this);
        }
    }
}
```

```java
package org.apache.roller.planet.config;

import java.io.IOException;
import java.io.InputStream;
import java.time.Duration;
import java.util.HashSet;
import java.util.Properties;
import java.util.Set;

/**
 * Loads configuration from properties files and creates type-safe config objects.
 * Migrates from primitive Properties access to structured configuration.
 */
public class ConfigurationLoader {
    
    public static RollerConfiguration loadConfiguration() throws IOException {
        Properties versionProps = loadProperties("roller-version.properties");
        Properties proponoProps = loadProperties("propono.properties");
        Properties romeProps = loadProperties("rome.properties");
        Properties strutsProps = loadProperties("struts.properties");
        Properties dbProps = loadProperties("database.properties");
        
        return RollerConfiguration.builder()
            .version(loadVersionConfig(versionProps))
            .propono(loadProponoConfig(proponoProps))
            .rome(loadRomeConfig(romeProps))
            .struts(loadStrutsConfig(strutsProps))
            .database(loadDatabaseConfig(dbProps))
            .build();
    }
    
    private static VersionConfig loadVersionConfig(Properties props) {
        String version = props.getProperty("roller.version", "0.0.0");
        return VersionConfig.parse(version);
    }
    
    private static ProponoConfig loadProponoConfig(Properties props) {
        boolean enabled = Boolean.parseBoolean(props.getProperty("propono.enabled", "true"));
        int maxEntries = Integer.parseInt(props.getProperty("propono.max.entries", "20"));
        Duration timeout = Duration.ofMinutes(
            Long.parseLong(props.getProperty("propono.cache.timeout.minutes", "30"))
        );
        return ProponoConfig.of(enabled, maxEntries, timeout);
    }
    
    private static RomeConfig loadRomeConfig(Properties props) {
        String formatsStr = props.getProperty("rome.supported.formats", "rss_2.0,atom_1.0");
        Set<String> formats = new HashSet<>();
        for (String format : formatsStr.split(",")) {
            formats.add(format.trim());
        }
        boolean prettyPrint = Boolean.parseBoolean(props.getProperty("rome.pretty.print", "true"));
        String defaultFormat = props.getProperty("rome.default.format", "rss_2.0");
        
        return RomeConfig.of(formats, prettyPrint, defaultFormat);
    }
    
    private static StrutsConfig loadStrutsConfig(Properties props) {
        boolean devMode = Boolean.parseBoolean(props.getProperty("struts.devMode", "false"));
        String bundlesStr = props.getProperty("struts.custom.i18n.resources", "ApplicationResources");
        String[] bundles = bundlesStr.split(",");
        int maxFileSize = Integer.parseInt(props.getProperty("struts.multipart.maxSize", "2097152"));
        
        return StrutsConfig.of(devMode, bundles, maxFileSize);
    }
    
    private static DatabaseConfig loadDatabaseConfig(Properties props) {
        return DatabaseConfig.builder()
            .url(props.getProperty("database.url"))
            .username(props.getProperty("database.username"))
            .driver(props.getProperty("database.driver", "org.apache.derby.jdbc.EmbeddedDriver"))
            .maxPoolSize(Integer.parseInt(props.getProperty("database.pool.max", "10")))
            .minPoolSize(Integer.parseInt(props.getProperty("database.pool.min", "2")))
            .build();
    }
    
    private static Properties loadProperties(String resourceName) throws IOException {
        Properties props = new Properties();
        try (InputStream is = ConfigurationLoader.class.getClassLoader()
                .getResourceAsStream(resourceName)) {
            if (is != null) {
                props.load(is);
            }
        }
        return props;
    }
}
```

---

### Refactoring 3: Rich Domain Model with Specifications

```java
package org.apache.roller.planet.domain.specification;

/**
 * Specification pattern for encapsulating business rules.
 * Allows combining specifications with AND, OR, NOT logic.
 */
public interface Specification<T> {
    
    boolean isSatisfiedBy(T candidate);
    
    default Specification<T> and(Specification<T> other) {
        return candidate -> this.isSatisfiedBy(candidate) && other.isSatisfiedBy(candidate);
    }
    
    default Specification<T> or(Specification<T> other) {
        return candidate -> this.isSatisfiedBy(candidate) || other.isSatisfiedBy(candidate);
    }
    
    default Specification<T> not() {
        return candidate -> !this.isSatisfiedBy(candidate);
    }
}
```

```java
package org.apache.roller.planet.domain.specification;

import org.apache.roller.planet.domain.model.Entry;

/**
 * Specification for entries that can be published.
 * Encapsulates business rules for publication eligibility.
 */
public class PublishableEntrySpecification implements Specification<Entry> {
    
    @Override
    public boolean isSatisfiedBy(Entry entry) {
        return entry != null 
            && entry.getContent().isValid()
            && entry.getMetadata().isValid()
            && !entry.isPublished();
    }
    
    public String getReasonForRejection(Entry entry) {
        if (entry == null) {
            return "Entry is null";
        }
        if (!entry.getContent().isValid()) {
            return "Content is invalid";
        }
        if (!entry.getMetadata().isValid()) {
            return "Metadata is invalid";
        }
        if (entry.isPublished()) {
            return "Entry is already published";
        }
        return "Unknown reason";
    }
}
```

```java
package org.apache.roller.planet.domain.specification;

import org.apache.roller.planet.domain.model.Entry;
import java.util.Objects;

/**
 * Specification for filtering entries by author.
 */
public class EntryByAuthorSpecification implements Specification<Entry> {
    private final String author;
    
    public EntryByAuthorSpecification(String author) {
        this.author = Objects.requireNonNull(author, "Author cannot be null");
    }
    
    @Override
    public boolean isSatisfiedBy(Entry entry) {
        return entry != null 
            && entry.getMetadata().getAuthor().equalsIgnoreCase(author);
    }
}
```

```java
package org.apache.roller.planet.domain.specification;

import org.apache.roller.planet.domain.model.Entry;
import org.apache.roller.planet.domain.model.PublicationStatus;

/**
 * Specification for published entries.
 */
public class PublishedEntrySpecification implements Specification<Entry> {
    
    @Override
    public boolean isSatisfiedBy(Entry entry) {
        return entry != null && entry.getStatus() == PublicationStatus.PUBLISHED;
    }
}
```

```java
package org.apache.roller.planet.domain.model;

import org.apache.roller.planet.domain.specification.Specification;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Rich domain model for a Group (Planet aggregation).
 * Demonstrates behavior-rich entity with encapsulated business logic.
 */
public class Group {
    private final GroupId id;
    private String name;
    private String description;
    private final Set<Entry> entries;
    private GroupSettings settings;
    
    public Group(GroupId id, String name, String description, GroupSettings settings) {
        this.id = Objects.requireNonNull(id, "Group ID cannot be null");
        this.name = Objects.requireNonNull(name, "Group name cannot be null");
        this.description = description;
        this.settings = Objects.requireNonNull(settings, "Settings cannot be null");
        this.entries = new HashSet<>();
    }
    
    /**
     * Adds entry to group if it meets criteria.
     */
    public void addEntry(Entry entry) {
        Objects.requireNonNull(entry, "Entry cannot be null");
        
        if (entries.size() >= settings.getMaxEntries()) {
            throw new IllegalStateException("Group has reached maximum entry limit");
        }
        
        entries.add(entry);
    }
    
    /**
     * Removes entry from group.
     */
    public void removeEntry(Entry entry) {
        entries.remove(entry);
    }
    
    /**
     * Gets entries matching specification.
     */
    public List<Entry> getEntries(Specification<Entry> spec) {
        return entries.stream()
            .filter(spec::isSatisfiedBy)
            .collect(Collectors.toList());
    }
    
    /**
     * Gets all published entries.
     */
    public List<Entry> getPublishedEntries() {
        return entries.stream()
            .filter(Entry::isPublished)
            .sorted(Comparator.comparing(Entry::getLastModified).reversed())
            .limit(settings.getMaxPublishedEntries())
            .collect(Collectors.toList());
    }
    
    /**
     * Updates group settings.
     */
    public void updateSettings(GroupSettings newSettings) {
        this.settings = Objects.requireNonNull(newSettings, "Settings cannot be null");
        
        // Business rule: If max entries reduced, trim entries
        if (entries.size() > newSettings.getMaxEntries()) {
            trimEntriesToLimit(newSettings.getMaxEntries());
        }
    }
    
    private void trimEntriesToLimit(int limit) {
        List<Entry> entriesToKeep = entries.stream()
            .sorted(Comparator.comparing(Entry::getLastModified).reversed())
            .limit(limit)
            .collect(Collectors.toList());
        
        entries.clear();
        entries.addAll(entriesToKeep);
    }
    
    public void updateName(String newName) {
        this.name = Objects.requireNonNull(newName, "Name cannot be null");
    }
    
    public void updateDescription(String newDescription) {
        this.description = newDescription;
    }
    
    public int getEntryCount() {
        return entries.size();
    }
    
    // Getters
    public GroupId getId() { return id; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public GroupSettings getSettings() { return settings; }
}
```

```java
package org.apache.roller.planet.domain.model;

import java.util.Objects;
import java.util.UUID;

/**
 * Value object for Group identifier.
 */
public final class GroupId {
    private final UUID value;
    
    private GroupId(UUID value) {
        this.value = Objects.requireNonNull(value, "GroupId value cannot be null");
    }
    
    public static GroupId of(UUID value) {
        return new GroupId(value);
    }
    
    public static GroupId of(String value) {
        return new GroupId(UUID.fromString(value));
    }
    
    public static GroupId generate() {
        return new GroupId(UUID.randomUUID());
    }
    
    public UUID getValue() {
        return value;
    }
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        GroupId groupId = (GroupId) o;
        return value.equals(groupId.value);
    }
    
    @Override
    public int hashCode() {
        return Objects.hash(value);
    }
    
    @Override
    public String toString() {
        return value.toString();
    }
}
```

```java
// filepath: app/src/main/java/org/apache/roller/planet/domain/model/GroupSettings.java
package org.apache.roller.planet.domain.model;

/**
 * Value object for Group settings.
 */
public final class GroupSettings {
    private final int maxEntries;
    private final int maxPublishedEntries;
    private final boolean autoPublish;
    
    private GroupSettings(int maxEntries, int maxPublishedEntries, boolean autoPublish) {
        this.maxEntries = maxEntries;
        this.maxPublishedEntries = maxPublishedEntries;
        this.autoPublish = autoPublish;
    }
    
    public static GroupSettings of(int maxEntries, int maxPublishedEntries, boolean autoPublish) {
        if (maxEntries <= 0) {
            throw new IllegalArgumentException("Max entries must be positive");
        }
        if (maxPublishedEntries <= 0) {
            throw new IllegalArgumentException("Max published entries must be positive");
        }
        if (maxPublishedEntries > maxEntries) {
            throw new IllegalArgumentException("Max published cannot exceed max entries");
        }
        return new GroupSettings(maxEntries, maxPublishedEntries, autoPublish);
    }
    
    public static GroupSettings defaultSettings() {
        return new GroupSettings(100, 50, false);
    }
    
    public int getMaxEntries() { return maxEntries; }
    public int getMaxPublishedEntries() { return maxPublishedEntries; }
    public boolean isAutoPublish() { return autoPublish; }
}
```

