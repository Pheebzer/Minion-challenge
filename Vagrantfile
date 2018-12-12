# -*- mode: ruby -*-

BOX_IMAGE = "bento/ubuntu-18.04"
NODE_COUNT = 35

Vagrant.configure("2") do |config|
  config.vm.define "master" do |subconfig|
    subconfig.vm.box = BOX_IMAGE
    subconfig.vm.hostname = "master"
  end
  
  (1..NODE_COUNT).each do |i|
    config.vm.define "node#{i}" do |subconfig|
      subconfig.vm.box = BOX_IMAGE
      subconfig.vm.hostname = "node#{i}"
    end
  end

  config.vm.provider "virtualbox" do |v|
    v.memory = 250
  end

  config.vm.provision "shell", path: "salter.sh"
end
