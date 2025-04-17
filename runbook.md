# Create an Ordinal inscription and send it

## Create an ordinal wallet

```bash
docker exec -it ord ord \
  --data-dir /index-data \
  --bitcoin-rpc-url http://bitcoin-regtest-node:18443 \
  --regtest \
  --bitcoin-rpc-username foo \
  --bitcoin-rpc-password rpcpassword \
  wallet create
```

## Ask the wallet for an address to receive funds
``` bash
docker exec -it ord ord \
  --data-dir /index-data \
  --bitcoin-rpc-url http://bitcoin-regtest-node:18443 \
  --regtest \
  --bitcoin-rpc-username foo \
  --bitcoin-rpc-password rpcpassword \
  wallet --server-url http://0.0.0.0:8080 receive
```

## Ask bitcoin core to mine 101 blocks and transfer its block rewards (coinbase) to the ordinal wallet address, take in mind that coinbase rewards need tow ait 100 blocks to be spent, that's why we are mining 101 blocks
```bash
docker exec -it bitcoin-regtest-node bitcoin-cli -regtest -rpcuser=foo -rpcpassword="rpcpassword" generatetoaddress 101 <address bcrt1qxyz...>
```

## Copy the file we want to inscript into the container
```bash
docker cp ./hello.txt ord:/hello.txt
```

## Create the inscription
```bash
docker exec -it ord ord \
  --data-dir /index-data \
  --bitcoin-rpc-url http://bitcoin-regtest-node:18443 \
  --regtest \
  --bitcoin-rpc-username foo \
  --bitcoin-rpc-password rpcpassword \
  wallet --server-url http://0.0.0.0:8080 inscribe --file /hello.txt --fee-rate 1
```

## Mine another block to confirm the inscription (let's gift the coinbase to the ordinal wallet address)
```bash
docker exec -it bitcoin-regtest-node bitcoin-cli -regtest -rpcuser=foo -rpcpassword="rpcpassword" generatetoaddress 1 <address bcrt1qxyz...>
```

## lets check the inscriptions
```bash
docker exec -it ord ord \
  --data-dir /index-data \
  --bitcoin-rpc-url http://bitcoin-regtest-node:18443 \
  --regtest \
  --bitcoin-rpc-username foo \
  --bitcoin-rpc-password rpcpassword \
  wallet --server-url http://0.0.0.0:8080 inscriptions
```

## Check the reveal transaction
```
docker exec -it bitcoin-regtest-node bitcoin-cli -regtest -rpcuser=foo -rpcpassword="rpcpassword" getrawtransaction <reveal tx id> true
```

## Browse the inscription
http://localhost:8080/inscription/<inscription id>

## Check the inscription data using the read only JSON API
```bash
curl -H "Accept: application/json" http://localhost:8080/inscription/<inscription id> | jq
```

## Send this inscription to the new owner, in this case the user address
```
docker exec -it ord ord \
  --data-dir /index-data \
  --regtest \
  --bitcoin-rpc-url http://bitcoin-regtest-node:18443 \
  --bitcoin-rpc-username foo \
  --bitcoin-rpc-password rpcpassword \
  wallet --server-url http://0.0.0.0:8080 \
  send --fee-rate 1 <destiny address> <your_inscription_id>
```

## Mine another block to confirm (let's gift the coinbase to the ordinal wallet address)
```bash
docker exec -it bitcoin-regtest-node bitcoin-cli -regtest -rpcuser=foo -rpcpassword="rpcpassword" generatetoaddress 1 <address bcrt1qxyz...>
```


## check the ordinal send transaction
```
docker exec -it bitcoin-regtest-node bitcoin-cli -regtest -rpcuser=foo -rpcpassword="rpcpassword" getrawtransaction <ordinal send txid> true
```

## check the vout, to see the address owner of the ordinal (might be the taptree)
docker exec -it bitcoin-regtest-node bitcoin-cli -regtest -rpcuser=foo -rpcpassword="rpcpassword" gettxout <ordinal send txid> <ordinal send vout>

