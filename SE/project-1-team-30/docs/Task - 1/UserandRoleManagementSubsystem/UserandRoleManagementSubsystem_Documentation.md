# Apache Roller - User and Role Management Subsystem Report

## Overview

This report describes the User and Role Management Subsystem of Apache Roller. This subsystem handles user account management, authentication, authorization through roles, and fine-grained permissions for weblog access control.

**Total Classes in Subsystem**: 30 classes
- 4 Interfaces
- 4 Main Implementations
- 8 Domain Entities (POJOs)
- 8 UI Controller Classes
- 3 Security Filter/Interceptor Classes
- 3 Support/Utility Classes

---

## Class-by-Class Documentation

---

## Class 1: User

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/pojos/User.java
Package: org.apache.roller.weblogger.pojos
```

### Type
JPA Entity (Domain Object)

### Role
Represents a user account in the system. This is the central entity that stores all user information including authentication credentials, personal details, and preferences. Every user interaction with the system is tied to a User entity.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `id` | `String` | Unique identifier (UUID) for the user |
| `userName` | `String` | Login username (unique, sanitized) |
| `password` | `String` | Encrypted password hash |
| `openIdUrl` | `String` | OpenID URL for external authentication |
| `screenName` | `String` | Display name shown to other users |
| `fullName` | `String` | User's full legal name |
| `emailAddress` | `String` | User's email address |
| `dateCreated` | `Date` | Timestamp when account was created |
| `locale` | `String` | Preferred language (e.g., "en", "fr") |
| `timeZone` | `String` | User's timezone for date formatting |
| `enabled` | `Boolean` | Whether account is active (can login) |
| `activationCode` | `String` | Code for email-based account activation |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `getId()` | `String` | Returns the unique user ID |
| `setId(String)` | `void` | Sets the user ID |
| `getUserName()` | `String` | Returns the username |
| `setUserName(String)` | `void` | Sets username (with HTML sanitization) |
| `getPassword()` | `String` | Returns encrypted password |
| `setPassword(String)` | `void` | Sets password (should be pre-encrypted) |
| `resetPassword(String)` | `void` | Encrypts and sets new password |
| `getOpenIdUrl()` | `String` | Returns OpenID URL |
| `getScreenName()` | `String` | Returns display name |
| `getFullName()` | `String` | Returns full name |
| `getEmailAddress()` | `String` | Returns email address |
| `getDateCreated()` | `Date` | Returns creation date |
| `getLocale()` | `String` | Returns preferred locale |
| `getTimeZone()` | `String` | Returns timezone |
| `getEnabled()` | `Boolean` | Returns whether account is enabled |
| `getActivationCode()` | `String` | Returns activation code |
| `hasGlobalPermission(String)` | `boolean` | Checks if user has a global permission |
| `hasGlobalPermissions(List<String>)` | `boolean` | Checks if user has all specified global permissions |

### Interactions with System
- **Managed by**: `UserManager` for all CRUD operations
- **Referenced by**: `UserRole` (one user has many roles)
- **Referenced by**: `WeblogPermission` (one user has many permissions)
- **Referenced by**: `RollerSession` (stores authenticated user)
- **Used by**: All UI controllers to get current user context
- **Sanitizes input**: Uses `HTMLSanitizer` to prevent XSS attacks
- **Encrypts passwords**: Uses Spring Security `PasswordEncoder`

### Important Notes
- Password is always stored encrypted using Spring Security's password encoder
- HTML content is sanitized for `userName`, `screenName`, `fullName`, `emailAddress`, `openIdUrl`, and `activationCode`
- Date is cloned on get/set to prevent external modification
- Equality is based solely on `userName` (unique identifier)
- Disabled users (`enabled = false`) cannot login
- Activation code workflow: new users get code → verify email → activate account

---

## Class 2: UserRole

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/pojos/UserRole.java
Package: org.apache.roller.weblogger.pojos
```

### Type
JPA Entity (Association Object)

### Role
Represents the assignment of a role to a user. This entity implements role-based access control (RBAC) by linking users to their assigned roles. Each role implies certain global permissions.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `id` | `String` | Unique identifier for this role assignment |
| `userName` | `String` | Username of the user who has this role |
| `role` | `String` | Name of the role (e.g., "admin", "editor") |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| Constructor | - | Creates empty role assignment |
| Constructor | - | Creates role assignment with username and role |
| `getId()` | `String` | Returns the assignment ID |
| `getUserName()` | `String` | Returns the username |
| `setUserName(String)` | `void` | Sets the username |
| `getRole()` | `String` | Returns the role name |
| `setRole(String)` | `void` | Sets the role name |

### Interactions with System
- **Managed by**: `RoleManager` for grant/revoke operations
- **Links**: `User` to role names
- **Queried by**: `GlobalPermission` to determine user's global permissions
- **Used by**: `RoleAssignmentFilter` for servlet security integration

### Important Notes
- This is a simple association table between users and roles
- One user can have multiple `UserRole` records (multiple roles)
- Role names are defined in configuration (`rollerwebapp/WEB-INF/security.xml`)
- Equality is based on both `userName` and `role` combination
- No cascade delete - must be explicitly removed before user deletion

---

## Class 3: RollerPermission

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/pojos/RollerPermission.java
Package: org.apache.roller.weblogger.pojos
```

### Type
Abstract Class (extends Java `Permission`)

### Role
Base class for all permission types in Roller. Provides common functionality for managing permission actions (capabilities that can be granted or denied). This follows the Java Security Permission model.

### Attributes

None (abstract base class, subclasses define attributes)

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `setActions(String)` | `void` | Sets actions as comma-separated string (abstract) |
| `getActions()` | `String` | Gets actions as comma-separated string (abstract) |
| `getActionsAsList()` | `List<String>` | Returns actions as a list |
| `setActionsAsList(List<String>)` | `void` | Sets actions from a list |
| `hasAction(String)` | `boolean` | Checks if permission has a specific action |
| `hasActions(List<String>)` | `boolean` | Checks if permission has all specified actions |
| `addActions(List<String>)` | `void` | Adds new actions to this permission |
| `addActions(ObjectPermission)` | `void` | Merges actions from another permission |
| `removeActions(List<String>)` | `void` | Removes specified actions |
| `isEmpty()` | `boolean` | Returns true if no actions are granted |

### Interactions with System
- **Extended by**: `GlobalPermission` and `ObjectPermission`
- **Used by**: `UserManager` for permission checking
- **Used by**: `UISecurityInterceptor` for authorization

### Important Notes
- Follows Java Security `Permission` class design pattern
- Actions are stored as comma-separated strings internally
- Provides both String and List APIs for flexibility
- Subclasses must implement `setActions()` and `getActions()`
- Extending Java `Permission` allows integration with Java security model

---

## Class 4: ObjectPermission

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/pojos/ObjectPermission.java
Package: org.apache.roller.weblogger.pojos
```

### Type
Abstract JPA Entity (extends `RollerPermission`)

### Role
Abstract class for permissions on specific objects (not global). Adds object-scoping to permissions - defines which object the permission applies to and supports pending permissions (invitation workflow).

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `id` | `String` | Unique identifier for this permission |
| `userName` | `String` | Username of permission holder |
| `objectType` | `String` | Type of object (e.g., "Weblog") |
| `objectId` | `String` | Identifier of the specific object |
| `pending` | `boolean` | Whether permission is pending acceptance |
| `dateCreated` | `Date` | When permission was created |
| `actions` | `String` | Comma-separated allowed actions |

### Interactions with System
- **Extends**: `RollerPermission`
- **Extended by**: `WeblogPermission` (concrete implementation)
- **Managed by**: `PermissionManager`
- **Stores**: Object-specific permission grants

### Important Notes
- This is a JPA entity mapped to database
- `pending = true` means user was invited but hasn't accepted yet
- Once user accepts, `pending` becomes `false`
- If user declines, the permission record is deleted
- Supports invitation-based collaboration workflow

---

## Class 5: GlobalPermission

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/pojos/GlobalPermission.java
Package: org.apache.roller.weblogger.pojos
```

### Type
Concrete Class (extends `RollerPermission`)

### Role
Represents system-wide permissions not tied to any specific object. Controls access to global features like administration, creating weblogs, or basic login. GlobalPermission is derived from user's roles.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `actions` | `String` | Comma-separated global actions |

### Constants

| Name | Value | What It Means |
|------|-------|---------------|
| `LOGIN` | "login" | Can login and edit own profile |
| `WEBLOG` | "weblog" | Can login and manage weblogs |
| `ADMIN` | "admin" | Full administrative access |

### Methods

| Method Name | Parameters | Return Type | What It Does |
|-------------|------------|-------------|--------------|
| Constructor | `User` | - | Creates permission from user's roles |
| Constructor | `List<String>` | - | Creates permission with specified actions |
| Constructor | `User, List<String>` | - | Creates permission for user with specified actions |
| `implies(Permission)` | `Permission` | `boolean` | Checks if this permission implies another |
| `setActions(String)` | `String` | `void` | Sets actions as string |
| `getActions()` | - | `String` | Gets actions as string |

### Interactions with System
- **Extends**: `RollerPermission`
- **Created from**: `UserRole` records via configuration
- **Used by**: `UISecurityInterceptor` to check global permissions
- **Checked by**: `UIAction` classes requiring global permissions
- **Configuration**: Role-to-action mapping in `roller.properties`

### Important Notes
- Not a JPA entity - created dynamically from user roles
- Roles map to actions via configuration: `role.action.{roleName} = action1,action2`
- Permission hierarchy: `ADMIN` implies `WEBLOG` which implies `LOGIN`
- `implies()` method implements permission hierarchy logic
- Example: if user has "admin" role, they get `ADMIN` action which implies all other permissions

---

## Class 6: WeblogPermission

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/pojos/WeblogPermission.java
Package: org.apache.roller.weblogger.pojos
```

### Type
JPA Entity (extends `ObjectPermission`)

### Role
Represents a user's permission to perform actions on a specific weblog. Enables fine-grained access control at the weblog level - different users can have different capabilities within the same weblog.

### Constants

| Name | Value | What It Means |
|------|-------|---------------|
| `EDIT_DRAFT` | "edit_draft" | Can create and edit draft posts |
| `POST` | "post" | Can publish posts (includes EDIT_DRAFT) |
| `ADMIN` | "admin" | Full weblog admin (includes POST) |
| `ALL_ACTIONS` | `List<String>` | All possible actions |

### Methods

| Method Name | Parameters | Return Type | What It Does |
|-------------|------------|-------------|--------------|
| Constructor | - | - | Empty constructor for JPA |
| Constructor | `Weblog, User, String` | - | Creates permission with string actions |
| Constructor | `Weblog, User, List<String>` | - | Creates permission with list of actions |
| Constructor | `Weblog, List<String>` | - | Creates permission for weblog with actions |
| `getWeblog()` | - | `Weblog` | Retrieves the weblog this permission is for |
| `getUser()` | - | `User` | Retrieves the user who has this permission |
| `implies(Permission)` | `Permission` | `boolean` | Checks if this permission implies another |

### Interactions with System
- **Extends**: `ObjectPermission`
- **Links**: `User` to `Weblog` with specific actions
- **Managed by**: `PermissionManager` for grant/revoke
- **Checked by**: `UISecurityInterceptor` before weblog actions
- **Created by**: `MembersInvite` controller for invitations
- **Confirmed by**: Users accepting weblog invitations

### Important Notes
- Stored in database as JPA entity
- `objectType` is always "Weblog"
- `objectId` stores weblog handle (not ID)
- Action hierarchy: `ADMIN` implies `POST` implies `EDIT_DRAFT`
- Pending invitations have `pending = true`
- When user leaves weblog, permission record is deleted

---

## Class 7: UserManager

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/UserManager.java
Package: org.apache.roller.weblogger.business
```

### Type
Interface

### Role
Main business interface for user management operations. Defines the contract for all user-related functionality including CRUD operations, querying, permission checking, and both role and weblog permission management.

### Method Categories

| Category | Methods |
|----------|---------|
| **User CRUD** | `addUser`, `saveUser`, `removeUser`, `getUser`, `getUserByUserName`, `getUserByOpenIdUrl`, `getUserByActivationCode` |
| **User Queries** | `getUsers`, `getUsersStartingWith`, `getUsersByLetter`, `getUserNameLetterMap`, `getUserCount` |
| **Permission Checking** | `checkPermission` |
| **Weblog Permissions** | `grantWeblogPermission`, `grantWeblogPermissionPending`, `confirmWeblogPermission`, `declineWeblogPermission`, `revokeWeblogPermission`, `getWeblogPermission`, `getWeblogPermissionIncludingPending`, `getWeblogPermissions`, `getPendingWeblogPermissions`, `getWeblogPermissionsIncludingPending` |
| **Role Management** | `grantRole`, `revokeRole`, `hasRole`, `getRoles` |

### Key Methods

| Method Name | Parameters | Return Type | What It Does |
|-------------|------------|-------------|--------------|
| `addUser()` | `User` | `void` | Creates new user, assigns default role if first user |
| `saveUser()` | `User` | `void` | Updates existing user |
| `removeUser()` | `User` | `void` | Deletes user and all associated data |
| `checkPermission()` | `RollerPermission, User` | `boolean` | Checks if user has permission |
| `grantWeblogPermission()` | `Weblog, User, List<String>` | `void` | Grants active permission |
| `grantWeblogPermissionPending()` | `Weblog, User, List<String>` | `void` | Creates pending invitation |
| `confirmWeblogPermission()` | `Weblog, User` | `void` | Accepts pending invitation |
| `grantRole()` | `String, User` | `void` | Grants role to user |

### Interactions with System
- **Implemented by**: `JPAUserManagerImpl`
- **Used by**: All UI controllers for user operations
- **Used by**: `UISecurityInterceptor` for permission checks
- **Manages**: `User`, `UserRole`, `WeblogPermission` entities
- **Called by**: `Register`, `Profile`, `UserAdmin`, `UserEdit`, `Members` controllers

### Important Notes
- Combines multiple responsibilities: users, roles, and permissions (God Interface anti-pattern)
- All methods can throw `WebloggerException`
- `addUser()` automatically grants admin role to first user
- User queries support pagination with offset and length
- `enabled` parameter filters disabled users
- Interface segregation could improve design

---

## Class 8: JPAUserManagerImpl

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/jpa/JPAUserManagerImpl.java
Package: org.apache.roller.weblogger.business.jpa
```

### Type
Concrete Class (implements `UserManager`)

### Role
JPA-based implementation of UserManager interface. Handles all database operations for users, roles, and weblog permissions using Java Persistence API. This is the only implementation of UserManager.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `strategy` | `JPAPersistenceStrategy` | Persistence layer for database operations |
| `userNameToIdMap` | `Map<String, String>` | Cache mapping usernames to user IDs |

### Key Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `saveUser(User)` | `void` | Persists or updates user in database |
| `removeUser(User)` | `void` | Deletes user and cleans up related data |
| `addUser(User)` | `void` | Adds new user, grants roles, manages activations |
| `getUserByUserName(String, Boolean)` | `User` | Retrieves user by username with enabled filter |
| `getUsers(...)` | `List<User>` | Complex query with date range and pagination |
| `checkPermission(RollerPermission, User)` | `boolean` | Evaluates if user has permission |
| `grantWeblogPermission(...)` | `void` | Creates or updates weblog permission |
| `confirmWeblogPermission(...)` | `void` | Changes pending permission to active |
| `grantRole(String, User)` | `void` | Creates UserRole entity |
| `revokeRole(String, User)` | `void` | Deletes UserRole entity |

### Interactions with System
- **Implements**: `UserManager` interface
- **Uses**: `JPAPersistenceStrategy` for all database operations
- **Manages**: `User`, `UserRole`, `WeblogPermission` entities
- **Queries**: Named queries defined in entity classes
- **Caches**: Username to ID mappings for performance

### Important Notes
- All database operations go through `strategy` persistence layer
- Uses username-to-ID cache to avoid repeated queries
- `addUser()` handles complex logic: activation codes, role assignment
- First user automatically gets "admin" role
- `removeUser()` must clean up all related entities first
- Permission checking combines global (role-based) and object (weblog) permissions
- Thread-safe for read operations, transactions handle write conflicts

---

## Class 9: PermissionManager

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/PermissionManager.java
Package: org.apache.roller.weblogger.business
```

### Type
Interface

### Role
Dedicated interface for managing weblog permissions. This interface was extracted from UserManager to separate permission management concerns from user management concerns, following the Interface Segregation Principle.

### Methods

| Method Name | Parameters | Return Type | What It Does |
|-------------|------------|-------------|--------------|
| `checkPermission()` | `RollerPermission, User` | `boolean` | Checks if user has permission |
| `grantWeblogPermission()` | `Weblog, User, List<String>` | `void` | Grants active weblog permission |
| `grantWeblogPermissionPending()` | `Weblog, User, List<String>` | `void` | Creates pending permission (invitation) |
| `confirmWeblogPermission()` | `Weblog, User` | `void` | Confirms pending permission |
| `declineWeblogPermission()` | `Weblog, User` | `void` | Declines pending permission |
| `revokeWeblogPermission()` | `Weblog, User, List<String>` | `void` | Revokes specific actions |
| `getWeblogPermission()` | `Weblog, User` | `WeblogPermission` | Gets active permission |
| `getWeblogPermissionIncludingPending()` | `Weblog, User` | `WeblogPermission` | Gets active or pending permission |
| `getWeblogPermissions(User)` | `User` | `List<WeblogPermission>` | Gets all user's weblog permissions |
| `getPendingWeblogPermissions(User)` | `User` | `List<WeblogPermission>` | Gets user's pending invitations |
| `getWeblogPermissions(Weblog)` | `Weblog` | `List<WeblogPermission>` | Gets all weblog members |
| `getPendingWeblogPermissions(Weblog)` | `Weblog` | `List<WeblogPermission>` | Gets pending invitations for weblog |
| `getWeblogPermissionsIncludingPending()` | `Weblog` | `List<WeblogPermission>` | Gets all permissions for weblog |

### Interactions with System
- **Implemented by**: `JPAPermissionManagerImpl`
- **Used by**: `Members`, `MembersInvite`, `MemberResign` controllers
- **Used by**: `UISecurityInterceptor` for authorization
- **Manages**: `WeblogPermission` entities

### Important Notes
- Cleaner interface than UserManager for permission operations
- Supports invitation workflow with pending permissions
- `confirm` changes `pending` flag to false
- `decline` deletes the permission record
- `revoke` can remove some actions or delete entire permission if empty
- Part of refactoring effort to separate concerns from UserManager

---

## Class 10: RoleManager

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/RoleManager.java
Package: org.apache.roller.weblogger.business
```

### Type
Interface

### Role
Dedicated interface for managing user roles. Extracted from UserManager to separate role management from user and permission management, following Single Responsibility Principle.

### Methods

| Method Name | Parameters | Return Type | What It Does |
|-------------|-------------|--------------|--------------|
| `grantRole()` | `String roleName, User` | `void` | Assigns a role to a user |
| `revokeRole()` | `String roleName, User` | `void` | Removes a role from a user |
| `hasRole()` | `String roleName, User` | `boolean` | Checks if user has specific role |
| `getRoles()` | `User` | `List<String>` | Gets all roles for a user |
| `release()` | - | `void` | Releases any held resources |

### Interactions with System
- **Implemented by**: `JPARoleManagerImpl`
- **Used by**: `UserEdit` controller for role management
- **Used by**: `GlobalPermission` to determine user's global permissions
- **Manages**: `UserRole` entities

### Important Notes
- Much simpler interface than UserManager
- Focused solely on role operations
- Roles are represented as strings (e.g., "admin", "editor")
- No role hierarchy management - roles are flat
- Part of refactoring to decompose UserManager

---

## Class 11: JPAPermissionManagerImpl

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/jpa/JPAPermissionManagerImpl.java
Package: org.apache.roller.weblogger.business.jpa
```

### Type
Concrete Class (implements `PermissionManager`)

### Role
JPA implementation of PermissionManager. Handles all database operations for weblog permissions including creation, modification, deletion, and querying of WeblogPermission entities.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `strategy` | `JPAPersistenceStrategy` | Persistence layer for database operations |

### Key Methods

| Method Name | What It Does |
|-------------|--------------|
| `checkPermission()` | Evaluates global and weblog permissions using implies() logic |
| `grantWeblogPermission()` | Creates or updates WeblogPermission with pending=false |
| `grantWeblogPermissionPending()` | Creates or updates WeblogPermission with pending=true |
| `confirmWeblogPermission()` | Sets pending=false on existing pending permission |
| `declineWeblogPermission()` | Deletes pending permission record |
| `revokeWeblogPermission()` | Removes actions; deletes if empty |
| `getWeblogPermission()` | Queries for active permission only |
| `getWeblogPermissionIncludingPending()` | Queries for active or pending permission |

### Interactions with System
- **Implements**: `PermissionManager`
- **Uses**: `JPAPersistenceStrategy` for database access
- **Manages**: `WeblogPermission` entities
- **Used by**: Permission-related UI controllers

### Important Notes
- Separated from JPAUserManagerImpl during refactoring
- All queries use JPA named queries
- Permission checking combines global permissions (from roles) with weblog permissions
- Creates new permission if none exists during grant
- Updates existing permission by adding/removing actions
- Deletes permission if all actions are revoked

---

## Class 12: JPARoleManagerImpl

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/jpa/JPARoleManagerImpl.java
Package: org.apache.roller.weblogger.business.jpa
```

### Type
Concrete Class (implements `RoleManager`)

### Role
JPA implementation of RoleManager. Handles all database operations for user role assignments including granting, revoking, and querying UserRole entities.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `strategy` | `JPAPersistenceStrategy` | Persistence layer for database operations |

### Key Methods

| Method Name | What It Does |
|-------------|--------------|
| `grantRole()` | Creates UserRole entity linking user to role |
| `revokeRole()` | Deletes UserRole entity |
| `hasRole()` | Queries for specific UserRole record |
| `getRoles()` | Returns list of all role names for user |

### Interactions with System
- **Implements**: `RoleManager`
- **Uses**: `JPAPersistenceStrategy` for database access
- **Manages**: `UserRole` entities
- **Used by**: User management controllers

### Important Notes
- Extracted from JPAUserManagerImpl for better separation
- Very simple implementation - just CRUD on UserRole entities
- No role validation - accepts any role string
- No role hierarchy logic - that's in GlobalPermission
- Duplicate role grants are prevented by database constraints

---

## Class 13: JPAPersistenceStrategy

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/business/jpa/JPAPersistenceStrategy.java
Package: org.apache.roller.weblogger.business.jpa
```

### Type
Interface

### Role
Abstraction layer between business logic and JPA. Provides simplified database operations hiding JPA complexity from manager classes. This follows the Repository pattern.

### Methods

| Method Name | Parameters | Return Type | What It Does |
|-------------|------------|-------------|--------------|
| `store()` | `Object` | `void` | Persist or update entity |
| `remove()` | `Object` | `void` | Delete entity |
| `load()` | `Class, String` | `Object` | Load entity by ID |
| `getNamedQuery()` | `String, Class` | `TypedQuery` | Get named query for execution |

### Interactions with System
- **Used by**: All JPA manager implementations
- **Wraps**: JPA `EntityManager`
- **Returns**: JPA `TypedQuery` objects

### Important Notes
- Hides JPA details from business layer
- Allows easier testing (can mock this interface)
- Handles transaction management internally
- All manager classes depend on this, not directly on JPA

---

## Class 14: UIAction

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/util/UIAction.java
Package: org.apache.roller.weblogger.ui.struts2.util
```

### Type
Abstract Class (implements `UISecurityEnforced`)

### Role
Base class for all Struts2 action controllers. Provides common infrastructure including authentication context, weblog context, permission requirements, and helper methods for all UI actions.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `actionName` | `String` | Name of the action |
| `desiredMenu` | `String` | Which menu tab should be active |
| `pageTitle` | `String` | Title for the HTML page |
| `authenticatedUser` | `User` | Currently logged-in user |
| `actionWeblog` | `Weblog` | Current weblog context |
| `weblog` | `String` | Weblog handle from request |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `isUserRequired()` | `boolean` | Returns true if login is required |
| `isWeblogRequired()` | `boolean` | Returns true if weblog context is needed |
| `requiredGlobalPermissionActions()` | `List<String>` | Lists required global permissions |
| `requiredWeblogPermissionActions()` | `List<String>` | Lists required weblog permissions |
| `getAuthenticatedUser()` | `User` | Gets current user |
| `setAuthenticatedUser(User)` | `void` | Sets current user (by interceptor) |
| `getActionWeblog()` | `Weblog` | Gets current weblog |

### Interactions with System
- **Implements**: `UISecurityEnforced` interface
- **Extended by**: All UI controller classes
- **Used by**: `UIActionInterceptor` (sets up context)
- **Used by**: `UISecurityInterceptor` (checks permissions)
- **References**: `User` and `Weblog` for context

### Important Notes
- All controllers must extend this class
- Interceptors populate `authenticatedUser` and `actionWeblog` before action execution
- Subclasses override permission requirement methods
- Default: no authentication required, no permissions required
- Provides consistent context across all actions

---

## Class 15: UISecurityEnforced

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/util/UISecurityEnforced.java
Package: org.apache.roller.weblogger.ui.struts2.util
```

### Type
Interface

### Role
Defines security requirements for UI actions. Enables declarative security - controllers declare what they need, interceptors enforce it. This separates security concerns from business logic.

### Methods

| Method Name | Return Type | What It Means |
|-------------|-------------|---------------|
| `isUserRequired()` | `boolean` | Must user be logged in? |
| `isWeblogRequired()` | `boolean` | Must action have weblog context? |
| `requiredGlobalPermissionActions()` | `List<String>` | Which global permissions are needed? |
| `requiredWeblogPermissionActions()` | `List<String>` | Which weblog permissions are needed? |

### Interactions with System
- **Implemented by**: `UIAction` (base class)
- **Read by**: `UISecurityInterceptor`
- **Enables**: Declarative security model

### Important Notes
- Simple marker interface with getters
- No business logic - just declarations
- Controllers override in `UIAction` subclass
- Interceptor reads these before executing action
- Failure to meet requirements → redirect to error/login

---

## Class 16: UserAdmin

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/admin/UserAdmin.java
Package: org.apache.roller.weblogger.ui.struts2.admin
```

### Type
Controller Class (extends `UIAction`)

### Role
Administrator interface for viewing and managing all user accounts. Provides functionality for admins to view user lists, search users, and access user edit functions.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `bean` | `CreateUserBean` | Form data for user creation/editing |
| `authMethod` | `AuthMethod` | Current authentication method (DB, LDAP, etc.) |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `execute()` | `String` | Shows list of users |
| `requiredGlobalPermissionActions()` | `List<String>` | Returns `[GlobalPermission.ADMIN]` |

### Interactions with System
- **Extends**: `UIAction`
- **Uses**: `UserManager` to query users
- **Uses**: `CreateUserBean` for data transfer
- **Requires**: `ADMIN` global permission
- **Redirects to**: `UserEdit` for modifying users

### Important Notes
- Admin-only functionality
- Displays paginated user list
- Can search/filter users
- Read-only view - editing is in separate action
- Checks authentication method to customize UI

---

## Class 17: UserEdit

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/admin/UserEdit.java
Package: org.apache.roller.weblogger.ui.struts2.admin
```

### Type
Controller Class (extends `UIAction`)

### Role
Administrator interface for editing existing user accounts. Allows admins to modify user details, enable/disable accounts, change roles, and view user's weblog permissions.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `bean` | `CreateUserBean` | Form data for user editing |
| `user` | `User` | The user being edited |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `execute()` | `String` | Loads user for editing |
| `save()` | `String` | Saves user changes |
| `requiredGlobalPermissionActions()` | `List<String>` | Returns `[GlobalPermission.ADMIN]` |

### Interactions with System
- **Extends**: `UIAction`
- **Uses**: `UserManager` for save operations
- **Uses**: `RoleManager` for role changes
- **Uses**: `CreateUserBean` for form data
- **Loads**: `User` entity by ID
- **Modifies**: `User` and `UserRole` entities

### Important Notes
- Admin-only controller
- Can enable/disable accounts
- Can change user roles (grant/revoke)
- Shows user's weblog permissions (read-only)
- Form validation ensures required fields
- Cannot delete users from this action

---

## Class 18: CreateUserBean

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/admin/CreateUserBean.java
Package: org.apache.roller.weblogger.ui.struts2.admin
```

### Type
Data Transfer Object (Form Bean)

### Role
Form bean for user creation and editing. Transfers data between HTML forms and User entities. Provides validation and data conversion for admin user management operations.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `id` | `String` | User ID (for edits) |
| `userName` | `String` | Username |
| `password` | `String` | Password |
| `screenName` | `String` | Display name |
| `fullName` | `String` | Full name |
| `emailAddress` | `String` | Email |
| `locale` | `String` | Preferred locale |
| `timeZone` | `String` | Timezone |
| `openIdUrl` | `String` | OpenID URL |
| `enabled` | `Boolean` | Account status |
| `activationCode` | `String` | Activation code |
| `administrator` | `boolean` | Whether user should be admin |

### Methods

| Method Name | What It Does |
|-------------|--------------|
| `copyTo(User)` | Copies bean data to User entity |
| `copyFrom(User)` | Copies User entity data to bean |

### Interactions with System
- **Used by**: `UserAdmin`, `UserEdit` controllers
- **Transfers to**: `User` entity
- **Validates**: Form inputs

### Important Notes
- Separate from User entity to prevent direct entity binding
- Includes `administrator` flag for role management
- Password handling: blank = no change, filled = reset
- Validation happens at this layer
- Prevents mass assignment vulnerabilities

---

## Class 19: Register

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/core/Register.java
Package: org.apache.roller.weblogger.ui.struts2.core
```

### Type
Controller Class (extends `UIAction`)

### Role
Handles new user registration. Provides self-service account creation workflow including form submission, validation, account creation, and optional email activation.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `activationStatus` | `String` | Status of activation process |
| `activationCode` | `String` | Code for account activation |
| `bean` | `ProfileBean` | Registration form data |
| `authMethod` | `AuthMethod` | Authentication method in use |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `execute()` | `String` | Shows registration form |
| `save()` | `String` | Creates new user account |
| `activate()` | `String` | Activates account via email code |

### Interactions with System
- **Extends**: `UIAction`
- **Uses**: `UserManager` to create users
- **Uses**: `ProfileBean` for form data
- **Checks**: `AuthMethod` to determine if registration is allowed
- **Creates**: New `User` entity

### Important Notes
- Registration may be disabled (LDAP/CMA authentication)
- Can require email activation based on configuration
- First user automatically gets admin role
- Subsequent users get configured default role
- Sends activation email if enabled
- OAuth and OpenID also supported

---

## Class 20: Profile

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/core/Profile.java
Package: org.apache.roller.weblogger.ui.struts2.core
```

### Type
Controller Class (extends `UIAction`)

### Role
Allows users to view and edit their own profile information. Provides self-service profile management including password changes and preference updates.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `bean` | `ProfileBean` | Profile form data |
| `authMethod` | `AuthMethod` | Authentication method |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `execute()` | `String` | Shows profile edit form |
| `save()` | `String` | Saves profile changes |
| `isUserRequired()` | `boolean` | Returns true (must be logged in) |

### Interactions with System
- **Extends**: `UIAction`
- **Uses**: `UserManager` to save changes
- **Uses**: `ProfileBean` for form data
- **Modifies**: Current user's `User` entity
- **Checks**: `AuthMethod` to determine editable fields

### Important Notes
- Users can only edit their own profile
- Some fields read-only based on auth method (e.g., LDAP users)
- Password change requires current password verification
- Changes take effect immediately
- Locale/timezone affect date display throughout app

---

## Class 21: ProfileBean

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/core/ProfileBean.java
Package: org.apache.roller.weblogger.ui.struts2.core
```

### Type
Data Transfer Object (Form Bean)

### Role
Form bean for user profile editing. Similar to CreateUserBean but designed for user self-service rather than admin management. Includes password confirmation fields.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `id` | `String` | User ID |
| `userName` | `String` | Username (read-only for display) |
| `password` | `String` | Current password for verification |
| `screenName` | `String` | Display name |
| `fullName` | `String` | Full name |
| `emailAddress` | `String` | Email address |
| `locale` | `String` | Preferred locale |
| `timeZone` | `String` | Timezone |
| `openIdUrl` | `String` | OpenID URL |
| `passwordText` | `String` | New password |
| `passwordConfirm` | `String` | Password confirmation |

### Methods

| Method Name | What It Does |
|-------------|--------------|
| `copyTo(User)` | Copies bean data to User entity |
| `copyFrom(User)` | Copies User entity data to bean |

### Interactions with System
- **Used by**: `Register`, `Profile` controllers
- **Transfers to**: `User` entity
- **Validates**: Password matches, email format, etc.

### Important Notes
- Username is read-only (cannot change after creation)
- Password change requires: current password, new password, confirmation
- Blank password fields = no password change
- Email validation prevents invalid addresses
- Locale and timezone must be valid Java values

---

## Class 22: Members

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/editor/Members.java
Package: org.apache.roller.weblogger.ui.struts2.editor
```

### Type
Controller Class (extends `UIAction`)

### Role
Displays and manages weblog membership. Shows all users who have permissions on a weblog and allows weblog admins to modify or revoke those permissions.

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `execute()` | `String` | Shows list of weblog members |
| `revoke()` | `String` | Revokes user's weblog permission |
| `isWeblogRequired()` | `boolean` | Returns true |
| `requiredWeblogPermissionActions()` | `List<String>` | Returns `[WeblogPermission.ADMIN]` |

### Interactions with System
- **Extends**: `UIAction`
- **Uses**: `PermissionManager` to query and modify permissions
- **Displays**: List of `WeblogPermission` entities
- **Requires**: Weblog context and `ADMIN` permission

### Important Notes
- Only weblog admins can access
- Shows active members and pending invitations
- Can change permission levels (ADMIN, POST, EDIT_DRAFT)
- Can remove members entirely
- Cannot remove last admin (enforced by business logic)

---

## Class 23: MembersInvite

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/editor/MembersInvite.java
Package: org.apache.roller.weblogger.ui.struts2.editor
```

### Type
Controller Class (extends `UIAction`)

### Role
Handles inviting new users to collaborate on a weblog. Creates pending permissions that require user acceptance, enabling invitation-based collaboration workflow.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `userName` | `String` | Username to invite |
| `permissionString` | `String` | Permissions to grant (comma-separated) |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `execute()` | `String` | Shows invitation form |
| `save()` | `String` | Creates pending permission |
| `requiredWeblogPermissionActions()` | `List<String>` | Returns `[WeblogPermission.ADMIN]` |

### Interactions with System
- **Extends**: `UIAction`
- **Uses**: `PermissionManager.grantWeblogPermissionPending()`
- **Creates**: `WeblogPermission` with `pending = true`
- **Sends**: Email notification to invited user

### Important Notes
- Only weblog admins can invite
- User must already exist in system
- Creates pending permission (not active until accepted)
- Invited user receives email notification
- User accepts via their pending invitations page
- Duplicate invitations update existing pending permission

---

## Class 24: MemberResign

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/editor/MemberResign.java
Package: org.apache.roller.weblogger.ui.struts2.editor
```

### Type
Controller Class (extends `UIAction`)

### Role
Allows users to resign from a weblog they have access to. Removes their weblog permissions, effectively removing them as a collaborator.

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `execute()` | `String` | Shows resignation confirmation |
| `resign()` | `String` | Removes user's weblog permission |
| `isWeblogRequired()` | `boolean` | Returns true |

### Interactions with System
- **Extends**: `UIAction`
- **Uses**: `PermissionManager` to revoke permissions
- **Deletes**: User's `WeblogPermission` record

### Important Notes
- Users can resign from any weblog they have access to
- Cannot resign if you're the last admin (prevented by business logic)
- After resignation, cannot access weblog unless re-invited
- Resignation is immediate and permanent
- Must be re-invited to regain access

---

## Class 25: RoleAssignmentFilter

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/rendering/filters/RoleAssignmentFilter.java
Package: org.apache.roller.weblogger.ui.rendering.filters
```

### Type
Servlet Filter

### Role
Servlet filter that integrates Roller's role system with servlet container security. Wraps requests to provide role checking via `HttpServletRequest.isUserInRole()`.

### Methods

| Method Name | What It Does |
|-------------|--------------|
| `doFilter()` | Wraps request with role-aware wrapper |
| `init()` | Initializes filter |
| `destroy()` | Cleans up filter |

### Interactions with System
- **Creates**: `RoleAssignmentRequestWrapper`
- **Uses**: `UserManager` to check roles
- **Integrates**: Roller roles with servlet security

### Important Notes
- Runs on every request
- Enables standard servlet security checks
- Allows Spring Security integration
- Compatible with declarative security in web.xml
- Wraps request before processing

---

## Class 26: RoleAssignmentRequestWrapper

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/rendering/filters/RoleAssignmentRequestWrapper.java
Package: org.apache.roller.weblogger.ui.rendering.filters
```

### Type
Request Wrapper Class

### Role
Wraps HttpServletRequest to provide custom role checking. Overrides `isUserInRole()` to use Roller's role system instead of container-managed roles.

### Methods

| Method Name | What It Does |
|-------------|--------------|
| `isUserInRole(String)` | Checks if current user has specified role |

### Interactions with System
- **Created by**: `RoleAssignmentFilter`
- **Uses**: `UserManager.hasRole()`
- **Checks**: `UserRole` entities

### Important Notes
- Transparent to application code
- Works with both Struts and Spring Security
- Enables role-based URL protection
- Consistent with Java EE security model

---

## Class 27: UISecurityInterceptor

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/util/UISecurityInterceptor.java
Package: org.apache.roller.weblogger.ui.struts2.util
```

### Type
Struts2 Interceptor

### Role
Enforces security requirements before action execution. Reads requirement declarations from UIAction and validates that current user meets all requirements. This is the enforcement point for declarative security.

### Methods

| Method Name | What It Does |
|-------------|--------------|
| `doIntercept()` | Checks all security requirements before allowing action |

### Security Checks

| Check | How It Works |
|-------|--------------|
| **User Required** | If `isUserRequired()` true, verify user is logged in |
| **Weblog Required** | If `isWeblogRequired()` true, verify weblog context exists |
| **Global Permissions** | Check `requiredGlobalPermissionActions()` against user's roles |
| **Weblog Permissions** | Check `requiredWeblogPermissionActions()` against weblog permissions |

### Interactions with System
- **Reads**: `UISecurityEnforced` interface on actions
- **Uses**: `UserManager.checkPermission()` for authorization
- **Creates**: `GlobalPermission` and `WeblogPermission` for checking
- **Redirects**: To login or error page if requirements not met

### Important Notes
- Runs before Every action execution (part of interceptor stack)
- Short-circuits action if security check fails
- Provides centralized security enforcement
- Keeps security logic out of action classes
- Failures result in user-friendly error pages

---

## Class 28: UIActionInterceptor

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/struts2/util/UIActionInterceptor.java
Package: org.apache.roller.weblogger.ui.struts2.util
```

### Type
Struts2 Interceptor

### Role
Prepares the action execution context. Sets up authenticated user and weblog context for actions before they execute. Runs before UISecurityInterceptor in the interceptor stack.

### Methods

| Method Name | What It Does |
|-------------|--------------|
| `doIntercept()` | Sets up user and weblog context |

### What It Does

1. Retrieves `RollerSession` from HTTP session
2. Gets authenticated user from `RollerSession`
3. Sets `authenticatedUser` on the action
4. Resolves weblog from request parameter
5. Sets `actionWeblog` on the action

### Interactions with System
- **Uses**: `RollerSession` to get authenticated user
- **Uses**: `WeblogManager` to resolve weblog
- **Sets**: `UIAction.authenticatedUser`
- **Sets**: `UIAction.actionWeblog`

### Important Notes
- Runs on every action execution
- Provides context for downstream interceptors and actions
- weblog resolution is optional (only if `weblog` parameter present)
- User resolution fails silently (null if not logged in)
- Runs before UISecurityInterceptor which validates requirements

---

## Class 29: RollerSession

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/ui/core/RollerSession.java
Package: org.apache.roller.weblogger.ui.core
```

### Type
Session Management Class

### Role
Manages user authentication state in HTTP session. Provides centralized access to the currently authenticated user throughout the application. Acts as session-scoped user context holder.

### Attributes

| Name | Type | What It Stores |
|------|------|----------------|
| `authenticatedUser` | `User` | Currently logged-in user |

### Methods

| Method Name | Return Type | What It Does |
|-------------|-------------|--------------|
| `getRollerSession()` | `RollerSession` | Static factory to get session from request |
| `getAuthenticatedUser()` | `User` | Returns logged-in user or null |
| `setAuthenticatedUser(User)` | `void` | Sets the logged-in user |

### Interactions with System
- **Stores**: Authenticated `User` in HTTP session
- **Used by**: `UIActionInterceptor` to get current user
- **Used by**: Authentication filters to set user after login
- **Accessed by**: Controllers needing current user

### Important Notes
- One instance per HTTP session
- Created on first access (lazy initialization)
- Stored in session attribute
- Cleared on logout
- Not serializable (transient user reference)
- Thread-safe (session per thread in servlet model)

---

## Class 30: Weblog

### Location
```
File: app/src/main/java/org/apache/roller/weblogger/pojos/Weblog.java
Package: org.apache.roller.weblogger.pojos
```

### Type
JPA Entity (External Reference)

### Role
Represents a blog/weblog in the system. While primarily part of another subsystem, it's referenced extensively by the User and Role Management Subsystem for permission scoping.

### Key Permission Methods

| Method Name | What It Does |
|-------------|--------------|
| `hasUserPermission(User, String)` | Checks if user has single permission on this weblog |
| `hasUserPermissions(User, List<String>)` | Checks if user has all specified permissions |

### Interactions with System
- **Referenced by**: `WeblogPermission` (permissions scoped to weblogs)
- **Used by**: `UIAction` for weblog context
- **Queried by**: `PermissionManager` for permission checks
- **Used in**: All weblog-aware controllers

### Important Notes
- Central object for multi-tenancy (each weblog is separate)
- Permissions are scoped per-weblog
- Users can have different permissions on different weblogs
- Weblog identified by "handle" (URL-safe unique name)
- Permission helper methods delegate to PermissionManager

---

---

## Strengths and Weaknesses of the Current Design

### Strengths

| Strength | Description |
|----------|-------------|
| **Layered Architecture** | Clear separation between Domain (POJOs), Business (Managers), Persistence (JPA), and UI (Controllers) layers. Each layer has distinct responsibilities and can evolve independently. |
| **Flexible Two-Level Permission Model** | Global permissions (role-based) and object permissions (weblog-specific) with an inheritance hierarchy (`RollerPermission` → `GlobalPermission`/`ObjectPermission` → `WeblogPermission`) provides granular access control while sharing action management logic. |
| **Declarative Security** | `UISecurityEnforced` interface allows controllers to declaratively specify permission requirements, enforced centrally by `UISecurityInterceptor`. Security logic stays out of business code. |
| **DTO Pattern Usage** | `CreateUserBean` and `ProfileBean` cleanly separate form data from entity objects, preventing mass assignment vulnerabilities and enabling validation. |
| **Pending Permission Workflow** | Invitation-based collaboration via the `pending` flag in `ObjectPermission` enables secure, user-controlled access grants to weblogs. |
| **Multiple Authentication Support** | Supports ROLLERDB, LDAP, CMA (Container-Managed), and OpenID authentication methods, providing deployment flexibility. |
| **XSS Protection** | HTML sanitization on all user inputs (`userName`, `screenName`, `fullName`, etc.) prevents cross-site scripting attacks. |
| **Refactored Interface Separation** | Recent extraction of `PermissionManager` and `RoleManager` from monolithic `UserManager` improves maintainability and follows Interface Segregation Principle. |

---

### Weaknesses

| Weakness | Description | Potential Improvement |
|----------|-------------|----------------------|
| **God Interface (Legacy)** | `UserManager` still contains deprecated methods for user CRUD, permissions, roles, and queries. Despite refactoring efforts, it violates Interface Segregation Principle. | Complete the migration: remove all deprecated methods from `UserManager`, forcing callers to use `PermissionManager` and `RoleManager`. |
| **Tight JPA Coupling** | All implementations are tightly coupled to JPA. Switching ORMs would require rewriting all `*ManagerImpl` classes. | Introduce repository interfaces (`UserRepository`, `PermissionRepository`) to abstract persistence technology. |
| **String-Based Actions and Roles** | Permissions (`"login"`, `"admin"`) and roles use String constants without compile-time safety or validation. Typos silently fail. | Replace with enums (`PermissionAction`, `Role`) for type safety and IDE support. |
| **No Audit Trail** | No mechanism for tracking security events (permission grants/revokes, role changes, user modifications, login attempts). | Add `AuditLog` entity and logging interceptor for all security-relevant operations. |
| **Missing Password Policy** | No enforcement of password complexity, length, or expiration requirements. Users can set weak passwords. | Implement configurable password policies (minimum length, complexity requirements, password history). |
| **Limited Role Hierarchy** | `UserRole` is a flat structure with no role inheritance or implied permissions. Each role must explicitly define all actions. | Implement role hierarchy where higher roles inherit lower role permissions (e.g., ADMIN inherits WEBLOG permissions). |
| **No Password Reset Flow** | No visible "forgot password" functionality or secure password reset mechanism. | Implement secure password reset via email with time-limited tokens. |
| **Session-Based Authentication** | `RollerSession` stores user in HTTP session, limiting horizontal scalability and requiring session replication. | Migrate to stateless authentication (JWT tokens or OAuth2) for cloud-native scalability. |
| **Struts2 Framework Lock-In** | UI layer tightly coupled to Struts2 (`UIAction`, interceptors, form beans). Framework migration would be costly. | Extract business logic into framework-agnostic service classes callable from any UI technology. |
| **Incomplete Refactoring** | `UserManager` retains deprecated permission/role methods for backward compatibility, creating API confusion and technical debt. | Deprecation period complete: remove legacy methods, update callers to new interfaces. |

---

## Assumptions

The following simplifications were made while modeling this subsystem:

1. **External Dependencies**: JPA classes (`EntityManager`, `TypedQuery`), Spring Security framework, and Struts2 framework are treated as external with only surface-level interactions shown.

2. **Weblog Entity**: Treated as external reference from Weblog Management Subsystem; only permission-related helper methods are documented.

3. **Security Implementation Details**: Password hashing (BCrypt), HTML sanitization, and encryption mechanisms are abstracted.

4. **Exception Handling**: Error handling, exception hierarchies (`WebloggerException`, `InitializationException`), and exception propagation are omitted for clarity.

5. **Concurrency Control**: Database-level locking, optimistic concurrency (JPA `@Version` fields), and transaction isolation levels are not explicitly modeled.

6. **Configuration Files**: Properties for authentication methods, locale/timezone defaults, activation settings, and role-to-action mappings exist in external configuration (`roller.properties`, `security.xml`).

7. **Infrastructure Services**: Email/notification system, logging framework, transaction management, and database schema are assumed to exist but not detailed.

8. **Backward Compatibility**: Deprecated methods in `UserManager` exist for transition but are not the recommended API.

---


