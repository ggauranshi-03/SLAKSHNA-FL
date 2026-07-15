// use ark_bn254::{ Bn254, Fr };
// use ark_groth16::{ Groth16, ProvingKey, VerifyingKey, Proof, PreparedVerifyingKey };
// use ark_relations::r1cs::{ ConstraintSynthesizer, ConstraintSystemRef, SynthesisError, LinearCombination };
// use ark_serialize::{ CanonicalDeserialize, CanonicalSerialize };
// use ark_ff::{ PrimeField, BigInteger };
// use ark_crypto_primitives::snark::SNARK;
// use rand::thread_rng;
// use serde::{ Serialize, Deserialize };
// use std::sync::OnceLock;

// /// Parameters for the ZKP Shield
// pub struct ZkpParams {
//     pub pk: ProvingKey<Bn254>,
//     pub vk: PreparedVerifyingKey<Bn254>,
// }

// static PARAMS: OnceLock<ZkpParams> = OnceLock::new();

// /// The Circuit for Shielded Transactions
// /// It proves that:
// /// 1. commitment = Hash(secret, receiver, amount, salt)
// /// 2. nullifier = Hash(secret, nonce)
// #[derive(Clone)]
// pub struct ShieldedTxCircuit {
//     // Private inputs
//     pub secret: Option<Fr>,
//     pub receiver: Option<Fr>,
//     pub amount: Option<Fr>,
//     pub salt: Option<Fr>,
//     pub nonce: Option<Fr>,

//     // Public inputs (will be verified against these)
//     pub commitment: Option<Fr>,
//     pub nullifier: Option<Fr>,
// }

// impl ConstraintSynthesizer<Fr> for ShieldedTxCircuit {
//     fn generate_constraints(self, cs: ConstraintSystemRef<Fr>) -> Result<(), SynthesisError> {
//         let secret = cs.new_witness_variable(|| self.secret.ok_or(SynthesisError::AssignmentMissing))?;
//         let receiver = cs.new_witness_variable(|| self.receiver.ok_or(SynthesisError::AssignmentMissing))?;
//         let amount = cs.new_witness_variable(|| self.amount.ok_or(SynthesisError::AssignmentMissing))?;
//         let salt = cs.new_witness_variable(|| self.salt.ok_or(SynthesisError::AssignmentMissing))?;
//         let nonce = cs.new_witness_variable(|| self.nonce.ok_or(SynthesisError::AssignmentMissing))?;

//         let commitment_val = cs.new_input_variable(|| self.commitment.ok_or(SynthesisError::AssignmentMissing))?;
//         let nullifier_val = cs.new_input_variable(|| self.nullifier.ok_or(SynthesisError::AssignmentMissing))?;

//         // Simplified Circuit Logic:
//         // In a real production system, we would use a Poseidon gadget here.
//         // For this implementation, we use a simpler algebraic relationship:
//         // Commitment = secret * (receiver + amount + salt)
//         // Nullifier = secret * nonce

//         // Constraint 1: secret * (receiver + amount + salt) == commitment
//         cs.enforce_constraint(
//             secret.into(),
//             LinearCombination::from(receiver) + amount + salt,
//             commitment_val.into()
//         )?;

//         // Constraint 2: secret * nonce == nullifier
//         cs.enforce_constraint(
//             secret.into(),
//             nonce.into(),
//             nullifier_val.into()
//         )?;

//         Ok(())
//     }
// }

// /// Initialize the ZKP parameters (One-time setup)
// pub fn init_params() -> &'static ZkpParams {
//     PARAMS.get_or_init(|| {
//         let mut rng = thread_rng();
//         let circuit = ShieldedTxCircuit {
//             secret: None,
//             receiver: None,
//             amount: None,
//             salt: None,
//             nonce: None,
//             commitment: None,
//             nullifier: None,
//         };

//         let (pk, vk) = Groth16::<Bn254>::circuit_specific_setup(circuit, &mut rng).expect("Setup failed");
//         let pvk = Groth16::<Bn254>::process_vk(&vk).expect("Process VK failed");

//         ZkpParams { pk, vk: pvk }
//     })
// }

// /// Verify a shielded transaction proof
// pub fn verify_shielded_proof(
//     proof_hex: &str,
//     commitment_hex: &str,
//     nullifier_hex: &str
// ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
//     let params = init_params();

//     // Deserialize proof
//     let proof_bytes = hex::decode(proof_hex)?;
//     let proof = Proof::<Bn254>::deserialize_compressed(&proof_bytes[..])?;

//     // Deserialize public inputs
//     let commitment_bytes = hex::decode(commitment_hex)?;
//     let nullifier_bytes = hex::decode(nullifier_hex)?;

//     let commitment = Fr::deserialize_uncompressed(&commitment_bytes[..])?;
//     let nullifier = Fr::deserialize_uncompressed(&nullifier_bytes[..])?;

//     let public_inputs = vec![commitment, nullifier];

//     let is_valid = Groth16::<Bn254>::verify_with_processed_vk(&params.vk, &public_inputs, &proof)?;

//     Ok(is_valid)
// }

// /// Helper to hash strings to field elements (for demonstration/integration)
// pub fn hash_to_field(s: &str) -> Fr {
//     use sha2::Digest;
//     let mut hasher = sha2::Sha256::new();
//     hasher.update(s.as_bytes());
//     let result = hasher.finalize();
//     Fr::from_be_bytes_mod_order(&result)
// }

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use ark_ff::UniformRand;

//     #[test]
//     fn test_zkp_flow() {
//         let mut rng = thread_rng();
//         let params = init_params();

//         let secret = Fr::rand(&mut rng);
//         let receiver = Fr::rand(&mut rng);
//         let amount = Fr::rand(&mut rng);
//         let salt = Fr::rand(&mut rng);
//         let nonce = Fr::rand(&mut rng);

//         let commitment = secret * (receiver + amount + salt);
//         let nullifier = secret * nonce;

//         let circuit = ShieldedTxCircuit {
//             secret: Some(secret),
//             receiver: Some(receiver),
//             amount: Some(amount),
//             salt: Some(salt),
//             nonce: Some(nonce),
//             commitment: Some(commitment),
//             nullifier: Some(nullifier),
//         };

//         let proof = Groth16::<Bn254>::prove(&params.pk, circuit, &mut rng).unwrap();

//         let mut proof_bytes = Vec::new();
//         proof.serialize_compressed(&mut proof_bytes).unwrap();

//         let mut commitment_bytes = Vec::new();
//         commitment.serialize_uncompressed(&mut commitment_bytes).unwrap();

//         let mut nullifier_bytes = Vec::new();
//         nullifier.serialize_uncompressed(&mut nullifier_bytes).unwrap();

//         let is_valid = verify_shielded_proof(
//             &hex::encode(proof_bytes),
//             &hex::encode(commitment_bytes),
//             &hex::encode(nullifier_bytes)
//         ).unwrap();

//         assert!(is_valid);
//     }
// }

use ark_bn254::{ Bn254, Fr };
use ark_groth16::{ Groth16, ProvingKey, VerifyingKey, Proof, PreparedVerifyingKey };
use ark_relations::r1cs::{
    ConstraintSynthesizer,
    ConstraintSystemRef,
    SynthesisError,
    LinearCombination,
};
use ark_serialize::{ CanonicalDeserialize, CanonicalSerialize };
use ark_ff::{ PrimeField, Field };
use ark_crypto_primitives::snark::SNARK;
use rand::thread_rng;
use std::sync::OnceLock;
use rand::{ SeedableRng, rngs::StdRng }; // <--- ADD THIS
// ========================================================================
// 1. SHIELDED TRANSACTION CIRCUIT (Upgraded to ZK-UTXO Merkle Tree)
// ========================================================================

/// A lightweight local representation of the Shielded State Tree
#[derive(Clone)]
pub struct MockMerkleTree {
    pub leaves: Vec<Fr>,
}

impl MockMerkleTree {
    pub fn new() -> Self {
        Self { leaves: Vec::new() }
    }

    pub fn insert(&mut self, leaf: Fr) {
        self.leaves.push(leaf);
    }

    fn get_padded_leaves(&self) -> Vec<Fr> {
        let mut leaves = self.leaves.clone();
        // Pad to exactly 1024 leaves (Depth = 10) for the fixed-size ZK circuit
        let capacity = 1024;
        while leaves.len() < capacity {
            leaves.push(Fr::from(0u32));
        }
        leaves
    }

    pub fn root(&self) -> Fr {
        let mut current_level = self.get_padded_leaves();
        while current_level.len() > 1 {
            let mut next_level = Vec::new();
            for i in (0..current_level.len()).step_by(2) {
                next_level.push(current_level[i] + current_level[i + 1]);
            }
            current_level = next_level;
        }
        current_level[0]
    }

    pub fn get_path(&self, index: usize) -> (Vec<Fr>, Vec<bool>) {
        let mut path = Vec::new();
        let mut indices = Vec::new();
        let mut current_level = self.get_padded_leaves();
        let mut curr_idx = index;
        
        while current_level.len() > 1 {
            let is_right = curr_idx % 2 != 0;
            let sibling_idx = if is_right { curr_idx - 1 } else { curr_idx + 1 };
            path.push(current_level[sibling_idx]);
            indices.push(is_right);
            
            let mut next_level = Vec::new();
            for i in (0..current_level.len()).step_by(2) {
                next_level.push(current_level[i] + current_level[i + 1]);
            }
            current_level = next_level;
            curr_idx /= 2;
        }
        (path, indices)
    }
}

/// Parameters for the ZKP Shield
pub struct ZkpParams {
    pub pk: ProvingKey<Bn254>,
    pub vk: PreparedVerifyingKey<Bn254>,
}

static PARAMS: OnceLock<ZkpParams> = OnceLock::new();

/// The Circuit for Shielded Transactions (Merkle UTXO)
#[derive(Clone)]
pub struct ShieldedTxCircuit {
    pub secret: Option<Fr>,
    pub nullifier_salt: Option<Fr>,
    pub path_elements: Vec<Option<Fr>>,
    pub path_indices: Vec<Option<bool>>,

    pub nullifier: Option<Fr>,
    pub expected_root: Option<Fr>,
}

impl ConstraintSynthesizer<Fr> for ShieldedTxCircuit {
    fn generate_constraints(self, cs: ConstraintSystemRef<Fr>) -> Result<(), SynthesisError> {
        let secret = cs.new_witness_variable(|| self.secret.ok_or(SynthesisError::AssignmentMissing))?;
        let null_salt = cs.new_witness_variable(|| self.nullifier_salt.ok_or(SynthesisError::AssignmentMissing))?;
        
        let nullifier_val = cs.new_input_variable(|| self.nullifier.ok_or(SynthesisError::AssignmentMissing))?;
        let expected_root_val = cs.new_input_variable(|| self.expected_root.ok_or(SynthesisError::AssignmentMissing))?;

        // 1. nullifier = secret * nullifier_salt
        cs.enforce_constraint(secret.into(), null_salt.into(), nullifier_val.into())?;

        // 2. Algebraic Merkle Path verification (Dummy Hashing: parent = current + sibling)
        let mut current_lc: LinearCombination<Fr> = secret.into();
        for element in self.path_elements {
            let sibling = cs.new_witness_variable(|| element.ok_or(SynthesisError::AssignmentMissing))?;
            current_lc = current_lc + sibling;
        }
        
        // 3. Verify that the calculated root matches the public expected_root
        cs.enforce_constraint(
            LinearCombination::from(ark_relations::r1cs::Variable::One),
            current_lc,
            expected_root_val.into()
        )?;

        Ok(())
    }
}

pub fn init_params() -> &'static ZkpParams {
    PARAMS.get_or_init(|| {
        let mut rng = StdRng::seed_from_u64(42); // Deterministic trusted setup
        let circuit = ShieldedTxCircuit {
            secret: None,
            nullifier_salt: None,
            path_elements: vec![None; 10], // Depth 10 tree
            path_indices: vec![None; 10],
            nullifier: None,
            expected_root: None,
        };

        let (pk, vk) = Groth16::<Bn254>
            ::circuit_specific_setup(circuit, &mut rng)
            .expect("Setup failed");
        let pvk = Groth16::<Bn254>::process_vk(&vk).expect("Process VK failed");

        ZkpParams { pk, vk: pvk }
    })
}

pub fn verify_shielded_proof(
    proof_hex: &str,
    expected_root_hex: &str,
    nullifier_hex: &str
) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
    let params = init_params();

    let proof_bytes = hex::decode(proof_hex)?;
    let proof = Proof::<Bn254>::deserialize_compressed(&proof_bytes[..])?;

    let root_bytes = hex::decode(expected_root_hex)?;
    let nullifier_bytes = hex::decode(nullifier_hex)?;

    let expected_root = Fr::deserialize_uncompressed(&root_bytes[..])?;
    let nullifier = Fr::deserialize_uncompressed(&nullifier_bytes[..])?;

    // Order matters: must match the allocation order in generate_constraints
    let public_inputs = vec![nullifier, expected_root];

    let is_valid = Groth16::<Bn254>::verify_with_processed_vk(&params.vk, &public_inputs, &proof)?;

    Ok(is_valid)
}

// ========================================================================
// 2. ZK-BATCHED MEMPOOL CIRCUIT REMOVED (Layer-1 FL Only)
// ========================================================================


// ========================================================================
// 3. UTILITIES & TESTING
// ========================================================================

/// Helper to hash strings to field elements
pub fn hash_to_field(s: &str) -> Fr {
    use sha2::Digest;
    let mut hasher = sha2::Sha256::new();
    hasher.update(s.as_bytes());
    let result = hasher.finalize();
    Fr::from_be_bytes_mod_order(&result)
}

#[cfg(test)]
mod tests {
    use super::*;
    use ark_ff::UniformRand;

    #[test]
    fn test_shielded_zkp_flow() {
        let mut rng = thread_rng();
        let params = init_params();

        // 1. Setup the Merkle Tree Vault
        let mut tree = MockMerkleTree::new();
        let secret = Fr::rand(&mut rng);
        
        // Let's insert the secret (Commitment) as the second leaf (index 1)
        tree.insert(Fr::rand(&mut rng)); // Index 0
        tree.insert(secret); // Index 1
        tree.insert(Fr::rand(&mut rng)); // Index 2
        
        let root = tree.root();
        let (path_elements, path_indices) = tree.get_path(1);

        // 2. Generate Nullifier
        let null_salt = Fr::rand(&mut rng);
        let nullifier = secret * null_salt;

        let circuit = ShieldedTxCircuit {
            secret: Some(secret),
            nullifier_salt: Some(null_salt),
            path_elements: path_elements.into_iter().map(Some).collect(),
            path_indices: path_indices.into_iter().map(Some).collect(),
            nullifier: Some(nullifier),
            expected_root: Some(root),
        };

        let proof = Groth16::<Bn254>::prove(&params.pk, circuit, &mut rng).unwrap();

        let mut proof_bytes = Vec::new();
        proof.serialize_compressed(&mut proof_bytes).unwrap();

        let mut root_bytes = Vec::new();
        root.serialize_uncompressed(&mut root_bytes).unwrap();

        let mut nullifier_bytes = Vec::new();
        nullifier.serialize_uncompressed(&mut nullifier_bytes).unwrap();

        let is_valid = verify_shielded_proof(
            &hex::encode(proof_bytes),
            &hex::encode(root_bytes),
            &hex::encode(nullifier_bytes)
        ).unwrap();

        assert!(is_valid);
    }
}

