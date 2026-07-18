fn main() {
    let s = "test";
    let a: std::result::Result<iroh::EndpointAddr, _> = s.parse();
}
