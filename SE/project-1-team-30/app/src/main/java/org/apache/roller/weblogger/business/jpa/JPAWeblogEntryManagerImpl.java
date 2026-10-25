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

import java.util.*;
import java.text.SimpleDateFormat;
import java.sql.Timestamp;
import jakarta.persistence.NoResultException;
import jakarta.persistence.Query;
import jakarta.persistence.TypedQuery;

import org.apache.commons.lang3.StringUtils;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import org.apache.roller.util.RollerConstants;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.Weblogger;
import org.apache.roller.weblogger.pojos.CommentSearchCriteria;
import org.apache.roller.weblogger.pojos.WeblogEntryComment;
import org.apache.roller.weblogger.pojos.WeblogEntryComment.ApprovalStatus;
import org.apache.roller.weblogger.pojos.WeblogEntrySearchCriteria;
import org.apache.roller.weblogger.pojos.WeblogHitCount;
import org.apache.roller.weblogger.pojos.StatCount;
import org.apache.roller.weblogger.pojos.TagStat;
import org.apache.roller.weblogger.pojos.WeblogCategory;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.pojos.WeblogEntry.PubStatus;
import org.apache.roller.weblogger.pojos.WeblogEntryTag;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogEntryAttribute;
import org.apache.roller.util.DateUtil;
import org.apache.roller.weblogger.business.WeblogCategoryService;
import org.apache.roller.weblogger.business.WeblogCommentService;
import org.apache.roller.weblogger.business.WeblogEntryManager;
import org.apache.roller.weblogger.business.WeblogHitCountService;
import org.apache.roller.weblogger.business.WeblogTagService;
import org.apache.roller.weblogger.business.jpa.query.WeblogEntryQueryBuilder;

/**
 * JPAWeblogManagerImpl.java
 *
 * Created on May 31, 2006, 4:08 PM
 *
 */
@com.google.inject.Singleton
public class JPAWeblogEntryManagerImpl implements WeblogEntryManager {

    private static final Log LOG = LogFactory.getLog(JPAWeblogEntryManagerImpl.class);

    private final Weblogger roller;
    private final JPAPersistenceStrategy strategy;

    // Delegated services
    private final WeblogCategoryService categoryService;
    private final WeblogCommentService commentService;
    private final WeblogHitCountService hitCountService;
    private final WeblogTagService tagService;

    // cached mapping of entryAnchors -> entryIds
    private final Map<String, String> entryAnchorToIdMap = Collections.synchronizedMap(new HashMap<String, String>());

    @com.google.inject.Inject
    protected JPAWeblogEntryManagerImpl(
            Weblogger roller,
            JPAPersistenceStrategy strategy,
            WeblogCategoryService categoryService,
            WeblogCommentService commentService,
            WeblogHitCountService hitCountService,
            WeblogTagService tagService) {
        LOG.debug("Instantiating JPA Weblog Manager");
        this.roller = roller;
        this.strategy = strategy;
        this.categoryService = categoryService;
        this.commentService = commentService;
        this.hitCountService = hitCountService;
        this.tagService = tagService;
    }

    /**
     * @inheritDoc
     */
    @Override
    public void saveWeblogCategory(WeblogCategory cat) throws WebloggerException {
        categoryService.saveWeblogCategory(cat);
    }

    /**
     * @inheritDoc
     */
    @Override
    public void removeWeblogCategory(WeblogCategory cat) throws WebloggerException {
        categoryService.removeWeblogCategory(cat);
    }

    /**
     * @inheritDoc
     */
    @Override
    public void moveWeblogCategoryContents(WeblogCategory srcCat, WeblogCategory destCat)
            throws WebloggerException {
        categoryService.moveWeblogCategoryContents(srcCat, destCat);
    }

    /**
     * @inheritDoc
     */
    @Override
    public void saveComment(WeblogEntryComment comment) throws WebloggerException {
        commentService.saveComment(comment);
    }

    /**
     * @inheritDoc
     */
    @Override
    public void removeComment(WeblogEntryComment comment) throws WebloggerException {
        commentService.removeComment(comment);
    }

    /**
     * @inheritDoc
     */
    // TODO: perhaps the createAnchor() and queuePings() items should go outside
    // this method?
    @Override
    public void saveWeblogEntry(WeblogEntry entry) throws WebloggerException {

        if (entry.getCategory() == null) {
            // Entry is invalid without category, so use weblog client cat
            WeblogCategory cat = entry.getWebsite().getBloggerCategory();
            if (cat == null) {
                // Still no category, so use first one found
                cat = entry.getWebsite().getWeblogCategories().iterator().next();
            }
            entry.setCategory(cat);
        }

        // Entry is invalid without local. if missing use weblog default
        if (entry.getLocale() == null) {
            entry.setLocale(entry.getWebsite().getLocale());
        }

        if (entry.getAnchor() == null || entry.getAnchor().isBlank()) {
            entry.setAnchor(this.createAnchor(entry));
        }

        if (entry.isPublished()) {
            // tag aggregates are updated only when entry published in order for
            // tag cloud counts to match published articles
            if (entry.getRefreshAggregates()) {
                // blog entry wasn't published before, so all tags need to be incremented
                for (WeblogEntryTag tag : entry.getTags()) {
                    updateTagCount(tag.getName(), entry.getWebsite(), 1);
                }
            } else {
                // only new tags need to be incremented
                for (WeblogEntryTag tag : entry.getAddedTags()) {
                    updateTagCount(tag.getName(), entry.getWebsite(), 1);
                }
            }
        } else {
            if (entry.getRefreshAggregates()) {
                // blog entry no longer published so need to reduce aggregate count
                for (WeblogEntryTag tag : entry.getTags()) {
                    updateTagCount(tag.getName(), entry.getWebsite(), -1);
                }
            }
        }

        for (WeblogEntryTag tag : entry.getRemovedTags()) {
            removeWeblogEntryTag(tag);
        }

        // if the entry was published to future, set status as SCHEDULED
        // we only consider an entry future published if it is scheduled
        // more than 1 minute into the future
        if (PubStatus.PUBLISHED.equals(entry.getStatus()) &&
                entry.getPubTime().after(new Date(System.currentTimeMillis() + RollerConstants.MIN_IN_MS))) {
            entry.setStatus(PubStatus.SCHEDULED);
        }

        // Store value object (creates new or updates existing)
        entry.setUpdateTime(new Timestamp(new Date().getTime()));

        this.strategy.store(entry);

        // update weblog last modified date. date updated by saveWebsite()
        if (entry.isPublished()) {
            roller.getWeblogManager().saveWeblog(entry.getWebsite());
        }

        if (entry.isPublished()) {
            // Queue applicable pings for this update.
            roller.getAutopingManager().queueApplicableAutoPings(entry);
        }
    }

    /**
     * @inheritDoc
     */
    @Override
    public void removeWeblogEntry(WeblogEntry entry) throws WebloggerException {
        Weblog weblog = entry.getWebsite();

        CommentSearchCriteria csc = new CommentSearchCriteria();
        csc.setEntry(entry);

        // remove comments
        List<WeblogEntryComment> comments = getComments(csc);
        for (WeblogEntryComment comment : comments) {
            this.strategy.remove(comment);
        }

        // remove tag & tag aggregates
        if (entry.getTags() != null) {
            for (WeblogEntryTag tag : entry.getTags()) {
                removeWeblogEntryTag(tag);
            }
        }

        // remove attributes
        if (entry.getEntryAttributes() != null) {
            for (Iterator<WeblogEntryAttribute> it = entry.getEntryAttributes().iterator(); it.hasNext();) {
                WeblogEntryAttribute att = it.next();
                it.remove();
                this.strategy.remove(att);
            }
        }

        // remove entry
        this.strategy.remove(entry);

        // update weblog last modified date. date updated by saveWebsite()
        if (entry.isPublished()) {
            roller.getWeblogManager().saveWeblog(weblog);
        }

        // remove entry from cache mapping
        this.entryAnchorToIdMap.remove(entry.getWebsite().getHandle() + ":" + entry.getAnchor());
    }

    private List<WeblogEntry> getNextPrevEntries(WeblogEntry current, String catName,
            String locale, int maxEntries, boolean next)
            throws WebloggerException {

        if (current == null) {
            LOG.debug("current WeblogEntry cannot be null");
            return Collections.emptyList();
        }

        TypedQuery<WeblogEntry> query;
        WeblogCategory category;

        List<Object> params = new ArrayList<>();
        int size = 0;
        String queryString = "SELECT e FROM WeblogEntry e WHERE ";
        StringBuilder whereClause = new StringBuilder();

        params.add(size++, current.getWebsite());
        whereClause.append("e.website = ?").append(size);

        params.add(size++, PubStatus.PUBLISHED);
        whereClause.append(" AND e.status = ?").append(size);

        if (next) {
            params.add(size++, current.getPubTime());
            whereClause.append(" AND e.pubTime > ?").append(size);
        } else {
            // pub time null if current article not yet published, in Draft view
            if (current.getPubTime() != null) {
                params.add(size++, current.getPubTime());
                whereClause.append(" AND e.pubTime < ?").append(size);
            }
        }

        if (catName != null) {
            category = getWeblogCategoryByName(current.getWebsite(), catName);
            if (category != null) {
                params.add(size++, category);
                whereClause.append(" AND e.category = ?").append(size);
            } else {
                throw new WebloggerException("Cannot find category: " + catName);
            }
        }

        if (locale != null) {
            params.add(size++, locale + '%');
            whereClause.append(" AND e.locale like ?").append(size);
        }

        if (next) {
            whereClause.append(" ORDER BY e.pubTime ASC");
        } else {
            whereClause.append(" ORDER BY e.pubTime DESC");
        }
        query = strategy.getDynamicQuery(queryString + whereClause.toString(), WeblogEntry.class);
        for (int i = 0; i < params.size(); i++) {
            query.setParameter(i + 1, params.get(i));
        }
        query.setMaxResults(maxEntries);

        return query.getResultList();
    }

    /**
     * @inheritDoc
     */
    @Override
    public List<WeblogCategory> getWeblogCategories(Weblog website)
            throws WebloggerException {
        if (website == null) {
            throw new WebloggerException("website is null");
        }

        TypedQuery<WeblogCategory> q = strategy.getNamedQuery(
                "WeblogCategory.getByWeblog", WeblogCategory.class);
        q.setParameter(1, website);
        return q.getResultList();
    }

    /**
     * @inheritDoc
     */
    @Override
    public List<WeblogEntry> getWeblogEntries(WeblogEntrySearchCriteria wesc) throws WebloggerException {
        // Resolve category if specified
        WeblogCategory cat = null;
        if (StringUtils.isNotEmpty(wesc.getCatName()) && wesc.getWeblog() != null) {
            cat = getWeblogCategoryByName(wesc.getWeblog(), wesc.getCatName());
        }

        // Use query builder to construct query (Strategy pattern reduces cognitive
        // complexity)
        WeblogEntryQueryBuilder queryBuilder = new WeblogEntryQueryBuilder();
        WeblogEntryQueryBuilder.QueryResult result = queryBuilder.buildQuery(wesc, cat);

        // Execute query
        TypedQuery<WeblogEntry> query = strategy.getDynamicQuery(result.getQueryString(), WeblogEntry.class);
        for (int i = 0; i < result.getParams().size(); i++) {
            query.setParameter(i + 1, result.getParams().get(i));
        }

        setFirstMax(query, wesc.getOffset(), wesc.getMaxResults());
        return query.getResultList();
    }

    /**
     * @inheritDoc
     */
    @Override
    public List<WeblogEntry> getWeblogEntriesPinnedToMain(Integer max)
            throws WebloggerException {
        TypedQuery<WeblogEntry> query = strategy.getNamedQuery(
                "WeblogEntry.getByPinnedToMain&statusOrderByPubTimeDesc", WeblogEntry.class);
        query.setParameter(1, Boolean.TRUE);
        query.setParameter(2, PubStatus.PUBLISHED);
        if (max != null) {
            query.setMaxResults(max);
        }
        return query.getResultList();
    }

    @Override
    public void removeWeblogEntryAttribute(String name, WeblogEntry entry)
            throws WebloggerException {

        // seems silly, why is this not done in WeblogEntry?

        for (Iterator<WeblogEntryAttribute> it = entry.getEntryAttributes().iterator(); it.hasNext();) {
            WeblogEntryAttribute entryAttribute = it.next();
            if (entryAttribute.getName().equals(name)) {

                // Remove it from database
                this.strategy.remove(entryAttribute);

                // Remove it from the collection
                it.remove();
            }
        }
    }

    private void removeWeblogEntryTag(WeblogEntryTag tag) throws WebloggerException {
        if (tag.getWeblogEntry().isPublished()) {
            updateTagCount(tag.getName(), tag.getWeblogEntry().getWebsite(), -1);
        }
        this.strategy.remove(tag);
    }

    /**
     * @inheritDoc
     */
    @Override
    public WeblogEntry getWeblogEntryByAnchor(Weblog website,
            String anchor) throws WebloggerException {

        if (website == null) {
            throw new WebloggerException("Website is null");
        }

        if (anchor == null) {
            throw new WebloggerException("Anchor is null");
        }

        // mapping key is combo of weblog + anchor
        String mappingKey = website.getHandle() + ":" + anchor;

        // check cache first
        // NOTE: if we ever allow changing anchors then this needs updating
        if (this.entryAnchorToIdMap.containsKey(mappingKey)) {

            WeblogEntry entry = this.getWeblogEntry(this.entryAnchorToIdMap.get(mappingKey));
            if (entry != null) {
                LOG.debug("entryAnchorToIdMap CACHE HIT - " + mappingKey);
                return entry;
            } else {
                // mapping hit with lookup miss? mapping must be old, remove it
                this.entryAnchorToIdMap.remove(mappingKey);
            }
        }

        // cache failed, do lookup
        TypedQuery<WeblogEntry> q = strategy.getNamedQuery(
                "WeblogEntry.getByWebsite&AnchorOrderByPubTimeDesc", WeblogEntry.class);
        q.setParameter(1, website);
        q.setParameter(2, anchor);
        WeblogEntry entry;
        try {
            entry = q.getSingleResult();
        } catch (NoResultException e) {
            entry = null;
        }

        // add mapping to cache
        if (entry != null) {
            LOG.debug("entryAnchorToIdMap CACHE MISS - " + mappingKey);
            this.entryAnchorToIdMap.put(mappingKey, entry.getId());
        }
        return entry;
    }

    /**
     * @inheritDoc
     */
    @Override
    public String createAnchor(WeblogEntry entry) throws WebloggerException {
        // Check for uniqueness of anchor
        String base = entry.createAnchorBase();
        String name = base;
        int count = 0;

        while (true) {
            if (count > 0) {
                name = base + count;
            }

            TypedQuery<WeblogEntry> q = strategy.getNamedQuery(
                    "WeblogEntry.getByWebsite&Anchor", WeblogEntry.class);
            q.setParameter(1, entry.getWebsite());
            q.setParameter(2, name);
            List<WeblogEntry> results = q.getResultList();

            if (results.isEmpty()) {
                break;
            } else {
                count++;
            }
        }
        return name;
    }

    /**
     * @inheritDoc
     */
    @Override
    public boolean isDuplicateWeblogCategoryName(WeblogCategory cat)
            throws WebloggerException {
        return (getWeblogCategoryByName(
                cat.getWeblog(), cat.getName()) != null);
    }

    /**
     * @inheritDoc
     */
    @Override
    public boolean isWeblogCategoryInUse(WeblogCategory cat)
            throws WebloggerException {
        if (cat.getWeblog().getBloggerCategory().equals(cat)) {
            return true;
        }
        TypedQuery<WeblogEntry> q = strategy.getNamedQuery("WeblogEntry.getByCategory", WeblogEntry.class);
        q.setParameter(1, cat);
        int entryCount = q.getResultList().size();
        return entryCount > 0;
    }

    /**
     * @inheritDoc
     */
    @Override
    public List<WeblogEntryComment> getComments(CommentSearchCriteria csc) throws WebloggerException {
        return commentService.getComments(csc);
    }

    /**
     * @inheritDoc
     */
    @Override
    public int removeMatchingComments(
            Weblog weblog,
            WeblogEntry entry,
            String searchString,
            Date startDate,
            Date endDate,
            ApprovalStatus status) throws WebloggerException {
        return commentService.removeMatchingComments(weblog, entry, searchString, startDate, endDate, status);
    }

    /**
     * @inheritDoc
     */
    @Override
    public WeblogCategory getWeblogCategory(String id) throws WebloggerException {
        return categoryService.getWeblogCategory(id);
    }

    // --------------------------------------------- WeblogCategory Queries

    /**
     * @inheritDoc
     */
    @Override
    public WeblogCategory getWeblogCategoryByName(Weblog weblog, String categoryName)
            throws WebloggerException {
        return categoryService.getWeblogCategoryByName(weblog, categoryName);
    }

    /**
     * @inheritDoc
     */
    @Override
    public WeblogEntryComment getComment(String id) throws WebloggerException {
        return commentService.getComment(id);
    }

    /**
     * @inheritDoc
     */
    @Override
    public WeblogEntry getWeblogEntry(String id) throws WebloggerException {
        return (WeblogEntry) strategy.load(WeblogEntry.class, id);
    }

    /**
     * @inheritDoc
     */
    @Override
    public Map<Date, List<WeblogEntry>> getWeblogEntryObjectMap(WeblogEntrySearchCriteria wesc)
            throws WebloggerException {
        TreeMap<Date, List<WeblogEntry>> map = new TreeMap<>(Collections.reverseOrder());

        List<WeblogEntry> entries = getWeblogEntries(wesc);

        Calendar cal = Calendar.getInstance();
        if (wesc.getWeblog() != null) {
            cal.setTimeZone(wesc.getWeblog().getTimeZoneInstance());
        }

        for (WeblogEntry entry : entries) {
            Date sDate = DateUtil.getNoonOfDay(entry.getPubTime(), cal);
            List<WeblogEntry> dayEntries = map.computeIfAbsent(sDate, k -> new ArrayList<>());
            dayEntries.add(entry);
        }
        return map;
    }

    /**
     * @inheritDoc
     */
    @Override
    public Map<Date, String> getWeblogEntryStringMap(WeblogEntrySearchCriteria wesc) throws WebloggerException {
        TreeMap<Date, String> map = new TreeMap<>(Collections.reverseOrder());

        List<WeblogEntry> entries = getWeblogEntries(wesc);

        Calendar cal = Calendar.getInstance();
        SimpleDateFormat formatter = DateUtil.get8charDateFormat();
        if (wesc.getWeblog() != null) {
            TimeZone tz = wesc.getWeblog().getTimeZoneInstance();
            cal.setTimeZone(tz);
            formatter.setTimeZone(tz);
        }

        for (WeblogEntry entry : entries) {
            Date sDate = DateUtil.getNoonOfDay(entry.getPubTime(), cal);
            if (map.get(sDate) == null) {
                map.put(sDate, formatter.format(sDate));
            }
        }
        return map;
    }

    /**
     * @inheritDoc
     */
    @Override
    public List<StatCount> getMostCommentedWeblogEntries(Weblog website,
            Date startDate, Date endDate, int offset, int length) throws WebloggerException {
        return commentService.getMostCommentedWeblogEntries(website, startDate, endDate, offset, length);
    }

    /**
     * @inheritDoc
     */
    @Override
    public WeblogEntry getNextEntry(WeblogEntry current,
            String catName, String locale) throws WebloggerException {
        WeblogEntry entry = null;
        List<WeblogEntry> entryList = getNextPrevEntries(current, catName, locale, 1, true);
        if (entryList != null && !entryList.isEmpty()) {
            entry = entryList.get(0);
        }
        return entry;
    }

    /**
     * @inheritDoc
     */
    @Override
    public WeblogEntry getPreviousEntry(WeblogEntry current,
            String catName, String locale) throws WebloggerException {
        WeblogEntry entry = null;
        List<WeblogEntry> entryList = getNextPrevEntries(current, catName, locale, 1, false);
        if (entryList != null && !entryList.isEmpty()) {
            entry = entryList.get(0);
        }
        return entry;
    }

    /**
     * @inheritDoc
     */
    @Override
    public void release() {
    }

    /**
     * @inheritDoc
     */
    @Override
    public void applyCommentDefaultsToEntries(Weblog website)
            throws WebloggerException {
        if (LOG.isDebugEnabled()) {
            LOG.debug("applyCommentDefaults");
        }

        // TODO: Non-standard JPA bulk update, using parameter values in set clause
        Query q = strategy.getNamedUpdate(
                "WeblogEntry.updateAllowComments&CommentDaysByWebsite");
        q.setParameter(1, website.getDefaultAllowComments());
        q.setParameter(2, website.getDefaultCommentDays());
        q.setParameter(3, website);
        q.executeUpdate();
    }

    /**
     * @inheritDoc
     */
    @Override
    public List<TagStat> getPopularTags(Weblog website, Date startDate, int offset, int limit)
            throws WebloggerException {
        return tagService.getPopularTags(website, startDate, offset, limit);
    }

    /**
     * @inheritDoc
     */
    @Override
    public List<TagStat> getTags(Weblog website, String sortBy,
            String startsWith, int offset, int limit) throws WebloggerException {
        return tagService.getTags(website, sortBy, startsWith, offset, limit);
    }

    /**
     * @inheritDoc
     */
    @Override
    public boolean getTagComboExists(List<String> tags, Weblog weblog) throws WebloggerException {
        return tagService.getTagComboExists(tags, weblog);
    }

    /**
     * This method maintains the tag aggregate table up-to-date with total counts.
     * More specifically every time this method is called it will act upon exactly
     * two
     * rows in the database (tag,website,count), one with website matching the
     * argument
     * passed and one where website is null. If the count ever reaches zero, the row
     * must
     * be deleted.
     *
     * @param name    The tag name
     * @param website The website to used when updating the stats.
     * @param amount  The amount to increment the tag count (it can be positive or
     *                negative).
     * @throws WebloggerException
     */
    private void updateTagCount(String name, Weblog website, int amount) throws WebloggerException {
        tagService.updateTagCount(name, website, amount);
    }

    /**
     * @inheritDoc
     */
    @Override
    public WeblogHitCount getHitCount(String id) throws WebloggerException {
        return hitCountService.getHitCount(id);
    }

    /**
     * @inheritDoc
     */
    @Override
    public WeblogHitCount getHitCountByWeblog(Weblog weblog) throws WebloggerException {
        return hitCountService.getHitCountByWeblog(weblog);
    }

    /**
     * @inheritDoc
     */
    @Override
    public List<WeblogHitCount> getHotWeblogs(int sinceDays, int offset, int length)
            throws WebloggerException {
        return hitCountService.getHotWeblogs(sinceDays, offset, length);
    }

    private static void setFirstMax(Query query, int offset, int length) {
        if (offset != 0) {
            query.setFirstResult(offset);
        }
        if (length != -1) {
            query.setMaxResults(length);
        }
    }

    public static Date getStartDateNow(int sinceDays) {
        Calendar cal = Calendar.getInstance();
        cal.setTime(new Date());
        cal.add(Calendar.DATE, -1 * sinceDays);
        return cal.getTime();
    }

    /**
     * @inheritDoc
     */
    @Override
    public void saveHitCount(WeblogHitCount hitCount) throws WebloggerException {
        hitCountService.saveHitCount(hitCount);
    }

    /**
     * @inheritDoc
     */
    @Override
    public void removeHitCount(WeblogHitCount hitCount) throws WebloggerException {
        hitCountService.removeHitCount(hitCount);
    }

    /**
     * @inheritDoc
     */
    @Override
    public void incrementHitCount(Weblog weblog, int amount) throws WebloggerException {
        hitCountService.incrementHitCount(weblog, amount);
    }

    /**
     * @inheritDoc
     */
    @Override
    public void resetAllHitCounts() throws WebloggerException {
        hitCountService.resetAllHitCounts();
    }

    /**
     * @inheritDoc
     */
    @Override
    public void resetHitCount(Weblog weblog) throws WebloggerException {
        hitCountService.resetHitCount(weblog);
    }

    /**
     * @inheritDoc
     */
    @Override
    public long getCommentCount() throws WebloggerException {
        return commentService.getCommentCount();
    }

    /**
     * @inheritDoc
     */
    @Override
    public long getCommentCount(Weblog website) throws WebloggerException {
        return commentService.getCommentCount(website);
    }

    /**
     * @inheritDoc
     */
    @Override
    public long getEntryCount() throws WebloggerException {
        TypedQuery<Long> q = strategy.getNamedQuery(
                "WeblogEntry.getCountDistinctByStatus", Long.class);
        q.setParameter(1, PubStatus.PUBLISHED);
        return q.getResultList().get(0);
    }

    /**
     * @inheritDoc
     */
    @Override
    public long getEntryCount(Weblog website) throws WebloggerException {
        TypedQuery<Long> q = strategy.getNamedQuery(
                "WeblogEntry.getCountDistinctByStatus&Website", Long.class);
        q.setParameter(1, PubStatus.PUBLISHED);
        q.setParameter(2, website);
        return q.getResultList().get(0);
    }

}
