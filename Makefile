build:
	rm lambda_function_payload.zip
	dep ensure -v
	env GOOS=linux go build -ldflags="-s -w" -o bin/notifier main.go
	zip -r lambda_function_payload.zip ./bin