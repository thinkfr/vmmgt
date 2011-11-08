#!/usr/bin/ruby
# Author:: Julien Fabre (<ju.pryz AT gmail.com>)
# Date:: Fri Oct 07 13:56:45 +0200 2011
#
# VSphere driver with rbvmomi library
#
require 'rubygems'
require 'rbvmomi'
require 'vmmgt/environment'

module VmMgt
  class BaseDriver
    attr_accessor :env, :connection
    def initialize(env)
      @env = VmMgt::Environment.new(env)
      @connection = @env.connection unless @env.nil? rescue nil  
      if @connection.nil?
        abort "Configuration file env.yml problem"
      end    
    end

    def check_params(needed, params)
      needed.each do |key, value|
        unless params.include? key
          return false
        end
      end
      true
    end
  end
end
