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
import java.text.MessageFormat;
import java.util.Date;
import java.util.List;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
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
 * Service for performing Lucene index write operations.
 * Replaces singular operation classes (AddEntryOperation, RemoveEntryOperation,
 * etc.).
 */
public class LuceneOperations {

    private static final Log logger = LogFactory.getFactory().getInstance(LuceneOperations.class);

    private final LuceneIndexManager manager;
    private final Weblogger roller;

    public LuceneOperations(LuceneIndexManager manager, Weblogger roller) {
        this.manager = manager;
        this.roller = roller;
    }

    public Runnable getAddEntryOperation(WeblogEntry data) {
        return () -> addEntry(data);
    }

    public Runnable getRemoveEntryOperation(WeblogEntry data) {
        return () -> removeEntry(data);
    }

    public Runnable getReIndexEntryOperation(WeblogEntry data) {
        return () -> reIndexEntry(data);
    }

    public Runnable getRebuildWebsiteIndexOperation(Weblog website) {
        return () -> rebuildWebsiteIndex(website);
    }

    public Runnable getRemoveWebsiteIndexOperation(Weblog website) {
        return () -> removeWebsiteIndex(website);
    }

    private void addEntry(WeblogEntry data) {
        // since this operation can be run on a separate thread we must treat
        // the weblog object passed in as a detached object which is proned to
        // lazy initialization problems, so requery for the object now
        try {
            WeblogEntryManager wMgr = roller.getWeblogEntryManager();
            data = wMgr.getWeblogEntry(data.getId());
        } catch (WebloggerException ex) {
            logger.error("Error getting weblogentry object", ex);
            return;
        }

        final WeblogEntry finalData = data;
        manager.executeWrite(writer -> {
            writer.addDocument(LuceneDocumentFactory.createDocument(finalData));
        });
    }

    private void removeEntry(WeblogEntry data) {
        // requery for detached object
        try {
            WeblogEntryManager wMgr = roller.getWeblogEntryManager();
            data = wMgr.getWeblogEntry(data.getId());
        } catch (WebloggerException ex) {
            logger.error("Error getting weblogentry object", ex);
            return;
        }

        final String id = data.getId();
        manager.executeWrite(writer -> {
            Term term = new Term(FieldConstants.ID, id);
            writer.deleteDocuments(term);
        });
    }

    private void reIndexEntry(WeblogEntry data) {
        // requery for detached object
        try {
            WeblogEntryManager wMgr = roller.getWeblogEntryManager();
            data = wMgr.getWeblogEntry(data.getId());
        } catch (WebloggerException ex) {
            logger.error("Error getting weblogentry object", ex);
            return;
        }

        final WeblogEntry finalData = data;
        manager.executeWrite(writer -> {
            Term term = new Term(FieldConstants.ID, finalData.getId());
            writer.deleteDocuments(term);
            writer.addDocument(LuceneDocumentFactory.createDocument(finalData));
        });
    }

    private void rebuildWebsiteIndex(Weblog website) {
        Date start = new Date();

        // Requery
        if (website != null) {
            logger.debug("Reindexining weblog " + website.getHandle());
            try {
                website = roller.getWeblogManager().getWeblog(website.getId());
            } catch (WebloggerException ex) {
                logger.error("Error getting website object", ex);
                return;
            }
        } else {
            logger.debug("Reindexining entire site");
        }

        final Weblog finalWebsite = website;

        manager.executeWrite(writer -> {
            // Delete Doc
            Term tWebsite = null;
            if (finalWebsite != null) {
                tWebsite = IndexUtil.getTerm(FieldConstants.WEBSITE_HANDLE,
                        finalWebsite.getHandle());
            }
            if (tWebsite != null) {
                writer.deleteDocuments(tWebsite);
            } else {
                Term all = IndexUtil.getTerm(FieldConstants.CONSTANT,
                        FieldConstants.CONSTANT_V);
                writer.deleteDocuments(all);
            }

            // Add Doc
            WeblogEntryManager weblogManager = roller.getWeblogEntryManager();
            WeblogEntrySearchCriteria wesc = new WeblogEntrySearchCriteria();
            wesc.setWeblog(finalWebsite);
            wesc.setStatus(PubStatus.PUBLISHED);
            List<WeblogEntry> entries = weblogManager.getWeblogEntries(wesc);

            logger.debug("Entries to index: " + entries.size());

            for (WeblogEntry entry : entries) {
                writer.addDocument(LuceneDocumentFactory.createDocument(entry));
                logger.debug(MessageFormat.format(
                        "Indexed entry {0}: {1}",
                        entry.getPubTime(), entry.getAnchor()));
            }
        });

        Date end = new Date();
        double length = (end.getTime() - start.getTime()) / (double) RollerConstants.SEC_IN_MS;

        if (website == null) {
            logger.info("Completed rebuilding index for all users in '"
                    + length + "' secs");
        } else {
            logger.info("Completed rebuilding index for website handle: '"
                    + website.getHandle() + "' in '" + length + "' seconds");
        }
    }

    private void removeWebsiteIndex(Weblog website) {
        // Requery
        if (website != null) {
            try {
                website = roller.getWeblogManager().getWeblog(website.getId());
            } catch (WebloggerException ex) {
                logger.error("Error getting website object", ex);
                return;
            }
        }

        final Weblog finalWebsite = website;
        manager.executeWrite(writer -> {
            Term tWebsite = null;
            if (finalWebsite != null) {
                tWebsite = IndexUtil.getTerm(FieldConstants.WEBSITE_HANDLE,
                        finalWebsite.getHandle());
            }
            if (tWebsite != null) {
                writer.deleteDocuments(tWebsite);
            }
        });
    }
}
