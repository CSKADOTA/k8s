# Debian 11.4.0
# For all servers, include work nodes and control plane:
su
Enter you root password
apt install sudo vim
vim /etc/sudoers
# Add your admin username into sudoers list
exit
# Disable swap, swapoff then edit your fstab removing any entry for swap partitions

sudo swapoff -a
sudo vim /etc/fstab
comment out sw partitions
or:
sudo -i sed '/swap \{1,\}sw/,d' /etc/fstab



#0 - Install Packages 

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF



cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF



sudo sysctl --system


# Install containerd
sudo apt-get update 
sudo apt-get install -y containerd


# Create a containerd configuration file
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

sudo vim /etc/containerd/config.toml
#Set the cgroup driver for containerd to systemd which is required for the kubelet.


#At the end of this section
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        ...

            SystemdCgroup = true

#You can use sed to swap in true
sudo sed -i  '/\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\]/a\            SystemdCgroup = true' /etc/containerd/config.toml


#Verify the change was made
sudo vim /etc/containerd/config.toml

#Restart containerd with the new configuration
sudo systemctl restart containerd




#Install Kubernetes packages - kubeadm, kubelet and kubectl
#Add Google's apt repository gpg key
sudo apt install gnupg2 -y
sudo apt install curl -y
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -


#Add the Kubernetes apt repository
sudo bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'


#Update the package list and use apt-cache policy to inspect versions available in the repository
sudo apt-get update



sudo apt-get install kubelet kubeadm kubectl -y
# sudo apt-mark hold kubelet kubeadm kubectl containerd if you don't want to auto upgrade k8s versions


#1 - systemd Units
#Check the status of our kubelet and our container runtime, containerd.
#The kubelet will enter a crashloop until a cluster is created or the node is joined to an existing cluster.
sudo systemctl status kubelet.service 
sudo systemctl status containerd.service 


#Ensure both are set to start when the system starts up.
sudo systemctl enable kubelet.service
sudo systemctl enable containerd.service
# For control plane:
wget https://docs.projectcalico.org/manifests/calico.yaml


#Look inside calico.yaml and find the setting for Pod Network IP address range CALICO_IPV4POOL_CIDR, 
#adjust if needed for your infrastructure to ensure that the Pod network IP
#range doesn't overlap with other networks in our infrastructure.
vim calico.yaml

sudo kubeadm init

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


#1 - Creating a Pod Network
#Deploy yaml file for your pod network.
kubectl apply -f calico.yaml


#Look for the all the system pods and calico pods to change to Running. 
#The DNS pod won't start (pending) until the Pod network is deployed and Running.
kubectl get pods --all-namespaces


#Gives you output over time, rather than repainting the screen on each iteration.
kubectl get pods --all-namespaces --watch


#All system pods should be Running
kubectl get pods --all-namespaces


#Get a list of our current nodes, just the Control Plane Node/Master Node...should be Ready.
kubectl get nodes 

kubeadm token create --print-join-command

# Copy the command printed above, then excute the command on work nodes.
# For work nodes:
sudo kubeadm join <Information you copied from above>
