define apache::vhost (
  $ensure=present,
  $config_file="",
  $config_content=false,
  $htdocs=false,
  $home="",
  $readme=false,
  $docroot=false,
  $cgibin=true,
  $user="",
  $admin="",
  $group="root",
  $mode=2570,
  $aliases=[],
  $enable_default=true,
  $ports=['*:80'],
  $accesslog_format="combined"
) {

  include apache::params

  $wwwuser = $user ? {
    ""      => $apache::params::user,
    default => $user,
  }

  # used in ERB templates
  if $home == "" {
    $home = $apache::params::root
  }

  $documentroot = $docroot ? {
    false   => "${home}/${name}/htdocs",
    default => $docroot,
  }

  $cgipath = $cgibin ? {
    true    => "${home}/${name}/cgi-bin/",
    false   => false,
    default => $cgibin,
  }

  # check if default virtual host is enabled
  if $enable_default == true {

    exec { "enable default virtual host from ${name}":
      command => "${apache::params::a2ensite} default",
      unless  => "test -L ${apache::params::conf}/sites-enabled/000-default",
      notify  => Exec["apache-graceful"],
      require => Package["apache"],
    }

  } else {

    exec { "disable default virtual host from ${name}":
      command => "a2dissite default",
      onlyif  => "test -L ${apache::params::conf}/sites-enabled/000-default",
      notify  => Exec["apache-graceful"],
      require => Package["apache"],
    }
  }

  case $ensure {
    present: {
      file { "${apache::params::conf}/sites-available/${name}":
        ensure  => present,
        owner   => root,
        group   => root,
        mode    => 644,
        seltype => $operatingsystem ? {
          redhat => "httpd_config_t",
          CentOS => "httpd_config_t",
          default => undef,
        },
        require => Package[$apache::params::pkg],
        notify  => Exec["apache-graceful"],
      }

      file { "${home}/${name}":
        ensure => directory,
        owner  => root,
        group  => root,
        mode   => 755,
        seltype => $operatingsystem ? {
          redhat => "httpd_sys_content_t",
          CentOS => "httpd_sys_content_t",
          default => undef,
        },
        require => File["root directory"],
      }

      file { "${home}/${name}/htdocs":
        ensure => directory,
        owner  => $wwwuser,
        group  => $group,
        mode   => $mode,
        seltype => $operatingsystem ? {
          redhat => "httpd_sys_content_t",
          CentOS => "httpd_sys_content_t",
          default => undef,
        },
        require => [File["${home}/${name}"]],
      }
 
      if $htdocs {
        File["${home}/${name}/htdocs"] {
          source  => $htdocs,
          recurse => true,
        }
      }

      # cgi-bin
      file { "${name} cgi-bin directory":
        path   => $cgipath ? {
          false   => "${home}/${name}/cgi-bin/",
          default => $cgipath,
        },
        ensure => $cgipath ? {
          "${home}/${name}/cgi-bin/" => directory,
          default => undef, # don't manage this directory unless under $root/$name
        },
        owner  => $wwwuser,
        group  => $group,
        mode   => $mode,
        seltype => $operatingsystem ? {
          redhat => "httpd_sys_script_exec_t",
          CentOS => "httpd_sys_script_exec_t",
          default => undef,
        },
        require => [File["${home}/${name}"]],
      }

      case $config_file {

        default: {
          File["${apache::params::conf}/sites-available/${name}"] {
            source => $config_file,
          }
        }
        "": {

          if $config_content {
            File["${apache::params::conf}/sites-available/${name}"] {
              content => $config_content,
            }
          } else {
            # default vhost template
            File["${apache::params::conf}/sites-available/${name}"] {
              content => template("apache/vhost.erb"), 
            }
          }
        }
      }

      # Log files
      file {"${home}/${name}/logs":
        ensure => directory,
        owner  => root,
        group  => root,
        mode   => 755,
        seltype => $operatingsystem ? {
          redhat => "httpd_log_t",
          CentOS => "httpd_log_t",
          default => undef,
        },
        require => File["${home}/${name}"],
      }

      # We have to give log files to right people with correct rights on them.
      # Those rights have to match those set by logrotate
      file { ["${home}/${name}/logs/access.log",
              "${home}/${name}/logs/error.log"] :
        ensure => present,
        owner => root,
        group => adm,
        mode => 644,
        seltype => $operatingsystem ? {
          redhat => "httpd_log_t",
          CentOS => "httpd_log_t",
          default => undef,
        },
        require => File["${home}/${name}/logs"],
      }

      # Private data
      file {"${home}/${name}/private":
        ensure  => directory,
        owner   => $wwwuser,
        group   => $group,
        mode    => $mode,
        seltype => $operatingsystem ? {
          redhat => "httpd_sys_content_t",
          CentOS => "httpd_sys_content_t",
          default => undef,
        },
        require => File["${home}/${name}"],
      }

      # README file
      file {"${home}/${name}/README":
        ensure  => present,
        owner   => root,
        group   => root,
        mode    => 644,
        content => $readme ? {
          false => template("apache/README_vhost.erb"),
          default => $readme,
        },
        require => File["${home}/${name}"],
      }

      exec {"enable vhost ${name}":
        command => $operatingsystem ? {
          RedHat => "${apache::params::a2ensite} ${name}",
          CentOS => "${apache::params::a2ensite} ${name}",
          default => "${apache::params::a2ensite} ${name}"
        },
        notify  => Exec["apache-graceful"],
        require => [$operatingsystem ? {
          redhat => File["${apache::params::a2ensite}"],
          CentOS => File["${apache::params::a2ensite}"],
          default => Package[$apache::params::pkg]},
          File["${apache::params::conf}/sites-available/${name}"],
          File["${home}/${name}/htdocs"],
          File["${home}/${name}/logs"],
        ],
        unless  => "/bin/sh -c '[ -L ${apache::params::conf}/sites-enabled/${name} ] \\
          && [ ${apache::params::conf}/sites-enabled/${name} -ef ${apache::params::conf}/sites-available/${name} ]'",
      }
    }

    absent:{
      file { "${apache::params::conf}/sites-enabled/${name}":
        ensure  => absent,
        require => Exec["disable vhost ${name}"]
      }
      
      file { "${apache::params::conf}/sites-available/${name}":
        ensure  => absent,
        require => Exec["disable vhost ${name}"]
      }

      exec { "remove ${home}/${name}":
        command => "rm -rf ${home}/${name}",
        onlyif  => "test -d ${home}/${name}",
        require => Exec["disable vhost ${name}"],
      }

      exec { "disable vhost ${name}":
        command => $operatingsystem ? {
          RedHat => "/usr/local/sbin/a2dissite ${name}",
          CentOS => "/usr/local/sbin/a2dissite ${name}",
          default => "/usr/sbin/a2dissite ${name}"
        },
        notify  => Exec["apache-graceful"],
        require => [$operatingsystem ? {
          redhat => File["${apache::params::a2ensite}"],
          CentOS => File["${apache::params::a2ensite}"],
          default => Package[$apache::params::pkg]}],
        onlyif => "/bin/sh -c '[ -L ${apache::params::conf}/sites-enabled/${name} ] \\
          && [ ${apache::params::conf}/sites-enabled/${name} -ef ${apache::params::conf}/sites-available/${name} ]'",
      }
   }

   disabled: {
      exec { "disable vhost ${name}":
        command => "a2dissite ${name}",
        notify  => Exec["apache-graceful"],
        require => Package[$apache::params::pkg],
        onlyif => "/bin/sh -c '[ -L ${apache::params::conf}/sites-enabled/${name} ] \\
          && [ ${apache::params::conf}/sites-enabled/${name} -ef ${apache::params::conf}/sites-available/${name} ]'",
      }

      file { "${apache::params::conf}/sites-enabled/${name}":
        ensure  => absent,
        require => Exec["disable vhost ${name}"]
      }
    }
    default: { err ( "Unknown ensure value: '${ensure}'" ) }
  }
}
