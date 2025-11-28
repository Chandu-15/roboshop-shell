#!/bin/bash
set -euo pipefail
AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-0c2d09e696b53ec3b"
ZONE_ID="Z04822952PR3OZ2CFSC4O"
DOMAIN_NAME="daws-86.shop"
for INSTANCE in "$@";
do 
    INSTANCE_ID=$(/usr/local/bin/aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --security-group-ids $SG_ID --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE}]" --query 'Instances[0].InstanceId' --output text)
   /usr/local/bin/aws ec2 wait instance-running --instance-ids $INSTANCE_ID
   if [ $INSTANCE != "Frontend" ]; then
     IP=$(/usr/local/bin/aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
     RECORD_NAME=$INSTANCE.$DOMAIN_NAME
    else
     IP=$(/usr/local/bin/aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
     RECORD_NAME=$DOMAIN_NAME
    fi

    echo "$INSTANCE: $IP"

    /usr/local/bin/aws route53 change-resource-record-sets \
    --hosted-zone-id $ZONE_ID \
    --change-batch '
    {
        "Comment": "Updating record set"
        ,"Changes": [{
        "Action"              : "UPSERT"
        ,"ResourceRecordSet"  : {
            "Name"              : "'$RECORD_NAME'"
            ,"Type"             : "A"
            ,"TTL"              : 1
            ,"ResourceRecords"  : [{
                "Value"         : "'$IP'"
            }]
        }
        }]
    }
    '
done


   