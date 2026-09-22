#!/bin/bash

# DISCLAIMER   :   It is recomended to test this script on a test machine.
#                  ManageEngine will not be responsible for any damage/loss
#                  to the data/setup based on the behavior of the script.
#
# DESCRIPTION  :   Script to sync with NTP time server from the list specified in  https://www.pool.ntp.org/zone/@
#
# ARGUMENT(S):
#  1) To sync with the time server.
#
#         ARGUMENT FORMAT: <ntp_server>
#         EXAMPLE        : us.pool.ntp.org
#
#           RETURN VALUE          MEANING
#
#                0             Timeserver synced successfully.
#                1             Error while syncing with timeserver
#                2             Invalid arguments.
#
# NOTE :
#   To see the script output, Kindly enable the option Enable logging in Troubleshooting while deploying configuration.

errorCode=2
for i in 1; do
  euid=$(id -u)
  #check root access
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
  timeServer=$1

  ntpdate -u $timeServer

  if [ $? -eq 0 ]; then
    echo "Timeserver synced successfully."
  else
    echo "Error while syncing with timeserver"
    errorCode=1
  fi
done

errorFunc() {
  return $errorCode
}
errorFunc
