# zen-nodes
An experimental effort to automate setting up Horizen nodes.  The scripts have yet to be migrated to execute all commands from a non-root user, so this project is not yet fully functional.

## Setup
Set the following environment variables that Terraform will need:

- `ZEN_DOMAIN                 // Domain used for DNS purposes whose cname records will point to ZEN nodes`
- `DNSIMPLE_ACCESS_TOKEN_ZEN  // dnsimple access token`
- `DNSIMPLE_ACCOUNT           // dnsimple account id`
- `DNSIMPLE_EMAIL             // Email associated with dnsimple account`
- `ZEN_EMAIL                  // Email to be used for event notification purposes`
- `SCALEWAY_ORG_ID            // Scaleway organization ID`
- `SCALEWAY_SECRET_KEY        // Scaleway API access secret key`
