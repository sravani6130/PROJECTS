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
 * Handler for weblog criterion in entry queries.
 * Filters entries by weblog or visible weblogs if no specific weblog is
 * provided.
 */
public class WeblogCriterionHandler implements QueryCriterionHandler<WeblogEntrySearchCriteria> {

    @Override
    public boolean applyCriterion(StringBuilder queryString, List<Object> params, WeblogEntrySearchCriteria criteria) {
        if (criteria.getWeblog() != null) {
            params.add(criteria.getWeblog().getId());
            queryString.append("e.website.id = ?").append(params.size());
        } else {
            params.add(Boolean.TRUE);
            queryString.append("e.website.visible = ?").append(params.size());
        }
        return true; // Always applies - either specific weblog or visible weblogs
    }
}
