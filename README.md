

---

# 🚀 Terraform 기반 K8s 클러스터 구축 후 가이드

이 문서는 Terraform을 통해 생성된 AWS EC2 인스턴스 위에서 쿠버네티스 클러스터를 초기화하고 구성하는 단계를 설명합니다.

## 📌 사전 확인 사항

* 모든 인스턴스 생성이 완료된 후 **약 2~3분 뒤**에 접속하세요. (유저데이터 설치 시간 소요)
* 각 노드에 SSH로 접속하여 `kubeadm version` 명령어가 정상 작동하는지 확인합니다.

---

## 🏗️ 1. 마스터 노드 (Control Plane) 설정

마스터 노드 퍼블릭 IP로 접속한 뒤 다음 과정을 순서대로 진행합니다.

### 1.1 클러스터 초기화 (kubeadm init)

마스터 노드의 **사설 IP(Private IP)**를 확인한 후 클러스터를 초기화합니다.

```bash
# 사설 IP 확인 명령어
hostname -I

# 클러스터 초기화 (사설 IP 입력 필수)
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=<마스터-사설-IP>

```

> **중요:** 실행 후 마지막에 출력되는 `kubeadm join ...` 명령어를 별도로 복사해 두세요. (워커 노드 합류 시 사용)

### 1.2 kubectl 사용자 권한 설정

일반 유저(`ubuntu`)가 쿠버네티스 명령어를 사용할 수 있도록 설정합니다.

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

```

### 1.3 네트워크 플러그인 (Calico CNI) 설치

노드 간 통신 및 파드 네트워크 구성을 위해 Calico를 설치합니다.

```bash
# Calico Operator 설치
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml

# Calico 커스텀 리소스 배포
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml

```

---

## 👷 2. 워커 노드 (Worker Nodes) 설정

각 워커 노드(2대)에 개별적으로 접속하여 진행합니다.

### 2.1 필수 패키지 수동 설치

쿠버네티스 네트워크 추적을 위한 필수 도구를 설치합니다.

```bash
sudo apt-get update && sudo apt-get install -y conntrack

```

### 2.2 클러스터 합류 (Join)

마스터 노드 초기화 시 복사해 두었던 명령어를 실행합니다. (**sudo** 권한 필수)

```bash
sudo kubeadm join <마스터-사설-IP>:6443 --token <토큰값> \
        --discovery-token-ca-cert-hash sha256:<해시값>

```

---

## ✅ 3. 최종 상태 확인 (마스터 노드에서 실행)

모든 설정이 완료되면 마스터 노드에서 클러스터 상태를 확인합니다.

```bash
# 모든 노드가 Ready 상태인지 확인 (약 1~2분 소요)
kubectl get nodes

# 모든 시스템 파드가 정상 작동(Running) 중인지 확인
kubectl get pods -A

```

---

## ⚠️ 주의 사항 및 비용 관리

* **인프라 삭제:** 실습 종료 후 반드시 `terraform destroy`를 실행하여 비용 발생을 차단하세요.
* **인프라 중지:** 설정을 유지하고 싶다면 AWS 콘솔에서 인스턴스를 **'중지(Stop)'** 하세요. (EBS 비용은 지속 발생)

---

# aws-k8s-kubeadm-terraform
