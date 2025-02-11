CfhighlanderTemplate do
  Name 'ElastiCacheRedis'
  Description "#{component_name} - #{component_version}"
  ComponentVersion component_version

  DependsOn 'vpc'

  Parameters do
    ComponentParam 'VPCId'
    ComponentParam 'StackOctet', isGlobal: true
    ComponentParam 'EnvironmentName', 'dev', isGlobal: true
    ComponentParam 'EnvironmentType', 'development', isGlobal: true, allowedValues: ['development', 'production']
    ComponentParam 'DnsDomain'
    ComponentParam 'CacheInstanceType'
    ComponentParam 'RedisEndpointType', 'PrimaryEndPoint.Address'

    ComponentParam 'S3Snapshot', '' if restore_from_s3
    ComponentParam 'Snapshot', '' if restore_from_snapshot

    ComponentParam 'CacheClusters', 1, allowedValues: [1,2,3,4,5,6]
    ComponentParam 'Cluster', 'false', allowedValues: ['true','false']
    ComponentParam 'NumNodeGroups', 1
    ComponentParam 'ReplicasPerNodeGroup', 0, allowedValues: [0,1,2,3,4,5]

    MappingParam 'SnapshotRetentionLimit', 0 do
      map 'EnvironmentType'
      attribute 'SnapshotRetentionLimit'
    end

    maximum_availability_zones.times do |az|
      ComponentParam "SubnetCache#{az}"
    end
  end
end
