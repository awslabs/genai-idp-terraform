# External identity provider federation (SAML / OIDC)

Federate an external identity provider (Okta, PingOne, ADFS, Auth0, Entra ID)
into the solution's Cognito user pool so users sign in with corporate
credentials and land in the right RBAC role.

Federation is off by default. Direct Cognito sign-in keeps working when it is
enabled: `COGNITO` is always retained in the pool client's supported identity
providers.

## What gets created

Setting `idp_federation.enabled = true` provisions, via
`modules/features/idp-federation`:

- a Cognito identity provider (`SAML` or `OIDC`) on the user pool
- attribute mapping from IdP claims to `email`, `given_name`, `family_name` and,
  when `group_attribute_name` is set, `custom:idp_groups`
- a group-mapping Lambda to attach as the pool's `PreTokenGeneration` (`V2_0`)
  trigger, which reads `custom:idp_groups` and adds the user to the matching
  RBAC Cognito group

Three things must then be true on the **user pool**, which may or may not be
owned by this module (see the two paths below):

1. the pool client lists the external provider alongside `COGNITO`
2. the pool schema has the custom `idp_groups` attribute
3. the pool has a hosted UI domain, since federated sign-in redirects through it

## Supplying the OIDC client secret

The secret is passed **by reference**, never as a literal:

```hcl
idp_federation = {
  enabled                = true
  provider_type          = "OIDC"
  provider_name          = "Okta"
  oidc_issuer            = "https://example.okta.com/oauth2/default"
  oidc_client_id         = "0oa1example"
  oidc_client_secret_ref = "arn:aws:secretsmanager:us-east-1:111122223333:secret:okta-client-secret-AbCdEf"
  oidc_authorize_scopes  = "openid email profile"
  group_attribute_name   = "groups"
}
```

`oidc_client_secret_ref` accepts a Secrets Manager secret ARN or an SSM
parameter name. It is read at apply time and only ever flows into the identity
provider's `provider_details`.

## Path 1: the module owns the user pool

If you do not set `var.user_identity`, the module creates the pool through
`modules/user-identity` and wires all three requirements automatically. One
apply is enough:

```hcl
module "genai_idp_accelerator" {
  source = "../.."

  # user_identity omitted, so the module creates the pool

  idp_federation = {
    enabled              = true
    provider_type        = "SAML"
    provider_name        = "PingOne"
    saml_metadata_url    = "https://auth.pingone.com/.../saml20/metadata"
    group_attribute_name = "groups"
  }
}
```

Set `idp_federation.hosted_ui_domain_prefix` if you need a specific hosted UI
domain prefix. It must be globally unique across all AWS accounts, and Cognito
rejects prefixes containing `aws`, `amazon` or `cognito`.

## Path 2: you own the user pool (two applies)

Every processor example under `examples/` creates Cognito itself and passes it in
through `var.user_identity`. The pool then lives *outside* the module while the
federation resources are created *inside* it, so wiring the trigger by direct
reference would close a dependency cycle:

```
pool -> module -> group-mapping Lambda -> pool.PreTokenGeneration -> pool
```

Terraform reports this as `Error: Cycle: ...`. The resolution is two applies.

**First apply** turns federation on and creates the identity provider and the
group-mapping Lambda:

```hcl
idp_federation = {
  enabled              = true
  provider_type        = "OIDC"
  provider_name        = "Okta"
  oidc_issuer          = "https://example.okta.com/oauth2/default"
  oidc_client_id       = "0oa1example"
  oidc_client_secret_ref = "arn:aws:secretsmanager:...:okta-client-secret-AbCdEf"
  group_attribute_name = "groups"
}
```

Then read the two outputs:

```console
$ terraform output federation_group_mapping_function_arn
"arn:aws:lambda:us-east-1:111122223333:function:Okta-idp-group-mapping"
$ terraform output federation_supported_identity_providers
tolist(["Okta"])
```

**Second apply** feeds them back onto your pool. In
`examples/unified-processor` that is one variable:

```hcl
federation_pool_wiring = {
  supported_identity_providers      = ["Okta"]
  pre_token_generation_function_arn = "arn:aws:lambda:us-east-1:111122223333:function:Okta-idp-group-mapping"
  enable_idp_groups_attribute       = true
  hosted_ui_domain_prefix           = "my-idp-signin"
}
```

Also set `idp_federation.hosted_ui_domain` to the resulting FQDN
(`<prefix>.auth.<region>.amazoncognito.com`) so the web UI knows where to
redirect.

If you wire your own pool by hand instead, apply the same three changes: append
the provider name to the client's `supported_identity_providers`, add the
`idp_groups` string attribute to the pool schema, and attach the Lambda as
`lambda_config.pre_token_generation_config` with `lambda_version = "V2_0"`.
`V2_0` is required: the handler returns
`claimsAndScopeOverrideDetails.groupOverrideDetails`, which `V1_0` does not
carry.

## The `idp_groups` attribute is a one-way door

Cognito can add a schema attribute to an existing pool in place, but it can
**never remove one**. Adding `idp_groups` is therefore irreversible: turning the
option back off does not produce a resolvable plan.

Before enabling it on a pool that holds real users, confirm the plan shows an
in-place update and **not** a replacement of `aws_cognito_user_pool`. A
replacement destroys every user in the pool.

## Group mapping

With `group_attribute_name` set to the claim carrying the user's groups, name
your IdP's groups in `idp_federation.group_mapping` and map each to one of the
four roles:

```hcl
idp_federation = {
  enabled              = true
  group_attribute_name = "groups"

  group_mapping = {
    "IDP-Admins"    = "Admin"
    "IDP-Authors"   = "Author"
    "IDP-Reviewers" = "Reviewer"
    "IDP-Everyone"  = "Viewer"
  }
}
```

The keys are the group names as they appear in the claim; the values must be the
canonical roles. One external group per role — the trigger reads a single group
name per role, so a second one mapped to the same role is rejected at plan time.
A role you leave unmapped is simply never assigned.

Users whose claim matches no mapped group are added to no RBAC group and have no
access beyond authentication.

The trigger adds users to the groups named `Admin`, `Author`, `Reviewer` and
`Viewer` literally. Renaming them through `var.rbac.group_names` puts them out of
its reach, so enabling group mapping on a deployment with renamed groups fails
the plan rather than signing federated users in with no role.

## OAuth scopes

The pool client must allow the `phone` scope. The hosted UI requests it during
federated sign-in and Cognito fails the authorize call with `invalid_scope`
without it. All shipped examples now include
`["email", "openid", "phone", "profile"]`.

## Sign-in experience

When federation is enabled the web UI build receives `VITE_COGNITO_DOMAIN`,
`VITE_EXTERNAL_IDP_NAME` and `VITE_EXTERNAL_IDP_AUTO_LOGIN`. Set
`idp_federation.auto_login = true` to send users straight to the external IdP
instead of showing the hosted UI's provider chooser.

## Callback URLs

Federated sign-in redirects back to a URL the pool client explicitly allows. Set
`web_ui.custom_domain_url` and it is registered as both a callback and a logout
URL. A CloudFront-only deployment has no stable custom domain, so add the
distribution URL to your pool client's callback list yourself after the first
apply.

## Perpetual diff on the OIDC provider

Cognito resolves `attributes_url`, `attributes_url_add_attributes`,
`authorize_url`, `jwks_uri` and `token_url` from the issuer's OpenID discovery
document and writes them back into `provider_details`. They are never present in
configuration, so the module ignores changes to those five keys. Without that,
every plan reports a diff on an unchanged provider.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Error: Cycle: ...` mentioning `pre_token_generation` | The trigger was referenced directly on a pool created outside the module. Use the two-apply flow. |
| `invalid_scope` on the authorize call | The `phone` scope is missing from the pool client. |
| Federated user signs in but has no permissions | Group mapping is not wired: check `group_attribute_name`, that the trigger is attached as `V2_0`, and that the `group_mapping` keys match the group names in the claim. |
| Sign-in page shows no external provider button | The provider name is not in the client's `supported_identity_providers`, or the UI was built before federation was enabled. |
| Redirect fails after authenticating at the IdP | The redirect URL is not in the client's callback URLs, or no hosted UI domain exists. |
