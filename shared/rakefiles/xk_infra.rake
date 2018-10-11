task :refresh_common_infra, [:project_type] => [@gcp_creds_file] do | taskname, args|

  next if args[:project_type] == "common"

  # The common infrastructure might create the DNS resources, in order to avoid
  # conflicts at the creation resources we need to import the already created
  # DNS zone.

  dns_zone_found = %x{
    #{@exekube_cmd} sh -c " \
    terragrunt state show module.gke_network.google_dns_managed_zone.dns_zones \
    --terragrunt-working-dir /project/live/#{@env}/infra/network 2>/dev/null \
  "}

  if dns_zone_found.empty?
    # The DNS zone is not in the TF state file, we need to add it
    puts "DNS zone #{ENV["TF_VAR_domain_name"].tr('.','-')} not found in TF state, importing..."
    sh "#{@exekube_cmd} sh -c ' \
      terragrunt import module.gke_network.google_dns_managed_zone.dns_zones #{ENV["TF_VAR_domain_name"].tr('.','-')} \
      --terragrunt-working-dir /project/live/#{@env}/infra/network \
    '"
  else
    # The DNS zone is in the TF state file, we will refresh it just in case
    puts "DNS zone #{ENV["TF_VAR_domain_name"].tr('.','-')} found in TF state, refreshing..."
    sh "#{@exekube_cmd} sh -c ' \
      terragrunt refresh \
      --terragrunt-working-dir /project/live/#{@env}/infra/network \
    '"
  end
end

task :apply_common_infra => [@gcp_creds_file] do
  # Steps to initialize GCP with a minimum set of resources to allow Terraform
  # create the rest of the infrastructure.
  # These steps are the same found in this tutorial:
  # https://cloud.google.com/community/tutorials/managing-gcp-projects-with-terraform
  #
  # Due to the needed permissions for creating the following resources, only an
  # administrator of the organization can run this task.

  projects_list = %x{
    #{@exekube_cmd} gcloud projects list --format='json' --filter='name:#{ENV["TF_VAR_project_id"]}'
  }
  projects_list = JSON.parse(projects_list)
  if projects_list.empty?
    puts "#{ENV["TF_VAR_project_id"]} not found, I'll create a new one"
    sh "#{@exekube_cmd} gcloud projects create #{ENV["TF_VAR_project_id"]} \
      --organization #{ENV["ORGANIZATION_ID"]} \
      --set-as-default"
  else
    Rake::Task[:configure_current_project].invoke
  end

  sh "#{@exekube_cmd} gcloud beta billing projects link #{ENV["TF_VAR_project_id"]} \
    --billing-account #{ENV["BILLING_ID"]}"

  sa_list = %x{
    #{@exekube_cmd} gcloud iam service-accounts list --format='json' \
    --filter='email:projectowner@#{ENV["TF_VAR_project_id"]}.iam.gserviceaccount.com'
  }
  sa_list = JSON.parse(sa_list)
  if sa_list.empty?
    sh "#{@exekube_cmd} gcloud iam service-accounts create projectowner --display-name 'CI account'"
  end

  Rake::Task[:configure_serviceaccount].invoke

  ["roles/viewer", "roles/storage.admin", "roles/dns.admin"].each do |role|
    sh "#{@exekube_cmd} gcloud projects add-iam-policy-binding #{ENV["TF_VAR_project_id"]} \
      --member serviceAccount:projectowner@#{ENV["TF_VAR_project_id"]}.iam.gserviceaccount.com \
      --role #{role}"
  end

  services_list = %x{
    #{@exekube_cmd} gcloud services list --format='json'
  }
  services_list = JSON.parse(services_list)

  ["cloudresourcemanager.googleapis.com",
   "cloudbilling.googleapis.com",
   "iam.googleapis.com",
   "dns.googleapis.com",
   "compute.googleapis.com"].each do |service|
     sh "#{@exekube_cmd} gcloud services enable #{service}" unless services_list.any? { |s| s['serviceName'] == service }
  end

  ["roles/resourcemanager.projectCreator", "roles/billing.user"].each do |role|
    sh "#{@exekube_cmd} gcloud organizations add-iam-policy-binding #{ENV["ORGANIZATION_ID"]} \
      --member serviceAccount:projectowner@#{ENV["TF_VAR_project_id"]}.iam.gserviceaccount.com --role #{role}"
  end

  tfstate_bucket = %x{
    #{@exekube_cmd} gsutil ls | grep 'gs://#{ENV["TF_VAR_project_id"]}-tfstate'
  }
  unless tfstate_bucket
    sh "#{@exekube_cmd} gsutil mb gs://#{ENV["TF_VAR_project_id"]}-tfstate"
    sh "#{@exekube_cmd} gsutil versioning set on gs://#{ENV["TF_VAR_project_id"]}-tfstate"
  end
end