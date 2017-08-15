#! /bin/sh
# This script is for PARROT BEBOP and BEBOP 2 Dones.
# Mounting script for recording to USB OTG Drive.
# v1.4a by PeteTum 12/08/2017
#
# Written by PeteTum.
# http://youtube.com/c/PeteTum
# To download full installer go to https://goo.gl/Hbpgu1
#
# Special thanks for https://github.com/Daggers/
# https://github.com/Daggers/Bebop2CopyMoveRecord2USBDrive

# debug
echo "------------------------ DEBUG ------------------------"
echo "Script version: v1.4a"
grep Hardware /proc/cpuinfo
echo "Firmware version "$(cat /version.txt)
echo
echo "Contents of /data/ftp"
ls -x /data/ftp
echo
echo "List of devices starting with /dev/sd"
ls -x /dev/sd*
echo "-------------------------------------------------------"
echo

# set user feedback
SOUND() { BLDC_Test_Bench -M 1 >/dev/null 2>&1; usleep 1010000; }
ERR_SOUND() { BLDC_Test_Bench -M 2 >/dev/null 2>&1; usleep 600000; }
LIGHT_R() { BLDC_Test_Bench -G 1 0 0 >/dev/null 2>&1; }
LIGHT_O() { BLDC_Test_Bench -G 1 1 0 >/dev/null 2>&1; }
LIGHT_G() { BLDC_Test_Bench -G 0 1 0 >/dev/null 2>&1; }
LIGHT_LIT() { sprop "system.shutdown" "0" >/dev/null 2>&1; }
LIGHT_FLA() { sprop "system.shutdown" "1" >/dev/null 2>&1; }
FB_START() { if [ $BBDIR == "Bebop_2" ]; then LIGHT_FLA; else LIGHT_R; fi; }
FB_WORKING() {
# starting heartbeat
	touch /tmp/heartbeat.tmp
	( while [ -f /tmp/heartbeat.tmp ]; do
		if [ $BBDIR == "Bebop_2" ];
			then LIGHT_FLA; usleep 50000; LIGHT_LIT; usleep 50000; LIGHT_FLA; usleep 50000; LIGHT_LIT
			else LIGHT_G; usleep 50000; LIGHT_O; usleep 50000; LIGHT_G; usleep 50000; LIGHT_O
		fi
		usleep 800000;
	done )
}
FB_DONE () {
# stopping heartbeat
rm -f /tmp/heartbeat.tmp
if [ $BBDIR == "Bebop_2" ]
	then SOUND; LIGHT_LIT
	else SOUND; LIGHT_G
fi
}
FB_ERROR () { 
# stopping heartbeat
rm -f /tmp/heartbeat.tmp
if [ $BBDIR == "Bebop_2" ]; 
	then ( ERR_SOUND; ERR_SOUND; ERR_SOUND; ERR_SOUND; ERR_SOUND ) & ( C=0; while [ $C -lt 20 ]; do LIGHT_LIT; usleep 50000; LIGHT_FLA; usleep 5000; let C=$C+1; done )
	else ( ERR_SOUND; ERR_SOUND; ERR_SOUND; ERR_SOUND; ERR_SOUND ) & ( C=0; while [ $C -lt 20 ]; do LIGHT_G; usleep 50000; LIGHT_R; usleep 5000; let C=$C+1; done )
fi 
}


# internal memory location
INTPATH=/data/ftp/internal_000

# detect hardware and set BBDIR
BBDIR=$( if grep -q Mykonos3 /proc/cpuinfo; then echo Bebop_Drone; elif grep -q Milos /proc/cpuinfo; then echo Bebop_2; fi )

# user feedback
FB_START
sleep 1
FB_WORKING &

if [ "$( mount | grep '/dev/sda' )" ] || [ "$( mount | grep '/dev/sdb' )" ]; then
# USB OTG drive path
	USBPATH=$( mount | grep '/dev/sda' | awk '{print $3}' )
# USB OTG drive hardware
	USBDEV=$( mount | grep '/dev/sda' | awk '{print $1}' )
elif [ "$( mount | grep '/dev/sdb' )" ]; then
# USB OTG drive path
	USBPATH=$( mount | grep '/dev/sdb' | awk '{print $3}' )
# USB OTG drive hardware
	USBDEV=$( mount | grep '/dev/sdb' | awk '{print $1}' )
fi




MOUNT () {
# Checks...
if [ ! $BBDIR ]; then
	ERROR=1; echo "Hardware NOT compatible."
elif [ ! $USBPATH ]; then
	ERROR=1; echo "USB drive not mounted"
elif [ ! -e /dev/sda ] && [ ! -e /dev/sdb ]; then
	ERROR=1; echo there is no usb device
else
	echo "All tests O.K."
fi

# Creating folders on the USB drive.
if [ ! $ERROR ];
then
	if [ ! -d $USBPATH/academy/ ]; then	mkdir $USBPATH/academy/; echo academy folder created; fi
	if [ ! -d $USBPATH/media/ ];   then mkdir $USBPATH/media/;   echo media folder created; fi
	if [ ! -d $USBPATH/navdata/ ]; then mkdir $USBPATH/navdata/; echo navdata folder created; fi
	if [ ! -d $USBPATH/thumb/ ];   then	mkdir $USBPATH/thumb/;   echo thumb folder created; fi
fi
sync
# Unmounting USB Drive
if [ ! $ERROR ];
then
	echo Unmounting USB Drive
	umount $USBPATH
	if [ $? -ne 0 ];
	then
		echo "Cannot unmount!"
		echo ""
		ERROR=1
	else
		echo Done
	fi
fi

# Re-mounting USB Drive to $INTMEM/$BBDIR
if [ ! $ERROR ];
then
	echo Re-mounting USB Drive to $INTMEM/$BBDIR
	mount $USBDEV $INTPATH/$BBDIR
	if [ $? -ne 0 ];
	then
		echo "Cannot mount!"
		echo ""
		ERROR=1
	fi
fi

if [ ! $ERROR ] && [ -e /dev/sda ]; then
#debug
	OLDUSBPATH=$USBPATH 
	echo $USBPATH > /tmp/oldusbpath.tmp
	USBPATH=$( mount | grep '/dev/sda' | awk '{print $3}' )
elif [ ! $ERROR ] && [ -e /dev/sdb ]; then
	USBPATH=$( mount | grep '/dev/sdb' | awk '{print $3}' )
fi

if [ ! $ERROR ] && [ ! $USBPATH ];
then
	echo "USB Drive unplugged"
	ERROR=1
elif [ ! $ERROR ] && [ ! $USBPATH == "$INTPATH/$BBDIR" ];
then
	echo "Failed to mount USB Drive for direct recordning."
	ERROR=1
elif [ ! $ERROR ];
then
	echo "USB Drive successfully mounted for direct recording."
if [ -d $OLDUSBPATH ] && [ ! "$(ls -A $OLDUSBPATH)" ]; then rm -rf $OLDUSBPATH; fi
fi
}

REMOUNT () {
OLDUSBPATH=$( if [ -f /tmp/oldusbpath.tmp ]; then cat /tmp/oldusbpath.tmp ; fi )

# Checks...
if [ ! $BBDIR ]; then
	ERROR=1; echo "Hardware NOT compatible."
elif [ ! $USBPATH ]; then
	ERROR=1; echo "USB drive not mounted"
else
	echo "All tests O.K."
fi

# Unmounting USB Drive
if [ ! $ERROR ];
then
	echo Unmounting USB Drive
	umount $INTPATH/$BBDIR
	if [ $? -ne 0 ];
	then
		echo "Cannot unmount!"
		echo ""
		ERROR=1
	fi
fi

# Re-mounting USB Drive to external


if [ ! $ERROR ] && [ ! -e /dev/sda ] && [ ! -e /dev/sdb ]; then
	echo There is no usb device. Nothing to remount.
	if [ -f /tmp/oldusbpath.tmp ]; then rm -f /tmp/oldusbpath.tmp ;	fi
else
	if [ ! $ERROR ] && [ ! "$( mount | grep '/dev/sda' )" ] && [ ! "$( mount | grep '/dev/sdb' )" ]; then
		if [ $OLDUSBPATH ] && [ -d $OLDUSBPATH ]; then
			echo Directory already exists $OLDUSBPATH
			echo ""
		elif [ $OLDUSBPATH ] && [ ! -d $OLDUSBPATH ]; then
			echo Creating directory $OLDUSBPATH
			mkdir $OLDUSBPATH
			if [ $? -ne 0 ]; then
				ERROR=1; echo "Cannot create directory!"
			fi
		elif [ ! $OLDUSBPATH ]; then
			OLDUSBPATH=/data/ftp/usbdrive_000
			echo Creating directory $OLDUSBPATH
			if [ ! -d $OLDUSBPATH ]
			then
				mkdir $OLDUSBPATH
				if [ $? -ne 0 ];
				then
					echo "Cannot create directory!"
					echo ""
					ERROR=1
				fi
			fi
		fi
	fi

	if [ ! $ERROR ] && [ ! -d $OLDUSBPATH ]; then
		echo "Directory doesn't exist! "$OLDUSBPATH
		ERROR=1
	fi
		
	if [ ! $ERROR ] && [ $OLDUSBPATH ];
	then
		echo Re-mounting USB Drive to $OLDUSBPATH
		mount $USBDEV $OLDUSBPATH
		if [ $? -ne 0 ];
		then
			echo "Cannot mount!"
			echo ""
			ERROR=1
		else
			echo Done
		fi
	fi

	if [ ! $ERROR ] && [ -e /dev/sda ]; 
	then
		USBPATH=$( mount | grep '/dev/sda' | awk '{print $3}' )
	elif [ ! $ERROR ] && [ -e /dev/sdb ]; then
		USBPATH=$( mount | grep '/dev/sdb' | awk '{print $3}' )
	fi

	if [ ! $ERROR ] && [ ! -e /dev/sda ];
	then
		echo "USB Drive unplugged"
		ERROR=1
	elif [ ! $ERROR ] && [ ! $USBPATH ];
	then
		echo "USB Drive successfully unmounted but couldn't remounted. It will be available after reboot."
	elif [ ! $ERROR ] && [ $USBPATH == $OLDUSBPATH ];
	then
		echo "USB Drive successfully mounted for as an external drive."
		if [ -f /tmp/oldusbpath.tmp ]; then rm -f /tmp/oldusbpath.tmp ;	fi
	fi
fi
}

if [ ! $( echo $USBPATH | grep "internal_000" ) ]
then
	echo usbpath is not in internal memory
	doing=mount
	MOUNT
elif [ $( echo $USBPATH | grep "internal_000" ) ]
then
	echo usb is already internal
	doing=remount
	REMOUNT
fi

# user feedback
if [ $ERROR ]; then
	FB_ERROR
elif [ $doing = "mount" ]; then
	FB_DONE
elif [ $doing = "remount" ]; then
	FB_DONE
	FB_DONE
fi