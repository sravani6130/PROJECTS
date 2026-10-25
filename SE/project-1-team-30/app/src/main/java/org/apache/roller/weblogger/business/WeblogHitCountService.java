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

import java.util.List;

import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogHitCount;

/**
 * Service interface for weblog hit count operations.
 * 
 * This service encapsulates all hit count-related business logic,
 * extracted from WeblogEntryManager to improve cohesion and
 * reduce the complexity of the manager class.
 */
public interface WeblogHitCountService {

    /**
     * Get a hit count by id.
     * 
     * @param id The hit count id
     * @return The hit count or null if not found
     * @throws WebloggerException If there is an error
     */
    WeblogHitCount getHitCount(String id) throws WebloggerException;

    /**
     * Get hit count for a specific weblog.
     * 
     * @param weblog The weblog
     * @return The hit count or null if not found
     * @throws WebloggerException If there is an error
     */
    WeblogHitCount getHitCountByWeblog(Weblog weblog) throws WebloggerException;

    /**
     * Get hit counts for the hottest weblogs.
     * 
     * @param sinceDays Number of days in the past to consider
     * @param offset    Offset for paging
     * @param length    Maximum results
     * @return List of hit counts ordered by daily hits descending
     * @throws WebloggerException If there is an error
     */
    List<WeblogHitCount> getHotWeblogs(int sinceDays, int offset, int length)
            throws WebloggerException;

    /**
     * Save a hit count.
     * 
     * @param hitCount The hit count to save
     * @throws WebloggerException If there is an error
     */
    void saveHitCount(WeblogHitCount hitCount) throws WebloggerException;

    /**
     * Remove a hit count.
     * 
     * @param hitCount The hit count to remove
     * @throws WebloggerException If there is an error
     */
    void removeHitCount(WeblogHitCount hitCount) throws WebloggerException;

    /**
     * Increment the hit count for a weblog.
     * 
     * @param weblog The weblog
     * @param amount Amount to increment (must be non-zero)
     * @throws WebloggerException If there is an error
     */
    void incrementHitCount(Weblog weblog, int amount) throws WebloggerException;

    /**
     * Reset all hit counts to zero.
     * 
     * @throws WebloggerException If there is an error
     */
    void resetAllHitCounts() throws WebloggerException;

    /**
     * Reset hit count for a specific weblog to zero.
     * 
     * @param weblog The weblog
     * @throws WebloggerException If there is an error
     */
    void resetHitCount(Weblog weblog) throws WebloggerException;
}
