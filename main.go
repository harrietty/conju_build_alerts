package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

func handleRequest(ctx context.Context, event events.CloudWatchEvent) (string, error) {
	return fmt.Sprintf("Hello %s!", event), nil
}

func main() {
	lambda.Start(handleRequest)
}
