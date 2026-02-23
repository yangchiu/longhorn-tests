# GitHub Copilot Instructions for Longhorn E2E Test Development

This file provides guidelines for AI assistants (GitHub Copilot) when implementing automated Robot Framework test cases in the `e2e/` folder.

---

## General Principles

### 1. Keyword Reuse
**Always reuse existing keywords as much as possible.**

- Before creating new keywords, check the [API_references.md](../API_references.md) for existing keywords
- Review keywords in `e2e/keywords/*.resource` files across all 33 resource files
- Leverage the comprehensive keyword library (400+ keywords) already available
- Only create new keywords when existing ones cannot fulfill the requirement

### 2. Test Structure
- Follow the existing test patterns in `e2e/tests/`
- Use descriptive test case names that clearly indicate the scenario being tested
- Include proper test setup and teardown
- Add meaningful documentation to test cases

---

## Keyword Selection Guidelines

### Volume Operations
Use existing volume keywords from [e2e/keywords/volume.resource](../e2e/keywords/volume.resource):
- `Create volume ${volume_id}` - for basic volume creation
- `Attach volume ${volume_id}` - for volume attachment
- `Wait for volume ${volume_id} healthy` - for state validation
- See full list in API_references.md

### Workload Operations
Use workload-specific keywords from:
- [e2e/keywords/workload.resource](../e2e/keywords/workload.resource) - for pod operations
- [e2e/keywords/deployment.resource](../e2e/keywords/deployment.resource) - for deployments
- [e2e/keywords/statefulset.resource](../e2e/keywords/statefulset.resource) - for statefulsets

### Custom Host Commands
When the test requires **highly customized operations** like executing specific commands on a host, use the **host command keyword set**:

**Available host command keywords from [e2e/keywords/host.resource](../e2e/keywords/host.resource):**

1. **`Run command on node`**
   - Use for: Basic command execution on a specific node
   - Parameters: `${node_id}`, `${command}`
   - Example: `Run command on node 0 systemctl status longhorn-manager`

2. **`Run command on node ${node_id} and not expect output`**
   - Use for: Execute command and verify specific output is NOT present
   - Parameters: `${command}`, `${unexpected_output}`
   - Example: `Run command on node 0 and not expect output dmesg ERROR`

3. **`Run command on node ${node_id} and wait for output`**
   - Use for: Execute command and wait until expected output appears
   - Parameters: `${command}`, `${expected_output}`
   - Example: `Run command on node 0 and wait for output active (running)`

4. **`Run command on node ${node_id} and get output`**
   - Use for: Execute command, verify expected output, and return the result
   - Parameters: `${command}`, `${expected_output}`
   - Returns: Command output as result
   - Example:
     ```robot
     ${result} = Run command on node 0 and get output cat /proc/meminfo Active
     ```

5. **`Run command on node ${node_id} and get output string`**
   - Use for: Execute command and capture the full output string
   - Parameters: `${command}`
   - Returns: Full command output
   - Example:
     ```robot
     ${output} = Run command on node 0 and get output string df -h
     ```

### Custom Kubernetes Commands
When the test requires **executing specific kubectl commands**, use the **kubectl command keyword set** from [e2e/keywords/common.resource](../e2e/keywords/common.resource):

**Available kubectl command keywords:**

1. **`Run command`**
   - Use for: Basic kubectl command execution
   - Parameters: `${command}`
   - Example: `Run command kubectl get pods -n longhorn-system`

2. **`Run command and expect output`**
   - Use for: Execute kubectl command and verify specific output is present
   - Parameters: `${command}`, `${expected_output}`
   - Example: `Run command and expect output kubectl get nodes Running`

3. **`Run command and wait for output`**
   - Use for: Execute kubectl command and wait until expected output appears
   - Parameters: `${command}`, `${expected_output}`
   - Example: `Run command and wait for output kubectl get pvc pvc-0 Bound`

4. **`Run command and not expect output`**
   - Use for: Execute kubectl command and verify specific output is NOT present
   - Parameters: `${command}`, `${unexpected_output}`
   - Example: `Run command and not expect output kubectl get pods Error`

---

## Best Practices

### When to Use Custom Command Keywords

Use **host command keywords** (`Run command on node ...`) when:
- Executing system-level commands on specific nodes (systemctl, iptables, etc.)
- Checking host filesystem or process state
- Performing node-specific operations not covered by existing keywords
- Need to verify/retrieve command output from a particular node

Use **kubectl command keywords** (`Run command ...`) when:
- Running kubectl commands for Kubernetes resources
- Checking status of custom resources not covered by existing keywords
- Performing operations on namespaces, configmaps, secrets, etc.
- Validating Kubernetes API objects directly

### When NOT to Use Custom Command Keywords

**Avoid using custom command keywords when existing keywords already exist:**

❌ **DON'T:**
```robot
Run command    kubectl create -f volume.yaml
Run command on node 0    systemctl restart kubelet
```

✅ **DO:**
```robot
Create volume 0 with    size=5Gi
Reboot node 0
```

### Keyword Naming Conventions

When creating new keywords (only if absolutely necessary):
- Use descriptive, action-oriented names
- Follow the existing patterns: `<Action> <Resource> <ID> <Details>`
- Examples: `Wait for volume ${volume_id} healthy`, `Delete backup ${backup_id}`

### Parameter Patterns

- Use `${resource_id}` for numeric identifiers (e.g., `${volume_id}`, `${node_id}`)
- Use `${resource_name}` for string names (e.g., `${backup_name}`)
- Use `&{config}` for flexible optional parameters
- Document all parameters in keyword documentation

---

## Example Test Case Structure

```robot
*** Settings ***
Resource    ../keywords/volume.resource
Resource    ../keywords/workload.resource
Resource    ../keywords/host.resource
Resource    ../keywords/common.resource

*** Test Cases ***
Test Volume Resilience After Node Reboot
    [Documentation]    Verify volume remains healthy after node reboot
    [Tags]    node    resilience
    
    Given Create volume 0 with    size=5Gi    numberOfReplicas=3
    And Attach volume 0
    And Wait for volume 0 healthy
    And Write data to volume 0
    
    When Reboot node 0
    And Wait for node 0 up
    
    Then Wait for volume 0 healthy
    And Check volume 0 data is intact

Test Custom Node Configuration
    [Documentation]    Verify custom kernel parameter persists
    
    # Use custom command when no existing keyword covers this
    Run command on node 0 and wait for output    cat /proc/sys/vm/swappiness    0
    
    # But use existing keywords for standard operations
    Create volume 0
    Attach volume 0
    Wait for volume 0 healthy
```

---

## Reference Documentation

- **Complete Keyword Reference**: [API_references.md](../API_references.md)
- **Keyword Files**: `e2e/keywords/*.resource` (33 files)
- **Python Implementations**: `e2e/libs/keywords/*.py`
- **Example Tests**: `e2e/tests/`

---

## Summary Checklist

Before implementing a new test case:

- [ ] Review existing keywords in API_references.md
- [ ] Reuse existing keywords where possible
- [ ] Use host command keywords for customized node operations
- [ ] Use kubectl command keywords for custom Kubernetes commands
- [ ] Follow existing test patterns and naming conventions
- [ ] Add proper documentation and tags
- [ ] Verify test cleanup in teardown

---

**Last Updated**: 2026-02-13  
**Maintained by**: Longhorn QA Team
