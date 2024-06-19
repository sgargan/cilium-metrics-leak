# cilium metric leak 

Simple deployment to help verify the fix for https://github.com/cilium/cilium/issues/31889

# Prereq

Expects a working dev cilium cluster configured with 

`make kind kind-image kind-install-cilium`

Note that `contrib/testing/kind-values.yaml` need to be updated to enable metrics 
 
```yaml
kubeProxyReplacement: "false"
hubble:
  enabled: true
  metrics:
    enabled:
      - drop:labelsContext=source_namespace,source_pod,destination_namespace,destination_pod
      - tcp:labelsContext=source_namespace,source_pod,destination_namespace,destination_pod
      - flow:labelsContext=source_namespace,source_pod,destination_namespace,destination_pod
      - http:labelsContext=source_namespace,source_pod,destination_namespace,destination_pod
```

after which `make kind-install-cilium` can be run.

# Test

Test builds an image that runs a simple python server in two pods in separate namespaces. Importantly each pod is placed on a separate node, one on the worker and one on the control-plane.

Each test pod calls the other and it verifies that hubble metrics are tracked for the calls, notably metrics for pod-one are present on both nodes. Pod-one is then deleted and after 1 min we check the metrics again to verify that no metrics exist for pod-one anymore.

## Running
run `make all` to build the image, deploy the pods and run the tests.

```
make all
docker build -t sgargan/cilium-metric-leak-test -f Dockerfile .
[...
kind load docker-image sgargan/cilium-metric-leak-test --name kind
Image: "sgargan/cilium-metric-leak-test" with ID "sha256:6b5f8f110c44dde044136242c08844cbf7c0968092de675c24cd3bf673299637" not yet present on node "kind-control-plane", loading...
Image: "sgargan/cilium-metric-leak-test" with ID "sha256:6b5f8f110c44dde044136242c08844cbf7c0968092de675c24cd3bf673299637" not yet present on node "kind-worker", loading...
kubectl apply -f deploy-test-pods
namespace/somenamespace created
namespace/anothernamespace created
pod/pod-one created
pod/pod-two created
kubectl wait --for=condition=ready pod -l app=pod-one -n somenamespace --timeout=30s
pod/pod-one condition met
kubectl wait --for=condition=ready pod -l app=pod-two -n anothernamespace --timeout=30s
pod/pod-two condition met
./test.sh
called pod-two from pod-one
called pod-one from pod-two
found        4 metrics referencing pod-one
found        4 metrics referencing pod-two
found        4 metrics referencing pod-one
found        4 metrics referencing pod-two
pod "pod-one" deleted
found        0 metrics referencing pod-one
found        0 metrics referencing pod-one
found        0 metrics referencing pod-two
found        0 metrics referencing pod-two
```
