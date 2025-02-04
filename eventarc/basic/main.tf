/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# [START eventarc_basic_parent_tag]
# [START eventarc_terraform_enableapis]
# Used to retrieve project_number later
data "google_project" "project" {
  provider = google-beta
}

# Enable Cloud Run API
resource "google_project_service" "run" {
  provider           = google-beta
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# Enable Eventarc API
resource "google_project_service" "eventarc" {
  provider           = google-beta
  service            = "eventarc.googleapis.com"
  disable_on_destroy = false
}

# [END eventarc_terraform_enableapis]

# [START cloudrun_terraform_deploy_eventarc]

# Deploy Cloud Run service
resource "google_cloud_run_service" "default" {
  provider = google-beta
  name     = "cloudrun-hello-tf"
  location = "us-east1"

  template {
    spec {
      containers {
        image = "gcr.io/cloudrun/hello"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.run]
}

# [END cloudrun_terraform_deploy_eventarc]

# [START eventarc_terraform_pubsub]

# Create a Pub/Sub trigger
resource "google_eventarc_trigger" "trigger_pubsub_tf" {
  provider = google-beta
  name     = "trigger-pubsub-tf"
  location = google_cloud_run_service.default.location
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }
  destination {
    cloud_run_service {
      service = google_cloud_run_service.default.name
      region  = google_cloud_run_service.default.location
    }
  }

  service_account = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"

  depends_on = [google_project_service.eventarc]
}

# [END eventarc_terraform_pubsub]
# [START eventarc_terraform_auditlog_storage]

# Give default Compute service account eventarc.eventReceiver role
resource "google_project_iam_binding" "project" {
  provider = google-beta
  project  = data.google_project.project.id
  role     = "roles/eventarc.eventReceiver"

  members = [
    "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  ]
}

# Create an AuditLog for Cloud Storage trigger
resource "google_eventarc_trigger" "trigger_auditlog_tf" {
  provider = google-beta
  name     = "trigger-auditlog-tf"
  location = google_cloud_run_service.default.location
  project  = data.google_project.project.id
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.audit.log.v1.written"
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "storage.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "storage.objects.create"
  }
  destination {
    cloud_run_service {
      service = google_cloud_run_service.default.name
      region  = google_cloud_run_service.default.location
    }
  }
  service_account = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"

  depends_on = [google_project_service.eventarc]
}

# [END eventarc_terraform_auditlog_storage]
# [END eventarc_basic_parent_tag]
