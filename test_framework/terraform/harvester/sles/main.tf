terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 8.5.0"
    }
  }
}

provider "rancher2" {
  api_url   = var.lab_url
  insecure  = true
  access_key = var.lab_access_key
  secret_key = var.lab_secret_key
}

resource "random_string" "random_suffix" {
  length           = 8
  special          = false
  lower            = true
  upper            = false
}

data "rancher2_cluster_v2" "hal-cluster" {
  name = "hal"
}

resource "rancher2_cloud_credential" "e2e-credential" {
  name = "e2e-credential-${random_string.random_suffix.id}"
  harvester_credential_config {
    cluster_id = data.rancher2_cluster_v2.hal-cluster.cluster_v1_id
    cluster_type = "imported"
    kubeconfig_content = data.rancher2_cluster_v2.hal-cluster.kube_config
  }
}

resource "rancher2_machine_config_v2" "e2e-machine-config-controlplane" {

  generate_name = "e2e-machine-config-controlplane-${random_string.random_suffix.id}"

  depends_on = [rancher2_cloud_credential.e2e-credential]

  harvester_config {

    vm_namespace = "longhorn-qa"

    cpu_count = "8"
    memory_size = "16"

    disk_info = <<EOF
    {
        "disks": [{
            "imageName": "longhorn-qa/image-qzfjl",
            "size": ${var.block_device_size_controlplane},
            "bootOrder": 1
        }]
    }
    EOF

    network_info = <<EOF
    {
        "interfaces": [{
            "networkName": "longhorn-qa/vlan-2011"
        }]
    }
    EOF

    ssh_user = "sles"

    user_data = <<EOF
#cloud-config
ssh_authorized_keys:
  - >-
    ${file(var.ssh_public_key_file_path)}
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDEzxJar4pg7+gL4XmFW2vgqYcuKBsTBc1AVe8e8citD8dj+CAmKz2kiTC4g423w35rk5dRk8ucjDOv8lhurlE5qPdkOKjWWfzDyWsuaJGjadCDYYvfmoP+v9XIuUD+aokoP/3DHg1S8zZCLGcuF69asyWW4gbr6TydqdKz5HwylUl7f8/uTd+yTjOadJ2Xtvn8aUsV0Yt9bT1H6BnAliJPwcWbvIEdb8bsIo9b6+AzT/vx7aD8KFYgFNTFeK3Kl3+swQxsjJQ2zi+0m1paBJYb9eUyGYC0VTbD+ZsjbUR5zT+KZ8tbBXGDiIgerdMb+/+ju642wBPZNR5EkPExP36uV0JWpE+jeX8s7zoaiwZVIL/LujoaE87lKzf+S71KDXn3+zvpUwYQfo6zfZ7rWic92zZ/hkACkSqMDodzhZpm4m33rmmcvxLLeu7qJhH6hSqxhc0XCNwZNZfNgZ95ptb87OyU5PHJm6USWrC6ylKrMf/HZHObzrhInMGlr1Bn61tcqbAcz29gmDaSnnzSHqHrTUEzhT8daifQToyHV0hmQASQ6m7H4APSLQ2hGkcBE5vyPWc1ZFbwS43AQnFjng0EAd0T2uB6XgSxnjXxuJxULQx/FMsqScHggVX5wOnZvCaAdOd/Lt8kcjabLS6nWpcpurypApT0/UQwz6IQnJDUtw==
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCyoFC8gCOuI0hZezVNeby3wCIZu5VaS0yH3Kf+QDeZ4JntScpmrs1fRUvJUJqSXSU/wD58eT5RIzWIoC07kXwXIKT+ODanIhMc+GToy9OlBTsJbX4hLJXJQHX36/Bl3KDwR9BHHH0LFAGC6nZ9t7RoQmfYG8LvJinoU9CdV4OwAKxCjwHBdelpq2VmhHSc2vrUGN4B8bUHDlaT0A0f2cFXaBpMtf83j6/VXLA+bwUth3cmap1FZqTSc8sFVK8fgR8fJDfC3US4teguoVP66GPIW+tox933GVwJ2MPGQLh/Ozh5HH1KCdjraLvzQa+CF3pmrkZEwMu5+JzBrITdnZavgYOzrJuqJepQaLLeprILoI0YZaX8lETkSRqFKu5wiu5MgDSmCMvMSpraPvMgjxiQH+H9kFea9RncBCVHXDceBW2TIlk+kNJ4gq+J4oRzbB/j3/U80d6aYjBJ7g5QFCebpblJfH+9kg9oDhD26kwVejCrdHBLSH8QfEpm1wwPToDFdDgaRaKD3Jc3BGnuQpyYeGJcO5Gz5xVSGJFTHOLutXnqlVjdb1GaNJNfeIIOJeckmCrPFPJu2nPos3cVUjW0vmv3FW1cjEULu6hV3HthBXXwqlril+jxzPrclV8rWcbGFxdXvy0KWFK9nwT/2VrcQgE/YNhJfYv3sZ9BRSZ9Jw==
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCksKyQcOefu3yOGiUYgwCkVQiTcfd0ZXy78F3eT8Iyu54VtAiKqTuvSQwptszexifMumIXg5H2hL8aBy0/3szr2jGY6kvU0pR5s2TWqbmOJWd+jZqfYXiYT69sXqQUvqvSPLlliOGgBA2Uj/wvQ1y1INbYO/8K5CmPick7j0eSfA2qCXtwyOy8frWMnyD6hPI0Hy52FHtG5Mbh2t4YpftyZJcNPh6tszO2o+9jGC7pndgqsIUlifKuGN84GbEX2YeK6nNALO7g39pKQHceENJST2qoIRO7SoQOCLLUWXS+d4sPs76uOIiKikUvJeSn1gF44FPPvU+bCm+usRgj+XyKgu2lyrLnb4bYSX+pvw1i8y/DTy60L6lLco0w2XpxRiTOD8PZtBWQD2vowjqOUuk4m/nDX1tltWl/IdOtlnplwmgGsMOw9cWP9QIbKBsAWzmqqGBAREEnK1vX1oof/tUA+NW6H/ubcMD6rcsOQydLuCYXsCSYB5j7WuqSr1AMFAU5+jsUyDVPxnqk+uz8HCOdrmlYAWGcn+tw6tUPQEhAm/BAGOPNNTEU5LrimHfSPGFvvVAJ7JqwTkxnMYJq8jnWdCeI51RqdQ1aU5k/H8eiqKto4sHlkODSNH6YPHeA9VvNtmaFCc2EX2DgMe5VdImyxbtthibUySDEYbv33GrlTQ==
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6n+fZNbBYXQZM5WVRwWHUp0ocH37oEEdgIcGtXRHHfIKQ77UX4t8bYTlik1Tz5L8dxy7imm+8MXuH0/Ga10EvVKYmRVnw/p23R3LnDz0z3jMkrX8aN6QyMM+3TI0ciPwm9o0AU+yCMIffpFQHEEWyVZDZvc9LIZL93zTjYQpjp0Ld3JfCfRqVQnXKeplopNZyP9XoVEjdAIchrPUcXxWmIVvhOqMF1LsbKMnHQkifqK2gGGeR2mHIcnP95zwPFuKIA86WSfiYBCwglFpXJzKec/0MSoE4oD5kMuS33PAykOSzkmZtih29Ls1IMv7lO5tsNQeI5ZkX6VunZLOWG/O5J+iSiluM45sTeeyeD4yQtR+DmD56V493WifkhkoG3QTJqixK9Yl1oD45cpEI3yu1Tnc0rrTXMKrOOxXz9yvPVR+6e8M0lXgClPQTSDSBEZhLdgbXWfid1+czoK6GYqr9e+07zNE6yyuI8NJwIC96IFFxwP7EfmT1FvYBBy/5m+E=
  - ${var.custom_ssh_public_key}
runcmd:
  - SUSEConnect -r ${var.registration_code}
  - zypper install -y qemu-guest-agent iptables samba cifs-utils
  - - systemctl
    - enable
    - '--now'
    - qemu-guest-agent.service
EOF
  }
}

resource "rancher2_machine_config_v2" "e2e-machine-config-worker" {

  generate_name = "e2e-machine-config-worker-${random_string.random_suffix.id}"

  depends_on = [rancher2_cloud_credential.e2e-credential]

  harvester_config {

    vm_namespace = "longhorn-qa"

    cpu_count = "4"
    memory_size = "16"

    disk_info = <<EOF
    {
        "disks": [{
            "imageName": "longhorn-qa/image-qzfjl",
            "size": ${var.block_device_size_worker},
            "bootOrder": 1
        },
        {
            "storageClassName": "longhorn-v2",
            "size": ${var.block_device_size_worker},
            "bootOrder": 2
        }]
    }
    EOF

    network_info = <<EOF
    {
        "interfaces": [{
            "networkName": "longhorn-qa/vlan-2011"
        }]
    }
    EOF

    ssh_user = "sles"

    user_data = <<EOF
#cloud-config
ssh_authorized_keys:
  - >-
    ${file(var.ssh_public_key_file_path)}
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDEzxJar4pg7+gL4XmFW2vgqYcuKBsTBc1AVe8e8citD8dj+CAmKz2kiTC4g423w35rk5dRk8ucjDOv8lhurlE5qPdkOKjWWfzDyWsuaJGjadCDYYvfmoP+v9XIuUD+aokoP/3DHg1S8zZCLGcuF69asyWW4gbr6TydqdKz5HwylUl7f8/uTd+yTjOadJ2Xtvn8aUsV0Yt9bT1H6BnAliJPwcWbvIEdb8bsIo9b6+AzT/vx7aD8KFYgFNTFeK3Kl3+swQxsjJQ2zi+0m1paBJYb9eUyGYC0VTbD+ZsjbUR5zT+KZ8tbBXGDiIgerdMb+/+ju642wBPZNR5EkPExP36uV0JWpE+jeX8s7zoaiwZVIL/LujoaE87lKzf+S71KDXn3+zvpUwYQfo6zfZ7rWic92zZ/hkACkSqMDodzhZpm4m33rmmcvxLLeu7qJhH6hSqxhc0XCNwZNZfNgZ95ptb87OyU5PHJm6USWrC6ylKrMf/HZHObzrhInMGlr1Bn61tcqbAcz29gmDaSnnzSHqHrTUEzhT8daifQToyHV0hmQASQ6m7H4APSLQ2hGkcBE5vyPWc1ZFbwS43AQnFjng0EAd0T2uB6XgSxnjXxuJxULQx/FMsqScHggVX5wOnZvCaAdOd/Lt8kcjabLS6nWpcpurypApT0/UQwz6IQnJDUtw==
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCyoFC8gCOuI0hZezVNeby3wCIZu5VaS0yH3Kf+QDeZ4JntScpmrs1fRUvJUJqSXSU/wD58eT5RIzWIoC07kXwXIKT+ODanIhMc+GToy9OlBTsJbX4hLJXJQHX36/Bl3KDwR9BHHH0LFAGC6nZ9t7RoQmfYG8LvJinoU9CdV4OwAKxCjwHBdelpq2VmhHSc2vrUGN4B8bUHDlaT0A0f2cFXaBpMtf83j6/VXLA+bwUth3cmap1FZqTSc8sFVK8fgR8fJDfC3US4teguoVP66GPIW+tox933GVwJ2MPGQLh/Ozh5HH1KCdjraLvzQa+CF3pmrkZEwMu5+JzBrITdnZavgYOzrJuqJepQaLLeprILoI0YZaX8lETkSRqFKu5wiu5MgDSmCMvMSpraPvMgjxiQH+H9kFea9RncBCVHXDceBW2TIlk+kNJ4gq+J4oRzbB/j3/U80d6aYjBJ7g5QFCebpblJfH+9kg9oDhD26kwVejCrdHBLSH8QfEpm1wwPToDFdDgaRaKD3Jc3BGnuQpyYeGJcO5Gz5xVSGJFTHOLutXnqlVjdb1GaNJNfeIIOJeckmCrPFPJu2nPos3cVUjW0vmv3FW1cjEULu6hV3HthBXXwqlril+jxzPrclV8rWcbGFxdXvy0KWFK9nwT/2VrcQgE/YNhJfYv3sZ9BRSZ9Jw==
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCksKyQcOefu3yOGiUYgwCkVQiTcfd0ZXy78F3eT8Iyu54VtAiKqTuvSQwptszexifMumIXg5H2hL8aBy0/3szr2jGY6kvU0pR5s2TWqbmOJWd+jZqfYXiYT69sXqQUvqvSPLlliOGgBA2Uj/wvQ1y1INbYO/8K5CmPick7j0eSfA2qCXtwyOy8frWMnyD6hPI0Hy52FHtG5Mbh2t4YpftyZJcNPh6tszO2o+9jGC7pndgqsIUlifKuGN84GbEX2YeK6nNALO7g39pKQHceENJST2qoIRO7SoQOCLLUWXS+d4sPs76uOIiKikUvJeSn1gF44FPPvU+bCm+usRgj+XyKgu2lyrLnb4bYSX+pvw1i8y/DTy60L6lLco0w2XpxRiTOD8PZtBWQD2vowjqOUuk4m/nDX1tltWl/IdOtlnplwmgGsMOw9cWP9QIbKBsAWzmqqGBAREEnK1vX1oof/tUA+NW6H/ubcMD6rcsOQydLuCYXsCSYB5j7WuqSr1AMFAU5+jsUyDVPxnqk+uz8HCOdrmlYAWGcn+tw6tUPQEhAm/BAGOPNNTEU5LrimHfSPGFvvVAJ7JqwTkxnMYJq8jnWdCeI51RqdQ1aU5k/H8eiqKto4sHlkODSNH6YPHeA9VvNtmaFCc2EX2DgMe5VdImyxbtthibUySDEYbv33GrlTQ==
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6n+fZNbBYXQZM5WVRwWHUp0ocH37oEEdgIcGtXRHHfIKQ77UX4t8bYTlik1Tz5L8dxy7imm+8MXuH0/Ga10EvVKYmRVnw/p23R3LnDz0z3jMkrX8aN6QyMM+3TI0ciPwm9o0AU+yCMIffpFQHEEWyVZDZvc9LIZL93zTjYQpjp0Ld3JfCfRqVQnXKeplopNZyP9XoVEjdAIchrPUcXxWmIVvhOqMF1LsbKMnHQkifqK2gGGeR2mHIcnP95zwPFuKIA86WSfiYBCwglFpXJzKec/0MSoE4oD5kMuS33PAykOSzkmZtih29Ls1IMv7lO5tsNQeI5ZkX6VunZLOWG/O5J+iSiluM45sTeeyeD4yQtR+DmD56V493WifkhkoG3QTJqixK9Yl1oD45cpEI3yu1Tnc0rrTXMKrOOxXz9yvPVR+6e8M0lXgClPQTSDSBEZhLdgbXWfid1+czoK6GYqr9e+07zNE6yyuI8NJwIC96IFFxwP7EfmT1FvYBBy/5m+E=
  - ${var.custom_ssh_public_key}
write_files:
  - path: "/tmp/SUSE_Trust_Root_encoded.crt"
    content: >-
      ${fileexists("/usr/local/share/ca-certificates/SUSE_Trust_Root.crt")
      ? filebase64("/usr/local/share/ca-certificates/SUSE_Trust_Root.crt")
      : ""}
runcmd:
  - SUSEConnect -r ${var.registration_code}
  - zypper install -y qemu-guest-agent iptables open-iscsi nfs-client cryptsetup device-mapper samba cifs-utils
  - zypper -n install --force-resolution kernel-default
  - - systemctl
    - enable
    - '--now'
    - qemu-guest-agent.service
  - systemctl enable iscsid
  - systemctl start iscsid
  - touch /etc/modules-load.d/modules.conf
  - echo uio >> /etc/modules-load.d/modules.conf
  - echo uio_pci_generic >> /etc/modules-load.d/modules.conf
  - echo vfio_pci >> /etc/modules-load.d/modules.conf
  - echo nvme-tcp >> /etc/modules-load.d/modules.conf
  - echo dm_crypt >> /etc/modules-load.d/modules.conf
  - echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
  - echo "vm.nr_hugepages=1024" >> /etc/sysctl.conf
  - base64 -d /tmp/SUSE_Trust_Root_encoded.crt > /tmp/SUSE_Trust_Root.crt
  - mkdir -p /etc/pki/trust/anchors/
  - cp /tmp/SUSE_Trust_Root.crt /etc/pki/trust/anchors/
  - update-ca-certificates
  - shutdown -r +1
EOF
  }
}

resource "rancher2_cluster_v2" "e2e-cluster" {

  name = "e2e-cluster-${random_string.random_suffix.id}"

  depends_on = [
    rancher2_cloud_credential.e2e-credential,
    rancher2_machine_config_v2.e2e-machine-config-controlplane,
    rancher2_machine_config_v2.e2e-machine-config-worker
  ]

  timeouts {
    create = "90m"
  }

  kubernetes_version = var.k8s_distro_version

  rke_config {
    machine_pools {
      name = "control-plane-pool"
      cloud_credential_secret_name = rancher2_cloud_credential.e2e-credential.id
      control_plane_role = true
      etcd_role = true
      worker_role = false
      quantity = 1
      machine_config {
        kind = rancher2_machine_config_v2.e2e-machine-config-controlplane.kind
        name = rancher2_machine_config_v2.e2e-machine-config-controlplane.name
      }
    }
    machine_pools {
      name = "worker-pool"
      cloud_credential_secret_name = rancher2_cloud_credential.e2e-credential.id
      control_plane_role = false
      etcd_role = false
      worker_role = true
      quantity = 3
      machine_config {
        kind = rancher2_machine_config_v2.e2e-machine-config-worker.kind
        name = rancher2_machine_config_v2.e2e-machine-config-worker.name
      }
    }
    machine_selector_config {
      config = <<EOF
        cloud-provider-name: ""
EOF
    }
    machine_global_config = <<EOF
cni: "calico"
disable-kube-proxy: false
etcd-expose-metrics: false
EOF
    etcd {
      disable_snapshots = true
    }
    chart_values = ""
  }
}

resource "rancher2_cluster_role_template_binding" "dev-longhorn" {
  name = "dev-longhorn-binding"
  cluster_id = rancher2_cluster_v2.e2e-cluster.cluster_v1_id
  role_template_id = "cluster-owner"
  group_principal_id = "github_team://3300040"  
}

resource "rancher2_cluster_role_template_binding" "qa-longhorn" {
  name = "qa-longhorn-binding"
  cluster_id = rancher2_cluster_v2.e2e-cluster.cluster_v1_id
  role_template_id = "cluster-owner"
  group_principal_id = "github_team://10714512"  
}

output "kube_config" {
  value = rancher2_cluster_v2.e2e-cluster.kube_config
  sensitive = true
}

output "cluster_id" {
  value = data.rancher2_cluster_v2.hal-cluster.cluster_v1_id
}
