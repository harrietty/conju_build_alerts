package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

func handleRequest(ctx context.Context, event events.CloudWatchEvent) (string, error) {
	webhook := os.Getenv("SLACK_WEBHOOK")

	type codepipelineDetail struct {
		Pipeline string `json:"pipeline"`
		State    string `json:"state"`
	}

	detail := codepipelineDetail{}
	json.Unmarshal(event.Detail, &detail)

	reqBody, err := json.Marshal(map[string]string{
		"text": fmt.Sprintf("%v state change: %v", detail.Pipeline, detail.State),
	})
	if err != nil {
		fmt.Println("Error marshalling JSON", err)
		return "", err
	}

	resp, err := http.Post(webhook, "application/json", bytes.NewBuffer(reqBody))
	if err != nil {
		fmt.Println("Error posting to Slack", err)
		return "", err
	}

	body, _ := ioutil.ReadAll(resp.Body)

	return string(body), err
}

func main() {
	lambda.Start(handleRequest)
}
