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

import org.apache.commons.lang3.BooleanUtils;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.pings.AutoPingManager;
import org.apache.roller.weblogger.business.pings.PingTargetManager;
import org.apache.roller.weblogger.config.WebloggerConfig;

import jakarta.persistence.NoResultException;
import jakarta.persistence.Query;
import jakarta.persistence.TypedQuery;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

import org.apache.roller.weblogger.business.MediaFileManager;
import org.apache.roller.weblogger.business.UserManager;
import org.apache.roller.weblogger.business.PermissionManager;
import org.apache.roller.weblogger.business.WeblogEntryManager;
import org.apache.roller.weblogger.business.WeblogManager;
import org.apache.roller.weblogger.business.WeblogTemplateService;
import org.apache.roller.weblogger.business.Weblogger;
import org.apache.roller.weblogger.business.WebloggerFactory;
import org.apache.roller.weblogger.business.jpa.query.WeblogQueryBuilder;
import org.apache.roller.weblogger.pojos.AutoPing;
import org.apache.roller.weblogger.pojos.CustomTemplateRendition;
import org.apache.roller.weblogger.pojos.PingQueueEntry;
import org.apache.roller.weblogger.pojos.PingTarget;
import org.apache.roller.weblogger.pojos.StatCount;
import org.apache.roller.weblogger.pojos.StatCountCountComparator;
import org.apache.roller.weblogger.pojos.TagStat;
import org.apache.roller.weblogger.pojos.ThemeTemplate.ComponentType;
import org.apache.roller.weblogger.pojos.User;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogBookmark;
import org.apache.roller.weblogger.pojos.WeblogBookmarkFolder;
import org.apache.roller.weblogger.pojos.WeblogCategory;
import org.apache.roller.weblogger.pojos.WeblogEntry;
import org.apache.roller.weblogger.pojos.WeblogEntryTag;
import org.apache.roller.weblogger.pojos.WeblogEntryTagAggregate;
import org.apache.roller.weblogger.pojos.WeblogPermission;
import org.apache.roller.weblogger.pojos.WeblogTemplate;

/*
 * JPAWeblogManagerImpl.java
 * Created on May 31, 2006, 4:08 PM
 */
@com.google.inject.Singleton
public class JPAWeblogManagerImpl implements WeblogManager {

    private static final Log log = LogFactory.getLog(JPAWeblogManagerImpl.class);

    private static final Comparator<StatCount> STAT_COUNT_COUNT_REVERSE_COMPARATOR = Collections
            .reverseOrder(StatCountCountComparator.getInstance());

    private final Weblogger roller;
    private final JPAPersistenceStrategy strategy;
    private final WeblogTemplateService templateService;

    // cached mapping of weblogHandles -> weblogIds
    private final Map<String, String> weblogHandleToIdMap = Collections.synchronizedMap(new HashMap<>());

    @com.google.inject.Inject
    protected JPAWeblogManagerImpl(
            Weblogger roller,
            JPAPersistenceStrategy strat,
            WeblogTemplateService templateService) {
        log.debug("Instantiating JPA Weblog Manager");
        this.roller = roller;
        this.strategy = strat;
        this.templateService = templateService;
    }

    @Override
    public void release() {
    }

    /**
     * Update existing weblog.
     */
    @Override
    public void saveWeblog(Weblog weblog) throws WebloggerException {

        weblog.setLastModified(new java.util.Date());
        strategy.store(weblog);
    }

    @Override
    public void removeWeblog(Weblog weblog) throws WebloggerException {

        // remove contents first, then remove weblog
        this.removeWeblogContents(weblog);
        this.strategy.remove(weblog);

        // remove entry from cache mapping
        this.weblogHandleToIdMap.remove(weblog.getHandle());
    }

    /**
     * convenience method for removing contents of a weblog.
     * TODO BACKEND: use manager methods instead of queries here
     */
    private void removeWeblogContents(Weblog weblog)
            throws WebloggerException {

        UserManager umgr = roller.getUserManager();
        WeblogEntryManager emgr = roller.getWeblogEntryManager();

        // remove tags
        TypedQuery<WeblogEntryTag> tagQuery = strategy.getNamedQuery("WeblogEntryTag.getByWeblog",
                WeblogEntryTag.class);
        tagQuery.setParameter(1, weblog);
        List<WeblogEntryTag> results = tagQuery.getResultList();

        for (WeblogEntryTag tagData : results) {
            if (tagData.getWeblogEntry() != null) {
                tagData.getWeblogEntry().getTags().remove(tagData);
            }
            this.strategy.remove(tagData);
        }

        // remove site tag aggregates
        List<TagStat> tags = emgr.getTags(weblog, null, null, 0, -1);
        updateTagAggregates(tags);

        // delete all weblog tag aggregates
        Query removeAggs = strategy.getNamedUpdate(
                "WeblogEntryTagAggregate.removeByWeblog");
        removeAggs.setParameter(1, weblog);
        removeAggs.executeUpdate();

        // delete all bad counts
        Query removeCounts = strategy.getNamedUpdate(
                "WeblogEntryTagAggregate.removeByTotalLessEqual");
        removeCounts.setParameter(1, 0);
        removeCounts.executeUpdate();

        // Remove the weblog's ping queue entries
        TypedQuery<PingQueueEntry> q = strategy.getNamedQuery("PingQueueEntry.getByWebsite", PingQueueEntry.class);
        q.setParameter(1, weblog);
        List<PingQueueEntry> queueEntries = q.getResultList();
        for (Object obj : queueEntries) {
            this.strategy.remove(obj);
        }

        // Remove the weblog's auto ping configurations
        AutoPingManager autoPingMgr = roller.getAutopingManager();
        List<AutoPing> autopings = autoPingMgr.getAutoPingsByWebsite(weblog);
        for (AutoPing autoPing : autopings) {
            this.strategy.remove(autoPing);
        }

        // remove associated templates
        TypedQuery<WeblogTemplate> templateQuery = strategy.getNamedQuery("WeblogTemplate.getByWeblog",
                WeblogTemplate.class);
        templateQuery.setParameter(1, weblog);
        List<WeblogTemplate> templates = templateQuery.getResultList();

        for (WeblogTemplate template : templates) {
            this.strategy.remove(template);
        }

        // remove folders (including bookmarks)
        TypedQuery<WeblogBookmarkFolder> folderQuery = strategy.getNamedQuery("WeblogBookmarkFolder.getByWebsite",
                WeblogBookmarkFolder.class);
        folderQuery.setParameter(1, weblog);
        List<WeblogBookmarkFolder> folders = folderQuery.getResultList();
        for (WeblogBookmarkFolder wbf : folders) {
            this.strategy.remove(wbf);
        }

        // remove mediafile metadata
        // remove uploaded files
        MediaFileManager mfmgr = WebloggerFactory.getWeblogger().getMediaFileManager();
        mfmgr.removeAllFiles(weblog);
        // List<MediaFileDirectory> dirs = mmgr.getMediaFileDirectories(weblog);
        // for (MediaFileDirectory dir : dirs) {
        // this.strategy.remove(dir);
        // }
        this.strategy.flush();

        // remove entries
        TypedQuery<WeblogEntry> refQuery = strategy.getNamedQuery("WeblogEntry.getByWebsite", WeblogEntry.class);
        refQuery.setParameter(1, weblog);
        List<WeblogEntry> entries = refQuery.getResultList();
        for (WeblogEntry entry : entries) {
            emgr.removeWeblogEntry(entry);
        }
        this.strategy.flush();

        // delete all weblog categories
        Query removeCategories = strategy.getNamedUpdate("WeblogCategory.removeByWeblog");
        removeCategories.setParameter(1, weblog);
        removeCategories.executeUpdate();

        // remove permissions
        PermissionManager pmgr = roller.getPermissionManager();
        for (WeblogPermission perm : pmgr.getWeblogPermissions(weblog)) {
            pmgr.revokeWeblogPermission(perm.getWeblog(), perm.getUser(), WeblogPermission.ALL_ACTIONS);
        }

        // flush the changes before returning. This is required as there is a
        // circular dependency between WeblogCategory and Weblog
        this.strategy.flush();
    }

    protected void updateTagAggregates(List<TagStat> tags) throws WebloggerException {
        for (TagStat stat : tags) {
            TypedQuery<WeblogEntryTagAggregate> query = strategy.getNamedQueryCommitFirst(
                    "WeblogEntryTagAggregate.getByName&WebsiteNullOrderByLastUsedDesc", WeblogEntryTagAggregate.class);
            query.setParameter(1, stat.getName());
            try {
                WeblogEntryTagAggregate agg = query.getSingleResult();
                agg.setTotal(agg.getTotal() - stat.getCount());
            } catch (NoResultException ignored) {
                // nothing to update
            }
        }
    }

    /**
     * @see org.apache.roller.weblogger.business.WeblogManager#saveTemplate(WeblogTemplate)
     */
    @Override
    public void saveTemplate(WeblogTemplate template) throws WebloggerException {
        templateService.saveTemplate(template);
    }

    @Override
    public void saveTemplateRendition(CustomTemplateRendition rendition) throws WebloggerException {
        templateService.saveTemplateRendition(rendition);
    }

    @Override
    public void removeTemplate(WeblogTemplate template) throws WebloggerException {
        templateService.removeTemplate(template);
    }

    @Override
    public void addWeblog(Weblog newWeblog) throws WebloggerException {
        this.strategy.store(newWeblog);
        this.strategy.flush();
        this.addWeblogContents(newWeblog);
    }

    private void addWeblogContents(Weblog newWeblog)
            throws WebloggerException {

        // grant weblog creator ADMIN permission
        List<String> actions = new ArrayList<>();
        actions.add(WeblogPermission.ADMIN);
        roller.getPermissionManager().grantWeblogPermission(
                newWeblog, newWeblog.getCreator(), actions);

        String cats = WebloggerConfig.getProperty("newuser.categories");
        WeblogCategory firstCat = null;
        if (cats != null) {
            String[] splitcats = cats.split(",");
            for (String split : splitcats) {
                if (split.isBlank()) {
                    continue;
                }
                WeblogCategory c = new WeblogCategory(
                        newWeblog,
                        split,
                        null,
                        null);
                if (firstCat == null) {
                    firstCat = c;
                }
                this.strategy.store(c);
            }
        }

        // Use first category as default for Blogger API
        if (firstCat != null) {
            newWeblog.setBloggerCategory(firstCat);
        }

        this.strategy.store(newWeblog);

        // add default bookmarks
        WeblogBookmarkFolder defaultFolder = new WeblogBookmarkFolder(
                "default", newWeblog);
        this.strategy.store(defaultFolder);

        String blogroll = WebloggerConfig.getProperty("newuser.blogroll");
        if (blogroll != null) {
            String[] splitroll = blogroll.split(",");
            for (String splitItem : splitroll) {
                String[] rollitems = splitItem.split("\\|");
                if (rollitems.length > 1) {
                    WeblogBookmark b = new WeblogBookmark(
                            defaultFolder,
                            rollitems[0],
                            "",
                            rollitems[1].trim(),
                            null,
                            null);
                    this.strategy.store(b);
                }
            }
        }

        roller.getMediaFileManager().createDefaultMediaFileDirectory(newWeblog);

        // flush so that all data up to this point can be available in db
        this.strategy.flush();

        // add any auto enabled ping targets
        PingTargetManager pingTargetMgr = roller.getPingTargetManager();
        AutoPingManager autoPingMgr = roller.getAutopingManager();

        for (PingTarget pingTarget : pingTargetMgr.getCommonPingTargets()) {
            if (pingTarget.isAutoEnabled()) {
                AutoPing autoPing = new AutoPing(
                        null, pingTarget, newWeblog);
                autoPingMgr.saveAutoPing(autoPing);
            }
        }

    }

    @Override
    public Weblog getWeblog(String id) throws WebloggerException {
        return (Weblog) this.strategy.load(Weblog.class, id);
    }

    @Override
    public Weblog getWeblogByHandle(String handle) throws WebloggerException {
        return getWeblogByHandle(handle, Boolean.TRUE);
    }

    /**
     * Return weblog specified by handle.
     */
    @Override
    public Weblog getWeblogByHandle(String handle, Boolean visible) throws WebloggerException {

        if (handle == null) {
            throw new WebloggerException("Handle cannot be null");
        } else if (!isAlphanumeric(handle)) {
            throw new WebloggerException("Invalid handle: '" + handle + "'");
        }

        // check cache first
        // NOTE: if we ever allow changing handles then this needs updating
        String blogID = this.weblogHandleToIdMap.get(handle);
        if (blogID != null) {

            Weblog weblog = this.getWeblog(blogID);
            if (weblog != null) {
                // only return weblog if enabled status matches
                if (visible == null || visible.equals(weblog.getVisible())) {
                    log.debug("weblogHandleToId CACHE HIT - " + handle);
                    return weblog;
                }
            } else {
                // mapping hit with lookup miss? mapping must be old, remove it
                this.weblogHandleToIdMap.remove(handle);
            }
        }

        TypedQuery<Weblog> query = strategy.getNamedQuery("Weblog.getByHandle", Weblog.class);
        query.setParameter(1, handle);
        Weblog weblog;
        try {
            weblog = query.getSingleResult();
        } catch (NoResultException e) {
            weblog = null;
        }

        // add mapping to cache
        if (weblog != null) {
            log.debug("weblogHandleToId CACHE MISS - " + handle);
            this.weblogHandleToIdMap.put(weblog.getHandle(), weblog.getId());
        }

        if (weblog != null &&
                (visible == null || visible.equals(weblog.getVisible()))) {
            return weblog;
        } else {
            return null;
        }
    }

    /**
     * Get weblogs of a user
     */
    @Override
    public List<Weblog> getWeblogs(
            Boolean enabled, Boolean active,
            Date startDate, Date endDate, int offset, int length) throws WebloggerException {

        // Use query builder to construct query (Strategy pattern reduces cognitive
        // complexity)
        WeblogQueryBuilder.WeblogSearchCriteria criteria = new WeblogQueryBuilder.WeblogSearchCriteria();
        criteria.setEnabled(enabled);
        criteria.setActive(active);
        criteria.setStartDate(startDate);
        criteria.setEndDate(endDate);

        WeblogQueryBuilder queryBuilder = new WeblogQueryBuilder();
        WeblogQueryBuilder.QueryResult result = queryBuilder.buildQuery(criteria);

        // Execute query
        TypedQuery<Weblog> query = strategy.getDynamicQuery(result.getQueryString(), Weblog.class);
        if (offset != 0) {
            query.setFirstResult(offset);
        }
        if (length != -1) {
            query.setMaxResults(length);
        }
        for (int i = 0; i < result.getParams().size(); i++) {
            query.setParameter(i + 1, result.getParams().get(i));
        }

        return query.getResultList();
    }

    @Override
    public List<Weblog> getUserWeblogs(User user, boolean enabledOnly) throws WebloggerException {
        List<Weblog> weblogs = new ArrayList<>();
        if (user == null) {
            return weblogs;
        }
        List<WeblogPermission> perms = roller.getPermissionManager().getWeblogPermissions(user);
        for (WeblogPermission perm : perms) {
            Weblog weblog = perm.getWeblog();
            if ((!enabledOnly || weblog.getVisible()) && BooleanUtils.isTrue(weblog.getActive())) {
                weblogs.add(weblog);
            }
        }
        return weblogs;
    }

    @Override
    public List<User> getWeblogUsers(Weblog weblog, boolean enabledOnly) throws WebloggerException {
        List<User> users = new ArrayList<>();
        List<WeblogPermission> perms = roller.getPermissionManager().getWeblogPermissions(weblog);
        for (WeblogPermission perm : perms) {
            User user = perm.getUser();
            if (user == null) {
                log.error("ERROR user is null, userName:" + perm.getUserName());
                continue;
            }
            if (!enabledOnly || user.getEnabled()) {
                users.add(user);
            }
        }
        return users;
    }

    @Override
    public WeblogTemplate getTemplate(String id) throws WebloggerException {
        return templateService.getTemplate(id);
    }

    /**
     * Use JPA directly because Weblogger's Query API does too much allocation.
     */
    @Override
    public WeblogTemplate getTemplateByLink(Weblog weblog, String templateLink)
            throws WebloggerException {
        return templateService.getTemplateByLink(weblog, templateLink);
    }

    /**
     * @see org.apache.roller.weblogger.business.WeblogManager#getTemplateByAction(Weblog,
     *      ComponentType)
     */
    @Override
    public WeblogTemplate getTemplateByAction(Weblog weblog, ComponentType action)
            throws WebloggerException {
        return templateService.getTemplateByAction(weblog, action);
    }

    /**
     * @see org.apache.roller.weblogger.business.WeblogManager#getTemplateByName(Weblog,
     *      java.lang.String)
     */
    @Override
    public WeblogTemplate getTemplateByName(Weblog weblog, String templateName)
            throws WebloggerException {
        return templateService.getTemplateByName(weblog, templateName);
    }

    /**
     * @see org.apache.roller.weblogger.business.WeblogManager#getTemplates(Weblog)
     */
    @Override
    public List<WeblogTemplate> getTemplates(Weblog weblog) throws WebloggerException {
        return templateService.getTemplates(weblog);
    }

    @Override
    public Map<String, Long> getWeblogHandleLetterMap() throws WebloggerException {
        String lc = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        Map<String, Long> results = new TreeMap<>();
        TypedQuery<Long> query = strategy.getNamedQuery(
                "Weblog.getCountByHandleLike", Long.class);
        for (int i = 0; i < 26; i++) {
            char currentChar = lc.charAt(i);
            query.setParameter(1, currentChar + "%");
            List<Long> row = query.getResultList();
            Long count = row.get(0);
            results.put(String.valueOf(currentChar), count);
        }
        return results;
    }

    @Override
    public List<Weblog> getWeblogsByLetter(char letter, int offset, int length)
            throws WebloggerException {
        TypedQuery<Weblog> query = strategy.getNamedQuery(
                "Weblog.getByLetterOrderByHandle", Weblog.class);
        query.setParameter(1, letter + "%");
        if (offset != 0) {
            query.setFirstResult(offset);
        }
        if (length != -1) {
            query.setMaxResults(length);
        }
        return query.getResultList();
    }

    @Override
    public List<StatCount> getMostCommentedWeblogs(Date startDate, Date endDate,
            int offset, int length)
            throws WebloggerException {

        Query query;

        if (endDate == null) {
            endDate = new Date();
        }

        if (startDate != null) {
            Timestamp start = new Timestamp(startDate.getTime());
            Timestamp end = new Timestamp(endDate.getTime());
            query = strategy.getNamedQuery(
                    "WeblogEntryComment.getMostCommentedWebsiteByEndDate&StartDate");
            query.setParameter(1, end);
            query.setParameter(2, start);
        } else {
            Timestamp end = new Timestamp(endDate.getTime());
            query = strategy.getNamedQuery(
                    "WeblogEntryComment.getMostCommentedWebsiteByEndDate");
            query.setParameter(1, end);
        }
        if (offset != 0) {
            query.setFirstResult(offset);
        }
        if (length != -1) {
            query.setMaxResults(length);
        }
        List<?> queryResults = query.getResultList();
        List<StatCount> results = new ArrayList<>();
        if (queryResults != null) {
            for (Object obj : queryResults) {
                Object[] row = (Object[]) obj;
                StatCount sc = new StatCount(
                        (String) row[1], // weblog id
                        (String) row[2], // weblog handle
                        (String) row[3], // weblog name
                        "statCount.weblogCommentCountType", // stat type
                        ((Long) row[0])); // # comments
                sc.setWeblogHandle((String) row[2]);
                results.add(sc);
            }
        }

        // Original query ordered by desc # comments.
        // JPA QL doesn't allow queries to be ordered by aggregates; do it in memory
        results.sort(STAT_COUNT_COUNT_REVERSE_COMPARATOR);

        return results;
    }

    /**
     * Get count of weblogs, active and inactive
     */
    @Override
    public long getWeblogCount() throws WebloggerException {
        List<Long> results = strategy.getNamedQuery(
                "Weblog.getCountAllDistinct", Long.class).getResultList();
        return results.get(0);
    }

    /**
     * Returns true if alphanumeric or '_'.
     */
    private boolean isAlphanumeric(String str) {
        if (str == null) {
            return false;
        }
        for (int i = 0; i < str.length(); i++) {
            if (!Character.isLetterOrDigit(str.charAt(i)) && str.charAt(i) != '_') {
                return false;
            }
        }
        return true;
    }

}
