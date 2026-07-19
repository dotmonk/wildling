use std::env;
use std::process;
use wildling::run_cli;

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    process::exit(run_cli(&args));
}
