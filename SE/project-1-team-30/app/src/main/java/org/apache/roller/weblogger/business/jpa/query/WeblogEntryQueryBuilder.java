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

package org.apache.roller.weblogger.business.jpa.query;

import org.apache.roller.weblogger.business.jpa.query.handlers.*;
import org.apache.roller.weblogger.pojos.WeblogCategory;
import org.apache.roller.weblogger.pojos.WeblogEntrySearchCriteria;

import java.util.ArrayList;
import java.util.List;

/**
 * Builder class for constructing WeblogEntry queries.
 * Uses the Strategy pattern with QueryCriterionHandler implementations
 * to handle each search criterion, reducing cognitive complexity.
 */
public class WeblogEntryQueryBuilder {

    /**
     * Result class containing the built query string and parameters.
     */
    public static class QueryResult {
        private final String queryString;
        private final List<Object> params;

        public QueryResult(String queryString, List<Object> params) {
            this.queryString = queryString;
            this.params = params;
        }

        public String getQueryString() {
            return queryString;
        }

        public List<Object> getParams() {
            return params;
        }
    }

    /**
     * Builds a query for WeblogEntry based on the given search criteria.
     *
     * @param wesc     The search criteria
     * @param category The resolved category (or null if not applicable)
     * @return QueryResult containing the query string and parameters
     */
    public QueryResult buildQuery(WeblogEntrySearchCriteria wesc, WeblogCategory category) {
        List<Object> params = new ArrayList<>();
        StringBuilder queryString = new StringBuilder();

        // Build the SELECT clause with optional JOIN for tags
        buildSelectClause(queryString, params, wesc);

        // Apply criterion handlers for WHERE clauses
        List<QueryCriterionHandler<WeblogEntrySearchCriteria>> handlers = createHandlers(category);
        for (QueryCriterionHandler<WeblogEntrySearchCriteria> handler : handlers) {
            handler.applyCriterion(queryString, params, wesc);
        }

        // Apply sort order (always last)
        new SortOrderCriterionHandler().applyCriterion(queryString, params, wesc);

        return new QueryResult(queryString.toString(), params);
    }

    /**
     * Builds the SELECT clause, handling tag joins if necessary.
     */
    private void buildSelectClause(StringBuilder queryString, List<Object> params,
            WeblogEntrySearchCriteria wesc) {
        if (wesc.getTags() == null || wesc.getTags().isEmpty()) {
            queryString.append("SELECT e FROM WeblogEntry e WHERE ");
        } else {
            queryString.append("SELECT e FROM WeblogEntry e JOIN e.tags t WHERE ");
            queryString.append("(");
            for (int i = 0; i < wesc.getTags().size(); i++) {
                if (i != 0) {
                    queryString.append(" OR ");
                }
                params.add(wesc.getTags().get(i));
                queryString.append(" t.name = ?").append(params.size());
            }
            queryString.append(") AND ");
        }
    }

    /**
     * Creates the list of criterion handlers to apply.
     * Each handler is responsible for one specific criterion.
     */
    private List<QueryCriterionHandler<WeblogEntrySearchCriteria>> createHandlers(WeblogCategory category) {
        List<QueryCriterionHandler<WeblogEntrySearchCriteria>> handlers = new ArrayList<>();

        // Add handlers in order they should be applied
        handlers.add(new WeblogCriterionHandler());
        handlers.add(new UserCriterionHandler());
        handlers.add(new DateRangeCriterionHandler());
        handlers.add(new CategoryCriterionHandler(category));
        handlers.add(new StatusCriterionHandler());
        handlers.add(new LocaleCriterionHandler());
        handlers.add(new TextSearchCriterionHandler());

        return handlers;
    }
}
