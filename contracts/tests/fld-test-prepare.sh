
#!/bin/bash
set -xe

tos=tonos-cli

DEBOT_NAME=SubsMan
DEBOT_CLIENT=clientDebot
giver=0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94


function giver {
$tos --url $NETWORK call --abi ../../local_giver.abi.json $giver sendGrams "{\"dest\":\"$1\",\"amount\":2000000000}"
}
function get_address {
echo $(cat log.log | grep "Raw address:" | cut -d ' ' -f 3)
}

function genseed {
$tos genphrase > service.seed
}

function genpubkey {
$tos genpubkey "$1" > $2.pub
}


function genkeypair {
$tos getkeypair service.keys.json "$2"
}

function genaddrservice {
$tos genaddr $1.tvc $1.abi.json --setkey service.keys.json > log.log
}

function genaddr {
$tos genaddr $1.tvc $1.abi.json --setkey $1.keys.json > log.log
}

function deployMsigService {
genseed
seed=`cat service.seed | grep -o '".*"' | tr -d '"'`
echo "Service seed - $seed"
genpubkey "$seed" "service"
pub=`cat service.pub | grep "Public key" | awk '{print $3}'`
echo "Service pubkey - $pub"
genkeypair "service" "$seed"
msig=../SafeMultisigWallet
echo GENADDR $msig ----------------------------------------------
genaddrservice $msig
ADDRESS=$(get_address)
echo GIVER $msig ------------------------------------------------
giver $ADDRESS
echo DEPLOY $msig -----------------------------------------------
PUBLIC_KEY=$(cat service.keys.json | jq .public)
$tos --url $NETWORK deploy $msig.tvc "{\"owners\":[\"0x${PUBLIC_KEY:1:64}\"],\"reqConfirms\":1}" --sign service.keys.json --abi $msig.abi.json
echo -n $ADDRESS > msig.service.addr
}

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

deployMsigService
MSIG_SERVICE_ADDRESS=$(cat msig.service.addr)
tonos-cli config --pubkey 0x$(cat service.keys.json | jq .public -r) --wallet $(cat msig.service.addr)
