fn __sh_env(n: &str) -> String {
    std::env::var(n).unwrap_or_default()
}

fn main() -> std::process::ExitCode {
    if !{ let __v = __sh_env("MYVAR"); if __v.is_empty() { String::new() } else { "set".to_string() } }.is_empty() {
        print!("MYVAR is set\n");
    } else {
    }
    std::process::ExitCode::SUCCESS
}