#!/bin/bash

# Define the permission set and group names
PERMISSION_SET_NAME="DB_OPS" # Replace to your permissionset
GROUP_NAME="YourGroupNameHere"   #  Change group name

# Get the Identity Center (SSO) instance ARN
INSTANCE_ARN=$(aws sso-admin list-instances --query "Instances[0].InstanceArn" --output text)

# Get the Identity Store ID to fetch group info
IDENTITY_STORE_ID=$(aws sso-admin list-instances --query "Instances[0].IdentityStoreId" --output text)

# Get the correct permission set ARN by name
PERMISSION_SET_ARN=""
for arn in $(aws sso-admin list-permission-sets --instance-arn $INSTANCE_ARN --output text --query "PermissionSets[]"); do
  name=$(aws sso-admin describe-permission-set \
           --instance-arn $INSTANCE_ARN \
           --permission-set-arn $arn \
           --query "PermissionSet.Name" --output text)
  if [[ "$name" == "$PERMISSION_SET_NAME" ]]; then
    PERMISSION_SET_ARN=$arn
    break
  fi
done

echo "Permission Set ARN for $PERMISSION_SET_NAME is: $PERMISSION_SET_

if [[ -z "$PERMISSION_SET_ARN" ]]; then
  echo "Permission set '$PERMISSION_SET_NAME' not found."
  exit 1
fi

echo "Found permission set ARN: $PERMISSION_SET_ARN"

#  FETCH GROUP ID 

GROUP_ID=$(aws identitystore list-groups \
  --identity-store-id $IDENTITY_STORE_ID \
  --query "Groups[?DisplayName=='$GROUP_NAME'].GroupId" \
  --output text)

if [[ -z "$GROUP_ID" ]]; then
  echo "Group '$GROUP_NAME' not found in Identity Store."
  exit 1
fi

echo "Found group ID: $GROUP_ID"

#  GET AWS ACCOUNT LIST 

ACCOUNT_IDS=$(aws organizations list-accounts --query "Accounts[].Id" --output text)

#- ASSIGN GROUP TO PERMISSION SET IN EACH ACCOUNT 

for ACCOUNT_ID in $ACCOUNT_IDS; do
  echo "Assigning group '$GROUP_NAME' to permission set '$PERMISSION_SET_NAME' in account $ACCOUNT_ID..."

  aws sso-admin create-account-assignment \
    --instance-arn $INSTANCE_ARN \
    --target-id $ACCOUNT_ID \
    --target-type AWS_ACCOUNT \
    --permission-set-arn $PERMISSION_SET_ARN \
    --principal-type GROUP \
    --principal-id $GROUP_ID

  if [[ $? -eq 0 ]]; then
    echo "Successfully assigned in account $ACCOUNT_ID"
  else
    echo "Failed to assign in account $ACCOUNT_ID"
  fi
done
