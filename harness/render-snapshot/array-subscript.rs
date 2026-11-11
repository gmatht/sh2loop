fn main() -> std::process::ExitCode {
    let arr = ["a".to_string(), "b".to_string(), "c".to_string()];
    println!("{}", arr[1].clone());
    std::process::ExitCode::SUCCESS
}