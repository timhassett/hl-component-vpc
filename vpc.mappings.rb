require 'aws-sdk-core'
require 'aws-sdk-ec2'
require 'aws-sdk-sts'

module Highlander

  module MapProviders

    class AzMappings

      @@maps = nil

      def self.getMaps(config)
        return @@maps if not @@maps.nil?
        cached_mappings_path = "#{ENV['HIGHLANDER_WORKDIR']}/az.mappings.yaml"

        if File.exists? cached_mappings_path
          maps = YAML.safe_load(File.read(cached_mappings_path))
          unless maps.nil?
            @@maps = maps
            return @@maps
          end
        end

        raise 'No managed_accounts config key for AzMappings helper' unless config.key? 'managed_accounts'
        raise 'No maximum_availability_zones' unless config.key? 'maximum_availability_zones'
        maps = {}
        # loop over managed accounts
        only_local = (ENV.key? 'HL_VPC_AZ_LOCAL_ONLY') and (ENV['HL_VPC_AZ_LOCAL_ONLY'] == '1')
        config['managed_accounts'].each do |name, account_config|
          credentials = nil

          if (account_config.key? 'local' and account_config['local'])
            puts("Collecting AZ mapping for default account")
            sts = Aws::STS::Client.new(region: 'us-east-1')
            aws_account_id = sts.get_caller_identity().account
          else
            next if only_local
            puts("Collecting AZ mapping for #{name} - #{account_config['aws_account_number']}")
            credentials = Aws::AssumeRoleCredentials.new(
                role_arn: "arn:aws:iam::#{account_config['aws_account_number']}:role/#{account_config['assume_iam_role']}",
                role_session_name: "az_mappings_highlander_#{name}",
                region: 'us-east-1'
            )
            aws_account_id = account_config['aws_account_number']
          end

          # if mapping default sdk zones or from assumed role
          if credentials.nil?
            ec2_client = ec2 = Aws::EC2::Client.new(region: 'us-east-1')
          else
            ec2_client = ec2 = Aws::EC2::Client.new(region: 'us-east-1', credentials: credentials)
          end

          region_resp = ec2.describe_regions()
          maps[aws_account_id.to_s] = {}
          region_resp.regions.each do |region|
            maps[aws_account_id.to_s][region.region_name]={}
            config['maximum_availability_zones'].times do |i|
              maps[aws_account_id.to_s][region.region_name]["Az#{i}"] = false
            end
            ec2region = Aws::EC2::Client.new(region: region.region_name) if credentials.nil?
            ec2region = Aws::EC2::Client.new(region: region.region_name, credentials: credentials) unless credentials.nil?
            az_resp = ec2region.describe_availability_zones({})
            az_resp.availability_zones.each_with_index do |az, i|
              maps[aws_account_id][region.region_name]["Az#{i}"] = az.zone_name
            end
          end
        end
        @@maps = maps
        FileUtils.mkpath (File.dirname (cached_mappings_path )) unless File.exists? (File.dirname (cached_mappings_path))
        File.write(cached_mappings_path, maps.to_yaml)
        return maps
      end

      def self.getMapName
        return "Ref('AWS::AccountId')"
      end

      def self.getDefaultKey
        return "Ref('AWS::Region')"
      end

    end

  end

end