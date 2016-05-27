require 'yast'
require_relative 'base_component_configuration.rb'
Yast.import 'UI'

module Yast
  # Communication Layer Configuration
  class CommunicationLayerConfiguration < BaseComponentConfiguration

    attr_reader  :number_of_rings,
                 :transport_mode,
                 :cluster_name,
                 :expected_votes

    include Yast::UIShortcuts
    include Yast::Logger # TODO: rm

    def initialize(number_of_rings = 1)
      @rings = {}
      @transport_mode = :unicast
      @number_of_rings = number_of_rings
      @cluster_name = 'hacluster'
      # TODO: shouldn't it be in cluster_members?
      @expected_votes = 2
      init_rings
    end

    def init_rings
      (1..@number_of_rings).each do |ix|
        @rings["ring#{ix}".to_sym] = {
          address: '',
          port: '',
          id: ix,
          mcast: ''
        }
      end
    end

    def table_items
      if @transport_mode == :unicast
        @rings.map { |k, v| Item(Id(k), k.to_s, v[:address], v[:port]) }
      else
        @rings.map { |k, v| Item(Id(k), k.to_s, v[:address], v[:port], v[:mcast]) }
      end
    end

    def number_of_rings=(value)
      @number_of_rings = value
      # reinit the items
      rings_old = @rings.dup
      @rings = {}
      (1..@number_of_rings).each do |ix|
        key = "ring#{ix}".to_sym
        if rings_old.key?(key)
          @rings[key] = rings_old[key]
        else
          @rings[key] = {
            address: '',
            port: '',
            id: ix,
            mcast: ''
          }
        end
      end
    end

    def ring_info(ring_id)
      @rings[ring_id]
    end

    def all_rings
      @rings.dup
    end

    def update_ring(ring_id, values)
      [:address, :port].each { |e| @rings[ring_id][e] = values[e] }
      if @transport_mode == :multicast
        @rings[ring_id][:mcast] = values[:mcast]
      end
    end

    def transport_mode=(value)
      unless [:multicast, :unicast].include? value
        raise CommunicationLayerConfigurationException,
          "Error setting transport mode to #{value}"
      end
      @transport_mode=value
    end

    def configured?
      @rings.all? { |_,v| !v[:address].empty? && !v[:port].empty? }
    end

    def description
      a = []
      a << "&nbsp; Transport mode: #{@transport_mode.to_s}."
      a << "&nbsp; Cluster name: #{@cluster_name}."
      a << "&nbsp; Expected votes: #{@expected_votes}."
      @rings.each do |_, r|
        add = (@transport_mode == :multicast) ? "(mcast #{r[:mcast]})." : "."
        a << "&nbsp; Ring #{r[:id]}: #{r[:address]}:#{r[:port]}#{add}"
      end
      a.join('<br>')
    end
  end
end