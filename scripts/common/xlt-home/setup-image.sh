#!/bin/bash
set -e

## Script parameters ##

XLT_SOURCE="$1"
export ARCH="${2:-amd64}"
ENABLE_ROOT_LOGIN="$3"

function err() {
  printf >&2 "\nERROR: $1\n\n"
  exit 1
}
# Check if script is run as root user
if ! test `id -u` -eq 0 ; then
  echo "This script must be run as root"
  exit 1
fi

if [ -z "$XLT_SOURCE" ]; then
  echo "Setup script must be invoked with XLT-Version or path to XLT distribution archive as 1st argument"
  exit 1
fi

if [ "$ARCH" != "amd64" -a "$ARCH" != "arm64" ]; then
  echo "Unsupported architecture: \"$ARCH\""
  exit 1
fi

echo "Building image for architecture \"$ARCH\" ..."


## first the variables
export SCRIPT_DIR=`realpath -m $0/..`
export INIT_SCRIPT_DIR="$(dirname $SCRIPT_DIR)/init.d"

XLT_USER="xlt"
XLT_HOME="/home/$XLT_USER"
XLT_WORKDIR="/mnt/$XLT_USER"
TARGET_ARCHIVE="$XLT_HOME/xlt.zip"
XLT_CHECKSUM_FILE="${TARGET_ARCHIVE}.sha"

IPv6_SCRIPT_NAME="ipv6tunnel"
MOUNT_SCRIPT_NAME="mountdev"
USERDATA_START_SCRIPT_NAME="userdata"
XLT_SERVICE_CONFIG="xlt.service"
XLT_INITD_SCRIPT_NAME="xlt"
XLT_START_SCRIPT_NAME="start-xlt.sh"
NTP_START_SCRIPT="ntptime"

GECKODRIVER_VERSION="v0.36.0"
if [ "$ARCH" == "arm64" ]; then
  GECKODRIVER_DOWNLOAD_URL="https://github.com/mozilla/geckodriver/releases/download/${GECKODRIVER_VERSION}/geckodriver-${GECKODRIVER_VERSION}-linux-aarch64.tar.gz"
  GECKODRIVER_SHA512="3902a6f4b2d0645ebf28e6b3dcee5ab40f6a6e3b50908d25167b6ba1c5ea008c2d60199a58900ce9843f6522fc0712b54ee7b5275f475eb223601e3528067f01"
else
  GECKODRIVER_DOWNLOAD_URL="https://github.com/mozilla/geckodriver/releases/download/${GECKODRIVER_VERSION}/geckodriver-${GECKODRIVER_VERSION}-linux64.tar.gz"
  GECKODRIVER_SHA512="16cb5ab065242023517e2dc0318cc0841af4745e5676fbfdd6ee9adf45978957b4e68a6c1afb48b8dcf6a79e5bc35226c6e4c1f99c752b4f845533204081b6ee"
fi

## check referenced files existance
function checkFile {
  local FILE="$SCRIPT_DIR/$1"
  if [ ! -e $FILE ]; then
    echo "Can not find $FILE"
    exit 1
  fi
}

function checkInitFile {
  local FILE="$INIT_SCRIPT_DIR/$1"
  if [ ! -e $FILE ]; then
    echo "Cannot find $FILE"
    exit 1
  fi
}

function runAsXltUser() {
  sudo -HEu $XLT_USER $*
}

checkFile $XLT_START_SCRIPT_NAME;

checkInitFile $USERDATA_START_SCRIPT_NAME
checkInitFile $XLT_INITD_SCRIPT_NAME
checkInitFile $NTP_START_SCRIPT
checkInitFile $XLT_SERVICE_CONFIG

## create XLT user
echo "Create XLT user"
adduser --disabled-login --disabled-password --gecos "" $XLT_USER

## update system
echo "Update system"
# update available packages
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

# install required packages
echo "Install additional packages"
DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install \
  curl \
  unzip \
  tar \
  xvfb \
  dos2unix \
  software-properties-common \
  ipv6calc \
  firefox-esr \
  chromium \
  chromium-driver \
  libgconf-2-4 \
  dbus-x11 \
  jq \
  psmisc \
  gpg

## Install JDK 21 from Adoptium repository (s. https://adoptium.net/installation/linux/)
# install the Adoptium GPG key
curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null || err "Failed to install public key of Adoptum Repository"
# configure the Adoptium repository
echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/ { print $2 }' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list > /dev/null
# install JDK 21
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install temurin-21-jdk \
  || err "Failed to install Java 21 JDK"

# Download Geckodriver from GitHub and put it into path
echo "Install geckodriver"
curl -fsSL $GECKODRIVER_DOWNLOAD_URL -o /tmp/geckodriver-linux64.tgz \
  && echo "$GECKODRIVER_SHA512 /tmp/geckodriver-linux64.tgz" | sha512sum -c - \
  && tar -xz -C /usr/bin -f /tmp/geckodriver-linux64.tgz \
  && chown root:root /usr/bin/geckodriver \
  && chmod 755 /usr/bin/geckodriver \
  && rm /tmp/geckodriver-linux64.tgz \
  || err "Failed to download and install GeckoDriver binary"

# Setup XLT start script
echo "Install XLT start script"
cp $SCRIPT_DIR/$XLT_START_SCRIPT_NAME $XLT_HOME
chmod 755 $XLT_HOME/$XLT_START_SCRIPT_NAME
chown xlt:xlt $XLT_HOME/$XLT_START_SCRIPT_NAME

# Setup NTP script
echo "Install NTP script"
cp $INIT_SCRIPT_DIR/$NTP_START_SCRIPT /etc/init.d/
chmod 755 /etc/init.d/$NTP_START_SCRIPT
update-rc.d $NTP_START_SCRIPT start 19 2 3 4 5 .

# Setup user data script
echo "Install UserData script"
cp $INIT_SCRIPT_DIR/$USERDATA_START_SCRIPT_NAME /etc/init.d/
chmod 755 /etc/init.d/$USERDATA_START_SCRIPT_NAME
update-rc.d $USERDATA_START_SCRIPT_NAME remove

# Setup XLT init scripts
echo "Install initial XLT start script"
update-rc.d $XLT_INITD_SCRIPT_NAME remove
cp $INIT_SCRIPT_DIR/$XLT_INITD_SCRIPT_NAME /etc/init.d/
chmod 755 /etc/init.d/$XLT_INITD_SCRIPT_NAME

if [ -d /etc/systemd ]; then
  # Remove "old" userdata.service - we have XLT service now!
  if [ -f /etc/systemd/system/userdata.service ]; then
    systemctl disable userdata.service
    rm /etc/systemd/system/userdata.service
  fi

  cp $INIT_SCRIPT_DIR/$XLT_SERVICE_CONFIG /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable $XLT_SERVICE_CONFIG

else
  update-rc.d $XLT_INITD_SCRIPT_NAME defaults
fi

# Setup IPv6 script
if [ -e $INIT_SCRIPT_DIR/$IPv6_SCRIPT_NAME ]; then
  echo "Install IPv6 script"
  cp $INIT_SCRIPT_DIR/$IPv6_SCRIPT_NAME /etc/init.d/
  chmod 755 /etc/init.d/$IPv6_SCRIPT_NAME
  update-rc.d $IPv6_SCRIPT_NAME defaults
fi


## tune system limits
echo "Tune system limits"
if ! grep '^\s*\*\s*soft\s*nofile' /etc/security/limits.conf; then
  echo '*       soft    nofile  128000' >> /etc/security/limits.conf
fi
if ! grep '^\s*\*\s*hard\s*nofile' /etc/security/limits.conf; then
  echo '*       hard    nofile  128000' >> /etc/security/limits.conf
fi
if ! grep '^\s*\*\s*soft\s*nproc' /etc/security/limits.conf; then
  echo '*       soft    nproc  16000' >> /etc/security/limits.conf
  fi
if ! grep '^\s*\*\s*hard\s*nproc' /etc/security/limits.conf; then
  echo '*       hard    nproc  16000' >> /etc/security/limits.conf
fi

## tune kernel settings
if [ -d /etc/sysctl.d ]; then
  echo "Tune kernel"
  cat <<-EOF > /etc/sysctl.d/99-xlt.conf
# Enable reuse of ipv4 sockets that are in waiting state
net.ipv4.tcp_tw_reuse=1
# Widen local port range
net.ipv4.ip_local_port_range=1024 65000
EOF

fi

## secure login
echo "Secure login"
if [ "$ENABLE_ROOT_LOGIN" = "enableRootLogin" ]
then
  echo "Enable root login"
  sed -ri 's/^\s*PermitRootLogin\s*no$/PermitRootLogin\ yes/g' /etc/ssh/sshd_config
else
  echo "Disable root login"
  sed -ri 's/^\s*PermitRootLogin\s*yes$/PermitRootLogin\ no/g' /etc/ssh/sshd_config
fi

# install XLT
echo "Installing XLT"

if [ ! -f $XLT_SOURCE ]; then
  XLT_SOURCE="https://oss.sonatype.org/service/local/artifact/maven/redirect?r=releases&g=com.xceptance&a=xlt&e=zip&v=$XLT_SOURCE"
fi

if [[ $XLT_SOURCE == http://* ]] || [[ $XLT_SOURCE == https://* ]]; then
  # load from URL
  echo "download ..."
  curl -fsSL "$XLT_SOURCE" -o "$TARGET_ARCHIVE" || err "Failed to download XLT distribution archive"
  curl -fsSL $(echo $XLT_SOURCE | sed -e 's/e=zip/e=zip.sha1/' -) -o "$XLT_CHECKSUM_FILE" || err "Failed to retrieve SHA1 checksum of XLT distribution archive"
  echo "`cat $XLT_CHECKSUM_FILE` $TARGET_ARCHIVE" | sha1sum -c - && rm -f "$XLT_CHECKSUM_FILE" || err "Checksum mismatch"
else
  # is not a URL -> must be a file
  if [ -r "$XLT_SOURCE" ] && [ -f "$XLT_SOURCE" ]; then
    # get from file
    mv "$XLT_SOURCE" "$TARGET_ARCHIVE"
  fi
fi

if [ ! -f "$TARGET_ARCHIVE" ]; then
  echo "Given parameter '$XLT_SOURCE' is neither a valid URL nor points to an existing file."
  exit 2;
fi

echo "Set up rights"
chown xlt:xlt "$TARGET_ARCHIVE"


# Execute post-installation script if present and executable
if [ -x "$SCRIPT_DIR/post-setup.sh" ]; then
  echo "Running post-setup"
  "$SCRIPT_DIR/post-setup.sh"
  if [ $? != 0 ]; then exit 4; fi
fi

# print version of installed tools for verification
echo "------------------------------------------------"
echo "JDK:"
runAsXltUser java --version
echo
echo "Chromium:"
runAsXltUser chromium --version
echo
echo "Chromedriver:"
runAsXltUser chromedriver --version
echo
echo "Firefox:"
runAsXltUser firefox --version
echo
echo "Geckodriver:"
runAsXltUser geckodriver --version
echo "------------------------------------------------"

# prepare image creation
echo "Remove SSH stuff ..."

[ -d /etc/ssh ] && rm /etc/ssh/ssh_host_*

# do NOT remove the authorized_keys file but just empty it
if [ -d /home/admin/.ssh ]; then
  echo | tee /home/admin/.ssh/authorized_keys
  if [ $? != 0 ]; then exit 4; fi
fi

# do NOT remove the authorized_keys file but just empty it
if [ -d /root/.ssh ]; then
  echo | tee /root/.ssh/authorized_keys
  if [ $? != 0 ]; then exit 4; fi
fi


## clean up
echo "Clean up setup files"
DEBIAN_FRONTEND=noninteractive apt-get -y autoremove \
  && apt-get -y clean \
  && rm -rf /var/lib/lists/*
cd /
rm -rf "$SCRIPT_DIR" "$INIT_SCRIPT_DIR"

echo "Setup finished."
