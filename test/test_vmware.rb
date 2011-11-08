#!/usr/bin/ruby

require 'vmmgt/driver'
require 'test/unit'



class TestVmmgt < Test::Unit::TestCase
  def setup
    @driver = VmMgt::Driver.plop('lab', 'vmware')
    @vm_name = 'TESTAUTO'
  end

  def test_1_connection
    puts "Test the connection"
    assert_kind_of(VmMgt::VMwareDriver, @driver)
  end

  def test_2_create
    puts "Creation of a simple RHEL VM : #{@vm_name}"
    params = {
      :guest_id => "rhel5_64Guest",
      :ram_size => 2048,
      :cpu_count => 2,
      :disks_array => [
        {:size => 20000000},
        {:size => 8000000}
      ]
    }
    r_create = @driver.create_vm(@vm_name,'Common', params)
    assert_equal('success', r_create['state'])
  end

  def test_3_start
    puts "Start the VM #{@vm_name}"
    r_start= @driver.start_vm(@vm_name)
    assert_equal('success', r_start['state'])
  end

  def test_4_reset
    puts "Reset the VM #{@vm_name}"
    r_reset = @driver.reset_vm(@vm_name)
    assert_equal('success', r_reset['state'], "The VM has to be Powered ON to be reset")
  end

  def test_5_stop
    puts "Shutdown the VM #{@vm_name}"
    r_stop = @driver.stop_vm(@vm_name)
    assert_equal('success', r_stop['state'])
  end

  def test_6_destroy
    puts "Destroy the VM #{@vm_name}"
    r_destroy = @driver.destroy_vm(@vm_name)
    assert_equal('success', r_destroy["state"])
  end

  def test_7_create_and_edit
    puts "Create, customize and destroy the VM #{@vm_name}"
    params = {
      :guest_id => "rhel5_64Guest",
      :ram_size => 2048,
      :cpu_count => 2,
      :disks_array => [
        {:size => 20000000},
        {:size => 8000000}
      ]
    }
    r = @driver.create_vm(@vm_name, 'Common', params)
    assert_equal('success', r['state'])

    puts "> Change CPU count"
    r = @driver.set_cpu(@vm_name, 4)
    assert_equal('success', r['state'])

    puts "> Change RAM size"
    r = @driver.set_ram(@vm_name, 2048)
    assert_equal('success', r['state'])

    puts "> Start the VM"
    r = @driver.start_vm(@vm_name)
    assert_equal('success', r['state'])

    puts "> Stop the VM"
    #TODO: Check 4 CPUS and 2048 RAM
    r = @driver.stop_vm(@vm_name)
    assert_equal('success', r['state'])

    puts "> Destroy the VM"
    r = @driver.destroy_vm(@vm_name)
    assert_equal('success', r["state"])
  end
end
