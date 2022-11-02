
#! /bin/bash
shell_renew(){
    curl -o /root/.naive.sh https://raw.githubusercontent.com/imajeason/nas_tools/main/NaiveProxy/install.sh 
    chmod +x /root/.naive.sh
    ln -s /root/.naive.sh /usr/bin/naive
}

shell_renew
naive