# Task 2A - Design Smells

## Weblog and Content Subsystem:

**Modularization Smell – Insufficient Modularization** :
- Evidence from UML :
  - Manager implementation such as:
    - `JPAWeblogManagerImpl`
    - `JPAWeblogEntryManagerImpl`
    - `JPAMediaFileManagerImpl`
  - are responsible for:
    - Bussiness logic(weblog, entry and media file management)
    - Persistence cooerdination(`JPAPersistenceStrategy`)
  - These classes manage multiple domain entities simuntaneously, such as:
    - `Weblog`,`WeblogCategory` and `WeblogEntry`
    - `WeblogEntryComment`
    - `MediaFile` and `MediaFileDirectory`
  - The UML shows that bussiness logic and persistence concerns are packed into a same manager class, instead of being modularized into a smaller,focused components.

- Evidence from Tools :
  - SonarQube :
    - sonarqube reports size and complexity related smells in manager implementation, indicating responsibility concentration.
    - Exact SonarQube Code Smell Evidence :
  
    JPAWeblogEntryManagerImpl
    ```
    Rule       : java:S3776
    Severity   : CRITICAL
    Component  : app/src/main/java/org/apache/roller/weblogger/business/jpa/JPAWeblogEntryManagerImpl.java
    Message    : Refactor this method to reduce its Cognitive Complexity from 18 to the 15 allowed.
    ```

    JPAWeblogManagerImpl

    ```
    Rule       : java:S3776
    Severity   : CRITICAL
    Component  : app/src/main/java/org/apache/roller/weblogger/business/jpa/JPAWeblogManagerImpl.java
    Message    : Refactor this method to reduce its Cognitive Complexity from 21 to the 15 allowed.
    ```

  - Designite :
    - Designite flags manager classes in the weblog and content subsystem with excessive responsibilities 
    - Exact Designite Evidence :

    JPAWeblogManagerImpl
    ```
    Smell Type : Insufficient Modularization
    Package    : org.apache.roller.weblogger.business.jpa
    Class      : JPAWeblogManagerImpl
    Description:
    The tool detected the smell in this class because it has too many responsibilities
    and exhibits low cohesion.

    ```

    JPAWeblogEntryManagerImpl
    ```
    Smell Type : Insufficient Modularization
    Package    : org.apache.roller.weblogger.business.jpa
    Class      : JPAWeblogEntryManagerImpl
    Description:
    The tool detected the smell in this class because it has too many responsibilities
    and exhibits low cohesion.
    ```

---

**Hierarchy Smell – Missing Hierarchy** :
- Evidence from UML :
  - The UML shows that core manager classes such as:
    - `WeblogManager`
    - `WeblogEntryManager`
    - `MediaFileManager`
    encapsulate multiple behavior variants related to :
    - content retrieval
    - content processing
    - content rendering
    - Media handling
  - These variations are handled within single manager classes, rather than being modeled as separate subclasses.
  - The UML does not define any inheritance or interface hirerarchy to represent different:
    - Content processing strategies
    - Rendering behaviors
    - Media handling behaviors
  
- Evidence from Tools :
  - SonarQube :
    - High cognitive complexity in manager methods indicates a branch heavy logic, a common indication of missing hierarchy
    - Exact SonarQube Code Smell Evidence :
  
    JPAWeblogManagerImpl
    ```
    Rule      : java:S3776
    Severity  : CRITICAL
    Component : app/src/main/java/org/apache/roller/weblogger/business/jpa/JPAWeblogManagerImpl.java
    Message   : Refactor this method to reduce its Cognitive Complexity from 21 to the 15 allowed.
    ```

    JPAWeblogEntryManagerImpl
    ```
    Rule      : java:S3776
    Severity  : CRITICAL
    Component : app/src/main/java/org/apache/roller/weblogger/business/jpa/JPAWeblogEntryManagerImpl.java
    Message   : Refactor this method to reduce its Cognitive Complexity from 18 to the 15 allowed.
    ```


## User and Role Management Subsystem :

**Modularization Smell – Insufficient Modularization** :
- Evidence from UML :
  - `UserManager` is responsible for:
    - User CRUD operations
    - Role assignment and management
    - Weblog permission management
    - Permission checking
    - User queries,filters and paging
  - `JPAUserManagerImpl` is responsible for:
    - `User`
    - `UserRole`
    - `WeblogPermission`
    - `JPAPersistenceStrategy`
  - This results in  multiple unrelated responsibilities being packed in a single service abstraction.
  
- Evidence from Tools :
  - Designite :
    - Designite flags a large class with excessive responsibilities
    - Exact Designite Evidence :
    
    UserManager
    ```
    Smell Type : Insufficient Modularization
    Package    : org.apache.roller.weblogger.business
    Class      : UserManager
    Description:
    The tool detected the smell in this class because it has too many responsibilities
    and exhibits low cohesion.
    ```

    JPAUserManagerImpl
    ```
    Smell Type : Insufficient Modularization
    Package    : org.apache.roller.weblogger.business.jpa
    Class      : JPAUserManagerImpl
    Description:
    The tool detected the smell in this class because it has too many responsibilities
    and exhibits low cohesion.
    ```


---

**Abstraction Smell – Missing Abstraction** : 
- Evidence from UML :
  - The UML shows that distinct domain concepts related to user management are not modeled as separate abstractions:
    - User lifecycle management
    - Role management
    - Permission evaluation
    - Weblog membership handling
  - No explicit abstractions exist to represent these concepts individually

- Evidence from Tools :
  - Designite :
    - Designite reports that a single abstraction encapsulates multiple unrelated responsibilities, indicating a missing abstraction boundaries in the design
    - Exact Designite Evidence :
    
    ```
    Smell Type : Missing Abstraction
    Package    : org.apache.roller.weblogger.business
    Class      : UserManager
    Description:
    One abstraction performs multiple unrelated responsibilities, indicating that
    important domain concepts are not modeled as separate abstractions.
    ```

---

## Search and Indexing Subsystem :

**Modularization Smell – Insufficient Modularization** :
- Evidence from UML : 
  - `LuceneIndexManager` is responsible for:
    - Index lifecycle management
    - Search execution
    - Index consistency handling
    - Concurrency control 
    - Creation and scheduling of IndexOperations
    - Lucene configuration and access

- Evidence from Tools :
  - SonarQube :
    - sonarqube reports multiple CRITICAL cognitive complexity and responsibility overload issues in manager class
    - Exact SonarQube Code Smell Evidence : 
    
    Lucene / Search-related managers
    ```
    Rule       : java:S3776
    Severity   : CRITICAL
    Component  : app/src/main/java/org/apache/roller/weblogger/business/search/lucene/RebuildWebsiteIndexOperation.java
    Message    : Refactor this method to reduce its Cognitive Complexity from 17 to the 15 allowed.
    ```

    ```
    Rule      : java:S3776
    Severity  : CRITICAL
    Component : app/src/main/java/org/apache/roller/weblogger/business/search/lucene/IndexOperation.java
    Message   : Refactor this method to reduce its Cognitive Complexity from 18 to the 15 allowed.
    ```



---

**Abstraction Smell – Imperative Abstraction** :
- Evidence from UML : 
  - Multiple classes exist solely to perform a single action:
    - `AddEntryOperation`
    - `RemoveEntryOperation`
    - `ReIndexEntryOperation`
    - `RebuildWebsiteIndexOperation`
  - Each class primarily implements a single `doRun()` method, while the actual data resides in WeblogEntry or Weblog

- Evidence from Tools :
  - Designite :
    - Designite flags these low cohesion abstractions with minimal behavioural identity
    - Exact Designite Evidence :
    
    AddEntryOperation
    ```
    Smell Type : Imperative Abstraction
    Package    : org.apache.roller.planet.business.operations
    Class      : AddEntryOperation
    Description:
    The abstraction represents a single operation rather than a meaningful domain
    concept.
    ```

    RemoveEntryOperation
    ```
    Smell Type : Imperative Abstraction
    Package    : org.apache.roller.planet.business.operations
    Class      : RemoveEntryOperation
    Description:
    The abstraction represents a single operation rather than a meaningful domain
    concept.
    ```
    
---

**Encapsulation Smell – Leaky Encapsulation** :
- Evidence from UML :
  - `LuceneIndexManager` exposes internal implementation details via:
    - `getReadWriteLock()`
    - `getSharedIndexReader()`
    - `getIndexDirectory()`
  - Clients can directly access Lucene internals and concurency mechanisms

- Evidence from Tools :
  - Designite :
    - Designite identifies encapsulation violations where internal state is exposed.
    - Exact Designite Evidence :
    
    LuceneIndexManager
    ```
    Smell Type : Deficient Encapsulation
    Package    : org.apache.roller.planet.business
    Class      : LuceneIndexManager
    Description:
    The tool detected the smell because internal state is exposed, increasing coupling
    between this class and its clients.
    ```
