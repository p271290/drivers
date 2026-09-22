#!/bin/bash

# DISCLAIMER   :   It is recomended to test this script on a test machine.
#                  ManageEngine will not be responsible for any damage/loss
#                  to the data/setup based on the behavior of the script.

# DESCRIPTION  :   Script to change existing local user password in linux agent machines.
#
# ARGUMENT(S):
#  1) User for whom password should be changed.
#
#         ARGUMENT FORMAT: <user_name>
#         EXAMPLE        : test
#
#    Edit the line password="passwd" to password="your_password" in this script.
#    Edit the line confirm_password="passwd" to confirm_password="your_new_password" in this script.
#
#     IMPORTANT NOTE:
#     If password contains dollar symbol, kindly use escape character before $, else script will fail.
#     For Example : If user password is Manageengine$ ,then Edit the line password="Manageengine\$"
#                   If user password is Manageengine$$ ,then Edit the line password="Manageengine\$\$"
#     Same applies for confirm_password also.
#
#
#           RETURN VALUE                  MEANING
#
#                0             Password changed successfully.
#                1             Error while changing password.
#                2             Invalid arguments.
#                3             Password did not match.
# NOTE :
#   To see the script output, Kindly enable the option Enable logging in Troubleshooting while deploying configuration.

errorCode=2
euid=$(id -u)

for i in 1; do
  #check sudo access
  if [ $euid -ne 0 ]; then
    echo "This script must be run as root"
    break
  fi

  if [ $# -ne 1 ]; then
    echo "Incorrect Usage : Arguments mismatch."
    echo "Refer ARGUMENT(S) section in this script."
    break
  fi

  errorCode=0
  username=$1

  export HISTIGNORE="*passwd*"

  #  Edit the line password="passwd" to password="your_password" in this script.
  #  Edit the line confirm_password="passwd" to confirm_password="your_new_password" in this script.
  #
  #  IMPORTANT NOTE:
  #    If password contains dollar symbol, kindly use escape character before $, else script will fail.
  #    For Example : If user password is Manageengine$ ,then Edit the line password="Manageengine\$"
  #                  If user password is Manageengine$$ ,then Edit the line password="Manageengine\$\$"
  #    Same applies for confirm_password also.
  password="passwd"
  confirm_password="passwd"

  # check given username exist or not
  IsUser=$(grep -c '^'$username':' /etc/passwd)

  if [ $IsUser -eq 0 ]; then
    echo "UserName : $username does not exist"
    errorCode=1
    break
  fi

  if [ "$password" != "$confirm_password" ]; then
    echo "Passwords did not match"
    errorCode=3
    break
  fi

  # change the password for given user
  echo $username:$password | chpasswd
  # fallback if chpasswd fails
  if [ $? -ne 0 ]; then
    echo -e "$password\n$password" | passwd $username
    if [ $? -ne 0 ]; then
      echo "$password\n$password" | passwd $username
    fi
  fi

  if [ $? -eq 0 ]; then
    echo "User: $username password changed successfully"
  else
    echo "Error while changing password for user: $username"
    errorCode=1
  fi
done

errorFunc() {
  return $errorCode
}
errorFunc
