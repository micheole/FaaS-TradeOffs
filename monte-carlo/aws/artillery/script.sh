#!/bin/bash

# Check if the user provided the required arguments
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <TRIALS>"
    exit 1
fi

# Get the URL and number of trials from the command-line arguments
# URL=$1
TRIALS=$1

sed "s/__TRIALS__/$TRIALS/" temp.yaml > test.yaml

# Define the Artillery test file and log file
LOG_DIR="./logs"
ARTILLERY_TEST_FILE="test.yaml"
LOG_FILE_NAME="$LOG_DIR/aws-log-trials-$TRIALS-$(date +'%Y-%m-%d_%H-%M-%S').log"

echo "Running with TRIALS=$TRIALS"

START_TIME=$(date +%s)
artillery run test.yaml -t "URL" | grep -E "Unique ID:|Pi:|Trials:" >> "$LOG_FILE_NAME" #CHANGE URL

if [ $? -ne 0 ]; then
    echo "Artillery test failed. Check the logs in $LOG_FILE_NAME."
    exit 1
else
    echo "Artillery test completed. Logs saved to $LOG_FILE_NAME."
fi

echo "Waiting 5 minutes for CloudWatch logs to update..."
sleep 300

# Extract all Request IDs from the Artillery output
REQUEST_IDS=$(grep "Unique ID:" "$LOG_FILE_NAME" | awk -F "Unique ID: " '{print $2}' | tr -d ',')

# Query CloudWatch logs for each Request ID
echo "Querying CloudWatch logs for each Request ID..."
AWS_REGION="eu-central-1" # Replace with your region
LOG_GROUP="/aws/lambda/..." # Replace with your Lambda function log group

for ID in $REQUEST_IDS; do
    echo "Processing Request ID: $ID"
    
    # Query CloudWatch logs for the specific Request ID
    QUERY_ID=$(aws logs start-query \
        --log-group-name "$LOG_GROUP" \
        --query-string 'fields @message | filter @message like "REPORT"' \
        --start-time "$START_TIME" \
        --end-time $(date +%s) \
        --region "$AWS_REGION" \
        --output text)
    
    if [ -z "$QUERY_ID" ]; then
        echo "Failed to start CloudWatch query for Request ID: $ID" >> "$LOG_FILE_NAME"
        continue
    fi

    echo "Query_ID: $QUERY_ID"

    # Wait for query to complete
    echo "Waiting for query results..."
    sleep 10

    # Fetch query results
    RESULT=$(aws logs get-query-results --query-id "$QUERY_ID" --region "$AWS_REGION")
    echo "Result: $RESULT"

    # Extract Billed Duration
    BILLED_DURATION=$(echo "$RESULT" | \
        jq -r '.results[] | .[] | select(.field == "@message") | .value' | \
        grep "Billed Duration" | awk -F "Billed Duration: " '{print $2}' | awk '{print $1}')
    
    if [ -n "$BILLED_DURATION" ]; then
        echo "Billed Duration: $BILLED_DURATION ms" >> "$LOG_FILE_NAME"
    else
        echo "Billed Duration: Not Found" >> "$LOG_FILE_NAME"
    fi
done

# Output the final log
echo "Relevant details saved to $LOG_FILE_NAME."
cat "$LOG_FILE_NAME"
