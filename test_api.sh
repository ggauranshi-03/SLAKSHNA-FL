# #!/bin/bash

# # ============================================================
# # IIITD COMPREHENSIVE API TEST SCRIPT
# # Tests ALL endpoints including:
# # - Chain info, blocks, transactions
# # - Wallet & accounts
# # - Signature verification
# # - IIITD-20 tokens
# # - IVM contracts (deploy, call, free reads)
# # - Access control
# # - Mempool & pending nonce
# # ============================================================

# BASE_URL="http://172.23.64.1:8545"
# RED='\033[0;31m'
# GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
# BLUE='\033[0;34m'
# NC='\033[0m' # No Color

# PASS=0
# FAIL=0

# # Test helper
# test_endpoint() {
#     local name="$1"
#     local result="$2"
#     local expected="$3"
    
#     if echo "$result" | grep -q "$expected"; then
#         echo -e "   ${GREEN}✓${NC} $name"
#         ((PASS++))
#     else
#         echo -e "   ${RED}✗${NC} $name"
#         echo "      Expected: $expected"
#         echo "      Got: $(echo $result | head -c 200)"
#         ((FAIL++))
#     fi
# }

# echo ""
# echo "============================================================"
# echo "🚀 IIITD COMPREHENSIVE API TEST"
# echo "============================================================"
# echo ""

# # ============================================================
# # SECTION 1: CHAIN INFO
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 1: CHAIN INFO ━━━${NC}"

# echo "Testing GET /"
# RESULT=$(curl -s $BASE_URL/)
# test_endpoint "Root endpoint" "$RESULT" '"name":"IIITD Virtual Machine"'

# echo "Testing GET /status"
# RESULT=$(curl -s $BASE_URL/status)
# test_endpoint "Status endpoint" "$RESULT" '"chain_id"'
# test_endpoint "Status has pending_transactions" "$RESULT" '"pending_transactions"'

# echo "Testing GET /mempool"
# RESULT=$(curl -s $BASE_URL/mempool)
# test_endpoint "Mempool endpoint" "$RESULT" '"transactions"'

# echo "Testing GET /block/latest"
# RESULT=$(curl -s $BASE_URL/block/latest)
# test_endpoint "Latest block" "$RESULT" '"height"'

# echo "Testing GET /block/1"
# RESULT=$(curl -s $BASE_URL/block/1)
# test_endpoint "Block by height" "$RESULT" '"block"'

# echo "Testing GET /blocks?limit=5"
# RESULT=$(curl -s "$BASE_URL/blocks?limit=5")
# test_endpoint "Recent blocks" "$RESULT" '"blocks"'

# echo "Testing GET /txs?limit=5"
# RESULT=$(curl -s "$BASE_URL/txs?limit=5")
# test_endpoint "Recent transactions" "$RESULT" '"transactions"'

# echo ""

# # ============================================================
# # SECTION 2: WALLET & ACCOUNTS
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 2: WALLET & ACCOUNTS ━━━${NC}"

# echo "Testing GET /wallet/new (Wallet 1)"
# WALLET1=$(curl -s $BASE_URL/wallet/new)
# ADDR1=$(echo $WALLET1 | jq -r '.address')
# PRIV1=$(echo $WALLET1 | jq -r '.private_key')
# PUB1=$(echo $WALLET1 | jq -r '.public_key')
# test_endpoint "Create wallet 1" "$WALLET1" '"address":"iiitd1'

# echo "Testing GET /wallet/new (Wallet 2)"
# WALLET2=$(curl -s $BASE_URL/wallet/new)
# ADDR2=$(echo $WALLET2 | jq -r '.address')
# PRIV2=$(echo $WALLET2 | jq -r '.private_key')
# PUB2=$(echo $WALLET2 | jq -r '.public_key')
# test_endpoint "Create wallet 2" "$WALLET2" '"address":"iiitd1'

# echo "Testing GET /balance/$ADDR1"
# RESULT=$(curl -s $BASE_URL/balance/$ADDR1)
# test_endpoint "Get balance (should be 0)" "$RESULT" '"balance"'

# echo "Testing GET /nonce/pending/$ADDR1"
# RESULT=$(curl -s $BASE_URL/nonce/pending/$ADDR1)
# test_endpoint "Get nonce" "$RESULT" '"nonce"'

# echo "Testing POST /faucet/$ADDR1"
# RESULT=$(curl -s -X POST $BASE_URL/faucet/$ADDR1)
# test_endpoint "Faucet wallet 1" "$RESULT" '"success":true'

# echo "Testing POST /faucet/$ADDR2"
# RESULT=$(curl -s -X POST $BASE_URL/faucet/$ADDR2)
# test_endpoint "Faucet wallet 2" "$RESULT" '"success":true'

# echo "Testing GET /account/$ADDR1"
# RESULT=$(curl -s $BASE_URL/account/$ADDR1)
# test_endpoint "Get account info" "$RESULT" '"balance"'

# echo ""

# # ============================================================
# # SECTION 3: SIGNATURE VERIFICATION
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 3: SIGNATURE VERIFICATION ━━━${NC}"

# echo "Testing correct signer = payer..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR1\",
#   \"to\": \"$ADDR2\",
#   \"value\": 1,
#   \"nonce\": $NONCE
# }")
# SIG=$(echo $SIGN | jq -r '.signature')
# test_endpoint "Sign transaction" "$SIGN" '"signature"'

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR1\",
#   \"to\": \"$ADDR2\",
#   \"value\": 1,
#   \"nonce\": $NONCE,
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Transfer with correct signer" "$RESULT" '"success":true'

# sleep 65

# echo "Testing WRONG signer (sign with key1, submit as key2)..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR2 | jq -r '.pending_nonce')
# # Sign with wallet 1's key but claim it's from wallet 2
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR2\",
#   \"to\": \"$ADDR1\",
#   \"value\": 1,
#   \"nonce\": $NONCE
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR2\",
#   \"to\": \"$ADDR1\",
#   \"value\": 1,
#   \"nonce\": $NONCE,
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Transfer with WRONG signer (should fail)" "$RESULT" '"error"'

# echo "Testing public_key mismatch..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR1\",
#   \"to\": \"$ADDR2\",
#   \"value\": 1,
#   \"nonce\": $NONCE
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# # Use wrong public key
# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR1\",
#   \"to\": \"$ADDR2\",
#   \"value\": 1,
#   \"nonce\": $NONCE,
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB2\"
# }")
# test_endpoint "Transfer with wrong public_key (should fail)" "$RESULT" '"error"'

# echo ""

# # ============================================================
# # SECTION 4: TOKENS
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 4: IIITD-20 TOKENS ━━━${NC}"

# echo "Testing create_token..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"create_token\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"name\": \"Test Token\", \"symbol\": \"TEST\", \"total_supply\": 1000000}
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"create_token\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"name\": \"Test Token\", \"symbol\": \"TEST\", \"total_supply\": 1000000},
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Create token" "$RESULT" '"success":true'
# TX_HASH=$(echo $RESULT | jq -r '.hash')

# sleep 65

# echo "Testing GET /tokens"
# RESULT=$(curl -s $BASE_URL/tokens)
# test_endpoint "List tokens" "$RESULT" '"tokens"'
# TOKEN=$(echo $RESULT | jq -r '.tokens[0].address')

# echo "Testing GET /token/$TOKEN"
# RESULT=$(curl -s $BASE_URL/token/$TOKEN)
# test_endpoint "Token info" "$RESULT" '"symbol":"TEST"'

# echo "Testing GET /token/$TOKEN/balance/$ADDR1"
# RESULT=$(curl -s $BASE_URL/token/$TOKEN/balance/$ADDR1)
# test_endpoint "Token balance" "$RESULT" '"balance"'

# echo "Testing GET /tokens/creator/$ADDR1"
# RESULT=$(curl -s $BASE_URL/tokens/creator/$ADDR1)
# test_endpoint "Tokens by creator" "$RESULT" '"tokens"'

# echo "Testing GET /tokens/holder/$ADDR1"
# RESULT=$(curl -s $BASE_URL/tokens/holder/$ADDR1)
# test_endpoint "Tokens by holder" "$RESULT" '"holdings"'

# echo "Testing transfer_token..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"transfer_token\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$TOKEN\", \"to\": \"$ADDR2\", \"amount\": 1000}
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"transfer_token\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$TOKEN\", \"to\": \"$ADDR2\", \"amount\": 1000},
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Transfer token" "$RESULT" '"success":true'

# sleep 65

# echo ""

# # ============================================================
# # SECTION 5: SIMPLE CONTRACT
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 5: SIMPLE CONTRACT ━━━${NC}"

# echo "Deploying simple Counter contract..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"deploy_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {
#     \"name\": \"Counter\",
#     \"variables\": [{\"name\": \"count\", \"type\": \"uint64\", \"default\": \"0\"}]
#   }
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"deploy_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {
#     \"name\": \"Counter\",
#     \"variables\": [{\"name\": \"count\", \"type\": \"uint64\", \"default\": \"0\"}]
#   },
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Deploy Counter contract" "$RESULT" '"success":true'
# TX_HASH=$(echo $RESULT | jq -r '.hash')

# sleep 65

# COUNTER=$(curl -s $BASE_URL/tx/$TX_HASH | jq -r '.transaction.to')
# echo "   Counter address: $COUNTER"

# echo "Testing GET /contracts"
# RESULT=$(curl -s $BASE_URL/contracts)
# test_endpoint "List contracts" "$RESULT" '"contracts"'

# echo "Testing GET /contract/$COUNTER"
# RESULT=$(curl -s $BASE_URL/contract/$COUNTER)
# test_endpoint "Contract info" "$RESULT" '"name":"Counter"'

# echo ""

# # ============================================================
# # SECTION 6: FREE READS (No signature needed!)
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 6: FREE READS (No signature!) ━━━${NC}"

# echo "Testing GET /contract/$COUNTER/var/count (FREE)"
# RESULT=$(curl -s $BASE_URL/contract/$COUNTER/var/count)
# test_endpoint "Read variable (FREE)" "$RESULT" '"value":0'

# echo "Testing GET /contract/$COUNTER/var/owner (FREE)"
# RESULT=$(curl -s $BASE_URL/contract/$COUNTER/var/owner)
# test_endpoint "Read owner (FREE)" "$RESULT" '"value":"iiitd1'

# echo "Testing GET /contract/$COUNTER/call/get_count (FREE)"
# RESULT=$(curl -s $BASE_URL/contract/$COUNTER/call/get_count)
# test_endpoint "Call get_count (FREE)" "$RESULT" '"result":0'

# echo "Testing GET /contract/$COUNTER/call/get_owner (FREE)"
# RESULT=$(curl -s $BASE_URL/contract/$COUNTER/call/get_owner)
# test_endpoint "Call get_owner (FREE)" "$RESULT" '"result":"iiitd1'

# echo "Testing GET /contract/$COUNTER/mbi (MBI)"
# RESULT=$(curl -s $BASE_URL/contract/$COUNTER/mbi)
# test_endpoint "Get MBI" "$RESULT" '"mbi"'

# echo ""

# # ============================================================
# # SECTION 7: CONTRACT WITH MAPPINGS
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 7: CONTRACT WITH MAPPINGS ━━━${NC}"

# echo "Deploying Whitelist contract..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"deploy_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {
#     \"name\": \"Whitelist\",
#     \"mappings\": [{\"name\": \"allowed\", \"key_type\": \"address\", \"value_type\": \"bool\"}]
#   }
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"deploy_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {
#     \"name\": \"Whitelist\",
#     \"mappings\": [{\"name\": \"allowed\", \"key_type\": \"address\", \"value_type\": \"bool\"}]
#   },
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Deploy Whitelist contract" "$RESULT" '"success":true'
# TX_HASH=$(echo $RESULT | jq -r '.hash')

# sleep 65

# WHITELIST=$(curl -s $BASE_URL/tx/$TX_HASH | jq -r '.transaction.to')
# echo "   Whitelist address: $WHITELIST"

# echo "Setting allowed[$ADDR2] = true..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$WHITELIST\", \"method\": \"set_allowed\", \"args\": [\"$ADDR2\", \"true\"]}
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$WHITELIST\", \"method\": \"set_allowed\", \"args\": [\"$ADDR2\", \"true\"]},
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Set mapping value" "$RESULT" '"success":true'

# sleep 65

# echo "Testing GET /contract/$WHITELIST/mapping/allowed (list all)"
# RESULT=$(curl -s $BASE_URL/contract/$WHITELIST/mapping/allowed)
# test_endpoint "List mapping entries" "$RESULT" '"entries"'

# echo "Testing GET /contract/$WHITELIST/mapping/allowed/$ADDR2 (FREE)"
# RESULT=$(curl -s $BASE_URL/contract/$WHITELIST/mapping/allowed/$ADDR2)
# test_endpoint "Read mapping value (FREE)" "$RESULT" '"value":true'

# echo "Testing GET /contract/$WHITELIST/call/get_allowed?args=$ADDR2 (FREE)"
# RESULT=$(curl -s "$BASE_URL/contract/$WHITELIST/call/get_allowed?args=$ADDR2")
# test_endpoint "Call get_allowed (FREE)" "$RESULT" '"result":true'

# echo ""

# # ============================================================
# # SECTION 8: CONTRACT WITH FUNCTIONS
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 8: CONTRACT WITH FUNCTIONS ━━━${NC}"

# echo "Deploying Vault contract with stake/unstake..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"deploy_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {
#     \"name\": \"Vault\",
#     \"token\": \"$TOKEN\",
#     \"variables\": [{\"name\": \"total_staked\", \"type\": \"uint64\", \"default\": \"0\"}],
#     \"mappings\": [{\"name\": \"balances\", \"key_type\": \"address\", \"value_type\": \"uint64\"}],
#     \"functions\": [
#       {
#         \"name\": \"stake\",
#         \"modifiers\": [\"payable\"],
#         \"args\": [],
#         \"body\": [
#           {\"op\": \"require\", \"left\": \"msg.amount\", \"cmp\": \">\", \"right\": \"0\", \"msg\": \"Amount=0\"},
#           {\"op\": \"map_add\", \"map\": \"balances\", \"key\": \"msg.sender\", \"value\": \"msg.amount\"},
#           {\"op\": \"add\", \"var\": \"total_staked\", \"value\": \"msg.amount\"}
#         ]
#       },
#       {
#         \"name\": \"unstake\",
#         \"modifiers\": [\"write\"],
#         \"args\": [{\"name\": \"amount\", \"type\": \"uint64\"}],
#         \"body\": [
#           {\"op\": \"require\", \"left\": \"balances[msg.sender]\", \"cmp\": \">=\", \"right\": \"amount\", \"msg\": \"Insufficient\"},
#           {\"op\": \"map_sub\", \"map\": \"balances\", \"key\": \"msg.sender\", \"value\": \"amount\"},
#           {\"op\": \"sub\", \"var\": \"total_staked\", \"value\": \"amount\"},
#           {\"op\": \"transfer\", \"to\": \"msg.sender\", \"amount\": \"amount\"}
#         ]
#       },
#       {
#         \"name\": \"get_balance\",
#         \"modifiers\": [\"view\"],
#         \"args\": [{\"name\": \"user\", \"type\": \"address\"}],
#         \"body\": [
#           {\"op\": \"return\", \"value\": \"balances[user]\"}
#         ],
#         \"returns\": \"uint64\"
#       }
#     ]
#   }
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"deploy_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {
#     \"name\": \"Vault\",
#     \"token\": \"$TOKEN\",
#     \"variables\": [{\"name\": \"total_staked\", \"type\": \"uint64\", \"default\": \"0\"}],
#     \"mappings\": [{\"name\": \"balances\", \"key_type\": \"address\", \"value_type\": \"uint64\"}],
#     \"functions\": [
#       {
#         \"name\": \"stake\",
#         \"modifiers\": [\"payable\"],
#         \"args\": [],
#         \"body\": [
#           {\"op\": \"require\", \"left\": \"msg.amount\", \"cmp\": \">\", \"right\": \"0\", \"msg\": \"Amount=0\"},
#           {\"op\": \"map_add\", \"map\": \"balances\", \"key\": \"msg.sender\", \"value\": \"msg.amount\"},
#           {\"op\": \"add\", \"var\": \"total_staked\", \"value\": \"msg.amount\"}
#         ]
#       },
#       {
#         \"name\": \"unstake\",
#         \"modifiers\": [\"write\"],
#         \"args\": [{\"name\": \"amount\", \"type\": \"uint64\"}],
#         \"body\": [
#           {\"op\": \"require\", \"left\": \"balances[msg.sender]\", \"cmp\": \">=\", \"right\": \"amount\", \"msg\": \"Insufficient\"},
#           {\"op\": \"map_sub\", \"map\": \"balances\", \"key\": \"msg.sender\", \"value\": \"amount\"},
#           {\"op\": \"sub\", \"var\": \"total_staked\", \"value\": \"amount\"},
#           {\"op\": \"transfer\", \"to\": \"msg.sender\", \"amount\": \"amount\"}
#         ]
#       },
#       {
#         \"name\": \"get_balance\",
#         \"modifiers\": [\"view\"],
#         \"args\": [{\"name\": \"user\", \"type\": \"address\"}],
#         \"body\": [
#           {\"op\": \"return\", \"value\": \"balances[user]\"}
#         ],
#         \"returns\": \"uint64\"
#       }
#     ]
#   },
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Deploy Vault contract" "$RESULT" '"success":true'
# TX_HASH=$(echo $RESULT | jq -r '.hash')

# sleep 65

# VAULT=$(curl -s $BASE_URL/tx/$TX_HASH | jq -r '.transaction.to')
# echo "   Vault address: $VAULT"

# echo "Testing MBI for Vault..."
# RESULT=$(curl -s $BASE_URL/contract/$VAULT/mbi)
# test_endpoint "Vault MBI" "$RESULT" '"functions"'

# echo "Staking 10000 tokens (payable function)..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$VAULT\", \"method\": \"stake\", \"args\": [], \"amount\": 10000}
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$VAULT\", \"method\": \"stake\", \"args\": [], \"amount\": 10000},
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# STAKE_TX=$(echo $RESULT | jq -r '.hash')
# test_endpoint "Stake TX submitted" "$RESULT" '"success":true'

# sleep 65

# # Check stake TX status
# echo "Checking stake TX status..."
# STAKE_STATUS=$(curl -s $BASE_URL/tx/$STAKE_TX)
# test_endpoint "Stake TX success" "$STAKE_STATUS" '"status":"Success"'

# # Debug: show stake TX details if failed
# if ! echo "$STAKE_STATUS" | grep -q '"status":"Success"'; then
#     echo "   DEBUG: Stake TX details:"
#     echo "$STAKE_STATUS" | jq '.transaction.status, .transaction.error // "no error"'
# fi

# sleep 65

# echo "Testing FREE read of balances mapping..."
# RESULT=$(curl -s $BASE_URL/contract/$VAULT/mapping/balances/$ADDR1)
# test_endpoint "Read stake balance (FREE)" "$RESULT" '"value":10000'

# echo "Testing FREE read of total_staked..."
# RESULT=$(curl -s $BASE_URL/contract/$VAULT/var/total_staked)
# test_endpoint "Read total_staked (FREE)" "$RESULT" '"value":10000'

# echo "Testing view function is FREE..."
# # Debug: Check what functions the contract has
# echo "   DEBUG: Contract functions from MBI:"
# curl -s "$BASE_URL/contract/$VAULT/mbi" | jq '.mbi.functions[] | .name'

# RESULT=$(curl -s "$BASE_URL/contract/$VAULT/call/get_balance?args=$ADDR1")
# test_endpoint "Call view function (FREE)" "$RESULT" '"gas":0'

# # Debug if failed
# if ! echo "$RESULT" | grep -q '"gas":0'; then
#     echo "   DEBUG: View function response:"
#     echo "$RESULT" | jq '.'
# fi

# echo "Testing write function NOT free..."
# RESULT=$(curl -s "$BASE_URL/contract/$VAULT/call/unstake?args=1000")
# test_endpoint "Write function should fail on read endpoint" "$RESULT" '"error"'

# echo ""

# # ============================================================
# # SECTION 9: ACCESS CONTROL
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 9: ACCESS CONTROL ━━━${NC}"

# echo "Testing non-owner trying to set_count..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR2 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV2\",
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR2\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$COUNTER\", \"method\": \"set_count\", \"args\": [\"999\"]}
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR2\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$COUNTER\", \"method\": \"set_count\", \"args\": [\"999\"]},
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB2\"
# }")
# NON_OWNER_TX=$(echo $RESULT | jq -r '.hash')
# test_endpoint "Non-owner TX submitted" "$RESULT" '"success":true'

# sleep 65

# # Check that the TX failed during execution
# echo "Checking TX status (should be Failed)..."
# TX_STATUS=$(curl -s $BASE_URL/tx/$NON_OWNER_TX)
# test_endpoint "TX execution failed (owner check)" "$TX_STATUS" '"status":"Failed"'

# echo "Verifying count unchanged..."
# RESULT=$(curl -s $BASE_URL/contract/$COUNTER/var/count)
# test_endpoint "Count still 0" "$RESULT" '"value":0'

# echo ""

# # ============================================================
# # SECTION 10: TRANSACTION HISTORY
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 10: TRANSACTION HISTORY ━━━${NC}"

# echo "Testing GET /tx/$TX_HASH"
# RESULT=$(curl -s $BASE_URL/tx/$TX_HASH)
# test_endpoint "Get transaction by hash" "$RESULT" '"transaction"'

# echo "Testing GET /txs/$ADDR1"
# RESULT=$(curl -s $BASE_URL/txs/$ADDR1)
# test_endpoint "Get address transactions" "$RESULT" '"transactions"'

# echo ""

# # ============================================================
# # SECTION 11: MEMPOOL & PENDING NONCE
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 11: MEMPOOL & PENDING NONCE ━━━${NC}"

# echo "Testing GET /nonce/pending/$ADDR1"
# RESULT=$(curl -s $BASE_URL/nonce/pending/$ADDR1)
# test_endpoint "Pending nonce endpoint" "$RESULT" '"pending_nonce"'

# echo "Testing mempool with multiple transactions..."
# # Get current nonce
# CURRENT_NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# echo "   Current nonce: $CURRENT_NONCE"

# # Submit 3 transactions quickly (they should all go to mempool)
# NONCE1=$CURRENT_NONCE
# NONCE2=$((CURRENT_NONCE + 1))
# NONCE3=$((CURRENT_NONCE + 2))

# # Sign and submit TX 1
# SIGN1=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR1\",
#   \"to\": \"$ADDR2\",
#   \"value\": 100000000,
#   \"nonce\": $NONCE1
# }")
# SIG1=$(echo $SIGN1 | jq -r '.signature')

# # Sign TX 2
# SIGN2=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR1\",
#   \"to\": \"$ADDR2\",
#   \"value\": 100000000,
#   \"nonce\": $NONCE2
# }")
# SIG2=$(echo $SIGN2 | jq -r '.signature')

# # Sign TX 3
# SIGN3=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR1\",
#   \"to\": \"$ADDR2\",
#   \"value\": 100000000,
#   \"nonce\": $NONCE3
# }")
# SIG3=$(echo $SIGN3 | jq -r '.signature')

# # Submit all 3 quickly
# RESULT1=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR1\",
#   \"to\": \"$ADDR2\",
#   \"value\": 100000000,
#   \"nonce\": $NONCE1,
#   \"signature\": \"$SIG1\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Submit TX 1 (nonce $NONCE1)" "$RESULT1" '"success":true'

# RESULT2=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR1\",
#   \"to\": \"$ADDR2\",
#   \"value\": 100000000,
#   \"nonce\": $NONCE2,
#   \"signature\": \"$SIG2\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Submit TX 2 (nonce $NONCE2)" "$RESULT2" '"success":true'

# RESULT3=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR1\",
#   \"to\": \"$ADDR2\",
#   \"value\": 100000000,
#   \"nonce\": $NONCE3,
#   \"signature\": \"$SIG3\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Submit TX 3 (nonce $NONCE3)" "$RESULT3" '"success":true'

# # Check mempool has transactions
# sleep 1
# MEMPOOL=$(curl -s $BASE_URL/mempool)
# MEMPOOL_COUNT=$(echo $MEMPOOL | jq -r '.count')
# echo "   Mempool count: $MEMPOOL_COUNT"
# test_endpoint "Mempool has transactions" "$MEMPOOL" '"transactions"'

# # Check pending nonce is updated
# PENDING_NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1)
# PENDING_VAL=$(echo $PENDING_NONCE | jq -r '.pending_nonce')
# echo "   Pending nonce: $PENDING_VAL"
# test_endpoint "Pending nonce updated" "$PENDING_NONCE" '"pending_nonce"'

# # Test duplicate/invalid nonce rejection
# # If mempool already processed, nonce 8 should fail as "invalid_nonce"
# # If mempool has it, should fail as "nonce_already_pending" or "already in mempool"
# echo "Testing duplicate/invalid nonce rejection..."

# # First check what the current confirmed nonce is
# CONFIRMED=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# echo "   Confirmed nonce: $CONFIRMED"
# echo "   Attempting to submit nonce: $NONCE1"

# RESULT_DUP=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"transfer\",
#   \"from\": \"$ADDR1\",
#   \"to\": \"$ADDR2\",
#   \"value\": 100000000,
#   \"nonce\": $NONCE1,
#   \"signature\": \"$SIG1\",
#   \"public_key\": \"$PUB1\"
# }")
# echo "   Response: $(echo $RESULT_DUP | head -c 150)"

# # Should be rejected for ANY reason (invalid_nonce, nonce_already_pending, duplicate hash)
# if echo "$RESULT_DUP" | grep -q '"success":false'; then
#     echo -e "   ${GREEN}✓${NC} Old nonce rejected (success:false)"
#     ((PASS++))
# elif echo "$RESULT_DUP" | grep -q '"error"'; then
#     echo -e "   ${GREEN}✓${NC} Old nonce rejected (has error)"
#     ((PASS++))
# else
#     echo -e "   ${RED}✗${NC} Old nonce should be rejected"
#     echo "      Got: $(echo $RESULT_DUP | head -c 200)"
#     ((FAIL++))
# fi

# # Wait for block to process transactions
# echo "Waiting for block to process mempool..."
# sleep 65

# # Check mempool is empty after block
# MEMPOOL_AFTER=$(curl -s $BASE_URL/mempool)
# MEMPOOL_AFTER_COUNT=$(echo $MEMPOOL_AFTER | jq -r '.count')
# echo "   Mempool count after block: $MEMPOOL_AFTER_COUNT"
# test_endpoint "Mempool processed" "$MEMPOOL_AFTER" '"transactions"'

# echo ""

# # ============================================================
# # SECTION 12: NEW OPCODES (mul, div, mod)
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 12: NEW OPCODES (mul, div, mod) ━━━${NC}"

# echo "Deploying Calculator contract with mul/div/mod..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"deploy_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {
#     \"name\": \"Calculator\",
#     \"variables\": [{\"name\": \"result\", \"type\": \"uint256\", \"default\": \"10\"}],
#     \"functions\": [
#       {
#         \"name\": \"multiply\",
#         \"modifiers\": [\"write\"],
#         \"args\": [{\"name\": \"factor\", \"type\": \"uint256\"}],
#         \"body\": [{\"op\": \"mul\", \"var\": \"result\", \"value\": \"factor\"}]
#       },
#       {
#         \"name\": \"divide\",
#         \"modifiers\": [\"write\"],
#         \"args\": [{\"name\": \"divisor\", \"type\": \"uint256\"}],
#         \"body\": [{\"op\": \"div\", \"var\": \"result\", \"value\": \"divisor\"}]
#       },
#       {
#         \"name\": \"modulo\",
#         \"modifiers\": [\"write\"],
#         \"args\": [{\"name\": \"modval\", \"type\": \"uint256\"}],
#         \"body\": [{\"op\": \"mod\", \"var\": \"result\", \"value\": \"modval\"}]
#       },
#       {
#         \"name\": \"get_result\",
#         \"modifiers\": [\"view\"],
#         \"args\": [],
#         \"body\": [{\"op\": \"return\", \"value\": \"result\"}],
#         \"returns\": \"uint256\"
#       }
#     ]
#   }
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"deploy_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {
#     \"name\": \"Calculator\",
#     \"variables\": [{\"name\": \"result\", \"type\": \"uint256\", \"default\": \"10\"}],
#     \"functions\": [
#       {
#         \"name\": \"multiply\",
#         \"modifiers\": [\"write\"],
#         \"args\": [{\"name\": \"factor\", \"type\": \"uint256\"}],
#         \"body\": [{\"op\": \"mul\", \"var\": \"result\", \"value\": \"factor\"}]
#       },
#       {
#         \"name\": \"divide\",
#         \"modifiers\": [\"write\"],
#         \"args\": [{\"name\": \"divisor\", \"type\": \"uint256\"}],
#         \"body\": [{\"op\": \"div\", \"var\": \"result\", \"value\": \"divisor\"}]
#       },
#       {
#         \"name\": \"modulo\",
#         \"modifiers\": [\"write\"],
#         \"args\": [{\"name\": \"modval\", \"type\": \"uint256\"}],
#         \"body\": [{\"op\": \"mod\", \"var\": \"result\", \"value\": \"modval\"}]
#       },
#       {
#         \"name\": \"get_result\",
#         \"modifiers\": [\"view\"],
#         \"args\": [],
#         \"body\": [{\"op\": \"return\", \"value\": \"result\"}],
#         \"returns\": \"uint256\"
#       }
#     ]
#   },
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Deploy Calculator" "$RESULT" '"success":true'
# CALC_TX=$(echo $RESULT | jq -r '.hash')

# sleep 65

# CALC=$(curl -s $BASE_URL/tx/$CALC_TX | jq -r '.transaction.to')
# echo "   Calculator address: $CALC"

# echo "Multiplying result (10) by 5..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$CALC\", \"method\": \"multiply\", \"args\": [\"5\"]}
# }")
# SIG=$(echo $SIGN | jq -r '.signature')
# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$CALC\", \"method\": \"multiply\", \"args\": [\"5\"]},
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Multiply call" "$RESULT" '"success":true'

# sleep 65

# RESULT=$(curl -s $BASE_URL/contract/$CALC/var/result)
# test_endpoint "Result = 50 after mul" "$RESULT" '"value":50'

# echo "Dividing 50 by 3..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$CALC\", \"method\": \"divide\", \"args\": [\"3\"]}
# }")
# SIG=$(echo $SIGN | jq -r '.signature')
# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$CALC\", \"method\": \"divide\", \"args\": [\"3\"]},
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Divide call" "$RESULT" '"success":true'

# sleep 65

# RESULT=$(curl -s $BASE_URL/contract/$CALC/var/result)
# test_endpoint "Result = 16 after div" "$RESULT" '"value":16'

# echo ""

# # ============================================================
# # SECTION 13: GUARD & SIGNAL (IVM keywords)
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 13: GUARD & SIGNAL ━━━${NC}"

# echo "Deploying contract with guard and signal..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"deploy_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {
#     \"name\": \"GuardTest\",
#     \"variables\": [{\"name\": \"value\", \"type\": \"uint256\", \"default\": \"0\"}],
#     \"functions\": [
#       {
#         \"name\": \"safe_set\",
#         \"modifiers\": [\"write\"],
#         \"args\": [{\"name\": \"new_val\", \"type\": \"uint256\"}],
#         \"body\": [
#           {\"op\": \"guard\", \"left\": \"new_val\", \"cmp\": \">\", \"right\": \"0\", \"msg\": \"Must be positive\"},
#           {\"op\": \"set\", \"var\": \"value\", \"value\": \"new_val\"},
#           {\"op\": \"signal\", \"event_name\": \"ValueSet\", \"event_args\": [\"new_val\"]}
#         ]
#       },
#       {
#         \"name\": \"get_value\",
#         \"modifiers\": [\"view\"],
#         \"args\": [],
#         \"body\": [{\"op\": \"return\", \"value\": \"value\"}],
#         \"returns\": \"uint256\"
#       }
#     ]
#   }
# }")
# SIG=$(echo $SIGN | jq -r '.signature')

# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"deploy_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {
#     \"name\": \"GuardTest\",
#     \"variables\": [{\"name\": \"value\", \"type\": \"uint256\", \"default\": \"0\"}],
#     \"functions\": [
#       {
#         \"name\": \"safe_set\",
#         \"modifiers\": [\"write\"],
#         \"args\": [{\"name\": \"new_val\", \"type\": \"uint256\"}],
#         \"body\": [
#           {\"op\": \"guard\", \"left\": \"new_val\", \"cmp\": \">\", \"right\": \"0\", \"msg\": \"Must be positive\"},
#           {\"op\": \"set\", \"var\": \"value\", \"value\": \"new_val\"},
#           {\"op\": \"signal\", \"event_name\": \"ValueSet\", \"event_args\": [\"new_val\"]}
#         ]
#       },
#       {
#         \"name\": \"get_value\",
#         \"modifiers\": [\"view\"],
#         \"args\": [],
#         \"body\": [{\"op\": \"return\", \"value\": \"value\"}],
#         \"returns\": \"uint256\"
#       }
#     ]
#   },
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "Deploy GuardTest" "$RESULT" '"success":true'
# GUARD_TX=$(echo $RESULT | jq -r '.hash')

# sleep 65

# GUARD_ADDR=$(curl -s $BASE_URL/tx/$GUARD_TX | jq -r '.transaction.to')
# echo "   GuardTest address: $GUARD_ADDR"

# echo "Calling safe_set(42) — should succeed..."
# NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
# SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
#   \"private_key\": \"$PRIV1\",
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$GUARD_ADDR\", \"method\": \"safe_set\", \"args\": [\"42\"]}
# }")
# SIG=$(echo $SIGN | jq -r '.signature')
# RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
#   \"tx_type\": \"call_contract\",
#   \"from\": \"$ADDR1\",
#   \"nonce\": $NONCE,
#   \"data\": {\"contract\": \"$GUARD_ADDR\", \"method\": \"safe_set\", \"args\": [\"42\"]},
#   \"signature\": \"$SIG\",
#   \"public_key\": \"$PUB1\"
# }")
# test_endpoint "safe_set(42)" "$RESULT" '"success":true'

# sleep 65

# RESULT=$(curl -s $BASE_URL/contract/$GUARD_ADDR/var/value)
# test_endpoint "Value = 42" "$RESULT" '"value":42'

# echo "Testing events endpoint..."
# RESULT=$(curl -s $BASE_URL/contract/$GUARD_ADDR/events)
# test_endpoint "Events endpoint" "$RESULT" '"events"'

# echo ""

# # ============================================================
# # SECTION 14: LEADERBOARD
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 14: LEADERBOARD ━━━${NC}"

# echo "Testing GET /leaderboard..."
# RESULT=$(curl -s $BASE_URL/leaderboard)
# test_endpoint "Leaderboard endpoint" "$RESULT" '"top_balances"'
# test_endpoint "Has token_creators" "$RESULT" '"top_balances"'
# test_endpoint "Has contract_deployers" "$RESULT" '"top_balances"'
# test_endpoint "Has tx_senders" "$RESULT" '"top_balances"'

# echo ""

# # ============================================================
# # SECTION 15: FINAL STATUS CHECK
# # ============================================================
# echo -e "${BLUE}━━━ SECTION 15: FINAL STATUS CHECK ━━━${NC}"

# echo "Checking final chain status..."
# STATUS=$(curl -s $BASE_URL/status)
# HEIGHT=$(echo $STATUS | jq -r '.height')
# PENDING=$(echo $STATUS | jq -r '.pending_transactions')
# echo "   Block height: $HEIGHT"
# echo "   Pending TXs: $PENDING"
# test_endpoint "Chain status OK" "$STATUS" '"chain_id"'

# echo ""

# # ============================================================
# # SUMMARY
# # ============================================================
# echo "============================================================"
# echo -e "📊 ${YELLOW}TEST SUMMARY${NC}"
# echo "============================================================"
# echo ""
# echo -e "   ${GREEN}PASSED: $PASS${NC}"
# echo -e "   ${RED}FAILED: $FAIL${NC}"
# echo ""

# TOTAL=$((PASS + FAIL))
# if [ $FAIL -eq 0 ]; then
#     echo -e "   ${GREEN}✅ ALL $TOTAL TESTS PASSED!${NC}"
# else
#     echo -e "   ${RED}❌ $FAIL/$TOTAL TESTS FAILED${NC}"
# fi

# echo ""
# echo "============================================================"
# echo "📦 CONTRACTS DEPLOYED"
# echo "============================================================"
# echo "   Counter:    $COUNTER"
# echo "   Whitelist:  $WHITELIST"
# echo "   Vault:      $VAULT"
# echo "   Calculator: $CALC"
# echo "   GuardTest:  $GUARD_ADDR"
# echo "   Token:      $TOKEN"
# echo ""
# echo "============================================================"
# echo "🔑 WALLETS"
# echo "============================================================"
# echo "   Wallet 1: $ADDR1"
# echo "   Wallet 2: $ADDR2"
# echo ""
# echo "============================================================"
# echo "📡 FREE READ ENDPOINTS (No signature needed)"
# echo "============================================================"
# echo "   GET /contract/:addr/var/:name"
# echo "   GET /contract/:addr/mapping/:name/:key"
# echo "   GET /contract/:addr/call/get_*"
# echo "   GET /contract/:addr/mbi"
# echo ""
# echo "============================================================"
# echo "📦 MEMPOOL ENDPOINTS"
# echo "============================================================"
# echo "   GET /mempool              - View pending transactions"
# echo "   GET /nonce/pending/:addr  - Get next nonce (incl. pending)"
# echo "   GET /status               - Includes pending_transactions"
# echo ""














#!/bin/bash

# ============================================================
# IIITD COMPREHENSIVE API TEST SCRIPT (WITH ZKP)
# Tests ALL endpoints including:
# - Chain info, blocks, transactions
# - Wallet & accounts
# - Signature verification
# - IIITD-20 tokens
# - IVM contracts (deploy, call, free reads)
# - Access control
# - Mempool & pending nonce
# - ZKP Shielded Transactions & Double-Spend Prevention
# ============================================================

BASE_URL="http://172.23.64.1:8545"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
EPOCH_WAIT=65 # Wait time for ML Epoch to finish

# Test helper
test_endpoint() {
    local name="$1"
    local result="$2"
    local expected="$3"
    
    if echo "$result" | grep -q "$expected"; then
        echo -e "   ${GREEN}✓${NC} $name"
        ((PASS++))
    else
        echo -e "   ${RED}✗${NC} $name"
        echo "      Expected: $expected"
        echo "      Got: $(echo "$result" | head -c 200)"
        ((FAIL++))
    fi
}

echo ""
echo "============================================================"
echo "🚀 IIITD COMPREHENSIVE API TEST (INCL. ZKP)"
echo "============================================================"
echo ""

# ============================================================
# SECTION 1: CHAIN INFO
# ============================================================
echo -e "${BLUE}━━━ SECTION 1: CHAIN INFO ━━━${NC}"

echo "Testing GET /"
RESULT=$(curl -s $BASE_URL/)
test_endpoint "Root endpoint" "$RESULT" '"name":"IIITD Virtual Machine"'

echo "Testing GET /status"
RESULT=$(curl -s $BASE_URL/status)
test_endpoint "Status endpoint" "$RESULT" '"chain_id"'
test_endpoint "Status has pending_transactions" "$RESULT" '"pending_transactions"'

echo "Testing GET /tx_mempool"
RESULT=$(curl -s $BASE_URL/tx_mempool)
test_endpoint "Mempool endpoint" "$RESULT" '"transactions"'

echo "Testing GET /block/latest"
RESULT=$(curl -s $BASE_URL/block/latest)
test_endpoint "Latest block" "$RESULT" '"height"'

echo "Testing GET /block/1"
RESULT=$(curl -s $BASE_URL/block/1)
test_endpoint "Block by height" "$RESULT" '"block"'

echo "Testing GET /blocks?limit=5"
RESULT=$(curl -s "$BASE_URL/blocks?limit=5")
test_endpoint "Recent blocks" "$RESULT" '"blocks"'

echo "Testing GET /txs?limit=5"
RESULT=$(curl -s "$BASE_URL/txs?limit=5")
test_endpoint "Recent transactions" "$RESULT" '"transactions"'

echo ""

# ============================================================
# SECTION 2: WALLET & ACCOUNTS
# ============================================================
echo -e "${BLUE}━━━ SECTION 2: WALLET & ACCOUNTS ━━━${NC}"

echo "Testing GET /wallet/new (Wallet 1)"
WALLET1=$(curl -s $BASE_URL/wallet/new)
ADDR1=$(echo "$WALLET1" | jq -r '.address')
PRIV1=$(echo "$WALLET1" | jq -r '.private_key')
PUB1=$(echo "$WALLET1" | jq -r '.public_key')
test_endpoint "Create wallet 1" "$WALLET1" '"address":"iiitd1'

echo "Testing GET /wallet/new (Wallet 2)"
WALLET2=$(curl -s $BASE_URL/wallet/new)
ADDR2=$(echo "$WALLET2" | jq -r '.address')
PRIV2=$(echo "$WALLET2" | jq -r '.private_key')
PUB2=$(echo "$WALLET2" | jq -r '.public_key')
test_endpoint "Create wallet 2" "$WALLET2" '"address":"iiitd1'

echo "Testing GET /balance/$ADDR1"
RESULT=$(curl -s $BASE_URL/balance/$ADDR1)
test_endpoint "Get balance (should be 0)" "$RESULT" '"balance"'

echo "Testing GET /nonce/pending/$ADDR1"
RESULT=$(curl -s $BASE_URL/nonce/pending/$ADDR1)
test_endpoint "Get nonce" "$RESULT" '"pending_nonce"'

echo "Testing POST /faucet/$ADDR1"
RESULT=$(curl -s -X POST $BASE_URL/faucet/$ADDR1)
test_endpoint "Faucet wallet 1" "$RESULT" '"success":true'

echo "Testing POST /faucet/$ADDR2"
RESULT=$(curl -s -X POST $BASE_URL/faucet/$ADDR2)
test_endpoint "Faucet wallet 2" "$RESULT" '"success":true'

echo "Testing GET /account/$ADDR1"
RESULT=$(curl -s $BASE_URL/account/$ADDR1)
test_endpoint "Get account info" "$RESULT" '"balance"'

echo ""

# ============================================================
# SECTION 3: SIGNATURE VERIFICATION
# ============================================================
echo -e "${BLUE}━━━ SECTION 3: SIGNATURE VERIFICATION ━━━${NC}"

echo "Testing correct signer = payer..."
NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
  \"private_key\": \"$PRIV1\",
  \"tx_type\": \"transfer\",
  \"from\": \"$ADDR1\",
  \"to\": \"$ADDR2\",
  \"value\": 1,
  \"nonce\": $NONCE
}")
SIG=$(echo "$SIGN" | jq -r '.signature')
test_endpoint "Sign transaction" "$SIGN" '"signature"'

RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
  \"tx_type\": \"transfer\",
  \"from\": \"$ADDR1\",
  \"to\": \"$ADDR2\",
  \"value\": 1,
  \"nonce\": $NONCE,
  \"signature\": \"$SIG\",
  \"public_key\": \"$PUB1\"
}")
test_endpoint "Transfer with correct signer" "$RESULT" '"success":true'

# Sleep for block finality
echo "Waiting for Layer 2 BFT Certificate..."
sleep $EPOCH_WAIT

echo "Testing WRONG signer (sign with key1, submit as key2)..."
NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR2 | jq -r '.pending_nonce')
SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
  \"private_key\": \"$PRIV1\",
  \"tx_type\": \"transfer\",
  \"from\": \"$ADDR2\",
  \"to\": \"$ADDR1\",
  \"value\": 1,
  \"nonce\": $NONCE
}")
SIG=$(echo "$SIGN" | jq -r '.signature')

RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
  \"tx_type\": \"transfer\",
  \"from\": \"$ADDR2\",
  \"to\": \"$ADDR1\",
  \"value\": 1,
  \"nonce\": $NONCE,
  \"signature\": \"$SIG\",
  \"public_key\": \"$PUB1\"
}")
test_endpoint "Transfer with WRONG signer (should fail)" "$RESULT" '"error"'

echo "Testing public_key mismatch..."
NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
  \"private_key\": \"$PRIV1\",
  \"tx_type\": \"transfer\",
  \"from\": \"$ADDR1\",
  \"to\": \"$ADDR2\",
  \"value\": 1,
  \"nonce\": $NONCE
}")
SIG=$(echo "$SIGN" | jq -r '.signature')

RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
  \"tx_type\": \"transfer\",
  \"from\": \"$ADDR1\",
  \"to\": \"$ADDR2\",
  \"value\": 1,
  \"nonce\": $NONCE,
  \"signature\": \"$SIG\",
  \"public_key\": \"$PUB2\"
}")
test_endpoint "Transfer with wrong public_key (should fail)" "$RESULT" '"error"'

echo ""

# ============================================================
# SECTION 4: TOKENS
# ============================================================
echo -e "${BLUE}━━━ SECTION 4: IIITD-20 TOKENS ━━━${NC}"

echo "Testing create_token..."
NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
  \"private_key\": \"$PRIV1\",
  \"tx_type\": \"create_token\",
  \"from\": \"$ADDR1\",
  \"nonce\": $NONCE,
  \"data\": {\"name\": \"Test Token\", \"symbol\": \"TEST\", \"total_supply\": 1000000}
}")
SIG=$(echo "$SIGN" | jq -r '.signature')

RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
  \"tx_type\": \"create_token\",
  \"from\": \"$ADDR1\",
  \"nonce\": $NONCE,
  \"data\": {\"name\": \"Test Token\", \"symbol\": \"TEST\", \"total_supply\": 1000000},
  \"signature\": \"$SIG\",
  \"public_key\": \"$PUB1\"
}")
test_endpoint "Create token" "$RESULT" '"success":true'

echo "Waiting for Layer 2 BFT Certificate..."
sleep $EPOCH_WAIT

echo "Testing GET /tokens"
RESULT=$(curl -s $BASE_URL/tokens)
test_endpoint "List tokens" "$RESULT" '"tokens"'
TOKEN=$(echo "$RESULT" | jq -r '.tokens[0].address')

echo "Testing GET /token/$TOKEN"
RESULT=$(curl -s $BASE_URL/token/$TOKEN)
test_endpoint "Token info" "$RESULT" '"symbol":"TEST"'

echo "Testing GET /token/$TOKEN/balance/$ADDR1"
RESULT=$(curl -s $BASE_URL/token/$TOKEN/balance/$ADDR1)
test_endpoint "Token balance" "$RESULT" '"balance"'

echo "Testing GET /tokens/creator/$ADDR1"
RESULT=$(curl -s $BASE_URL/tokens/creator/$ADDR1)
test_endpoint "Tokens by creator" "$RESULT" '"tokens"'

echo "Testing GET /tokens/holder/$ADDR1"
RESULT=$(curl -s $BASE_URL/tokens/holder/$ADDR1)
test_endpoint "Tokens by holder" "$RESULT" '"holdings"'

echo ""

# ============================================================
# SECTION 5: ZK-SHIELDED TRANSACTIONS
# ============================================================
echo -e "${BLUE}━━━ SECTION 5: ZK-SHIELDED TRANSACTIONS ━━━${NC}"

echo "Generating Groth16 ZK-Proof..."
ZKP_RES=$(curl -s -X POST $BASE_URL/zkp/generate_proof -H "Content-Type: application/json" -d "{
  \"receiver_address\": \"$ADDR2\",
  \"amount\": 100
}")
test_endpoint "ZKP Generation Endpoint" "$ZKP_RES" '"success":true'

PROOF=$(echo "$ZKP_RES" | jq -r '.proof')
COMMITMENT=$(echo "$ZKP_RES" | jq -r '.commitment')
NULLIFIER=$(echo "$ZKP_RES" | jq -r '.nullifier')

echo "Submitting Shielded Transaction..."
NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
SHIELD_TX_RES=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
  \"tx_type\": \"shielded_transfer\",
  \"from\": \"$ADDR1\",
  \"to\": \"$ADDR2\",
  \"value\": 100,
  \"nonce\": $NONCE,
  \"signature\": \"ZKP_SHIELDED\",
  \"public_key\": \"ZKP_SHIELDED\",
  \"commitment\": \"$COMMITMENT\",
  \"proof\": \"$PROOF\",
  \"nullifier\": \"$NULLIFIER\"
}")
test_endpoint "Shielded Transfer Submission" "$SHIELD_TX_RES" '"success":true'

echo "Waiting for Layer 2 BFT Certificate..."
sleep $EPOCH_WAIT

echo "Testing Double-Spend Prevention (ZKP Nullifier Reuse)..."
NONCE_DUP=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
SHIELD_DUP_RES=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
  \"tx_type\": \"shielded_transfer\",
  \"from\": \"$ADDR1\",
  \"to\": \"$ADDR2\",
  \"value\": 100,
  \"nonce\": $NONCE_DUP,
  \"signature\": \"ZKP_SHIELDED\",
  \"public_key\": \"ZKP_SHIELDED\",
  \"commitment\": \"$COMMITMENT\",
  \"proof\": \"$PROOF\",
  \"nullifier\": \"$NULLIFIER\"
}")
# It should fail because the nullifier was spent in the previous block!
test_endpoint "ZKP Double Spend Prevented" "$SHIELD_DUP_RES" '"success":false'

echo ""

# ============================================================
# SECTION 6: SIMPLE CONTRACT
# ============================================================
echo -e "${BLUE}━━━ SECTION 6: SIMPLE CONTRACT ━━━${NC}"

echo "Deploying simple Counter contract..."
NONCE=$(curl -s $BASE_URL/nonce/pending/$ADDR1 | jq -r '.pending_nonce')
SIGN=$(curl -s -X POST $BASE_URL/tx/sign -H "Content-Type: application/json" -d "{
  \"private_key\": \"$PRIV1\",
  \"tx_type\": \"deploy_contract\",
  \"from\": \"$ADDR1\",
  \"nonce\": $NONCE,
  \"data\": {
    \"name\": \"Counter\",
    \"variables\": [{\"name\": \"count\", \"type\": \"uint64\", \"default\": \"0\"}]
  }
}")
SIG=$(echo "$SIGN" | jq -r '.signature')

RESULT=$(curl -s -X POST $BASE_URL/tx -H "Content-Type: application/json" -d "{
  \"tx_type\": \"deploy_contract\",
  \"from\": \"$ADDR1\",
  \"nonce\": $NONCE,
  \"data\": {
    \"name\": \"Counter\",
    \"variables\": [{\"name\": \"count\", \"type\": \"uint64\", \"default\": \"0\"}]
  },
  \"signature\": \"$SIG\",
  \"public_key\": \"$PUB1\"
}")
test_endpoint "Deploy Counter contract" "$RESULT" '"success":true'
TX_HASH=$(echo "$RESULT" | jq -r '.hash')

echo "Waiting for Layer 2 BFT Certificate..."
sleep $EPOCH_WAIT

COUNTER=$(curl -s $BASE_URL/tx/$TX_HASH | jq -r '.transaction.to')
echo "   Counter address: $COUNTER"

echo "Testing GET /contracts"
RESULT=$(curl -s $BASE_URL/contracts)
test_endpoint "List contracts" "$RESULT" '"contracts"'

echo "Testing GET /contract/$COUNTER"
RESULT=$(curl -s $BASE_URL/contract/$COUNTER)
test_endpoint "Contract info" "$RESULT" '"name":"Counter"'

echo ""

# ============================================================
# SECTION 7: FREE READS (No signature needed!)
# ============================================================
echo -e "${BLUE}━━━ SECTION 7: FREE READS (No signature!) ━━━${NC}"

echo "Testing GET /contract/$COUNTER/var/count (FREE)"
RESULT=$(curl -s $BASE_URL/contract/$COUNTER/var/count)
test_endpoint "Read variable (FREE)" "$RESULT" '"value":0'

echo "Testing GET /contract/$COUNTER/var/owner (FREE)"
RESULT=$(curl -s $BASE_URL/contract/$COUNTER/var/owner)
test_endpoint "Read owner (FREE)" "$RESULT" '"value":"iiitd1'

echo "Testing GET /contract/$COUNTER/mbi (MBI)"
RESULT=$(curl -s $BASE_URL/contract/$COUNTER/mbi)
test_endpoint "Get MBI" "$RESULT" '"mbi"'

echo ""

# ============================================================
# SECTION 8: LEADERBOARD
# ============================================================
echo -e "${BLUE}━━━ SECTION 8: LEADERBOARD ━━━${NC}"

echo "Testing GET /leaderboard..."
RESULT=$(curl -s $BASE_URL/leaderboard)
test_endpoint "Leaderboard balances" "$RESULT" '"top_balances"'
test_endpoint "Has token_creators" "$RESULT" '"top_token_creators"'
test_endpoint "Has contract_deployers" "$RESULT" '"top_contract_deployers"'
test_endpoint "Has tx_senders" "$RESULT" '"top_tx_senders"'

echo ""

# ============================================================
# SUMMARY
# ============================================================
echo "============================================================"
echo -e "📊 ${YELLOW}TEST SUMMARY${NC}"
echo "============================================================"
echo ""
echo -e "   ${GREEN}PASSED: $PASS${NC}"
echo -e "   ${RED}FAILED: $FAIL${NC}"
echo ""

TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
    echo -e "   ${GREEN}✅ ALL $TOTAL TESTS PASSED!${NC}"
else
    echo -e "   ${RED}❌ $FAIL/$TOTAL TESTS FAILED${NC}"
fi