-- =============================================
-- Author:		Ali Sadeghi Aghili
-- Create date: 2023/11/26
-- Description: If you want to give the new user all the same permissions as the existing user, 
--              including server-level and database-level permissions, you can use dynamic SQL 
--              to generate and execute the necessary commands
-- =============================================

DECLARE @sourceUser NVARCHAR(100) = 'source_user';
DECLARE @newUser NVARCHAR(100) = 'new_user';
DECLARE @sql NVARCHAR(MAX);

-- Copy server-level permissions
SET @sql = 'ALTER SERVER ROLE ' + (
    SELECT ISNULL(role.name, '') + ', '
    FROM sys.server_role_members AS members
    INNER JOIN sys.server_principals AS role ON members.role_principal_id = role.principal_id
    INNER JOIN sys.server_principals AS user ON members.member_principal_id = user.principal_id
    WHERE user.name = @sourceUser
    FOR XML PATH('')
) + ' ADD MEMBER ' + @newUser;

-- Execute the server-level permissions copy
EXEC sp_executesql @sql;

-- Copy database-level permissions
SET @sql = 'USE YourDatabase;';
SET @sql += 'CREATE USER ' + @newUser + ' FOR LOGIN ' + @newUser + ';';
SET @sql += (
    SELECT 'EXEC sp_addrolemember ' + role.name + ', ' + @newUser + '; '
    FROM sys.database_role_members AS members
    INNER JOIN sys.database_principals AS role ON members.role_principal_id = role.principal_id
    INNER JOIN sys.database_principals AS user ON members.member_principal_id = user.principal_id
    WHERE user.name = @sourceUser
    FOR XML PATH('')
);

-- Execute the database-level permissions copy
EXEC sp_executesql @sql;

-- Optionally, copy other settings (e.g., default schema)
SET @sql = 'ALTER USER ' + @newUser + ' WITH DEFAULT_SCHEMA = ' + @sourceUser;
EXEC sp_executesql @sql;

-- Optionally, copy permissions on specific objects (e.g., tables)
SET @sql = (
    SELECT 'GRANT ' + permission_name + ' ON ' + OBJECT_NAME(major_id) + ' TO ' + @newUser + '; '
    FROM sys.database_permissions
    WHERE grantee_principal_id = (SELECT principal_id FROM sys.database_principals WHERE name = @sourceUser)
    FOR XML PATH('')
);

-- Execute the object-level permissions copy
EXEC sp_executesql @sql;
