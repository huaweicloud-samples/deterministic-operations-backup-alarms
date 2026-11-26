# deterministic-operations-backup-alarms

![License](https://img.shields.io/badge/License-MIT--0-blue)
![Huawei Cloud](https://img.shields.io/badge/Huawei%20Cloud-cn--north--4-red)
![Terraform](https://img.shields.io/badge/Terraform%20Validate-passing-brightgreen)

## 1. Overview

### Introduction

A Huawei Cloud best practice for **centralized backup alarms**: when a Cloud Backup and Recovery (CBR) backup job, replication job, or restoration task fails, operations staff are automatically notified by email.

The architecture uses Huawei Cloud's native **Cloud Eye event monitoring** (namespace `SYS.CBR`, with events such as `backupFailed` / `replicationFailed` / `restorationFailed`) to trigger an alarm, which is then sent by email through the **SMN** message notification service. The **infrastructure** (KMS customer key, CBR vaults and backup policies, SMN topic and email subscription) is declared and managed by Terraform; the **alarm rule** (CBR failure event → SMN) is created in the Cloud Eye console — see "Why alarm rules are not managed by Terraform" below for the reason.

Target users: operations / cloud operations teams that want to monitor backup health centrally within a single Huawei Cloud account and detect backup failures in time.

---

## 2. Table of Contents

- [1. Overview](#1-overview)
- [2. Table of Contents](#2-table-of-contents)
- [3. Architecture Diagram](#3-architecture-diagram)
- [4. Highlights](#4-highlights)
- [5. Cloud Services Used](#5-cloud-services-used)
- [6. Prerequisites](#6-prerequisites)
- [7. Quick Start](#7-quick-start)
- [8. Step-by-Step Deployment](#8-step-by-step-deployment)
- [9. Usage / Verification](#9-usage--verification)
- [10. Cleanup](#10-cleanup)
- [11. Detailed Explanation](#11-detailed-explanation)
- [12. Dependencies](#12-dependencies)
- [13. FAQ / Troubleshooting](#13-faq--troubleshooting)
- [14. Contributing](#14-contributing)
- [15. License](#15-license)
- [16. Contact / Maintainers](#16-contact--maintainers)

---

## 3. Architecture Diagram

```mermaid
flowchart LR
CBR[CBR Cloud Backup] -->|Failure event SYS.CBR| CES[Cloud Eye event monitoring alarm]
CES -->|Trigger alarm| SMN[SMN topic ${var.name_prefix}-alarm-topic]
SMN --> MAIL[(Operations mailbox ops@example.com)]
```

> The alarm rule (CES event alarm) is created in the Cloud Eye console; see step 4 of [`docs/deployment-guide.md`](docs/deployment-guide.md).

---

## 4. Highlights

- **Infrastructure as code**: KMS / CBR / SMN are all declared by Terraform, enabling version-controlled management and one-click reproduction.
- **Native and reliable**: alarms use Huawei Cloud Cloud Eye event monitoring (the official exposure path for CBR failure events), with zero ambiguity and immediate effect.
- **No custom functions**: only the native capabilities of Cloud Eye + SMN are used, with no runtime code to maintain.

---

## 5. Cloud Services Used

| Service | Purpose | Notes |
|---|---|---|
| CBR | Cloud Backup and Recovery (monitored object) | Backup / replication / restoration jobs |
| Cloud Eye | Event monitoring alarm (CBR failure events) | Alarm rule created in the console |
| SMN | Email subscription notifications | Recipient must click the confirmation link |
| KMS | Customer-managed key | CMK explicitly created |
| Terraform | IaC declaration of infrastructure | Alarm rule created in the console |

> **Tip**: all services can be created with one click through this repository's Terraform code. For cleanup, see [Section 10 "Cleanup"](#10-cleanup).

---

## 6. Prerequisites

- A Huawei Cloud account (region `cn-north-4`) with CBR / SMN / KMS / Cloud Eye enabled.
- Terraform >= 1.0 (this repository was validated with provider v1.96.1).
- Permissions to create the above services; credentials are provided through environment variables (**do not write them into code or configuration files**).
- An email address that can receive alarms (example in this repository: `ops@example.com`).

---

## 7. Quick Start

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars # fill in email_endpoint
# export credentials (never write them to files):
export HW_ACCESS_KEY=<your-access-key> HW_SECRET_KEY=<your-secret-key> HW_PROJECT_ID=<your-project-id> HW_REGION_NAME=cn-north-4
terraform init
terraform plan
terraform apply
```

Once the infrastructure is ready, **an alarm rule must still be created in the Cloud Eye console** (see step 4 of `docs/deployment-guide.md`) for the whole solution to have alarm capability.

---

## 8. Step-by-Step Deployment

1. **Prepare credentials**: export `HW_ACCESS_KEY` / `HW_SECRET_KEY` / `HW_REGION_NAME` / `HW_PROJECT_ID` (environment variables only).
2. **Initialize**: `cd infra && terraform init` (downloads the huaweicloud provider).
3. **Preview**: `terraform plan -out=tfplan`, and review the KMS / CBR / SMN resource list.
4. **Apply**: `terraform apply tfplan`, creating the KMS customer key, CBR policies and vaults, SMN topic, and email subscription.
5. **Alarm rule in the console**: following step 4 of `docs/deployment-guide.md`, create a CBR failure-event alarm rule in the Cloud Eye console, with the newly created SMN topic as the notification target.

---

## 9. Usage / Verification

### Usage and Verification

1. Log in to the SMN console and click the confirmation link for the email subscription of `${var.name_prefix}-alarm-topic` (or check the confirmation email).
2. Log in to the Cloud Eye console → Event Monitoring, and confirm that alarm rules have been created for `backupFailed` / `replicationFailed` / `restorationFailed` of `SYS.CBR`, with this SMN topic as the notification target.
3. Manually trigger a backup failure (for example, suspend a resource to cause a failure) and confirm that the operations mailbox receives the alarm email.

After deployment, follow these steps to verify that the business functionality works before considering the delivery complete.

---

## 10. Cleanup

```bash
cd infra && terraform destroy
```

> Note: `terraform destroy` only cleans up the infrastructure managed by Terraform (KMS / CBR / SMN).
> The alarm rule created in the Cloud Eye console must be deleted manually in the console.

---

## 11. Detailed Explanation

### Why alarm rules are not managed by Terraform (an honest note)

`huaweicloud` provider v1.96.1 has incomplete support for the two capabilities "event → notification":

- **EG Event Grid**: CBR failure events do not automatically enter an EG custom channel; the official CBR event source must be attached via `huaweicloud_eg_custom_event_source`, but its `type` / `detail` parameters have no reliable documentation. A blind deployment passes but the alarm silently never fires (equivalent to not configuring it at all).
- **CES event alarms** (`huaweicloud_ces_alarmrule`): event-type alarms require undocumented mandatory fields such as `metric_name` / resource dimension name / `filter`, and the API rejects the request outright (`ces.0014`).

Therefore the alarm rule is created in the console (official, native, zero ambiguity), while Terraform is reserved for the stable, automatable infrastructure part.

- See [`docs/architecture.md`](docs/architecture.md) for the architecture and component responsibilities.
- See [`docs/deployment-guide.md`](docs/deployment-guide.md) for deployment steps, access key configuration, and verification.

---

## 12. Dependencies

See `docs/architecture.md` and `docs/deployment-guide.md` for the full architecture and deployment description.

---

## 13. FAQ / Troubleshooting

### FAQ

**Q: Is it necessary to create a CBR vault?**
A: No. If CBR resources already exist in the account, set `create_cbr_resources` to `false`; the alarm pipeline (SMN + console alarm rule) can still monitor existing CBR jobs.

**Q: Why do I never receive the email?**
A: First confirm that the SMN email subscription has been confirmed by clicking the link (unconfirmed subscriptions are not delivered); then confirm that the corresponding alarm rule has been created in the Cloud Eye console with the correct notification topic.

**Q: Why not use EG Event Grid?**
A: EG custom channels do not automatically receive official CBR events, and the parameters for attaching the official source have no reliable documentation in the current provider, so a blind deployment is equivalent to not configuring it. Cloud Eye event monitoring is the official, zero-ambiguity exposure path for CBR failure events; see "Why alarm rules are not managed by Terraform" above.

**Q: Should alarms be aggregated across multiple accounts?**
A: A single account already provides the full capability. Multi-account aggregation can be extended with EG cross-account authorization + RFS StackSets.

---

## 14. Contributing

Please submit feedback and improvement suggestions through Issues. This repository does not accept direct PRs; all changes are reviewed and merged by the maintainers.

---

## 15. License

This practice is licensed under the **MIT No Attribution** license. See the [`LICENSE`](LICENSE) file in the repository root for details.

This project is released under the MIT-0 license.

---

## 16. Contact / Maintainers
| Item | Content |
|---|---|
| **Creator** | [dgc-git](https://github.com/dgc-git) |
| **Maintainer** | [dgc-git](https://github.com/dgc-git) |
| **Contact** | GitHub Issues / PR (see [Section 14](#14-contributing)) |
