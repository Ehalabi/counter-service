# Counter Service Project
This project implements a simple web service that counts the number of POST requests it receives and returns the current count on every GET request. The service is fully containerized and uses Redis to persist the count, ensuring that the data is maintained even if the pod restarts.

# Architecture & Deployment

* The application container is built, tested, and pushed to Docker Hub via a GitHub Actions CI/CD pipeline.
* Each commit to the repository triggers the pipeline:

  1. Runs tests (linting, unit tests)
  2. Builds the Docker image and tags it with the Git SHA
  3. Updates the `values.yaml` in the Helm chart with the new image tag
  4. Pushes the updated Helm chart back to the repository
* Argo CD continuously monitors the repository for changes and performs a rolling update of the application on the cluster on the prod namespace whenever a new image is available.

The service is exposed via a Ingress controller, which provisions an AWS Application Load Balancer (ALB) to handle external traffic.

A single Redis replica statefulset is used for storing counts and has persistent storage via a PersistentVolumeClaim, ensuring data is retained across pod restarts.

Additionally, the service provides:

* Metrics endpoint for monitoring
* Health and readiness probes for Kubernetes to manage pod lifecycle
* Horizontal Pod Autoscaler (HPA) support for scaling based on load working alongside ArgoCD

# Instructions
## 1. Provision the Kubernetes Cluster

This project assumes a managed Kubernetes cluster (EKS on AWS). You can provision it using Terraform or your preferred method:
```bash
terraform plan
terraform apply
```
This will create a VPC with two public subnets and an Internet Gateway, suitable for hosting the application and related services.

## 2. Set up Namespaces and Storage

Create the namespaces for the production application and monitoring:
```bash
kubectl create namespace prod
kubectl create namespace monitoring
kubectl create namespace argocd
```
## 3. Install EBS CSI Driver and StorageClaim

To allow dynamic EBS volumes for PVCs:
```bash
eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster <cluster-name> \
    --role-name AmazonEKS_EBS_CSI_DriverRole \
    --role-only \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve

eksctl create addon --cluster <cluster-name> --name aws-ebs-csi-driver --version latest

kubectl apply -f manifests/gp3_storageclass.yaml
```

## 4. Deploy Redis
The application uses Redis to persist the counter. Apply the Redis StatefulSet and Service:
```bash
kubectl apply -f redis.yaml -n prod
```
Redis uses a PersistentVolumeClaim (PVC) to retain data across pod restarts.

## 5. Install Metrics Server
Metrics server is required for Horizontal Pod Autoscaler (HPA) to function:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## 6. Install AWS Load Balancer Controller
```bash
# Download the IAM policy
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json

# Create the policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# Create the IAM service account for the controller
eksctl create iamserviceaccount \
    --cluster <cluster-name> \
    --namespace kube-system \
    --name aws-load-balancer-controller \
    --attach-policy-arn arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region <aws-region-code> \
    --approve

# Install the controller via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --version 1.14.0
```

## 7. Install Argo CD

Argo CD manages deployment of the Helm chart:
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode ; echo

# Port-forward Argo CD to localhost
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login
argocd login localhost:8080 --insecure
```
Apply the Argo CD Application manifest for the counter service:
```bash
kubectl apply -f manifests/argocd-counter.yaml
```

## 8. Deploy Monitoring (Prometheus + Grafana)

Prometheus:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus --namespace monitoring -f manifests/prometheus-values.yaml
```
Grafana:
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana -n monitoring

# Retrieve Grafana admin password
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```
You can import dashboards for Kubernetes cluster and Node Exporter monitoring.

## 9. Running the CI/CD Pipeline

The pipeline is configured via GitHub Actions and works as follows:
1. Push code to the repository main branch to trigger the workflow.
2. Tests (linting, unit tests) are executed.
3. Docker image is built and pushed to Docker Hub with a unique Git SHA tag.
4. Helm chart values.yaml is updated with the new image tag and pushed back.
5. Argo CD detects the change and performs a rolling update on the cluster.

#### Required GitHub Secrets

These must be configured in the repository:

| Secret Name       | Description                           |
| ----------------- | ------------------------------------- |
| `DOCKER_USERNAME` | Docker Hub username                   |
| `DOCKER_PASSWORD` | Docker Hub access token               |

GitHub Repository -> Settings -> Security secrets and variables -> Actions -> New repository secret

## 10. Testing the Application
Once deployed:
```bash
# Get the ALB address
kubectl get ingress -n prod
```
Test the application:
```bash
# Increment counter
curl -X POST http://<ALB-DNS>

# Get current count
curl http://<ALB-DNS>
```
Check metrics:
```bash
curl http://<ALB-DNS>/metrics
```
Check pod health and scaling:
```bash
kubectl get pods -n prod
kubectl get hpa -n prod
```

Notes on HA, Scaling, and Persistence
* High Availability: Redis and the web service are deployed with a StatefulSet/Deployment and persistent storage to maintain data.
* Scaling: Horizontal Pod Autoscaler adjusts the number of web service pods based on CPU or custom metrics. Works seamlessly alongside Argo CD.
* Persistence: Redis uses a PersistentVolumeClaim for data retention. The web service no longer uses its own PVC, relying on Redis.
* Trade-offs: Using Redis centralizes persistence but adds operational overhead. ALB handles external traffic but introduces a small cost.
