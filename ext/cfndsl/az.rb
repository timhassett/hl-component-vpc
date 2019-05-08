$maximum_availability_zones = 6

def az_conditions(x = $maximum_availability_zones)
  x.times do |az|
    Condition("Az#{az}", FnNot([FnEquals(Ref("Az#{az}"), false)]))
  end

  x.times do |i|
    tf = []
    (i + 1).times do |y|
      tf << { 'Condition' => "Az#{y}" }
    end
    (x - (i + 1)).times do |z|
      tf << FnNot(['Condition' => "Az#{i + z + 1}"])
    end
    Condition("#{i + 1}Az", FnAnd(tf))
  end
end

def nat_gateway_ips_list_internal(x = $maximum_availability_zones)
  if x.to_i > 0
    resources = []
    x.times do |y|
      resources << FnIf("Nat#{y}EIPRequired",
          Ref("NatIPAddress#{y}"),
          Ref("AWS::NoValue")
      )
    end
    if_statement = FnIf("NatGateway#{x-1}Exist", resources, nat_gateway_ips_list_internal( x - 1))
    if_statement
  else
    FnIf("Nat#{x}EIPRequired",
        Ref("NatIPAddress#{x}"),
        Ref("AWS::NoValue")
    )
  end
end

def az_conditional_resources_internal(resource_name, x = $maximum_availability_zones)
  if x.to_i > 0
    resources = []
    x.times do |y|
      resources << Ref("#{resource_name}#{y}")
    end
    if_statement = FnIf("#{x}Az", resources, az_conditional_resources_internal(resource_name, x - 1))
    if_statement
  else
    Ref("#{resource_name}#{x}")
  end
end

def az_conditions_resources(resource_name, x = $maximum_availability_zones)
  if x.to_i > 0
    x.times do |y|
      if y <= 1
        Condition("#{y}#{resource_name}", FnNot([FnEquals(Ref("#{resource_name}#{y}"), "")]))
      elsif y-1 >= 0
        Condition("#{y}#{resource_name}", FnAnd([
            FnNot([FnEquals(Ref("#{resource_name}#{y}"), "")]),
            Condition("#{y-1}#{resource_name}")
        ]))
      end
    end
  end
end

def az_conditional_resources(resource_name, x = $maximum_availability_zones)
  if x.to_i > 0
    resources = []
    x.times do |y|
      resources << Ref("#{resource_name}#{y}")
    end
    if_statement = FnIf("#{x-1}#{resource_name}", resources, az_conditional_resources(resource_name, x - 1)) if x>1
    if_statement = Ref("#{resource_name}#{x}") if x == 1
    if_statement
  else
    Ref("#{resource_name}#{x}")
  end
end


def az_conditional_resources_names(resource_name, x = $maximum_availability_zones)
  if x.to_i > 0
    resources = []
    x.times do |y|
      resources << "#{resource_name}#{y}"
    end
    if_statement = FnIf("#{x}Az", resources, az_conditional_resources_names(resource_name, x - 1))
    if_statement
  else
    "#{resource_name}#{x}"
  end
end

def az_conditional_resources_array(resource_name, x = $maximum_availability_zones)
  if x.to_i > 0
    if_statement = FnIf("#{x}Az", resource_name[x - 1], az_conditional_resources_array(resource_name, x - 1))
    if_statement
  else
    resource_name[0]
  end
end

def az_create_subnets(subnet_allocation, subnet_name, type = 'private', vpc = 'VPC', x = $maximum_availability_zones, tags = [])
  subnets = []
  x.times do |az|
    subnet_name_az = "Subnet#{subnet_name}#{az}"
    subnet_tags = []
    subnet_tags += tags
    subnet_tags << { Key: 'Name', Value: "#{subnet_name}#{az}" }
    Resource(subnet_name_az) do
      Condition "Az#{az}"
      Type 'AWS::EC2::Subnet'
      Property('VpcId', Ref(vpc.to_s))
      Property('CidrBlock', FnJoin('', ['10.', Ref('StackOctet'), ".#{subnet_allocation * x + az}.0/24"]))
      Property('AvailabilityZone', Ref("Az#{az}"))
      Property('Tags', tags)
    end

    # Route table associations
    if type == 'private'
      # Associate subnet with public route
      EC2_SubnetRouteTableAssociation("RouteTableAssociation#{subnet_name_az}") do
        Condition "Az#{az}"
        SubnetId Ref(subnet_name_az)
        RouteTableId Ref("RouteTablePrivate#{az}")
      end
    end

    if type == 'public'
      # Associate Subnet with public ACL
      EC2_SubnetNetworkAclAssociation("ACLAssociation#{subnet_name_az}") do
        Condition "Az#{az}"
        SubnetId Ref(subnet_name_az)
        NetworkAclId Ref('PublicNetworkAcl')
      end

      # Associate subnet with public route
      EC2_SubnetRouteTableAssociation("RouteTableAssociation#{subnet_name_az}") do
        Condition "Az#{az}"
        SubnetId Ref(subnet_name_az)
        RouteTableId Ref('RouteTablePublic')
      end
    end
    subnets << "#{subnet_name}#{az}"
  end

  subnets
end

def az_create_private_route_associations(subnet_name, x = $maximum_availability_zones)
  x.times do |az|
    Resource("RouteTableAssociation#{subnet_name}#{az}") do
      Condition "Az#{az}"
      Type 'AWS::EC2::SubnetRouteTableAssociation'
      Property('SubnetId', Ref("#{subnet_name}#{az}"))
      Property('RouteTableId', Ref("RouteTablePrivate#{az}"))
    end
  end
end
