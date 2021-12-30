# DigitalOcean Kubernetes Challenge

## Challenge

**Deploy a scalable message queue**

A critical component of all the scalable architectures are message queues used
to store and distribute messages to multiple parties and introduce buffering.
Kafka is widely used in this space and there are multiple operators like Strimzi
or to deploy it. For this project, use a sample app to demonstrate how your
message queue works.

## Preparation

The examples are targeting [DigitalOcean Managed
Kubernetes](https://www.digitalocean.com/products/kubernetes/) platform. If you
don't have an account yet, you can create one using [this referral
link](https://m.do.co/c/7865fa4898c6) so we both
get some credits to use there (You get 100$, me 25$).

It's possible to use the examples locally (with minikube, Kind, k3d, or some
other distro) or using other Kubernetes providers.
Keep in mind that you'll need some beefy hardware for Kafka.

This repository uses some automations to handle configuration.

### Nix

Nix is a package manager for Linux an macOS that allows reproducible builds.
It's based on a declarative lazily-evaluated functional language. Unlike
Homebrew, it allows pinning exact version of packages and their dependencies.
The dependencies are also reused between different Nix environments.

You can find installation instructions at https://nixos.org/download.html .

When combined with `direnv`, each time you `cd` to the working directory, Nix
will create a nix-shell with all your variables and tools presented to you.

Alternatively, if you don't want to use `direnv`, you can create a shell
manually:

```
nix-shell default.nix
```

This will install all the dependencies (like `doctl`, `kubectl`, etc.) in the
required versions and make them instantly available in your shell.

### Direnv

Direnv is a shell extension. It augments existing shells with a new feature that
can load and unload environment variables depending on the current directory.

Apart from that, it can do a few more tricks, including running a Nix shell in a
supported directory. This way, we can have portable versioned development
environments stored as code.

You can install `direnv` with either `brew install direnv` or `nix-env -i
direnv`. After installation, add the following to your shell startup file (eg.
`~/.zshrc`):

```
eval "$(direnv hook zsh)"
```

Substitute `zsh` for `bash` if you prefer.

Before `direnv` starts modifying your environment, you have to first add the
current directory to the trusted ones by running `direnv allow`.

More about `direnv`: https://direnv.net/

## Getting started

1. Create a Kubernetes cluster in DigitalOcean. Make sure to select nodes with
   2GB RAM as Kafka can be quite memory-consuming. Name it
   `do-kubernetes-challenge`.
2. Create a `.env` file with a DigitalOcean API Token (you can get one from
   https://cloud.digitalocean.com/account/api/tokens)
3. Install the prerequisites: Nix and direnv
4. Run `direnv allow`
5. Wait until everything installs and configures
6. Run `doctl kubernetes cluster kubeconfig save do-kubernetes-challenge` to
   download the cluster config for use with `kubectl`
7. Run `kubectl get nodes` to make sure you are connected to the right cluster

## Deploying Strimzi and Kafka to the Kubernetes cluster

If you want to deploy your own Kafka cluster using Strimzi operator, follow the
steps below.

### Step 1

First of all, we would like to create a unique namespace for all our resources.
This will allow us to keep them separated from other workloads that might be
running on your cluster.

To create a `do-kafka` namespace, run:

`kubectl apply -f step1`

### Step 2

Now, we want to deploy the Strimzi Operator that will take care of the Kafka
cluster. Strimzi Operator is a Kubernetes Operator that can create, update, and
destroy clusters, topics, users, bridges, and a lot more resources that Kafka
may use.

In short, it takes the administrative burden from human operators.

To deploy the operator, run:

`kubectl apply -f step2`

### Step 3

Now is the time to create a Kafka Custom Resource that will describe our Kafka
cluster. Once we create it, the Strimzi Operator will take over and prepare all
the necessary Kubernetes resources that the Kafka cluster may need.

To deploy the Kafka cluster, run:

`kubectl apply -f step3`

It takes a while for the cluster to be fully operational. The following command
will stop running whenever the resources are ready: `kubectl wait kafka/do-cluster
--for=condition=Ready --timeout=600s -n do-kafka`

Now, you may want to list all the resources created for our Kafka cluster:

`kubectl get all -n do-kafka`

#### Producing and consuming Kafka messages

In this step, we'll see how to connect directly to the Kafka broker and use the
example clients to produce and consume messages. Normally, you would write your
own applications that either connect to the broker or use some other connection
method, such as Kafka Bridge with the HTTP REST API.

When the cluster is ready, we can play with it by sending and receiving some
messages. Make sure you have two terminals ready (or use a multiplexer such as
`tmux`): one will run a producer, the other a consumer. Both the producer and
consumer are example applications that come from the Kafka project.

In terminal one, run:

```
kubectl -n do-kafka run kafka-producer -ti \
--image=quay.io/strimzi/kafka:0.27.0-kafka-3.0.0 --rm=true --restart=Never -- \
bin/kafka-console-producer.sh --broker-list do-cluster-kafka-bootstrap:9092 \
--topic first-do-topic
```

This will create an interactive session attached to a pod running the console
producer. The Kafka topic that the producer will write to is `first-do-topic`.

In terminal two, run:

```
kubectl -n do-kafka run kafka-consumer -ti \
--image=quay.io/strimzi/kafka:0.27.0-kafka-3.0.0 --rm=true --restart=Never -- \
bin/kafka-console-consumer.sh --bootstrap-server \
do-cluster-kafka-bootstrap:9092 --topic first-do-topic --from-beginning
```

Now, whenever you type a message followed by enter in terminal one, it should
show in terminal two as well.

This is the simplest form of Kafka at work.

### Step 4

In a previous example, we used a sample application that connected directly to
the broker. This time, we want to set up Kafka Bridge that will expose the REST
API for us to use.

In our case, Kafka Bridge will be running as a sidecar container along with our
main application. Well, the main application is nothing more than a shell with
`curl`, but that shouldn't matter.

To deploy the configuration for the Bridge and the Pod using Bridge as a sidecar
run:

`kubectl apply -f step4`

Once again, you can confirm everything is operational by running `kubectl get
all -n do-kafka`. You should see the `bridge-sidecar` Pod and it should have 2/2
containers ready. If that's the case, we can go to the next step which uses HTTP
client to communicate with Kafka.

### Step 5

The main container that is running in the Kafka Bridge Pod has `curl` installed.
Typing `curl` commands manually can be tedious and error-prone, so we have a few
shell scripts that should make this easier.

First, we need to copy them to the container:

```
for i in step5/*sh; do kubectl cp "$i" \
bridge-sidecar:"/usr/local/bin/$(basename $i)" -n do-kafka -c main; done
```

This command will copy each shell script from the `step5` directory and put it
under `/usr/local/bin` in the `main` container of the `bridge-sidecar` Pod.

With the scripts ready, connect an interactive session to the Pod:

`kubectl exec -ti bridge-sidecar -n do-kafka -c main -- bash`

Now, with a shell session inside the Pod, we can start producing messages to a
Kafka topic. This time, we choose a different topic than before:

`/usr/local/bin/producer.sh second-do-topic 'Hello, World!'`

You can send as many messages as you like this way.

Next, we need to create a consumer to start receiving the messages. First, to
create the consumer itself, run: `/usr/local/bin/create_consumer.sh`.

After that, subscribe to the new topic with:
`/usr/local/bin/consumer_subscribe.sh second-do-topic`.

Finally, run `/usr/local/bin/consumer_get_messages.sh` to get the messages sent
to the queue. You may need to run it a few times before you start receiving the
messages!

If you still have the consumer from Step 3 running in one of the terminals, you
can also use the REST API to publish messages to the previous topic that we
used like that: `/usr/local/bin/producer.sh first-do-topic 'Ahoy!'`.

### Next Steps

And that's mostly it! Of course, Kafka is much more complex than that! If you
want to use it in your projects, make sure to read [Strimzi
Documentation](https://strimzi.io/documentation/) and [Kafka
Introduction](https://kafka.apache.org/intro) (at the very least!). You can also find useful
real-world examples on the [Strimzi blog](https://strimzi.io/blog/).

## Try It Yourself!

You can open an interactive session on GitPod and follow the above steps there:

[![Open in
Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/doomhammer/digitalocean-kubernetes-challenge)

[![DigitalOcean Referral
Badge](https://web-platforms.sfo2.digitaloceanspaces.com/WWW/Badge%202.svg)](https://www.digitalocean.com/?refcode=7865fa4898c6&utm_campaign=Referral_Invite&utm_medium=Referral_Program&utm_source=badge)
