#!/bin/bash

get_ip() {
    kubectl get pod -n $1 $2 -o jsonpath="{.status.podIP}"
}

get_cilium_pod(){
    kubectl get pod -n kube-system --field-selector spec.nodeName=$1 \
         -o jsonpath='{ range .items[*]}{.metadata.name}{"\n"}{end}' | grep -v operator | grep cilium
}

port_forward() {
    kubectl port-forward -n kube-system `get_cilium_pod $1` $2:9965 2>&1 > /dev/null &
}

metrics() {
    curl -s localhost:$1/metrics | grep "hubble_flows_processed_total" | grep $2
}

has_hubble_metric_for_pod() {
    num_metrics=`metrics $1 $2 | wc -l`
    if [[ -z $num_metrics ]]; then
      echo "no metrics found for $2"
    else
      echo "found $num_metrics metrics referencing $2"
    fi
}

pod_one_ip=`get_ip somenamespace pod-one`
pod_two_ip=`get_ip anothernamespace pod-two`

kubectl exec -n somenamespace pod-one -- curl -s http://$pod_two_ip:9000 > /dev/null
echo "called pod-two from pod-one"

kubectl exec -n anothernamespace pod-two -- curl -s http://$pod_one_ip:9000 > /dev/null
echo "called pod-one from pod-two"

port_forward kind-control-plane 9965
port_forward kind-worker 9966

sleep 5 

has_hubble_metric_for_pod 9965 pod-one
has_hubble_metric_for_pod 9965 pod-two

has_hubble_metric_for_pod 9966 pod-one
has_hubble_metric_for_pod 9966 pod-two

kubectl delete pod -n somenamespace pod-one 

sleep 70
has_hubble_metric_for_pod 9965 pod-one
has_hubble_metric_for_pod 9966 pod-one

has_hubble_metric_for_pod 9965 pod-two
has_hubble_metric_for_pod 9966 pod-two
