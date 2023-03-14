# Configure the GCP provider
provider "google" {
  project = "my-gcp-project"
  region  = "us-central1"
}

# Create a VPC network
resource "google_compute_network" "example" {
  name                    = "example-vpc"
  auto_create_subnetworks = false

  routing_mode = "REGIONAL"
}

# Create three subnets in three different regions
resource "google_compute_subnetwork" "example" {
  count     = 3
  name      = "example-subnet-${count.index}"
  region    = "us-central1"
  network   = google_compute_network.example.self_link
  ip_cidr_range = "10.${count.index}.0.0/16"
}

# Create a firewall rule to allow incoming HTTP and SSH traffic
resource "google_compute_firewall" "example" {
  name        = "example-fw"
  network     = google_compute_network.example.self_link

  allow {
    protocol = "tcp"
    ports    = ["80", "22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Create a managed instance group with an autoscaling policy
resource "google_compute_instance_template" "example" {
  name_prefix = "example-it"
  machine_type = "n1-standard-1"
  region = "us-central1"
  network_interface {
    network = google_compute_network.example.self_link
    subnetwork = google_compute_subnetwork.example.*.self_link[count.index]
    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    echo "Hello, World!" > index.html
    nohup python -m SimpleHTTPServer 80 &
  EOF
}

resource "google_compute_instance_group_manager" "example" {
  name = "example-igm"
  base_instance_name = "example-vm"
  instance_template = google_compute_instance_template.example.self_link
  target_size = 2

  autoscaler {
    cooldown_period = 60
    cpu_utilization {
      target = 0.8
    }
  }

  named_port {
    name = "http"
    port = 80
  }

  zone = "us-central1-a"
}

# Create a HTTP(S) load balancer
resource "google_compute_global_forwarding_rule" "example" {
  name       = "example-lb"
  ip_address = null

  port_range = "80-80"

  target = google_compute_target_http_proxy.example.self_link
}

resource "google_compute_backend_service" "example" {
  name                = "example-backend"
  protocol            = "HTTP"
  timeout_sec         = 10
  enable_cdn          = false

  backend {
    group = google_compute_instance_group_manager.example.self_link
  }

  health_checks = [
    google_compute_http_health_check.example.self_link
  ]
}

resource "google_compute_url_map" "example" {
  name            = "example-url-map"
  default_service = google_compute_backend_service.example.self_link

  host_rule {
    hosts = ["example.com"]
  }

  path_matcher {
    name = "example-path-matcher"
    default_service = google_compute_backend_service.example.self_link
    path_rules {
      paths = ["/"]
      service = google_compute_backend_service.example.self_link
    }
  }
}

resource "google_compute_http_health_check" "example" {
  name                = "example-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
  request_path        = "/"
  port                = 80
}

resource "google_compute_target_http_proxy" "example" {
  name        = "example-proxy"
  url_map     = google_compute_url_map.example.self_link
  description = "HTTP Proxy for example"
}

resource "google_compute_global_forwarding_rule" "example-https" {
  name       = "example-https-lb"
  ip_address = null

  port_range = "443-443"

  target = google_compute_target_https_proxy.example.self_link
}

resource "google_compute_backend_service" "example-https" {
  name                = "example-https-backend"
  protocol            = "HTTPS"
  timeout_sec         = 10
  enable_cdn          = false

  backend {
    group = google_compute_instance_group_manager.example.self_link
  }

  health_checks = [
    google_compute_http_health_check.example.self_link
  ]
}

resource "google_compute_ssl_certificate" "example" {
  name        = "example-certificate"
  description = "SSL certificate for example.com"
  certificate = file("example.crt")
  private_key = file("example.key")
}

resource "google_compute_target_https_proxy" "example" {
  name                 = "example-https-proxy"
  ssl_certificates     = [google_compute_ssl_certificate.example.self_link]
  url_map              = google_compute_url_map.example.self_link
  quic_override        = "NONE"
  ssl_policy           = "MODERN"
  security_policy      = google_compute_security_policy.example.self_link
  backend_service      = google_compute_backend_service.example-https.self_link
  validate_for_proxyless = false
  description = "HTTPS Proxy for example"
}

resource "google_compute_security_policy" "example" {
  name = "example-security-policy"

  rule {
    action = "allow"
    description = "Allow inbound HTTP and HTTPS traffic"
    direction = "INGRESS"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["0.0.0.0/0"]
      }
    }
    target {
      service = "tcp:80"
    }
    target {
      service = "tcp:443"
    }
  }
}
 
