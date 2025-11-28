#!/usr/bin/env bash

DOMAIN_FILE="$1"
OUTFILE="$2"

if [ -z "$DOMAIN_FILE" ] || [ -z "$OUTFILE" ]; then
  echo "Usage: $0 <domain_list.txt> <outfile.csv>"
  exit 1
fi

if [ ! -f "$DOMAIN_FILE" ]; then
  echo "Domain file $DOMAIN_FILE not found!"
  exit 1
fi

# Write CSV header
echo "Domain,IssueDate,ExpiryDate,SAN" > "$OUTFILE"

while IFS= read -r DOMAIN; do
  [ -z "$DOMAIN" ] && continue
  [[ "$DOMAIN" =~ ^# ]] && continue

  echo "Fetching latest certificate SANs for $DOMAIN ..."

  CERT_ID=$(curl -s "https://crt.sh/?q=${DOMAIN}&output=json" \
            | jq -r 'sort_by(.entry_timestamp) | last | .id')

  if [ -z "$CERT_ID" ] || [ "$CERT_ID" == "null" ]; then
    echo "No certificate found for $DOMAIN"
    continue
  fi

  PEM=$(curl -s "https://crt.sh/?d=${CERT_ID}")

  if [ -z "$PEM" ]; then
    echo "Failed to download certificate for $DOMAIN"
    continue
  fi

  # Extract SANs
  SANs=$(echo "$PEM" | openssl x509 -noout -text 2>/dev/null \
         | grep -oP 'DNS:[^,]*' | sed 's/DNS://')

  # Extract issue date (notBefore) and expiry (notAfter)
  ISSUE_RAW=$(echo "$PEM" | openssl x509 -noout -startdate 2>/dev/null)
  EXPIRY_RAW=$(echo "$PEM" | openssl x509 -noout -enddate 2>/dev/null)

  ISSUE=${ISSUE_RAW#notBefore=}
  EXPIRY=${EXPIRY_RAW#notAfter=}

  # Convert both to DD-MM-YYYY
  ISSUE_FMT=$(date -u -d "$ISSUE" +"%d-%m-%Y" 2>/dev/null)
  EXPIRY_FMT=$(date -u -d "$EXPIRY" +"%d-%m-%Y" 2>/dev/null)

  # Fallback if date -d fails (BSD/macOS)
  if [ -z "$ISSUE_FMT" ]; then ISSUE_FMT="$ISSUE"; fi
  if [ -z "$EXPIRY_FMT" ]; then EXPIRY_FMT="$EXPIRY"; fi

  # Output each SAN on its own CSV row
  while IFS= read -r SAN; do
    echo "\"$DOMAIN\",\"$ISSUE_FMT\",\"$EXPIRY_FMT\",\"$SAN\"" >> "$OUTFILE"
  done <<< "$SANs"

  sleep 1

done < "$DOMAIN_FILE"

echo "CSV output saved to $OUTFILE"
