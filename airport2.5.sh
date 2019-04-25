#!/bin/bash
#################################################
# Script originally from the posted
# "Air Defense" script posted awhile back on JAMF Nation
# Revised to work on newer USB-C hardware Macs
# Revision by Christopher Miller for 
# ITSD-ISS of JHU-APL, Dated: 2017-02-20
#################################################
# Some variables to make things easier to read:
#############################################
PlistBuddy=/usr/libexec/PlistBuddy
plist=/Library/Preferences/SystemConfiguration/NetworkInterfaces.plist
FILE=/tmp/ether.cfg


# Find the number of Interfaces
######################################################
# NOTE: Newer USB-C only systems keep reporting 
# the Thunderbolt Bridge adapter as ALWAYS active
# Thus using grep -v to avoid listing the bridge
######################################################
count=$(networksetup -listallhardwareports | grep -i "Device: en" -B 1 | grep -v -i "Bridge" | grep -v -i "Bluetooth"| grep "Hardware" | grep -v -i "fw" | wc -l | tr -s " ")
#count=$(networksetup -listallhardwareports | grep -i "Device: en" -B 1 | wc -l | tr -s " ")
echo "Found$count network interfaces"
let count=count+1


# Set Counter to Zero, Get Interface media
#############################################
counter=0
while [ $counter -lt $count ] 
do
	interface[$counter]=$($PlistBuddy -c "Print Interfaces:$counter:SCNetworkInterfaceType" $plist) 
	#echo $interface[$counter]
	let "counter += 1"
done


#############################################
# Get Real Interfaces
#############################################
# reset counter
#############################################
counter=0

while [ $counter -lt $count ] 
do
		bsdname[$counter]=$($PlistBuddy -c "Print Interfaces:$counter:BSD\ Name" $plist)
		echo $bsdname[$counter]
	let "counter += 1"
done


##########################################################################################
# Build Airport Array ${airportArray[@]} and Ethernet Array ${ethernetArray[@]}
##########################################################################################
counter=0
while [ $counter -lt $count ] 
do
# Check for Airport, add to array when found
	if [ "${interface[$counter]}" = "IEEE80211" ]; then
		airportArray[$counter]=${bsdname[$counter]}
	fi

# Check for Ethernet, add to array when found
	if [ "${interface[$counter]}" = "Ethernet" ]; then
		ethernetArray[$counter]=${bsdname[$counter]}
	fi
	let "counter += 1"
done


#############################################
# Tell us what was found
#############################################
for i in ${ethernetArray[@]}
do
	echo $i is Ethernet
done

for i in ${airportArray[@]}
do
	echo $i is Airport
done

############################################
# Add interfaces from ifconfig rather than
# using the standard loop above
############################################


ifconfig |grep en[1-9]: |awk '{print $1}'| cut -d '=' -f 2 | sed 's/:$//' >>$FILE

getArray() {
    array=() # Create array
    while IFS= read -r line # Read a line
    do
        array_en+=("$line") # Append line to the array
    done < "$1"
}

getArray "$FILE"


for i in "${array_en[@]}"; do echo "$i"; done


#############################################
# Check to see if any Ethernet is connected
# Figure out which Interface has activity
#############################################
#MACTST=`ifconfig | grep "ac:de:48:00:11:22" |awk '{print $2}'`
mycount=`ifconfig |grep en[1-9]: |wc -l`
#for i in ${ifaces[@]}
for i in ${array_en[@]}
do
		MACTST=`ifconfig | grep "ac:de:48:00:11:22" |awk '{print $2}'`
		MACADD=`ifconfig $i| grep ether |awk '{print $2}'`
		checkActive=`ifconfig $i | grep status | awk '{print $2}'`

		echo $i $MACADD $checkActive
		echo "Are these the same $MACTST $MACADD?"
		if [ "$MACADD" == "$MACTST" ]; then
			echo "They are the same!"
			checkActive="inactive"
		else
			echo "$i is not the toolbar bus."
		fi
		if [ "$checkActive" == 'active' ]; then 
			# Ethernet IS connected
			echo "$i is connected with MAC address $MACADD...turning off Airport"
			networksetup -setairportpower ${airportArray[@]} off
			echo "Airport off"
		else
			# Ethernet is NOT connected
			echo "$i is not active"
		fi
		
done
	rm $FILE
	echo "Checked all Interfaces"

# Exit the script, we'll check again later
exit 0
