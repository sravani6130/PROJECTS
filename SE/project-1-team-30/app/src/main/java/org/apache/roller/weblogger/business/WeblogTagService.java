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

package org.apache.roller.weblogger.business;

import java.util.Date;
import java.util.List;

import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.TagStat;
import org.apache.roller.weblogger.pojos.Weblog;

/**
 * Service interface for weblog tag operations.
 * 
 * This service encapsulates all tag-related business logic,
 * extracted from WeblogEntryManager to improve cohesion and
 * reduce the complexity of the manager class.
 */
public interface WeblogTagService {

    /**
     * Get list of popular tags.
     * 
     * @param website   Weblog or null for all weblogs
     * @param startDate Date or null for no date restriction
     * @param offset    Offset for paging
     * @param limit     Maximum results or -1 for no limit
     * @return List of TagStat objects with intensity values
     * @throws WebloggerException If there is an error
     */
    List<TagStat> getPopularTags(Weblog website, Date startDate, int offset, int limit)
            throws WebloggerException;

    /**
     * Get list of tags with optional filtering.
     * 
     * @param website    Weblog or null for all weblogs
     * @param sortBy     Sort by "name" or "count" (null defaults to name)
     * @param startsWith Prefix filter or null
     * @param offset     Offset for paging
     * @param limit      Maximum results or -1 for no limit
     * @return List of TagStat objects
     * @throws WebloggerException If there is an error
     */
    List<TagStat> getTags(Weblog website, String sortBy, String startsWith, int offset, int limit)
            throws WebloggerException;

    /**
     * Check if a combination of tags exists.
     * 
     * @param tags   List of tag names
     * @param weblog Weblog to search in or null for all
     * @return true if all tags exist together
     * @throws WebloggerException If there is an error
     */
    boolean getTagComboExists(List<String> tags, Weblog weblog) throws WebloggerException;

    /**
     * Update tag count for aggregate tracking.
     * 
     * @param name    Tag name
     * @param website The weblog
     * @param amount  Amount to increment (can be negative)
     * @throws WebloggerException If there is an error
     */
    void updateTagCount(String name, Weblog website, int amount) throws WebloggerException;
}
