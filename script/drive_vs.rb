#!/usr/bin/ruby

require 'vmmgt/driver'

if not ARGV[0].nil? and not ARGV[1].nil? and not ARGV[2].nil?
driver = VmMgt::Driver.plop(ARGV[1], 'vmware')
end

case ARGV[0]
when "adddisk"
  puts driver.add_disk(ARGV[2], ARGV[3],ARGV[4]).inspect
when "changevlan"
  puts "Change to VLAN \"#{ARGV[3]}\" for the server #{ARGV[2]}"
  puts driver.change_vlan(ARGV[2], ARGV[3], ARGV[4]).inspect
when "setcpu"
  puts driver.set_cpu(ARGV[2], ARGV[3]).inspect
when "setram"
  puts driver.set_ram(ARGV[2], ARGV[3]).inspect
when "destroy"
  puts "Destroying #{ARGV[2]}"
  puts driver.destroy_vm(ARGV[2]).inspect
when "create"
  puts "Let's create a new VM !"
  params = {
    :guest_id => "rhel5_64Guest",
    :ram_size => 2048,
    :cpu_count => 2,
    :disks_array => [
      {:size => 20000000},
      {:size => 8000000}
    ]
  }
  puts driver.create_vm(ARGV[2], 'Common', params).inspect
when "start"
  puts "Powering on #{ARGV[2]}"
  puts driver.start_vm(ARGV[2]).inspect
when "stop"
  puts "Powering off #{ARGV[2]}"
  puts driver.stop_vm(ARGV[2]).inspect
when "reset"
  puts "Reseting #{ARGV[2]}"
  puts driver.reset_vm(ARGV[2]).inspect
when "status"
  puts driver.get_power_status(ARGV[2]).inspect
when "deploy"
  params = {
    :domain => "mydomain.home",
    :dns1 => "192.168.0.10",
    :dns2 => "192.168.0.11",
    :product_key => "FXHPB-7TH2W-P8MMH-DHQVT-WJKVM", # Your product key for Windows 2003 Server
    :template_name => "template_Windows_2008_64bits",
    :server_name => ARGV[2],
    :ip_address => "192.168.0.42",
    :gateway => "10.151.2.1",
    :netmask => "255.255.255.0",
    :ram_size => 1024,
    :cpu_count => 2,
  }
  puts driver.deploy_template(ARGV[2], 'Common', params).inspect
else
STDOUT.puts <<-EOF
You can control the virtualization power buddy !

Usage:
./drive_vs.rb create ENV VMNAME
./drive_vs.rb destroy ENV VMNAME
./drive_vs.rb start ENV VMNAME
./drive_vs.rb stop ENV VMNAME
./drive_vs.rb reset ENV VMNAME
./drive_vs.rb setcpu ENV VMNAME CPUCOUNT
./drive_vs.rb setram ENV VMNAME RAMSIZE
./drive_vs.rb changevlan ENV VMNAME VLAN_LABEL CARD_ID
./drive_vs.rb adddisk ENV VMNAME SIZE DATASTORE
./drive_vs.rb status ENV VMNAME
./drive_vs.rb deploy ENV VMNAME
EOF
end
