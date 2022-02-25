dnf install epel-release -y
yum groupinstall -y "Server with GUI"
yum install -y xrdp
systemctl enable xrdp --now
firewall-cmd --permanent --add-port=3389/tcp
firewall-cmd --reload
