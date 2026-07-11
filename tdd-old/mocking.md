# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes - prefer test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

Mocks, fakes, fake servers, temporary files, env setup, and clocks belong in test files or test harness setup.

Smoke-test shortcuts belong in the smoke command, fixture setup, fake external service, test config, or test environment. They do not belong in production branches.

If an e2e command is expensive or flaky, prefer harness-level controls over production conditionals.

If a command needs real external effects suppressed, use test doubles outside the production code path.

## Mock from Production Boundaries

At system boundaries, use production interfaces that are easy to mock:

**1. Use dependency injection**

Use dependency injection only when the dependency is already a production boundary or the production design naturally needs multiple implementations. Dependency injection is for real architecture, not test convenience.

Do not add optional clients, flags, callbacks, clocks, fetchers, or stores to production APIs only because tests need control.

```typescript
// GOOD: Production boundary dependency
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// BAD: Hard-coded external dependency
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. Prefer SDK-style interfaces over generic fetchers**

Create specific functions for each external operation instead of one generic function with conditional logic:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

The SDK approach means:
- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Type safety per endpoint
