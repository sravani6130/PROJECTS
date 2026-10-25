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
import jakarta.persistence.NoResultException;
import jakarta.persistence.TypedQuery;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.PermissionManager;
import org.apache.roller.weblogger.business.RoleManager;
import org.apache.roller.weblogger.pojos.GlobalPermission;
import org.apache.roller.weblogger.pojos.RollerPermission;
import org.apache.roller.weblogger.pojos.User;
import org.apache.roller.weblogger.pojos.Weblog;
import org.apache.roller.weblogger.pojos.WeblogPermission;

/**
 * JPA implementation of PermissionManager.
 * 
 * Handles all weblog permission-related persistence operations.
 */
@com.google.inject.Singleton
public class JPAPermissionManagerImpl implements PermissionManager {

    private static final Log log = LogFactory.getLog(JPAPermissionManagerImpl.class);
    
    private final JPAPersistenceStrategy strategy;
    private final RoleManager roleManager;

    @com.google.inject.Inject
    protected JPAPermissionManagerImpl(JPAPersistenceStrategy strat, RoleManager roleManager) {
        log.debug("Instantiating JPA Permission Manager");
        this.strategy = strat;
        this.roleManager = roleManager;
    }

    @Override
    public void release() {}

    @Override
    public boolean checkPermission(RollerPermission perm, User user) throws WebloggerException {
        // if permission a weblog permission
        if (perm instanceof WeblogPermission) {
            // if user has specified permission in weblog return true
            WeblogPermission permToCheck = (WeblogPermission) perm;
            try {
                RollerPermission existingPerm = getWeblogPermission(permToCheck.getWeblog(), user);
                if (existingPerm != null && existingPerm.implies(perm)) {
                    return true;
                }
            } catch (WebloggerException ignored) {
            }
        }

        // if Blog Server admin would still have weblog permission above
        GlobalPermission globalPerm = new GlobalPermission(user);
        if (globalPerm.implies(perm)) {
            return true;
        }

        if (log.isDebugEnabled()) {
            log.debug("PERM CHECK FAILED: user " + user.getUserName() + " does not have " + perm.toString());
        }
        return false;
    }

    @Override
    public WeblogPermission getWeblogPermission(Weblog weblog, User user) throws WebloggerException {
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByUserName&WeblogId",
                WeblogPermission.class);
        q.setParameter(1, user.getUserName());
        q.setParameter(2, weblog.getHandle());
        try {
            return q.getSingleResult();
        } catch (NoResultException ignored) {
            return null;
        }
    }

    @Override
    public WeblogPermission getWeblogPermissionIncludingPending(Weblog weblog, User user) throws WebloggerException {
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByUserName&WeblogIdIncludingPending",
                WeblogPermission.class);
        q.setParameter(1, user.getUserName());
        q.setParameter(2, weblog.getHandle());
        try {
            return q.getSingleResult();
        } catch (NoResultException ignored) {
            return null;
        }
    }

    @Override
    public void grantWeblogPermission(Weblog weblog, User user, List<String> actions) throws WebloggerException {
        // first, see if user already has a permission for the specified object
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByUserName&WeblogIdIncludingPending",
                WeblogPermission.class);
        q.setParameter(1, user.getUserName());
        q.setParameter(2, weblog.getHandle());
        WeblogPermission existingPerm = null;
        try {
            existingPerm = q.getSingleResult();
        } catch (NoResultException ignored) {}

        // permission already exists, so add any actions specified in perm argument
        if (existingPerm != null) {
            existingPerm.addActions(actions);
            this.strategy.store(existingPerm);
        } else {
            // it's a new permission, so store it
            WeblogPermission perm = new WeblogPermission(weblog, user, actions);
            this.strategy.store(perm);
        }
    }

    @Override
    public void grantWeblogPermissionPending(Weblog weblog, User user, List<String> actions) throws WebloggerException {
        // first, see if user already has a permission for the specified object
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByUserName&WeblogIdIncludingPending",
                WeblogPermission.class);
        q.setParameter(1, user.getUserName());
        q.setParameter(2, weblog.getHandle());
        WeblogPermission existingPerm = null;
        try {
            existingPerm = q.getSingleResult();
        } catch (NoResultException ignored) {}

        // permission already exists, so complain 
        if (existingPerm != null) {
            throw new WebloggerException("Cannot make existing permission into pending permission");
        } else {
            // it's a new permission, so store it
            WeblogPermission perm = new WeblogPermission(weblog, user, actions);
            perm.setPending(true);
            this.strategy.store(perm);
        }
    }

    @Override
    public void confirmWeblogPermission(Weblog weblog, User user) throws WebloggerException {
        // get specified permission
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByUserName&WeblogIdIncludingPending",
                WeblogPermission.class);
        q.setParameter(1, user.getUserName());
        q.setParameter(2, weblog.getHandle());
        WeblogPermission existingPerm;
        try {
            existingPerm = q.getSingleResult();
        } catch (NoResultException ignored) {
            throw new WebloggerException("ERROR: permission not found");
        }
        // set pending to false
        existingPerm.setPending(false);
        this.strategy.store(existingPerm);
    }

    @Override
    public void declineWeblogPermission(Weblog weblog, User user) throws WebloggerException {
        // get specified permission
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByUserName&WeblogIdIncludingPending",
                WeblogPermission.class);
        q.setParameter(1, user.getUserName());
        q.setParameter(2, weblog.getHandle());
        WeblogPermission existingPerm;
        try {
            existingPerm = q.getSingleResult();
        } catch (NoResultException ignored) {
            throw new WebloggerException("ERROR: permission not found");
        }
        // remove permission
        this.strategy.remove(existingPerm);
    }

    @Override
    public void revokeWeblogPermission(Weblog weblog, User user, List<String> actions) throws WebloggerException {
        // get specified permission
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByUserName&WeblogIdIncludingPending",
                WeblogPermission.class);
        q.setParameter(1, user.getUserName());
        q.setParameter(2, weblog.getHandle());
        WeblogPermission oldperm;
        try {
            oldperm = q.getSingleResult();
        } catch (NoResultException ignored) {
            throw new WebloggerException("ERROR: permission not found");
        }

        // remove actions specified in perm argument
        oldperm.removeActions(actions);

        if (oldperm.isEmpty()) {
            // no actions left in permission so remove it
            this.strategy.remove(oldperm);
        } else {
            // otherwise save it
            this.strategy.store(oldperm);
        }
    }

    @Override
    public List<WeblogPermission> getWeblogPermissions(User user) throws WebloggerException {
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByUserName",
                WeblogPermission.class);
        q.setParameter(1, user.getUserName());
        return q.getResultList();
    }

    @Override
    public List<WeblogPermission> getWeblogPermissions(Weblog weblog) throws WebloggerException {
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByWeblogId",
                WeblogPermission.class);
        q.setParameter(1, weblog.getHandle());
        return q.getResultList();
    }

    @Override
    public List<WeblogPermission> getWeblogPermissionsIncludingPending(Weblog weblog) throws WebloggerException {
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByWeblogIdIncludingPending",
                WeblogPermission.class);
        q.setParameter(1, weblog.getHandle());
        return q.getResultList();
    }

    @Override
    public List<WeblogPermission> getPendingWeblogPermissions(User user) throws WebloggerException {
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByUserName&Pending",
                WeblogPermission.class);
        q.setParameter(1, user.getUserName());
        return q.getResultList();
    }

    @Override
    public List<WeblogPermission> getPendingWeblogPermissions(Weblog weblog) throws WebloggerException {
        TypedQuery<WeblogPermission> q = strategy.getNamedQuery("WeblogPermission.getByWeblogId&Pending",
                WeblogPermission.class);
        q.setParameter(1, weblog.getHandle());
        return q.getResultList();
    }
}
