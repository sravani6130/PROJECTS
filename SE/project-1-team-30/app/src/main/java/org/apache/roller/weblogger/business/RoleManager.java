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

/**
 * Interface for user role management operations.
 * 
 * This manager handles the assignment and revocation of roles to users,
 * providing a focused, cohesive API for role-related functionality.
 */
public interface RoleManager {

    /**
     * Grant role to user.
     * 
     * @param roleName Name of the role to grant
     * @param user User to grant the role to
     * @throws WebloggerException If there is a problem
     */
    void grantRole(String roleName, User user) throws WebloggerException;

    /**
     * Revoke role from user.
     * 
     * @param roleName Name of the role to revoke
     * @param user User to revoke the role from
     * @throws WebloggerException If there is a problem
     */
    void revokeRole(String roleName, User user) throws WebloggerException;

    /**
     * Returns true if user has role specified.
     * 
     * @param roleName Name of the role to check
     * @param user User to check
     * @return true if user has the role
     * @throws WebloggerException If there is a problem
     * @deprecated Use checkPermission() instead via PermissionManager
     */
    @Deprecated
    boolean hasRole(String roleName, User user) throws WebloggerException;

    /**
     * Get all roles associated with user.
     * 
     * @param user User to get roles for
     * @return List of role names
     * @throws WebloggerException If there is a problem
     * @deprecated Use checkPermission() instead via PermissionManager
     */
    @Deprecated
    List<String> getRoles(User user) throws WebloggerException;

    /**
     * Release any resources held by manager.
     */
    void release();
}
