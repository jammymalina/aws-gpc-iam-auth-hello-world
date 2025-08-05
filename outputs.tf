output "function_uri" {
  value = google_cloudfunctions2_function.main.service_config[0].uri
}
