#!/usr/bin/ruby
# Author:: Julien Fabre (<ju.pryz AT gmail.com>)
# Date:: Tue Oct 11 16:44:47 +0200 2011
#
# Connectors for hypervisers
#
require 'rubygems'
require 'rbvmomi'

module VmMgt
  class VsphereConnection
    def self.connect(vcenter, user, pwd)
      opt = {:host => vcenter, :user => user, :password => pwd, :insecure => true}
      begin
        RbVmomi::VIM.connect opt
      rescue => exception
        puts exception.message
        exit
      end
    end
  end

end
