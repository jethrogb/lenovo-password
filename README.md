Implementation of Lenovo ThinkPad HDD password algorithm
========================================================

This repository contains an implementation of the Lenovo ThinkPad HDD 
encryption password hashing algorithm. This can be useful to unlock your drive 
on another computer when your laptop fails.

Usage
-----

You'll need to save the ATA IDENTIFY block for the relevant hard drive (sda in 
this case):

    sudo hdparm --Istdout /dev/sda > sda.ata_identify

Enter the password and store the password hash in environment variable P:

    P="$(ruby pw.rb sda.ata_identify)"

The script will print an error message if there's something wrong with the 
input or output.

Next, use the password for one of the security commands of 
hdparm, e.g.:

    sudo hdparm --security-unlock "$P" /dev/sda

See also https://jbeekman.nl/blog/2015/03/lenovo-thinkpad-hdd-password/
