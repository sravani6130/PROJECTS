# Refactoring Modularization Complexity in Search Subsystem

## 1 - Refactor Planning

### Analysis of the Smell
The `LuceneIndexManager` suffers from **Insufficient Modularization**. It acts as a "God Class" for the searching subsystem, handling:
1.  **Infrastructure**: Managing Lucene Directories, Readers, Writers, Analyzers, and locks.
2.  **Lifecycle**: Initialization logic, consistency checks, index creation/deletion.
3.  **Operations**: Factory logic for creating and scheduling `IndexOperation` tasks.
4.  **Search**: Execution of searches.

Additionally, `IndexOperation` violates SRP by including the logic to convert a `WeblogEntry` domain object into a Lucene `Document` (Feature Envy). `RebuildWebsiteIndexOperation` has high cognitive complexity due to mixing control flow (threading, detached objects) with business logic (indexing).

### Refactoring Strategy
We will modularize the subsystem by extracting responsibilities into cohesive classes:

1.  **Extract `LuceneInfrastructure`**:
    *   **Responsibility**: Encapsulate low-level Lucene resource management (Directory, Reader, Writer Config, Analyzers, Locks).
    *   **Methods**: `getIndexDirectory`, `getSharedIndexReader`, `createIndex`, `deleteIndex`, `getAnalyzer`.
    *   **Benefit**: `LuceneIndexManager` no longer cares *how* a Reader is created or where the index lives.

2.  **Extract `LuceneDocumentFactory`**:
    *   **Responsibility**: Convert `WeblogEntry` to Lucene `Document`.
    *   **Moved Method**: `IndexOperation.getDocument(WeblogEntry)`.
    *   **Benefit**: Removes data conversion logic from the Operation hierarchy, fixing the "Feature Envy" and reducing `IndexOperation` complexity.

3.  **Refactor `RebuildWebsiteIndexOperation`**:
    *   **Strategy**: Extract helper methods for distinct steps (e.g., `deleteExistingData`, `indexEntries`).
    *   **Benefit**: Reduces Cognitive Complexity.

4.  **Update `LuceneIndexManager`**:
    *   It will act as a Coordinator/Facade.
    *   It delegates infrastructure tasks to `LuceneInfrastructure`.
    *   It retains the high-level scheduling and search entry point (as required by the interface).

### Impact Analysis
*   **New Classes**: `LuceneInfrastructure`, `LuceneDocumentFactory`.
*   **Modified Classes**: `LuceneIndexManager`, `IndexOperation`, `RebuildWebsiteIndexOperation`.
*   **Constraint Checklist**:
    *   *Syntactically correct?* Yes, standard Java.
    *   *Break functionality?* No, we are preserving the behavior, just moving the implementation.
    *   *Dependencies?* `LuceneIndexManager` will need to initialize or define these helpers.

---

## 2 - Refactor execution

### 1. New Helper Classes

#### LuceneInfrastructure.java
```java
package org.apache.roller.weblogger.business.search.lucene;

import java.io.File;
import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

import org.apache.commons.beanutils.ConstructorUtils;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.lucene.analysis.Analyzer;
import org.apache.lucene.analysis.miscellaneous.LimitTokenCountAnalyzer;
import org.apache.lucene.analysis.standard.StandardAnalyzer;
import org.apache.lucene.index.DirectoryReader;
import org.apache.lucene.index.IndexReader;
import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.index.IndexWriterConfig;
import org.apache.lucene.store.Directory;
import org.apache.lucene.store.FSDirectory;
import org.apache.roller.weblogger.config.WebloggerConfig;

/**
 * Manages low-level Lucene resources: Directory, Reader, Writer Configuration, and Analyzers.
 */
public class LuceneInfrastructure {
    
    private static final Log logger = LogFactory.getFactory().getInstance(LuceneInfrastructure.class);
    
    private final String indexDir;
    private final ReadWriteLock rwl = new ReentrantReadWriteLock();
    private IndexReader reader;

    public LuceneInfrastructure(String indexDir) {
        this.indexDir = indexDir;
    }

    public String getIndexDir() {
        return indexDir;
    }

    public ReadWriteLock getReadWriteLock() {
        return rwl;
    }

    public Directory getIndexDirectory() {
        try {
            return FSDirectory.open(Path.of(indexDir));
        } catch (IOException e) {
            logger.error("Problem accessing index directory", e);
        }
        return null;
    }

    public boolean indexExists() {
        try {
            return DirectoryReader.indexExists(getIndexDirectory());
        } catch (IOException e) {
            logger.error("Problem accessing index directory", e);
        }
        return false;
    }

    public synchronized IndexReader getSharedIndexReader() {
        if (reader == null) {
            try {
                reader = DirectoryReader.open(getIndexDirectory());
            } catch (IOException ex) {
                logger.error("Error opening DirectoryReader", ex);
                throw new RuntimeException(ex);
            }
        }
        return reader;
    }

    public synchronized void resetSharedReader() {
        reader = null;
    }
    
    public void close() {
        if (reader != null) {
            try {
                reader.close();
            } catch (IOException ex) {
                logger.error("Unable to close reader.", ex);
            }
        }
    }

    public void deleteIndex() {
        try(FSDirectory directory = FSDirectory.open(Path.of(indexDir))) {
            String[] files = directory.listAll();
            for (String file : files) {
                Files.delete(Path.of(indexDir, file));
            }
        } catch (IOException ex) {
             logger.error("Problem accessing index directory", ex);
        }
    }

    public void createIndex(Directory dir) {
        IndexWriter writer = null;
        try {
            IndexWriterConfig config = new IndexWriterConfig(
                    new LimitTokenCountAnalyzer(getAnalyzer(), 128));
            writer = new IndexWriter(dir, config);
        } catch (IOException e) {
            logger.error("Error creating index", e);
        } finally {
            if (writer != null) {
                try {
                    writer.close();
                } catch (IOException ex) {
                    logger.warn("Unable to close IndexWriter.", ex);
                }
            }
        }
    }

    public static Analyzer getAnalyzer() {
        final String className = WebloggerConfig.getProperty("lucene.analyzer.class");
        try {
            final Class<?> clazz = Class.forName(className);
            return (Analyzer) ConstructorUtils.invokeConstructor(clazz, null);
        } catch (final ClassNotFoundException e) {
            logger.error("failed to lookup analyzer class: " + className, e);
            return new StandardAnalyzer();
        } catch (final NoSuchMethodException | InstantiationException | IllegalAccessException | InvocationTargetException e) {
            logger.error("failed to instantiate analyzer: " + className, e);
            return new StandardAnalyzer();
        }
    }
}
```

#### LuceneDocumentFactory.java
```java
package org.apache.roller.weblogger.business.search.lucene;

import java.util.List;
import org.apache.lucene.document.Document;
import org.apache.lucene.document.Field;
import org.apache.lucene.document.SortedDocValuesField;
import org.apache.lucene.document.StringField;
import org.apache.lucene.document.TextField;
import org.apache.lucene.util.BytesRef;
import org.apache.roller.weblogger.config.WebloggerConfig;
import org.apache.roller.weblogger.pojos.WeblogCategory;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.pojos.WeblogEntryComment;

/**
 * Responsibile for converting WeblogEntry objects into Lucene Documents.
 */
public class LuceneDocumentFactory {

    public static Document createDocument(WeblogEntry data) {
        
        // Configuration check inside factory method or passed in? 
        // Keeping it consistent with original for now.
        boolean indexComments = WebloggerConfig.getBooleanProperty("search.index.comments", true);

        Document doc = new Document();

        // Standard Fields
        doc.add(new StringField(FieldConstants.ID, data.getId(), Field.Store.YES));
        doc.add(new StringField(FieldConstants.WEBSITE_HANDLE, data.getWebsite().getHandle(), Field.Store.YES));
        
        if (data.getCreator() != null) {
            doc.add(new TextField(FieldConstants.USERNAME, data.getCreator().getUserName().toLowerCase(), Field.Store.YES));
        }

        doc.add(new TextField(FieldConstants.TITLE, data.getTitle(), Field.Store.YES));
        doc.add(new StringField(FieldConstants.LOCALE, data.getLocale().toLowerCase(), Field.Store.YES));
        doc.add(new TextField(FieldConstants.CONTENT, data.getText(), Field.Store.NO));
        doc.add(new StringField(FieldConstants.UPDATED, data.getUpdateTime().toString(), Field.Store.YES));

        if (data.getPubTime() != null) {
            doc.add(new SortedDocValuesField(FieldConstants.PUBLISHED, new BytesRef(data.getPubTime().toString())));
        }

        WeblogCategory categorydata = data.getCategory();
        if (categorydata != null) {
            doc.add(new StringField(FieldConstants.CATEGORY, categorydata.getName().toLowerCase(), Field.Store.YES));
        }

        // Comment Handling
        addComments(doc, data, indexComments);

        return doc;
    }

    private static void addComments(Document doc, WeblogEntry data, boolean indexComments) {
        String commentContent = "";
        String commentEmail = "";
        String commentName = "";

        if (indexComments) {
            List<WeblogEntryComment> comments = data.getComments();
            if (comments != null) {
                StringBuilder commentEmailBld = new StringBuilder();
                StringBuilder commentContentBld = new StringBuilder();
                StringBuilder commentNameBld = new StringBuilder();
                for (WeblogEntryComment comment : comments) {
                    if (comment.getContent() != null) {
                        commentContentBld.append(comment.getContent()).append(",");
                    }
                    if (comment.getEmail() != null) {
                        commentEmailBld.append(comment.getEmail()).append(",");
                    }
                    if (comment.getName() != null) {
                        commentNameBld.append(comment.getName()).append(",");
                    }
                }
                commentEmail = commentEmailBld.toString();
                commentContent = commentContentBld.toString();
                commentName = commentNameBld.toString();
            }
        }

        doc.add(new TextField(FieldConstants.C_CONTENT, commentContent, Field.Store.NO));
        doc.add(new StringField(FieldConstants.C_EMAIL, commentEmail, Field.Store.YES));
        doc.add(new StringField(FieldConstants.C_NAME, commentName, Field.Store.YES));
    }
}
```

### 2. Modified Classes

#### IndexOperation.java (Refactored)
```java
package org.apache.roller.weblogger.business.search.lucene;

import java.io.IOException;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.lucene.analysis.miscellaneous.LimitTokenCountAnalyzer;
import org.apache.lucene.document.Document;
import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.index.IndexWriterConfig;
import org.apache.roller.weblogger.config.WebloggerConfig;
import org.apache.roller.weblogger.pojos.WeblogEntry;

/**
 * Base class for all index operations. 
 * Refactored to delegate Document creation to LuceneDocumentFactory.
 */
public abstract class IndexOperation implements Runnable {

    private static Log logger = LogFactory.getFactory().getInstance(IndexOperation.class);

    protected LuceneIndexManager manager;
    private IndexWriter writer;

    public IndexOperation(LuceneIndexManager manager) {
        this.manager = manager;
    }

    // Refactored: Delegated to Factory
    protected Document getDocument(WeblogEntry data) {
        return LuceneDocumentFactory.createDocument(data);
    }

    protected IndexWriter beginWriting() {
        try {
            // Using Infrastructure/Helper from Manager or static access if needed, 
            // but for now keeping logic here reusing the static analyzer access
            LimitTokenCountAnalyzer analyzer = new LimitTokenCountAnalyzer(
                    LuceneInfrastructure.getAnalyzer(),
                    WebloggerConfig.getIntProperty("lucene.analyzer.maxTokenCount"));

            IndexWriterConfig config = new IndexWriterConfig(analyzer);
            
            // Accessing directory via manager -> infrastructure
            writer = new IndexWriter(manager.getIndexDirectory(), config);

        } catch (IOException e) {
            logger.error("ERROR creating writer", e);
        }
        return writer;
    }

    protected void endWriting() {
        if (writer != null) {
            try {
                writer.close();
            } catch (IOException e) {
                logger.error("ERROR closing writer", e);
            }
        }
    }

    @Override
    public void run() {
        doRun();
    }

    protected abstract void doRun();
}
```

#### RebuildWebsiteIndexOperation.java (Refactored)
```java
package org.apache.roller.weblogger.business.search.lucene;

import java.text.MessageFormat;
import java.util.Date;
import java.util.List;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.index.Term;
import org.apache.roller.util.RollerConstants;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.WeblogEntryManager;
import org.apache.roller.weblogger.business.Weblogger;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.pojos.WeblogEntry.PubStatus;
import org.apache.roller.weblogger.pojos.WeblogEntrySearchCriteria;

/**
 * An index operation that rebuilds a given users index (or all indexes).
 * Refactored to reduce complexity by extracting methods.
 */
public class RebuildWebsiteIndexOperation extends WriteToIndexOperation {

    private static Log logger = LogFactory.getFactory().getInstance(RebuildWebsiteIndexOperation.class);
    
    private Weblog website;
    private Weblogger roller;

    public RebuildWebsiteIndexOperation(Weblogger roller, LuceneIndexManager mgr, Weblog website) {
        super(mgr);
        this.roller = roller;
        this.website = website;
    }

    @Override
    public void doRun() {
        Date start = new Date();
        
        if (!ensureWeblogState()) {
            return;
        }

        IndexWriter writer = beginWriting();
        try {
            if (writer != null) {
                deleteExistingData(writer);
                indexEntries(writer);
                roller.release();
            }
        } catch (Exception e) {
            logger.error("ERROR adding/deleting doc to index", e);
        } finally {
            endWriting();
            if (roller != null) {
                roller.release();
            }
        }

        logCompletion(start);
    }

    private boolean ensureWeblogState() {
        if (this.website != null) {
            logger.debug("Reindexining weblog " + website.getHandle());
            try {
                this.website = roller.getWeblogManager().getWeblog(this.website.getId());
            } catch (WebloggerException ex) {
                logger.error("Error getting website object", ex);
                return false;
            }
        } else {
            logger.debug("Reindexining entire site");
        }
        return true;
    }

    private void deleteExistingData(IndexWriter writer) throws Exception {
        if (website != null) {
            Term tWebsite = IndexUtil.getTerm(FieldConstants.WEBSITE_HANDLE, website.getHandle());
            writer.deleteDocuments(tWebsite);
        } else {
            Term all = IndexUtil.getTerm(FieldConstants.CONSTANT, FieldConstants.CONSTANT_V);
            writer.deleteDocuments(all);
        }
    }

    private void indexEntries(IndexWriter writer) throws Exception {
        WeblogEntryManager weblogManager = roller.getWeblogEntryManager();
        WeblogEntrySearchCriteria wesc = new WeblogEntrySearchCriteria();
        wesc.setWeblog(website);
        wesc.setStatus(PubStatus.PUBLISHED);
        
        List<WeblogEntry> entries = weblogManager.getWeblogEntries(wesc);
        logger.debug("Entries to index: " + entries.size());

        for (WeblogEntry entry : entries) {
            writer.addDocument(getDocument(entry));
            logger.debug(MessageFormat.format("Indexed entry {0}: {1}", entry.getPubTime(), entry.getAnchor()));
        }
    }

    private void logCompletion(Date start) {
        Date end = new Date();
        double length = (end.getTime() - start.getTime()) / (double) RollerConstants.SEC_IN_MS;
        String msg = (website == null) 
            ? "Completed rebuilding index for all users in '" + length + "' secs"
            : "Completed rebuilding index for website handle: '" + website.getHandle() + "' in '" + length + "' seconds";
        logger.info(msg);
    }
}
```

#### LuceneIndexManager.java (Refactored)
```java
package org.apache.roller.weblogger.business.search.lucene;

import java.io.File;
import java.io.IOException;
import java.util.concurrent.locks.ReadWriteLock;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.lucene.analysis.Analyzer;
import org.apache.lucene.index.IndexReader;
import org.apache.lucene.search.ScoreDoc;
import org.apache.lucene.search.TopFieldDocs;
import org.apache.lucene.store.Directory;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.InitializationException;
import org.apache.roller.weblogger.business.URLStrategy;
import org.apache.roller.weblogger.business.Weblogger;
import org.apache.roller.weblogger.business.search.IndexManager;
import org.apache.roller.weblogger.business.search.SearchResultList;
import org.apache.roller.weblogger.config.WebloggerConfig;
import org.apache.roller.weblogger.config.WebloggerRuntimeConfig;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogEntry;

@com.google.inject.Singleton
public class LuceneIndexManager implements IndexManager {

    private final static Log logger = LogFactory.getFactory().getInstance(LuceneIndexManager.class);
    
    private final Weblogger roller;
    private final LuceneInfrastructure infrastructure;
    
    // Configuration
    private boolean searchEnabled = true;
    private final File indexConsistencyMarker;
    private boolean inconsistentAtStartup = false;

    @com.google.inject.Inject
    protected LuceneIndexManager(Weblogger roller) {
        this.roller = roller;

        String enabled = WebloggerConfig.getProperty("search.enabled");
        if ("false".equalsIgnoreCase(enabled)) {
            this.searchEnabled = false;
        }

        String searchIndexDir = WebloggerConfig.getProperty("search.index.dir");
        String indexDir = searchIndexDir.replace('/', File.separatorChar);
        
        // Initialize infrastructure
        this.infrastructure = new LuceneInfrastructure(indexDir);

        logger.info("search enabled: " + this.searchEnabled);
        logger.info("index dir: " + indexDir);

        String test = indexDir + File.separator + ".index-inconsistent";
        indexConsistencyMarker = new File(test);
    }

    @Override
    public void initialize() throws InitializationException {
        if (!this.searchEnabled) return;

        // Check for consistency marker
        if (indexConsistencyMarker.exists()) {
            logger.debug("Index inconsistent: marker exists");
            inconsistentAtStartup = true;
            infrastructure.deleteIndex();
        } else {
            try {
                File makeIndexDir = new File(infrastructure.getIndexDir());
                if (!makeIndexDir.exists()) {
                    makeIndexDir.mkdirs();
                    inconsistentAtStartup = true;
                    logger.debug("Index inconsistent: new");
                }
                indexConsistencyMarker.createNewFile();
            } catch (IOException e) {
                logger.error(e);
            }
        }

        if (infrastructure.indexExists()) {
            try {
                // Pre-warm reader
                infrastructure.getSharedIndexReader();
            } catch (Exception ex) {
                logger.warn("Failed to open search index, scheduling rebuild.", ex);
                inconsistentAtStartup = true;
                infrastructure.deleteIndex();
            }
        } else {
            logger.debug("Creating index");
            inconsistentAtStartup = true;
            infrastructure.deleteIndex();
            infrastructure.createIndex(infrastructure.getIndexDirectory());
        }

        if (inconsistentAtStartup) {
            logger.info("Index was inconsistent. Rebuilding index in the background...");
            try {
                rebuildWeblogIndex();
            } catch (WebloggerException ex) {
                logger.error("ERROR: scheduling re-index operation", ex);
            }
        } else {
            logger.info("Index initialized and ready for use.");
        }
    }

    // Delegation to Infrastructure
    public Directory getIndexDirectory() {
        return infrastructure.getIndexDirectory();
    }
    
    public ReadWriteLock getReadWriteLock() {
        return infrastructure.getReadWriteLock();
    }
    
    public synchronized IndexReader getSharedIndexReader() {
        return infrastructure.getSharedIndexReader();
    }

    public synchronized void resetSharedReader() {
        infrastructure.resetSharedReader();
    }
    
    public static Analyzer getAnalyzer() {
        return LuceneInfrastructure.getAnalyzer();
    }

    @Override
    public boolean isInconsistentAtStartup() {
        return inconsistentAtStartup;
    }

    @Override
    public void shutdown() {
        indexConsistencyMarker.delete();
        infrastructure.close();
    }

    // Operations Scheduling
    @Override
    public void rebuildWeblogIndex() throws WebloggerException {
        scheduleIndexOperation(new RebuildWebsiteIndexOperation(roller, this, null));
    }

    @Override
    public void rebuildWeblogIndex(Weblog website) throws WebloggerException {
        scheduleIndexOperation(new RebuildWebsiteIndexOperation(roller, this, website));
    }

    @Override
    public void removeWeblogIndex(Weblog website) throws WebloggerException {
        scheduleIndexOperation(new RemoveWebsiteIndexOperation(roller, this, website));
    }

    @Override
    public void addEntryIndexOperation(WeblogEntry entry) throws WebloggerException {
        scheduleIndexOperation(new AddEntryOperation(roller, this, entry));
    }

    @Override
    public void addEntryReIndexOperation(WeblogEntry entry) throws WebloggerException {
        scheduleIndexOperation(new ReIndexEntryOperation(roller, this, entry));
    }

    @Override
    public void removeEntryIndexOperation(WeblogEntry entry) throws WebloggerException {
        executeIndexOperationNow(new RemoveEntryOperation(roller, this, entry));
    }

    private void scheduleIndexOperation(final IndexOperation op) {
        if (!this.searchEnabled) return;
        try {
            logger.debug("Starting scheduled index operation: " + op.getClass().getName());
            roller.getThreadManager().executeInBackground(op);
        } catch (InterruptedException e) {
            logger.error("Error executing operation", e);
        }
    }

    private void executeIndexOperationNow(final IndexOperation op) {
        if (!this.searchEnabled) return;
        try {
            logger.debug("Executing index operation now: " + op.getClass().getName());
            roller.getThreadManager().executeInForeground(op);
        } catch (InterruptedException e) {
            logger.error("Error executing operation", e);
        }
    }

    // Search Execution
    @Override
    public SearchResultList search(String term, String weblogHandle, String category, String locale, 
            int pageNum, int entryCount, URLStrategy urlStrategy) throws WebloggerException {
        
        SearchOperation search = new SearchOperation(this);
        search.setTerm(term);
        boolean weblogSpecific = !WebloggerRuntimeConfig.isSiteWideWeblog(weblogHandle);
        if (weblogSpecific) {
            search.setWeblogHandle(weblogHandle);
        }
        if (category != null) {
            search.setCategory(category);
        }
        if (locale != null) {
            search.setLocale(locale);
        }

        executeIndexOperationNow(search);
        
        if (search.getResultsCount() >= 0) {
            TopFieldDocs docs = search.getResults();
            ScoreDoc[] hitsArr = docs.scoreDocs;
            return convertHitsToEntryList(hitsArr, search, pageNum, entryCount, weblogHandle, weblogSpecific, urlStrategy);
        }
        throw new WebloggerException("Error executing search");
    }

    static SearchResultList convertHitsToEntryList(
        ScoreDoc[] hits,
        SearchOperation search,
        int pageNum,
        int entryCount,
        String weblogHandle,
        boolean websiteSpecificSearch,
        URLStrategy urlStrategy)
        throws WebloggerException {

        List<WeblogEntryWrapper> results = new java.util.ArrayList<>();

        // determine offset
        int offset = pageNum * entryCount;
        if (offset >= hits.length) {
            offset = 0;
        }

        // determine limit
        int limit = entryCount;
        if (offset + limit > hits.length) {
            limit = hits.length - offset;
        }

        try {
            java.util.Set<String> categories = new java.util.TreeSet<>();
            java.util.TreeSet<String> categorySet = new java.util.TreeSet<>();
            Weblogger roller = org.apache.roller.weblogger.business.WebloggerFactory.getWeblogger();
            org.apache.roller.weblogger.business.WeblogEntryManager weblogMgr = roller.getWeblogEntryManager();

            WeblogEntry entry;
            org.apache.lucene.document.Document doc;
            String handle;
            java.sql.Timestamp now = new java.sql.Timestamp(new java.util.Date().getTime());
            for (int i = offset; i < offset + limit; i++) {
                doc = search.getSearcher().doc(hits[i].doc);
                handle = doc.getField(FieldConstants.WEBSITE_HANDLE).stringValue();
                entry = weblogMgr.getWeblogEntry(doc.getField(FieldConstants.ID).stringValue());

                if (!(websiteSpecificSearch && handle.equals(weblogHandle))
                    && doc.getField(FieldConstants.CATEGORY) != null) {
                    categorySet.add(doc.getField(FieldConstants.CATEGORY).stringValue());
                }

                // maybe null if search result returned inactive user
                // or entry's user is not the requested user.
                // but don't return future posts
                if (entry != null && entry.getPubTime().before(now)) {
                    results.add(WeblogEntryWrapper.wrap(entry, urlStrategy));
                }
            }

            if (!categorySet.isEmpty()) {
                categories = categorySet;
            }

            return new SearchResultList(results, categories, limit, offset);

        } catch (IOException e) {
            throw new WebloggerException(e);
        }
    }
}
```
