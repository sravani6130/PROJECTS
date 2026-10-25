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
import org.apache.roller.weblogger.pojos.RollerPermission;
import org.apache.roller.weblogger.pojos.User;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogPermission;

/**
 * Interface for weblog permission management operations.
 * 
 * This manager handles the granting, revoking, and checking of permissions
 * for users within weblogs, providing a focused, cohesive API for 
 * permission-related functionality.
 */
public interface PermissionManager {

    /**
     * Return true if user has permission specified.
     * 
     * @param perm Permission to check
     * @param user User to check permission for
     * @return true if user has the permission
     * @throws WebloggerException If there is a problem
     */
    boolean checkPermission(RollerPermission perm, User user) throws WebloggerException;

    /**
     * Grant to user specific actions in a weblog.
     * (will create new permission record if none already exists)
     * 
     * @param weblog Weblog to grant permissions in
     * @param user User to grant permissions to
     * @param actions Actions to be granted
     * @throws WebloggerException If there is a problem
     */
    void grantWeblogPermission(Weblog weblog, User user, List<String> actions) throws WebloggerException;

    /**
     * Grant to user specific actions in a weblog, but pending confirmation.
     * (will create new permission record if none already exists)
     * 
     * @param weblog Weblog to grant permissions in
     * @param user User to grant permissions to
     * @param actions Actions to be granted
     * @throws WebloggerException If there is a problem
     */
    void grantWeblogPermissionPending(Weblog weblog, User user, List<String> actions) throws WebloggerException;

    /**
     * Confirm user's permission within specified weblog or throw exception if no pending permission exists.
     * (changes state of permission record to pending = true)
     * 
     * @param weblog Weblog to grant permissions in
     * @param user User to grant permissions to
     * @throws WebloggerException If there is a problem
     */
    void confirmWeblogPermission(Weblog weblog, User user) throws WebloggerException;

    /**
     * Decline permissions within specified weblog or throw exception if no pending permission exists.
     * (removes permission record)
     * 
     * @param weblog Weblog to grant permissions in
     * @param user User to grant permissions to
     * @throws WebloggerException If there is a problem
     */
    void declineWeblogPermission(Weblog weblog, User user) throws WebloggerException;

    /**
     * Revoke from user specific actions in a weblog.
     * (if resulting permission has empty removes permission record)
     * 
     * @param weblog Weblog to grant permissions in
     * @param user User to grant permissions to
     * @param actions Actions to be granted
     * @throws WebloggerException If there is a problem
     */
    void revokeWeblogPermission(Weblog weblog, User user, List<String> actions) throws WebloggerException;

    /**
     * Get all of user's weblog permissions.
     * 
     * @param user User to get permissions for
     * @return List of WeblogPermission objects
     * @throws WebloggerException If there is a problem
     */
    List<WeblogPermission> getWeblogPermissions(User user) throws WebloggerException;

    /**
     * Get all of user's pending weblog permissions.
     * 
     * @param user User to get permissions for
     * @return List of pending WeblogPermission objects
     * @throws WebloggerException If there is a problem
     */
    List<WeblogPermission> getPendingWeblogPermissions(User user) throws WebloggerException;

    /**
     * Get all active permissions associated with a weblog.
     * 
     * @param weblog Weblog to get permissions for
     * @return List of WeblogPermission objects
     * @throws WebloggerException If there is a problem
     */
    List<WeblogPermission> getWeblogPermissions(Weblog weblog) throws WebloggerException;

    /**
     * Get all pending permissions associated with a weblog.
     * 
     * @param weblog Weblog to get permissions for
     * @return List of pending WeblogPermission objects
     * @throws WebloggerException If there is a problem
     */
    List<WeblogPermission> getPendingWeblogPermissions(Weblog weblog) throws WebloggerException;

    /**
     * Get all permissions (pending or actual) for a weblog.
     * 
     * @param weblog Weblog to get permissions for
     * @return List of all WeblogPermission objects
     * @throws WebloggerException If there is a problem
     */
    List<WeblogPermission> getWeblogPermissionsIncludingPending(Weblog weblog) throws WebloggerException;

    /**
     * Get user's permission within a weblog or null if none.
     * 
     * @param weblog Weblog to check
     * @param user User to check
     * @return WeblogPermission or null
     * @throws WebloggerException If there is a problem
     */
    WeblogPermission getWeblogPermission(Weblog weblog, User user) throws WebloggerException;

    /**
     * Get user's permission (pending or actual) for a weblog.
     * 
     * @param weblog Weblog to check
     * @param user User to check
     * @return WeblogPermission or null
     * @throws WebloggerException If there is a problem
     */
    WeblogPermission getWeblogPermissionIncludingPending(Weblog weblog, User user) throws WebloggerException;

    /**
     * Release any resources held by manager.
     */
    void release();
}
