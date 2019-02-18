#!/bin/bash

## first the variables
SCRIPT_DIR=`dirname $0`
SCRIPT_DIR="$SCRIPT_DIR/../xlt-home"
INIT_SCRIPT_DIR="$SCRIPT_DIR/../init.d"

XLT_USER="xlt"
XLT_HOME="/home/$XLT_USER"

IPv6_SCRIPT_NAME="ipv6tunnel"
MOUNT_SCRIPT_NAME="mountdev"
UPDATE_SCRIPT_NAME="update-xlt.sh"
IMAGE_PREPARATION_SCRIPT_NAME="prepare-image-creation.sh"
USERDATA_START_SCRIPT_NAME="userdata"
XLT_SERVICE_CONFIG="xlt.service"
XLT_INITD_SCRIPT_NAME="xlt"
XLT_START_SCRIPT_NAME="start-xlt.sh"
XLT_VERSION=${1:-LATEST}
NTP_START_SCRIPT="ntptime"

FIREFOX_ESR_VERSION="60.2.2esr"
FIREFOX_ESR_DOWNLOAD_URL="https://download-installer.cdn.mozilla.net/pub/firefox/releases/${FIREFOX_ESR_VERSION}/linux-x86_64/en-US/firefox-${FIREFOX_ESR_VERSION}.tar.bz2"
FIREFOX_ESR_CHECKSUM="71ac702c25e654c04ee61ddd5a394ae52e27886beeed7d575542e3fe7e8e4939"
GECKODRIVER_VERSION="v0.23.0"
GECKODRIVER_DOWNLOAD_URL="https://github.com/mozilla/geckodriver/releases/download/${GECKODRIVER_VERSION}/geckodriver-${GECKODRIVER_VERSION}-linux64.tar.gz"
CHROMEDRIVER_VERSION="2.43"
CHROMEDRIVER_DOWNLOAD_URL="https://chromedriver.storage.googleapis.com/${CHROMEDRIVER_VERSION}/chromedriver_linux64.zip"

OPENJDK_DOWNLOAD_URL="https://download.java.net/java/GA/jdk11/9/GPL/openjdk-11.0.2_linux-x64_bin.tar.gz"
OPENJDK_CHECKSUM="99be79935354f5c0df1ad293620ea36d13f48ec3ea870c838f20c504c9668b57"

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

checkFile $UPDATE_SCRIPT_NAME;
checkFile $IMAGE_PREPARATION_SCRIPT_NAME;
checkFile $XLT_START_SCRIPT_NAME;
checkFile openjdk-dummy_0.0.1_all.deb

checkInitFile $USERDATA_START_SCRIPT_NAME;
checkInitFile $XLT_INITD_SCRIPT_NAME;
checkInitFile $NTP_START_SCRIPT;

## create XLT user
echo "Create XLT user"
sudo adduser --disabled-login --disabled-password $XLT_USER


## update system
echo "Update system"
# update available packages
sudo apt-get update
DEBIAN_FRONTEND=noninteractive sudo -E apt-get -y upgrade
# install required progs: unzip, firefox, Xvfb etc.
DEBIAN_FRONTEND=noninteractive sudo -E apt-get --no-install-recommends -y install \
  wget \
  curl \
  unzip \
  tar \
  xvfb \
  dos2unix \
  software-properties-common \
  firefox \
  ipv6calc \
  chromium-browser \
  libgconf-2-4 \
  dbus-x11 \
  git \
  jq

# install OpenJDK11
curl -Ls "$OPENJDK_DOWNLOAD_URL" -o /tmp/openjdk11.tgz
echo "$OPENJDK_CHECKSUM /tmp/openjdk11.tgz" | sha256sum -c --status - || exit 1
sudo mkdir -p /usr/lib/jvm
sudo tar -C /usr/lib/jvm -xzf /tmp/openjdk11.tgz
rm /tmp/openjdk11.tgz

JAVA_HOME=/usr/lib/jvm/jdk-11.0.2
sudo update-alternatives --install /usr/bin/java java $JAVA_HOME/bin/java 1099

cat <<-EOF | sudo tee /etc/profile.d/jdk.sh > /dev/null
export JAVA_HOME=$JAVA_HOME
export PATH=\$PATH:\$JAVA_HOME/bin
EOF
sudo chmod +x /etc/profile.d/jdk.sh

# Set default keystore type to JKS
sudo sed -i -e 's/^\(keystore\.type\)=.*$/\1=JKS/' $JAVA_HOME/conf/security/java.security

sudo dpkg -i $SCRIPT_DIR/openjdk-dummy_0.0.1_all.deb

sudo apt-get install -y --no-install-recommends ca-certificates-java \
  && sudo rm $JAVA_HOME/lib/security/cacerts \
  && sudo ln -s /etc/ssl/certs/java/cacerts $JAVA_HOME/lib/security/


# install Maven (Maven needs Java, so install it in the correct order)
DEBIAN_FRONTEND=noninteractive sudo -E apt-get --no-install-recommends -y install maven


# Download Firefox ESR and put it into path
curl -L $FIREFOX_ESR_DOWNLOAD_URL -o /tmp/firefox.tar.bz2
echo "$FIREFOX_ESR_CHECKSUM /tmp/firefox.tar.bz2" | sha256sum -c -
sudo tar -xj -C /tmp -f /tmp/firefox.tar.bz2
[ -d /usr/lib/firefox-esr ] && sudo rm -rf /usr/lib/firefox-esr
sudo mv /tmp/firefox /usr/lib/firefox-esr
sudo ln -s /usr/lib/firefox-esr/firefox /usr/bin/firefox-esr
rm /tmp/firefox.tar.bz2

# Download Geckodriver from GitHub and put it into path
curl -L $GECKODRIVER_DOWNLOAD_URL -o /tmp/geckodriver-linux64.tgz
sudo tar -xz -C /usr/bin -f /tmp/geckodriver-linux64.tgz
sudo chown root:root /usr/bin/geckodriver
sudo chmod 755 /usr/bin/geckodriver

# Download chromedriver from Google and put it into path
curl -L $CHROMEDRIVER_DOWNLOAD_URL -o /tmp/chromedriver_linux64.zip
sudo unzip -d /usr/bin /tmp/chromedriver_linux64.zip
sudo chown root:root /usr/bin/chromedriver
sudo chmod 755 /usr/bin/chromedriver
rm /tmp/chromedriver_linux64.zip

## Clean up
sudo apt-get clean && rm -rf /var/lib/lists/*

## move scripts to their destination folder and setup permissions

# set update script
echo "Install update script"
sudo cp $SCRIPT_DIR/$UPDATE_SCRIPT_NAME $XLT_HOME
sudo chmod 755 $XLT_HOME/$UPDATE_SCRIPT_NAME
sudo chown xlt:xlt $XLT_HOME/$UPDATE_SCRIPT_NAME

# set image preparation script
echo "Install image preparation script"
sudo cp $SCRIPT_DIR/$IMAGE_PREPARATION_SCRIPT_NAME $XLT_HOME
sudo chmod 755 $XLT_HOME/$IMAGE_PREPARATION_SCRIPT_NAME
sudo chown xlt:xlt $XLT_HOME/$IMAGE_PREPARATION_SCRIPT_NAME

# setup XLT start script
echo "Install XLT start script"
sudo cp $SCRIPT_DIR/$XLT_START_SCRIPT_NAME $XLT_HOME
sudo chmod 755 $XLT_HOME/$XLT_START_SCRIPT_NAME
sudo chown xlt:xlt $XLT_HOME/$XLT_START_SCRIPT_NAME

# set ntp script
echo "Install NTP script"
sudo cp $INIT_SCRIPT_DIR/$NTP_START_SCRIPT /etc/init.d/
sudo chmod 755 /etc/init.d/$NTP_START_SCRIPT
sudo update-rc.d $NTP_START_SCRIPT start 19 2 3 4 5 .

# user data script
echo "Install UserData script"
sudo cp $INIT_SCRIPT_DIR/$USERDATA_START_SCRIPT_NAME /etc/init.d/
sudo chmod 755 /etc/init.d/$USERDATA_START_SCRIPT_NAME
sudo update-rc.d $USERDATA_START_SCRIPT_NAME remove

# set start script
echo "Install initial XLT start script"
sudo update-rc.d $XLT_INITD_SCRIPT_NAME remove
sudo cp $INIT_SCRIPT_DIR/$XLT_INITD_SCRIPT_NAME /etc/init.d/
sudo chmod 755 /etc/init.d/$XLT_INITD_SCRIPT_NAME
if [ -d /etc/systemd ]; then
  # Remove "old" userdata.service - we have XLT service now!
  if [ -f /etc/systemd/system/userdata.service ]; then
    sudo systemctl disable userdata.service
    sudo rm /etc/systemd/system/userdata.service
  fi

  sudo cp $INIT_SCRIPT_DIR/$XLT_SERVICE_CONFIG /etc/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl enable $XLT_SERVICE_CONFIG

else
  sudo update-rc.d $XLT_INITD_SCRIPT_NAME defaults
fi

# set IPv6 script
if [ -e $INIT_SCRIPT_DIR/$IPv6_SCRIPT_NAME ]; then
  echo "Install IPv6 script"
  sudo cp $INIT_SCRIPT_DIR/$IPv6_SCRIPT_NAME /etc/init.d/
  sudo chmod 755 /etc/init.d/$IPv6_SCRIPT_NAME
  sudo update-rc.d $IPv6_SCRIPT_NAME defaults
fi


## tune system limits
echo "Tune system limits"
FOUND=$(grep '^\s*\*\s*soft\s*nofile' /etc/security/limits.conf)
if [ ! $? -eq 0 ]; then
  echo "*       soft    nofile  128000" | sudo tee -a /etc/security/limits.conf >/dev/null
fi
FOUND=$(grep '^\s*\*\s*hard\s*nofile' /etc/security/limits.conf)
if [ ! $? -eq 0 ]; then
  echo "*       hard    nofile  128000" | sudo tee -a /etc/security/limits.conf >/dev/null
fi
### ... same for SystemD
if [ -f /etc/systemd/system.conf ]; then
  FOUND=$(grep '^\s*DefaultLimitNOFILE=' /etc/systemd/system.conf)
  if [ ! $? -eq 0 ]; then
    echo "DefaultLimitNOFILE=128000" | sudo tee -a /etc/systemd/system.conf >/dev/null
  fi
fi


## secure login
echo "Secure login"
sudo sed -ri 's/^\s*PermitRootLogin\s*yes$/PermitRootLogin\ no/g' /etc/ssh/sshd_config


## install XLT
while true; do
  read -p "Do you want to download and install the latest version of XLT? [Y/n] : " yn
  case $yn in
    ''|[yY] )
      sudo $XLT_HOME/$UPDATE_SCRIPT_NAME "https://lab.xceptance.de/nexus/service/rest/v1/search/assets/download?group=com.xceptance&name=xlt&repository=public&maven.extension=zip&version=${XLT_VERSION}"
      break
      ;;
    [nN] )
      echo "If you want to install XLT execute $XLT_HOME/$UPDATE_SCRIPT_NAME ."
      echo "If you intent to create an AMI don't forget to call $XLT_HOME/$IMAGE_PREPARATION_SCRIPT_NAME ."
      break
      ;;
    * )
      echo "Please answer 'y', 'Y', 'n', or 'N'. If nothing is entered the default answer is 'y'."
      ;;
  esac
done


## clean up
while true; do
  read -p "Do you want to clean up setup files? [Y/n] : " yn
  case $yn in
    ''|[yY] )
      echo "Clean up setup files"
      cd $HOME
      sudo rm -rf $SCRIPT_DIR
      sudo rm -rf $INIT_SCRIPT_DIR
      break
      ;;
    [nN] )
      break
      ;;
    * )
      echo "Please answer 'y', 'Y', 'n', or 'N'. If nothing is entered the default answer is 'y'."
      ;;
  esac
done

echo "Setup finished."
