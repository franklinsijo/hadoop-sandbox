#!/bin/bash

# name: install.sh
# author: franklinsijo
# usage: install.sh [--apps=all|{hdfs,yarn,hive,hbase,sqoop,kafka,flume,spark}] [--installdir=/absolute/path] [--datadir=/absolute/path]

EXECUTION_USER=$(whoami)
ANSIBLE_CONNECTION='local'
APPS_LIST='["HDFS","YARN","HIVE","HBASE","SQOOP","KAFKA","FLUME","SPARK"]'
INSTALL_DIR='/usr/local'
DATA_DIR="${HOME}"

ansibleOpts="--connection=${ANSIBLE_CONNECTION}"
ansibleExtraVars=""

for arg in "$@"
do
	case $arg in
		--apps=*)
		APPS="${arg#*=}"
		if [ "$APPS" != "all" ]
		then
			APPS_LIST='['
			for x in ${APPS//,/ }
			do 
				APPS_LIST="${APPS_LIST}\"${x^^}\","
			done
			APPS_LIST="${APPS_LIST/%,/]}"
		fi
		shift
		;;
		--installdir=*)
		INSTALL_DIR="${arg#*=}"
		if [ ! -d "$INSTALL_DIR" ]
		then
			echo -e "Install Directory \033[1m\"${INSTALL_DIR}\"\033[0m does not exist."
			exit 1
		fi
		shift
		;;
		--datadir=*)
		DATA_DIR="${arg#*=}"
		if [ ! -d "$DATA_DIR" ]
		then
			echo -e "Data Directory \033[1m\"${DATA_DIR}\"\033[0m does not exist."
			exit 1
		fi
		shift
		;;	
		*)
		echo -e "Unrecognized argument: \033[1m${arg}\033[0m"
		echo -e "\033[1mUsage:\033[0m install.sh [--apps=all|{hdfs,yarn,hive,hbase,sqoop,kafka,flume,spark}] [--installdir=/absolute/path] [--datadir=/absolute/path]"
		exit 1
		;;
	esac
done

ansibleExtraVars="${ansibleExtraVars}\"components\":${APPS_LIST},\"install_dir\":\"${INSTALL_DIR}\",\"data_dir\":\"${DATA_DIR}\","

echo -e "Performing installation as: \033[1m${EXECUTION_USER}\033[0m"
if [ "$EXECUTION_USER" != 'root' ]
then
	ansibleOpts="${ansibleOpts} --become"
	SUDO_STATUS=$(sudo -kn true 2>&1)  # Checks whether password is required to perform sudo
	if [ $? -ne 0 ]
	then
		echo -n "Enter Password (${EXECUTION_USER}): "
		read -s SUDO_PASSWORD
		if [ ! -z "$SUDO_PASSWORD" ]
		then
			echo -e "\n"
		else
			echo -e "\nPassword cannot be empty. Try Again."
			exit 1
		fi
		ansibleExtraVars="${ansibleExtraVars}\"exec_user\":\"${EXECUTION_USER}\",\"ansible_become_pass\":\"${SUDO_PASSWORD}\","
	fi
fi

OSARCH=$(uname -m)
if [ "$OSARCH" == 'x86_64' ]
then
	ARCH='64bit'
else
	ARCH='32bit'
fi

echo "Checking Python version..."
PYTHON_VERSION=$(python --version 2>&1 | awk '{print $2}')			
if [ $? -ne 0 ]
then
	echo -e "Unable to detect \033[1mPython\033[0m version. Install \033[1mPython\033[0m to proceed."
	exit 1
fi

if [ -f /etc/lsb-release ]
then
	. /etc/lsb-release
	OS=${DISTRIB_DESCRIPTION}
	OSTYPE=${DISTRIB_ID}
	if [ "$OSTYPE" == 'Ubuntu' ]
	then	
		if [ "$APPS_LIST" == "*HIVE*" ]
		then
			echo "Checking MySQL Server..."
			if [ -f /etc/init.d/mysql ]
			then
				MYSQL_STATUS=$(sudo /etc/init.d/mysql status)
				if [ "$MYSQL_STATUS" == 'stopped' ]
				then
					sudo /etc/init.d/mysql start
					MYSQL_STATUS=$(sudo /etc/init.d/mysql status)
					if [ "$MYSQL_STATUS" != 'running' ]
					then
						echo "Unable to start MySQL Server. Aborting Sandbox setup."
						exit 1
					fi
				fi
				echo -e -n "MySQL Username (leave blank if \033[1mroot\033[0m): "
				read -s MYSQL_USERNAME
				if [ -z "$MYSQL_USERNAME" ]
				then
					MYSQL_USERNAME='root'
				fi
				echo -n "MySQL Password for $MYSQL_USERNAME: "
				read -s MYSQL_PASSWORD
			else
				echo "MySQL Server not installed"
				echo -n "Proceed to install (Y/N): "
				read -s FLAG_TO_INSTALL
				if [ "$FLAG_TO_INSTALL" == 'y' || "$FLAG_TO_INSTALL" == 'Y']
				then
					sudo apt-get install mysql-server -y
					sudo /etc/init.d/mysql start
					# add logic to set the root password
					MYSQL_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c10)
				fi				
			fi
		fi
		echo "\nChecking Ansible version..."	
		ANSIBLE_STATUS=$(ansible --version 2>&1)
		if [ $? -ne 0 ]
		then				
			echo "Installing Ansible..."
			sudo apt-add-repository ppa:ansible/ansible -y
			sudo apt-get update
			sudo apt-get install wget -y
			sudo apt-get install ansible -y		
			if [ $? -ne 0 ]
			then
				echo -e "Ansible installation failed. Aborting Sandbox setup."
				exit 1
			fi			
		fi
		ANSIBLE_VERSION=$(ansible --version 2>&1 | awk 'NR == 1{print $2}')
		ANSIBLE_VERSION_MAJOR=$(ansible --version 2>&1 | awk 'NR == 1{print substr($2, 1, 1)}')		
		if [ ! "$ANSIBLE_VERSION_MAJOR" -ge 2 ]
		then
			echo -e "Minimum requirement not met: \033[1mAnsible > 2.0\033[0m"
			exit 1
		fi
	fi
fi
ansibleExtraVars="{${ansibleExtraVars}\"arch\":\"${ARCH}\",\"os\":\"${OSTYPE}\",\"mysqluser\":\"${MYSQL_USERNAME}\",\"mysqlpass\":\"${MYSQL_PASSWORD}\"}"

echo -e "----------------------------------------------------------------------------------------------"
echo -e "Operating System: \033[1m${OS}\033[0m"
echo -e "Architecture: \033[1m${ARCH}\033[0m"
echo -e "Python: \033[1m${PYTHON_VERSION}\033[0m"
echo -e "Ansible: \033[1m${ANSIBLE_VERSION}\033[0m"
echo -e "Components to install: \033[1m${APPS_LIST}\033[0m"
echo -e "----------------------------------------------------------------------------------------------"

ansible-playbook playbook/main.yml -i playbook/hosts ${ansibleOpts} --extra-vars=${ansibleExtraVars}