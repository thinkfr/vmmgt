#!/usr/bin/ruby
# Author:: Julien Fabre (<ju.pryz AT gmail.com>)
# Date:: Tue Oct 11 15:55:54 +0200 2011
#
# The purporse of this class is to configure the working environment
# Environment example : preproduction, production
#
require 'rubygems'
require 'rbvmomi'
require 'yaml'

module VmMgt

  PATH_CONF_YML = File.dirname(__FILE__) + '/conf/'
  class Environment

    attr_accessor :env, :config, :connection
    def initialize(env)
      @env = env
      self.parse_env
      self.parse_connection
    end

    def parse_env
      begin
        envs = YAML.load_file(PATH_CONF_YML + 'env.yml')
      rescue => e
        fail e.message
      end
      envs.each do |environment|
        if environment['Stage'].eql? @env
          @config = environment
          break
        end
      end
    end

    def parse_connection
      begin
        conf = YAML.load_file(PATH_CONF_YML + 'connection.yml')
      rescue => e
        fail e.message
      end
      conf.each do |key, values|
        if key.eql? @env
          @connection = values
          break
        end
      end
    end

    def get_clusters_for_platform(platform)
      finded_clusters = Array.new
      @config['Clusters'].each do |cluster|
        if cluster['Environment'].include? platform
          finded_clusters.push(cluster['Cluster'])
        end
      end
      finded_clusters
    end

    def get_rand_cluster_for_platform(platform)
      clusters = self.get_clusters_for_platform(platform)
      clusters[rand(clusters.length)]
    end

  end
end