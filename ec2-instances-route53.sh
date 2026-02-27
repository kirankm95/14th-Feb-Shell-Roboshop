#!/bin/bash
AMI="ami-0b4f379183e5706b9"
SG="sg-0ec1d694d0be0920e"
SUBNET="subnet-0b81d24fb28353d3f"
HOSTED_ZONE="Z09372402SX8LY0VINKFB"
DOMAIN="kiranku.online"

APP=("web" "catalogue" "cart" "user" "shipping" "payments" "dispatch" "mongodb" "redis" "mysql" "rabbitmq")

for i in "${APP[@]}"
do
  echo "Creating instance for $i"

  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI" \
    --instance-type t3.micro \
    --security-group-ids "$SG" \
    --subnet-id "$SUBNET" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${i}}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

  echo "Instance ID: $INSTANCE_ID"

  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

  PRIVATE_IP=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[0].Instances[0].PrivateIpAddress' \
      --output text)

  echo "Private IP: $PRIVATE_IP"

  JSON_FILE=$(mktemp)
  cat > "$JSON_FILE" <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${i}.${DOMAIN}",
        "Type": "A",
        "TTL": 1,
        "ResourceRecords": [
          { "Value": "${PRIVATE_IP}" }
        ]
      }
    }
  ]
}
EOF

  aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch "file://$JSON_FILE"

  rm -f "$JSON_FILE"

  echo "Route53 record created for ${i}.${DOMAIN}"
  echo "----------------------------------------"
done