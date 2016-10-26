#!/bin/bash

#require openssl
#require base64

auth=$1
host=$2
port=25
user=$3
pass=$4
from=$user
to=$user
step=0
data="Subject: SMTP Check
From: $from
To: $to

Hello!
test
"

smtp () {
  exec 10<>/dev/tcp/$host/$port
  exec 4> >(tee >(cat - >&10))

  while read -u10 r
  do
    echo "$r"
    case "$r:$auth:$step" in
      "220 "*)                    echo -ne "EHLO test\r\n" >&4                            ;;
      "250 "[A-Za-z]*:LOGIN:0)    echo -ne "AUTH LOGIN\r\n" >&4         ; let step++     ;;
      "250 "[A-Za-z]*:PLAIN:0)    echo -ne "AUTH PLAIN\r\n" >&4         ; let step++     ;;
      "250 "[A-Za-z]*:CRAM-MD5:0) echo -ne "AUTH CRAM-MD5\r\n" >&4      ; let step++     ;;
      "334 VXNlcm5hbWU6"*:LOGIN:*)  echo -ne "$(b64 $user)\r\n" >&4                         ;;
      "334 UGFzc3dvcmQ6"*:LOGIN:*)  echo -ne "$(b64 $pass)\r\n" >&4                         ;;
      "334"*:PLAIN:*)               echo -ne "$(b64 "\0$user\000$pass")\r\n" >&4            ;;
      "334"*:CRAM-MD5:*)            echo -ne "$(cram-md5 $user $pass ${r/* })\r\n" >&4      ;;
      "235 "*)                    echo -ne "MAIL FROM: $from\r\n" >&4                     ;;
      "250 "*:*:1)                echo -ne "RCPT TO: $to\r\n" >&4       ; let step++     ;;
      "250 "*:*:2)                echo -ne "DATA\r\n$data\r\n.\r\n" >&4 ; let step++     ;;
      "250 "*:*:3)                echo -ne "QUIT\r\n" >&4               ; let step++     ;;
      "250-"*) ;; "221 "*) ;; 
      *)                          echo -ne "QUIT\r\n" >&4                                 ;;
    esac
  done

  exec 10<&-
  exec 4<&-

  return $true
}

function cram-md5 () { 
  local luser=$1
  local lpass=$2
  local lreq=$3

  local req_decr=$(printf "$lreq\n" | openssl enc -base64 -d)
  local hmac_md5=$(printf "$req_decr" | openssl dgst -md5 -hmac "$lpass")
  local response=$(printf "$luser ${hmac_md5/* }" | openssl enc -base64 -A)

  echo $response
}

function b64 () {
  local response=$(printf "$@" | base64)

  echo $response
}

smtp
