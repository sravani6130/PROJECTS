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

package org.apache.roller.weblogger.business.jpa.query.handlers;

import org.apache.roller.weblogger.business.jpa.query.QueryCriterionHandler;
import org.apache.roller.weblogger.pojos.WeblogEntrySearchCriteria;

import java.util.List;

/**
 * Handler for sort order criterion in entry queries.
 * Applies ORDER BY clause based on sort settings.
 */
public class SortOrderCriterionHandler implements QueryCriterionHandler<WeblogEntrySearchCriteria> {

    @Override
    public boolean applyCriterion(StringBuilder queryString, List<Object> params, WeblogEntrySearchCriteria criteria) {
        // Determine sort column
        if (criteria.getSortBy() != null &&
                criteria.getSortBy().equals(WeblogEntrySearchCriteria.SortBy.UPDATE_TIME)) {
            queryString.append(" ORDER BY e.updateTime ");
        } else {
            queryString.append(" ORDER BY e.pubTime ");
        }

        // Determine sort direction
        if (criteria.getSortOrder() != null &&
                criteria.getSortOrder().equals(WeblogEntrySearchCriteria.SortOrder.ASCENDING)) {
            queryString.append("ASC ");
        } else {
            queryString.append("DESC ");
        }

        return true; // Always applies sort
    }
}
