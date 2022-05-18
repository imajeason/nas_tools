上期添加了普通硬盘的挂载，并共享了

但作为一个nas系统，raid或者类raid的数据保护机制是必要的

现在我们就来实现它

使用的工具是snapraid

SnapRAID 是一个目录级别的冗余存储方案，它与 RAID 的原理有相似的地方，但它并不是 RAID。

特点

```bash
数据独立，跟unraid一样，所有硬盘里的数据是单独存储的
抗灾能力，折一点也跟unraid一样，没坏的盘里的数据就不会丢
配置更灵活，snapraid可以配置1-6块校验盘，用来实现更大的阵列
误删处理，因为snapraid的校验同步不是即时的，校验盘就可以作为误删恢复来使用，当然得在你同步前，如果你有此类需求，还需要使用增量备份
空间利利用率高，可以使用任意大小的校验盘，只不过校验盘的大小不能超过被校验数据的大小，比如说你有2块盘，10t，4t，如果是unraid必须10t用来做校验，但是snapraid可以用4t校验，为10t盘中最早使用的4t空间进行校验，10t中的其他6t不提供校验，可以存放不重要的数据，非常灵活
```

搞起

先给机器加几块硬盘，如果是nas机器，装上硬盘就好了，跟unraid类似

我用的虚拟机，添加3块盘，50g，50g，40g，第一块sdb作为校验盘

启动虚拟机

登录到系统

为方便演示，我是用secucrt来操作，大家可以在系统下操作或者putty来操作

登陆成功后查看硬盘

```bash
sudo fdisk -l
# 有3块盘
# sdb sdc sdd 均为53.7G，普通机器上可以大小不同的盘来操作
```

安装epel源

```bash
sudo yum install epel-release
sudo yum install snapraid
```

安装完成

```bash
# 如果是有数据的硬盘，直接挂载，如果是新盘需要做分区格式化才能挂载，注意数据盘别格式化直接跳到下一步
sudo fdisk /dev/sdb 
sudo mkfs.ext4 /dev/sdb1
# sdc，sdd相同
# 创建挂载点
sudo mkdir /mnt/{diskp,disk1,disk2}
# 挂载硬盘
sudo mount /dev/sdb1 /mnt/disk1
# 讲挂载信息写入/etc/fstab ，开机自动挂载
sudo blkid /dev/sdb1
sudo echo 'UUID=c1d94833-d69c-410e-90c2-799372a52d51 /mnt/diskp ext4 noatime,defaults 0 0' >> /etc/fstab
# 其他硬盘同理
sudo blkid /dev/sdc1
sudo echo 'UUID=e6e7d00b-c739-499a-a721-386887c5bcad /mnt/disk1 ext4 noatime,defaults 0 0' >> /etc/fstab

sudo blkid /dev/sdd1
sudo echo 'UUID=54539ff7-3e79-4c0f-9c45-6daf3950b7ec /mnt/disk2 ext4 noatime,defaults 0 0' >> /etc/fstab

```

配置/etc/snapraid.conf

填写以下内容 

```bash
# 后面是注释
parity parity /mnt/diskp/snapraid.parity
#2-parity /mnt/diskq/snapraid.2-parity
#3-parity /mnt/diskr/snapraid.3-parity
#4-parity /mnt/disks/snapraid.4-parity
#5-parity /mnt/diskt/snapraid.5-parity
#6-parity /mnt/disku/snapraid.6-parity
# 系统下还有一个盘是数据盘/data 可以存放文件列表，还可以作为数据盘
# content /data/snapraid.content
content /mnt/disk1/snapraid.content
content /mnt/disk2/snapraid.content

# 数据盘
data d1 /mnt/disk1/
data d2 /mnt/disk2/
# data d3 /mnt/disk3/

# 排除的文件类型以及目录
exclude Thumbs.db
exclude *.unrecoverable
exclude /tmp/
# exclude /lost+found/

# 块大小
blocksize 256
# 修改了多少数据才进行同步，除此之外也可以手动执行sync命令，或者crontab定时任务
autosave 5
```

运行

```bash
snapraid sync
# 空文件
```

因为没有数据，所以是空

之前的时候已经挂载了一个/data盘，也可以挂载进来

只需要去snapraid.conf中添加一条数据盘就可以了

可以发现，/data盘中有了一个snapraid文件，而且不影响现有其他文件

添加一个定时任务，每天凌晨一点执行同步

```bash
# sudo crontab -a
0 1 * * * /usr/bin/snapraid sync
```

现在备份做完了，但是数据需要单独写到硬盘里，这时候还需要一个合并工具把数据盘合并成一个盘方便使用，选择mergerfs

```bash
# 安装
wget https://github.com/trapexit/mergerfs/releases/download/2.32.6/mergerfs-2.32.6-1.el7.x86_64.rpm

sudo yum groupinstall "Development Tools"
sudo yum install glibc-static libstdc++-static
yum install mergerfs-2.32.6-1.el7.x86_64.rpm

# 创建一个挂载点
mkdir /mnt/vdisk
```

配置挂载，添加你的挂载到/etc/fstab，因为之前我们创建了一个新的

```bash
/mnt/disk1:/mnt/disk2:/data  /mnt/vdisk    fuse.mergerfs   defaults,allow_other,use_ino,minfreespace=10G,ignorepponrename=true 0 0

/mnt/disk1:/mnt/disk2:/data  /mnt/vdisk    fuse.mergerfs   defaults,noauto,allow_other,use_ino,minfreespace=10G,ignorepponrename=true 0 0
```

挂载

```bash
mount -a
mount -l
df -h
```

可以发现

现在有了/mnt/vdisk，这就是合并后的分区，测试一下

```bash
snapraid sync
# 其他命令
Sync, 同步数据，并更新校验，默认进行差量同步
Scrub，检查潜在的错误
Diff，列出和上一次存在的差别
Fix，尽可能恢复到上一次同步状态
Fix silent，修复潜在的错误

```

把共享修改一下

重启samba服务，查看共享

写入文件进行测试

```bash
iostat -d -m 2
```

因为是虚拟机，所以速度比较慢，物理机的话速度是正常的，毕竟写入只是往一个盘写入，没有校验

写入大于10g的容量，查看status

copy完毕

查看

```bash
snapraid status
snapraid sync
snapraid status
```

已经可以同步了

现在就完成了自由配置阵列大小与冗余大小的配置，而且，超过校验盘大小的硬盘也可以作为数据盘来使用，系统会提示浪费了多少，其实那不是浪费了，而是无法进行校验的部分，但是可以写入数据

模拟硬盘损坏，或者你有了其他更大的盘可以替换

直接更换，我这里是添加了一块数据盘，更换原来的/data

根据上面的操作，分区格式化新硬盘，如果有数据得直接挂载，修改fstab，修改snapraidconf配置文件

同步操作完可以看见数据都回来了

```bash
snapraid scrub
snapraid fix
# 如果已经发生了硬盘丢失或者文件丢失，就不能sync了，需要先修复现在的问题，修复完毕sync同步一次就可以了
# snapraid sync

```

所有的操作就完成了，如果你觉得snapraid适合你，需要知道以下几点

snapraid sync同步后生成地校验文件与数据盘中的content也就是文件列表是生成数据的重点

如果你太高频率的sync了，snapraid就无法起到数据恢复的作用了，手动进行sync可能是一个最佳方案，但是相对来说比较繁琐，每次修改了文件你需要手动进行操作

另外以上配置过程可以看出，写文件实际上写入的是具体的某一个磁盘，所以写入和读取速度都取决于这一块盘的性能，snapraid无法提高阵列性能

因为是文件系统级别的备份，如果小文件过多，所有的操作性能都会非常低

作为我个人来说，我硬盘多机器多，更适合我的肯定还是raid，之所以要配置snapraid，纯属为了对比下unraid的类raid

结论是相对unraid来说，

配置上当然是更加繁琐，如果你用的是omv5，是有插件可以界面操作的，相对来说可以大幅度的降低配置难度

snapraid更像一个文件版本管理的工具，可以进行文件误操作的恢复，数据恢复比较灵活这是unraid做不到的

性能方便，虽然性能没有办法提高，但是也没有降低，读写就是单盘的性能

snapraid可以在windows上使用

我个人的观点仅供参考，可以讨论