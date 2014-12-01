module Flare; end
module Flare::Entity; end
class Flare::Entity::Server < Struct.new(:host, :port)
  def to_s
    nodekey
  end

  def nodekey
    "#{self.host}:#{self.port}"
  end
end
