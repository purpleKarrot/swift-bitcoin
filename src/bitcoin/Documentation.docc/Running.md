# Running

Start a Bitcoin node service, query it and control it with the command line utility.

# Overview

Swift Bitcoin comes with two executables:

- A client or _node_ service called `bcnode`.
- A command line utility named `bcutil`.

They can be run in debug mode using `swift run` or from Xcode on Mac. You can also use Docker to run them interactively or as standalone container images.

## Run from the Swift command line

To start a node use `swift run bcnode`.

To check the node's status use `swift run bcutil status`.

## Build and run executables directly

To produce executables with `release` configuration use `swift build -c release`.

Now you can start a node with `.build/release/bcnode` or use the utility with `.build/release/bcutil`.

## Run with docker

### Interactive container

To start an interactive container based on the official docker image use `docker run --rm -it -v $PWD:/opt/swift-bitcoin swift`.

From there you can run all the commands from the previous section:

```sh
cd /opt/swift-bitcoin
swift run bcutil
```

### Build executable docker images

Build both executable images `bcnode` and `bcutil` from Swift Bitcoin's project root:

```sh
docker build --target bcnode -t bcnode -f tools/Dockerfile .
docker build --target bcutil -t bcutil -f tools/Dockerfile .
```

## Simulate a muilt-node network

Docker can help connect multiple nodes together.

### Setup

First create a docker network named `bitcoin-regtest` using `docker network create bitcoin-regtest`.

### Alice

Run Alice's node using the docker image `docker run --rm -it --network bitcoin-regtest --name alice bcnode -n regtest`.

On another terminal query the node's status and request to start listening for peer-to-peer connections using `docker run --rm --network bitcoin-regtest bcutil -n regtest -h alice status`.

To make it easier to run further commands we can create an alias and change our terminal prompt:

```sh
alias bcutil="docker run --rm --network bitcoin-regtest bcutil -n regtest -h alice"
prompt="alice: "
bcutil start-p2p
```

### Bob

On a new terminal window start Bob's node with `docker run --rm -it --network bitcoin-regtest --name bob bcnode -n regtest`.

And create an alias for Bob's `bcutil` command:

```sh
alias bcutil="docker run --rm --network bitcoin-regtest bcutil -n regtest -h bob"
prompt="bob: "
```

Request Bob's node to connect to Alice's and check its status:

```sh
bcutil connect -i alice
bcutil status
```

We can also enable Bob to receive connections with `bcutil start-p2p`.

On Alice's terminal double check that a connection is active using `bcutil status`.

### Carol (Bitcoin Core)

Adding Bitcoin Core to the mix can be done using a similar approach with [docker executable images](https://github.com/craigwrong/bitcoin-lightning-node/blob/develop/docker/bitcoind/Dockerfile).

Assuming you have `bitcoind` and `bitcoin-cli` built as docker images, you can start Bitcoin Core nodes in the same `regtest` network as your Swift Bitcoin nodes:

```sh
docker run --name carol --rm -it --network bitcoin-regtest -v /bitcoin_auth/ bitcoind -chain=regtest -disablewallet -txindex -server -rpcallowip=0.0.0.0/0 -rpcbind=0.0.0.0 -rpccookiefile=/bitcoin_auth/cookie
```

We use a custom volume to store the authentication cookie which we read from when running the `bitcoin-cli` image for which we'll also create an alias:

```sh
alias bcutil="docker run --rm --network bitcoin-regtest --volumes-from carol bitcoin-cli -regtest -rpcconnect=carol  -rpccookiefile=/bitcoin_auth/cookie"
prompt="carol: "
bitcoin-cli -getinfo
```

From Alice's terminal you can connect to Carol's Bitcoin Core instance using `bcutil connect -i carol`.

Verify connection on Carol's node: `bitcoin-cli getpeerinfo`.

To connect from Bitcoin Core to Swift Bitcoin use `bitcoin-cli addnode bob onetry`.
