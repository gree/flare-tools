use flare_tools::FlareClient;

fn main() {
    let mut client = FlareClient::new("flared1".to_string(), 12121);
    
    println!("Testing connection...");
    match client.ping() {
        Ok(()) => println!("Ping successful"),
        Err(e) => println!("Ping failed: {}", e),
    }
    
    println!("Testing set operation...");
    match client.set_key_value("testkey", 0, 0, b"testvalue") {
        Ok(()) => println!("Set successful"),
        Err(e) => println!("Set failed: {}", e),
    }
    
    println!("Testing get operation...");
    match client.get_key_value("testkey") {
        Ok(Some(value)) => println!("Get successful: {}", String::from_utf8_lossy(&value)),
        Ok(None) => println!("Key not found"),
        Err(e) => println!("Get failed: {}", e),
    }
}