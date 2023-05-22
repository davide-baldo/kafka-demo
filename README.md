## Kafka demo minikube project

In order to demonstrate provisioning of kafka integration into K8s environment
we set up kafka server, consumer and producer in a minikube cluster.

We configure kafka interceptors for producer and consumer and kafka outlet
to connect to the brokers.

<img src="./assets/overview.jpg" width="80%">


### Requirements

- Docker
- Minikube installed https://minikube.sigs.k8s.io/
- Helm https://helm.sh/
- Ockam to enroll and provision components in a project https://docs.ockam.io/

### Demo sequence

1. Enroll with ockam orchestrator

```
ockam enroll
```

This will create a `default` project which can be used in the demo


2. Get the project information into `mnt/project.json`

```
ockam project information default --output=json > mnt/project.json
```

This project information will be used by provisioned ockam nodes

3. Create enrollment tokens for components to authenticate with the project

```
ockam project enroll --attribute role=member > mnt/consumer.token
ockam project enroll --attribute role=member > mnt/producer.token
```

**NOTE:** we might want to enroll the outlet node as well
**QUESTION:** do we have control over expiration of the token?

4. Start the minikube cluster with `mnt` directory mounted

```
minikube start --mount --mount-string="$(pwd)/mnt:/mnt/minikube"
```

`mnt` directory is used to provision project information and enrollment tokens
to the ockam containers

**NOTE:** Further commands in this demo assume that minikube configures `kubectl` and `helm`
are using the minikube cluster.

5. Install kafka helm release

```
helm install kafka oci://registry-1.docker.io/bitnamicharts/kafka
```

We assume default configuration of the helm release resources in the demo configs:
- service `kafka` with port 9092
- three kafka brokers

6. Start `kafka-outlet` pod

```
kubectl apply -f kafka-outlet.yaml
```

This pod will connect to the `kafka` service.

7. Start `kafka-consumer` pod

```
kubectl apply -f kafka-consumer.yaml
```

This pod starts `kafka-console-consumer.sh` reading from `demo-topic`

This pod includes ockam kafka sidecar which will intercept and decrypt all encrypted messages.

8. Show logs from kafka consumer which will contain decrypted messages

```
kubectl logs -f kafka-consumer
```

9. Start `kafka-producer` pod

```
kubectl apply -f kafka-producer.yaml
```

This pod starts with kafka docker image, but only runs `sleep infinity`, to start
an actual producer we will use `kubectl exec`.

This pod includes ockam kafka sidecar which will intercept and encrypt messages.

10. Start kafka-console-producer on producer pod to send messages to the topic

```
kubectl exec --tty -i kafka-producer --namespace default -- kafka-console-producer.sh --topic demo-topic --bootstrap-server localhost:9092
```

Important note here: we set `localhost:9092` as a bootstrap server instead of `kafka:9092`,
that will make the producer app connect to the ockam sidecar instead of directly to kafka.

### Building images

Currently pod configurations are using locall images, please make sure you have
loaded them in minikube:

For outlet image:

```
eval $(minikube docker-env)

cd ockam_kafka_outlet
docker build build -t ockam_kafka_outlet:latest .
```

**See the pod configs**


### Implementation details

- Currently using elixir app for `kafka-outlet`, it will validate credentials but will not present its own credentials to the interceptor sidecars.
- We have to use ockam nodes as sidecars because current implementation assumes localhost for dynamic inlets, we could change that with some configuration

### TODO

We need to make a docker image which will start a rust kafka sidecar with a single command.

- It needs to read `project.json`
- It needs to enroll using enrollment token (if not enrolled yet)
- It needs connect to the configured outlet instead of the project node

Optional:
- We might also set up the sidecars to establish encryption secure channel over kafka-outlet.




