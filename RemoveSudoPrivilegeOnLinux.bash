#!/bin/bash

# DISCLAIMER   :   It is recomended to test this script on a test machine.
#                  ManageEngine will not be responsible for any damage/loss
#                  to the data/setup based on the behavior of the script.
#
# DESCRIPTION  :   Script to remove sudo privilege from existing local user in linux agent machines.
#
# ARGUMENT(S):
#         ARGUMENT FORMAT: <user_name>
#         EXAMPLE        : test
#
#    RETURN VALUE                  MEANING
#
#         0             Sudo privilege removed successfully
#         1             Error while removing sudo privilege
#         2             Invalid arguments.
# NOTE :
#   To see the script output, Kindly enable the option Enable logging in Troubleshooting while deploying configuration.

errorCode=0
euid=$(id -u)

for q in 1; do

  #check root access
  if [ $euid -ne 0 ]; then
    echo "This script must be run as root"
    break
  fi

  if [ $# -lt 1 ]; then
    echo "Incorrect Usage : No arguments given."
    echo "Refer ARGUMENT(S) section in the script."
    errorCode=2
    break
  fi

  user=$1

  doesUserExist=$(grep -c '^'$user':' /etc/passwd)

  if [ $doesUserExist -eq 0 ]; then
    echo "User: $user does not exist."
    errorCode=1
    break
  fi

  sed -i '/'$user'/d' /etc/sudoers
  if [ $? -eq 0 ]; then
    echo "For User: $username sudo privilege removed successfully"
  else
    echo "Error while removing sudo privilege"
    errorCode=1
  fi

  sudogrouplist=$(cat "/etc/sudoers" | grep '^\s*%' | sed 's/ //' | sed 's/ALL.*//' | sed 's/%//')
  sudogrouplist=$(echo "$sudogrouplist superadmin sudo")
  echo " ~~~~~~~~~~~~~~~~ "
  echo " Sudo groups : $sudogrouplist "
  echo " ~~~~~~~~~~~~~~~~ "
  #Removing user from any other existing sudo groups.
  for i in $user; do
    usergroup=$(groups $i | sed 's/[^:]*//' | sed 's/://')
    for j in $usergroup; do
      for k in $sudogrouplist; do
        if [ $j = $k ]; then
          gpasswd -d $i $j
        fi
      done
    done
  done
done

errorFunc() {
  return $errorCode
}
errorFunc
