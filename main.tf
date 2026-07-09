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

# Automatically fetch project metadata (including the project number)
data "google_project" "project" {
  project_id = "thecloudresumechallenge"
}

# 4. Allow Cloud Datastore User role to Cloud Run service account
resource "google_project_iam_member" "counter_api_firestore_access" {
  project = "thecloudresumechallenge"
  role    = "roles/datastore.user"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# 5. Cloud Run Admin Role to manage the counter service revisions
resource "google_project_iam_member" "cloudbuild_run_admin" {
  project = "thecloudresumechallenge"
  role    = "roles/run.admin"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# 6. Service Account User Role to deploy the container with its runtime service account)
resource "google_project_iam_member" "cloudbuild_sa_user" {
  project = "thecloudresumechallenge"
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# 7. Artifact Registry Writer Role to push the buildpacks container image)
resource "google_project_iam_member" "cloudbuild_registry_writer" {
  project = "thecloudresumechallenge"
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}
