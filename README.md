# Oraora

Oraora is a command-line utility for interacting with Oracle database.

## Features

* Command line history
* Input TAB-completion
* Password file support
* Metadata querying
* Context-aware SQL
* Readable colored output
* su/sudo as SYS

## Installation

Oraora comes bundled as a Ruby gem. To install just run:
```
$ gem install oraora
```

If you don't have Ruby, check one-click installer for Windows or rvm for Linux.

## Usage

### Connecting to database

Start oraora passing connection string as argument, just like you would connect to SQL*Plus:
```
$ oraora user/password@DB
```

OS authentication is supported (pass `/`).

Roles are supported (append `as SYSDBA` / `as SYSOPER`).

### Passfile

Oraora attempts to read file `.orapass` in your home directory if it exists. It should contain connection strings in
`user/password@DB` format. Then it's enough to provide `user@DB` when connecting and oraora will automatically fill
the password.
```
$ oraora --log-level=debug user@DB
[DEBUG] Connecting: user/password@DB
```

### Context

Use `c` command to navigate through database like directory structure.
```
~ $ c some_table                  # Starting at home schema, navigate into table some_table
~.SOME_TABLE $ c col1             # Navigate into column col1
~.SOME_TABLE.COL1 $ c -           # Navigate up
~.SOME_TABLE $ c --               # Navigate two levels up - to database level. You could also use 'cd .'
. $ c HR.EMPLOYEES                # Navigate to schema HR, table EMPLOYEES
HR.EMPLOYEES $ c -/DEPARTMENTS    # Navigate up, then to table DEPARTMENTS
HR.DEPARTMENTS $ c .              # Navigate to root (database level)
/ $ c                             # Navigate to your home schema
```

Note: `c` is aliased as `cd` for unix addicts.

### Listing and describing objects

Use `d` command to describe object currently in context.
```
HR.EMPLOYEES $ d
Schema:       HR
Name:         EMPLOYEES
Partitioned:  NO
```

Use `l` command to list for object currently in context. In database schemas are listed. In schema - objects. In table,
view or materialized view - columns, etc.
```
HR.EMPLOYEES $ l
EMPLOYEE_ID                     PHONE_NUMBER                    COMMISSION_PCT
FIRST_NAME                      HIRE_DATE                       MANAGER_ID
LAST_NAME                       JOB_ID                          DEPARTMENT_ID
EMAIL                           SALARY
```

You can also provide context path as additional parameter for list and describe:
```
HR.EMPLOYEES $ l .SYS.DUAL
DUMMY
```

For list provide filter as last segment of the path:
```
~ $ l .HR.EMPLOYEES.*NAME
FIRST_NAME                      LAST_NAME
```

Note: `l` is aliased as `ls`. `d` is aliased as `desc` and `describe`.

### SQL

Any command starting with SQL keyword like `SELECT`, `CREATE`, `ALTER`, etc. is treated as SQL and passed to
database for execution

```
~ $ SELECT * FROM dual;
D
-
X

[INFO] 1 row(s) selected
```

### Context-aware SQL

Within specific context, you can omit some obvious keywords or identifiers at the beginning of SQL statements.
For example, in context of a table following statements will work:
```
~.SOME_TABLE $ SELECT;                  # implicit 'SELECT * FROM SOME_TABLE'
~.SOME_TABLE $ WHERE col = 1;           # implicit 'SELECT * FROM SOME_TABLE WHERE col = 1'
~.SOME_TABLE $ SET col = 2;             # implicit 'UPDATE SOME_TABLE SET col = 2'
~.SOME_TABLE $ ADD x INTEGER;           # implicit 'ALTER TABLE SOME_TABLE ADD x INTEGER'
```

Some other examples:
```
~ $ IDENTIFIED BY oraora;               # implicit 'ALTER USER xxx IDENTIFIED BY oraora'
~.SOME_TABLE.COL $ WHERE x = 1;         # implicit 'SELECT COL FROM SOME_TABLE WHERE x = 1'
~.SOME_TABLE.COL $ RENAME TO kol;       # implicit 'ALTER TABLE SOME_TABLE RENAME COLUMN col TO kol'
```

### Tab completion

Oraora has bash-style tab completion - hit `<TAB>` to autocomplete current word with SQL keyword or context. If there are
multiple possible completions hit `<TAB>` twice to see the list.

Also there are several quick templates defined. For example, type `S*`, then hit `<TAB>` to expand it into
`SELECT * FROM `. Available templates are as follows:

```
s  => SELECT
s* => SELECT * FROM
c* => SELECT COUNT(*) FROM
i  => INSERT
u  => UPDATE
d  => DELETE
a  => ALTER
c  => CREATE
cr => CREATE OR REPLACE
```

### Su / sudo

`su` and `sudo` allow to switch to SYS session temporarily or execute a single statement as SYS, similarly to their
unix counterparts. If you don't have SYS password for current connection in orafile, you will be prompted for it.
```
$ oraora test@DB
~ $ CREATE TABLE test (a INTEGER);
[ERROR] ORA-01031: insufficient privileges at 0
~ $ sudo GRANT CREATE TABLE TO test;
[INFO] 0 row(s) affected
~ $ CREATE TABLE test (a INTEGER);
[INFO] 0 row(s) affected
```

## Limitations

This is an early alpha version. Things may crash and bugs are hiding out there.

PL/SQL blocks are not supported (yet).

Oraora does not implement SQL*Plus-specific commands. `rem`, `set`, `show`, `desc`, `exec`, etc. are not
supported.
