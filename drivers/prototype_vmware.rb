#!/usr/bin/ruby
# Author:: Julien Fabre (<ju.pryz AT gmail.com>)
# Date:: Fri Oct 07 13:56:45 +0200 2011
#
# VSphere driver with rbvmomi library
#
require 'rubygems'
require 'rbvmomi'

module VmMgt
  class PrototypeVmware

    attr_accessor :cfg, :name, :guestid, :datastore, :network, :ramsize,
    :cpucount, :disks_list, :dvswitch_uuid, :portgroup_key
    def initialize args
      @cfg = Hash.new

      args.each do |k, v|
        instance_variable_set("@#{k}", v) unless v.nil?
      end

      self.set_base_configuration()

      unless @disks_list.empty?
        self.set_disks_hash(@disks_list, @datastore)
      end

    end

    # Return the hash configuration
    def get_configuration
      @cfg
    end

    # Set the base configuration with 1 network card and without disk configuration
    def set_base_configuration
      @cfg = {
        :name => @name,
        :guestId => @guestid,
        :files => { :vmPathName => '['+@datastore+']' },
        :numCPUs => @cpucount,
        :memoryMB => @ramsize,
        :memoryHotAddEnabled => true,
        :tools => RbVmomi::VIM.ToolsConfigInfo(
          :syncTimeWithHost => true
        ),
        :deviceChange => [
          {
            :operation => :add,
            :device => RbVmomi::VIM.VirtualLsiLogicController(
              :key => 1000,
              :busNumber => 0,
              :sharedBus => :noSharing
            )
          }, {
            :operation => :add,
            :device => RbVmomi::VIM.VirtualVmxnet3(
              :key => 0,
              :backing => RbVmomi::VIM.VirtualEthernetCardDistributedVirtualPortBackingInfo(
                :port => RbVmomi::VIM.DistributedVirtualSwitchPortConnection(
                  :switchUuid => @dvswitch_uuid,
                  :portgroupKey => @portgroup_key
                )
              ),
              :addressType => 'generated'
            )
          }
        ],
        :extraConfig => [
          {
            :key => 'bios.bootOrder',
            :value => 'ethernet0'
          }
        ]
      }
    end

    # Return a disks configuration
    # from : disks = [{:name => 'disk 1', :size => 10000000},...]
    def set_disks_hash(disks,datastore)
      i=0
      disks.each do |disk|
        datastore = if disk[:datastore].nil? or disk[:datastore].empty? then datastore else disk[:datastore] end
        @cfg[:deviceChange].push(
        {
          :operation => :add,
          :fileOperation => :create,
          :device => RbVmomi::VIM.VirtualDisk(
            :key => 0+i,
            :backing => RbVmomi::VIM.VirtualDiskFlatVer2BackingInfo(
              :fileName => '['+datastore+']',
              :diskMode => :persistent,
              :thinProvisioned => true
            ),
            :controllerKey => 1000,
            :unitNumber => 0+i,
            :capacityInKB => disk[:size]
          )
        }
        )
        i+=1
      end
    end

    # Create a network card configuration
    # and add it to the base configuration
    # common label : Production, Save
    def set_network_card(switch_uuid, portgroup_key)
      card_cfg = {
        :operation => :add,
        :device => RbVmomi::VIM.VirtualVmxnet3(
          :key => 0,
          :backing => RbVmomi::VIM.VirtualEthernetCardDistributedVirtualPortBackingInfo(
            :port => RbVmomi::VIM.DistributedVirtualSwitchPortConnection(
              :switchUuid => switch_uuid,
              :portgroupKey => portgroup_key
            )
          ),
          :addressType => 'generated'
        )
      }
      @cfg[:deviceChange].push(card_cfg)
    end

    def self.get_network_card_edit(key, switch_uuid, portgroup_key)
      card_cfg = {
        :spec => RbVmomi::VIM.VirtualMachineConfigSpec(
          :deviceChange => [{
              :operation => :edit,
              :device => RbVmomi::VIM.VirtualVmxnet3(
                :key => key,
                :backing => RbVmomi::VIM.VirtualEthernetCardDistributedVirtualPortBackingInfo(
                  :port => RbVmomi::VIM.DistributedVirtualSwitchPortConnection(
                    :switchUuid => switch_uuid,
                    :portgroupKey => portgroup_key
                  )
                )
              )
          }]
        )
      }
    end

    def self.get_disk_cfg(size, datastore)
      disk_cfg = {
        :spec => RbVmomi::VIM.VirtualMachineConfigSpec(
        :deviceChange => [{
            :operation => :add,
            :fileOperation => :create,
            :device => RbVmomi::VIM.VirtualDisk(
              :key => -1,
              :backing => RbVmomi::VIM.VirtualDiskFlatVer2BackingInfo(
                :fileName => '['+datastore+']',
                :diskMode => :persistent,
                :thinProvisioned => true
              ),
              :controllerKey => 1000,
              :unitNumber => -1,
              :capacityInKB => size
            )
          }]
        )
      }
    end

    def self.get_cpu_cfg(cpucount)
      cpu_cfg = {
        :spec => RbVmomi::VIM.VirtualMachineConfigSpec(
          :numCPUs => cpucount
        )
      }
    end

    def self.get_ram_cfg(ramsize)
      ram_cfg = {
        :spec => RbVmomi::VIM.VirtualMachineConfigSpec(
          :memoryMB => ramsize
        )
      }
    end

    def self.get_template_spec(args)
      if not args.kind_of? Hash
        return nil
      end

      nav_runonce = RbVmomi::VIM.CustomizationGuiRunOnce(
        :commandList => ["setx DNSDomain #{args[:domain]} -m",
          "setx OU_Destination #{args[:ou_dest]} -m",
          "setx DSMScal #{args[:dsm_scal]} -m",
          "setx provi_address #{args[:provi_address]} -m",
          "c:\\sources\\starter.bat"
        ]
      )

      nav_guiUnattended = RbVmomi::VIM.CustomizationGuiUnattended(
        :autoLogon => true,
        :autoLogonCount => 2,
        :password => RbVmomi::VIM.CustomizationPassword(
          :plainText => true,
          :value => "decathlon."
        ),
        :timeZone => 105
      )

      # Has to be 'WORKGROUP', it will be changed during the post provisioning
      nav_identification = RbVmomi::VIM.CustomizationIdentification(
        :joinWorkgroup => 'WORKGROUP'
      )

      nav_licenseFilePrintData = RbVmomi::VIM.CustomizationLicenseFilePrintData(
        :autoMode => RbVmomi::VIM.CustomizationLicenseDataMode('perSeat')
      )

      nav_userData = RbVmomi::VIM.CustomizationUserData(
        :fullName => 'IT TEAM',
        :orgName => 'DECATHLON',
        :productId => args[:product_key],
        :computerName => RbVmomi::VIM.CustomizationFixedName(:name => args[:server_name])
      )

      sys_identity = RbVmomi::VIM.CustomizationSysprep(
        :guiRunOnce => nav_runonce,
        :guiUnattended => nav_guiUnattended,
        :identification => nav_identification,
        :licenseFilePrintData => nav_licenseFilePrintData,
        :userData => nav_userData
      )

      prod_ip = RbVmomi::VIM.CustomizationFixedIp(:ipAddress => args[:ip_address])
      backup_ip = RbVmomi::VIM.CustomizationFixedIp(:ipAddress => '127.0.0.1')

      nic0_setting = RbVmomi::VIM.CustomizationAdapterMapping(
        :adapter => RbVmomi::VIM.CustomizationIPSettings(
          :dnsDomain => args[:domain],
          :dnsServerList => [ args[:dns1], args[:dns2] ],
          :gateway => [ args[:gateway] ],
          :ip => prod_ip,
          :subnetMask => args[:netmask]
        )
      )

      nic1_setting = RbVmomi::VIM.CustomizationAdapterMapping(
        :adapter => RbVmomi::VIM.CustomizationIPSettings(
          :dnsDomain => args[:domain],
          :dnsServerList => [ args[:dns1], args[:dns2] ],
          :gateway => [ args[:gateway] ],
          :ip => backup_ip,
          :subnetMask => args[:netmask]
        )
      )

      customization_spec = RbVmomi::VIM.CustomizationSpec(
        :globalIPSettings => RbVmomi::VIM.CustomizationGlobalIPSettings(
          :dnsServerList => [ args[:dns1] , args[:dns2] ],
          :dnsSuffixList => [ args[:domain] ]
        ),
        :identity => sys_identity,
        :nicSettingMap => [ nic0_setting , nic1_setting],
        :options => RbVmomi::VIM.CustomizationWinOptions(:changeSID => true, :deleteAccounts => false)
      )

      vm_config_spec = RbVmomi::VIM.VirtualMachineConfigSpec(
        :annotation => "Virtual Machine created from template",
        :memoryMB => args[:ram_size],
        :numCPUs => args[:cpu_count]
      )

      reloc_spec = RbVmomi::VIM.VirtualMachineRelocateSpec(
        :datastore => args[:datastore],
        :pool => args[:pool]
      )

      clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(
        :powerOn => false,
        :template => false,
        :location => reloc_spec,
        :customization => customization_spec,
        :config => vm_config_spec
      )
    end
  end
end