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

import java.util.List;

/**
 * Interface for query criterion handlers that build dynamic JPA query clauses.
 * Each implementation handles one specific type of search criterion,
 * following the Strategy pattern to reduce branch-heavy logic in manager
 * classes.
 *
 * @param <T> The type of search criteria this handler works with
 */
public interface QueryCriterionHandler<T> {

    /**
     * Applies this criterion to the query being built.
     *
     * @param queryString The StringBuilder containing the query being built
     * @param params      The list of query parameters (modified by this method if
     *                    criterion applies)
     * @param criteria    The search criteria object containing the criterion values
     * @return true if this criterion was applied (added to the query), false
     *         otherwise
     */
    boolean applyCriterion(StringBuilder queryString, List<Object> params, T criteria);
}
