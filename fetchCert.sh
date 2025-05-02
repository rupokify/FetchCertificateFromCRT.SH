#!/bin/bash

# Get target common name as input from the user
printf "\n>> Write the target common name and hit Enter! \n\n"

read commonName

printf "\n"

# Exit if no common name is entered
if [ -z "$commonName" ]; then
  echo "No Valid Common Name Entered!"
  exit 1
fi

# Fetch certificates in JSON format
certs=$(curl -s "https://crt.sh/?q=${commonName}&output=json")

# Pick the latest certificate ID
latestID=$(echo "$certs" | jq '.[0].id')

# Exit if no certificate is found
if [ $latestID == null ]; then
  echo "+------------------------------------------------------+"
  echo "| > Could not find any certificate for: $commonName !  |"
  echo "+------------------------------------------------------+"
  exit 1
fi

echo "+-------------------------------------------+"
echo "| > Certificate Found!                      |"
echo "+-------------------------------------------+"

echo "+-------------------------------------------+"
echo "| > Downloading certificate PEM...          |"
echo "+-------------------------------------------+"

curl -s "https://crt.sh/?d=${latestID}" -o "${commonName}.crt"

echo "+-------------------------------------------+"
echo "| > Certificate saved in current directory! |"
echo "+-------------------------------------------+"