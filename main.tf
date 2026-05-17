terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}
provider "yandex" {
  token = "${var.yc_token}"
  cloud_id  = "b1ggel59310trksk1fu4"
  folder_id = "b1g9oing6niujio3j61t"
  zone      = "ru-central1-a"
}
data "template_file" "metadata" {
  template = file("./metadata.yaml")
}
resource "yandex_compute_instance_group" "ig-1" {
  name               = "fixed-ig-with-balancer"
  folder_id          = "b1g9oing6niujio3j61t"
  service_account_id = "ajer9g2i8khs2tjf74b7"
  instance_template {
    platform_id = "standard-v3"
    resources {
      core_fraction = 50
      cores  = 2
      memory = 4
    }
    boot_disk {
      initialize_params {
        image_id = "fd8ps4vdhf5hhuj8obp2"
        size = 10
        type = "network-ssd"
      }
    }
    network_interface {
      network_id = "${yandex_vpc_network.network-2.id}"
      subnet_ids = ["${yandex_vpc_subnet.subnet-1.id}"]
      nat       = true
    }
    metadata = {
      user-data = data.template_file.metadata.rendered
    }
    scheduling_policy {
      preemptible = true
    }
  }
  scale_policy {
    fixed_scale {
      size = 2
    }
  }
  allocation_policy {
    zones = ["ru-central1-a"]
  }
  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }
  load_balancer {
    target_group_name        = "target-group"
    target_group_description = "load balancer target group"
  }
}

resource "yandex_vpc_network" "network-2" {
  name = "network2"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-2.id
  v4_cidr_blocks = ["192.168.1.0/24"]
}

resource "yandex_lb_network_load_balancer" "lb-1" {
  name = "network-load-balancer-1"

  listener {
    name = "network-load-balancer-1-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.ig-1.load_balancer.0.target_group_id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

output "external_ip_addresses" {
  value = yandex_compute_instance_group.ig-1.instances.*.network_interface.0.nat_ip_address
  # value = [
  #   for instance_template in yandex_compute_instance_group.ig-1.instance_template :
  #   instance_template.network_interface.0.nat_ip_address
  # ]
}

output "external_ip_address_lb" {
  value = [
    for listener in yandex_lb_network_load_balancer.lb-1.listener :
    listener.external_address_spec
  ]
}