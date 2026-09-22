#!/bin/bash

# DISCLAIMER   :   It is recomended to test this script on a test machine.
#                  ManageEngine will not be responsible for any damage/loss
#                  to the data/setup based on the behavior of the script.
#
# DESCRIPTION  :   Script to add sudo privilege to existing local user in linux agent machines.
#
# ARGUMENT(S):
#         ARGUMENT FORMAT: <user_name>
#         EXAMPLE        : test
#
#    RETURN VALUE                  MEANING
#
#         0             Sudo privilege added successfully
#         1             Error while adding sudo privilege
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

  username=$1

  addsudo=1

  id $username

  if [ $? -eq 1 ]; then
    echo "User: $username not exists"
    errorCode=1
    break
  fi

  sudolist=$(cat "/etc/sudoers" | grep -v '^\s*#' | grep -v '^\s*%' | grep -v 'root' | grep 'ALL' | sed 's/ .*//' | sed 's/\t.*//')
  for i in $sudolist; do
    if [ $i = $username ]; then
      echo "User $username already have sudo privilege"
      errorCode=1
      addsudo=0
      break
    fi
  done

  if [ $addsudo -eq 1 ]; then
    echo "$username ALL=(ALL) ALL" >>/etc/sudoers
    echo "For User: $username sudo privilege added successfully"
  else
    echo "Error while adding sudo privilege"
    errorCode=1
  fi
done

errorFunc() {
  return $errorCode
}
errorFunc
