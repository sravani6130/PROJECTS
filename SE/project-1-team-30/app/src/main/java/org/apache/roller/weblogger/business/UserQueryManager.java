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

import java.util.Date;
import java.util.List;
import java.util.Map;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.pojos.User;


/**
 * Interface for user query and lookup operations.
 * This interface handles all read-only user query operations, separating them
 * from user lifecycle management (CRUD) in UserManager.
 */
public interface UserQueryManager {
    
    /**
     * Get count of enabled users
     */    
    long getUserCount() throws WebloggerException;
    
    
    /**
     * get a user by activation code
     * @param activationCode
     * @return
     * @throws WebloggerException
     */
    User getUserByActivationCode(String activationCode)
            throws WebloggerException;
    
    
    /**
     * Retrieve a user by its internal identifier id.
     *
     * @param id the id of the user to retrieve.
     * @return the user object with specified id or null if not found
     * @throws WebloggerException
     */
    User getUser(String id) throws WebloggerException;

    /**
     * Lookup a user by UserName.
     * 
     * This lookup is restricted to 'enabled' users by default.  So this method
     * will return null if the user is found but is not enabled.
     * 
     * @param userName User Name of user to lookup.
     * @return The user, or null if not found or not enabled.
     * @throws WebloggerException If there is a problem.
     */
    User getUserByUserName(String userName) throws WebloggerException;
    
    /**
     * Lookup a user by UserName with the given enabled status.
     * 
     * @param userName User Name of user to lookup.
     * @param enabled True if user is enabled, false otherwise.
     * @return The user, or null if not found or of the proper enabled status.
     * @throws WebloggerException If there is a problem.
     */
    User getUserByUserName(String userName, Boolean enabled)
        throws WebloggerException;

    /**
     * Lookup a user by Open ID URL.
     *
     * This lookup is restricted to 'enabled' users by default.  So this method
     * will return null if the user is found but is not enabled.
     *
     * @param openIdUrl OpenIdUrl of user to lookup.
     * @return The user, or null if not found or not enabled.
     * @throws WebloggerException If there is a problem.
     */
    User getUserByOpenIdUrl(String openIdUrl)
            throws WebloggerException;

    /**
     * Lookup a group of users.
     * 
     * The lookup may be constrained to users with a certain enabled status,
     * to users created within a certain date range, and the results can be
     * confined to a certain offset & length for paging abilities.
     * 
     * @param enabled True for enabled only, False for disabled only (or null for all)
     * @param startDate Restrict to those created after startDate (or null for all)
     * @param endDate Restrict to those created before startDate (or null for all)
     * @param offset The index of the first result to return.
     * @param length The number of results to return.
     * @return List A list of UserDatUsers which match the criteria.
     * @throws WebloggerException If there is a problem.
     */
    List<User> getUsers(
            Boolean enabled,
            Date    startDate,
            Date    endDate,
            int     offset,
            int     length) throws WebloggerException;

    /**
     * Lookup users whose usernames or email addresses start with a string.
     *
     * @param startsWith String to match userNames and emailAddresses against
     * @param offset     Offset into results (for paging)
     * @param length     Max to return (for paging)
     * @param enabled    True for only enalbed, false for disabled, null for all
     * @return List of (up to length) users that match startsWith string
     */
    List<User> getUsersStartingWith(String startsWith,
            Boolean enabled, int offset, int length) throws WebloggerException;
    
    
    /**
     * Get map with 26 entries, one for each letter A-Z and
     * containing Longs reflecting the number of users whose
     * names start with each letter.
     */
    Map<String, Long> getUserNameLetterMap() throws WebloggerException;
    
    
    /** 
     * Get collection of users whose names begin with specified letter 
     */
    List<User> getUsersByLetter(char letter, int offset, int length)
        throws WebloggerException;
}
