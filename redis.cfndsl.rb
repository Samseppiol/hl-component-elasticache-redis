CloudFormation do

  Condition(:FailOver, FnNot(FnEquals(Ref(:CacheClusters), '1')))
  Condition(:Cluster, FnEquals(Ref(:Cluster), 'true'))
  az_conditions_resources('SubnetCache', maximum_availability_zones)

  tags = []
  tags << { Key: 'Environment', Value: Ref(:EnvironmentName) }
  tags << { Key: 'EnvironmentType', Value: Ref(:EnvironmentType) }

  extra_tags.each { |key,value| tags << { Key: key, Value: value } } if defined? extra_tags

  EC2_SecurityGroup(:SecurityGroupRedis) do
    VpcId Ref('VPCId')
    GroupDescription FnJoin(' ', [ Ref(:EnvironmentName), component_name, 'security group' ])
    SecurityGroupIngress sg_create_rules(security_groups, ip_blocks)
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'security-group' ])}]
  end

  ElastiCache_SubnetGroup(:RedisSubnetGroup) {
    Description FnJoin('',[ Ref(:EnvironmentName), 'redis parameter group'] )
    SubnetIds az_conditional_resources('SubnetCache', maximum_availability_zones)
  }

  ElastiCache_ParameterGroup(:RedisParameterGroup) {
    CacheParameterGroupFamily family
    Description FnJoin(' ',[ Ref(:EnvironmentName), component_name, 'parameter group'] )
    Properties parameters if defined? parameters
  }

  cluster_parameters = { 'cluster-enabled': 'yes' }
  cluster_parameters.merge!(parameters) if defined? parameters

  ElastiCache_ParameterGroup(:RedisClusterParameterGroup) {
    CacheParameterGroupFamily family
    Description FnJoin(' ',[ Ref(:EnvironmentName), component_name, 'parameter group'] )
    Properties cluster_parameters
  }

  ElastiCache_ReplicationGroup(:RedisReplicationGroup) {
    DependsOn ["RedisSubnetGroup"]

    ReplicationGroupDescription FnJoin(' ',[ Ref(:EnvironmentName), component_name, 'replication group'] )

    Engine 'redis'
    EngineVersion engine_version if defined? engine_version
    AutoMinorVersionUpgrade minor_upgrade || true
    Port redis_port if defined? redis_port
    CacheNodeType Ref(:CacheInstanceType)
    CacheParameterGroupName FnIf(:Cluster, Ref(:RedisClusterParameterGroup), Ref(:RedisParameterGroup))
    CacheSubnetGroupName Ref(:RedisSubnetGroup)
    SecurityGroupIds [ Ref(:SecurityGroupRedis) ]

    Property('AtRestEncryptionEnabled', encrypt) if defined? encrypt

    # AuthToken 'String'
    # TransitEncryptionEnabled true
    AutomaticFailoverEnabled FnIf(:FailOver, true, false)
    case cluster_type
    when 'cache_cluster'
      NumCacheClusters Ref(:CacheClusters)
    when 'node_group'
      NumNodeGroups FnIf(:Cluster, Ref(:NumNodeGroups), 1)
      ReplicasPerNodeGroup FnIf(:Cluster, Ref(:ReplicasPerNodeGroup), 0)
    end if defined? cluster_type

    SnapshotArns [ Ref(:S3Snapshot) ] if restore_from_s3
    SnapshotName Ref(:Snapshot) if restore_from_snapshot
    SnapshotWindow snapshot_window if defined? snapshot_window
    SnapshotRetentionLimit Ref(:SnapshotRetentionLimit)
    PreferredMaintenanceWindow maintenance_window if defined? maintenance_window
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'cache-cluster' ]) }]
  }

  record = (defined?(dns_record) ? "#{dns_record}" : 'redis')

  Route53_RecordSet(:RedisHostRecord) {
    HostedZoneName FnJoin('', [ Ref(:EnvironmentName), '.', Ref(:DnsDomain), '.'])
    Name FnJoin('', [record, '.', Ref(:EnvironmentName), '.', Ref(:DnsDomain), '.'])
    Type 'CNAME'
    TTL '60'
    ResourceRecords [ FnGetAtt(:RedisReplicationGroup, Ref('RedisEndpointType')) ]
  }
end
