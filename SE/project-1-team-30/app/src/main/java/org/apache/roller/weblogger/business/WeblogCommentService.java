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
import org.apache.roller.weblogger.pojos.CommentSearchCriteria;
import org.apache.roller.weblogger.pojos.StatCount;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.pojos.WeblogEntryComment;
import org.apache.roller.weblogger.pojos.WeblogEntryComment.ApprovalStatus;

/**
 * Service interface for weblog comment operations.
 * 
 * This service encapsulates all comment-related business logic,
 * extracted from WeblogEntryManager to improve cohesion and
 * reduce the complexity of the manager class.
 */
public interface WeblogCommentService {

    /**
     * Save a comment.
     * 
     * @param comment The comment to save
     * @throws WebloggerException If there is an error saving
     */
    void saveComment(WeblogEntryComment comment) throws WebloggerException;

    /**
     * Remove a comment.
     * 
     * @param comment The comment to remove
     * @throws WebloggerException If there is an error removing
     */
    void removeComment(WeblogEntryComment comment) throws WebloggerException;

    /**
     * Get a comment by id.
     * 
     * @param id The comment id
     * @return The comment or null if not found
     * @throws WebloggerException If there is an error
     */
    WeblogEntryComment getComment(String id) throws WebloggerException;

    /**
     * Search for comments using the given criteria.
     * 
     * @param csc The search criteria
     * @return List of matching comments
     * @throws WebloggerException If there is an error
     */
    List<WeblogEntryComment> getComments(CommentSearchCriteria csc) throws WebloggerException;

    /**
     * Remove comments that match the given criteria.
     * 
     * @param weblog       Weblog or null for all
     * @param entry        Entry or null for all entries
     * @param searchString Search string or null
     * @param startDate    Start date or null
     * @param endDate      End date or null
     * @param status       Approval status
     * @return Number of comments removed
     * @throws WebloggerException If there is an error
     */
    int removeMatchingComments(
            Weblog weblog,
            WeblogEntry entry,
            String searchString,
            Date startDate,
            Date endDate,
            ApprovalStatus status) throws WebloggerException;

    /**
     * Get site-wide comment count.
     * 
     * @return The total number of approved comments
     * @throws WebloggerException If there is an error
     */
    long getCommentCount() throws WebloggerException;

    /**
     * Get comment count for a specific weblog.
     * 
     * @param weblog The weblog
     * @return The number of approved comments for the weblog
     * @throws WebloggerException If there is an error
     */
    long getCommentCount(Weblog weblog) throws WebloggerException;

    /**
     * Get weblog entries ordered by descending number of comments.
     * 
     * @param website   Weblog or null for all weblogs
     * @param startDate Start date or null
     * @param endDate   End date or null
     * @param offset    Offset for paging
     * @param length    Maximum results or -1 for no limit
     * @return List of StatCount objects
     * @throws WebloggerException If there is an error
     */
    List<StatCount> getMostCommentedWeblogEntries(
            Weblog website,
            Date startDate,
            Date endDate,
            int offset,
            int length) throws WebloggerException;
}
