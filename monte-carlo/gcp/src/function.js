const functions = require('@google-cloud/functions-framework');

functions.http('estimatePi', (req, res) => {
    let startTime = Date.now();

    // Handle trials from both query parameters and request body
    const queryTrials = req.query.trials ? parseInt(req.query.trials, 10) : null;
    const body = req.body || {};
    const bodyTrials = body.trials && parseInt(body.trials, 10) > 0 ? parseInt(body.trials, 10) : null;

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

    // Estimate Pi
    const pi = (4 * circle_points) / square_points;

    let endTime = Date.now();
    let duration = endTime - startTime;

    // Send the response as JSON
    res.status(200).set('Content-Type', 'application/json').json({
      estimatedPi: pi,
      trials: trials,
      duration: duration
  });  
});
