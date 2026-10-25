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

package org.apache.roller.weblogger.business.jpa;

import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.List;

import jakarta.persistence.Query;
import jakarta.persistence.TypedQuery;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.WeblogCommentService;
import org.apache.roller.weblogger.business.WeblogManager;
import org.apache.roller.weblogger.business.Weblogger;
import org.apache.roller.weblogger.pojos.CommentSearchCriteria;
import org.apache.roller.weblogger.pojos.StatCount;
import org.apache.roller.weblogger.pojos.StatCountCountComparator;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.pojos.WeblogEntryComment;
import org.apache.roller.weblogger.pojos.WeblogEntryComment.ApprovalStatus;

/**
 * JPA implementation of WeblogCommentService.
 * 
 * This service handles all weblog comment operations, extracted from
 * JPAWeblogEntryManagerImpl to improve cohesion and reduce class complexity.
 */
@com.google.inject.Singleton
public class JPAWeblogCommentServiceImpl implements WeblogCommentService {

    private static final Log LOG = LogFactory.getLog(JPAWeblogCommentServiceImpl.class);

    private static final Comparator<StatCount> STAT_COUNT_COUNT_REVERSE_COMPARATOR = Collections
            .reverseOrder(StatCountCountComparator.getInstance());

    private final Weblogger roller;
    private final JPAPersistenceStrategy strategy;

    @com.google.inject.Inject
    protected JPAWeblogCommentServiceImpl(Weblogger roller, JPAPersistenceStrategy strategy) {
        LOG.debug("Instantiating JPA Weblog Comment Service");
        this.roller = roller;
        this.strategy = strategy;
    }

    @Override
    public void saveComment(WeblogEntryComment comment) throws WebloggerException {
        this.strategy.store(comment);

        // update weblog last modified date
        WeblogManager weblogManager = roller.getWeblogManager();
        weblogManager.saveWeblog(comment.getWeblogEntry().getWebsite());
    }

    @Override
    public void removeComment(WeblogEntryComment comment) throws WebloggerException {
        this.strategy.remove(comment);

        // update weblog last modified date
        WeblogManager weblogManager = roller.getWeblogManager();
        weblogManager.saveWeblog(comment.getWeblogEntry().getWebsite());
    }

    @Override
    public WeblogEntryComment getComment(String id) throws WebloggerException {
        return (WeblogEntryComment) this.strategy.load(WeblogEntryComment.class, id);
    }

    @Override
    public List<WeblogEntryComment> getComments(CommentSearchCriteria csc) throws WebloggerException {

        List<Object> params = new ArrayList<>();
        int size = 0;
        StringBuilder queryString = new StringBuilder();
        queryString.append("SELECT c FROM WeblogEntryComment c ");

        StringBuilder whereClause = new StringBuilder();
        if (csc.getEntry() != null) {
            params.add(size++, csc.getEntry());
            whereClause.append("c.weblogEntry = ?").append(size);
        } else if (csc.getWeblog() != null) {
            params.add(size++, csc.getWeblog());
            whereClause.append("c.weblogEntry.website = ?").append(size);
        }

        if (csc.getSearchText() != null) {
            params.add(size++, "%" + csc.getSearchText().toUpperCase() + "%");
            appendConjunctionToWhereClause(whereClause, "upper(c.content) LIKE ?").append(size);
        }

        if (csc.getStartDate() != null) {
            Timestamp start = new Timestamp(csc.getStartDate().getTime());
            params.add(size++, start);
            appendConjunctionToWhereClause(whereClause, "c.postTime >= ?").append(size);
        }

        if (csc.getEndDate() != null) {
            Timestamp end = new Timestamp(csc.getEndDate().getTime());
            params.add(size++, end);
            appendConjunctionToWhereClause(whereClause, "c.postTime <= ?").append(size);
        }

        if (csc.getStatus() != null) {
            params.add(size++, csc.getStatus());
            appendConjunctionToWhereClause(whereClause, "c.status = ?").append(size);
        }

        if (whereClause.length() != 0) {
            queryString.append(" WHERE ").append(whereClause);
        }
        if (csc.isReverseChrono()) {
            queryString.append(" ORDER BY c.postTime DESC");
        } else {
            queryString.append(" ORDER BY c.postTime ASC");
        }

        TypedQuery<WeblogEntryComment> query = strategy.getDynamicQuery(
                queryString.toString(), WeblogEntryComment.class);
        setFirstMax(query, csc.getOffset(), csc.getMaxResults());
        for (int i = 0; i < params.size(); i++) {
            query.setParameter(i + 1, params.get(i));
        }
        return query.getResultList();
    }

    @Override
    public int removeMatchingComments(
            Weblog weblog,
            WeblogEntry entry,
            String searchString,
            Date startDate,
            Date endDate,
            ApprovalStatus status) throws WebloggerException {

        CommentSearchCriteria csc = new CommentSearchCriteria();
        csc.setWeblog(weblog);
        csc.setEntry(entry);
        csc.setSearchText(searchString);
        csc.setStartDate(startDate);
        csc.setEndDate(endDate);
        csc.setStatus(status);

        List<WeblogEntryComment> comments = getComments(csc);
        int count = 0;
        for (WeblogEntryComment comment : comments) {
            removeComment(comment);
            count++;
        }
        return count;
    }

    @Override
    public long getCommentCount() throws WebloggerException {
        TypedQuery<Long> q = strategy.getNamedQuery(
                "WeblogEntryComment.getCountAllDistinctByStatus", Long.class);
        q.setParameter(1, ApprovalStatus.APPROVED);
        return q.getResultList().get(0);
    }

    @Override
    public long getCommentCount(Weblog website) throws WebloggerException {
        TypedQuery<Long> q = strategy.getNamedQuery(
                "WeblogEntryComment.getCountDistinctByWebsite&Status", Long.class);
        q.setParameter(1, website);
        q.setParameter(2, ApprovalStatus.APPROVED);
        return q.getResultList().get(0);
    }

    @Override
    public List<StatCount> getMostCommentedWeblogEntries(Weblog website,
            Date startDate, Date endDate, int offset, int length) throws WebloggerException {

        TypedQuery<WeblogEntryComment> query;
        List<WeblogEntryComment> queryResults;

        Timestamp end = new Timestamp(endDate != null ? endDate.getTime() : new Date().getTime());

        if (website != null) {
            if (startDate != null) {
                Timestamp start = new Timestamp(startDate.getTime());
                query = strategy.getNamedQuery(
                        "WeblogEntryComment.getMostCommentedWeblogEntryByWebsite&EndDate&StartDate",
                        WeblogEntryComment.class);
                query.setParameter(1, website);
                query.setParameter(2, end);
                query.setParameter(3, start);
            } else {
                query = strategy.getNamedQuery(
                        "WeblogEntryComment.getMostCommentedWeblogEntryByWebsite&EndDate",
                        WeblogEntryComment.class);
                query.setParameter(1, website);
                query.setParameter(2, end);
            }
        } else {
            if (startDate != null) {
                Timestamp start = new Timestamp(startDate.getTime());
                query = strategy.getNamedQuery(
                        "WeblogEntryComment.getMostCommentedWeblogEntryByEndDate&StartDate",
                        WeblogEntryComment.class);
                query.setParameter(1, end);
                query.setParameter(2, start);
            } else {
                query = strategy.getNamedQuery(
                        "WeblogEntryComment.getMostCommentedWeblogEntryByEndDate",
                        WeblogEntryComment.class);
                query.setParameter(1, end);
            }
        }
        setFirstMax(query, offset, length);
        queryResults = query.getResultList();
        List<StatCount> results = new ArrayList<>();
        if (queryResults != null) {
            for (Object obj : queryResults) {
                Object[] row = (Object[]) obj;
                StatCount sc = new StatCount(
                        (String) row[1], // weblog handle
                        (String) row[2], // entry anchor
                        (String) row[3], // entry title
                        "statCount.weblogEntryCommentCountType", // stat desc
                        ((Long) row[0])); // count
                sc.setWeblogHandle((String) row[1]);
                results.add(sc);
            }
        }
        // Original query ordered by desc count.
        // JPA QL doesn't allow queries to be ordered by aggregates; do it in memory
        results.sort(STAT_COUNT_COUNT_REVERSE_COMPARATOR);

        return results;
    }

    /**
     * Appends given expression to given whereClause. If whereClause already
     * has other conditions, an " AND " is also appended before appending
     * the expression.
     */
    private static StringBuilder appendConjunctionToWhereClause(StringBuilder whereClause,
            String expression) {
        if (whereClause.length() != 0 && expression.length() != 0) {
            whereClause.append(" AND ");
        }
        return whereClause.append(expression);
    }

    private static void setFirstMax(Query query, int offset, int length) {
        if (offset != 0) {
            query.setFirstResult(offset);
        }
        if (length != -1) {
            query.setMaxResults(length);
        }
    }
}
