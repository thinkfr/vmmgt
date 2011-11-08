#!/usr/bin/ruby
# Author:: Julien Fabre (<ju.pryz AT gmail.com>)
# Date:: Fri Oct 07 13:56:45 +0200 2011
#
# VSphere driver with rbvmomi library
#

require 'vmmgt/drivers/prototype_vmware'
require 'vmmgt/drivers/driver_base'
require 'vmmgt/connector'

# External dependencies
require 'rubygems'
require 'rbvmomi'

module VmMgt
  class VMwareDriver < VmMgt::BaseDriver

    attr_accessor :vim, :datacenter
    def initialize(env)
      super(env)
      @vim = VmMgt::VsphereConnection.connect(
        @connection['vcenter'], @connection['user'], @connection['password']
      )
      # FIXME : Add datacenter management
      self.set_datacenter(@env.config["VmwareDatacenter"])
    end

    def set_datacenter(datacenter)
      @datacenter = @vim.serviceInstance.find_datacenter(datacenter) or fail 'Datacenter not found'
    end

    #
    # Instances creation
    #
    def create_vm(vmname, platform, params)
      # Parameters needed by the CreateVM_Task method
      needed_params = [:guest_id, :ram_size, :cpu_count, :disks_array]
      if not check_params(needed_params, params)
        return { "state" => "error", "error" => "Parameters missing to create a VM"}
      end

      vmFolder = @datacenter.vmFolder
      cluster = @env.get_rand_cluster_for_platform(platform)
      rp = self.get_ressourcepool_for_cluster(cluster)
      host = self.get_host_for_cluster(cluster)

      # Set the datastore for each disk and set the default datastore where to create the VM
      params[:disks_array].each do |disk|
        disk[:datastore] = self.get_datastore_for_disk(cluster, disk[:size])
      end
      params[:datastore] = params[:disks_array][0][:datastore]

      # Get a VMware network configuration
      dvswitch_uuid = self.get_dvswitch_uuid
      portgroup_key = self.get_portgroup_key(@env.config["VlanProvi"])

      # Create the VM configuration from Prototype
      vm_cfg = PrototypeVmware.new(
        :name => vmname, :guestid => params[:guest_id],
        :datastore => params[:datastore],
        :dvswitch_uuid => dvswitch_uuid, :portgroup_key => portgroup_key,
        :ramsize => params[:ram_size], :cpucount => params[:cpu_count],
        :disks_list => params[:disks_array]
      )
      vm_cfg.set_network_card(dvswitch_uuid, portgroup_key)

      execute_task(
        vmFolder.CreateVM_Task(:config => vm_cfg.get_configuration, :pool => rp ,:host => host)
      )
    end

    def deploy_template(vmname, platform, params)
      # Parameters needed by the CloneVM_Task method
      needed_params = [:template_name, :domain, :dns1, :dns2, :ou_dest, :dsm_scal, :provi_address,
        :product_key, :ip_address, :gateway, :netmask, :ram_size, :cpu_count, :server_name]
      if not check_params(needed_params, params)
        return { "state" => "error", "error" => "Parameters missing to deploy a template"}
      end

      vmFolder = @datacenter.vmFolder
      cluster = @env.get_rand_cluster_for_platform(platform)

      rp = self.get_ressourcepool_for_cluster(cluster)
      params[:pool] = rp

      template = find_template(params[:template_name])
      unless template.nil?
        tpl_disks_size = 0
        template.config.hardware.device.each do |device|
          tpl_disks_size += device.capacityInKB if device.kind_of? RbVmomi::VIM::VirtualDisk
        end
        params[:datastore] = self.get_datastore(self.get_datastore_for_disk(cluster, tpl_disks_size))
        spec = PrototypeVmware.get_template_spec(params)

        execute_task(
          template.CloneVM_Task(:folder => vmFolder, :name => vmname, :spec => spec)
        )
      end
      
      error = {"state" => "error", "error" => "Template #{params[:template_name]} not found"}
    end

    #
    # Instances modification
    # card_id = 0 - Production card, 1 - Save card
    #
    def change_vlan(vmname, vlan, card_id=0)
      vm = find_vm(vmname)
      # Retrieve device key
      keys = Array.new
      vm.config.hardware.device.each do |device|
        keys.push(device.key) if device.kind_of? RbVmomi::VIM::VirtualVmxnet3
      end
      if keys.count >= card_id.to_i
        # Apply changes
        switch_uuid = self.get_dvswitch_uuid
        portgroup_key = self.get_portgroup_key(vlan)
        execute_task(
          vm.ReconfigVM_Task(
            PrototypeVmware.get_network_card_edit(keys[card_id.to_i], switch_uuid, portgroup_key)
          )
        )
      else
        result = { 'state' => 'error', 'error' => "Card #{card_id} doesn't exist" }
      end
    end

    def add_disk(vmname, size, datastore)
      execute_task(
        find_vm(vmname).ReconfigVM_Task(
          PrototypeVmware.get_disk_cfg(size,datastore)
        )
      )
    end

    def set_cpu(vmname, cpucount)
      execute_task(
        find_vm(vmname).ReconfigVM_Task(
          PrototypeVmware.get_cpu_cfg(cpucount)
        )
      )
    end

    def set_ram(vmname, ramsize)
      execute_task(
        find_vm(vmname).ReconfigVM_Task(
          PrototypeVmware.get_ram_cfg(ramsize)
        )
      )
    end

    #
    # Instances management
    #
    def start_vm(vmname)
      execute_task(
        find_vm(vmname).PowerOnVM_Task(:host => vm.summary.runtime.host)
      )
    end

    def reset_vm(vmname)
      execute_task(
        find_vm(vmname).ResetVM_Task
      )
    end

    def stop_vm(vmname)
      execute_task(
        find_vm(vmname).PowerOffVM_Task
      )
    end

    def destroy_vm(vmname)
      unless (vm = find_vm(vmname)).nil?
        user_file = vm.config[:extraConfig].select { |k| k.key == 'user_iso_file' }.first
        VSphere::FileManager::delete_iso!(vm.send(:datastore).first, user_file.value) if user_file
        execute_task(vm.Destroy_Task)
      end
    end

    #
    # Utils to get informations VMware VM
    #
    def find_vm(vmname)
      @datacenter.find_vm(vmname)
    end

    def find_template(template)
      folder = nil
      @datacenter.vmFolder.children.each do |child|
        if child.kind_of? RbVmomi::VIM::Folder and child.name.eql? 'Template'
          folder = child
          break
        end
      end
      folder.find(template, RbVmomi::VIM::VirtualMachine) rescue nil
    end

    def execute_task(task)
      begin
        task.wait_for_completion
      rescue => exception
        err_message = exception.message
      end
      err_message = task.info.error.localizedMessage unless task.info.error.nil?
      result = { 'state' => task.info.state, 'error' => err_message }
    end

    def get_resourcepool(datacenter)
      hosts = @datacenter.hostFolder.children
    end

    def get_datastore(dsname)
      @datacenter.datastore.each do |datastore|
        return datastore if datastore[:name].eql? dsname
      end
      nil
    end

    def get_power_status(vmname)
      vm = find_vm(vmname)
      unless vm.nil?
        {
          vmname => {
            "status" => find_vm(vmname).summary.runtime[:powerState]
          }
        }
      else
        {
          vmname => {
            "status" => "VM #{vmname} not found !"
          }
        }
      end
    end

    # TODO: Make sure we can provision on all dvs !
    def get_dvswitch_uuid
      netfolder = @datacenter.networkFolder
      netfolder.childEntity.each do |switch|
        if switch.kind_of? RbVmomi::VIM::DistributedVirtualSwitch
          return switch.uuid
        end
      end
      nil
    end

    def get_portgroup_key(vlan)
      netfolder = @datacenter.networkFolder
      netfolder.childEntity.each do |switch|
        if switch.kind_of? RbVmomi::VIM::DistributedVirtualPortgroup and switch.name.eql? vlan
          return switch.key
        end
      end
      nil
    end

    def get_ressourcepool_for_cluster(clustername)
      @datacenter.hostFolder.childEntity.each do |cluster_compute|
        if cluster_compute.name.eql? clustername
          return cluster_compute.resourcePool
        end
      end
      nil
    end

    def get_host_for_cluster(clustername)
      @datacenter.hostFolder.childEntity.each do |cluster_compute|
        if cluster_compute.name.eql? clustername
          return cluster_compute.host[rand(cluster_compute.host.length)]
        end
      end
      nil
    end

    def get_datastore_for_disk(clustername, disksize)
      dsname = nil
      @datacenter.hostFolder.childEntity.each do |cluster_compute|
        if cluster_compute.name.eql? clustername
          cluster_compute.datastore.each do |datastore|
            free_left = datastore.summary[:freeSpace] - disksize
            quarter = datastore.summary[:capacity]/4
            if datastore.name.match(@env.config["Datastores"]) and free_left >= quarter
              return datastore.name
            elsif dsname.nil? and free_left > 0
              dsname = datastore.name
            end
          end
        end
      end
      dsname
    end

  end
end
