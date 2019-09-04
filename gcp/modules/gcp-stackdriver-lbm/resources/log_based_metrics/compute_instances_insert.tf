resource "google_logging_metric" "compute_instances_insert" {
  name   = "compute.instances.insert"
  filter = "resource.type=\"gce_instance\" AND (protoPayload.methodName=\"beta.compute.instances.insert\" OR protoPayload.methodName=\"compute.instances.insert\") AND protoPayload.authenticationInfo.principalEmail!=\"${organization_id}@cloudservices.gserviceaccount.com\""
}
