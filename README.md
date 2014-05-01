# Oraora

Oraora is a command-line utility for interacting with Oracle database.

## Features

* Command line history
* Input TAB-completion
* Password file support
* Metadata querying
* Context-aware SQL
* Readable colored output
* su/sudo as SYS or other user

## Installation

Oraora comes bundled as a Ruby gem. To install just run:

```
gem install oraora
```

If you don't have Ruby, check one-click installer for Windows or rvm for Linux.

## Usage

Start oraora passing connection string as argument, just like you would connect to SQL*Plus:

```
oraora user/password@DB
```

OS authentication is supported (pass `/`).

Roles are supported (append `as SYSDBA` / `as SYSOPER`).

### Passfile

Oraora attempts to read file `.orapass` in your home directory if it exists. It should contain connection strings in `user/password@DB` format. Then it's enough to provide `user@DB` when connecting and oraora will automatically fill the password.

### Context

...

### Listing and describing objects

...

### SQL

Any input starting with SQL keyword like SELECT, INSERT, CREATE, ... is reckognized as SQL and passed to database for execution. 

### Context-aware SQL

...

### Su / sudo

```
oraora foo@DB
~ > SELECT * FROM boo.test;
ERROR: Insufficient privileges
~ > sudo GRANT SELECT ON boo.test TO foo;
Grant succeeded.
~ > SELECT * FROM boo.test;
text
------------
Hello world!
```

### Miscellaneous

...

=== Limitations

This is an early alpha version. Things may crash and bugs are hiding out
there.

Oraora does not implement SQL*Plus-specific commands. `rem`, `set`, `show`, `desc`, `exec`, etc. are not
supported.
