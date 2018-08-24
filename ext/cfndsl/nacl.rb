def nacl_entry( cidr_block, entry, type, acl_id)
  EC2_NetworkAclEntry("#{type}#{entry['number']}") {
    NetworkAclId acl_id
    RuleNumber entry['number']
    Protocol entry['protocol'] || '6'
    RuleAction entry['action'] || 'allow'
    Egress (type == 'outbound' ? true : false)
    CidrBlock cidr_block
    PortRange ({ From: entry['from'], To: entry['to'] || entry['from'] })
  }
end