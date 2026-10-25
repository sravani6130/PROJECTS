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
import org.apache.roller.weblogger.pojos.WeblogCategory;

/**
 * Service interface for weblog category operations.
 * 
 * This service encapsulates all category-related business logic,
 * extracted from WeblogEntryManager to improve cohesion and
 * reduce the complexity of the manager class.
 */
public interface WeblogCategoryService {

    /**
     * Save a weblog category.
     * 
     * @param category The category to save
     * @throws WebloggerException If there is an error saving
     */
    void saveWeblogCategory(WeblogCategory category) throws WebloggerException;

    /**
     * Remove a weblog category.
     * 
     * @param category The category to remove
     * @throws WebloggerException If category has entries or there is an error
     */
    void removeWeblogCategory(WeblogCategory category) throws WebloggerException;

    /**
     * Move all entries from source category to destination category.
     * 
     * @param srcCat  Source category
     * @param destCat Destination category
     * @throws WebloggerException If there is an error moving entries
     */
    void moveWeblogCategoryContents(WeblogCategory srcCat, WeblogCategory destCat)
            throws WebloggerException;

    /**
     * Get category by id.
     * 
     * @param id The category id
     * @return The category or null if not found
     * @throws WebloggerException If there is an error
     */
    WeblogCategory getWeblogCategory(String id) throws WebloggerException;

    /**
     * Get category by weblog and name.
     * 
     * @param weblog       The weblog
     * @param categoryName The category name
     * @return The category or null if not found
     * @throws WebloggerException If there is an error
     */
    WeblogCategory getWeblogCategoryByName(Weblog weblog, String categoryName)
            throws WebloggerException;

    /**
     * Get all categories for a weblog.
     * 
     * @param weblog The weblog
     * @return List of categories
     * @throws WebloggerException If there is an error
     */
    List<WeblogCategory> getWeblogCategories(Weblog weblog) throws WebloggerException;

    /**
     * Check for duplicate category name within a weblog.
     * 
     * @param category The category to check
     * @return true if a category with the same name already exists
     * @throws WebloggerException If there is an error
     */
    boolean isDuplicateWeblogCategoryName(WeblogCategory category) throws WebloggerException;

    /**
     * Check if a category is in use (has entries or is the default blogger
     * category).
     * 
     * @param category The category to check
     * @return true if the category is in use
     * @throws WebloggerException If there is an error
     */
    boolean isWeblogCategoryInUse(WeblogCategory category) throws WebloggerException;
}
