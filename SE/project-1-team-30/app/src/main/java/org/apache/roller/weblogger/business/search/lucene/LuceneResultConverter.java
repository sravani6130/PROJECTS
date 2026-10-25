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
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

import org.apache.lucene.document.Document;
import org.apache.lucene.index.StoredFields;
import org.apache.lucene.search.ScoreDoc;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.URLStrategy;
import org.apache.roller.weblogger.business.WeblogEntryManager;
import org.apache.roller.weblogger.business.Weblogger;
import org.apache.roller.weblogger.business.WebloggerFactory;
import org.apache.roller.weblogger.business.search.SearchResultList;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.pojos.wrapper.WeblogEntryWrapper;

/**
 * Converts Lucene search hits to Roller SearchResultList.
 */
public final class LuceneResultConverter {

    private LuceneResultConverter() {
        // utility class
    }

    /**
     * Convert hits to entries.
     *
     * @param hits
     *               the hits
     * @param search
     *               the search
     * @throws WebloggerException
     *                            the weblogger exception
     */
    public static SearchResultList convertHitsToEntryList(
            ScoreDoc[] hits,
            SearchOperation search,
            int pageNum,
            int entryCount,
            String weblogHandle,
            boolean websiteSpecificSearch,
            URLStrategy urlStrategy)
            throws WebloggerException {

        List<WeblogEntryWrapper> results = new ArrayList<>();

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
            Set<String> categories = new TreeSet<>();
            TreeSet<String> categorySet = new TreeSet<>();
            Weblogger roller = WebloggerFactory.getWeblogger();
            WeblogEntryManager weblogMgr = roller.getWeblogEntryManager();

            WeblogEntry entry;
            Document doc;
            String handle;
            Timestamp now = new Timestamp(new Date().getTime());
            StoredFields storedFields = search.getSearcher().storedFields();
            for (int i = offset; i < offset + limit; i++) {
                doc = storedFields.document(hits[i].doc);
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
