## Summary

Describe the user-visible or security-relevant outcome.

## Risk

- [ ] Normal
- [ ] Compatibility-critical
- [ ] Security-critical

## Verification

- [ ] `make check`
- [ ] Relevant unit/integration tests
- [ ] Malformed/adversarial input test
- [ ] Device or simulator verification
- [ ] Documentation/fixture updated

## Security checklist

- [ ] No networking, telemetry, remote content, or new entitlement
- [ ] No secret-bearing log, clipboard, share, backup, or screenshot path
- [ ] Errors fail closed without a weaker fallback
- [ ] Transaction outputs and warnings remain fully visible
- [ ] Dependency/policy/format change has an ADR
