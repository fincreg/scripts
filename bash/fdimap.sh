#!/bin/bash

auth=$1
host=$2
port=$3
user=$4
pass=$5
header=$6
value=$7

imap () {
  exec 10<>/dev/tcp/$host/143 || return 1
  exec 4> >(tee >(cat - >&10))

  while read -u10 -t 10 r
  do
    echo "$r"
    case "$r" in
     "* OK [CAPA"*) [[ "$header" != "" && "$value" != "" ]] &&\
                    echo -ne "A001 LOGIN $user $pass\r\n" >&4 ||\
                    echo -ne "ONLY LOGIN $user $pass\r\n" >&4 ;;
        "A001 OK"*) echo -ne "A002 SELECT INBOX\r\n" >&4 ;;
        "A002 OK"*) echo -ne "A003 SEARCH HEADER $header \"$value\"\r\n" >&4 ;;
      "* SEARCH "*) [[ "$r" =~ ^\*[[:space:]]+SEARCH[[:space:]]+(.*)$ ]] && MSGNUM=${BASH_REMATCH[1]};;
        "A003 OK"*) [[ -n "$MSGNUM" ]] &&\
                    echo -ne "A004 FETCH ${MSGNUM##* } BODY[HEADER]\r\n" >&4 ||\
                    echo -ne "A004 LOGOUT\r\n" >&4 ;;
        "A004 OK"*) echo -ne "A005 LOGOUT\r\n" >&4 ;;
        "ONLY OK"*) echo -ne "END LOGOUT\r\n" >&4 ;;
           *" NO"*) echo -ne "ERR LOGOUT\r\n" >&4 ;;
    esac
  done

  exec 10<&-
  exec 4<&-

  return 0
}

imap
