fn main() {
    // Before anything can write to stdout (see the fn docs).
    bash_o4::restore_sigpipe_default();
    let args: Vec<String> = std::env::args().skip(1).collect();
    std::process::exit(bash_o4::cli(&args));
}
