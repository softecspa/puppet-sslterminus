class sslterminus{

  if !defined(Class['nginx']) {

    $proxy_conf_template = $::lsbdistcodename? {
      'lucid' => 'nginx/conf.d/proxy.conf.erb',
      default => 'nginx/conf.d/proxy.conf-prior-1.1.4.erb'
    }

    class {'nginx':
      super_user              => true,
      worker_processes        => '2',
      worker_rlimit_nofile    => '4096',
      worker_connections      => '2048',
      multi_accept            => 'off',
      server_tokens           => 'off',
      http_tcp_nopush         => 'on',
      http_tcp_nodelay        => 'off',
      types_hash_max_size     => '2048',
      names_hash_bucket_size  => '64',
      types_hash_bucket_size  => '64',
      underscores_in_headers  => 'on',
      proxy_set_header        => [
        'HTTP_HOST $http_host',
        'Host $host',
        'X-Forwarded-For $remote_addr',
        'X-Real-IP $remote_addr',
        'X-Ssl 1'
      ],
      confd_purge             => true,
      vhost_purge             => true,
      proxy_conf_template     => $proxy_conf_template,
    }

    $my_hash = $::subnet_hash

    nginx::resource::geo {'from_softec':
      networks        => $my_hash,
      default_value   => '0',
    }
  }

}
