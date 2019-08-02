#!/bin/bash

cd $(dirname $0)

UNAME=`uname -a | grep -i 'GNU/Linux'`
if [ -z "${UNAME}" ] ; then
	echo "This environment is not Ubuntu/Debian."
	exit -1
else
	OSNAME="Debian"
fi

FLASH_DOWNLOAD_URL=https://github.com/hypriot/flash/releases/download/2.3.0/flash

USER_DATA_PARAMS_SAMPLE="../conf/user-data.params.sample"
USER_DATA_PARAMS="../conf/user-data.params"
USER_DATA_YAML="../conf/user-data.yml"
USER_DATA_YAML_IN="../conf/user-data.yml.in"

HELP_MESSAGE="Usage: flashRDBOX.sh [-s] [-u user-data.params] [-n hostname] -p ssh-pubkey-file -k ssh-key-file <SD image file>"

while getopts "shu:n:p:k:" OPT
do
	case $OPT in
		s) OPT_FLAG_s=1;;
		u) OPT_FLAG_u=1; OPT_VALUE_u=$OPTARG;;
		n) OPT_FLAG_n=1; OPT_VALUE_n=$OPTARG;;
		p) OPT_FLAG_p=1; OPT_VALUE_p=$OPTARG;;
		k) OPT_FLAG_k=1; OPT_VALUE_k=$OPTARG;;
		h) echo ${HELP_MESSAGE}; exit 0;;
		:) echo "[ERROR] Option argument is undefined."; echo ${HELP_MESSAGE}; exit -1;;
		\?) echo "[ERROR] Undefined options."; echo ${HELP_MESSAGE}; exit -1;;
	esac
done

OPT_ERROR_COUNT=0

USER_DATA_PARAMS_COPY=0
if [ -z "${OPT_FLAG_u}" ] ; then
	if [ ! -f ${USER_DATA_PARAMS} ] ; then
		echo "Copy from default parameter file: ${USER_DATA_PARAMS_SAMPLE}..."
		cp -p ${USER_DATA_PARAMS_SAMPLE} ${USER_DATA_PARAMS}
		USER_DATA_PARAMS_COPY=1
	fi
else
	USER_DATA_PARAMS=${OPT_VALUE_u}
fi

if [ ! -f ${USER_DATA_PARAMS} ] ; then
	echo "[ERROR] ${USER_DATA_PARAMS} file not found."
	let OPT_ERROR_COUNT++
fi

if [ -z "${OPT_FLAG_p}" ] ; then
	echo "[ERROR] -p ssh-pubkey-file is not specified."
	let OPT_ERROR_COUNT++
else
	USER_SSH_PUB_FILE=${OPT_VALUE_p}
	if [ ! -f ${USER_SSH_PUB_FILE} ] ; then
		echo "[ERROR] ${USER_SSH_PUB_FILE} file not found."
		let OPT_ERROR_COUNT++
	fi
fi

if [ -z "${OPT_FLAG_k}" ] ; then
	echo "[ERROR] -k ssh-key-file is not specified."
	let OPT_ERROR_COUNT++
else
	USER_SSH_KEY_FILE=${OPT_VALUE_k}
	if [ ! -f ${USER_SSH_KEY_FILE} ] ; then
		echo "[ERROR] ${USER_SSH_KEY_FILE} file not found."
		let OPT_ERROR_COUNT++
	fi
fi

if [ ${OPT_ERROR_COUNT} -gt 0 ] ; then
	echo "failed to flashRDBOX.sh"
	exit -1
fi

#-----------------------------------------------------------------------------------------------------
# Determine hostname.
#-----------------------------------------------------------------------------------------------------
if [ -z "${OPT_FLAG_n}" ] ; then
	HOST_TYPE=""
	while :
	do
		echo "host type:"
		echo "0. other"
		echo "1. master"
		echo "2. slave"
		echo "3. vpnbridge"
		read -p "What number do you select? [0-3] " selected
		case $selected in
			"0") SELECTED_NO=0; echo "[other]"; break;;
			"1") SELECTED_NO=1; HOST_TYPE="master"; echo "[${HOST_TYPE}]"; break;;
			"2") SELECTED_NO=2; HOST_TYPE="slave"; echo "[${HOST_TYPE}]"; break;;
			"3") SELECTED_NO=3; HOST_TYPE="vpnbridge"; echo "[${HOST_TYPE}]"; break;;
			*) echo "The selected number \"${selected}\" is not 0 to 3.";;
		esac
	done

	if [ -z ${HOST_TYPE} ] ; then
		echo
		while :
		do
			read -p "hostname? " TARGET_HOSTNAME
			case $TARGET_HOSTNAME in
				*) if [ ! -z ${TARGET_HOSTNAME} ] ; then break; fi;;
			esac
		done
	else
		echo
		while :
		do
			read -p "prefix? " HOST_PREFIX
			case $HOST_PREFIX in
				*) if [ ! -z ${HOST_PREFIX} ] ; then echo "[${HOST_PREFIX}]"; break; fi;;
			esac
		done
		echo
		echo "  * '00' is a special host name."
		echo "  * '^[0-9a-zA-Z]+$' (ex: room1) is a base master."
		while :
		do
			read -p "suffix? " HOST_SUFFIX
			case $HOST_SUFFIX in
				*) if [ ! -z ${HOST_SUFFIX} ] ; then echo "[${HOST_SUFFIX}]"; break; fi;;
			esac
		done
		TARGET_HOSTNAME=${HOST_PREFIX}-${HOST_TYPE}-${HOST_SUFFIX}
	fi

	echo
	read -p "hostname [${TARGET_HOSTNAME}] is ok? ? (y/N): " yn
	case $yn in
		[yY]*) echo "hostname [${TARGET_HOSTNAME}] selected."; echo;;
		*) echo "hostname [${TARGET_HOSTNAME}] rejected."; echo "failed to flashRDBOX.sh"; exit -1;;
	esac
else
	TARGET_HOSTNAME=${OPT_VALUE_n}
fi

#-----------------------------------------------------------------------------------------------------
# Install sudo/unzip/file/pv/udev/hdparam/curl/uuid-runtime/whois/wpasupplicant and hypriot/flash
#-----------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------
# for Ubuntu/Debian
#-----------------------------------------------------------------------------------------------------
APT_GET_UPDATED=0

function install_one_tool_for_debian() {
	PKG_NAME=$1

	PKG_VER=`dpkg -l | grep ${PKG_NAME} | awk -v pkg_name="${PKG_NAME}" '{ if ($2 == pkg_name) {print $3}}'`
	PKG_STATUS=`dpkg -l | grep ${PKG_NAME} | awk -v pkg_name="${PKG_NAME}" '{ if ($2 == pkg_name) {print $1}}'`
	if [ -z "${PKG_VER}" ] || [ "${PKG_STATUS}" != "ii" ] ; then
		if [ ${APT_GET_UPDATED} -eq 0 ] ; then
			apt-get update
			echo
			APT_GET_UPDATED=1
		fi

		echo "The ${PKG_NAME} package is not installed and so installing it..."
		apt-get -y install ${PKG_NAME}
		echo "done."
		echo
		sleep 1
	fi
}

function install_tools_for_debian() {
	install_one_tool_for_debian "sudo"
	install_one_tool_for_debian "unzip"
	install_one_tool_for_debian "file"
	install_one_tool_for_debian "pv"
	install_one_tool_for_debian "udev"
	install_one_tool_for_debian "hdparm"
	install_one_tool_for_debian "curl"
	install_one_tool_for_debian "uuid-runtime"
	install_one_tool_for_debian "whois"
	install_one_tool_for_debian "wpasupplicant"
}

#-----------------------------------------------------------------------------------------------------
# for Darwin
#-----------------------------------------------------------------------------------------------------
function install_tools_for_darwin() {
	brew install expect
}

if [ ${OSNAME} = "Debian" ] ; then
	# for Ubuntu/Debian
	install_tools_for_debian
else
	# for Darwin
	install_tools_for_darwin
fi

#-----------------------------------------------------------------------------------------------------
# Install hypriot/flash
#-----------------------------------------------------------------------------------------------------

FLASH_CMD_PATH=`which flash`
if [ -z "${FLASH_CMD_PATH}" ] ; then
	echo "hypriot/flash command is not installed and so installing it..."
	curl -o /tmp/flash -LO ${FLASH_DOWNLOAD_URL}
	chown root:root /tmp/flash
	chmod 0755 /tmp/flash
	mv -f /tmp/flash /usr/local/bin/
	echo "done."
	echo
	sleep 1
fi

#-----------------------------------------------------------------------------------------------------

if [ -z "${OPT_FLAG_s}" ] ; then
	if [ ${USER_DATA_PARAMS_COPY} -eq 1 ] ; then
		CREATE_USER_DATA_PARAMS_SKIP=0
	else
		read -p "Do you want to use ${USER_DATA_PARAMS} as it is ? (y/N): " yn
		case $yn in
			[yY]*) CREATE_USER_DATA_PARAMS_SKIP=1;;
			*) CREATE_USER_DATA_PARAMS_SKIP=0;;
		esac
	fi
else
	CREATE_USER_DATA_PARAMS_SKIP=1
fi

if [ ${CREATE_USER_DATA_PARAMS_SKIP} -eq 0 ] ; then
	perl create-user-data-params.pl -i ${USER_DATA_PARAMS} -o ${USER_DATA_PARAMS}
	exit_code=$?
	if [ ${exit_code} -ne 0 ] ; then
		let OPT_ERROR_COUNT++
	fi
else
	echo "Skip creating ${USER_DATA_PARAMS}."
fi

echo
sleep 1

if [ -z "${OPT_FLAG_s}" ] ; then
	perl create-user-data-yaml.pl -i ${USER_DATA_YAML_IN} -p ${USER_DATA_PARAMS} -o ${USER_DATA_YAML}
	exit_code=$?

	if [ ${exit_code} -ne 0 ] ; then
		echo "failed to flashRDBOX.sh"
		exit -1
	fi
else
	echo "Skip creating ${USER_DATA_YAML}."
fi

echo
sleep 1

if [ ! -f ${USER_DATA_YAML} ] ; then
	echo "[ERROR] ${USER_DATA_YAML} file not found."
	let OPT_ERROR_COUNT++
fi

shift $(($OPTIND - 1))

if [ $# -eq 0 ] ; then
	echo "[ERROR] No image file to write to SD card is specified."
	let OPT_ERROR_COUNT++
else
	SD_IMAGE_FILE=$1
fi

if [ ${OPT_ERROR_COUNT} -gt 0 ] ; then
	echo "failed to flashRDBOX.sh"
	exit -1
fi

echo "Start writing to the SD card..."
flash -u ${USER_DATA_YAML} -n ${TARGET_HOSTNAME} ${SD_IMAGE_FILE}
exit_code=$?

if [ ${exit_code} -ne 0 ] ; then
	echo "failed to flashRDBOX.sh"
	exit -1
fi

echo "done."
echo

#-----------------------------------------------------------------------------------------------------
# Set ssh public and private keys
#-----------------------------------------------------------------------------------------------------
SD_DEV_FILE_PART=""

#-----------------------------------------------------------------------------------------------------
# for Ubuntu/Debian
#-----------------------------------------------------------------------------------------------------
function get_sd_device_file_for_debian() {
	SD_DEV_FILES=`dmesg | grep -i 'Attached SCSI removable disk' | sed -e 's/\[//g' | sed -e 's/\]//g' | awk '{print $4}' | sort | uniq | while read LINE ; do FILENAME=/dev/${LINE}1 ; if [ -e $FILENAME ] ; then echo $LINE ; fi ; done`
	SD_DEV_FILES=$(echo $SD_DEV_FILES | sed -e 's/\s*$//')
	if [ -z "${SD_DEV_FILES}" ] ; then
		echo ""
	else
		while :
		do
			SPACE_INC="^.* .*$"
			SD_DEV_FILE=""
			read -p "Please select the writing device from the following device files [${SD_DEV_FILES}]: " selected_dev
			if [ -z "${selected_dev}" ] ; then
				if [[ ! ${SD_DEV_FILES} =~ ${SPACE_INC} ]] ; then
					SD_DEV_FILE=/dev/${SD_DEV_FILES}1
					if [ -e ${SD_DEV_FILE} ] ; then
						read -p "Removable disk device which write ssh public/private keys to is [${SD_DEV_FILES}], ok? (y/N): " yn
						case $yn in
							[yY]*) echo "[${SD_DEV_FILES}] selected."; SD_DEV_FILE_PART=${SD_DEV_FILE}; break;;
							*) echo "[${SD_DEV_FILES}] rejected."; break;;
						esac
					fi
				fi
			else
				if [[ ! ${selected_dev} =~ ${SPACE_INC} ]] ; then
					SD_DEV_FILE=/dev/${selected_dev}1
					if [[ ${SD_DEV_FILES} =~ ${selected_dev} ]] && [ -e ${SD_DEV_FILE} ] ; then
						read -p "Removable disk device which write ssh public/private keys to is [${selected_dev}], ok? (y/N): " yn
						case $yn in
							[yY]*) echo "[${selected_dev}] selected."; SD_DEV_FILE_PART=${SD_DEV_FILE}; break;;
							*) echo "[${selected_dev}] rejected."; break;;
						esac
					fi
				fi
			fi
		done
	fi
}

#-----------------------------------------------------------------------------------------------------
# for Darwin
#-----------------------------------------------------------------------------------------------------
function get_sd_device_file_for_darwin() {
	echo ""
}

echo "setting ssh public and private keys..."

if [ ${OSNAME} = "Debian" ] ; then
	# for Ubuntu/Debian
	get_sd_device_file_for_debian
	if [ -z "${SD_DEV_FILE_PART}" ] ; then
		echo "[ERROR] Removable disk not found."
		let OPT_ERROR_COUNT++
	else
		echo "${SD_DEV_FILE_PART} is selected as the device file of removable disk."
		echo ""
	fi
else
	# for Darwin
	get_sd_device_file_for_darwin
	if [ -z "${SD_DEV_FILE_PART}" ] ; then
		echo "[ERROR] Removable disk not found."
		let OPT_ERROR_COUNT++
	else
		echo "${SD_DEV_FILE_PART} is selected as the device file of removable disk."
		echo ""
	fi
fi

if [ ${OPT_ERROR_COUNT} -gt 0 ] ; then
	echo "failed to flashRDBOX.sh"
	exit -1
fi

TMP_MNT_DIR=/tmp/`uuidgen`
mkdir ${TMP_MNT_DIR}

sudo mount ${SD_DEV_FILE_PART} ${TMP_MNT_DIR}
exit_code=$?

if [ ${exit_code} -ne 0 ] ; then
	echo "failed to flashRDBOX.sh"
	exit -1
fi

sudo cp ${USER_SSH_PUB_FILE} ${TMP_MNT_DIR}/id_rsa.pub
sudo cp ${USER_SSH_KEY_FILE} ${TMP_MNT_DIR}/id_rsa

sudo umount ${TMP_MNT_DIR}
rmdir ${TMP_MNT_DIR}

echo "done."
