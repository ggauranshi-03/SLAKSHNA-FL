use crate::config::Config;
use crate::state::State;
use crate::address::Address;
use crate::iiitd::IIITD;
use ark_ff::Field;
use serde::{ Deserialize, Serialize };
use sha2::{ Sha256, Digest };
use std::sync::Arc;
use tokio::sync::RwLock;
use chrono::Utc;
use std::collections::HashMap;
use rayon::prelude::*;

pub type BoxError = Box<dyn std::error::Error + Send + Sync>;

// Global constant for committee size
pub const COMMITTEE_SIZE: usize = 4;
// --- BFT-ARCHIPELAGO ALGORITHM 5 ---

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub enum BftMessage {
//     RStep {
//         rank: u64,
//         block: Layer2Block,
//         sender: String,
//     },
//     AStep {
//         rank: u64,
//         block: Layer2Block,
//         sender: String,
//     },
//     BStep {
//         rank: u64,
//         flag: bool,
//         block: Layer2Block,
//         sender: String,
//     },
// }

// #[derive(Debug, Default, Clone)]
// pub struct BftRoundState {
//     pub r_votes: std::collections::HashMap<String, Layer2Block>,
//     pub a_votes: std::collections::HashMap<String, Layer2Block>,
//     pub b_votes: std::collections::HashMap<String, (bool, Layer2Block)>,
// }

/// STEP 3: The Proposal Payload (< 1 KB)
/// Sent by the Worker over Gossipsub. Raw transactions are EXCLUDED.


/// Transaction error types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TxError {
    InvalidSignature {
        message: String,
    },
    InvalidNonce {
        expected: u64,
        got: u64,
    },
    InsufficientBalance {
        required: u64,
        available: u64,
    },
    InvalidAddress {
        address: String,
    },
    InvalidRecipient {
        message: String,
    },
    TokenNotFound {
        contract: String,
    },
    InsufficientTokenBalance {
        required: u64,
        available: u64,
    },
    ContractError {
        message: String,
    },
    InvalidTxType {
        tx_type: String,
    },
    GasExceeded {
        limit: u64,
        used: u64,
    },
    InternalError {
        message: String,
    },
}

impl std::fmt::Display for TxError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TxError::InvalidSignature { message } => write!(f, "Invalid signature: {}", message),
            TxError::InvalidNonce { expected, got } =>
                write!(f, "Invalid nonce: expected {}, got {}", expected, got),
            TxError::InsufficientBalance { required, available } =>
                write!(f, "Insufficient balance: need {}, have {}", required, available),
            TxError::InvalidAddress { address } => write!(f, "Invalid address: {}", address),
            TxError::InvalidRecipient { message } => write!(f, "Invalid recipient: {}", message),
            TxError::TokenNotFound { contract } => write!(f, "Token not found: {}", contract),
            TxError::InsufficientTokenBalance { required, available } =>
                write!(f, "Insufficient token balance: need {}, have {}", required, available),
            TxError::ContractError { message } => write!(f, "Contract error: {}", message),
            TxError::InvalidTxType { tx_type } =>
                write!(f, "Invalid transaction type: {}", tx_type),
            TxError::GasExceeded { limit, used } =>
                write!(f, "Gas exceeded: limit {}, used {}", limit, used),
            TxError::InternalError { message } => write!(f, "Internal error: {}", message),
        }
    }
}

impl std::error::Error for TxError {}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Block {
    pub height: u64,
    pub hash: String,
    pub prev_hash: String,
    pub timestamp: i64,
    pub validator: String,
    pub transactions: Vec<Transaction>,
    pub tx_count: usize,
    pub gas_used: u64,
    pub gas_limit: u64,
    pub rewards: BlockRewards,
    pub signature: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BlockRewards {
    pub validator_reward: u64,
    pub service_rewards: Vec<ServiceReward>,
    pub total_minted: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceReward {
    pub rank: u8,
    pub node_id: String,
    pub address: String,
    pub browsers: u32,
    pub amount: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transaction {
    pub hash: String,
    pub tx_type: TxType,
    pub from: String,
    pub to: Option<String>,
    pub value: u64,
    pub gas_price: u64,
    pub gas_limit: u64,
    pub gas_used: u64,
    pub nonce: u64,
    pub data: Option<TxData>,
    pub timestamp: i64,
    pub signature: String,
    pub public_key: String,
    pub status: TxStatus,
    pub error: Option<String>,
    // ZKP Shield Fields
    pub commitment: Option<String>,
    pub proof: Option<String>,
    pub nullifier: Option<String>,
    pub encrypted_note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TxType {
    Transfer,
    Deploy,
    Call,
    CreateToken,
    TransferToken,
    DeployContract,
    CallContract,
    Shield,
    Unshield,
}

impl TxType {
    pub fn as_str(&self) -> &str {
        match self {
            TxType::Transfer => "transfer",
            TxType::Deploy => "deploy",
            TxType::Call => "call",
            TxType::CreateToken => "create_token",
            TxType::TransferToken => "transfer_token",
            TxType::DeployContract => "deploy_contract",
            TxType::CallContract => "call_contract",
            TxType::Shield => "shield",
            TxType::Unshield => "unshield",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TxData {
    Deploy {
        code: Vec<u8>,
        name: String,
    },
    Call {
        contract: String,
        method: String,
        args: Vec<String>,
    },
    CreateToken {
        name: String,
        symbol: String,
        total_supply: u64,
    },
    TransferToken {
        contract: String,
        to: String,
        amount: u64,
    },
    // IVM Contract Deployment
    DeployContract {
        name: String,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        token: Option<String>,
        #[serde(default)]
        variables: Vec<crate::iiitd::VarDef>,
        #[serde(default)]
        mappings: Vec<crate::iiitd::MappingDef>,
        #[serde(default)]
        functions: Vec<crate::iiitd::FnDef>,
    },
    // IVM Contract Call
    CallContract {
        contract: String,
        method: String,
        #[serde(default)]
        args: Vec<String>,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        amount: Option<u64>,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TxStatus {
    Pending,
    Success,
    Failed,
}

impl Transaction {
    pub fn calculate_hash(&self) -> String {
        let mut hasher = Sha256::new();
        hasher.update(format!("{:?}", self.tx_type));
        hasher.update(&self.from);
        hasher.update(self.to.as_deref().unwrap_or(""));
        hasher.update(self.value.to_le_bytes());
        hasher.update(self.nonce.to_le_bytes());
        hasher.update(self.timestamp.to_le_bytes());
        if let Some(note) = &self.encrypted_note {
            hasher.update(note.as_bytes());
        }
        hex::encode(hasher.finalize())
    }

    /// Get the message that needs to be signed
    pub fn get_sign_message(&self) -> Vec<u8> {
        let data_str = self.data.as_ref().map(|d| serde_json::to_string(d).unwrap_or_default());
        crate::address::hash_tx_data(
            self.tx_type.as_str(),
            &self.from,
            self.to.as_deref(),
            self.value,
            self.nonce,
            data_str.as_deref(),
            self.encrypted_note.as_deref()
        )
    }

    /// Verify the transaction signature
    pub fn verify_signature(&self) -> Result<bool, BoxError> {
        let message = self.get_sign_message();
        crate::address::verify_tx_signature(&self.from, &message, &self.signature, &self.public_key)
    }
}

impl Block {
    pub fn genesis(master_address: &str, master_balance: u64) -> Self {
        let timestamp = Utc::now().timestamp();
        let mut block = Block {
            height: 0,
            hash: String::new(),
            prev_hash: "0".repeat(64),
            timestamp,
            validator: master_address.to_string(),
            transactions: vec![],
            tx_count: 0,
            gas_used: 0,
            gas_limit: 1_000_000,
            rewards: BlockRewards {
                validator_reward: master_balance,
                service_rewards: vec![],
                total_minted: master_balance,
            },
            signature: String::new(),
        };
        block.hash = block.calculate_hash();
        block
    }

    pub fn new(
        height: u64,
        prev_hash: &str,
        validator: &str,
        transactions: Vec<Transaction>,
        rewards: BlockRewards,
        gas_limit: u64
    ) -> Self {
        let timestamp = Utc::now().timestamp();
        let tx_count = transactions.len();
        let gas_used: u64 = transactions
            .iter()
            .map(|tx| tx.gas_used)
            .sum();

        let mut block = Block {
            height,
            hash: String::new(),
            prev_hash: prev_hash.to_string(),
            timestamp,
            validator: validator.to_string(),
            transactions,
            tx_count,
            gas_used,
            gas_limit,
            rewards,
            signature: String::new(),
        };
        block.hash = block.calculate_hash();
        block
    }

    pub fn calculate_hash(&self) -> String {
        let mut hasher = Sha256::new();
        hasher.update(self.height.to_le_bytes());
        hasher.update(&self.prev_hash);
        hasher.update(self.timestamp.to_le_bytes());
        hasher.update(&self.validator);
        for tx in &self.transactions {
            hasher.update(&tx.hash);
        }
        hex::encode(hasher.finalize())
    }

    pub fn is_valid(&self) -> bool {
        self.hash == self.calculate_hash()
    }
}

// --- LAYER 1: ASYNCHRONOUS MODEL-LATTICE ---

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum LatticeBlockType {
    Proposal {
        payload_hash: String,
        compressed_delta: String, // CHANGED from storage_uri
    },
    Evaluation {
        target_node: String,
        proposal_hash: String,
        loss_drop: f64,
        trust_score: f64,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LatticeBlock {
    pub node_id: String,
    pub prev_hash: String,
    pub block_type: LatticeBlockType,
    pub signature: String,
    pub hash: String,
}

impl LatticeBlock {
    pub fn calculate_hash(&self) -> String {
        let mut hasher = Sha256::new();
        hasher.update(&self.node_id);
        hasher.update(&self.prev_hash);
        match &self.block_type {
            LatticeBlockType::Proposal { payload_hash, compressed_delta } => {
                hasher.update(b"proposal");
                hasher.update(payload_hash);
                hasher.update(compressed_delta);
            }
            LatticeBlockType::Evaluation { target_node, proposal_hash, loss_drop, trust_score } => {
                hasher.update(b"evaluation");
                hasher.update(target_node);
                hasher.update(proposal_hash);
                hasher.update(loss_drop.to_le_bytes());
                hasher.update(trust_score.to_le_bytes());
            }
        }
        hex::encode(hasher.finalize())
    }
}

pub struct Blockchain {
    pub config: Config,
    pub state: Arc<RwLock<State>>,
    pub master_address: Address,
    pub iiitd: IIITD,
    pub lattice_chains: std::collections::HashMap<String, Vec<LatticeBlock>>, // Personal chains per node
}

impl Blockchain {
    pub async fn new(
        config: Config,
        state: Arc<RwLock<State>>,
        master_address: Address
    ) -> Result<Self, BoxError> {
        let iiitd = IIITD::new();

        Ok(Blockchain {
            config,
            state,
            master_address,
            iiitd,
            lattice_chains: std::collections::HashMap::new(),
        })
    }

    // ========================================================================
    // LAYER 1: FEDERATED LEARNING WORK
    // ========================================================================

    
    pub fn add_lattice_block(&mut self, block: LatticeBlock) {
        if block.hash != block.calculate_hash() {
            tracing::warn!("Invalid lattice block hash from {}", block.node_id);
            return;
        }
        
        let chain = self.lattice_chains.entry(block.node_id.clone()).or_insert_with(Vec::new);
        
        // Simple append for now
        chain.push(block);
    }

    pub fn get_elected_committee(&self, k: usize) -> Vec<String> {
        let mut global_reputation: std::collections::HashMap<String, f64> = std::collections::HashMap::new();

        // Accumulate trust weights from all Evaluation blocks
        for (_, chain) in &self.lattice_chains {
            for block in chain {
                if let LatticeBlockType::Evaluation { target_node, trust_score, .. } = &block.block_type {
                    let rep = global_reputation.entry(target_node.clone()).or_insert(0.0);
                    *rep += trust_score;
                }
            }
        }

        let mut eligible_nodes: Vec<_> = global_reputation.into_iter().collect();

        // Sort descending by score
        eligible_nodes.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal).then_with(|| a.0.cmp(&b.0)));

        eligible_nodes.into_iter().take(k).map(|(id, _)| id).collect()
    }

    pub fn get_committee_with_reputation(&self, k: usize) -> Vec<(String, f64)> {
        let mut global_reputation: std::collections::HashMap<String, f64> = std::collections::HashMap::new();

        for (_, chain) in &self.lattice_chains {
            for block in chain {
                if let LatticeBlockType::Evaluation { target_node, trust_score, .. } = &block.block_type {
                    let rep = global_reputation.entry(target_node.clone()).or_insert(0.0);
                    *rep += trust_score;
                }
            }
        }

        let mut eligible_nodes: Vec<_> = global_reputation.into_iter().collect();

        eligible_nodes.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal).then_with(|| a.0.cmp(&b.0)));

        eligible_nodes.into_iter().take(k).collect()
    }

    // ========================================================================
    // TRANSACTION EXECUTION (Original Logic Preserved)
    // ========================================================================

    async fn execute_transaction(&mut self, tx: &mut Transaction) -> Result<(), TxError> {
           tx.gas_used = match &tx.tx_type {
            TxType::Transfer => 21000,
            TxType::Deploy => 200000,
            TxType::Call => 50000,
            TxType::CreateToken => 100000,
            TxType::TransferToken => 65000,
            TxType::DeployContract => 150000,
            TxType::CallContract => 50000, // Base, actual depends on method
            TxType::Shield => 100000,
            TxType::Unshield => 150000, // ZK proof verification is expensive
        };

        // --- ZKP SHIELDING (DEPOSIT) ---
        if tx.tx_type == TxType::Shield {
            let commitment = tx.commitment.as_ref().ok_or_else(|| TxError::InvalidSignature {
                message: "Missing commitment".to_string(),
            })?;
            
            let mut state_write = self.state.write().await;
            
            // Increment Nonce FIRST to prevent balance drain on out-of-order failures
            let sender_nonce = state_write.get_nonce(&tx.from).unwrap_or(0);
            if tx.nonce != sender_nonce {
                return Err(TxError::InvalidNonce { expected: sender_nonce, got: tx.nonce });
            }
            state_write.set_nonce(&tx.from, sender_nonce + 1).map_err(|e| TxError::InternalError { message: e.to_string() })?;
            
            // Deduct public funds
            let sender_balance = state_write.get_balance(&tx.from).map_err(|e| TxError::InternalError { message: e.to_string() })?;
            if sender_balance < tx.value + tx.gas_used {
                return Err(TxError::InsufficientBalance { required: tx.value + tx.gas_used, available: sender_balance });
            }
            state_write.set_balance(&tx.from, sender_balance - tx.value - tx.gas_used).map_err(|e| TxError::InternalError { message: e.to_string() })?;

            // Insert new Commitment into Merkle Tree
            let mut tree = state_write.get_shielded_tree().unwrap_or(crate::zkp::MockMerkleTree::new());
            let commitment_bytes = hex::decode(commitment).map_err(|e| TxError::InternalError { message: e.to_string() })?;
            
            use ark_serialize::CanonicalDeserialize;
            let commitment_fr = ark_bn254::Fr::deserialize_uncompressed(&commitment_bytes[..])
                .map_err(|e| TxError::InternalError { message: e.to_string() })?;
            
            tree.insert(commitment_fr);
            state_write.save_shielded_tree(&tree).map_err(|e| TxError::InternalError { message: e.to_string() })?;
            
            tracing::info!("🛡️ SHIELDED {} tokens! Inserted UTXO Commitment.", tx.value);
            return Ok(());
        }

        // --- ZKP UNSHIELDING (WITHDRAWAL) ---
        if tx.tx_type == TxType::Unshield {
            let proof = tx.proof.as_ref().ok_or_else(|| TxError::InvalidSignature {
                message: "Missing ZK proof".to_string(),
            })?;
            let nullifier = tx.nullifier.as_ref().ok_or_else(|| TxError::InvalidSignature {
                message: "Missing nullifier".to_string(),
            })?;

            // 1. Check double spending
            let state_read = self.state.read().await;
            if state_read.has_nullifier(nullifier).map_err(|e| TxError::InternalError { message: e.to_string() })? {
                return Err(TxError::InvalidSignature {
                    message: "Nullifier already spent (Double spending)".to_string(),
                });
            }

            // Get global Merkle Root
            let tree = state_read.get_shielded_tree().unwrap_or(crate::zkp::MockMerkleTree::new());
            let current_root = tree.root();
            let current_root_hex = {
                use ark_serialize::CanonicalSerialize;
                let mut bytes = Vec::new();
                current_root.serialize_uncompressed(&mut bytes).map_err(|e| TxError::InternalError { message: e.to_string() })?;
                hex::encode(bytes)
            };
            drop(state_read);

            // Use the anchor root from public_key if provided, else use current root
            let anchor_root_hex = if tx.public_key.is_empty() {
                current_root_hex
            } else {
                tx.public_key.clone()
            };

            // 2. Verify ZK Proof (Merkle Path Verification)
            match crate::zkp::verify_shielded_proof(proof, &anchor_root_hex, nullifier) {
                Ok(true) => {
                    tracing::info!("🛡️ ZK-UTXO: Proof verified against global Merkle Root! Nullifier: {}", &nullifier[..8]);
                }
                Ok(false) => {
                    return Err(TxError::InvalidSignature { message: "Invalid ZK proof against Merkle Root".to_string() });
                }
                Err(e) => {
                    return Err(TxError::InvalidSignature { message: format!("ZKP Verification Error: {}", e) });
                }
            }

            // 3. Finalize unshielded state (IGNORE tx.from COMPLETELY)
            let mut state_write = self.state.write().await;

            // Add to receiver if 'to' is present
            if let Some(ref to) = tx.to {
                let to_balance = state_write.get_balance(to).map_err(|e| TxError::InternalError { message: e.to_string() })?;
                state_write.set_balance(to, to_balance + tx.value).map_err(|e| TxError::InternalError { message: e.to_string() })?;
                tracing::info!("🔓 Unshielded {} tokens to public address {}", tx.value, to);
            }

            // Record Nullifier as spent
            state_write.save_nullifier(nullifier).map_err(|e| TxError::InternalError { message: e.to_string() })?;

            // Notice: tx.from is completely decoupled. No balances deducted, no nonces incremented for Unshield.
            return Ok(());
        }

        // --- ORIGINAL SIGNATURE VERIFICATION ---
        // match tx.verify_signature() {
        //     Ok(true) => {}
        //     Ok(false) => {
        //         return Err(TxError::InvalidSignature {
        //             message: "Signature does not match sender address".to_string(),
        //         });
        //     }
        //     Err(e) => {
        //         return Err(TxError::InvalidSignature {
        //             message: e.to_string(),
        //         });
        //     }
        // }

        // Verify nonce
        let expected_nonce = {
            let state_guard = self.state.read().await;
            state_guard.get_nonce(&tx.from).unwrap_or(0)
        };

        if tx.nonce != expected_nonce {
            return Err(TxError::InvalidNonce { expected: expected_nonce, got: tx.nonce });
        }

        // Calculate gas fee
        let gas_fee = tx.gas_used * tx.gas_price;

        // Check balance for gas fee (+ value for transfers)
        let total_cost = match &tx.tx_type {
            TxType::Transfer => tx.value + gas_fee,
            _ => gas_fee,
        };

        {
            let state_guard = self.state.read().await;
            let from_balance = state_guard
                .get_balance(&tx.from)
                .map_err(|e| TxError::InternalError { message: e.to_string() })?;
            if from_balance < total_cost {
                return Err(TxError::InsufficientBalance {
                    required: total_cost,
                    available: from_balance,
                });
            }
        }

        // Execute transaction based on type
        match &tx.tx_type {
            TxType::Transfer => {
                let mut state_guard = self.state.write().await;
                let from_balance = state_guard
                    .get_balance(&tx.from)
                    .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                let to = tx.to.as_ref().ok_or_else(|| TxError::InvalidRecipient {
                    message: "Missing recipient address".to_string(),
                })?;

                let to_addr = Address::new(to);
                if !to_addr.is_valid() {
                    return Err(TxError::InvalidAddress { address: to.clone() });
                }

                let to_balance = state_guard
                    .get_balance(to)
                    .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                // Deduct value + gas fee from sender
                state_guard
                    .set_balance(&tx.from, from_balance - total_cost)
                    .map_err(|e| TxError::InternalError { message: e.to_string() })?;
                // Add value to recipient
                state_guard
                    .set_balance(to, to_balance + tx.value)
                    .map_err(|e| TxError::InternalError { message: e.to_string() })?;
                state_guard
                    .increment_nonce(&tx.from)
                    .map_err(|e| TxError::InternalError { message: e.to_string() })?;
            }
            TxType::Deploy => {
                let mut state_guard = self.state.write().await;
                let from_balance = state_guard
                    .get_balance(&tx.from)
                    .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                // Deduct gas fee
                state_guard
                    .set_balance(&tx.from, from_balance - gas_fee)
                    .map_err(|e| TxError::InternalError { message: e.to_string() })?;
                state_guard
                    .increment_nonce(&tx.from)
                    .map_err(|e| TxError::InternalError { message: e.to_string() })?;
            }
            TxType::Call => {
                if let Some(TxData::Call { contract, method, args }) = &tx.data {
                    let mut state_guard = self.state.write().await;
                    let from_balance = state_guard
                        .get_balance(&tx.from)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    // Deduct gas fee
                    state_guard
                        .set_balance(&tx.from, from_balance - gas_fee)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    self.iiitd
                        .execute_call(&mut state_guard, contract, method, args)
                        .map_err(|e| TxError::ContractError { message: e.to_string() })?;
                    state_guard
                        .increment_nonce(&tx.from)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;
                }
            }
            TxType::CreateToken => {
                if let Some(TxData::CreateToken { name, symbol, total_supply }) = &tx.data {
                    let mut state_guard = self.state.write().await;
                    let from_balance = state_guard
                        .get_balance(&tx.from)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    // Deduct gas fee
                    state_guard
                        .set_balance(&tx.from, from_balance - gas_fee)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    let contract_address = crate::standards
                        ::create_iiitd20_token(
                            &mut state_guard,
                            &tx.from,
                            name,
                            symbol,
                            *total_supply
                        )
                        .map_err(|e| TxError::ContractError { message: e.to_string() })?;
                    tx.to = Some(contract_address);
                    state_guard
                        .increment_nonce(&tx.from)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;
                }
            }
            TxType::TransferToken => {
                if let Some(TxData::TransferToken { contract, to, amount }) = &tx.data {
                    let mut state_guard = self.state.write().await;
                    let from_balance = state_guard
                        .get_balance(&tx.from)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    // Deduct gas fee
                    state_guard
                        .set_balance(&tx.from, from_balance - gas_fee)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    // Check token exists
                    let token = state_guard
                        .get_token(contract)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?
                        .ok_or_else(|| TxError::TokenNotFound { contract: contract.clone() })?;

                    // Check token balance
                    let token_balance = state_guard
                        .get_token_balance(contract, &tx.from)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    if token_balance < *amount {
                        return Err(TxError::InsufficientTokenBalance {
                            required: *amount,
                            available: token_balance,
                        });
                    }

                    // Validate recipient
                    let to_addr = Address::new(to);
                    if !to_addr.is_valid() {
                        return Err(TxError::InvalidAddress { address: to.clone() });
                    }

                    crate::standards
                        ::transfer_iiitd20(&mut state_guard, contract, &tx.from, to, *amount)
                        .map_err(|e| TxError::ContractError { message: e.to_string() })?;

                    state_guard
                        .increment_nonce(&tx.from)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    drop(token);
                }
            }
            TxType::DeployContract => {
                if
                    let Some(
                        TxData::DeployContract { name, token, variables, mappings, functions },
                    ) = &tx.data
                {
                    let mut state_guard = self.state.write().await;
                    let from_balance = state_guard
                        .get_balance(&tx.from)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    // Deduct gas fee
                    state_guard
                        .set_balance(&tx.from, from_balance - gas_fee)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    // Deploy IVM contract
                    let contract_addr = self.iiitd
                        .deploy(
                            &mut state_guard,
                            &tx.from,
                            name,
                            token.clone(),
                            variables.clone(),
                            mappings.clone(),
                            functions.clone()
                        )
                        .map_err(|e| TxError::ContractError { message: e.to_string() })?;

                    tx.to = Some(contract_addr);
                    state_guard
                        .increment_nonce(&tx.from)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;
                }
            }
            TxType::CallContract => {
                // ... (existing logic)
                if let Some(TxData::CallContract { contract, method, args, amount }) = &tx.data {
                    let mut state_guard = self.state.write().await;
                    let from_balance = state_guard
                        .get_balance(&tx.from)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    // Deduct base gas fee
                    state_guard
                        .set_balance(&tx.from, from_balance - gas_fee)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;

                    // Call IVM contract
                    let result = self.iiitd
                        .call(
                            &mut state_guard,
                            &tx.from,
                            contract,
                            method,
                            args.clone(),
                            amount.unwrap_or(0)
                        )
                        .map_err(|e| TxError::ContractError { message: e.to_string() })?;

                    tx.gas_used = result.gas_used;

                    if !result.success {
                        return Err(TxError::ContractError {
                            message: result.error.unwrap_or("Unknown error".to_string()),
                        });
                    }

                    tx.to = Some(contract.clone());
                    state_guard
                        .increment_nonce(&tx.from)
                        .map_err(|e| TxError::InternalError { message: e.to_string() })?;
                }
            }
            TxType::Shield | TxType::Unshield => {
                // Handled in the ZKP logic at the beginning of execute_transaction
                // This arm is required for exhaustiveness.
            }
        }

        Ok(())
    }



    // Existing getters
    pub async fn get_balance(&self, address: &str) -> Result<u64, BoxError> {
        let state_guard = self.state.read().await;
        Ok(state_guard.get_balance(address)?)
    }

    pub async fn get_nonce(&self, address: &str) -> Result<u64, BoxError> {
        let state_guard = self.state.read().await;
        Ok(state_guard.get_nonce(address)?)
    }

    pub async fn get_height(&self) -> Result<u64, BoxError> {
        let state_guard = self.state.read().await;
        Ok(state_guard.get_height()?)
    }

    // Note: get_block should be updated in your API/State to return Layer2Block.
    // Assuming State is updated separately, this signature stays the same for now,
    // or you can replace `Block` with `Layer2Block` here if you've already changed it elsewhere.
    /*
    pub async fn get_block(&self, height: u64) -> Result<Option<Layer2Block>, BoxError> {
        let state_guard = self.state.read().await;
        Ok(state_guard.get_layer2_block(height)?)
    }
    */
}
