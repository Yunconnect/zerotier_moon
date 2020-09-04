#!/bin/bash

function blue(){
  echo -e "\033[34m\033[01m$1\033[0m"
}
function green(){
  echo -e "\033[32m\033[01m$1\033[0m"
}
function red(){
  echo -e "\033[31m\033[01m$1\033[0m"
}
function version_lt(){
  test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1";
}

#copy from ��ˮ�ݱ� ss scripts
if [[ -f /etc/redhat-release ]]; then
  release_os="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
  release_os="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
  release_os="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
  release_os="centos"
elif cat /proc/version | grep -Eqi "debian"; then
  release_os="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
  release_os="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
  release_os="centos"
fi

if [ "$release_os" == "centos" ]; then
  systemPackage_os="yum"
elif [ "$release_os" == "ubuntu" ]; then
  systemPackage_os="apt"
elif [ "$release_os" == "debian" ]; then
  systemPackage_os="apt"
fi

#�޸�SSH�˿ں�
function change_ssh_port(){
  cd
  declare -i port_num
  read -p "�������¶˿ں�(1024-65535):" port_num
  if [[ $port_num -ge 1024 && $port_num -le 65535 ]]; then
    green " ����˿ں���ȷ���������øö˿ں�"
  else
    red "����Ķ˿ںŴ�������������"
    unset port_num
    change_ssh_port
  fi
  grep -q "Port $port_num" /etc/ssh/sshd_config
  if [ $? -eq 0 ]; then
    red " �˿��Ѿ���ӣ������ظ����"
    return
  else
    sed -i "/Port 22/a\Port $port_num" /etc/ssh/sshd_config
    sed -i '/Port 22/s/^#//' /etc/ssh/sshd_config
    if [ "$release_os" == "centos" ]; then
      firewall-cmd --zone=public --add-port=$port_num/tcp --permanent
      firewall-cmd --reload
    elif [ "$release_os" == "ubuntu" ]; then
      ufw allow $port_num
      ufw reload
    fi
    #ĿǰSELinux ֧������ģʽ���ֱ���enforcing��ǿ��ģʽ��permissive������ģʽ��disabled���ر�
    if [ -f "/etc/selinux/config" ]; then
      CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
      if [ "$CHECK" != "SELINUX=disabled" ]; then
        read -p "��⵽SELinux����״̬���Ƿ��������SElinux ?������ [Y/n] :" yn
        [ -z "${yn}" ] && yn="y"
        if [[ $yn == [Yy] ]]; then
          green "��ӷ���$port_num�˿ڹ���"
          $systemPackage_os -y install policycoreutils-python
          semanage port -a -t ssh_port_t -p tcp $port_num
        else
          if [ "$CHECK" == "SELINUX=enforcing" ]; then
            sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
          elif [ "$CHECK" == "SELINUX=permissive" ]; then
            sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
          fi
          red "======================================================================="
          red "�ر�selinux�󣬱�������VPS������Ч����ִ�б��ű���������3�������......"
          red "======================================================================="
          clear
          green "��������ʱ3s"
          sleep 1s
          clear
          green "��������ʱ2s"
          sleep 1s
          clear
          green "��������ʱ1s"
          sleep 1s
          clear
          green "������..."
          reboot
        fi
      fi
    fi
    systemctl restart sshd.service
    sleep 1s
    red " �Ժ���ʹ���޸ĺõĶ˿�����SSH"
  fi
}

#�ر�SSHĬ��22�˿�
function close_ssh_default_port(){
  cd
  grep -q "#Port 22" /etc/ssh/sshd_config
  if [ $? -eq 0 ]; then
    red " �˿�22�ѱ��رգ������ظ�����"
  else
    sed -i 's/Port 22/#Port 22/g' /etc/ssh/sshd_config
    if [ "$release_os" == "centos" ]; then
      firewall-cmd --reload
    elif [ "$release_os" == "ubuntu" ]; then
      ufw reload
    fi
    systemctl restart sshd.service
    green " �¶˿����ӳɹ�������ԭ22�˿ڳɹ�"
  fi
}

#����moon�ڵ�
function creat_moon(){
  blue "��װzerotier���"
  curl -s https://install.zerotier.com/ | sudo bash
  blue "����zerotier"
  systemctl start zerotier-one.service
  systemctl enable zerotier-one.service
  blue "����װ��ZeroTier�ļ���������ע��õ�ZeroTier�����������"
  read -p "���������ZeroTier���������ID�ţ�" you_net_ID
  zerotier-cli join $you_net_ID | grep OK
  if [ $? -eq 0 ]; then
    green "��������ɹ�����ȥȥzerotier����ҳ�棬�Լ�����豸���д�"
    read -s -n1 -p "ȷ��zerotier����ҳ������moon�ڵ�����������... "
    blue "�ZeroTier��Moon��ת������������moon�����ļ�"
    cd /var/lib/zerotier-one/
    blue "����moon.json�ļ���������б༭"
    zerotier-idtool initmoon identity.public > moon.json
    sleep 2s
    vi moon.json
    green "�༭���"
    blue "����ǩ���ļ�"
    zerotier-idtool genmoon moon.json
    blue "����moons.d�ļ��У�����ǩ���ļ��ƶ����ļ�����"
    mkdir moons.d
    mv ./*.moon ./moons.d/
    blue "zerotier-one����"
    systemctl restart zerotier-one
    green "moon�ڵ㴴�����"
    green "��ǵý�moons.d�ļ��п����������ڿͻ��˵����ã�·��/var/lib/zerotier-one/"
  else
    red "����ʧ�ܣ������������ID�����޴���"
  fi
}

#���üƻ�����
function crontab_edit(){
  cd
  cat /etc/crontab
  read -p "�밴�����ϸ�ʽ����ƻ�����" crontab_cmd
  rm -f /etc/crontab
  sleep 1s
  cat > /etc/crontab <<-EOF
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root

# For details see man 4 crontabs

# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name  command to be executed

$crontab_cmd

EOF
  chmod +x /etc/crontab
  systemctl enable crond.service
  systemctl start crond.service
  crontab /etc/crontab
  systemctl reload crond.service
  systemctl status crond.service
  blue "�༭��ļƻ�����"
  echo
  crontab -l
}

#�������
function del_cache(){
  cd
  green " ������������"
  rm -f "$0"
}

#һ��ȫ�Զ���װ
function auto_install(){
  read -p "�Ƿ�ر�SSHĬ��22�˿� ?������ [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    close_ssh_default_port
    sleep 1s
  fi
  read -p "�Ƿ񴴽�moon ?������ [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    creat_moon
    sleep 1s
  fi
  read -p "�Ƿ����üƻ����� ?������ [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo
    crontab_edit
    sleep 1s
  fi
  read -p "�Ƿ�������� ?������ [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    del_cache
  fi
}

#��ʼ�˵�
start_menu(){
  clear
  green " ======================================="
  green " ���ܣ�"
  green " һ��zerotier���������moon�ڵ��ۺϽű�"
  green " һ�����üƻ������޸�SSH�˿�"
  green " ======================================="
  echo
  green " 1. �޸�SSH�˿ں�"
  green " 2. �ر�SSHĬ��22�˿�"
  green " 3. ����moon�ڵ㰲װ�ű�"
  green " 4. ���üƻ�����"
  green " 5. �������"
  green " 6. ȫ�Զ�ִ��2-5"
  blue " 0. �˳��ű�"
  echo
  read -p "����������:" num
  case "$num" in
  1)
  change_ssh_port
  exit
  ;;
  2)
  close_ssh_default_port
  sleep 1s
  read -s -n1 -p "����������ز˵� ... "
  start_menu
  ;;
  3)
  creat_moon
  sleep 1s
  read -s -n1 -p "������������ϼ��˵� ... "
  start_menu
  ;;
  4)
  crontab_edit
  sleep 1s
  read -s -n1 -p "����������ز˵� ... "
  start_menu
  ;;
  5)
  del_cache
  ;;
  6)
  auto_install
  ;;
  0)
  exit 1
  ;;
  *)
  clear
  red "��������ȷ����"
  sleep 1s
  start_menu
  ;;
  esac
}

start_menu
