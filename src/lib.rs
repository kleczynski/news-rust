use std::{io::Error, net::TcpListener};

use actix_web::{App, HttpResponse, HttpServer, dev::Server, web};
use serde::Deserialize;

#[derive(Deserialize)]
struct FormaData {
    email: String,
    name: String,
}

pub fn start_listen() -> TcpListener {
    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind random address");

    listener
}

async fn health_check() -> HttpResponse {
    HttpResponse::Ok().finish()
}

async fn subscribe(_form: web::Form<FormaData>) -> HttpResponse {
    HttpResponse::Ok().finish()
}

pub fn run(listener: TcpListener) -> Result<Server, Error> {
    let server = HttpServer::new(|| {
        App::new()
            .route("/health_check", web::get().to(health_check))
            .route("/subscriptions", web::post().to(subscribe))
    })
    .listen(listener)?
    .run();
    Ok(server)
}
