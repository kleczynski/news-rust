use std::io::Error;

use zero2prod::run;
use zero2prod::start_listen;

#[tokio::main]
async fn main() -> Result<(), Error> {
    let listener = start_listen();
    run(listener)?.await
}
