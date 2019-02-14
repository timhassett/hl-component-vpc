#### Parameter definitions HighLanderTemplate
## 1. embed parameters in modules and set default values
## 2. expose metadata for highlander assembly to assemble master template

CfhighlanderTemplate do

  Name 'VPC'
  ComponentVersion component_version
  ComponentDistribution 's3://source.highlander.base2.services/components'

  ##Definitions of parameters, to be embedded in cfn template, and to be
  # exposed as metadata
  Parameters do

    # Param with default value inside module config
    # but also exposed as top-level parameter
    ComponentParam 'EnvironmentType', isGlobal: true
    ComponentParam 'EnvironmentName', isGlobal: true
    ComponentParam 'StackOctet', 10, isGlobal: true
    ComponentParam 'NetworkPrefix', 10, isGlobal: true

    # Param with default value inside module config
    # but not exposed as top level parameter. Default config
    # can be overwritten
    ComponentParam 'StackMask', '16', isGlobal: true

    if enable_transit_vpc
      ComponentParam 'EnableTransitVPC', 'false', isGlobal: true
    end

    # Account mappings for AZs
    maximum_availability_zones.times do |x|
      az = x

      MappingParam "Az#{az}" do

        ## Predefined available maps
        ## AccountIdRegionMap and AccountIdMap
        map 'AzMappings'
        # Name of the attribute pulled from map
        attribute "Az#{az}"

      end

      ComponentParam "Nat#{az}EIPAllocationId", 'dynamic'

    end

    # Mapping parameter looking up value per domain
    MappingParam 'DnsDomain' do
      map 'AccountId'
      attribute 'DnsDomain'
    end

    MappingParam 'MaxNatGateways', maximum_availability_zones do
      map 'EnvironmentType'
      attribute 'MaxNatGateways'
    end

    MappingParam 'SingleNatGateway', 'true' do
      map 'EnvironmentType'
      attribute 'SingleNatGateway'
    end

  end

  Component template: 'route53-zone@1.0.2', name: 'dnszone', render: Inline do
    parameter name: 'CreateZone', value: 'true'
    parameter name: 'RootDomainName', value: FnSub('${DnsDomain}.')
  end if manage_ns_records
end
