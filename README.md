# SFTP SERVICE

Script to setup SFTP server and generate config files for all users passed by the customer.

Usage: sftp.sh [ run || cleanup || help ]

run --> setup the server and generate necessary files for users

cleanup --> delete files older than 48 hours and empty directories into users $HOME

help --> Print this help screen


# CONFIG FILES AND MOUNTS:

- ssh_host_*_key files --> /mnt/data/hostkeys/

- users home --> /mnt/data/home/

- users.json --> /opt/conf/

## EXAMPLE of JSON struct for users:

```json

{
    "users": [
        {
            "username" : "test",
            "keys" : [
                "ssh-rsa xxxxx test@debian",
                "ssh-rsa zzzzzzzzzzz test@debian"
            ]
        },
        {
            "username": "sftp_user",
            "keys" : [
                "ssh-rsa yyyyyy sftp_user@debian"
            ]
        }
    ]
}

```
