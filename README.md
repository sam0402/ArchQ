# ArchQ　[![Donate](images/pdonate.png)](https://paypal.me/sam402shu)

ArchQ is a headless Arch Linux-based high-quality music server and player designed for audiophiles.

Powered by an optimized real-time kernel (EVL), the system operates at a high tick rate (441 / 396.9 / 352.8 kHz).
As a result, you’ll experience sound quality similar to upsampling from a 44.1 kHz sample rate.

ArchQ includes LMS, Roon (Bridge), MPD (with CD playback), as well as optimized versions of Squeezelite, AirPlay, and a CD ripper (abcde). It is easy to install and configure.
If the CPU has more than 4 cores, MPD, LMS, and Squeezelite will run on isolated cores.


Install step:
1. Download the [ArchQ Linux install iso](https://drive.google.com/file/d/1Zp0T7ZAq4wMue6HeBbgSmVg7S6QnTDV8/view?usp=share_link), [mirror](https://miya.teracloud.jp/share/11d13acaf100ea47)

2. Flash ISO image to USB drive by [Etcher](https://www.balena.io/etcher/?).

3. Boot up with USB drive with UEFI mode, than use `install` command. (Use `ip addr` to check if conneted on the network or not.)

4. After reboot, the monitor will not show any message only 'linux-Q352 ...'

5. Enter URL `http://name@archq.local:9000` or `http://ip.address:9000` in browser to configure LMS.

   Enter URL `http://name@archq.local:6660` or `http://ip.address:6660` in browser to configure RompЯ.

6. Use `ssh name@hostname.local` or `ssh name@ip.address` to login ArchQ system and configure. (Use [PuTTY](https://www.putty.org) for Windows)
   
   Enter command `config` for setting kernel version, partitions, NFS client, SMB/CIFS client, ethernet, squeezelite and Airplay.

7. Use command `sensors` to check the temperature of CPU, which is not too high.

Enter command `reboot` if need to.

Enjoy it!　[![Donate](images/buymeacoffee.png)](https://buymeacoff.ee/samshu.tw)
 
[ArchQ Chinese manual](http://www.stsd99.com/phpBB3/viewtopic.php?f=61&t=3210&sid=702a4898b30a89bc20ba1276940ef412) 

Supported Hardware: (Include Macbook or Mac mini Intel version)
 1. CPU: Intel & AMD (x86_64)
 2. Disk drive: SATA, USB, NVME >= 16GB
 3. Filesystem: F2FS(default), EXT4, XFS, HFS+(Apple), NTFS3, FATs, NFS, SMB/CIFS
 4. Ethernet: Intel e100, e1000, 82575/82576(IGB), I225-LM/I225-V (IGC), Realtek RTL8125/8129/8130/8139/8111/8168/8411
 5. USB Ethernet: Realtek RTL8152/8153/8156, ASIX AX88179/178A
 6. Sound card: USB(DDC, DAC) & HDMI (Intel i915)

Stand-alone: Install
 1. LMS + Squeezelite
 2. MPD (CD play, Multiroom, Httpd Stream)
 3. Roon
 5. HQPlayer Embedded 4 & 5
 6. Airplay

Client-server:

 Server: Install Roon or LMS
 
 Player:
  1. Airplay
  2. Squeezelite
  3. Roonbridge
  4. HQPlayer NAA
  5. Raspberry 4 or CM4 install with [pCP8-Q264ax.img.001](https://raw.githubusercontent.com/sam0402/pcp-44.1KHz/master/pCP8-Q264ax.img.7z.001),  [pCP8-Q264ax.img.002](https://raw.githubusercontent.com/sam0402/pcp-44.1KHz/master/pCP8-Q264ax.img.7z.002)
     
 HDMI output (Intel i915): Install and boot by Q352H

![Server](images/server_players.png)
![abcde](images/abcde.png)
![Squeezelite](images/squeezelite.png)
![Config](images/config.png)
![Kernels](images/kernels.png)
![ethernet](images/ethernet.png)
![SMB/CIFS](images/smbcifs.png)
![NFServer](images/NFServer.png)
![NFS](images/nfs_mount.png)
![Desktop](images/desktop_vnc.png)
![Partition](images/partition_mount.png)
![cpufreq](images/cpu_freq.png)
![multiroom](images/multiroom.jpg)
![Rompr](images/Rompr.png)
