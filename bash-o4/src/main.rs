fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    std::process::exit(bash_o4::cli(&args));
}
