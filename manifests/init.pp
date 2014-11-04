class sslterminus{

  if !defined(Class['nginx']) {

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
      manage_repo             => false,
    }

    $my_hash = $::subnet_hash

    nginx::resource::geo {'from_softec':
      networks        => $my_hash,
      default_value   => '0',
    }
  }

}
