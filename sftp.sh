#!/bin/bash

function cleanup() {

    base_dir="/mnt/data/home/*/pub/"

    files_output=""
    files=$(find $base_dir -type f -mtime +2)
    for file in $files;
    do
        files_output+="$file\n"
        rm -f "$file"
    done


    dirs_output=""
    dirs=$(find $base_dir -mindepth 1 -type d -empty)
    for dir in $dirs; 
    do 

        dirs_output+="$dir\n"
        rm -df "$dir"
    
    done

    files_count=$(echo -ne $files_output | wc -l)
    dirs_count=$(echo -ne $dirs_output | wc -l)

if [ $files_count -ge 1 ] || [ $dirs_count -ge 1 ]
then
    
    echo -ne "Deleted $files_count files and $dirs_count empty folders\n"
    echo -ne "\n$files_output\n$dirs_output\n"
    echo "Cleanup successfull!"
    exit 0
else
    echo "Nothing to clean!"
    exit 0
fi
  
}


function run() {
   
    user_conf="/opt/conf/users.json"
    hostkeys="/mnt/data/hostkeys"
    home="/mnt/data/home"
    default_keys="$(ls /etc/ssh/ssh_host_*key)"

    if [ ! -f "$user_conf" ]
    then
        echo "$user_conf users configuration file does not exist!"
        exit 1
    fi

    echo "Validating JSON for user configuration..."
    cat $user_conf | jq -e > /dev/null

    if [ $? -ne 0 ]; then
        echo "Cannot parse JSON Users configuration in $user_conf"
        exit 1
    fi

    echo "JSON validated successfully!"
    
    echo "Creating $hostkeys and $home folders"
    mkdir -pv $hostkeys $home
    echo "Set 755 mode to /mnt/data/"
    chmod 755 /mnt/data

    #for default_key in $default_keys; do new_key="$(echo $default_key | cut -d "/" -f 4)"; list_keys+="${new_key} "; done
    for key_types in $default_keys; do new_key="$(echo $key_types | cut -d "/" -f 4 | cut -d "_" -f 3)"; list_keys+="${new_key} "; done    

    echo "Removing host keys under default sshd folder"
    rm -vf /etc/ssh/ssh_host_*key*

    echo "Creating host keys if not already exist in $hostkeys"

    key_counter=0

    for key_type in $list_keys; do

        new_key_path="$hostkeys/ssh_host_${key_type}_key"

        if [ ! -f "$new_key_path" ]; then

                { ssh-keygen -t $key_type -f $new_key_path -N '' <<<y && echo "Host key $key_type created succesfully!"; ((key_counter++)); } || echo "Cannot generate host $key_type key!"                
        fi
        
    done

    find $hostkeys -mindepth 1 -maxdepth 1 | read || { echo "No SSH host key generated. Cannot continue!"; exit 1; } 

    if [ $key_counter -gt 0 ]; then echo "Generated $key_counter SSH key"; else echo "No SSH key generated"; fi;

    echo "Creating folder for SSHD process"
    mkdir -vp /run/sshd
    echo "Creating SSH configuration to support SFTP"
    sed -E -i 's+^(.*/usr/lib/openssh/sftp-server)+#\1+' /etc/ssh/sshd_config
    tee /etc/ssh/sshd_config.d/sftp_configuration.conf << EOF
Subsystem	sftp 	internal-sftp
PermitRootLogin	no
HostKey ${hostkeys}/ssh_host_rsa_key
HostKey ${hostkeys}/ssh_host_ecdsa_key
HostKey ${hostkeys}/ssh_host_ed25519_key
EOF

    users=$(jq -rc '.users[].username' $user_conf)
    echo -e "\nChecking for old users home to remove..."
    for user_home in $(ls $home); do 
        if [ ! $(grep -w "$user_home" <<< "$users") ]
        then
            rm -rvf $home/$user_home
            echo "Removed $user_home home because user no longer exist!"
        fi
    done

    for user in $users;
    do
        echo -e "\nCreating user $user..."
        useradd -m -d $home/$user -s /bin/false $user
        echo "Creating '.ssh' folder for user: $user "
        mkdir -vp $home/$user/.ssh/
        echo "Creating new 'authorized_keys' file or empty it if exists for user: $user"
        > $home/$user/.ssh/authorized_keys
        echo "Creating 'known_hosts' file if not exists for user: $user"
        touch $home/$user/.ssh/known_hosts
        echo "Creating $home/$user/pub folder for user: $user"
        mkdir -pv $home/$user/pub
        echo "Set 'root' as owner of $home/$user for chroot environment"
        chown root: $home/$user
        echo "Set user: $user owner of 'pub' folder"
        chown -R $user:$user $home/$user/pub
        echo "Set 755 mode for $home/$user"
        chmod -R 755 $home/$user
        echo "Creating SSH config for $user in /etc/ssh/sshd_config.d/$user.conf"
        tee /etc/ssh/sshd_config.d/$user.conf << EOF
Match User $user
  ChrootDirectory %h
  ForceCommand internal-sftp
  AllowTcpForwarding no
  X11Forwarding no
EOF
    echo -e "\nVerifying SSH $user keys..."
    keys=$(jq --arg username $user -cr '.users[] | select(.username==$username).keys' $user_conf | sed 's/\[//g;s/\]//g;s/"//g')
    export IFS=","
      for key in $keys;
        do
          type=$(echo "$key" | ssh-keygen -lf /dev/stdin | awk '{printf $4}' | tr -d '(;)')
          byte=$(echo "$key" | ssh-keygen -lf /dev/stdin | awk '{printf $1}')
          if [ "$type" == "RSA" ] && [ "$byte" -ge 2048 ]
          then
              echo -e "$key\n" >> $home/$user/.ssh/authorized_keys
          else
              echo "Public key ""$key"" for user ""$user"" must be at least RSA 2048"!
              exit 1
          fi
      done
    unset IFS

    echo "All keys verified successfully!"

    done

    echo "Configuration script ended successfully!"

    exec /usr/sbin/sshd -D -e
}

function help() {

    echo "
Script to setup SFTP server and generate config files for all users passed by the customer.

Usage: "$0" [ run || cleanup || help ]

run --> setup the server and generate necessary files for users

cleanup --> delete files older than 48 hours and empty directories into users "\$HOME"

help --> Print this help screen
"
}

function main() {

  case $1 in
  run)
    run
    ;;

  cleanup)
    cleanup
    ;;

  *)
    help
    exit 1
    ;;
  esac

}

main $1
