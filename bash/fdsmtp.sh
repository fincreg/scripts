#!/bin/bash

#require openssl
#require base64

[[ $# -lt 5 ]] && {
  cat <<'EOF'
Usage: fdsmtp.sh auth host port user pass [rcpt] [subject]

  auth      AUTH method: NOLOGIN, LOGIN, PLAIN, CRAM-MD5, or LOGINONLY
  host      SMTP server
  port      SMTP port
  user      Username/email for authentication
  pass      Password
  rcpt      Recipient email (default: same as user, self sending)
  subject   Email subject (default: "TEST Message")

Example (with authentication):
  ./fdsmtp.sh LOGIN smtp.example.com 25 user@example.com password

Example (no authentication):
  ./fdsmtp.sh NOLOGIN smtp.example.com 25 user@example.com dummy

Example (auth only, no sending):
  ./fdsmtp.sh LOGINONLY smtp.example.com 25 user@example.com password
EOF
  exit 1
}

auth=$1
host=$2
port=$3
user=$4
pass=$5
from=${user}
rcpt=${6:-${user}}
subj=${7:-"TEST Message"}

data="X-Mailer: BASH
Subject: $subj
From: \"$from\" <$from>
To: <$rcpt>

Deliverability test message

Sincerely,
BASH Script

"

smtp () {
  exec 10<>/dev/tcp/$host/$port || return 1
  exec 4> >(tee >(cat - >&10))

  if [[ "$auth" == "LOGINONLY" ]]; then
    auth="LOGIN"
    nosending=true
  fi

  step=0
  while read -u10 -t 10 r
  do
    echo "$r"
    case "$r:$auth:$step" in
      "220 "*)                      echo -ne "EHLO ${from#*@}\r\n" >&4                              ;;
      "250 "[A-Za-z]*:NOLOGIN:0)    echo -ne "MAIL FROM: <$from>\r\n" >&4              ; ((step=3)) ;;
      "250 "[A-Za-z]*:LOGIN:0)      echo -ne "AUTH LOGIN\r\n" >&4                      ; ((step++)) ;;
      "250 "[A-Za-z]*:PLAIN:0)      echo -ne "AUTH PLAIN\r\n" >&4                      ; ((step++)) ;;
      "250 "[A-Za-z]*:CRAM-MD5:0)   echo -ne "AUTH CRAM-MD5\r\n" >&4                   ; ((step++)) ;;
      "334 VXNlcm5hbWU6"*:LOGIN:1)  echo -ne "$(b64 $user)\r\n" >&4                                 ;;
      "334 UGFzc3dvcmQ6"*:LOGIN:1)  echo -ne "$(b64 $pass)\r\n" >&4;\
                                    [[ "$nosending" == true ]] && ((step=9)) ||          ((step++)) ;;
      "334"*:PLAIN:1)               echo -ne "$(b64 "\0$user\000$pass")\r\n" >&4       ; ((step++)) ;;
      "334"*:CRAM-MD5:1)            echo -ne "$(cram-md5 $user $pass ${r/* })\r\n" >&4 ; ((step++)) ;;
      "235 "*:*:2)                  echo -ne "MAIL FROM: <$from>\r\n" >&4              ; ((step++)) ;;
      "250 2.1.0"*:*:3)             echo -ne "RCPT TO: <$rcpt>\r\n" >&4                ; ((step++)) ;;
      "250 2.1.5"*:*:4)             echo -ne "DATA\r\n" >&4; sleep .5;\
                                    echo -ne "$data\r\n.\r\n" >&4                      ; ((step++)) ;;
      "250 2.0.0"*:*:5)             echo -ne "QUIT\r\n" >&4                            ; ((step++)) ;;
      "235 "*:*:9)                  echo -ne "QUIT\r\n" >&4                            ; ((step++)) ;;
      "250-"*)                                                                                      ;;
      "221 "*)                                                                                      ;;
    esac
  done

  exec 10<&-
  exec 4<&-

  return 0
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
