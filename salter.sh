sudo apt-get update
sudo apt-get -y install salt-minion
sudo rm /etc/salt/minion
sudo touch /etc/salt/minion
echo -e "master: 178.128.206.165" | sudo tee /etc/salt/minion
sudo systemctl restart salt-minion.service
