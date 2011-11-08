#!/usr/bin/ruby
# Author:: Julien Fabre (<ju.pryz AT gmail.com>)
# Date:: Wed Oct 12 10:07:24 +0200 2011
#
# Main class to create a driver
# This class has to be used by clients
#
require 'vmmgt/drivers/driver_vmware.rb'

module VmMgt
  class Driver
    def self.plop(env, hypervisor)
      if hypervisor.eql? 'vmware'
        VmMgt::VMwareDriver.new(env)
      else
        abort 'Unknow driver, try with "vmware"'
      end
    end

  end
end

if __FILE__ == $0
end
