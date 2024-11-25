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
QUERY_IDS_FILE="$LOG_DIR/query-ids-$TRIALS-$(date +"%Y-%m-%d_%H-%M-%S").txt"
RESULT_FILE="$LOG_DIR/aws-query-results-$TRIALS-$(date +"%Y-%m-%d_%H-%M-%S").json"


echo "Running with TRIALS=$TRIALS"

START_TIME=$(date +%s)
artillery run test.yaml -t "https://mg29etspsa.execute-api.eu-central-1.amazonaws.com/dev/lambda" > "$LOG_FILE_NAME" 2>&1

if [ $? -ne 0 ]; then
    echo "Artillery test failed. Check the logs in $LOG_FILE_NAME."
    exit 1
else
    echo "Artillery test completed. Logs saved to $LOG_FILE_NAME."
fi

echo "Extracting relevant details from Artillery log..."
FINAL_LOG_FILE="$LOG_DIR/final/final-log-$TRIALS-$(date +"%Y-%m-%d_%H-%M-%S").log"

grep -E "Pi:|Trials:" "$LOG_FILE_NAME" > "$FINAL_LOG_FILE"
echo 

echo "Waiting 3 minutes for CloudWatch logs to update..."
sleep 180

# AWS log query setup
echo "Starting CloudWatch Logs queries..."
AWS_REGION="eu-central-1"
LOG_GROUP="/aws/lambda/json_terraform_lambda_monte_carlo_testing" # REPLACE

END_TIME=$(date +%s)

# Start the query
QUERY_ID=$(aws logs start-query \
    --log-group-name "$LOG_GROUP" \
    --query-string 'fields @message | filter @message like "REPORT"' \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --region "$AWS_REGION" \
    --output text)

if [ -z "$QUERY_ID" ]; then
    echo "Failed to start CloudWatch query."
    exit 1
else
    echo "$QUERY_ID" > "$QUERY_IDS_FILE"
fi

echo "Waiting 30 seconds for CloudWatch query to complete..."
sleep 30

# Fetch query results
echo "Fetching query results..."
rm -f "$RESULT_FILE"
touch "$RESULT_FILE"

aws logs get-query-results --query-id "$QUERY_ID" --region "$AWS_REGION" >> "$RESULT_FILE"


BILLED_DURATION=$(jq -r '.results[] | .[] | select(.field == "@message") | .value' "$RESULT_FILE" | \
grep "Billed Duration" | \
awk -F "Billed Duration: " '{print $2}' | awk '{print $1}')

if [[ -z "$BILLED_DURATION" ]]; then
    echo "No Billed Duration found." >> "$FINAL_LOG_FILE"
else
    echo "Billed Duration: $BILLED_DURATION ms" >> "$FINAL_LOG_FILE"
fi

# Final message
echo "Relevant details saved to $FINAL_LOG_FILE."