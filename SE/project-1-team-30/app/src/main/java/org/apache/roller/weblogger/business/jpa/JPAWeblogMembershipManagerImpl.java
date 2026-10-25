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
package org.apache.roller.weblogger.business.jpa;

import java.util.List;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.PermissionManager;
import org.apache.roller.weblogger.business.WeblogMembershipManager;
import org.apache.roller.weblogger.pojos.User;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogPermission;

/**
 * JPA implementation of WeblogMembershipManager.
 * 
 * Handles all weblog membership-related operations by delegating to
 * PermissionManager for the underlying permission management.
 */
@com.google.inject.Singleton
public class JPAWeblogMembershipManagerImpl implements WeblogMembershipManager {

    private static final Log log = LogFactory.getLog(JPAWeblogMembershipManagerImpl.class);
    
    private final PermissionManager permissionManager;

    @com.google.inject.Inject
    protected JPAWeblogMembershipManagerImpl(PermissionManager permissionManager) {
        log.debug("Instantiating JPA Weblog Membership Manager");
        this.permissionManager = permissionManager;
    }

    @Override
    public void release() {}

    @Override
    public void grantWeblogMembership(Weblog weblog, User user, List<String> actions)
            throws WebloggerException {
        permissionManager.grantWeblogPermission(weblog, user, actions);
    }

    @Override
    public void grantWeblogMembershipPending(Weblog weblog, User user, List<String> actions)
            throws WebloggerException {
        permissionManager.grantWeblogPermissionPending(weblog, user, actions);
    }

    @Override
    public void confirmWeblogMembership(Weblog weblog, User user)
            throws WebloggerException {
        permissionManager.confirmWeblogPermission(weblog, user);
    }

    @Override
    public void declineWeblogMembership(Weblog weblog, User user)
            throws WebloggerException {
        permissionManager.declineWeblogPermission(weblog, user);
    }

    @Override
    public void revokeWeblogMembership(Weblog weblog, User user, List<String> actions)
            throws WebloggerException {
        permissionManager.revokeWeblogPermission(weblog, user, actions);
    }

    @Override
    public List<WeblogPermission> getWeblogMemberships(User user)
            throws WebloggerException {
        return permissionManager.getWeblogPermissions(user);
    }

    @Override
    public List<WeblogPermission> getPendingWeblogMemberships(User user)
            throws WebloggerException {
        return permissionManager.getPendingWeblogPermissions(user);
    }

    @Override
    public List<WeblogPermission> getWeblogMemberships(Weblog weblog)
            throws WebloggerException {
        return permissionManager.getWeblogPermissions(weblog);
    }

    @Override
    public List<WeblogPermission> getPendingWeblogMemberships(Weblog weblog)
            throws WebloggerException {
        return permissionManager.getPendingWeblogPermissions(weblog);
    }

    @Override
    public List<WeblogPermission> getWeblogMembershipsIncludingPending(Weblog weblog)
            throws WebloggerException {
        return permissionManager.getWeblogPermissionsIncludingPending(weblog);
    }

    @Override
    public WeblogPermission getWeblogMembership(Weblog weblog, User user)
            throws WebloggerException {
        return permissionManager.getWeblogPermission(weblog, user);
    }

    @Override
    public WeblogPermission getWeblogMembershipIncludingPending(Weblog weblog, User user)
            throws WebloggerException {
        return permissionManager.getWeblogPermissionIncludingPending(weblog, user);
    }
}
