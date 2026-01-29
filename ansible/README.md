Installing Ansible on Ubuntu is straightforward using the official PPA for the latest stable version. The process takes about 5 minutes and works on Ubuntu 20.04, 22.04, 24.04, and newer. [docs.ansible](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html)

## Prerequisites
Update your package index and install required tools:
```
sudo apt update && sudo apt upgrade -y
sudo apt install software-properties-common -y
```

## Method 1: Official PPA (Recommended)
This provides the latest stable Ansible version:
```
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt update
sudo apt install ansible -y
```
Verify installation:
```
ansible --version
```
Expected output: `ansible [core 2.16.x]` or newer. [cyberpanel](https://cyberpanel.net/blog/install-ansible-on-ubuntu)

## Method 2: Python pip (Latest Development)
For cutting-edge features or isolated environments:
```
sudo apt install python3-pip python3-venv -y
python3 -m venv ~/ansible-env
source ~/ansible-env/bin/activate
pip install --upgrade pip
pip install ansible
```
Deactivate when done: `deactivate`. [cherryservers](https://www.cherryservers.com/blog/install-ansible-ubuntu-24-04)

## Method 3: Snap (Isolated)
```
sudo snap install ansible
```
Note: Snap versions may lag behind PPA releases. [docs.ansible](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html)

## Post-Installation Setup
1. **Create inventory file** (`inventory.ini`):
```
[local]
localhost ansible_connection=local
```
2. **Test connection**:
```
ansible -i inventory.ini all -m ping
```
3. **Configure** (optional) - Edit `/etc/ansible/ansible.cfg` for defaults.

## Perfect for Your AWS Ubuntu + Folder Comparison Workflow
Now you can run the folder comparison playbook from our previous conversation:
```
ansible-playbook compare_folders.yml
```

## Quick Uninstall (if needed)
```
sudo apt remove ansible ansible-base -y
sudo apt autoremove -y
sudo add-apt-repository --remove ppa:ansible/ansible
```

**PPA method is best** for production use on Ubuntu servers like your AWS EC2 instance—it stays updated with `sudo apt upgrade`. [cyberpanel](https://cyberpanel.net/blog/install-ansible-on-ubuntu)
