#!/bin/bash
set -e
set -u

clear

ami="ami-10e00b6d"
size="t2.medium"
today=$(date +"%m-%d-%y-%H%M")
localip=$(curl -s https://ipinfo.io/ip)

printf "Launching Kali EC2 Instance.\\n"
printf "AMI: %s\\n" "$ami"
printf "Type: %s\\n" "$size"
printf "\\n"

# Create SSH Key
mkdir -p  ~/Documents/instantkali/
aws ec2 create-key-pair --key-name KaliKey$today --query 'KeyMaterial' --output text >  ~/Documents/instantkali/KaliKey$today.pem
chmod 400  ~/Documents/instantkali/KaliKey"$today".pem

# Create Security Group
aws ec2 create-security-group --group-name KaliSecurityGroupSSHOnly"$today" --description "Inbound SSH only from my IP address" > /dev/null
aws ec2 authorize-security-group-ingress --group-name KaliSecurityGroupSSHOnly"$today" --cidr "$localip"/32 --protocol tcp --port 22


# Launch a Ec2 instance
instance=$(aws ec2 run-instances --image-id $ami --instance-type $size --key-name KaliKey$today --security-groups KaliSecurityGroupSSHOnly$today --output text)

id=$(printf "$instance" | grep INSTANCES | cut -f 8)
state=$(printf "$instance" | grep STATE | head -n 1 | cut -f 3)
printf "Instance launched: %s \\n" "$id"
printf "\\n"

# tag the instance
aws ec2 create-tags --resources $id --tags Key=Name,Value="Kali$today"

printf "Starting Instance: \\n"

# Wait for instance in `running` status
while [ "$state" = pending ]; do
    echo -ne "Waiting for running status.\\r"
    sleep 10
    info=$(aws ec2 describe-instances --instance-ids $id --output text)
    state=$(echo "$info" | grep STATE | cut -f 3)
done

printf "\\n"


# Fetch the publish host name
awsip=$(aws ec2 describe-instances --instance-ids $id --query "Reservations[*].Instances[*].PublicIpAddress" --output=text)

# Probe SSH connection until it's avalable
X_READY=''
while [ ! $X_READY ]; do
    echo -ne "Waiting for ready status.\\r"
    sleep 10
    set +e
    out=$(ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o BatchMode=yes ec2-user@$awsip 2>&1 | grep 'Permission denied' )
    [[ $? = 0 ]] && X_READY='ready'
    set -e
done

printf "\\n"
printf "\\n"

# Done
printf "Kali is Ready! Login With:\\n"
printf "ssh -i ~/Documents/instantkali/KaliKey%s.pem ec2-user@%s\\n" "$today" "$awsip"
