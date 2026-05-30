# DPO Provisioning — Golden Workstation & Cloud Provisioning Pack

This archive contains scripts, templates, and starter code to create a high-performance Windows + WSL development workstation and a cloud provisioning stack for Azure / Partner Center / Marketplace.

## What’s included (best-practice bundle)
- `scripts/master-setup.ps1` — Windows-side automation (enable WSL, tune .wslconfig, debloat, install tooling, create helpers).
- `scripts/wsl-init.sh` — Linux-side bootstrapping script to install .NET, Node, Python, Azure CLI, GitHub CLI, Docker, Dev Containers, and WSL performance tuning.
- `azure/app-manifest.json` — App registration manifest for Azure AD (use as starting point; tailor scopes to your needs).
- `azure/rg-deploy.json` & `azure/main.bicep` — ARM / Bicep examples for tenant onboarding.
- `webhook/index.js` & `webhook/package.json` — Node.js Express SaaS fulfillment webhook skeleton for Marketplace offers.
- `webhook/.env.example` — Environment variable example (do not commit secrets).
- `scripts/wsl-control-panel.ps1` — A lightweight PowerShell WPF control panel for common WSL operations.

## Recommended workflow (summary)
1. Enable virtualization in BIOS/UEFI.
2. Fresh install Windows, attach external NVMe, ensure it is assigned (recommended `D:`).
3. Run `master-setup.ps1` from an elevated PowerShell and reboot when prompted.
4. Launch WSL distros once to create user accounts.
5. Run the WSL init script inside each distro:
   ```bash
   chmod +x ~/wsl-init.sh
   ./wsl-init.sh
   ```
6. Register an Azure AD app using `azure/app-manifest.json`, store credentials in Azure Key Vault.
7. Enroll in Microsoft Partner Center and enable Marketplace / CSP programs.
8. Deploy the webhook to a secure public endpoint and configure SaaS fulfillment in Partner Center.

## Security notes
- Use certificates instead of client secrets where possible.
- Store all credentials in Azure Key Vault or a secure secrets manager.
- Validate Marketplace webhooks; implement idempotency & retries.
- Do not commit `.env` with real secrets to public repositories.

## Next steps
- Customize `app-manifest.json` to match exact Graph/ARM permissions you need.
- Implement DB/persistence and logging for the webhook.
- Harden the webhook with TLS, WAF, and API gateway.
- Optionally build a WinUI/Electron control panel if you need a richer UX.
