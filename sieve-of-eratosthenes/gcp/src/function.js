const functions = require('@google-cloud/functions-framework');

// Define the HTTP-triggered function
functions.http('sieveOfEratosthenes', (req, res) => {
    const startTime = Date.now(); // Start timer

    // Extract `num` from query parameters or body
    const queryNum = req.query.num ? parseInt(req.query.num, 10) : null;
    const bodyNum = req.body && req.body.num ? parseInt(req.body.num, 10) : null;

    // Use query parameter first, fallback to body, and default to 30 if invalid
    const num = queryNum || bodyNum || 30;

    // Execute the Sieve of Eratosthenes to find primes
    const primes = sieveOfEratosthenes(num);

    const endTime = Date.now(); // End timer
    const duration = endTime - startTime; // Calculate duration

    // Return response with primes, num, and duration
    res.status(200).json({
        primes: primes,
        num: num,
        duration: duration,
    });
});

// Sieve of Eratosthenes implementation
const sieveOfEratosthenes = (num) => {
    // Create a boolean array to mark primes
    const prime = Array(num + 1).fill(true);
    let p = 2;

    while (p * p <= num) {
        // If prime[p] is still true, it's a prime
        if (prime[p]) {
            // Mark all multiples of p as not prime
            for (let i = p * p; i <= num; i += p) {
                prime[i] = false;
            }
        }
        p++;
    }

    // Collect all prime numbers
    const primeNumbers = [];
    for (let p = 2; p <= num; p++) {
        if (prime[p]) {
            primeNumbers.push(p);
        }
    }

    return primeNumbers;
};
