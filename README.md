# Nomad Dash Doc generator

This projects is based on [consul-dash-doc-generator](https://github.com/bartoszj/consul-dash-doc-generator).

## Requirements

* [Ruby Version Manager](https://rvm.io/) (RVM)

## Installation

```shell
$ rvm install 2.5.3
$ rvm gemset --create use nomad-dash-doc-generator
$ gem install --no-document bundler
$ bundle install
```

## Build the docset

To build execute command:

```shell
$ ./build.sh <version>
```

For example, to build version documentation for Nomad version 0.10.2 you, execute:

```shell
$ ./build.sh 0.10.2
```

Then move the docset into a proper directory.
