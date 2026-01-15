# Counter Service Project
This project implements a simple web service that counts the number of POST requests it receives and returns the current count on every GET request. The service is fully containerized and uses Redis to persist the count, ensuring that the data is maintained even if the pod restarts.

# Architecture & Deployment

* The application container is built, tested, and pushed to Docker Hub via a GitHub Actions CI/CD pipeline.
* Each commit to the repository triggers the pipeline:

  1. Runs tests (linting, unit tests)
  2. Builds the Docker image and tags it with the Git SHA
  3. Updates the `values.yaml` in the Helm chart with the new image tag
  4. Pushes the updated Helm chart back to the repository
* Argo CD continuously monitors the repository for changes and performs a rolling update of the application on the cluster whenever a new image is available.

The service is exposed via a Ingress controller, which provisions an AWS Application Load Balancer (ALB) to handle external traffic.

A single Redis replica statefulset is used for storing counts and has persistent storage via a PersistentVolumeClaim, ensuring data is retained across pod restarts.

Additionally, the service provides:

* Metrics endpoint for monitoring
* Health and readiness probes for Kubernetes to manage pod lifecycle
* Horizontal Pod Autoscaler (HPA) support for scaling based on load
