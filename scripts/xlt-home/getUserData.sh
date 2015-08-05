USERDATA_EC2_URL="http://169.254.169.254/latest/user-data"
USERDATA_DO_URL="http://169.254.169.254/metadata/v1/user-data"

# get the user data
USERDATA=`curl -s -f $USERDATA_EC2_URL 2>&1`
if [[ -z "$USERDATA" ]]
  then
  USERDATA=`curl -s -f $USERDATA_DO_URL 2>&1`
fi

export IFS="&"
for data in $USERDATA; do
  if [[ $data == $1=* ]]
    then
    echo $(echo $data | sed -e 's/[a-z]*=//' | base64 --decode)
  fi
done
