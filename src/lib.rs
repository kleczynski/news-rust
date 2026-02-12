use std::{io::Error, net::TcpListener};

use actix_web::{App, HttpResponse, HttpServer, Responder, dev::Server, web};

pub fn start_listen() -> TcpListener {
    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind random address");

    listener
}

async fn health_check() -> impl Responder {
    HttpResponse::Ok().finish()
}

pub fn run(listener: TcpListener) -> Result<Server, Error> {
    let server = HttpServer::new(|| App::new().route("health_check", web::get().to(health_check)))
        .listen(listener)?
        .run();
    Ok(server)
}
