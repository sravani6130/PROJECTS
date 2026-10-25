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

import java.util.List;

import jakarta.persistence.NoResultException;
import jakarta.persistence.TypedQuery;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.WeblogManager;
import org.apache.roller.weblogger.business.WeblogTemplateService;
import org.apache.roller.weblogger.business.Weblogger;
import org.apache.roller.weblogger.pojos.CustomTemplateRendition;
import org.apache.roller.weblogger.pojos.ThemeTemplate.ComponentType;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogTemplate;

/**
 * JPA implementation of WeblogTemplateService.
 * 
 * This service handles all weblog template operations, extracted from
 * JPAWeblogManagerImpl to improve cohesion and reduce class complexity.
 */
@com.google.inject.Singleton
public class JPAWeblogTemplateServiceImpl implements WeblogTemplateService {

    private static final Log LOG = LogFactory.getLog(JPAWeblogTemplateServiceImpl.class);

    private final Weblogger roller;
    private final JPAPersistenceStrategy strategy;

    @com.google.inject.Inject
    protected JPAWeblogTemplateServiceImpl(Weblogger roller, JPAPersistenceStrategy strategy) {
        LOG.debug("Instantiating JPA Weblog Template Service");
        this.roller = roller;
        this.strategy = strategy;
    }

    @Override
    public void saveTemplate(WeblogTemplate template) throws WebloggerException {
        this.strategy.store(template);

        // update weblog last modified date
        WeblogManager weblogManager = roller.getWeblogManager();
        weblogManager.saveWeblog(template.getWeblog());
    }

    @Override
    public void saveTemplateRendition(CustomTemplateRendition rendition) throws WebloggerException {
        this.strategy.store(rendition);

        // update weblog last modified date
        WeblogManager weblogManager = roller.getWeblogManager();
        weblogManager.saveWeblog(rendition.getWeblogTemplate().getWeblog());
    }

    @Override
    public void removeTemplate(WeblogTemplate template) throws WebloggerException {
        this.strategy.remove(template);

        // update weblog last modified date
        WeblogManager weblogManager = roller.getWeblogManager();
        weblogManager.saveWeblog(template.getWeblog());
    }

    @Override
    public WeblogTemplate getTemplate(String id) throws WebloggerException {
        // Don't hit database for templates stored on disk
        if (id != null && id.endsWith(".vm")) {
            return null;
        }

        return (WeblogTemplate) this.strategy.load(WeblogTemplate.class, id);
    }

    @Override
    public WeblogTemplate getTemplateByLink(Weblog weblog, String templateLink)
            throws WebloggerException {

        if (weblog == null) {
            throw new WebloggerException("weblog is null");
        }

        if (templateLink == null) {
            throw new WebloggerException("templateLink is null");
        }

        TypedQuery<WeblogTemplate> query = strategy.getNamedQuery(
                "WeblogTemplate.getByWeblog&Link", WeblogTemplate.class);
        query.setParameter(1, weblog);
        query.setParameter(2, templateLink);
        try {
            return query.getSingleResult();
        } catch (NoResultException e) {
            return null;
        }
    }

    @Override
    public WeblogTemplate getTemplateByAction(Weblog weblog, ComponentType action)
            throws WebloggerException {

        if (weblog == null) {
            throw new WebloggerException("weblog is null");
        }

        if (action == null) {
            throw new WebloggerException("Action name is null");
        }

        TypedQuery<WeblogTemplate> query = strategy.getNamedQuery(
                "WeblogTemplate.getByAction", WeblogTemplate.class);
        query.setParameter(1, weblog);
        query.setParameter(2, action);
        try {
            return query.getSingleResult();
        } catch (NoResultException e) {
            return null;
        }
    }

    @Override
    public WeblogTemplate getTemplateByName(Weblog weblog, String templateName)
            throws WebloggerException {

        if (weblog == null) {
            throw new WebloggerException("weblog is null");
        }

        if (templateName == null) {
            throw new WebloggerException("Template name is null");
        }

        TypedQuery<WeblogTemplate> query = strategy.getNamedQuery(
                "WeblogTemplate.getByWeblog&Name", WeblogTemplate.class);
        query.setParameter(1, weblog);
        query.setParameter(2, templateName);
        try {
            return query.getSingleResult();
        } catch (NoResultException e) {
            return null;
        }
    }

    @Override
    public List<WeblogTemplate> getTemplates(Weblog weblog) throws WebloggerException {
        if (weblog == null) {
            throw new WebloggerException("weblog is null");
        }
        TypedQuery<WeblogTemplate> q = strategy.getNamedQuery(
                "WeblogTemplate.getByWeblogOrderByName", WeblogTemplate.class);
        q.setParameter(1, weblog);
        return q.getResultList();
    }
}
