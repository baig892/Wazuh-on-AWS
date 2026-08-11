# Wazuh on AWS

Terraform for a production Wazuh SIEM deployment on AWS, built against the
brief for ~400 agents, 25GB/day ingest, 90 days searchable / 12 months
archived, in a single account in eu-west-2.

This is not a finished, production-ready stack. It's roughly 70% of the
design — the network, security, access, and compute layers are real and
wired together, and the rest is scaffolded so the intended shape is visible
even where the resources aren't built yet. Section 3 below is a straight
list of what's done and what isn't, and I'd rather you read that than find
out the hard way.

## 1. Architecture

![Wazuh SIEM architecture diagram](docs/architecture-diagram.png)

Three-AZ VPC, all Wazuh components in private subnets, nothing reachable
from the public internet. Engineers get in through AWS Client VPN with
certificate-based auth rather than a bastion host — the decision record
covers why, but the short version is that a bastion is one more thing to
patch and one more shared credential to manage, and Client VPN gets rid of
inbound SSH entirely.

Manager and indexer nodes are spread one-per-AZ so losing a single AZ
doesn't take out agent connectivity or lose data — indexer shards
replicate across the cluster, and each AZ has its own NAT gateway so
losing one doesn't cut egress for the other two.

Here is Architecture Link: https://app.diagrams.net/#G1JQWP1LxTVVerjoKePHvc24grKfzzM4RN#%7B%22pageId%22%3A%223xCyvmNbljmYl6DW0TZp%22%7D 

## 2. What's actually in this repo

**Built and wired end to end:**
- Networking — VPC, three AZs, public/private subnets, one NAT gateway
  per AZ, S3 gateway endpoint, interface endpoints for Secrets
  Manager/KMS/SSM/CloudWatch Logs (toggle: `enable_interface_endpoints`)
- Security groups (least-privilege, one per tier), KMS CMK with an explicit
  policy (needed once CloudTrail/Config write through it)
- Secrets Manager secret shells — no values ever touch Terraform state
- AWS Client VPN for admin access, with connection logs wired to
  CloudWatch
- Wazuh manager nodes — one EC2 instance per AZ, node 0 tagged as cluster
  master, the rest as workers (see decision record: this is master/worker,
  not active-active — losing AZ-A needs a manual promotion)
- Wazuh indexer nodes — same pattern, persistent EBS data volume per node,
  sized for ~25GB/day x 90d x replica (`indexer_volume_size_gb = 1700`)
- Wazuh dashboard nodes — active/active behind the internal ALB (it's a
  stateless read layer, so no failover step is needed here)
- Internal ALB (dashboard, :443) and internal NLB (agent traffic,
  :1514/:1515) — separate load balancers because agents speak raw TCP,
  not HTTP
- AWS Backup — daily EBS snapshots via tag-based selection (`Backup=true`
  on every compute instance), optional cross-region copy_action
- S3 archive bucket — versioned, KMS-encrypted, lifecycle to Glacier IR
  then expiry at `archive_retention_days`, optional CRR to the DR region
- DR region module (`enable_dr = true`) — S3 replica bucket + DR KMS key +
  DR backup vault in `dr_region` (default eu-west-1), wired as the CRR/
  copy_action targets above. No compute — Backup & Restore, not warm
  standby; see decision record for the RPO/RTO/cost trade-off
- CloudTrail (multi-region, log file validation, KMS-encrypted) and AWS
  Config (recorder + delivery channel) for ISO 27001 audit evidence
- CloudWatch: VPN connection log group, StatusCheckFailed alarm per
  compute instance, SNS topic to receive them

**Scaffolded but not built (variables and outputs exist, resources
don't, or are stubbed with comments explaining the intended shape):**
- CPU/memory/disk alarms for the Wazuh nodes — needs the CloudWatch agent,
  which is part of the Ansible bootstrap below

**Not implemented anywhere in this repo:**
- Actual Wazuh installation and configuration. Terraform gets you
  correctly networked, IAM'd, encrypted, tagged EC2 instances — nothing
  installs Wazuh on them, forms the manager/indexer clusters, or sets
  `node_type master/worker` in ossec.conf from the `ManagerRole` tag.
  That's intended to be Ansible, run via SSM rather than opening SSH, and
  it isn't written. This is the biggest real gap between what's here and
  a working SIEM.
- On-prem agent connectivity. The NLB is internal-only, reachable from
  inside the VPC (and from the Client VPN CIDR once you add that ingress
  rule to the manager SG). Real on-prem Linux/Windows servers need either
  a Site-to-Site VPN or a public-facing NLB with source-IP allowlisting —
  neither is built here. Flagging this rather than guessing at your actual
  on-prem network.
- A tested DR/restore runbook. The decision record proposes an RPO of
  ~15 minutes and RTO of ~3-4 hours; nothing in this repo has actually
  exercised a restore, so treat that as an intended target, not a
  verified one.
- `terraform validate` has **not** been run against this version by me —
  the sandbox I used to write this had no network path to
  releases.hashicorp.com to install the real Terraform CLI. I cross-checked
  every module call's required arguments and every `module.X.Y` output
  reference by parsing the HCL directly (script-verified, not hand-checked),
  and `terraform-config-inspect` confirms every file parses as valid HCL —
  but that is not a substitute for a real `terraform init && terraform
  validate` run, which you should do before trusting this further.

## 3. How to use this

Clone it, then:

```bash
terraform init
terraform validate
```

You'll need three ACM certificate ARNs before a plan will fully resolve —
a server certificate and client root certificate for the Client VPN's
mutual TLS, plus one more for the internal ALB's HTTPS listener in front
of the dashboard. None of these are something Terraform should generate
for you (the VPN pair because a CA private key shouldn't pass through a
Terraform run; the ALB one you'd normally issue via ACM against an
internal domain name), so all three are a manual step.

Copy one of the example tfvars files and fill those two ARNs in:

```bash
cp demo.tfvars.example demo.tfvars
# edit demo.tfvars with your certificate ARNs
terraform plan -var-file=demo.tfvars
```

`demo.tfvars` is the reduced-scale config — single manager, single
indexer, small instance types, backup disabled — meant to be actually
applied for a cheap end-to-end check. `production.tfvars.example` has the
full three-node topology matching the cost estimate; plan against it to
see the full production shape, but there's no reason to apply it unless
you're actually standing up the real thing.

Remote state is local by default. There's a commented `backend "s3"`
block in `versions.tf` — bootstrap an S3 bucket and a DynamoDB table for
locking, uncomment it with your bucket name, and re-run `terraform init`
once you're past the "just checking this works" stage.

If you're picking this up to actually finish it, the order I'd tackle
things in is: write the Ansible side first (nothing here is a working
SIEM without it — including setting `node_type` from each manager's
`ManagerRole` tag), then decide how on-prem agents actually reach the
NLB (Site-to-Site VPN vs. public NLB + allowlist), then exercise an
actual DR restore once to turn the RPO/RTO from a target into a verified
number.

Set `enable_dr = true` to provision the DR-region resources (a second
`aws` provider, aliased `dr`, points at `var.dr_region`). Leave it `false`
for the demo stack — there's no reason to pay for a second region's KMS
key and S3 bucket just to smoke-test the primary topology.

## 4. Where Terraform stops

Terraform owns infrastructure — networking, compute, IAM, storage,
security groups, and the empty shells of secrets. It deliberately doesn't
own OS or application configuration (Ansible's job), secret values
(set out of band, never as a Terraform variable), or certificate issuance
for the VPN's client CA (a manual step involving a private key, not
something to automate here).


Enter your Env. Name. 

![alt text](image.png)

Enter your ACM Private CA 

![alt text](image-1.png)

Enter your Server Certificate

![alt text](image-2.png)
