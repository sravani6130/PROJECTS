

# Apache Roller Refactoring Analysis

## Phase 1: Analysis (Design Smell Identification)

### Smell 1: Primitive Obsession & Leaky Logic in File Validation
*   **Location**: `roller/app/src/main/java/org/apache/roller/weblogger/business/FileContentManagerImpl.java` (Method: `checkFileType`, lines ~286-350)
*   **Description**: The application manages file upload security (allowed/forbidden files) using raw `String[]` arrays. The logic to distinguish between a "file extension" rule and a "content-type" rule relies on checking for the presence of a slash (`/`) character inside the `checkFileType` method.
*   **Why it’s a problem**:
    *   **Brittle Logic**: Hardcoding `indexOf('/')` to distinguish types is error-prone.
    *   **Low Cohesion**: The `FileContentManagerImpl` is burdened with parsing rule syntax instead of just applying policies.
    *   **Duplication**: The loop logic for checking allows and forbids is nearly identical but repeated.

### Smell 2: Anemic Domain Model / Feature Envy in Media Management
*   **Location**: `roller/app/src/main/java/org/apache/roller/weblogger/pojos/MediaFileDirectory.java` and `roller/app/src/main/java/org/apache/roller/weblogger/business/MediaFileTest.java` (and potential managers)
*   **Description**: `MediaFileDirectory` is largely a data bucket (getter/setter). While it has `hasMediaFile` and `getMediaFile`, complex operations like moving files or validating uniqueness often leak into Service/Manager layers (e.g., `MediaFileManagerImpl` or tests like `testMoveDirectoryContents`).
*   **Why it’s a problem**:
    *   **Encapsulation Violation**: The internal `Set<MediaFile>` is exposed via getters/setters, allowing external classes to manipulate the collection state directly (or necessitating external managers to do heavy lifting).
    *   **Maintenance**: Logic regarding directory invariants (e.g., "cannot contain two files with the same name") is scattered.

### Smell 3: God Class / UI Coupling in Struts Actions
*   **Location**: `roller/app/src/main/java/org/apache/roller/weblogger/ui/struts2/editor/MediaFileAdd.java`
*   **Description**: This class handles UI request binding (setters for `uploadedFiles`), validation logic (`myValidate`), business delegation (`save`), and view preparation.
*   **Why it’s a problem**:
    *   **SRP Violation**: It mixes HTTP concern handling (Struts) with business validation logic (e.g., checking quotes/enabled status).
    *   **Hard to Test**: Testing `myValidate` requires setting up the specific Struts action state.

---

## Phase 2: Refactoring Plan

### Strategy 1: Introduce Value Objects for File Rules
Instead of passing `String[]` arrays and parsing them on the fly, we will introduce a `FileRule` interface with implementations `ExtensionRule` and `ContentTypeRule`.
1.  Create `FileRule` interface.
2.  Implement `ExtensionRule` and `ContentTypeRule`.
3.  Refactor `FileContentManagerImpl` to parse strings into these objects *once* (or receive them as objects) and iterate over them polymorphically.

### Strategy 2: Enrich MediaFileDirectory Domain Model
Move logic *into* the entity.
1.  Encapsulate the `mediaFiles` set in `MediaFileDirectory`.
2.  Add business methods like `addFile(MediaFile)` and `removeFile(MediaFile)` that enforce invariants (uniqueness).
3.  Deprecate direct access to the raw set for modification purposes.

### Strategy 3: Extract Validation Logic
Separate validation from the Struts Action.
1.  Extract the validation logic found in `MediaFileAdd.myValidate()` into a dedicated `MediaUploadValidator` class.
2.  Inject this validator into the Action.

---

## Phase 3: Refactored Code

### Refactoring 1: Primitive Obsession (File Rules)

**New Interface and Implementations:**

```java
// filepath: roller/app/src/main/java/org/apache/roller/weblogger/business/validation/FileRule.java
package org.apache.roller.weblogger.business.validation;

/**
 * Strategy interface for file acceptance rules.
 */
public interface FileRule {
    boolean matches(String fileName, String contentType);
}

// filepath: roller/app/src/main/java/org/apache/roller/weblogger/business/validation/ContentTypeRule.java
package org.apache.roller.weblogger.business.validation;

public class ContentTypeRule implements FileRule {
    private final String rule;

    public ContentTypeRule(String rule) {
        this.rule = rule;
    }

    @Override
    public boolean matches(String fileName, String contentType) {
        if (contentType == null) return false;
        
        if (rule.equals("*/*")) return true;
        if (rule.equals(contentType)) return true;
        
        String[] ruleParts = rule.split("/");
        String[] typeParts = contentType.split("/");
        
        return ruleParts.length == 2 && typeParts.length == 2 &&
               ruleParts[0].equals(typeParts[0]) && 
               ruleParts[1].equals("*");
    }
}

// filepath: roller/app/src/main/java/org/apache/roller/weblogger/business/validation/ExtensionRule.java
package org.apache.roller.weblogger.business.validation;

public class ExtensionRule implements FileRule {
    private final String extension;

    public ExtensionRule(String extension) {
        this.extension = extension.toLowerCase();
    }

    @Override
    public boolean matches(String fileName, String contentType) {
        return fileName != null && fileName.toLowerCase().endsWith(extension);
    }
}
```

**Refactored FileContentManagerImpl.java:**

```java
// filepath: roller/app/src/main/java/org/apache/roller/weblogger/business/FileContentManagerImpl.java
package org.apache.roller.weblogger.business;

import org.apache.roller.weblogger.business.validation.FileRule;
import org.apache.roller.weblogger.business.validation.ExtensionRule;
import org.apache.roller.weblogger.business.validation.ContentTypeRule;
import java.util.ArrayList;
import java.util.List;

// ... existing imports ...

public class FileContentManagerImpl implements FileContentManager {

    // ... existing fields ...

    /**
     * Return true if file is allowed to be uploaded given specified allowed and
     * forbidden file types.
     */
    private boolean checkFileType(String[] allowFiles, String[] forbidFiles,
            String fileName, String contentType) {

        // Default deny if specific rules exist, otherwise allow
        boolean allowFile = (allowFiles == null || allowFiles.length < 1);

        // Check ALLOW rules
        if (allowFiles != null && allowFiles.length > 0) {
            List<FileRule> allowRules = parseRules(allowFiles);
            for (FileRule rule : allowRules) {
                if (rule.matches(fileName, contentType)) {
                    allowFile = true;
                    break;
                }
            }
        }

        // Check FORBID rules (Override)
        if (forbidFiles != null && forbidFiles.length > 0) {
            List<FileRule> forbidRules = parseRules(forbidFiles);
            for (FileRule rule : forbidRules) {
                if (rule.matches(fileName, contentType)) {
                    allowFile = false;
                    break;
                }
            }
        }

        return allowFile;
    }

    private List<FileRule> parseRules(String[] rules) {
        List<FileRule> parsedRules = new ArrayList<>();
        for (String ruleStr : rules) {
            if (ruleStr == null || ruleStr.trim().isEmpty()) continue;
            
            if (ruleStr.indexOf('/') != -1) {
                parsedRules.add(new ContentTypeRule(ruleStr));
            } else {
                parsedRules.add(new ExtensionRule(ruleStr));
            }
        }
        return parsedRules;
    }
    
    // ... existing code ...
}
```

### Refactoring 2: Enrich Domain Model (MediaFileDirectory)

```java
// filepath: roller/app/src/main/java/org/apache/roller/weblogger/pojos/MediaFileDirectory.java
package org.apache.roller.weblogger.pojos;

import java.util.HashSet;
import java.util.Set;
import org.apache.roller.weblogger.WebloggerException;

// ... imports ...

public class MediaFileDirectory {
    
    private String id;
    private String name;
    private String description;
    private Weblog weblog;
    private Set<MediaFile> mediaFiles = new HashSet<>();

    // ... existing getters ...

    /**
     * Rich domain method to add a file. Enforces invariants.
     */
    public void addMediaFile(MediaFile file) throws IllegalArgumentException {
        if (file == null) {
            throw new IllegalArgumentException("MediaFile cannot be null");
        }
        if (this.hasMediaFile(file.getName())) {
            throw new IllegalArgumentException("Directory already contains file with name: " + file.getName());
        }
        
        file.setDirectory(this);
        this.mediaFiles.add(file);
    }

    /**
     * Rich domain method to move a file from this directory to another.
     */
    public void moveFileTo(MediaFile file, MediaFileDirectory targetDirectory) {
        if (!this.mediaFiles.contains(file)) {
             throw new IllegalArgumentException("File does not belong to this directory");
        }
        if (targetDirectory.hasMediaFile(file.getName())) {
             throw new IllegalArgumentException("Target directory already has a file with this name");
        }

        this.mediaFiles.remove(file);
        targetDirectory.addMediaFile(file);
    }

    // Existing helper, now cleaner because we trust our set state
    public boolean hasMediaFile(String name) {
        if (this.mediaFiles == null || name == null) {
            return false;
        }
        for (MediaFile mediaFile : this.mediaFiles) {
            if (name.equals(mediaFile.getName())) {
                return true;
            }
        }
        return false;
    }

    // Encapsulate the set (Hibernate might need the setter, but we validte access elsewhere)
    protected void setMediaFiles(Set<MediaFile> mediaFiles) {
        this.mediaFiles = mediaFiles;
    }
    
    public Set<MediaFile> getMediaFiles() {
        return mediaFiles;
    }
}
```

### Refactoring 3: Extract Validation (MediaFileAdd)

**New Validator Class:**

```java
// filepath: roller/app/src/main/java/org/apache/roller/weblogger/ui/struts2/editor/MediaUploadValidator.java
package org.apache.roller.weblogger.ui.struts2.editor;

import org.apache.roller.weblogger.config.WebloggerRuntimeConfig;
import java.util.ArrayList;
import java.util.List;

public class MediaUploadValidator {

    public List<String> validateUploadVisibility() {
        List<String> errors = new ArrayList<>();
        if (!WebloggerRuntimeConfig.getBooleanProperty("uploads.enabled")) {
            errors.add("error.upload.disabled");
        }
        // Add User Quota check logic here
        return errors;
    }
}
```

**Refactored MediaFileAdd.java:**

```java
// filepath: roller/app/src/main/java/org/apache/roller/weblogger/ui/struts2/editor/MediaFileAdd.java
package org.apache.roller.weblogger.ui.struts2.editor;

import java.io.File;
import java.util.List;
import org.apache.roller.weblogger.pojos.MediaFile;
import org.apache.roller.weblogger.pojos.MediaFileDirectory;
import org.apache.roller.weblogger.util.RollerMessages;

// ... existing imports ...

@SuppressWarnings("serial")
public class MediaFileAdd extends MediaFileBase {

    private final MediaUploadValidator validator = new MediaUploadValidator();

    // ... existing fields ...

    /**
     * Validates media file to be added.
     */
    public void myValidate() {
        List<String> validationErrors = validator.validateUploadVisibility();
        
        for (String errorKey : validationErrors) {
            addError(errorKey);
        }
    }
    
    // ... existing execute/save methods ...
    
    // ... getters and setters ...
}
```
