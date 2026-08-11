# Behavior Tests and Boundary Substitutes

Use this reference when choosing a test seam, independent expectation, or dependency substitute.

## Prefer caller-visible behavior

Good behavior tests use a public operation, name a capability, and survive a correct internal rewrite.

```typescript
test("user can check out a valid cart", async () => {
  const result = await checkout(cartWith(product), validPayment);
  expect(result.status).toBe("confirmed");
});
```

Implementation-coupled tests assert private methods, internal call counts or order, storage details, or snapshots without reviewed behavioral meaning. Refactoring can break them while behavior remains correct.

## Keep expectations independent

Do not calculate the expected value with the same algorithm as production code.

```typescript
// Tautological: repeats the implementation idea.
const expected = items.reduce((sum, item) => sum + item.price, 0);
expect(calculateTotal(items)).toBe(expected);

// Independent worked example.
expect(calculateTotal([{ price: 10 }, { price: 5 }])).toBe(15);
```

Use the governing spec, a fixed example, protocol fixture, or independent oracle.

## Substitute true boundaries only

Use substitutes for third-party APIs, nondeterministic time or randomness, remote infrastructure without a safe local instance, or I/O whose realistic local form is impractical.

Prefer a test database, in-memory filesystem, fake clock, or behaviorally realistic local adapter over mocks of owned modules. Inject narrow domain operations instead of a generic vendor client.

## Review questions

- Would the test survive a correct internal rewrite?
- Can it fail when the requested behavior is wrong?
- Is the seam one a real caller uses?
- Is each substitute a true boundary rather than an implementation detail?
- Did the red run fail for the intended behavioral reason?
- Is the test deterministic and limited to one logical behavior?
