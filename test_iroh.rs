use std::str::FromStr;

fn main() {
    let hex_str = "a65a49db0894467a3b6d95eda3924c309a5589e265f734332f2b65100364be90";
    let bytes = hex::decode(hex_str).unwrap();
    let mut array = [0u8; 32];
    array.copy_from_slice(&bytes);
    let endpoint_id = iroh::EndpointId::from(array);
    println!("Base32 string: {}", endpoint_id.to_string());
    println!("Parsed from hex? {}", endpoint_id.to_string() == endpoint_id.to_string());
}
