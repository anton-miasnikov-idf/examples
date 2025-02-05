# Infrastructure for the Yandex Cloud Managed Service for Redis sharded cluster and Virtual Machine
#
# RU: https://cloud.yandex.ru/docs/managed-redis/tutorials/redis-as-php-sessions-storage
# EN: https://cloud.yandex.com/en/docs/managed-redis/tutorials/redis-as-php-sessions-storage
#
# Set the following settings:
#
# * Password for the Yandex Managed Service for Redis cluster
# * Virtual Machine
#     * Image ID: https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list
#     * Username (for Ubuntu images used `ubuntu` name)
#     * Path to public part of SSH key


resource "yandex_vpc_network" "redis-and-vm-network" {
  name        = "redis-and-vm-network"
  description = "Network for the Managed Service for Redis cluster and VM."
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.redis-and-vm-network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Subnet in ru-central1-b availability zone
resource "yandex_vpc_subnet" "subnet-b" {
  name           = "subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.redis-and-vm-network.id
  v4_cidr_blocks = ["10.2.0.0/16"]
}

# Subnet in ru-central1-c availability zone
resource "yandex_vpc_subnet" "subnet-c" {
  name           = "subnet-c"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.redis-and-vm-network.id
  v4_cidr_blocks = ["10.3.0.0/16"]
}

# Security group for the Managed Service for Redis cluster and VM
resource "yandex_vpc_default_security_group" "redis-and-vm-security-group" {
  network_id = yandex_vpc_network.redis-and-vm-network.id

  ingress {
    protocol       = "TCP"
    description    = "Allow incoming HTTP connections from the Internet"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow incoming HTTPS connections from the Internet"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow incoming connections to cluster from the Internet"
    port           = 6379
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow incoming SSH connections to VM from the Internet"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow outgoing connections to any required resource"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Managed Service for Redis cluster
resource "yandex_mdb_redis_cluster" "redis-cluster" {
  name               = "redis-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.redis-and-vm-network.id
  security_group_ids = [yandex_vpc_default_security_group.redis-and-vm-security-group.id]
  sharded            = true

  config {
    password = ""    # Set the password
    version  = "6.2" # Version of the Redis
  }

  resources {
    resource_preset_id = "hm2.nano"
    disk_type_id       = "network-ssd"
    disk_size          = 16 # GB
  }

  host {
    zone       = "ru-central1-a"
    subnet_id  = yandex_vpc_subnet.subnet-a.id
    shard_name = "shard1"
  }

  host {
    zone       = "ru-central1-b"
    subnet_id  = yandex_vpc_subnet.subnet-b.id
    shard_name = "shard2"
  }

  host {
    zone       = "ru-central1-c"
    subnet_id  = yandex_vpc_subnet.subnet-c.id
    shard_name = "shard3"
  }
}

# Compute Virtual Machine
resource "yandex_compute_instance" "lamp-vm" {

  name        = "lamp-vm"
  platform_id = "standard-v3" # Intel Ice Lake

  resources {
    cores  = 2
    memory = 2 # GB
  }

  boot_disk {
    initialize_params {
      image_id = "" # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = true # Required for connection from the Internet
  }

  metadata = {
    ssh-keys = "<username>:${file("<path for SSH public key>")}" # Set username and path for SSH public key
  }
}
