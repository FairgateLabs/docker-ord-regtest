#!/bin/bash
set -euo pipefail
# example:  ./ordinal.sh --file=fairgate.png --destiny-address=bcrt1pnyhqvdrw4hndcntckmzwadcy00g4cvxfjfaf580ke83g6a4ge65qcwzjml

# === Configurable Variables ===

# File to inscribe (leave blank to prompt interactively)
INSCRIPTION_FILE_NAME=""
INSCRIPTION_FILE_PATH="./"

# Bitcoin node RPC configuration
BITCOIN_NODE_CONTAINER="bitcoin-regtest-node"
BITCOIN_RPC_URL="http://bitcoin-regtest-node:18443"
BITCOIN_RPC_USER="foo"
BITCOIN_RPC_PASS="rpcpassword"

# Ordinal wallet container and API config
ORD_CONTAINER_NAME="ord"
ORDINAL_PORT="8080"
ORDINAL_SERVER_URL="http://0.0.0.0:$ORDINAL_PORT"

# Optional destination address (leave empty to prompt interactively)
DESTINATION_ADDRESS=""

# === Parse Command-line Arguments ===
for ARG in "$@"; do
  case $ARG in
    --file=*)
      INSCRIPTION_FILE_NAME="${ARG#*=}";
      shift;;
    --destiny-address=*)
      DESTINATION_ADDRESS="${ARG#*=}";
      shift;;
    *)
      echo "Unknown argument: $ARG";
      exit 1;;
  esac
done

# === Helper Functions ===

wait_for_ord_sync() {
  echo "Waiting for ord to sync..."
  while true; do
    if docker exec -i "$ORD_CONTAINER_NAME" ord \
      --data-dir /index-data \
      --bitcoin-rpc-url "$BITCOIN_RPC_URL" \
      --regtest \
      --bitcoin-rpc-username "$BITCOIN_RPC_USER" \
      --bitcoin-rpc-password "$BITCOIN_RPC_PASS" \
      wallet --server-url "$ORDINAL_SERVER_URL" balance &> /dev/null; then
      break
    fi
    sleep 1
  done
}

# === Script Execution ===

# Prompt for inscription file name if not set
if [ -z "$INSCRIPTION_FILE_NAME" ]; then
  echo -n "Enter the name of the file to inscribe (relative to $INSCRIPTION_FILE_PATH): "
  read INSCRIPTION_FILE_NAME
fi

# TODO: check if wallet already exists before creating
# Create Ordinal Wallet
WALLET_OUTPUT=$(docker exec -i "$ORD_CONTAINER_NAME" ord \
  --data-dir /index-data \
  --bitcoin-rpc-url "$BITCOIN_RPC_URL" \
  --regtest \
  --bitcoin-rpc-username "$BITCOIN_RPC_USER" \
  --bitcoin-rpc-password "$BITCOIN_RPC_PASS" \
  wallet create)

echo "Wallet created."

# Get Address from Wallet
ORDINAL_WALLET_ADDRESS=$(docker exec -i "$ORD_CONTAINER_NAME" ord \
  --data-dir /index-data \
  --bitcoin-rpc-url "$BITCOIN_RPC_URL" \
  --regtest \
  --bitcoin-rpc-username "$BITCOIN_RPC_USER" \
  --bitcoin-rpc-password "$BITCOIN_RPC_PASS" \
  wallet --server-url "$ORDINAL_SERVER_URL" receive | jq -r '.addresses[0]')

echo "Ordinal wallet address: $ORDINAL_WALLET_ADDRESS"

# Mine 101 Blocks to Ordinal Wallet
docker exec -i "$BITCOIN_NODE_CONTAINER" bitcoin-cli -regtest -rpcuser="$BITCOIN_RPC_USER" -rpcpassword="$BITCOIN_RPC_PASS" \
  generatetoaddress 101 "$ORDINAL_WALLET_ADDRESS" > /dev/null

echo "Mined 101 blocks."

# Copy inscription file to container
docker cp "${INSCRIPTION_FILE_PATH}${INSCRIPTION_FILE_NAME}" "$ORD_CONTAINER_NAME":/"$INSCRIPTION_FILE_NAME"
echo "Copied file to container."

wait_for_ord_sync

# Create Inscription
INSCRIPTION_JSON=$(docker exec -i "$ORD_CONTAINER_NAME" ord \
  --data-dir /index-data \
  --bitcoin-rpc-url "$BITCOIN_RPC_URL" \
  --regtest \
  --bitcoin-rpc-username "$BITCOIN_RPC_USER" \
  --bitcoin-rpc-password "$BITCOIN_RPC_PASS" \
  wallet --server-url "$ORDINAL_SERVER_URL" inscribe --file /"$INSCRIPTION_FILE_NAME" --fee-rate 1)

INSCRIPTION_DESTINATION=$(echo "$INSCRIPTION_JSON" | jq -r '.inscriptions[0].destination')
INSCRIPTION_ID=$(echo "$INSCRIPTION_JSON" | jq -r '.inscriptions[0].id')
INSCRIPTION_LOCATION=$(echo "$INSCRIPTION_JSON" | jq -r '.inscriptions[0].location')

echo "Inscription ID: $INSCRIPTION_ID"

# Mine 1 block to confirm the inscription
docker exec -i "$BITCOIN_NODE_CONTAINER" bitcoin-cli -regtest -rpcuser="$BITCOIN_RPC_USER" -rpcpassword="$BITCOIN_RPC_PASS" \
  generatetoaddress 1 "$ORDINAL_WALLET_ADDRESS" > /dev/null

echo "Mined 1 block."

wait_for_ord_sync

echo "Confirmed inscription."

# Show correct Explorer URL
INSCRIPTION_EXPLORER_URL="http://localhost:$ORDINAL_PORT/inscription/$INSCRIPTION_ID"
echo "Explorer URL: $INSCRIPTION_EXPLORER_URL"

# Use configured destination address or prompt if empty
if [ -z "$DESTINATION_ADDRESS" ]; then
  echo -n "Enter destination address for the inscription: "
  read DESTINATION_ADDRESS
fi

# Send the inscription
SEND_JSON=$(docker exec -i "$ORD_CONTAINER_NAME" ord \
  --data-dir /index-data \
  --regtest \
  --bitcoin-rpc-url "$BITCOIN_RPC_URL" \
  --bitcoin-rpc-username "$BITCOIN_RPC_USER" \
  --bitcoin-rpc-password "$BITCOIN_RPC_PASS" \
  wallet --server-url "$ORDINAL_SERVER_URL" \
  send --fee-rate 1 "$DESTINATION_ADDRESS" "$INSCRIPTION_ID")

INSCRIPTION_TXID=$(echo "$SEND_JSON" | jq -r '.txid')
INSCRIPTION_FEE=$(echo "$SEND_JSON" | jq -r '.fee')

echo "Inscription sent. TXID: $INSCRIPTION_TXID"

# Mine 1 block to confirm the transfer
docker exec -i "$BITCOIN_NODE_CONTAINER" bitcoin-cli -regtest -rpcuser="$BITCOIN_RPC_USER" -rpcpassword="$BITCOIN_RPC_PASS" \
  generatetoaddress 1 "$ORDINAL_WALLET_ADDRESS" > /dev/null

echo "Mined 1 block."

wait_for_ord_sync

echo "Confirmed inscription transfer."

# Extract VOUT from location
INSCRIPTION_VOUT=$(echo "$INSCRIPTION_LOCATION" | cut -d':' -f2)

# Get transaction output details
docker exec -i "$BITCOIN_NODE_CONTAINER" bitcoin-cli -regtest -rpcuser="$BITCOIN_RPC_USER" -rpcpassword="$BITCOIN_RPC_PASS" \
  gettxout "$INSCRIPTION_TXID" "$INSCRIPTION_VOUT"

# Final info
echo "TXID: $INSCRIPTION_TXID"
echo "VOUT: $INSCRIPTION_VOUT"

echo ""
echo "ordinal outpoint: $INSCRIPTION_TXID:$INSCRIPTION_VOUT"
