# leap42-newton-aio

This is BASH scripts for practicing create all OpenStack Newton services in one openSUSE Leap 42 node.

Main reference: http://docs.openstack.org/newton/install-guide-obs/

__Requirements__
* CPU 4 cores
* RAM 8 GB
* HDD 30 GB
  * sda1 / XFS 16GB
  * sda2 SWAP 4GB
  * sda3 Extended all remaining disk space
  * sda5 LVM (PV) 5GB
  * sda6 XFS 1GB
  * sda7 XFS 1GB
  * sda8 XFS 1GB
  * sda9 XFS 1GB
* openSUSE Leap 42 minimal installation

__Topology__

Below is topology if the practice is using VM in VirtualBox
![alt tag](https://raw.githubusercontent.com/GLiBogor/leap42-newton-aio/master/leap42-newton-aio.png)

