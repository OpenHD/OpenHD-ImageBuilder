#!/usr/bin/env sh

# From https://gist.github.com/JustinTimperio/ae695eef5fda1f1590a685a017bbb5ec 
# Example: ./download_minio.sh example.url.com username password bucket-name minio/path/to/file.txt.zst /download/path/to/file.txt.zst

if [ -z $1 ]; then
  echo "You have NOT specified a MINIO URL!"
  exit 1
fi

if [ -z $2 ]; then
  echo "You have NOT specified a USERNAME!"
  exit 1
fi

if [ -z $3 ]; then
  echo "You have NOT specified a PASSWORD!"
  exit 1
fi

if [ -z $4 ]; then
  echo "You have NOT specified a BUCKET!"
  exit 1
fi

if [ -z $5 ]; then
  echo "You have NOT specified a MINIO FILE PATH!"
  exit 1
fi

if [ -z $6 ]; then
  echo "You have NOT specified a DOWNLOAD PATH!"
  exit 1
fi


# User Minio Vars
URL=$1
USERNAME=$2
PASSWORD=$3
BUCKET=$4
MINIO_PATH="/${BUCKET}/$5"
OUT_FILE=$6

# Static Vars
DATE=$(date -R --utc)
CONTENT_TYPE='application/zstd'
SIG_STRING="GET\n\n${CONTENT_TYPE}\n${DATE}\n${MINIO_PATH}"
SIGNATURE=`echo -en ${SIG_STRING} | openssl sha1 -hmac ${PASSWORD} -binary | base64`


curl -o "${OUT_FILE}" \
    -H "Host: $URL" \
    -H "Date: ${DATE}" \
    -H "Content-Type: ${CONTENT_TYPE}" \
    -H "Authorization: AWS ${USERNAME}:${SIGNATURE}" \
    https://$URL${MINIO_PATH}
