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
import org.apache.roller.weblogger.pojos.User;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogPermission;

/**
 * Interface for weblog membership management operations.
 * 
 * This manager handles the relationship between users and weblogs,
 * providing a focused, cohesive API for membership-related functionality
 * including granting, revoking, and querying weblog memberships.
 */
public interface WeblogMembershipManager {

    /**
     * Grant to user specific actions in a weblog.
     * (will create new permission record if none already exists)
     * 
     * @param weblog Weblog to grant membership in
     * @param user User to grant membership to
     * @param actions Actions to be granted
     * @throws WebloggerException If there is a problem
     */
    void grantWeblogMembership(Weblog weblog, User user, List<String> actions)
            throws WebloggerException;

    /**
     * Grant to user specific actions in a weblog, but pending confirmation.
     * (will create new permission record if none already exists)
     * 
     * @param weblog Weblog to grant membership in
     * @param user User to grant membership to
     * @param actions Actions to be granted
     * @throws WebloggerException If there is a problem
     */
    void grantWeblogMembershipPending(Weblog weblog, User user, List<String> actions)
            throws WebloggerException;

    /**
     * Confirm user's membership within specified weblog or throw exception if no pending membership exists.
     * (changes state of permission record to pending = false)
     * 
     * @param weblog Weblog to confirm membership in
     * @param user User to confirm membership for
     * @throws WebloggerException If there is a problem
     */
    void confirmWeblogMembership(Weblog weblog, User user)
            throws WebloggerException;

    /**
     * Decline membership within specified weblog or throw exception if no pending membership exists.
     * (removes permission record)
     * 
     * @param weblog Weblog to decline membership in
     * @param user User declining membership
     * @throws WebloggerException If there is a problem
     */
    void declineWeblogMembership(Weblog weblog, User user)
            throws WebloggerException;

    /**
     * Revoke from user specific actions in a weblog.
     * (if resulting permission has no actions, removes permission record)
     * 
     * @param weblog Weblog to revoke membership in
     * @param user User to revoke membership from
     * @param actions Actions to be revoked
     * @throws WebloggerException If there is a problem
     */
    void revokeWeblogMembership(Weblog weblog, User user, List<String> actions)
            throws WebloggerException;

    /**
     * Get all of user's weblog memberships.
     * 
     * @param user User to get memberships for
     * @return List of WeblogPermission objects representing memberships
     * @throws WebloggerException If there is a problem
     */
    List<WeblogPermission> getWeblogMemberships(User user)
            throws WebloggerException;

    /**
     * Get all of user's pending weblog memberships.
     * 
     * @param user User to get pending memberships for
     * @return List of pending WeblogPermission objects
     * @throws WebloggerException If there is a problem
     */
    List<WeblogPermission> getPendingWeblogMemberships(User user)
            throws WebloggerException;

    /**
     * Get all active memberships associated with a weblog.
     * 
     * @param weblog Weblog to get memberships for
     * @return List of WeblogPermission objects
     * @throws WebloggerException If there is a problem
     */
    List<WeblogPermission> getWeblogMemberships(Weblog weblog)
            throws WebloggerException;

    /**
     * Get all pending memberships associated with a weblog.
     * 
     * @param weblog Weblog to get pending memberships for
     * @return List of pending WeblogPermission objects
     * @throws WebloggerException If there is a problem
     */
    List<WeblogPermission> getPendingWeblogMemberships(Weblog weblog)
            throws WebloggerException;

    /**
     * Get all memberships (pending or active) for a weblog.
     * 
     * @param weblog Weblog to get all memberships for
     * @return List of all WeblogPermission objects
     * @throws WebloggerException If there is a problem
     */
    List<WeblogPermission> getWeblogMembershipsIncludingPending(Weblog weblog)
            throws WebloggerException;

    /**
     * Get user's membership within a weblog or null if none.
     * 
     * @param weblog Weblog to check
     * @param user User to check
     * @return WeblogPermission representing membership, or null
     * @throws WebloggerException If there is a problem
     */
    WeblogPermission getWeblogMembership(Weblog weblog, User user)
            throws WebloggerException;

    /**
     * Get user's membership (pending or active) for a weblog.
     * 
     * @param weblog Weblog to check
     * @param user User to check
     * @return WeblogPermission representing membership, or null
     * @throws WebloggerException If there is a problem
     */
    WeblogPermission getWeblogMembershipIncludingPending(Weblog weblog, User user)
            throws WebloggerException;

    /**
     * Release any resources held by manager.
     */
    void release();
}
