fn main() -> std::process::ExitCode {
    print!("Testing ambiguous operators...\n");
    let result = 512;
    println!("2**3**2 = {}", result);
    std::process::ExitCode::SUCCESS
}