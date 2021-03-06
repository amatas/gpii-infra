resource "google_monitoring_alert_policy" "gke_cluster_create" {
  display_name = "GKE audit log does not contain cluster creation events"
  combiner     = "OR"
  depends_on   = ["google_logging_metric.gke_cluster_create"]

  conditions {
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/gke_cluster.create\" resource.type=\"global\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.0
      duration        = "0s"

      aggregations {
        alignment_period   = "600s"
        per_series_aligner = "ALIGN_SUM"
      }

      denominator_filter = ""
    }

    display_name = "GKE cluster creation event found in the audit log"
  }

  documentation = {
    content   = "[Use this link to explore policy events in Logs Viewer](https://console.cloud.google.com/logs/viewer?project=${var.project_id}&minLogLevel=0&expandAll=false&interval=PT1H&advancedFilter=resource.type%3D%22gke_cluster%22%20AND%20protoPayload.methodName%3D%22google.container.v1beta1.ClusterManager.CreateCluster%22)"
    mime_type = "text/markdown"
  }

  notification_channels = ["${google_monitoring_notification_channel.email.name}", "${google_monitoring_notification_channel.alerts_slack.*.name}"]
  enabled               = "true"

  depends_on = ["google_logging_metric.gke_cluster_create"]
}
