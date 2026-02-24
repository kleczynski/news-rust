use actix_web::{HttpResponse, web};
use serde::Deserialize;

use crate::startup::spawn_app;

#[derive(Deserialize)]
pub struct FormaData {
    email: String,
    name: String,
}

pub async fn subscribe(_form: web::Form<FormaData>) -> HttpResponse {
    HttpResponse::Ok().finish()
}
