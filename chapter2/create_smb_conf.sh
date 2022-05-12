#!/bin/bash
dirconf="/etc/samba/smb.conf"
if ! rpm -q samba >/dev/null
then
   echo "将要安装samba"
   sleep 1
   yum -y install samba
   if [ $? -ne 0 ]
   then
      echo "samba 安装失败"
      exit 1
   fi
fi
echo "安装完成，开始配置.........--"
# 清空判断的参数值
unset doShare
# 判断是否需要创建共享，以及共享类型
while [ ! -n "$doShare" ]
do 
    read -p "创建共享访问权限: 1 公共  2 私密 0 退出"  doShare
    echo $doShare
    if [ -z $doShare ]
    then
        continue
    fi
    if [ $doShare -eq 0 ]
    then
        echo "退出."
        exit
    elif [ $doShare -eq 1 ]
        then 
        # 创建公共路径
        read -p "输入共享目录的绝对路径，例如/data/share： " sharepath
        echo $sharepath
        sharepath=$(echo $sharepath|sed -e 's/[ ]*//g')
        if [[ -z $(echo $sharepath | egrep "^/") ]]
        then
            echo "请提供一个绝对路径！"
            unset doShare
            continue
        fi
        # grep "\\$sharepath\$" $dirconf
        if [[ -n $(egrep $sharepath $dirconf )  ]]
        then
            echo "这个目录已经被共享了，查看配置文件$sharepath！"
            unset doShare
            continue
        fi


        # 创建公共共享

        sed -i 's#security.*#security = user#g' $dirconf
        sed -i 's#workgroup.*#workgroup = WORKGROUP#g' $dirconf
        sharename=$(echo $sharepath | sed 's;\/;;g')
        cat >> $dirconf << EOF
[$sharename]
        comment = Public Directories $sharepath #共享文件描述
        path = $sharepath
        browseable = yes
        public = yes
        writable = yes
        read only = no
        guest ok = yes
EOF
        if [ ! -d $sharepath ]
        then
            mkdir -p $sharepath
        fi

        chmod 777 $sharepath
        chown nobody:nobody $sharepath
        echo "Mr zhang da qi, follow me." > $sharepath/qi.txt



    elif [ $doShare -eq 2 ]
    then
        # 用户输入目录
        read -p "输入要共享的目录名：" sharepath
        sharepath=$(echo $sharepath|sed -e 's/[ ]*//g')
        if [[ -z $(echo $sharepath | egrep "^/") ]]
        then
            echo "请提供一个绝对路径！"
            unset doShare
            continue
        fi

        # grep "\\$sharepath\$" $dirconf
        if [[ -n $(egrep $sharepath $dirconf )  ]]
        then
            echo "这个目录已经被共享了，查看配置文件$sharepath！"
            unset doShare
            continue
        fi


        # 创建私密共享，需要创建用户
        read -p "输入用户名: " smbusername
        # if [[ "$smbusername" =~ ^[[:alpha:]]([[:alnum:]])* ]]
        if [[ -z $(echo $sharepath | egrep "^[a-z0-9A-Z][0-9a-zA-Z]*") ]]
        then 
            # 创建用户

            useradd $smbusername
            pdbedit -a -u zhangdaqi $smbusername
        else 
            echo "用户名规则为字母打头的字母与数字：$smbusername 不合法，重新进行操作。"
            unset doShare
            continue
        fi
        # 创建共享


        sed -i 's#security.*#security = user#g' $dirconf
        sed -i 's#workgroup.*#workgroup = WORKGROUP#g' $dirconf
        sharename=$(echo $sharepath | sed 's;\/;;g')
        cat >> $dirconf << EOF
[$sharename]
        comment= share $sharename
        path = $sharepath
        browseable = yes
        public = no
        writable = yes
        create mask = 0775       
        directory mask = 0775             
        write list = $smbusername         
        admin users = $smbusername             
EOF
        if [ ! -d $sharepath ]
        then
            mkdir -p $sharepath
        fi

        chmod 755 $sharepath
        chown $smbusername:$smbusername $sharepath
        echo "Mr zhang da qi, follow me." > $sharepath/qi.txt


    fi
    echo "=================="

done


systemctl restart smb
systemctl enable smb
if [ $? -ne 0 ]
then
   echo "samba服务启动失败，请检查配置文件是否正常"
else
   echo "samba服务启动正常"
fi
chmod +x $0
