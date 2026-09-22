#!/bin/bash

# Description   :   This script finds and remove JndiLookup.class from the vulnerable Log4j jar files
#
# Returns       :   0 if found and removed successfully.
#                   1 if found and removed successfully.
#
# Usage 1       :   sh Linux-Log-4j-Mitigation.sh "<comma separated list of service names to restart>"
#                   To find and remove class in vulnerable log4j jar from root path, then restart the specified services 
#                   (Don't forget to wrap the arguments with double quotes)
#                   
# Usage 2       :   sh Linux-Log-4j-Mitigation.sh "<comma separated list of service names to restart>" "<comma separated list of paths>"
#                   To find and remove class in vulnerable log4j jar from the specified paths, then restart the specified services
#                   (Don't forget to wrap the arguments with double quotes)
#
# Example 1     :   sh Linux-Log-4j-Mitigation.sh "tomcat9"
# Example 2     :   sh Linux-Log-4j-Mitigation.sh "tomcat9,apache2" "/var/lib/tomcat9,/etc/apache2"
#
# Maintainer    :   ManageEngine Endpoint Central <endpointcentral-support@manageengine.com>

if [ "$#" = 0 ]; then
    echo "Usage 1 : sh Linux-Log-4j-Mitigation.sh \"<comma separated list of service names to restart>\""
    echo "          To find and remove class in vulnerable log4j jar from root path, then restart the specified services"
    echo "          (Don't forget to wrap the arguments with double quotes)"
    echo ""
    echo "Usage 2 : sh Linux-Log-4j-Mitigation.sh \"<comma separated list of service names to restart>\" \"<comma separated list of paths>\""
    echo "          To find and remove class in vulnerable log4j jar from the specified paths, then restart the specified services"
    echo "          (Don't forget to wrap the arguments with double quotes)"
    echo ""
    echo "Example 1 : sh Linux-Log-4j-Mitigation.sh tomcat9"
    echo "Example 2 : sh Linux-Log-4j-Mitigation.sh tomcat9,apache2 /var/lib/tomcat9,/etc/apache2"
    echo ""
    exit 1
fi

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root, to find all the vulnerable log4j jar files"
   exit 1
fi

if ! type zip > /dev/null 2>&1 || ! type unzip > /dev/null 2>&1 ; then
    echo "This script needs zip and unzip package to remove class file from the vulnerable log4j jar files. Install zip and unzip package"
    exit 1
fi

serviceList=`echo $1 | tr , "\n"`

startServices()
{
for serviceName in $serviceList; do
    service $serviceName start > /dev/null 2>&1
    status=$?
    if [ $status != 0 ]; then
        echo "Error while starting server, Service Name : $serviceName, error Code : $status"
    fi
done
}

checkAndRemoveClass()
{
    version=$(zipgrep -oh 'Implementation-Version:.*' $1 | cut -d: -f2 | awk '{$1=$1};1')
    status=$?
    echo "Found $1, Version : $version"
    if [ $status = 0 ]; then
        vulnerable="0"
        if $(echo $version | egrep -q "2\.([0-9]|1[0-5])\.[0-9.]+"); then
            case $version in
            *"2.12"*) if $(echo $version | egrep -q "2\.12\.[0-1]"); then vulnerable="1"; fi;;
            *"2.3"*) if [ $version = "2.3.0" ]; then vulnerable="1"; fi;;
            *) vulnerable="1";;
            esac
        fi
        if [ $vulnerable = "1" ]; then
            echo "Going to remove class file"
            cp -p "$1" "$1.bak" > /dev/null 2>&1
            status=$?
            if [ $status = 0 ]; then
                zip -d "$1" org/apache/logging/log4j/core/lookup/JndiLookup.class > /dev/null 2>&1
                status=$?
                if [ $status != 0 ] && [ $status != 12 ]; then
                    echo "Error while removing class file in $1, error Code : $status"
                    startServices
                    exit 1
                fi
            else
                echo "Error while backing up $1, error Code : $status"
                startServices
                exit 1
            fi
        fi
    else
        echo "Error while getting verion $1, error Code : $status"
        startServices
        exit 1
    fi
}

for serviceName in $serviceList; do
    service $serviceName stop > /dev/null 2>&1
    status=$?
    if [ $status != 0 ]; then
        echo "Error while stopping server, Service Name : $serviceName, error Code : $status"
        exit 1
    fi
done

if [ -n "$2" ]; then
    for path in `echo $2 | tr , "\n"`; do
        if [ -d $path ]; then
            for jarFile in $(find $path -type f -regex ".*log4j-core-[^-]*\.jar"); do
                checkAndRemoveClass $jarFile
            done
        fi
    done
else
    for jarFile in $(find / -type f -regex ".*log4j-core-[^-]*\.jar"); do
        checkAndRemoveClass $jarFile
    done
fi

startServices