def max_nat_conditions(maximum_azs)

  maximum_azs.times do |az|
    Condition("#{az+1}NatGateways", FnEquals((az + 1).to_s, Ref('MaxNatGateways')))
  end


  Condition("RoutedBySingleNat", FnEquals(Ref("SingleNatGateway"), 'true'))

  maximum_azs.times do |az|
    range_inverted=*(az..maximum_azs-1)
    az_condition = Condition("Az#{az}")
    if range_inverted.size() > 1
      nat_condition = FnOr(range_inverted.map { |x| Condition("#{x+1}NatGateways") })
    else
      nat_condition = Condition("#{az+1}NatGateways")
    end
    Condition("NatGateway#{az}Exist", FnAnd([az_condition, nat_condition]))
    Condition("RoutedByNat#{az}", FnAnd([Condition("NatGateway#{az}Exist"), FnNot([Condition("RoutedBySingleNat")])]))
    Condition("RoutedBySingleNat#{az}", FnAnd([Condition("Az#{az}"), Condition("RoutedBySingleNat")]))
  end

end