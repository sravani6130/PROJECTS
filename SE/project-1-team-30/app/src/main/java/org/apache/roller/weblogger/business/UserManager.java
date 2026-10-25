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

import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.User;


/**
 * Interface for User entity CRUD operations.
 * 
 * <p>This interface provides only the core user persistence operations:
 * Create, Read (via other managers), Update, and Delete.</p>
 * 
 * <p>For user query operations, use {@link UserQueryManager}.</p>
 * <p>For role management operations, use {@link RoleManager}.</p>
 * <p>For permission operations, use {@link PermissionManager}.</p>
 * <p>For weblog membership operations, use {@link WeblogMembershipManager}.</p>
 */
public interface UserManager {
    
    //--------------------------------------------------------------- user CRUD    
    
    /**
     * Add a new user.
     * 
     * This method is used to provide supplemental data to new user accounts,
     * such as adding the proper roles for the user.  This method should see if
     * the new user is the first user and give that user the admin role if so.
     *
     * @param newUser User object to be added.
     * @throws WebloggerException If there is a problem.
     */
    void addUser(User newUser) throws WebloggerException;
    
    
    /**
     * Save a user.
     *
     * @param user User to be saved.
     * @throws WebloggerException If there is a problem.
     */
    void saveUser(User user) throws WebloggerException;
    
    
    /**
     * Remove a user.
     *
     * @param user User to be removed.
     * @throws WebloggerException If there is a problem.
     */
    void removeUser(User user) throws WebloggerException;
}
