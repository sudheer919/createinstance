#!/bin/bash
LTD=lt-00d954dd0d5a270fb             ## template id
LVER=6                               ## template version
#COMPONENT=$1                            ## component name to pass
HOSTED_ZONE_ID=Z03836083A9HXUHEYJIW5 ## Hosted zone id

## validating the input is giving or not
if [ -z "$1" ]; then
  echo -e "\e[31mComponent Name Input Is Need"
  exit 1
fi
Instance_Create() {
  #####################################################################
  ##checking the instance Data is exist or not (INSTANCE_EXISTS)
  # hear -z "STRING"      True if string is empty.
  #      -z "STRING"      False if string is not empty.
  ##Launching the Spot instance fron template fron line 20
  ##Checking the instance Status is terminated or not (STATE)
  #####################################################################
  COMPONENT=$1
  INSTANCE_EXISTS=$(aws ec2 describe-instances --filters Name=tag:Name,Values=${COMPONENT} | jq .Reservations[])
  STATE=$(aws ec2 describe-instances --filters Name=tag:Name,Values=${COMPONENT} | jq .Reservations[].Instances[].State.Name | xargs)
  if [ -z "${INSTANCE_EXISTS}" -o "$STATE" == "terminated" ]; then
    aws ec2 run-instances --launch-template LaunchTemplateId=${LTD},Version=${LVER} --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${COMPONENT}}]" | jq
  else
    echo -e "Instance \e[35m${COMPONENT}\e[0m Already Exist"
  fi

  IPADDRESS=$(aws ec2 describe-instances --filters Name=tag:Name,Values=${COMPONENT} | jq .Reservations[].Instances[].PrivateIpAddress | grep -v null | xargs)
  sed -e "s/COMPONENT/${COMPONENT}/" -e "s/IPADDRESS/${IPADDRESS}/" record.json >/tmp/record.json
  aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch file:///tmp/record.json
  sed -i -e "/${COMPONENT}/ d " ../inventory
  echo "${IPADDRESS}  APP=$(echo ${COMPONENT})" >> ../inventory
}

if [ "$1" == "all" ]; then
  for instance in frontend mongodb catalogue redis user cart mysql shipping rabbitmq payment; do
    Instance_Create $instance
  done
else
  Instance_Create $1
fi
