pub mod star;
pub mod mesh;

use crate::chain::{LatticeBlock, Transaction, BoxError};
use async_trait::async_trait;

pub use star::StarNetwork;

#[async_trait]
pub trait Network: Send + Sync {
    async fn start(&mut self) -> Result<(), BoxError>;
    async fn broadcast_lattice_block(&self, block: &LatticeBlock) -> Result<(), BoxError>;
    async fn broadcast_tx(&self, tx: &Transaction) -> Result<(), BoxError>;
    
    async fn get_active_peer_ids(&self) -> Vec<String>;
    
    fn peer_count(&self) -> usize;
    fn browser_count(&self) -> usize;
}