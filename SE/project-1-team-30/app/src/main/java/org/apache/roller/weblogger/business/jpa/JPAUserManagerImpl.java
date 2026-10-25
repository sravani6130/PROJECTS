
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

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import org.apache.roller.weblogger.WebloggerException;
import org.apache.roller.weblogger.business.UserManager;

import java.util.List;
import org.apache.roller.weblogger.config.WebloggerConfig;
import org.apache.roller.weblogger.pojos.User;
import org.apache.roller.weblogger.pojos.WeblogPermission;
import org.apache.roller.weblogger.business.RoleManager;
import org.apache.roller.weblogger.business.PermissionManager;
import org.apache.roller.weblogger.business.UserQueryManager;


/**
 * JPA implementation of UserManager interface.
 * 
 * <p>This implementation provides only core user CRUD operations:
 * addUser, saveUser, and removeUser.</p>
 */
@com.google.inject.Singleton
public class JPAUserManagerImpl implements UserManager {
    private static final Log log = LogFactory.getLog(JPAUserManagerImpl.class);

    private final JPAPersistenceStrategy strategy;
    private final RoleManager roleManager;
    private final PermissionManager permissionManager;
    private final UserQueryManager userQueryManager;

    @com.google.inject.Inject
    protected JPAUserManagerImpl(JPAPersistenceStrategy strat, RoleManager roleManager, 
            PermissionManager permissionManager, UserQueryManager userQueryManager) {
        log.debug("Instantiating JPA User Manager");
        this.strategy = strat;
        this.roleManager = roleManager;
        this.permissionManager = permissionManager;
        this.userQueryManager = userQueryManager;
    }

    
    //--------------------------------------------------------------- user CRUD
 
    @Override
    public void addUser(User newUser) throws WebloggerException {

        if (newUser == null) {
            throw new WebloggerException("cannot add null user");
        }
        
        boolean adminUser = false;
        List<User> existingUsers = userQueryManager.getUsers(Boolean.TRUE, null, null, 0, 1);
        boolean firstUserAdmin = WebloggerConfig.getBooleanProperty("users.firstUserAdmin");
        if (existingUsers.isEmpty() && firstUserAdmin) {
            // Make first user an admin
            adminUser = true;

            //if user was disabled (because of activation user 
            // account with e-mail property), enable it for admin user
            newUser.setEnabled(Boolean.TRUE);
            newUser.setActivationCode(null);
        }

        if (userQueryManager.getUserByUserName(newUser.getUserName()) != null ||
                userQueryManager.getUserByUserName(newUser.getUserName().toLowerCase()) != null) {
            throw new WebloggerException("error.add.user.userNameInUse");
        }

        this.strategy.store(newUser);

        roleManager.grantRole("editor", newUser);
        if (adminUser) {
            roleManager.grantRole("admin", newUser);
        }
    }

    
    @Override
    public void saveUser(User user) throws WebloggerException {
        this.strategy.store(user);
    }

    
    @Override
    public void removeUser(User user) throws WebloggerException {
        // remove permissions, maintaining both sides of relationship
        List<WeblogPermission> perms = permissionManager.getWeblogPermissions(user);
        for (WeblogPermission perm : perms) {
            this.strategy.remove(perm);
        }
        this.strategy.remove(user);
    }
}
