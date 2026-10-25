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
import org.apache.roller.weblogger.pojos.CustomTemplateRendition;
import org.apache.roller.weblogger.pojos.ThemeTemplate.ComponentType;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogTemplate;

/**
 * Service interface for weblog template operations.
 * 
 * This service encapsulates all template-related business logic,
 * extracted from WeblogManager to improve cohesion and
 * reduce the complexity of the manager class.
 */
public interface WeblogTemplateService {

    /**
     * Save a custom weblog template.
     * 
     * @param template The template to save
     * @throws WebloggerException If there is an error saving
     */
    void saveTemplate(WeblogTemplate template) throws WebloggerException;

    /**
     * Save a custom template rendition.
     * 
     * @param rendition The rendition to save
     * @throws WebloggerException If there is an error saving
     */
    void saveTemplateRendition(CustomTemplateRendition rendition) throws WebloggerException;

    /**
     * Remove a custom template.
     * 
     * @param template The template to remove
     * @throws WebloggerException If there is an error removing
     */
    void removeTemplate(WeblogTemplate template) throws WebloggerException;

    /**
     * Get a custom template by id.
     * 
     * @param id The template id
     * @return The template or null if not found
     * @throws WebloggerException If there is an error
     */
    WeblogTemplate getTemplate(String id) throws WebloggerException;

    /**
     * Get a custom template by link.
     * 
     * @param weblog       The weblog
     * @param templateLink The template link
     * @return The template or null if not found
     * @throws WebloggerException If there is an error
     */
    WeblogTemplate getTemplateByLink(Weblog weblog, String templateLink) throws WebloggerException;

    /**
     * Get a custom template by action.
     * 
     * @param weblog The weblog
     * @param action The component type action
     * @return The template or null if not found
     * @throws WebloggerException If there is an error
     */
    WeblogTemplate getTemplateByAction(Weblog weblog, ComponentType action) throws WebloggerException;

    /**
     * Get a custom template by name.
     * 
     * @param weblog       The weblog
     * @param templateName The template name
     * @return The template or null if not found
     * @throws WebloggerException If there is an error
     */
    WeblogTemplate getTemplateByName(Weblog weblog, String templateName) throws WebloggerException;

    /**
     * Get all custom templates for a weblog.
     * 
     * @param weblog The weblog
     * @return List of templates
     * @throws WebloggerException If there is an error
     */
    List<WeblogTemplate> getTemplates(Weblog weblog) throws WebloggerException;
}
