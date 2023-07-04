FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y openssh-sftp-server jq

COPY ./sftp.sh /

RUN chmod +x /sftp.sh

ENTRYPOINT [ "/sftp.sh" ]
CMD ["run"]
