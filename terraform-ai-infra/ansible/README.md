# Ansible — configure both EC2 instances (multi-AZ) via SSM

Runs the same playbook on **all** running instances tagged `SecureLLM-prod-app` in parallel—one per Availability Zone.

## Prerequisites (laptop)

```bash
brew install ansible session-manager-plugin   # macOS
aws configure   # or export AWS_PROFILE=...
```

Install collections:

```bash
cd terraform-ai-infra/ansible
ansible-galaxy collection install -r requirements.yml
```

IAM permissions (your user/role): `ssm:StartSession`, `ec2:DescribeInstances`, and SSM messaging (same as AWS Console Session Manager).

## Step 1 — See both instances

```bash
export AWS_REGION=us-west-1
ansible-inventory --graph
```

Expected shape:

```text
@ai_platform:
  |--i-aaa...
  |--i-bbb...
@az_us-west-1a:
  |--i-aaa...
@az_us-west-1c:
  |--i-bbb...
```

Ping (optional):

```bash
ansible ai_platform -m ping
```

## Step 2 — Deploy to both AZs at once

```bash
ansible-playbook playbooks/site.yml
```

Ansible uses `forks` (default 10 in `ansible.cfg`) so **both hosts run in parallel**.

Rolling update (one instance at a time):

```bash
ansible-playbook playbooks/site.yml -e serial=1
```

## Step 3 — Verify

```bash
# Per host
ansible ai_platform -a "docker ps" -b

# ALB health (from terraform root)
curl -s "http://$(terraform -chdir=.. output -raw alb_dns_name)/health"
```

## Variables

Edit `group_vars/all.yml` for images, ports, or tag name if your Terraform prefix differs.

## Static inventory fallback

```bash
cp inventory.static.example.yml inventory.static.yml
# edit instance IDs, then:
ansible-playbook -i inventory.static.yml playbooks/site.yml
```

## Troubleshooting

| Issue | Fix |
|--------|-----|
| `Target not connected` in SSM | Wait for SSM agent Online; check instance profile + NAT |
| Empty inventory | Confirm tag `Name=SecureLLM-prod-app` and region `us-west-1` |
| Permission denied on Docker | Playbook uses `become: true` — instance role does not need SSH |
| `community.docker` errors | Ensure Docker service started on instance (playbook installs it) |
