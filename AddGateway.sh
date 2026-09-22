#  It is recommended to test the script on a local machine for its purpose and effects.
#  ManageEngine Endpoint Central will not be responsible for any
#  damage/loss to the data/setup based on the behavior of the script.
#  Description - Script to add Default Gateway
#  Scrtipt argument - "<interface name>" "<IP Address>"
#  Example 1 - "192.168.1.254" "eth0"
#  Example 2 - "142.22.112.22" "eth2"
#  Configuration Type - COMPUTER

if [ $# == '2' ]; then

route add default $2 -ifscope $1
ret=$?
if [ $ret == "0" ]; then
echo "Added default gateway Successfully"
else
echo "Error in Adding gateway IP"
fi
exit $ret

else
echo "Invalid Arguments - Please refer description of the script"
exit 1
fi
