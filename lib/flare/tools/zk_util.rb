
require 'zookeeper'

module Flare
  module Tools
    module ZkUtil
      ZOK = 0

      def clear_nodemap z, path
        path_nodemap = "#{path}/index/nodemap"
        xml = <<EOS
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<!DOCTYPE boost_serialization>
<boost_serialization signature="serialization::archive" version="4">
<node_map class_id="0" tracking_level="0" version="0">
	<count>0</count>
	<item_version>0</item_version>
</node_map>
<thread_type>16</thread_type>
</boost_serialization>
EOS
        result = z.set(:path => path_nodemap, :data => xml)
        rc = result[:rc]
        raise "failed to clear nodemap (#{rc})" if rc != ZOK
      end
    end # module ZkUtil
  end # module Tools
end # module Flare
