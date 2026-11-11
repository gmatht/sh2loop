static __SH_ARGV: std::sync::Mutex<Vec<String>> = std::sync::Mutex::new(Vec::new());

fn __sh_arg(i: usize) -> String {
    __SH_ARGV.lock().unwrap().get(i).cloned().unwrap_or_default()
}

fn main() -> std::process::ExitCode {
    if __sh_arg(0) == "a".to_string() {
        if __sh_arg(1) == "x".to_string() {
            print!("x\n");
        } else {
        }
    } else if __sh_arg(0) == "b".to_string() {
        print!("b\n");
    } else {
    }
    std::process::ExitCode::SUCCESS
}