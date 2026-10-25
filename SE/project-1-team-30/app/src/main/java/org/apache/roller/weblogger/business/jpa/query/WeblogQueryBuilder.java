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

import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

/**
 * Builder class for constructing Weblog queries.
 * Uses the Strategy pattern to reduce cognitive complexity in query building.
 */
public class WeblogQueryBuilder {

    /**
     * Search criteria for weblog queries.
     */
    public static class WeblogSearchCriteria {
        private Boolean enabled;
        private Boolean active;
        private Date startDate;
        private Date endDate;

        public Boolean getEnabled() {
            return enabled;
        }

        public void setEnabled(Boolean enabled) {
            this.enabled = enabled;
        }

        public Boolean getActive() {
            return active;
        }

        public void setActive(Boolean active) {
            this.active = active;
        }

        public Date getStartDate() {
            return startDate;
        }

        public void setStartDate(Date startDate) {
            this.startDate = startDate;
        }

        public Date getEndDate() {
            return endDate;
        }

        public void setEndDate(Date endDate) {
            this.endDate = endDate;
        }
    }

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
     * Builds a query for Weblog based on the given search criteria.
     *
     * @param criteria The search criteria
     * @return QueryResult containing the query string and parameters
     */
    public QueryResult buildQuery(WeblogSearchCriteria criteria) {
        List<Object> params = new ArrayList<>();
        StringBuilder whereClause = new StringBuilder();

        // Apply date range criterion
        applyDateCriterion(whereClause, params, criteria);

        // Apply enabled criterion
        applyEnabledCriterion(whereClause, params, criteria);

        // Apply active criterion
        applyActiveCriterion(whereClause, params, criteria);

        // Build final query
        String queryString = "SELECT w FROM Weblog w WHERE " +
                (whereClause.length() > 0 ? whereClause.toString() : "1=1") +
                " ORDER BY w.dateCreated DESC";

        return new QueryResult(queryString, params);
    }

    private void applyDateCriterion(StringBuilder whereClause, List<Object> params,
            WeblogSearchCriteria criteria) {
        if (criteria.getStartDate() != null) {
            Timestamp start = new Timestamp(criteria.getStartDate().getTime());
            appendAndIfNeeded(whereClause);
            params.add(start);
            whereClause.append(" w.dateCreated > ?").append(params.size());
        }
        if (criteria.getEndDate() != null) {
            Timestamp end = new Timestamp(criteria.getEndDate().getTime());
            appendAndIfNeeded(whereClause);
            params.add(end);
            whereClause.append(" w.dateCreated < ?").append(params.size());
        }
    }

    private void applyEnabledCriterion(StringBuilder whereClause, List<Object> params,
            WeblogSearchCriteria criteria) {
        if (criteria.getEnabled() != null) {
            appendAndIfNeeded(whereClause);
            params.add(criteria.getEnabled());
            whereClause.append(" w.visible = ?").append(params.size());
        }
    }

    private void applyActiveCriterion(StringBuilder whereClause, List<Object> params,
            WeblogSearchCriteria criteria) {
        if (criteria.getActive() != null) {
            appendAndIfNeeded(whereClause);
            params.add(criteria.getActive());
            whereClause.append(" w.active = ?").append(params.size());
        }
    }

    private void appendAndIfNeeded(StringBuilder whereClause) {
        if (whereClause.length() > 0) {
            whereClause.append(" AND ");
        }
    }
}
