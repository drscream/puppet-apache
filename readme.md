# puppet-apache

This module requires `stdlib` for `validate_re` support.

## Types

### Authentication, Authorization and Access Control

Definitions related to the apache authentication should always be in the form :

    apache::auth::type::provider::authorization

To be consistent with the three types of Apache modules involved in the 
authentication and authorization process:
http://httpd.apache.org/docs/2.2/howto/auth.html

The main advantages of this new way to manage authentication are the possibility 
of sharing resources between virtual hosts and access restrictions

#### Simple Basic File Authentication

Example:

* create one or more users:

<pre>
apache::auth::htpasswd {"user1 in /a/path/htpasswd":
    ensure           => present,
    userFileLocation => "/srv/a/path",
    userFileName     => "htpasswd",
    username         => "user1",
    clearPassword    => "user1", # use encryption in definition
}

apache::auth::htpasswd {"user2 in /var/www/camptocamp.com/private/htpasswd":
  ensure        => present,
  vhost         => "camptocamp.com"
  username      => "user2",
  cryptPassword => 'kdrY191UyPY3E', # (htpasswd -ndb user2 user2)
}
</pre>
 
* create one or more groups:

<pre>
apache::auth::htgroup {"group1 in /var/www/camptocamp.com/private/htgroup":
  ensure    => present,
  groupname => "group1",
  members   => "user1 user2",
}
</pre>

* restrict access to a location with these users our groups:

<pre>
apache::auth::basic::file::group {"group1-webdav1":
  vhost    => "camptocamp.com",
  location => "/webdav1",
  groups   => "group1",
}

apache::auth::basic::file::user {"user1-on-webdav2":
  vhost        => "camptocamp.com",
  location     => "/webdav2",
  authUserFile => "/srv/dav0/htpasswd",
  users        => "user1", # it not defined -> 'valid-user'
}
</pre>

#### Basic LDAP Authentication

Example:

<pre>
apache::auth::basic::ldap {"collectd":
  vhost => $fqdn,
  location => "/collection3",
  authLDAPUrl => 'ldap://ldap.foobar.ch/c=ch?uid??',
  authLDAPGroupAttribute => "memberUid",
  authLDAPGroupAttributeIsDN => "off",
  authzRequire => "ldap-group ou=foo,ou=bar,o=entreprises,c=ch",
}
</pre>