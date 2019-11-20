# Conju-gator Slack Notifier

This repository contains resources for sending a Slack notification on build state changes for the Conju-gator frontend code.

![Diagram](./diagram.png)

### Deployment

The lambda function is written in Go.

To build the lambda:

    make build

To see the changes Terraform intends to apply to the production stack, run:

    $ terraform plan -var-file="secrets.tfvars"

If you are happy with these changes, run:

    $ terraform apply -var-file="secrets.tfvars"
