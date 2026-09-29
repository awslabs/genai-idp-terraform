# Deployment Guides

This section covers operating a deployment once it is stood up: monitoring it,
choosing how artifacts are built, and diagnosing failures. For a first deployment,
start with the [Quick Start](../getting-started/quick-start.md) and the README of
the example you are using.

## Guide Overview

### [Monitoring](monitoring.md)

**Purpose**: Set up comprehensive monitoring and observability

**Topics Covered**:

- CloudWatch metrics and alarms
- X-Ray distributed tracing
- Custom dashboards and reports
- Log aggregation and analysis

**Best For**: Operations teams and system monitoring

### [Local Lambda Build](local-lambda-build.md)

**Purpose**: Build Lambda layers and processor images on the deploy host instead of
in CodeBuild

**Best For**: Faster iteration, and avoiding per-apply CodeBuild cost

### [Local Web UI Build](local-web-ui-build.md)

**Purpose**: Build the web UI bundle locally rather than in CodeBuild

**Best For**: Front-end iteration against a deployed backend

### [Troubleshooting](troubleshooting.md)

**Purpose**: Diagnose and resolve common deployment issues

**Topics Covered**:

- Permission and access errors
- Resource limit issues
- Performance problems
- Debugging techniques

**Best For**: When things go wrong or for preventive planning

## Support and Resources

### Getting Help

1. **Documentation**: Start with relevant guide sections
2. **Troubleshooting**: Check the [troubleshooting guide](troubleshooting.md)
3. **Community**: Join discussions in the repository
4. **Support**: Open issues for bugs or feature requests

### Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
