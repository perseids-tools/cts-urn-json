# CTS URN JSON

This repository includes a set of scripts for generating a dictionary
that accepts a CTS URN and returns the author and title of a publication.

It also includes the a [JSON file](./urn.json) of the dictionary which
can be used in other libraries or applications.

## Setup

### Requirements

* Ruby ~2.7
* Git

### Installation

* `bundle install`

## How to use

Run `ruby ./bin/urn.rb --help` to view every option.

### Basic usage

```bash
$ ruby ./bin/urn.rb init     # Download repositories used to find texts and URNs
$ ruby ./bin/urn.rb generate # Create and save `urn.json` file
```

### Updating to latest version of repositories

```bash
$ ruby ./bin/urn.rb update
```
