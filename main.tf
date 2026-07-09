terraform {
  backend "gcs" {
    bucket = "thecloudresumechallenge-terraform-state" 
    prefix = "terraform/state"
  }
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "thecloudresumechallenge"
  region  = "us-central1"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

# 1. Reference your existing Firestore Database (or create it via code)
resource "google_firestore_database" "database" {
  project     = "thecloudresumechallenge"
  name        = "(default)"
  location_id = "us-central1"
  type        = "FIRESTORE_NATIVE"
}

# 2. Define your Cloud Run Function service
resource "google_cloud_run_v2_service" "counter_api" {
  name     = "thecloudresumechallenge-counter-api"
  location = "us-central1"
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    scaling {
      max_instance_count = 3
      min_instance_count = 0
    }
    containers {
      image = "us-central1-docker.pkg.dev/thecloudresumechallenge/cloud-run-source-deploy/thecloudresumechallenge-counter-api:${var.image_tag}"
      env {
        name  = "GOOGLE_FUNCTION_TARGET"
        value = "visitor_counter"
      }

      env {
        name  = "GOOGLE_FUNCTION_SIGNATURE_TYPE"
        value = "http"
      }
    }
  }
}

# 3. Allow Public Unauthenticated Access to the API
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  name     = google_cloud_run_v2_service.counter_api.name
  location = google_cloud_run_v2_service.counter_api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
