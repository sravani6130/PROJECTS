/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 *  contributor license agreements.  The ASF licenses this file to You
 * under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.  For additional information regarding
 * copyright in this work, please see the NOTICE file in the top level
 * directory of this distribution.
 */

package org.apache.roller.weblogger.business.search.lucene;

import java.io.IOException;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.lucene.analysis.Analyzer;
import org.apache.lucene.analysis.miscellaneous.LimitTokenCountAnalyzer;
import org.apache.lucene.index.DirectoryReader;
import org.apache.lucene.index.IndexReader;
import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.index.IndexWriterConfig;
import org.apache.lucene.search.IndexSearcher;
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

/**
 * Lucene implementation of IndexManager. This is the central entry point into
 * the Lucene searching API.
 * 
 * @author Mindaugas Idzelis (min@idzelis.com)
 * @author mraible (formatting and making indexDir configurable)
 */
@com.google.inject.Singleton
public class LuceneIndexManager implements IndexManager {

    private IndexReader reader;
    private final Weblogger roller;

    private final static Log logger = LogFactory.getFactory().getInstance(LuceneIndexManager.class);

    private boolean inconsistentAtStartup = false;

    private final ReadWriteLock rwl = new ReentrantReadWriteLock();

    // Delegated responsibilities
    private final LuceneIndexSetup indexSetup;
    private final LuceneOperations operations;

    /**
     * Creates a new lucene index manager. This should only be created once.
     * Creating the index manager more than once will definitely result in
     * errors. The preferred way of getting an index is through the
     * RollerContext.
     * 
     * @param roller - the weblogger instance
     */
    @com.google.inject.Inject
    protected LuceneIndexManager(Weblogger roller) {
        this.roller = roller;
        this.indexSetup = new LuceneIndexSetup();
        this.operations = new LuceneOperations(this, roller);
    }

    /**
     * @inheritDoc
     */
    @Override
    public void initialize() throws InitializationException {

        // only initialize the index if search is enabled
        if (indexSetup.isSearchEnabled()) {

            inconsistentAtStartup = indexSetup.initialize();

            if (indexExists()) {
                // test if the index is readable, if the version is outdated or it fails we
                // rebuild.
                try {
                    synchronized (this) {
                        reader = DirectoryReader.open(getIndexDirectory());
                    }
                } catch (IOException | IllegalArgumentException ex) { // IAE for incompatible codecs
                    logger.warn("Failed to open search index, scheduling rebuild.", ex);
                    inconsistentAtStartup = true;
                    indexSetup.deleteIndex();
                }
            }

            // Note: indexSetup already handled creation if it didn't exist in its
            // initialize()

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

    }

    @Override
    public void rebuildWeblogIndex() throws WebloggerException {
        scheduleIndexOperation(operations.getRebuildWebsiteIndexOperation(null));
    }

    @Override
    public void rebuildWeblogIndex(Weblog website) throws WebloggerException {
        scheduleIndexOperation(operations.getRebuildWebsiteIndexOperation(website));
    }

    @Override
    public void removeWeblogIndex(Weblog website) throws WebloggerException {
        scheduleIndexOperation(operations.getRemoveWebsiteIndexOperation(website));
    }

    @Override
    public void addEntryIndexOperation(WeblogEntry entry) throws WebloggerException {
        scheduleIndexOperation(operations.getAddEntryOperation(entry));
    }

    @Override
    public void addEntryReIndexOperation(WeblogEntry entry) throws WebloggerException {
        scheduleIndexOperation(operations.getReIndexEntryOperation(entry));
    }

    @Override
    public void removeEntryIndexOperation(WeblogEntry entry) throws WebloggerException {
        executeIndexOperationNow(operations.getRemoveEntryOperation(entry));
    }

    @Override
    public SearchResultList search(
            String term,
            String weblogHandle,
            String category,
            String locale,
            int pageNum,
            int entryCount,
            URLStrategy urlStrategy) throws WebloggerException {

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

            return LuceneResultConverter.convertHitsToEntryList(
                    hitsArr,
                    search,
                    pageNum,
                    entryCount,
                    weblogHandle,
                    weblogSpecific,
                    urlStrategy);
        }
        throw new WebloggerException("Error executing search");
    }

    // Generic execution methods to encapsulate resource management

    public void executeWrite(IndexWriterConsumer consumer) {
        try {
            getReadWriteLock().writeLock().lock();

            IndexWriter writer = null;
            try {
                LimitTokenCountAnalyzer analyzer = new LimitTokenCountAnalyzer(
                        LuceneAnalyzerFactory.getAnalyzer(),
                        WebloggerConfig.getIntProperty("lucene.analyzer.maxTokenCount"));

                IndexWriterConfig config = new IndexWriterConfig(analyzer);

                // Note: getIndexDirectory() is now private, accessible here
                writer = new IndexWriter(getIndexDirectory(), config);

                if (writer != null) {
                    consumer.accept(writer);
                }

            } catch (IOException e) {
                logger.error("ERROR creating/using writer", e);
            } finally {
                if (writer != null) {
                    try {
                        writer.close();
                    } catch (IOException e) {
                        logger.error("ERROR closing writer", e);
                    }
                }
            }

        } catch (Exception e) {
            logger.error("Error acquiring write lock on index", e);
        } finally {
            getReadWriteLock().writeLock().unlock();
            resetSharedReader();

            if (roller != null) {
                roller.release();
            }
        }
    }

    public void executeSearch(IndexSearcherConsumer consumer) {
        try {
            getReadWriteLock().readLock().lock();

            IndexReader sharedReader = getSharedIndexReader();
            if (sharedReader != null) {
                IndexSearcher searcher = new IndexSearcher(sharedReader);
                consumer.accept(searcher);
            }

        } catch (Exception e) {
            logger.error("Error executing search or acquiring read lock", e);
        } finally {
            getReadWriteLock().readLock().unlock();
        }
    }

    private ReadWriteLock getReadWriteLock() {
        return rwl;
    }

    @Override
    public boolean isInconsistentAtStartup() {
        return inconsistentAtStartup;
    }

    /**
     * This is the analyzer that will be used to tokenize comment text.
     * 
     * @return Analyzer to be used in manipulating the database.
     */
    public static final Analyzer getAnalyzer() {
        return LuceneAnalyzerFactory.getAnalyzer();
    }

    private void scheduleIndexOperation(final Runnable op) {
        try {
            // only if search is enabled
            if (indexSetup.isSearchEnabled()) {
                logger.debug("Starting scheduled index operation");
                roller.getThreadManager().executeInBackground(op);
            }
        } catch (InterruptedException e) {
            logger.error("Error executing operation", e);
        }
    }

    /**
     * @param op
     */
    private void executeIndexOperationNow(final Runnable op) {
        try {
            // only if search is enabled
            if (indexSetup.isSearchEnabled()) {
                logger.debug("Executing index operation now");
                roller.getThreadManager().executeInForeground(op);
            }
        } catch (InterruptedException e) {
            logger.error("Error executing operation", e);
        }
    }

    public synchronized void resetSharedReader() {
        reader = null;
    }

    private synchronized IndexReader getSharedIndexReader() {
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

    /**
     * Get the directory that is used by the lucene index. This method will
     * return null if there is no index at the directory location.
     * 
     * @return Directory The directory containing the index, or null if error.
     */
    private Directory getIndexDirectory() {
        return indexSetup.getIndexDirectory();
    }

    private boolean indexExists() {
        try {
            return DirectoryReader.indexExists(getIndexDirectory());
        } catch (IOException e) {
            logger.error("Problem accessing index directory", e);
        }
        return false;
    }

    // Used by operations to toggle consistency flag
    // In original code, indexConsistencyMarker was manipulated directly in
    // initialize()
    // and shutdown().

    @Override
    public void release() {
        // no-op
    }

    @Override
    public void shutdown() {
        indexSetup.setConsistent();

        if (reader != null) {
            try {
                reader.close();
            } catch (IOException ex) {
                logger.error("Unable to close reader.", ex);
            }
        }
    }

    @FunctionalInterface
    public interface IndexWriterConsumer {
        void accept(IndexWriter writer) throws IOException, WebloggerException;
    }

    @FunctionalInterface
    public interface IndexSearcherConsumer {
        void accept(org.apache.lucene.search.IndexSearcher searcher);
    }
}
