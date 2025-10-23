# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "generic/debian12"

  config.vm.provider :libvirt do |libvirt|
    libvirt.memory = 4096
    libvirt.cpus   = 4
  end

  config.vm.provider :vmware_desktop do |vmware|
    vmware.vmx["memsize"] = "4096"
    vmware.vmx["numvcpus"] = "4"
  end
end
