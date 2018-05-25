### Config


### Mappings

AZ maps are generated based on `managed_accounts` config setting. This defaults to only default
account picked up by ruby sdk. Additionally you can *always* use only default account by setting
environment variable `HL_VPC_AZ_LOCAL_ONLY` to `1`. Generated mappings are generated in `$HIGHLANDER_WORKDIR/az.mappings.yaml`, which 
defaults to `$PWD` (directory from where cli is executed). This functionality follows logic that highlander cli
is executed within directory where "master" component is stored. 

Once generated, az mappings file can be checked into scm repository, resulting in static AZs in produced CloudFormation
template. 