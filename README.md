# Nomad Docset generator

This project is based on [consul-dash-doc-generator](https://github.com/bartoszj/consul-dash-doc-generator).

## Requirements

* [npm](https://www.npmjs.com/)
* [Ruby](https://www.ruby-lang.org/)
* [Ruby Version Manager](https://rvm.io/) (RVM)

npm is used to build the Nomad website. RVM is used to install to Ruby, and
to manage nomad-docset-generator's associated gems in a dedicated dependency
environment.

## Installation

First, install Ruby 2.5.3 using RVM.

```shell
rvm install 2.5.3
```

Next, create a dedicated [Gemset](https://rvm.io/gemsets/basics) for nomad-docset-generator.

```shell
rvm gemset --create use nomad-docset-generator
```

Use `gem install` to install [Bundler](https://bundler.io/).

```shell
gem install --no-document bundler
```

Finally, install the required gems.

```shell
bundle install
```

## Build the docset

To build the docset, use the `build.sh` command. The syntax is as follows:

```shell
./build.sh <version>
```

To build a docset for Nomad version 0.11.0, execute:

```shell
./build.sh 0.11.0
```

The resultant file will be stored in `./build/<version>/Nomad.tgz`.

## Install the docset

To install the docset, first un-archive the file into the current directory.

```shell
tar --extract --gunzip --file ./build/0.11.0/Nomad.tgz
```

Install the docset by into [Dash](https://kapeli.com/dash) by either double-clicking
the file in Finder, or importing it using the following procedure.

1. Open Dash
1. Preferences (`⌘,`)
1. Click 'Docsets' from the menu bar
1. Click '+' and select 'Add Local Docset'
1. Navigate to Nomad.docset and click 'Open'
