const { AsyncLocalStorage } = require('async_hooks');

const tenantStorage = new AsyncLocalStorage();

const runWithTenant = (companyId, fn) => {
  const normalized = companyId ? String(companyId) : '';
  return tenantStorage.run({ companyId: normalized || null }, fn);
};

const getTenantCompanyId = () => {
  const store = tenantStorage.getStore();
  return store?.companyId || null;
};

module.exports = {
  runWithTenant,
  getTenantCompanyId,
};

