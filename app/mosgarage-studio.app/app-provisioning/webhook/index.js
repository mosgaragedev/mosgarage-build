require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const axios = require('axios');

const app = express();
app.use(bodyParser.json());

// Helper: get Azure AD token for ARM / Graph
async function getAzureADToken(scope) {
  const params = new URLSearchParams();
  params.append('grant_type', 'client_credentials');
  params.append('client_id', process.env.CLIENT_ID);
  params.append('client_secret', process.env.CLIENT_SECRET);
  params.append('scope', scope);

  const res = await axios.post(`https://login.microsoftonline.com/${process.env.TENANT_ID}/oauth2/v2.0/token`, params);
  return res.data.access_token;
}

// Example endpoint called by Marketplace when a new SaaS subscription is bought
app.post('/api/saas/subscribe', async (req, res) => {
  try {
    const payload = req.body;
    // TODO: validate signature from Microsoft Commercial Marketplace (JWT or HMAC depending on configuration)

    // Example: provision a customer resource group & assign subscription (this will vary by offer)
    const customerTenantId = payload.customer?.tenantId || null;
    const subscriptionId = payload.order?.subscriptionId || null;

    // 1) If you need to create a new Azure subscription for them (CSP flow), call Partner Center APIs (requires Partner credentials)
    // Placeholder: callPartnerCenterCreateSubscription(...)

    // 2) Deploy an ARM/Bicep template to customer's subscription via delegated token (if delegated admin)
    // Acquire token for Azure Resource Manager
    const armToken = await getAzureADToken('https://management.azure.com/.default');

    // Example: create a resource group (note: subscriptionId must be valid and you must have rights)
    if (subscriptionId) {
      const rgName = `rg-${payload.customer.id || 'cust'}-dpo`;
      const url = `https://management.azure.com/subscriptions/${subscriptionId}/resourcegroups/${rgName}?api-version=2021-04-01`;
      const rgBody = { location: 'eastus' };

      await axios.put(url, rgBody, {
        headers: { Authorization: `Bearer ${armToken}` }
      });
    }

    // 3) Save provisioning state to DB (not implemented here)
    // TODO: store payload and provisioning result in DB

    res.json({ status: 'success', message: 'Provisioning initiated.' });
  } catch (err) {
    console.error('Provision error', err?.response?.data || err.message);
    res.status(500).json({ status: 'error', message: 'Provisioning failed', detail: err?.message || err });
  }
});

// Unsubscribe / uninstall hook - clean up resources
app.post('/api/saas/unsubscribe', async (req, res) => {
  try {
    const payload = req.body;
    // Validate request
    // Delete resources you created
    res.json({ status: 'success', message: 'Unsubscribe handled.' });
  } catch (err) {
    res.status(500).json({ status: 'error', message: 'Unsubscribe failed', detail: err.message });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`SaaS fulfillment listening on ${port}`));
