# = Define sslterminus::domain
#
# This define make a nginx VirtualHost that works as SSL terminus. VirtualHost binds on a specified ip address, port 443 and
# forward requests to backends in http.
#
# == Params
#
# [*ensure*]
#   if present, nginx VH is linked in sites-enabled dir. If absent VH will be deleted. If disabled, VH will only unlinked un sites-enabled dir.
#
# [*domain_name*]
#   ServerName of the nginx VH. <name> will be used if it's not spedified. if sslcertname is not speficied certificates will be searched by puppet in modules/sslcert/files/domain_name/
#
# [*wildcard*]
#   if true, nginx server name become *.domain_name. Default: false
#
# [*proxy*]
#   Where requests should be proxyed. Default: http://localhost:80.
#
# [*listen_ip*]
#   ip address on which VH listens. Default: *
#
# [*sslcertname*]
#   If you want to use non default certificates. If this parameter is specified, certificates will be searched under modules/sslcert/files/<sslcertname>/ path
#
# [*serveraliases*]
#   server aliases for the nginx VH.
#
define sslterminus::domain(
  $ensure               = present,
  $domain_name          = '',
  $wildcard             = false,
  $proxy                = 'http://localhost:80',
  $listen_ip            = '*',
  $sslcertname          = '',
  $serveraliases        = [],
  $client_max_body_size = '20m',
  $auth_basic           = undef,
  $auth_basic_user_file = undef,
  $raw_prepend          = [],
  $proxy_read_timeout   = '90',
)
{
  #TODO: parameters check
  #TODO: parametrize ssl paths

  $ssl_certname = $sslcertname? {
    ''      => $name,
    default => $sslcertname
  }

  validate_array($serveraliases)

  include sslterminus

  $domainname = $domain_name? {
    ''      => $name,
    default => $domain_name
  }

  $servernames = $wildcard ? {
    true  => concat( [ $domainname, "*.${domainname}"],$serveraliases ),
    false => concat( [ $domainname ], $serveraliases )
  }

  if ! defined (Sslcert::Cert[$ssl_certname]) {
    sslcert::cert {$ssl_certname:
      notify      => Service['nginx'],
    }
  }

  $servernames_string=join($servernames, ' ')
  $escaped_servernames = regsubst(regsubst(regsubst($servernames_string,'\ ','|','G'),'\.','\.','G'),'\*','.*','G')

  $redirection = [
    "if (\$host !~* \"${escaped_servernames}\") {",
    '  rewrite  ^(.*)$  http://cluster.asp.softecspa.it/ssl_redirection.php?redir=$host$1  permanent;',
    '}'
  ]
  $real_raw_prepend =concat($redirection,$raw_prepend)

  $ssl_listen_option = $::lsbdistcodename ?{
    'lucid' => false,
    default => true
  }

  nginx::resource::vhost { "nginx-vhost-${name}":
    ensure                => $ensure,
    listen_ip             => $listen_ip,
    server_name           => $servernames,
    listen_port           => 443,
    ssl                   => true,
    ssl_listen_option     => $ssl_listen_option,
    ssl_cert              => "/etc/ssl/${ssl_certname}/sslcert.crt",
    ssl_key               => "/etc/ssl/${ssl_certname}/sslkey.key",
    ssl_dhparam           => "puppet:///modules/sslcert/dhparam.pem",
    ssl_session_timeout   => '10m',
    ssl_protocols         => 'TLSv1 TLSv1.1 TLSv1.2',
    ssl_ciphers           => '"EECDH+ECDSA+AESGCDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS"',
    add_header            => 'Strict-Transport-Security "max-age=31536000; includeSubdomains"', 
    proxy                 => $proxy,
    proxy_read_timeout    => $proxy_read_timeout,
    proxy_redirect        => 'off',
    proxy_connect_timeout => '90',
    index_files           => [],
    location_cfg_append   => {
      'client_body_buffer_size' => '128k',
      'proxy_send_timeout'      => '90',
      'proxy_buffers'           => '32 4k',
      'client_max_body_size'    => $client_max_body_size,
    },
    location_raw_append   => ['if ($from_softec) {', "  add_header X-Ssl-Terminus ${::hostname};", '  add_header X-Debug 1;','}'],
    raw_prepend           => $real_raw_prepend,
    auth_basic            => $auth_basic,
    auth_basic_user_file  => $auth_basic_user_file,
  }
}
