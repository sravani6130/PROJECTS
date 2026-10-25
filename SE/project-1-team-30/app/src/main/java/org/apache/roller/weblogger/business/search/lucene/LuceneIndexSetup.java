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

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.lucene.analysis.miscellaneous.LimitTokenCountAnalyzer;
import org.apache.lucene.index.DirectoryReader;
import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.index.IndexWriterConfig;
import org.apache.lucene.store.Directory;
import org.apache.lucene.store.FSDirectory;
import org.apache.roller.weblogger.business.InitializationException;
import org.apache.roller.weblogger.config.WebloggerConfig;

/**
 * Handles initialization and management of the Lucene index directory.
 */
public class LuceneIndexSetup {

    private static final Log logger = LogFactory.getFactory().getInstance(LuceneIndexSetup.class);

    private final String indexDir;
    private final File indexConsistencyMarker;
    private boolean searchEnabled = true;

    public LuceneIndexSetup() {
        // check config to see if the internal search is enabled
        String enabled = WebloggerConfig.getProperty("search.enabled");
        if ("false".equalsIgnoreCase(enabled)) {
            this.searchEnabled = false;
        }

        // we also need to know what our index directory is
        String searchIndexDir = WebloggerConfig.getProperty("search.index.dir");
        this.indexDir = searchIndexDir.replace('/', File.separatorChar);

        // a little debugging
        logger.info("search enabled: " + this.searchEnabled);
        logger.info("index dir: " + this.indexDir);

        String test = indexDir + File.separator + ".index-inconsistent";
        indexConsistencyMarker = new File(test);
    }

    public Directory getIndexDirectory() {
        try {
            return FSDirectory.open(Path.of(indexDir));
        } catch (IOException e) {
            logger.error("Problem accessing index directory", e);
        }
        return null;
    }

    public boolean isSearchEnabled() {
        return searchEnabled;
    }

    /**
     * Initializes the index, checking for consistency and creating if needed.
     * 
     * @return true if the index is inconsistent and needs rebuilding
     */
    public boolean initialize() throws InitializationException {
        // only initialize the index if search is enabled
        if (!this.searchEnabled) {
            return false;
        }

        boolean inconsistent = false;

        // delete index if inconsistency marker exists
        if (indexConsistencyMarker.exists()) {
            logger.debug("Index inconsistent: marker exists");
            inconsistent = true;
            deleteIndex();
        } else {
            try {
                File makeIndexDir = new File(indexDir);
                if (!makeIndexDir.exists()) {
                    makeIndexDir.mkdirs();
                    inconsistent = true;
                    logger.debug("Index inconsistent: new");
                }
                indexConsistencyMarker.createNewFile();
            } catch (IOException e) {
                logger.error(e);
            }
        }

        if (indexExists()) {
            // test if the index is readable, if the version is outdated or it fails we
            // rebuild.
            try (DirectoryReader reader = DirectoryReader.open(getIndexDirectory())) {
                // if open succeeds, we are good?
            } catch (IOException | IllegalArgumentException ex) { // IAE for incompatible codecs
                logger.warn("Failed to open search index, scheduling rebuild.", ex);
                inconsistent = true;
                deleteIndex();
            }
        } else {
            logger.debug("Creating index");
            inconsistent = true;
            deleteIndex();
            createIndex(getIndexDirectory());
        }

        return inconsistent;
    }

    public void setInconsistent() {
        // We might want to recreate the marker or just track state
        // In the original code, this was mostly tracking startup state.
        // But if we need to mark it inconsistent later:
        try {
            if (!indexConsistencyMarker.exists()) {
                indexConsistencyMarker.createNewFile();
            }
        } catch (IOException e) {
            logger.error("Error creating consistency marker", e);
        }
    }

    public void setConsistent() {
        if (indexConsistencyMarker.exists()) {
            indexConsistencyMarker.delete();
        }
    }

    private boolean indexExists() {
        try {
            return DirectoryReader.indexExists(getIndexDirectory());
        } catch (IOException e) {
            logger.error("Problem accessing index directory", e);
        }
        return false;
    }

    public void deleteIndex() {
        try (FSDirectory directory = FSDirectory.open(Path.of(indexDir))) {
            String[] files = directory.listAll();
            for (String file : files) {
                Files.delete(Path.of(indexDir, file));
            }
        } catch (IOException ex) {
            logger.error("Problem accessing index directory", ex);
        }
    }

    private void createIndex(Directory dir) {
        IndexWriter writer = null;
        try {
            IndexWriterConfig config = new IndexWriterConfig(
                    new LimitTokenCountAnalyzer(
                            LuceneAnalyzerFactory.getAnalyzer(), 128));

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
}
