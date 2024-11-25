exports.handler = async (event) => {
    const startTime = Date.now(); // Start timer

    const querynum = event.queryStringParameters && event.queryStringParameters.num
        ? parseInt(event.queryStringParameters.num, 10)
        : null;

    const body = event.body ? JSON.parse(event.body) : {};
    const bodynum = body.num && parseInt(body.num, 10) > 0
        ? parseInt(body.num, 10)
        : null;

    // Use query parameter first, fallback to body, and default to 30 if invalid
    const num = querynum || bodynum || 30;
    
    // Execute the Sieve of Eratosthenes to find primes
    const primes = sieveOfEratosthenes(num);

    const endTime = Date.now(); // End timer
    const duration = endTime - startTime; // Calculate duration

    // Return response with primes, num, and duration
    return {
        statusCode: 200,
        body: JSON.stringify({
            primes: primes,
            num: num,
            duration: duration
        }),
        headers: {
            'Content-Type': 'application/json'
        }
    };
};

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
