## Mass deploying Vagrant boxes previsoned with salt.

This is my entry to the "most salt-minions controlled at one time"-challenge presented by [Tero Karvinen](http://terokarvinen.com), as a part of [this course.](http://terokarvinen.com/2018/aikataulu--palvelinten-hallinta-ict4tn022-3004-ti-ja-3002-to--loppukevat-2018-5p)

## Tools and resources

I housed all the VMs in my personal desktop running Xubuntu 18.04 x64, and ran salt-master from my virtual server running Ubuntu 18,04 x64.

Software used:
 - Virtualbox
 - Vagrant
 - Salt

## Creating a test box.

It makes sense to first create a single Vagrant box to try out, before deploying a bunch of them.

```
$ mkdir vagrant
$ cd vagrant
$ vagrant init bento/ubuntu-18.04
$ vagrant up
```
Heres what the default `Vagrantfile` looks like.

```
# -*- mode: ruby -*-

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-18.04"
end
```

## Creating a bunch of boxes at once.

The obvious way to make n number of boxes would be to use a for-loop. 
`Vagrantfile` seems to be written in ruby, and i dont know a single thing about ruby.

Luckily, [this guy](https://manski.net/2016/09/vagrant-multi-machine-tutorial/) has a perfect solution for me to steal.

```
$ cat Vagrantfile

BOX_IMAGE = "bento/ubuntu-18.04"
NODE_COUNT = 2

Vagrant.configure("2") do |config|
  config.vm.define "master" do |subconfig|
    subconfig.vm.box = BOX_IMAGE
  end
  
  (1..NODE_COUNT).each do |i|
    config.vm.define "node#{i}" do |subconfig|
      subconfig.vm.box = BOX_IMAGE
    end
  end
end
```
The file will now deploy NODE_COUNT amount of boxes, in addition to the "master" box. Lets test it out.

```
$ vagrant up
Bringing machine 'master' up with 'virtualbox' provider...
Bringing machine 'node1' up with 'virtualbox' provider...
Bringing machine 'node2' up with 'virtualbox' provider...
...
Master: Machine booted and ready!
node1: Machine booted and ready!
node2: Machine booted and ready!
```

## Provisioning the boxes.

I dont want to ssh into every box to install and configure salt, because i think that would destroy the whole point of this exercise.

Here's where [provisioning](https://www.vagrantup.com/docs/provisioning/) comes in.

I'used a bash-script that [runs upon box-deployment](https://www.vagrantup.com/docs/provisioning/shell.html#external-script) to install and configure salt.

```
$ cat Vagrantfile

# -*- mode: ruby -*-

BOX_IMAGE = "bento/ubuntu-18.04"
NODE_COUNT = 2

Vagrant.configure("2") do |config|
  config.vm.define "master" do |subconfig|
    subconfig.vm.box = BOX_IMAGE
  end
  
  (1..NODE_COUNT).each do |i|
    config.vm.define "node#{i}" do |subconfig|
      subconfig.vm.box = BOX_IMAGE
    end
  end
end

Vagrant.configure("2") do |config|
  config.vm.provision "shell", path: "salter.sh"
end
```
```
$cat salter.sh

sudo apt-get update
sudo apt-get -y install salt-minion
sudo rm /etc/salt/minion
sudo touch /etc/salt/minion
echo -e "master: 178.128.206.165" | sudo tee /etc/salt/minion
sudo systemctl restart salt-minion.service

```
`Vagrantfile` now knows to look into `salter.sh` and run the content in the boxes after deployment.

```
$ vagrant ssh node2
$ cd /etc/salt/
$ cat minion
master: 178.128.206.165
```
I assumed that vagrant boxes would inherit the name from `config.vm.define "name"`, but they all came out as "vagrant.vm".

```
master$ sudo salt-key -L

Accepted Keys:
Winion
pheebzer
vagrant.vm

Denied Keys:
vagrant.vm

Unaccepted Keys:
Rejected Keys:
```
[Reading the documentation](https://www.vagrantup.com/docs/vagrantfile/machine_settings.html) reveals that you can (unsuprisingly) change the hostname:

```
# -*- mode: ruby -*-

BOX_IMAGE = "bento/ubuntu-18.04"
NODE_COUNT = 2

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

  config.vm.provision "shell", path: "salter.sh"
end
```
Master should now have 3 different, viable keys waiting to be accepted:
```
master$ sudo salt-key -A

The following keys are going to be accepted:
Unaccepted Keys:
master
node1
node2
Proceed? [n/Y] Y
Key for minion master accepted.
Key for minion node1 accepted.
Key for minion node2 accepted.

master$ sudo salt "*" test.ping

master:
    True
node2:
    True
node1:
    True

```


## How many boxes can my computer handle?

[Recommended amount of RAM for ubuntu without GUI](https://help.ubuntu.com/lts/installation-guide/powerpc/ch03s04.html) seems to be 512MB. So i set the RAM-cap of the boxes to 512MB, and bumped the NODE_COUNT to 25:

```
config.vm.provider "virtualbox" do |v|
  v.memory = 512
end
```

I got to 24th node before my system froze up. I decided to take a different approach: because the **minimum** RAM needed to run ubuntu without a GUI is 128MB, i decided to try capping the RAM usage there. After 20 minutes of waiting, not a single machine had managed to boot up. I then slowly increased the cap, until the boot-up times became bearable. 

4 boxes delpoyed succesfully in a reasonable time with 250MB.
```
$ sudo salt "*" test.ping
node2:
    True
master:
    True
node1:
    True
node3:
    True
```

25 boxes with 250MB ram booted and controlled with salt:

![](http://blog.petrusmanner.com/wp-content/uploads/2018/12/Selection_001.png)

## Final push

Since we still have a fair amount RAM left to utilize, i decided to try 35 boxes:

![](http://blog.petrusmanner.com/wp-content/uploads/2018/12/Selection_003.png)

The image clips a few of the minions, but all 35 nodes + master box are up, running, and controlled by salt. I then made a quick salt-module that copies a `hello.txt` file to every minion's `/tmp` folder...
```
/tmp/hello.txt
  file.managed:
    - source: salt://vagrant/hello.txt
```

...And to futher illustrate the functionality of my minions, i created a for-loop to make every box `cat` their hostname and the aforementioned `hello.txt`:

```
#!bin/bash

counter=1
num=1

while [ $counter -le 35 ]
do
         vagrant ssh node$num -c "hostname; cat /tmp/hello.txt"
	((counter++))
	((num++))
done

echo "Script done."
```
![](http://blog.petrusmanner.com/wp-content/uploads/2018/12/Selection_008.png)

## Conclusions and thoughts

So there we go, **36 minions** controlled at the same, all housed on a single pc. 

Overall this project was a lot of fun, and gave me some new insights on vagrant, salt and even bash-scripting. 
I'm not sure if the provisioning tactic i used was any the optimal way to go, since each box took a rather long time to deploy. Using type-1 virtualization would probably have yielded better results, but that is a project for another day.

#### Sources
- http://terokarvinen.com/2018/aikataulu--palvelinten-hallinta-ict4tn022-3004-ti-ja-30$
- https://manski.net/2016/09/vagrant-multi-machine-tutorial/
- https://www.vagrantup.com/docs/provisioning/
- https://www.vagrantup.com/docs/provisioning/shell.html#external-script
- https://www.vagrantup.com/docs/vagrantfile/machine_settings.html
- https://help.ubuntu.com/lts/installation-guide/powerpc/ch03s04.html
