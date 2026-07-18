use serde::Deserialize;
use std::fs;
use crate::BoxError;

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub chain: ChainConfig,
    pub block: BlockConfig,
    pub rewards: RewardsConfig,
    pub genesis: GenesisConfig,
    pub faucet: FaucetConfig,
    pub token: TokenConfig,
    pub node: NodeConfig,
    pub network: NetworkConfig,
    pub validators: ValidatorsConfig,
    pub pruning: PruningConfig,
    pub logging: LoggingConfig,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ChainConfig {
    pub chain_id: String,
    pub chain_name: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct BlockConfig {
    pub block_time: u64,
    pub gas_limit: u64,
    pub max_txs_per_block: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct RewardsConfig {
    pub block_reward: u64,
    pub validator_percent: u64,
    pub service_pool_percent: u64,
    pub top_nodes: u64,
    pub rank_1_percent: u64,
    pub rank_2_percent: u64,
    pub rank_3_percent: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct GenesisConfig {
    pub master_address: String,
    pub master_balance: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct FaucetConfig {
    pub enabled: bool,
    pub amount: u64,
    pub cooldown: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct TokenConfig {
    pub name: String,
    pub symbol: String,
    pub decimals: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct NodeConfig {
    pub id: String,
    #[serde(rename = "type")]
    pub node_type: String,
    pub data_dir: String,
    pub gpu_id: Option<u32>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct NetworkConfig {
    pub topology: String,
    pub host: String,
    pub p2p_port: u16,
    pub ws_port: u16,
    pub api_port: u16,
    pub boot_nodes: Option<Vec<String>>,
    pub star: Option<StarConfig>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct StarConfig {
    pub master_url: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ValidatorsConfig {
    pub addresses: Vec<String>,
    pub max_validators: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct PruningConfig {
    pub keep_blocks: u64,
    pub keep_txs: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct LoggingConfig {
    pub level: String,
}

impl Config {
    pub fn load(path: &str) -> Result<Self, BoxError> {
        let contents = fs::read_to_string(path)?;
        let config: Config = toml::from_str(&contents)?;
        Ok(config)
    }
}
