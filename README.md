# Ansible role to install HashiCorp Vault

This Ansible role installs/updates and configures vault


## Optional Variables

Dev mode:
```yml
vault_server_dev_mode: true
vault_server_dev_mode_listener_address: 0.0.0.0:8200
vault_server_dev_mode_root_token: 1234-5678-9012-3456
```

Note that switches vault to use an in-memory storage backend
and it does not register itself with consul. See the ["Dev" Server Mode](https://www.vaultproject.io/docs/concepts/dev-server.html)
docs to learn more.


## Usage

```yml
- role: vault
  vault_actions:
    - tmp-ca
    - install
    - init
    - token
    - unseal
    - audit
    - mount
    - auth
    - secret
    - policy
  # install
  vault_server: true
  vault_listener_address: 0.0.0.0:8200
  vault_telemetry_enabled: true
  vault_telemetry_statsd_address: 127.0.0.1:8125
  # init / token /unseal
  vault_keys_file: /tmp/.vault_keys
  vault_keys_file_local: /tmp/.vault_keys
  vault_init_gpg_required: false

  # audit
  vault_audit_config:
    - path: syslog
      config:
        type: syslog
        options:
          tag: vault
          facility: AUTH

  # mount
  vault_mount_config:
    - path: ops
      config:
        type: generic
        description: infrastructure secrets
    - path: transit
      parameters:
        type: transit
        description: pass-through encryption
    - path: pki
      config:
        type: pki
        description: Intermediate CA
        config:
          - path: sys/mounts/pki/tune
            data:
              max_lease_ttl: 8760h
          - path: pki/roles/vault
            data:
              max_ttl: 8760h
              allow_any_name: true

  # auth
  vault_auth_config:
    # Note: This is the default token auth backend
    - path: token
        parameters:
          type: token
          description: token based credentials
        config:
          - path: token/roles/testapp
            data:
              period: 60m
              orphan: true
              allowed_policies: "default"

  # secret
  vault_secret_config:
    - path: ops/test/foo
      payload:
        ttl: 1h
        app_id: bar
        app_secret: bazz

  # policy
  vault_policy_config:
  - name: administrator
    payload:
      rules: |
          path "*" {
            capabilities = ["list", "read", "create", "update", "delete", "sudo"]
          }

  tags:
    - vault
```


## Emergency Usage

```yml
# Seals the vault (USE CAREFULLY!)
- role: vault
  vault_actions:
    - token
    - seal
  vault_keys_file: /tmp/.vault_keys
  vault_keys_file_local: /tmp/.vault_keys
  tags:
    - vault
```


## License

MIT
