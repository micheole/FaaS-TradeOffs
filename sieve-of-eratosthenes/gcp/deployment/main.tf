provider "google" {
  project = "sieve-of-eratosthenes"
  region  = "europe-west3"
}

data "archive_file" "function_code" {
  type        = "zip"
  source_dir  = "${path.module}/../src" 
  output_path = "${path.module}/function.zip"
}

resource "google_storage_bucket" "function_bucket" {
  name     = "sieve-of-eratosthenes"
  location = "europe-west3"
  force_destroy = true
}

resource "google_storage_bucket_object" "function_zip" {
  name   = "function.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = data.archive_file.function_code.output_path
}

resource "google_service_account" "function_sa" {
  account_id   = "function-service-account"
  display_name = "Service Account for Cloud Function"
}

resource "google_cloudfunctions_function_iam_member" "public_invoker" {
  project        = "sieve-of-eratosthenes"
  region         = "europe-west3"
  cloud_function = google_cloudfunctions_function.cloud_function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}

resource "google_cloudfunctions_function" "cloud_function" {
  name                  = "json_terraform_gcp_function_eratosthenes"
  description           = "Cloud Function for executing Eratosthenes simulations"
  runtime               = "nodejs20"
  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.function_zip.name
  entry_point           = "sieveOfEratosthenes"

  trigger_http          = true
  service_account_email = google_service_account.function_sa.email
}

output "function_url" {
  value = google_cloudfunctions_function.cloud_function.https_trigger_url
}