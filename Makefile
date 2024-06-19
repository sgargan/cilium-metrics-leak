
all: image deploy test

image:
	docker build -t sgargan/cilium-metric-leak-test -f Dockerfile .

deploy:
	kind load docker-image sgargan/cilium-metric-leak-test --name kind
	kubectl apply -f deploy-test-pods
	kubectl wait --for=condition=ready pod -l app=pod-one -n somenamespace --timeout=30s 
	kubectl wait --for=condition=ready pod -l app=pod-two -n anothernamespace --timeout=30s 

test:
	./test.sh