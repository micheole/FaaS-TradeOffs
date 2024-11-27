exports.handler = async (event, context) => {
    let startTime = Date.now();
 
    let uniqueId = context.awsRequestId;

    // Handle trials from both query parameters and request body
    const queryTrials = event.queryStringParameters && event.queryStringParameters.trials
        ? parseInt(event.queryStringParameters.trials, 10)
        : null;

    const body = event.body ? JSON.parse(event.body) : {};
    const bodyTrials = body.trials && parseInt(body.trials, 10) > 0
        ? parseInt(body.trials, 10)
        : null;

    // Use query parameter first, fallback to body, and default to 10,000 if invalid
    let trials = queryTrials || bodyTrials || 10000;

    let circle_points = 0;
    let square_points = 0;

    for (let i = 0; i < trials; i++) {

        const rand_x = Math.random();
        const rand_y = Math.random();

        const origin_dist = rand_x * rand_x + rand_y * rand_y;

        if (origin_dist <= 1) {
            circle_points++;
        }

        square_points++;
    }

    let pi = (4 * circle_points) / square_points;
    
    let endTime = Date.now();
    let duration = endTime - startTime;

    console.log(JSON.stringify({
        uniqueId,
        estimatedPi: pi,
        trials,
    }));

    return {
        statusCode: 200,
        body: JSON.stringify({
            uniqueId: uniqueId,
            estimatedPi: pi,
            trials: trials,
            duration: duration
        }),
        headers: {
            'Content-Type': 'application/json'
        }
    };
};
