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

import java.sql.Timestamp;
import java.util.List;

/**
 * Handler for date range criterion in entry queries.
 * Filters entries by publication date range (start and/or end dates).
 */
public class DateRangeCriterionHandler implements QueryCriterionHandler<WeblogEntrySearchCriteria> {

    @Override
    public boolean applyCriterion(StringBuilder queryString, List<Object> params, WeblogEntrySearchCriteria criteria) {
        boolean applied = false;

        if (criteria.getStartDate() != null) {
            Timestamp start = new Timestamp(criteria.getStartDate().getTime());
            params.add(start);
            queryString.append(" AND e.pubTime >= ?").append(params.size());
            applied = true;
        }

        if (criteria.getEndDate() != null) {
            Timestamp end = new Timestamp(criteria.getEndDate().getTime());
            params.add(end);
            queryString.append(" AND e.pubTime <= ?").append(params.size());
            applied = true;
        }

        return applied;
    }
}
